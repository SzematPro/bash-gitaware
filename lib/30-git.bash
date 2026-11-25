
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
    [ -n "$_bga_git_hash" ] && _bga_git_msg="$(git -c log.showSignature=false log -1 --pretty=%s 2>/dev/null)"

    # Stash count: filesystem-gated, kept sync.
    if [ -f "$_bga_git_dir/refs/stash" ]; then
        _bga_git_stash="$(git -c log.showSignature=false stash list 2>/dev/null | wc -l)"
        _bga_git_stash=$(( _bga_git_stash ))
    fi

    __bga_git_state
}

# ---------------------------------------------------------------------------
# Running `git status` safely in a repository we did not create.
#
# A .git directory that came from an archive (not from `git clone`, which never
# copies .git/config) can name commands that git runs: core.fsmonitor,
# clean/process filter drivers for files whose stat data looks stale (any
# freshly extracted tree), gpg.program for a forged signed commit when
# log.showSignature is set, and the same again inside submodules. The prompt
# runs git on every `cd`, so it must not run them. Every git call here passes
# log.showSignature=false, and __bga_git_status_safe also:
#   * passes core.fsmonitor=false and --ignore-submodules=dirty (no git runs
#     inside submodules, which have their own config);
#   * reads the repository's own config (bash only, bounded) and neutralizes
#     every filter driver it defines (empty clean/process/smudge);
#   * skips `git status` entirely when that config uses include/includeIf
#     (what they pull in cannot be checked cheaply) or a filter name with
#     unexpected characters. The dirty/ahead/behind info is then unknown.
# Drivers from the user's own ~/.gitconfig are untouched. Users whose
# repositories legitimately define local filters (git-crypt, `git lfs install
# --local`) can opt out with BASHGITAWARE_TRUST_REPO_CONFIG=1.
# ---------------------------------------------------------------------------
__bga_git_status_safe() {
    local -a args=(-c core.fsmonitor=false -c log.showSignature=false)
    if [ "${BASHGITAWARE_TRUST_REPO_CONFIG:-0}" != 1 ]; then
        local gd="${_bga_git_dir:-.git}" cfg line low name n=0 REPLY
        # Linked worktrees keep the config in the common directory.
        if __bga_read_line "$gd/commondir"; then
            case "$REPLY" in /*) gd="$REPLY" ;; *) gd="$gd/$REPLY" ;; esac
        fi
        cfg="$gd/config"
        if [ -f "$cfg" ]; then
            while IFS= read -r line || [ -n "$line" ]; do
                n=$(( n + 1 )); [ "$n" -gt 5000 ] && return 1
                line="${line#"${line%%[![:blank:]]*}"}"
                case "$line" in \[*) ;; *) continue ;; esac
                low="${line,,}"
                case "$low" in
                    '[include'*) return 1 ;;
                    '[filter "'*) name="${line#*\"}"; name="${name%%\"*}" ;;
                    '[filter.'*)  name="${line#*.}";  name="${name%%]*}" ;;
                    *) continue ;;
                esac
                case "$name" in '' | *[!A-Za-z0-9._-]*) return 1 ;; esac
                args+=(-c "filter.$name.clean=" -c "filter.$name.process=" -c "filter.$name.smudge=")
            done < "$cfg"
        fi
    fi
    git "${args[@]}" status --porcelain=v2 --branch --ignore-submodules=dirty 2>/dev/null
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
