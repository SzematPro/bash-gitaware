
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
    _bga_git_gone=0 _bga_git_staged=0 _bga_git_unstaged=0 _bga_git_untracked=0 _bga_git_conflicts=0 _bga_git_capped=0
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
    # The subject is only fetched when it is shown (Lean: off by default;
    # classic: on), and only its first 2 KB: a commit can carry a subject of
    # many megabytes.
    local want_msg=1
    [ "${BASHGITAWARE_STYLE:-lean}" != classic ] && want_msg=0
    [ -n "${BASHGITAWARE_COMMIT_LINE:-}" ] && want_msg="$BASHGITAWARE_COMMIT_LINE"
    if [ "$want_msg" != 0 ] && [ -n "$_bga_git_hash" ] && [ "$_bga_git_untrusted" = 0 ]; then
        # git's own status (for the timeout check) via PIPESTATUS: `local -`
        # with pipefail made bash 4.4 and 5.0 crash.
        _bga_git_msg="$(__bga_git log -1 --pretty=%s 2>/dev/null | head -c 2048; exit "${PIPESTATUS[0]}")" \
            || __bga_git_check_timeout $?
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
_bga_trust_key='' _bga_trust_rc=0 _bga_trust_args=()

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
    local gd="${_bga_git_common:-}" wt="${_bga_git_dir:-.git}/config.worktree" key
    [ -n "$gd" ] && [ -f "$gd/config" ] || return 1
    # Cache per repository and worktree, validated by content: the files
    # are read with the read builtin (no fork; only regular files, at most
    # 64 KB, 1 s timeout in case one is swapped for a FIFO) and must match
    # what was checked. Modification times are not
    # trusted: `tar xf` can restore an old one over new content.
    local c1='' c2='' cacheable=1 REPLY
    __bga_read_whole "$gd/config" && c1="$REPLY" || cacheable=0
    if [ -f "$wt" ]; then __bga_read_whole "$wt" && c2="wt:$REPLY" || cacheable=0; fi
    key="$gd|${_bga_git_dir:-}|$c1|$c2"
    if [ "$cacheable" = 1 ] && [ "$key" = "${_bga_trust_key:-}" ]; then
        _bga_git_args=("${_bga_trust_args[@]}")
        return "$_bga_trust_rc"
    fi
    __bga_git_trust_scan "$gd" "$wt"; local rc=$?
    # Cache only if the files still hold what was read before the scan, so
    # the verdict is bound to the bytes git actually checked.
    local d1='' d2=''
    __bga_read_whole "$gd/config" && d1="$REPLY" || cacheable=0
    if [ -f "$wt" ]; then __bga_read_whole "$wt" && d2="wt:$REPLY" || cacheable=0; fi
    if [ "$cacheable" = 1 ] && [ "$d1" = "$c1" ] && [ "$d2" = "$c2" ]; then
        _bga_trust_key="$key" _bga_trust_rc="$rc"
        _bga_trust_args=("${_bga_git_args[@]}")
    else
        _bga_trust_key=''
    fi
    return "$rc"
}

# Whole content of a small regular file into REPLY; returns 1 if it is not a
# regular file, cannot be read within 1 s, or is 64 KB or larger. Byte
# semantics (LC_ALL=C): in a UTF-8 locale read -N and ${#var} count invalid
# sequences differently, which once let a larger file pass as complete. One
# extra byte is read to prove EOF was reached.
__bga_read_whole() {
    local LC_ALL=C x=''
    REPLY=''
    [ -f "$1" ] || return 1
    { IFS= read -r -t 1 -d '' -N 65536 REPLY; IFS= read -r -t 1 -N 1 x; } < "$1" 2>/dev/null
    [ -z "$x" ] && [ "${#REPLY}" -lt 65536 ]
}

# The uncached check: list the repository's filter drivers and the settings
# that make us fail closed, with git itself.
__bga_git_trust_scan() {
    local gd="$1" wt="$2" cfg names name rc
    for cfg in "$gd/config" "$wt"; do
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
    return 0
}

__bga_git_status_safe() {
    local _bga_git_limit="${_bga_status_limit:-3}"
    [ "${_bga_git_untrusted:-0}" = 1 ] && return 0
    __bga_git status --porcelain=v2 --branch --ignore-submodules=dirty 2>/dev/null
}

# Parse `git status --porcelain=v2 --branch` into _bga_st_dirty,
# _bga_st_ahead, _bga_st_behind and _bga_st_gone (an upstream is configured
# but no longer exists: the branch.upstream header without branch.ab).
# Headers come first. In compact mode the first entry line answers "dirty",
# so `head` stops git early on large dirty trees. With git_status = detail
# it counts staged, unstaged, untracked and conflicted entries
# (_bga_st_staged/_unstaged/_untracked/_conflicts) over at most 2000
# entries; _bga_st_capped=1 when it stopped there (3.2, ADR-0013).
# No process substitution (a syntax and runtime error in posix mode before
# bash 5.1) and no here-string (a temp file before bash 5.1).
# Results of __bga_git_status_parse (assigned there through printf -v).
_bga_st_dirty=0 _bga_st_ahead=0 _bga_st_behind=0 _bga_st_gone=0 _bga_st_staged=0
_bga_st_unstaged=0 _bga_st_untracked=0 _bga_st_conflicts=0 _bga_st_capped=0
__bga_git_status_parse() {
    local detail=0 n=8 r
    # Detail: up to 4 header lines, 2000 entries, and one more to tell "2000"
    # from "more than 2000".
    [ "${BASHGITAWARE_GIT_STATUS:-compact}" = detail ] && detail=1 n=2005
    # The counting runs at the end of a pipe and prints one result line: a
    # `read` loop is linear, while cutting lines off a captured string copies
    # the rest each time (17 s for 2000 entries, ruling out the worker's 10 s
    # limit). A pipe, not process substitution (R-3).
    r="$(__bga_git_status_safe | head -n "$n" | __bga_git_status_count "$detail")"
    case "$r" in *[!0-9\ ]* | '') r='0 0 0 0 0 0 0 0 0' ;; esac
    # Split with parameter expansion: no here-document (a temp file before
    # bash 5.1), and no dependence on the caller's IFS or globbing.
    local rest="$r " f v
    for f in dirty ahead behind gone staged unstaged untracked conflicts capped; do
        v="${rest%% *}"; rest="${rest#* }"
        printf -v "_bga_st_$f" '%s' "${v:-0}"
    done
    return 0
}

# Count porcelain v2 lines from stdin; $1 = 1 for detail. Prints "dirty ahead
# behind gone staged unstaged untracked conflicts capped" (numbers only).
__bga_git_status_count() {
    local line a b dirty=0 ahead=0 behind=0 up=0 ab=0 st=0 un=0 ut=0 cf=0 cap=0 e=0
    while IFS= read -r line; do
        case "$line" in
            '# branch.upstream '*) up=1 ;;
            '# branch.ab '*)
                ab=1; a="${line#'# branch.ab +'}"; b="${a##*-}"; a="${a%% -*}"
                case "$a" in '' | *[!0-9]*) a=0 ;; esac
                case "$b" in '' | *[!0-9]*) b=0 ;; esac
                ahead="$a" behind="$b" ;;
            '#'*) ;;
            ?*)
                dirty=1
                [ "$1" = 1 ] || break
                e=$(( e + 1 ))
                if [ "$e" -gt 2000 ]; then cap=1; break; fi
                case "$line" in
                    [12]' '[!.]*) st=$(( st + 1 )) ;;
                esac
                case "$line" in
                    [12]' '?[!.]*) un=$(( un + 1 )) ;;
                    'u '*) cf=$(( cf + 1 )) ;;
                    '? '*) ut=$(( ut + 1 )) ;;
                esac ;;
        esac
    done
    [ "$up" = 1 ] && [ "$ab" = 0 ] && up=gone
    [ "$up" = gone ] && up=1 || up=0
    printf '%s %s %s %s %s %s %s %s %s\n' "$dirty" "$ahead" "$behind" "$up" "$st" "$un" "$ut" "$cf" "$cap"
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
    _bga_git_gone="$_bga_st_gone" _bga_git_staged="$_bga_st_staged" _bga_git_unstaged="$_bga_st_unstaged"
    _bga_git_untracked="$_bga_st_untracked" _bga_git_conflicts="$_bga_st_conflicts" _bga_git_capped="$_bga_st_capped"
}

# Expensive: compute dirty / ahead / behind and emit them as "key=value" lines
# on stdout. Called inside the background subshell of lib/85-async.bash; never
# touches caller state directly.
__bga_git_info_expensive_compute() {
    local _bga_status_limit=10
    __bga_git_status_parse
    printf '_bga_async_v=2\n_bga_async_dirty=%d\n_bga_async_ahead=%d\n_bga_async_behind=%d\n' \
        "$_bga_st_dirty" "$_bga_st_ahead" "$_bga_st_behind"
    printf '_bga_async_gone=%d\n_bga_async_staged=%d\n_bga_async_unstaged=%d\n_bga_async_untracked=%d\n_bga_async_conflicts=%d\n_bga_async_capped=%d\n' \
        "$_bga_st_gone" "$_bga_st_staged" "$_bga_st_unstaged" "$_bga_st_untracked" "$_bga_st_conflicts" "$_bga_st_capped"
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
