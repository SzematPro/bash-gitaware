
# ---------------------------------------------------------------------------
# Git: collect prompt info with as few subprocesses as possible.
#
# Split for M5 async:
#   __bga_git_info_cheap    -- rev-parse + filesystem state + branch label.
#                              Reads .git/HEAD and .git/refs/heads/<branch> to
#                              get the branch + short hash without running
#                              `git status` (which is the expensive part on a
#                              large repo). At most 2 git subprocesses (one
#                              for rev-parse, one fallback for packed refs);
#                              0 outside a repo.
#   __bga_git_info_full     -- cheap + the full porcelain v2 status, sync.
#                              Used when BASHGITAWARE_ASYNC=0.
#   __bga_git_info_expensive_compute
#                           -- emits "key=value" lines for the expensive
#                              fields (dirty / ahead / behind). Called by the
#                              background subshell in lib/85-async.bash.
#   __bga_git_info          -- entry point used by the renderer. Branches on
#                              BASHGITAWARE_ASYNC and (when async) consults
#                              the cache before dispatching a background job.
# ---------------------------------------------------------------------------
__bga_git_state() {
    # Reads $_bga_git_dir; sets $_bga_git_state. Filesystem checks only -- no subprocesses.
    _bga_git_state=''
    local d="$_bga_git_dir" s e REPLY
    if [ -d "$d/rebase-merge" ]; then
        __bga_read_line "$d/rebase-merge/msgnum"; s="$REPLY"; __bga_read_line "$d/rebase-merge/end"; e="$REPLY"
        _bga_git_state="REBASE ${s:-?}/${e:-?}"
    elif [ -d "$d/rebase-apply" ]; then
        __bga_read_line "$d/rebase-apply/next"; s="$REPLY"; __bga_read_line "$d/rebase-apply/last"; e="$REPLY"
        if [ -f "$d/rebase-apply/rebasing" ]; then _bga_git_state="REBASE ${s:-?}/${e:-?}"
        else _bga_git_state="AM ${s:-?}/${e:-?}"; fi
    elif [ -f "$d/MERGE_HEAD" ];        then _bga_git_state="MERGING"
    elif [ -f "$d/CHERRY_PICK_HEAD" ];  then _bga_git_state="CHERRY-PICK"
    elif [ -f "$d/REVERT_HEAD" ];       then _bga_git_state="REVERTING"
    elif [ -f "$d/BISECT_LOG" ];        then _bga_git_state="BISECTING"
    fi
}

# Cheap part: always sync. No `git status` -- the dirty bit, ahead/behind
# counts come from the async path (or from __bga_git_info_full).
__bga_git_info_cheap() {
    _bga_in_git=0
    _bga_git_branch='' _bga_git_hash='' _bga_git_dirty=0
    _bga_git_ahead=0 _bga_git_behind=0 _bga_git_stash=0
    _bga_git_msg='' _bga_git_state='' _bga_git_dir='' _bga_git_top='' _bga_git_common=''

    # 1 subprocess: the git dir, the common dir (where the config lives for a
    # linked worktree; git resolves it, we never parse .git/commondir) and the
    # work-tree root, in one shot.
    # The trailing "x" keeps the final newlines that $(...) would strip: a
    # path ending in a newline would otherwise lose it and name a different
    # directory. Exactly three newline-terminated lines, else no git info: a
    # newline inside any path would shift the fields onto a decoy.
    local rp; rp="$(__bga_gitrun 1 rev-parse --git-dir --git-common-dir --show-toplevel 2>/dev/null && printf x)" || return
    rp="${rp%x}"
    local nls="${rp//[!$'\n']/}"
    [ "${#nls}" = 3 ] || return
    rp="${rp%$'\n'}"
    _bga_in_git=1
    _bga_git_untrusted=0
    _bga_git_dir="${rp%%$'\n'*}"; rp="${rp#*$'\n'}"
    _bga_git_common="${rp%%$'\n'*}"
    case "$rp" in *$'\n'*) _bga_git_top="${rp#*$'\n'}" ;; *) _bga_git_top= ;; esac
    __bga_git_trust || _bga_git_untrusted=1

    # Read .git/HEAD to determine branch / detached state. Filesystem-only.
    local head_path="$_bga_git_dir/HEAD"
    local REPLY
    if __bga_read_line "$head_path"; then
        local head_content="$REPLY"
        case "$head_content" in
            'ref: refs/heads/'*) _bga_git_branch="${head_content#ref: refs/heads/}" ;;
            'ref: '*)            _bga_git_branch="${head_content#ref: }" ;;
            *)
                # Detached HEAD: the file contains a raw SHA.
                _bga_git_hash="${head_content:0:7}"
                _bga_git_branch="detached@${_bga_git_hash}"
                ;;
        esac
    fi

    # Short hash for the branch case: try the loose ref file (filesystem-only),
    # fall back to a fast `git rev-parse` for packed refs.
    if [ -n "$_bga_git_branch" ] && [ -z "$_bga_git_hash" ]; then
        local ref_path="$_bga_git_dir/refs/heads/$_bga_git_branch"
        if __bga_read_line "$ref_path"; then
            _bga_git_hash="${REPLY:0:7}"
        else
            if [ "$_bga_git_untrusted" = 0 ]; then
                _bga_git_hash="$(__bga_git rev-parse --short HEAD 2>/dev/null)" || __bga_git_check_timeout $?
            fi
        fi
    fi

    # Commit subject: kept sync (fast even on large repos -- it only reads HEAD).
    if [ -n "$_bga_git_hash" ] && [ "$_bga_git_untrusted" = 0 ]; then
        _bga_git_msg="$(__bga_git log -1 --pretty=%s 2>/dev/null)" || __bga_git_check_timeout $?
    fi

    # Stash count: filesystem-gated, kept sync.
    if [ -f "$_bga_git_dir/refs/stash" ] && [ "$_bga_git_untrusted" = 0 ]; then
        local sl; sl="$(__bga_git stash list 2>/dev/null)" || __bga_git_check_timeout $?
        _bga_git_stash=0
        [ -n "$sl" ] && { sl="${sl//[!$'\n']/}"; _bga_git_stash=$(( ${#sl} + 1 )); }
    fi

    __bga_git_state
}

# ---------------------------------------------------------------------------
# Running git safely in a repository we did not create.
#
# `git clone` never copies .git/config or .git/hooks, but an extracted archive
# can ship a whole .git. Git settings and hooks there name commands that the
# prompt's own git calls would run on every `cd`: core.fsmonitor, clean/process
# filter drivers (stale stat data after extraction), the post-index-change
# hook (when status rewrites the index), gpg.program for a forged signed commit
# under log.showSignature, a lazy fetch with core.sshCommand in a partial
# clone, and the same again inside submodules.
#
# __bga_git_trust runs once per prompt, after `git rev-parse`, and fills
# _bga_git_args for __bga_git, the wrapper every other git call goes through:
#   * --no-optional-locks, core.hooksPath=/dev/null, core.fsmonitor=false,
#     log.showSignature=false; GIT_NO_LAZY_FETCH=1 and GIT_OPTIONAL_LOCKS=0
#     in the environment;
#   * every filter driver the repository's config (and config.worktree)
#     defines is neutralized (empty clean/process/smudge). Git itself lists
#     them (--file --no-includes --name-only): a bash parser disagrees with
#     git on edge cases;
#   * it fails closed (returns 1, and the prompt shows only the branch) on
#     include/includeIf, a partial clone (extensions.partialClone,
#     remote.*.promisor), an odd driver name, a missing config file in the
#     common dir that git reports, or a config git cannot parse.
# `git status` also passes --ignore-submodules=dirty (no git inside
# submodules, which have their own config). The user's own ~/.gitconfig is
# trusted. BASHGITAWARE_TRUST_REPO_CONFIG=1 keeps only the fixed overrides, for
# repositories that rely on local filters (git-crypt, `git lfs install --local`).
# ---------------------------------------------------------------------------
_bga_git_args=()

# Every git call has a hard time limit: a FIFO or a /dev/tty symlink planted
# anywhere git reads (.git/config, HEAD, index, packed-refs, .gitattributes,
# ...) would otherwise block the prompt for good, and Ctrl-C only restarts
# it. git also gets /dev/null as stdin. Checking file types first cannot work:
# git opens too many paths. timeout(1) (coreutils or BusyBox; gtimeout from
# Homebrew coreutils) is used when present, else a background watchdog.
if command -v timeout >/dev/null 2>&1; then _bga_tmo=timeout
elif command -v gtimeout >/dev/null 2>&1; then _bga_tmo=gtimeout
else _bga_tmo=''
fi

# __bga_gitrun <seconds> <git args...>
__bga_gitrun() {
    local lim="$1"; shift
    if [ -n "$_bga_tmo" ]; then
        GIT_NO_LAZY_FETCH=1 GIT_OPTIONAL_LOCKS=0 "$_bga_tmo" -s KILL "$lim" git "$@" </dev/null
        return
    fi
    local p w rc
    GIT_NO_LAZY_FETCH=1 GIT_OPTIONAL_LOCKS=0 git "$@" </dev/null &
    p=$!
    { sleep "$lim"; kill -KILL "$p"; } >/dev/null 2>&1 &
    w=$!
    wait "$p"; rc=$?
    kill "$w" >/dev/null 2>&1
    return "$rc"
}

# A call killed by the time limit (exit 124 or 137) means something in the
# repository blocks reads: mark it untrusted so the rest of this prompt skips
# git instead of waiting out each limit in turn.
__bga_git_check_timeout() {
    case "$1" in 124 | 137) _bga_git_untrusted=1 ;; esac
    return 0
}

# Prompt git calls: 1 second each. git status alone gets more: 3 s in the
# sync path, 10 s in the async job (_bga_status_limit, set with `local`).
__bga_git() {
    __bga_gitrun "${_bga_git_limit:-1}" "${_bga_git_args[@]}" "$@"
}

__bga_git_trust() {
    _bga_git_args=(--no-optional-locks -c core.hooksPath=/dev/null
                   -c core.fsmonitor=false -c log.showSignature=false)
    [ "${BASHGITAWARE_TRUST_REPO_CONFIG:-0}" = 1 ] && return 0
    # The common dir comes from `git rev-parse --git-common-dir`, so this is
    # the config file git itself loads. Fail closed if it is missing.
    local gd="${_bga_git_common:-}" cfg names name rc
    [ -n "$gd" ] && [ -f "$gd/config" ] || return 1
    for cfg in "$gd/config" "${_bga_git_dir:-.git}/config.worktree"; do
        [ -f "$cfg" ] || continue
        names="$(__bga_gitrun 1 config --file "$cfg" --no-includes --name-only \
                 --get-regexp '^(filter|include|includeif)\.|^extensions\.partialclone$|^remote\..*\.promisor$' 2>/dev/null)"
        rc=$?
        [ "$rc" = 1 ] && continue          # no match
        [ "$rc" = 0 ] || return 1
        while [ -n "$names" ]; do
            name="${names%%$'\n'*}"
            case "$names" in *$'\n'*) names="${names#*$'\n'}" ;; *) names='' ;; esac
            case "$name" in filter.*.*) ;; *) return 1 ;; esac   # include, partial clone
            name="${name#filter.}"; name="${name%.*}"
            case "$name" in '' | *[!A-Za-z0-9._-]*) return 1 ;; esac
            _bga_git_args+=(-c "filter.$name.clean=" -c "filter.$name.process=" -c "filter.$name.smudge=")
        done
    done
}

__bga_git_status_safe() {
    local _bga_git_limit="${_bga_status_limit:-3}"
    [ "${_bga_git_untrusted:-0}" = 1 ] && return 0
    __bga_git status --porcelain=v2 --branch --ignore-submodules=dirty 2>/dev/null
}

# Full sync info: cheap + the expensive porcelain v2 status. Used when
# BASHGITAWARE_ASYNC=0.
__bga_git_info_full() {
    __bga_git_info_cheap
    [ "$_bga_in_git" = 1 ] || return

    local line
    while IFS= read -r line; do
        case "$line" in
            '# branch.ab '*)
                _bga_git_ahead="${line#\# branch.ab +}"
                _bga_git_behind="${_bga_git_ahead##*-}"
                _bga_git_ahead="${_bga_git_ahead%% -*}" ;;
            '#'*) ;;
            ?*) _bga_git_dirty=1; break ;;
        esac
    done < <(__bga_git_status_safe)
}

# Expensive: compute dirty / ahead / behind and emit them as "key=value" lines
# on stdout. Called inside the background subshell of lib/85-async.bash; never
# touches caller state directly.
__bga_git_info_expensive_compute() {
    local _bga_status_limit=10
    local dirty=0 ahead=0 behind=0 line
    while IFS= read -r line; do
        case "$line" in
            '# branch.ab '*)
                ahead="${line#\# branch.ab +}"
                behind="${ahead##*-}"
                ahead="${ahead%% -*}" ;;
            '#'*) ;;
            ?*) dirty=1; break ;;
        esac
    done < <(__bga_git_status_safe)
    printf '_bga_async_dirty=%d\n_bga_async_ahead=%d\n_bga_async_behind=%d\n' \
        "$dirty" "$ahead" "$behind"
}

# Entry point used by the renderer. Picks the sync or async path.
__bga_git_info() {
    if [ "${BASHGITAWARE_ASYNC:-1}" = 0 ]; then
        __bga_git_info_full
        _bga_async_pending=0
        return
    fi

    __bga_git_info_cheap
    if [ "$_bga_in_git" = 1 ]; then
        __bga_async_apply_or_dispatch
    else
        _bga_async_pending=0
    fi
}
