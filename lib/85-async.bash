
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
#     Cancels any in-flight previous job (SIGTERM + wait) and spawns a new
#     subshell that computes expensive info and atomically writes it to the
#     cache (via rename of a sibling tmpfile).
#   - __bga_async_cleanup              (EXIT trap)
#     Kills any still-running background job and removes the cache file.
#
# Cache file:
#   ${XDG_RUNTIME_DIR:-/tmp}/bga-${$}.cache
#   Plain key=value lines. Parsed defensively (no `source`): we accept only
#   four known keys and ignore everything else.
# ---------------------------------------------------------------------------

_bga_async_pid=''
_bga_async_cache=''
_bga_async_pending=0

# Called once at source time from lib/90-hooks.bash.
__bga_async_init() {
    [ "${BASHGITAWARE_ASYNC:-1}" = 0 ] && return
    [[ $- == *i* ]] || return
    _bga_async_cache="${XDG_RUNTIME_DIR:-/tmp}/bga-${$}.cache"
    trap '__bga_async_cleanup' EXIT
}

__bga_async_cleanup() {
    if [ -n "$_bga_async_pid" ] && kill -0 "$_bga_async_pid" 2>/dev/null; then
        kill -TERM "$_bga_async_pid" 2>/dev/null
    fi
    [ -n "$_bga_async_cache" ] && [ -e "$_bga_async_cache" ] && rm -f "$_bga_async_cache"
}

# Try the cache for the current (PWD, gitdir) key. Hit -> populate the
# expensive vars, _bga_async_pending=0. Miss -> defaults stay (0,0,0),
# dispatch a job, _bga_async_pending=1.
__bga_async_apply_or_dispatch() {
    local key="${PWD}|${_bga_git_dir}"
    local cache_key='' dirty='' ahead='' behind=''

    if [ -n "$_bga_async_cache" ] && [ -e "$_bga_async_cache" ]; then
        local k v
        # Defensive parse: no `source`; accept only four known keys.
        while IFS='=' read -r k v; do
            v="${v#\"}"; v="${v%\"}"
            case "$k" in
                _bga_async_key)    cache_key="$v" ;;
                _bga_async_dirty)  dirty="$v" ;;
                _bga_async_ahead)  ahead="$v" ;;
                _bga_async_behind) behind="$v" ;;
            esac
        done < "$_bga_async_cache"
        if [ "$cache_key" = "$key" ]; then
            # Cache hit: only accept numeric values; reject anything funky.
            case "$dirty"  in '' | *[!0-9]*) dirty=0  ;; esac
            case "$ahead"  in '' | *[!0-9]*) ahead=0  ;; esac
            case "$behind" in '' | *[!0-9]*) behind=0 ;; esac
            _bga_git_dirty="$dirty"
            _bga_git_ahead="$ahead"
            _bga_git_behind="$behind"
            _bga_async_pending=0
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
        wait "$_bga_async_pid" 2>/dev/null
    fi
    _bga_async_pid=''

    local cache="$_bga_async_cache"
    (
        cd "$top" 2>/dev/null || exit 0
        local expensive
        expensive="$(__bga_git_info_expensive_compute)"
        # Atomic write: write to a sibling tmpfile and rename into place.
        local tmp="${cache}.tmp.$$"
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
