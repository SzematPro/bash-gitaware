
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
    _bga_git_msg='' _bga_git_state='' _bga_git_dir='' _bga_git_top=''

    # 1 subprocess: the git dir and the work-tree root, in one shot.
    local rp; rp="$(git rev-parse --git-dir --show-toplevel 2>/dev/null)" || return
    _bga_in_git=1
    _bga_git_dir="${rp%%$'\n'*}"
    case "$rp" in *$'\n'*) _bga_git_top="${rp#*$'\n'}" ;; *) _bga_git_top= ;; esac

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
            _bga_git_hash="$(git rev-parse --short HEAD 2>/dev/null)"
        fi
    fi

    # Commit subject: kept sync (fast even on large repos -- it only reads HEAD).
    [ -n "$_bga_git_hash" ] && _bga_git_msg="$(git log -1 --pretty=%s 2>/dev/null)"

    # Stash count: filesystem-gated, kept sync.
    if [ -f "$_bga_git_dir/refs/stash" ]; then
        _bga_git_stash="$(git stash list 2>/dev/null | wc -l)"
        _bga_git_stash=$(( _bga_git_stash ))
    fi

    __bga_git_state
}

# Parse the head of `git status --porcelain=v2 --branch` into _bga_st_dirty,
# _bga_st_ahead and _bga_st_behind. Branch headers come first, so the first
# entry line already answers "dirty"; `head` bounds the output and stops git
# early on large dirty trees. No process substitution (a syntax and runtime
# error in posix mode before bash 5.1) and no here-string (a temp file
# before bash 5.1).
__bga_git_status_parse() {
    local st line
    _bga_st_dirty=0 _bga_st_ahead=0 _bga_st_behind=0
    # core.fsmonitor names a command that `git status` runs; a .git/config
    # from an extracted archive could point it anywhere. Never run it.
    st="$(git -c core.fsmonitor=false status --porcelain=v2 --branch 2>/dev/null | head -n 8)"
    while [ -n "$st" ]; do
        line="${st%%$'\n'*}"
        case "$st" in *$'\n'*) st="${st#*$'\n'}" ;; *) st='' ;; esac
        case "$line" in
            '# branch.ab '*)
                _bga_st_ahead="${line#\# branch.ab +}"
                _bga_st_behind="${_bga_st_ahead##*-}"
                _bga_st_ahead="${_bga_st_ahead%% -*}" ;;
            '#'*) ;;
            ?*) _bga_st_dirty=1; break ;;
        esac
    done
}

# Full sync info: cheap + the expensive porcelain v2 status. Used when
# BASHGITAWARE_ASYNC=0.
__bga_git_info_full() {
    __bga_git_info_cheap
    [ "$_bga_in_git" = 1 ] || return
    __bga_git_status_parse
    _bga_git_dirty="$_bga_st_dirty"
    _bga_git_ahead="$_bga_st_ahead"
    _bga_git_behind="$_bga_st_behind"
}

# Expensive: compute dirty / ahead / behind and emit them as "key=value" lines
# on stdout. Called inside the background subshell of lib/85-async.bash; never
# touches caller state directly.
__bga_git_info_expensive_compute() {
    __bga_git_status_parse
    printf '_bga_async_dirty=%d\n_bga_async_ahead=%d\n_bga_async_behind=%d\n' \
        "$_bga_st_dirty" "$_bga_st_ahead" "$_bga_st_behind"
}

# Entry point used by the renderer. Picks the sync or async path.
__bga_git_info() {
    # Sync when async is off, or when it could not start (no safe state
    # directory, non-interactive shell): otherwise "pending" never clears.
    if [ "${BASHGITAWARE_ASYNC:-1}" = 0 ] || [ -z "${_bga_async_cache:-}" ]; then
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
