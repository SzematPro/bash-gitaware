
# ---------------------------------------------------------------------------
# Git: collect prompt info with as few subprocesses as possible
# ---------------------------------------------------------------------------
__bga_git_state() {
    # Reads $_bga_git_dir; sets $_bga_git_state. Filesystem checks only -- no subprocesses.
    _bga_git_state=''
    local d="$_bga_git_dir" s e
    if [ -d "$d/rebase-merge" ]; then
        s="$(cat "$d/rebase-merge/msgnum" 2>/dev/null)"; e="$(cat "$d/rebase-merge/end" 2>/dev/null)"
        _bga_git_state="REBASE ${s:-?}/${e:-?}"
    elif [ -d "$d/rebase-apply" ]; then
        s="$(cat "$d/rebase-apply/next" 2>/dev/null)"; e="$(cat "$d/rebase-apply/last" 2>/dev/null)"
        if [ -f "$d/rebase-apply/rebasing" ]; then _bga_git_state="REBASE ${s:-?}/${e:-?}"
        else _bga_git_state="AM ${s:-?}/${e:-?}"; fi
    elif [ -f "$d/MERGE_HEAD" ];        then _bga_git_state="MERGING"
    elif [ -f "$d/CHERRY_PICK_HEAD" ];  then _bga_git_state="CHERRY-PICK"
    elif [ -f "$d/REVERT_HEAD" ];       then _bga_git_state="REVERTING"
    elif [ -f "$d/BISECT_LOG" ];        then _bga_git_state="BISECTING"
    fi
}

__bga_git_info() {
    _bga_in_git=0
    _bga_git_branch='' _bga_git_hash='' _bga_git_dirty=0
    _bga_git_ahead=0 _bga_git_behind=0 _bga_git_stash=0
    _bga_git_msg='' _bga_git_state='' _bga_git_dir='' _bga_git_top=''

    # 1 subprocess: the git dir and the work-tree root, in one shot.
    local rp; rp="$(git rev-parse --git-dir --show-toplevel 2>/dev/null)" || return
    _bga_in_git=1
    _bga_git_dir="${rp%%$'\n'*}"
    case "$rp" in *$'\n'*) _bga_git_top="${rp#*$'\n'}" ;; *) _bga_git_top= ;; esac

    # 1 subprocess: branch, commit oid, ahead/behind, and whether the tree is dirty.
    local line
    while IFS= read -r line; do
        case "$line" in
            '# branch.head '*) _bga_git_branch="${line#\# branch.head }" ;;
            '# branch.oid '*)
                _bga_git_hash="${line#\# branch.oid }"
                case "$_bga_git_hash" in
                    '('*) _bga_git_hash= ;;          # "(initial)" -- no commits yet
                    *)    _bga_git_hash="${_bga_git_hash:0:7}" ;;
                esac ;;
            '# branch.ab '*)
                _bga_git_ahead="${line#\# branch.ab +}"
                _bga_git_behind="${_bga_git_ahead##*-}"
                _bga_git_ahead="${_bga_git_ahead%% -*}" ;;
            '#'*) ;;                                  # other headers (upstream, ...) -- ignore
            ?*) _bga_git_dirty=1; break ;;            # first changed-path line -- no need to read the rest
        esac
    done < <(git status --porcelain=v2 --branch 2>/dev/null)

    [ "$_bga_git_branch" = "(detached)" ] && _bga_git_branch="detached@${_bga_git_hash}"

    # 1 subprocess (only if there is a commit): the subject line of HEAD.
    [ -n "$_bga_git_hash" ] && _bga_git_msg="$(git log -1 --pretty=%s 2>/dev/null)"

    # 1 subprocess (only if a stash ref exists): count stashed entries.
    if [ -f "$_bga_git_dir/refs/stash" ]; then
        _bga_git_stash="$(git stash list 2>/dev/null | wc -l)"
        _bga_git_stash=$(( _bga_git_stash ))
    fi

    __bga_git_state
}
