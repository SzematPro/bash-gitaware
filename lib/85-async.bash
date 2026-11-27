
# ---------------------------------------------------------------------------
# Async / non-blocking rendering -- deferred refresh on the next prompt.
#
# Strategy (per ADR-0005): split git work into "cheap" (always sync:
# rev-parse, filesystem state, branch label via .git/HEAD) and "expensive"
# (`git status --porcelain=v2` for dirty/ahead/behind). The cheap part runs
# every prompt; the expensive part runs in a background subshell that writes
# its result to a per-shell cache file. The NEXT prompt cycle reads the cache
# and renders the full info. No in-place refresh -- a true in-place redraw
# fights readline and corrupts the line being edited; the "deferred refresh
# on next prompt" path is the honest deliverable. ADR-0005 records the
# tradeoff and what was actually shipped.
#
# Knob: BASHGITAWARE_ASYNC=0 -> fully synchronous, no background job, no
# cache file. The render path then calls __bga_git_info_full directly.
#
# Lifecycle:
#   - __bga_async_init                 (lib/90-hooks.bash, at source time)
#     Sets the cache path, installs the EXIT trap that cleans up.
#   - __bga_async_apply_or_dispatch    (lib/30-git.bash __bga_git_info)
#     Reads cache for the current (PWD, gitdir) key; if hit, populates the
#     dirty/ahead/behind vars. If miss, dispatches a background job.
#   - __bga_async_dispatch             (here)
#     Cancels any in-flight previous job (SIGTERM) and spawns a new
#     subshell that computes expensive info and atomically writes it to the
#     cache (via rename of a sibling tmpfile).
#   - __bga_async_cleanup              (EXIT trap)
#     Kills any still-running background job and removes the cache file.
#
# Cache file:
#   <state dir>/cache, in the private per-shell directory of lib/16-state.bash
#   (bga.XXXXXXXX under $XDG_RUNTIME_DIR or ${TMPDIR:-/tmp}, mode 0700).
#   Plain key=value lines. Parsed defensively (no `source`): we accept only
#   four known keys and ignore everything else.
# ---------------------------------------------------------------------------

_bga_async_pid=''
_bga_async_cache=''
_bga_async_dir=''
_bga_async_pending=0

# Called once at source time from lib/90-hooks.bash.
__bga_async_init() {
    [ "${BASHGITAWARE_ASYNC:-1}" = 0 ] && return
    [[ $- == *i* ]] || return
    # Private per-shell directory (lib/16-state.bash): never a predictable
    # name in a shared /tmp. No safe directory -> async stays off.
    __bga_state_dir_init || return
    _bga_async_dir="$_bga_state_dir"
    _bga_async_cache="$_bga_async_dir/cache"
    __bga_trap_add __bga_async_cleanup EXIT "$(trap -p EXIT)"
}

__bga_async_cleanup() {
    if [ -n "$_bga_async_pid" ] && kill -0 "$_bga_async_pid" 2>/dev/null; then
        kill -TERM "$_bga_async_pid" 2>/dev/null
    fi
    __bga_state_dir_cleanup
}

# Try the cache for the current (PWD, gitdir) key. Hit -> populate the
# expensive vars, _bga_async_pending=0. Miss -> defaults stay (0,0,0),
# dispatch a job, _bga_async_pending=1.
__bga_async_apply_or_dispatch() {
    # The git_status mode is part of the key: a compact result has no counts.
    local key="${PWD}|${_bga_git_dir}|${BASHGITAWARE_GIT_STATUS:-compact}"
    key="${key//$'\n'/?}"     # the cache is line-based: one line per key
    local cache_key='' dirty='' ahead='' behind='' ver='' f
    local gone='' staged='' unstaged='' untracked='' conflicts='' capped=''

    if [ -n "$_bga_async_cache" ] && [ -e "$_bga_async_cache" ]; then
        local k v
        # Defensive parse: no `source`; accept only known keys.
        while IFS='=' read -r k v; do
            v="${v#\"}"; v="${v%\"}"
            case "$k" in
                _bga_async_key)       cache_key="$v" ;;
                _bga_async_v)         ver="$v" ;;
                _bga_async_dirty)     dirty="$v" ;;
                _bga_async_ahead)     ahead="$v" ;;
                _bga_async_behind)    behind="$v" ;;
                _bga_async_gone)      gone="$v" ;;
                _bga_async_staged)    staged="$v" ;;
                _bga_async_unstaged)  unstaged="$v" ;;
                _bga_async_untracked) untracked="$v" ;;
                _bga_async_conflicts) conflicts="$v" ;;
                _bga_async_capped)    capped="$v" ;;
            esac
        done < "$_bga_async_cache"
        # A cache from another format version is a miss, never misread.
        if [ "$cache_key" = "$key" ] && [ "$ver" = 2 ]; then
            # Cache hit: only accept numeric values; reject anything funky.
            for f in dirty ahead behind gone staged unstaged untracked conflicts capped; do
                case "${!f}" in '' | *[!0-9]*) printf -v "$f" 0 ;; esac
            done
            _bga_git_dirty="$dirty"
            _bga_git_ahead="$ahead"
            _bga_git_behind="$behind"
            _bga_git_gone="$gone" _bga_git_staged="$staged" _bga_git_unstaged="$unstaged"
            _bga_git_untracked="$untracked" _bga_git_conflicts="$conflicts" _bga_git_capped="$capped"
            _bga_async_pending=0
            # A command just ran (the timer is set): it may have changed the
            # tree, so refresh in the background. The cached values stay on
            # screen meanwhile; no pending marker. Without this the first
            # result was kept for as long as the shell stayed here.
            [ -n "${_bga_timer_start:-}" ] && __bga_async_dispatch "$key" "$_bga_git_top"
            return
        fi
    fi

    # Cache miss: expensive vars stay at the cheap-path defaults (0,0,0),
    # mark pending, dispatch a background job to compute and write the cache.
    _bga_async_pending=1
    __bga_async_dispatch "$key" "$_bga_git_top"
}

__bga_async_dispatch() {
    [ -z "$_bga_async_cache" ] && return
    local key="$1" top="$2"
    [ -z "$top" ] && return

    # Cancel a previous in-flight job, if any.
    if [ -n "$_bga_async_pid" ] && kill -0 "$_bga_async_pid" 2>/dev/null; then
        kill -TERM "$_bga_async_pid" 2>/dev/null
    fi
    _bga_async_pid=''

    local cache="$_bga_async_cache"
    (
        # Run in the shell's own directory, the one the trust check validated,
        # never in a path re-derived from parsed output.
        local expensive
        expensive="$(__bga_git_info_expensive_compute)"
        # Atomic write: write to a sibling tmpfile and rename into place.
        # $BASHPID, not $$ ($$ is the parent shell in every job): a cancelled
        # job still running must not share the new job's tmp file.
        local tmp="${cache}.tmp.$BASHPID"
        {
            printf '_bga_async_key="%s"\n' "$key"
            printf '%s\n' "$expensive"
        } > "$tmp" 2>/dev/null || exit 0
        mv -f "$tmp" "$cache" 2>/dev/null
    ) &
    _bga_async_pid=$!
    # Detach from job control so "Done" messages do not leak into the terminal.
    disown "$_bga_async_pid" 2>/dev/null || true
}
