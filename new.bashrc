# ~/.bashrc: executed by bash(1) for non-login shells.
#
# bash-gitaware -- a modern, git-aware bash prompt.
# Author: Waldemar Szemat <waldemar@szemat.pro>
# Repo:   https://github.com/SzematPro/bash-gitaware
#
# A clean two-line prompt that surfaces context only when it matters: the
# repository-relative path, the branch, working-tree status, the runtime/version
# of the project you are in (Node, Python, Rust, Go), and how long the last
# command took. Inspired by modern cross-shell prompts; plain bash, no dependencies.
#
# Configuration (export before this file is sourced, e.g. from /etc/profile,
# ~/.profile, or near the top of this file):
#
#   BASHGITAWARE_GLYPHS=nerd|unicode|ascii  Force a glyph set. Default: auto --
#                                           "unicode" if the locale is UTF-8, else "ascii".
#                                           "nerd" is never auto-selected (a UTF-8 locale does not
#                                           mean the font has the glyphs): opt in explicitly.
#   BASHGITAWARE_NERD_FONT=1                 Shorthand for BASHGITAWARE_GLYPHS=nerd.
#   BASHGITAWARE_COMMIT_LINE=0               Hide the "last commit subject" line. Default: 1 (shown).
#   BASHGITAWARE_RUNTIME=0                   Disable the runtime/version modules. Default: 1 (enabled).
#   BASHGITAWARE_TIMER_THRESHOLD=N           Show command duration only if it took >= N seconds. Default: 2.
#   BASHGITAWARE_PATH_MAXDEPTH=N             Show at most N trailing path components (0 = unlimited). Default: 3.
#   BASHGITAWARE_SHOW_HOST=auto|always|never Show user@host. "auto" = only over SSH or as root. Default: auto.
#   NO_COLOR                                 If set (any value), disable all color. https://no-color.org

# If not running interactively, do nothing.
case $- in
    *i*) ;;
      *) return ;;
esac

# ---------------------------------------------------------------------------
# History
# ---------------------------------------------------------------------------
HISTCONTROL=ignoreboth
HISTSIZE=10000
HISTFILESIZE=20000
shopt -s histappend
shopt -s checkwinsize

[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot="$(cat /etc/debian_chroot)"
fi

# ---------------------------------------------------------------------------
# Environment detection (computed once, at shell startup)
# ---------------------------------------------------------------------------
if [ -n "${SSH_CONNECTION:-}" ] || [ -n "${SSH_TTY:-}" ] || [ -n "${SSH_CLIENT:-}" ]; then
    _bga_ssh=1
else
    _bga_ssh=0
fi

if [ -f /.dockerenv ] || [ -f /run/.containerenv ] \
   || grep -qsm1 'docker\|lxc\|containerd' /proc/1/cgroup 2>/dev/null; then
    _bga_container=1
else
    _bga_container=0
fi

# Is the active locale UTF-8?
case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
    *[Uu][Tt][Ff]-8* | *[Uu][Tt][Ff]8*) _bga_utf8=1 ;;
    *) _bga_utf8=0 ;;
esac

# Does the terminal understand an OSC window-title escape?
case "${TERM:-}" in
    xterm* | rxvt* | screen* | tmux* | alacritty* | foot* | wezterm* | konsole*) _bga_title=1 ;;
    *) _bga_title=0 ;;
esac

# Running as root?
if [ "${EUID:-$(id -u)}" -eq 0 ]; then _bga_root=1; else _bga_root=0; fi

# ---------------------------------------------------------------------------
# Color palette
# ---------------------------------------------------------------------------
_bga_color=0
if [ "${NO_COLOR+set}" != set ]; then
    case "${TERM:-}" in
        *-256color | *-color | xterm* | rxvt* | screen* | tmux* | alacritty* | foot* | wezterm* | konsole* | linux)
            _bga_color=1 ;;
        *)
            if [ -x /usr/bin/tput ] && tput setaf 1 >/dev/null 2>&1; then _bga_color=1; fi ;;
    esac
fi

if [ "$_bga_color" = 1 ]; then
    _R='\[\033[0m\]'
    _c_dim='\[\033[38;5;244m\]'         # connector words (on / via / took)
    _c_path='\[\033[1;38;5;75m\]'       # path -- bold steel blue
    _c_user='\[\033[38;5;79m\]'         # user -- teal
    _c_host='\[\033[38;5;79m\]'         # host -- teal
    _c_host_ssh='\[\033[1;38;5;215m\]'  # host over SSH -- bold amber
    _c_branch='\[\033[1;38;5;176m\]'    # branch -- bold purple
    _c_hash='\[\033[38;5;244m\]'        # short hash -- grey
    _c_state='\[\033[1;38;5;203m\]'     # in-progress state (rebase/merge) -- bold red
    _c_ahead='\[\033[38;5;179m\]'       # ahead -- yellow
    _c_behind='\[\033[38;5;179m\]'      # behind -- yellow
    _c_dirty='\[\033[38;5;179m\]'       # dirty marker -- yellow
    _c_stash='\[\033[38;5;110m\]'       # stash count -- soft blue
    _c_commit='\[\033[38;5;244m\]'      # "last commit" line -- grey
    _c_node='\[\033[38;5;114m\]'        # node runtime -- green
    _c_py='\[\033[38;5;179m\]'          # python runtime -- yellow
    _c_rust='\[\033[38;5;173m\]'        # rust runtime -- orange
    _c_go='\[\033[38;5;80m\]'           # go runtime -- cyan
    _c_tag='\[\033[38;5;215m\]'         # container / chroot tag -- amber
    _c_timer='\[\033[38;5;179m\]'       # command duration -- yellow
    _c_err='\[\033[1;38;5;203m\]'       # exit code -- bold red
    _c_ok='\[\033[1;38;5;114m\]'        # prompt symbol, success -- bold green
    _c_sym_err='\[\033[1;38;5;203m\]'   # prompt symbol, failure -- bold red
else
    _R=''
    _c_dim='' _c_path='' _c_user='' _c_host='' _c_host_ssh='' _c_branch='' _c_hash=''
    _c_state='' _c_ahead='' _c_behind='' _c_dirty='' _c_stash='' _c_commit=''
    _c_node='' _c_py='' _c_rust='' _c_go='' _c_tag='' _c_timer='' _c_err='' _c_ok='' _c_sym_err=''
fi

# ---------------------------------------------------------------------------
# Glyphs -- tiered: nerd > unicode > ascii
# A UTF-8 locale only tells us the *encoding* works, not that the *font* has the
# glyphs, so auto-detection never picks "nerd": opt in with BASHGITAWARE_NERD_FONT=1.
# ---------------------------------------------------------------------------
if [ -n "${BASHGITAWARE_GLYPHS:-}" ]; then
    _bga_glyphs="$BASHGITAWARE_GLYPHS"
elif [ "${BASHGITAWARE_NERD_FONT:-0}" = 1 ]; then
    _bga_glyphs=nerd
elif [ "$_bga_utf8" = 1 ]; then
    _bga_glyphs=unicode
else
    _bga_glyphs=ascii
fi
case "$_bga_glyphs" in nerd | unicode | ascii) ;; *) _bga_glyphs=ascii ;; esac

case "$_bga_glyphs" in
    nerd)    #  is the Powerline branch glyph -- present in every Nerd Font / Powerline font.
        _g_branch=$' '
        _g_dirty='●' _g_ahead='↑' _g_behind='↓' _g_stash='≡' _g_commit='↳' _g_sym='❯' _g_ell='…'
        ;;
    unicode)
        _g_branch=''
        _g_dirty='●' _g_ahead='↑' _g_behind='↓' _g_stash='≡' _g_commit='↳' _g_sym='❯' _g_ell='…'
        ;;
    ascii)
        _g_branch=''
        _g_dirty='*' _g_ahead='^' _g_behind='v' _g_stash='s' _g_commit='' _g_sym='>' _g_ell='...'
        ;;
esac
[ "$_bga_root" = 1 ] && _g_sym='#'

# ---------------------------------------------------------------------------
# Command timer (via the DEBUG trap)
# ---------------------------------------------------------------------------
_bga_timer_start=
_bga_last_duration=

__bga_timer_start() { _bga_timer_start="${_bga_timer_start:-$SECONDS}"; }
trap '__bga_timer_start' DEBUG

# ---------------------------------------------------------------------------
# Git: collect prompt info with as few subprocesses as possible
# ---------------------------------------------------------------------------
__bga_git_state() {
    # Reads $_bga_git_dir; sets $_bga_git_state. Filesystem checks only -- no subprocesses.
    _bga_git_state=
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
    _bga_git_branch= _bga_git_hash= _bga_git_dirty=0
    _bga_git_ahead=0 _bga_git_behind=0 _bga_git_stash=0
    _bga_git_msg= _bga_git_state= _bga_git_dir= _bga_git_top=

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

# ---------------------------------------------------------------------------
# Path: repo-name + path-within-repo when inside a repo; ~-relative otherwise.
# Trimmed to the last N components (the dropped prefix becomes an ellipsis).
# ---------------------------------------------------------------------------
__bga_path() {
    local max="${BASHGITAWARE_PATH_MAXDEPTH:-3}"; case "$max" in '' | *[!0-9]*) max=3 ;; esac
    local lead="" rest=""
    if [ -n "${_bga_git_top:-}" ] && case "$PWD/" in "$_bga_git_top"/*) true ;; *) false ;; esac; then
        lead="${_bga_git_top##*/}"                       # repository name
        rest="${PWD#"$_bga_git_top"}"; rest="${rest#/}"  # path within the repo
    elif case "$PWD/" in "$HOME"/*) true ;; *) false ;; esac; then
        lead="~"
        rest="${PWD#"$HOME"}"; rest="${rest#/}"
    else
        lead=""                                          # absolute path with no useful "lead"
        rest="${PWD#/}"
    fi
    [ -z "$rest" ] && { printf '%s' "${lead:-/}"; return; }

    local IFS=/ ; local -a p; read -ra p <<< "$rest"; local n=${#p[@]}
    if [ "$max" -ne 0 ] && [ "$n" -gt "$max" ]; then
        local out="" i
        for (( i = n - max ; i < n ; i++ )); do out="$out/${p[i]}"; done
        if [ -n "$lead" ]; then printf '%s/%s%s' "$lead" "$_g_ell" "$out"
        else printf '%s%s' "$_g_ell" "$out"; fi
        return
    fi
    if [ -n "$lead" ]; then printf '%s/%s' "$lead" "$rest"; else printf '/%s' "$rest"; fi
}

# ---------------------------------------------------------------------------
# Runtime / version modules -- shown only when the directory (or env) calls for it.
# Result is cached per (PWD, virtualenv, conda env) so the version commands run
# once when you cd into a project, not on every prompt.
# ---------------------------------------------------------------------------
__bga_runtime() {
    [ "${BASHGITAWARE_RUNTIME:-1}" = 0 ] && return
    local key="$PWD|${VIRTUAL_ENV:-}|${CONDA_DEFAULT_ENV:-}"
    if [ "$key" = "${_bga_rt_key:-}" ]; then printf '%s' "${_bga_rt_str:-}"; return; fi
    _bga_rt_key="$key"; _bga_rt_str=""
    local out="" v f s

    # --- Python: an active virtualenv / conda env, or a Python project marker ---
    local pyenv=""
    if [ -n "${VIRTUAL_ENV:-}" ]; then
        pyenv="${VIRTUAL_ENV##*/}"
        case "$pyenv" in
            .venv | venv | env | .env | virtualenv | .virtualenv)
                local _vp="${VIRTUAL_ENV%/*}"; pyenv="${_vp##*/}" ;;
        esac
    elif [ -n "${CONDA_DEFAULT_ENV:-}" ] && [ "${CONDA_DEFAULT_ENV}" != base ]; then
        pyenv="conda:${CONDA_DEFAULT_ENV}"
    fi
    if [ -n "$pyenv" ] || [ -e "$PWD/pyproject.toml" ] || [ -e "$PWD/setup.py" ] \
       || [ -e "$PWD/setup.cfg" ] || [ -e "$PWD/requirements.txt" ] || [ -e "$PWD/Pipfile" ] \
       || [ -e "$PWD/.python-version" ]; then
        v=""
        [ -r "$PWD/.python-version" ] && IFS= read -r v < "$PWD/.python-version" 2>/dev/null
        if [ -z "$v" ]; then
            if   command -v python3 >/dev/null 2>&1; then v="$(python3 --version 2>&1)"
            elif command -v python  >/dev/null 2>&1; then v="$(python --version 2>&1)"; fi
            v="${v#Python }"; v="${v%% *}"
        fi
        s="python"; [ -n "$v" ] && s="python $v"; [ -n "$pyenv" ] && s="$s ($pyenv)"
        out="$out ${_c_dim}via ${_R}${_c_py}${s}${_R}"
    fi

    # --- Node: a package.json in the current directory ---
    if [ -e "$PWD/package.json" ]; then
        v=""
        for f in .nvmrc .node-version; do
            [ -r "$PWD/$f" ] && { IFS= read -r v < "$PWD/$f" 2>/dev/null; v="${v#v}"; break; }
        done
        [ -z "$v" ] && command -v node >/dev/null 2>&1 && { v="$(node --version 2>/dev/null)"; v="${v#v}"; }
        s="node"; [ -n "$v" ] && s="node $v"
        out="$out ${_c_dim}via ${_R}${_c_node}${s}${_R}"
    fi

    # --- Rust: a Cargo.toml in the current directory ---
    if [ -e "$PWD/Cargo.toml" ]; then
        v=""; command -v rustc >/dev/null 2>&1 && { v="$(rustc --version 2>/dev/null)"; v="${v#rustc }"; v="${v%% *}"; }
        s="rust"; [ -n "$v" ] && s="rust $v"
        out="$out ${_c_dim}via ${_R}${_c_rust}${s}${_R}"
    fi

    # --- Go: a go.mod in the current directory ---
    if [ -e "$PWD/go.mod" ]; then
        v=""; command -v go >/dev/null 2>&1 && { v="$(go env GOVERSION 2>/dev/null)"; v="${v#go}"; }
        s="go"; [ -n "$v" ] && s="go $v"
        out="$out ${_c_dim}via ${_R}${_c_go}${s}${_R}"
    fi

    _bga_rt_str="$out"
    printf '%s' "$out"
}

# ---------------------------------------------------------------------------
# Prompt
# ---------------------------------------------------------------------------
__bga_prompt() {
    local exit_code=$?

    # Elapsed wall-clock time of the command that just finished.
    _bga_last_duration=
    if [ -n "$_bga_timer_start" ]; then
        local e=$(( SECONDS - _bga_timer_start ))
        local thr="${BASHGITAWARE_TIMER_THRESHOLD:-2}"; case "$thr" in '' | *[!0-9]*) thr=2 ;; esac
        if [ "$e" -ge "$thr" ]; then
            if   [ "$e" -ge 3600 ]; then _bga_last_duration="$(( e / 3600 ))h$(( e % 3600 / 60 ))m"
            elif [ "$e" -ge 60 ];   then _bga_last_duration="$(( e / 60 ))m$(( e % 60 ))s"
            else                         _bga_last_duration="${e}s"
            fi
        fi
    fi

    __bga_git_info

    local ps1=""

    # Optional OSC window title.
    if [ "$_bga_title" = 1 ]; then
        ps1="\[\033]0;${debian_chroot:+($debian_chroot) }\u@\h: \w\007\]"
    fi

    # --- Line 1: context ----------------------------------------------------
    [ -n "${debian_chroot:-}" ] && ps1+="${_c_tag}(${debian_chroot})${_R} "
    [ "$_bga_container" = 1 ]   && ps1+="${_c_tag}[container]${_R} "

    # user@host -- shown only when it matters, unless overridden.
    local show_host="${BASHGITAWARE_SHOW_HOST:-auto}"
    if [ "$show_host" = always ] || { [ "$show_host" != never ] && { [ "$_bga_ssh" = 1 ] || [ "$_bga_root" = 1 ]; }; }; then
        ps1+="${_c_user}\u${_R}@"
        if [ "$_bga_ssh" = 1 ]; then ps1+="${_c_host_ssh}\h${_R} "; else ps1+="${_c_host}\h${_R} "; fi
    fi

    # Path (repo-relative when inside a repo).
    local pwd_str; pwd_str="$(__bga_path)"
    ps1+="${_c_path}${pwd_str}${_R}"

    # Git: " on [glyph]branch[@hash][ STATE][ ^ahead][ vbehind][ dirty][ stashN]"
    if [ "$_bga_in_git" = 1 ]; then
        ps1+=" ${_c_dim}on ${_R}${_c_branch}${_g_branch}${_bga_git_branch}${_R}"
        if [ -n "$_bga_git_hash" ] && [ "$_bga_git_branch" != "detached@${_bga_git_hash}" ]; then
            ps1+="${_c_hash}@${_bga_git_hash}${_R}"
        fi
        [ -n "$_bga_git_state" ]                  && ps1+=" ${_c_state}${_bga_git_state}${_R}"
        [ "$_bga_git_ahead"  -gt 0 ] 2>/dev/null  && ps1+=" ${_c_ahead}${_g_ahead}${_bga_git_ahead}${_R}"
        [ "$_bga_git_behind" -gt 0 ] 2>/dev/null  && ps1+=" ${_c_behind}${_g_behind}${_bga_git_behind}${_R}"
        [ "$_bga_git_dirty"  = 1 ]                && ps1+=" ${_c_dirty}${_g_dirty}${_R}"
        [ "$_bga_git_stash"  -gt 0 ] 2>/dev/null  && ps1+=" ${_c_stash}${_g_stash}${_bga_git_stash}${_R}"
    fi

    # Runtime / version module(s), only when the directory calls for it.
    local rt; rt="$(__bga_runtime)"
    [ -n "$rt" ] && ps1+="$rt"

    # Command duration (if slow), then exit code (on failure only).
    [ -n "$_bga_last_duration" ] && ps1+=" ${_c_dim}took ${_R}${_c_timer}${_bga_last_duration}${_R}"
    if [ "$exit_code" -ne 0 ]; then
        if [ "$_bga_glyphs" = ascii ]; then ps1+=" ${_c_err}exit ${exit_code}${_R}"
        else ps1+=" ${_c_err}✘${exit_code}${_R}"; fi
    fi

    # --- Line 2: last commit subject (optional) -----------------------------
    if [ "${BASHGITAWARE_COMMIT_LINE:-1}" != 0 ] && [ "$_bga_in_git" = 1 ] && [ -n "$_bga_git_msg" ]; then
        local msg="$_bga_git_msg" w=$(( ${COLUMNS:-80} - 3 ))
        [ "$w" -lt 12 ] && w=12
        if [ "${#msg}" -gt "$w" ]; then msg="${msg:0:$(( w - ${#_g_ell} ))}${_g_ell}"; fi
        if [ -n "$_g_commit" ]; then ps1+="\n${_c_commit}${_g_commit} ${msg}${_R}"
        else                         ps1+="\n${_c_commit}commit: ${msg}${_R}"
        fi
    fi

    # --- Line 3: the prompt symbol ------------------------------------------
    if [ "$exit_code" -eq 0 ]; then ps1+="\n${_c_ok}${_g_sym}${_R} "
    else                            ps1+="\n${_c_sym_err}${_g_sym}${_R} "
    fi

    PS1="$ps1"
    _bga_timer_start=        # reset for the next command (must be the last thing here)
}
PROMPT_COMMAND=__bga_prompt

# ---------------------------------------------------------------------------
# ls / grep colors
# ---------------------------------------------------------------------------
if [ -x /usr/bin/dircolors ]; then
    if [ -r ~/.dircolors ]; then eval "$(dircolors -b ~/.dircolors)"; else eval "$(dircolors -b)"; fi
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# ---------------------------------------------------------------------------
# Aliases
# ---------------------------------------------------------------------------
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# "alert" for long-running commands: `some-long-command; alert`
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Git shortcuts
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --decorate --all'
alias gd='git diff'
alias gb='git branch'
alias gco='git checkout'
alias gst='git stash'
alias gsp='git stash pop'

# ---------------------------------------------------------------------------
# User overrides and bash completion
# ---------------------------------------------------------------------------
[ -f ~/.bash_aliases ] && . ~/.bash_aliases

if ! shopt -oq posix; then
    if   [ -f /usr/share/bash-completion/bash_completion ]; then . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then . /etc/bash_completion
    fi
fi

# ---------------------------------------------------------------------------
# PATH (edit to taste; idempotent so re-sourcing this file is safe)
# ---------------------------------------------------------------------------
case ":$PATH:" in *":$HOME/.npm-global/bin:"*) ;; *) PATH="$HOME/.npm-global/bin:$PATH" ;; esac
export PATH

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------
unset _bga_color
