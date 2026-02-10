# ~/.bashrc: executed by bash(1) for non-login shells.
# Modern, colorful, Git-aware configuration
# Author: Waldemar Szemat <waldemar@szemat.pro>

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# ============================================================================
# HISTORY CONFIGURATION
# ============================================================================
# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=10000
HISTFILESIZE=20000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# ============================================================================
# ENVIRONMENT DETECTION
# ============================================================================
# SSH detection (run once at shell startup)
if [ -n "$SSH_CONNECTION" ] || [ -n "$SSH_TTY" ] || [ -n "$SSH_CLIENT" ]; then
    _is_ssh=1
else
    _is_ssh=0
fi

# Container detection (run once at shell startup)
if [ -f /.dockerenv ] || [ -f /run/.containerenv ] || grep -qsm1 'docker\|lxc\|containerd' /proc/1/cgroup 2>/dev/null; then
    _is_container=1
else
    _is_container=0
fi

# UTF-8 support detection
case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
    *[Uu][Tt][Ff]-8*|*[Uu][Tt][Ff]8*) _utf8=1 ;;
    *) _utf8=0 ;;
esac

# Terminal title support
case "$TERM" in
    xterm*|rxvt*|screen*|tmux*) _set_title=1 ;;
    *) _set_title=0 ;;
esac

# ============================================================================
# COLOR DETECTION
# ============================================================================
# Respect NO_COLOR standard (https://no-color.org/)
if [ "${NO_COLOR+set}" = set ]; then
    color_prompt=
else
    # set a fancy prompt (non-color, unless we know we "want" color)
    case "$TERM" in
        xterm-color|*-256color) color_prompt=yes;;
    esac
fi

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ] && [ "${NO_COLOR+set}" != set ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

# ============================================================================
# COLOR DEFINITIONS
# ============================================================================
# Modern color palette with 256-color support
if [ "$color_prompt" = yes ] || { [ "${NO_COLOR+set}" != set ] && [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; }; then
    # We have color support
    color_prompt=yes

    # Basic colors
    RESET='\[\033[0m\]'
    BOLD='\[\033[1m\]'

    # Standard colors
    BLACK='\[\033[0;30m\]'
    RED='\[\033[0;31m\]'
    GREEN='\[\033[0;32m\]'
    YELLOW='\[\033[0;33m\]'
    BLUE='\[\033[0;34m\]'
    MAGENTA='\[\033[0;35m\]'
    CYAN='\[\033[0;36m\]'
    WHITE='\[\033[0;37m\]'

    # Bright colors
    BRIGHT_BLACK='\[\033[0;90m\]'
    BRIGHT_RED='\[\033[0;91m\]'
    BRIGHT_GREEN='\[\033[0;92m\]'
    BRIGHT_YELLOW='\[\033[0;93m\]'
    BRIGHT_BLUE='\[\033[0;94m\]'
    BRIGHT_MAGENTA='\[\033[0;95m\]'
    BRIGHT_CYAN='\[\033[0;96m\]'
    BRIGHT_WHITE='\[\033[0;97m\]'

    # Semantic prompt color mappings
    PROMPT_USER="${BRIGHT_CYAN}"
    PROMPT_HOST="${BRIGHT_YELLOW}"
    PROMPT_PATH="${BRIGHT_BLUE}"
    PROMPT_GIT_BRANCH="${BRIGHT_GREEN}"
    PROMPT_GIT_DIRTY="${BRIGHT_RED}"
    PROMPT_GIT_CLEAN="${BRIGHT_GREEN}"
    PROMPT_GIT_AHEAD="${BRIGHT_YELLOW}"
    PROMPT_GIT_BEHIND="${BRIGHT_MAGENTA}"
    PROMPT_GIT_COMMIT="${BRIGHT_CYAN}"
    PROMPT_GIT_MESSAGE="${BRIGHT_WHITE}"
    PROMPT_GIT_STASH="${BRIGHT_CYAN}"
    PROMPT_GIT_STATE="${BRIGHT_RED}"
    PROMPT_MESSAGE_BOX="${BRIGHT_BLACK}"
    PROMPT_SUCCESS="${BRIGHT_GREEN}"
    PROMPT_ERROR="${BRIGHT_RED}"
    PROMPT_SYMBOL="${BRIGHT_WHITE}"
    PROMPT_VENV="${BRIGHT_MAGENTA}"
    PROMPT_TIMER="${BRIGHT_YELLOW}"
    PROMPT_SSH_HOST="${BRIGHT_YELLOW}"
    PROMPT_CONTAINER="${BRIGHT_YELLOW}"
else
    color_prompt=
    RESET=''
    BOLD=''
    BRIGHT_BLACK=''
    BRIGHT_CYAN=''
    BRIGHT_YELLOW=''
    BRIGHT_MAGENTA=''
    PROMPT_USER=''
    PROMPT_HOST=''
    PROMPT_PATH=''
    PROMPT_GIT_BRANCH=''
    PROMPT_GIT_DIRTY=''
    PROMPT_GIT_CLEAN=''
    PROMPT_GIT_AHEAD=''
    PROMPT_GIT_BEHIND=''
    PROMPT_GIT_COMMIT=''
    PROMPT_GIT_MESSAGE=''
    PROMPT_GIT_STASH=''
    PROMPT_GIT_STATE=''
    PROMPT_MESSAGE_BOX=''
    PROMPT_SUCCESS=''
    PROMPT_ERROR=''
    PROMPT_SYMBOL=''
    PROMPT_VENV=''
    PROMPT_TIMER=''
    PROMPT_SSH_HOST=''
    PROMPT_CONTAINER=''
fi

# ============================================================================
# SYMBOL DEFINITIONS
# ============================================================================
# Unicode symbols with ASCII fallback for non-UTF-8 terminals
if [ "$_utf8" = 1 ]; then
    SYM_CLEAN="✓"
    SYM_DIRTY="✗"
    SYM_AHEAD="↑"
    SYM_BEHIND="↓"
    SYM_STASH="⚑"
else
    SYM_CLEAN="OK"
    SYM_DIRTY="*"
    SYM_AHEAD="^"
    SYM_BEHIND="v"
    SYM_STASH="S"
fi

# ============================================================================
# COMMAND TIMER
# ============================================================================
# Track command execution time using DEBUG trap
_timer_start=
_last_duration=

__timer_start() {
    _timer_start=${_timer_start:-$SECONDS}
}
trap '__timer_start' DEBUG

# ============================================================================
# GIT FUNCTIONS FOR PROMPT
# ============================================================================
# Detect rebase/merge/cherry-pick/bisect/revert state (filesystem checks only)
__detect_git_state() {
    _git_state=
    if [ -d "${_git_dir}/rebase-merge" ]; then
        local step total
        step=$(<"${_git_dir}/rebase-merge/msgnum")
        total=$(<"${_git_dir}/rebase-merge/end")
        _git_state="REBASE ${step}/${total}"
    elif [ -d "${_git_dir}/rebase-apply" ]; then
        local step total
        step=$(<"${_git_dir}/rebase-apply/next")
        total=$(<"${_git_dir}/rebase-apply/last")
        if [ -f "${_git_dir}/rebase-apply/rebasing" ]; then
            _git_state="REBASE ${step}/${total}"
        else
            _git_state="AM ${step}/${total}"
        fi
    elif [ -f "${_git_dir}/MERGE_HEAD" ]; then
        _git_state="MERGING"
    elif [ -f "${_git_dir}/CHERRY_PICK_HEAD" ]; then
        _git_state="CHERRY-PICK"
    elif [ -f "${_git_dir}/REVERT_HEAD" ]; then
        _git_state="REVERTING"
    elif [ -f "${_git_dir}/BISECT_LOG" ]; then
        _git_state="BISECTING"
    fi
}

# Consolidated git info: branch, hash, dirty, ahead/behind, stash, commit msg
# Uses git status --porcelain=v2 --branch (single subprocess for most info)
__git_prompt_info() {
    _git_branch=
    _git_hash=
    _git_dirty=0
    _git_ahead=0
    _git_behind=0
    _git_stash=0
    _git_commit_msg=
    _git_state=
    _git_dir=
    _in_git_repo=0

    # Get git directory (fast check + needed for state detection)
    _git_dir="$(git rev-parse --git-dir 2>/dev/null)" || return
    _in_git_repo=1

    # Call 1: git status --porcelain=v2 --branch
    # Provides: branch name, commit hash, ahead/behind, dirty status
    local line
    while IFS= read -r line; do
        case "$line" in
            '# branch.head '*)
                _git_branch="${line#\# branch.head }"
                ;;
            '# branch.oid '*)
                _git_hash="${line#\# branch.oid }"
                case "$_git_hash" in
                    '('*) _git_hash= ;;  # (initial) - no commits yet
                    *) _git_hash="${_git_hash:0:7}" ;;
                esac
                ;;
            '# branch.ab '*)
                # Format: "# branch.ab +N -M"
                _git_ahead="${line#\# branch.ab +}"
                _git_behind="${_git_ahead##*-}"
                _git_ahead="${_git_ahead%% -*}"
                ;;
            '#'*) ;;  # skip other headers (e.g. # branch.upstream)
            ?*)  # any non-empty, non-header line = dirty file
                _git_dirty=1
                break  # no need to parse remaining files
                ;;
        esac
    done < <(git status --porcelain=v2 --branch 2>/dev/null)

    # Handle detached HEAD
    if [ "$_git_branch" = "(detached)" ]; then
        _git_branch="detached:${_git_hash}"
    fi

    # Call 2: commit message (only if we have commits)
    if [ -n "$_git_hash" ]; then
        _git_commit_msg="$(git log -1 --pretty=format:'%s' 2>/dev/null)"
    fi

    # Call 3 (conditional): stash count
    if [ -f "${_git_dir}/refs/stash" ]; then
        _git_stash=$(git stash list 2>/dev/null | wc -l)
        _git_stash=$(( _git_stash ))
    fi

    # Detect git state (filesystem checks only, no subprocesses)
    __detect_git_state
}

# ============================================================================
# MODERN PROMPT
# ============================================================================
# Build the prompt dynamically each command
__prompt_command() {
    local exit_code=$?

    # Capture elapsed time before any other work
    _last_duration=
    if [ -n "$_timer_start" ]; then
        local _elapsed=$(( SECONDS - _timer_start ))
        if [ $_elapsed -ge 2 ]; then
            if [ $_elapsed -ge 3600 ]; then
                _last_duration="$((_elapsed / 3600))h$((_elapsed % 3600 / 60))m"
            elif [ $_elapsed -ge 60 ]; then
                _last_duration="$((_elapsed / 60))m$((_elapsed % 60))s"
            else
                _last_duration="${_elapsed}s"
            fi
        fi
    fi

    # Gather git info (2-3 subprocesses vs previous 7)
    __git_prompt_info

    # Initialize PS1 (with terminal title if supported)
    if [ "$_set_title" = 1 ]; then
        PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]"
    else
        PS1=""
    fi

    # === Commit message box ===
    if [ "$_in_git_repo" = 1 ] && [ -n "$_git_commit_msg" ]; then
        local term_width=${COLUMNS:-80}

        if [ "$term_width" -ge 30 ]; then
            local msg="$_git_commit_msg"
            local max_msg_width=$((term_width - 4))

            # Get display width (locale-aware via wc -L, fallback to char length)
            local msg_display_width
            msg_display_width=$(printf '%s' "$msg" | wc -L 2>/dev/null) || msg_display_width=0
            msg_display_width=$(( msg_display_width ))
            [ "$msg_display_width" -eq 0 ] && [ -n "$msg" ] && msg_display_width=${#msg}

            # Truncate if message exceeds available width
            if [ "$msg_display_width" -gt "$max_msg_width" ]; then
                msg="${msg:0:$((max_msg_width - 3))}..."
                msg_display_width=$max_msg_width
            fi

            # Top border: +- Commit ---...---+
            local label=" Commit"
            local top_used=$((2 + ${#label}))
            local top_remaining=$((term_width - top_used - 1))
            local fill
            PS1+="${PROMPT_MESSAGE_BOX}+-${RESET}"
            PS1+="${PROMPT_GIT_COMMIT}${label}${RESET}"
            PS1+="${PROMPT_MESSAGE_BOX}"
            if [ "$top_remaining" -gt 0 ]; then
                printf -v fill '%*s' "$top_remaining" ''
                PS1+="${fill// /-}"
            fi
            PS1+="+${RESET}\n"

            # Message line: | message       |
            PS1+="${PROMPT_MESSAGE_BOX}|${RESET} "
            PS1+="${PROMPT_GIT_MESSAGE}${msg}${RESET}"
            local msg_remaining=$((term_width - msg_display_width - 3))
            if [ "$msg_remaining" -gt 0 ]; then
                printf -v fill '%*s' "$msg_remaining" ''
                PS1+="$fill"
            fi
            PS1+="${PROMPT_MESSAGE_BOX}|${RESET}\n"

            # Bottom border: +---...---+
            printf -v fill '%*s' "$((term_width - 2))" ''
            PS1+="${PROMPT_MESSAGE_BOX}+${fill// /-}+${RESET}\n"
        else
            # Narrow terminal: show inline
            PS1+="${PROMPT_GIT_COMMIT}Commit: ${PROMPT_GIT_MESSAGE}${_git_commit_msg}${RESET}\n"
        fi
    fi

    # === Virtual environment indicators ===
    local venv_info=""
    if [ -n "$VIRTUAL_ENV" ]; then
        venv_info+="(${VIRTUAL_ENV##*/}) "
    fi
    if [ -n "$CONDA_DEFAULT_ENV" ] && [ "$CONDA_DEFAULT_ENV" != "base" ]; then
        venv_info+="(conda:${CONDA_DEFAULT_ENV}) "
    fi
    if [ -n "$NVM_BIN" ]; then
        local node_ver="${NVM_BIN%/bin}"
        node_ver="${node_ver##*/}"
        venv_info+="(node:${node_ver}) "
    fi
    [ -n "$venv_info" ] && PS1+="${PROMPT_VENV}${venv_info}${RESET}"

    # === Debian chroot indicator ===
    [ -n "${debian_chroot:-}" ] && PS1+="${BRIGHT_BLACK}(${debian_chroot})${RESET} "

    # === Container indicator ===
    [ "$_is_container" = 1 ] && PS1+="${PROMPT_CONTAINER}[container]${RESET} "

    # === User@Host (SSH: bold yellow hostname) ===
    if [ "$_is_ssh" = 1 ]; then
        PS1+="${PROMPT_USER}\u${RESET}@${BOLD}${PROMPT_SSH_HOST}\h${RESET}"
    else
        PS1+="${PROMPT_USER}\u${RESET}@${PROMPT_HOST}\h${RESET}"
    fi

    # === Current directory ===
    PS1+=":${PROMPT_PATH}\w${RESET}"

    # === Git information: [branch:hash|STATE] status ahead behind stash ===
    if [ "$_in_git_repo" = 1 ]; then
        PS1+=" ${PROMPT_GIT_BRANCH}["
        PS1+="${_git_branch}"
        if [ -n "$_git_hash" ] && [ "$_git_branch" != "detached:${_git_hash}" ]; then
            PS1+=":${PROMPT_GIT_COMMIT}${_git_hash}${PROMPT_GIT_BRANCH}"
        fi
        if [ -n "$_git_state" ]; then
            PS1+="|${PROMPT_GIT_STATE}${_git_state}${PROMPT_GIT_BRANCH}"
        fi
        PS1+="]${RESET}"

        # Dirty/clean indicator
        if [ "$_git_dirty" = 1 ]; then
            PS1+=" ${PROMPT_GIT_DIRTY}${SYM_DIRTY}${RESET}"
        else
            PS1+=" ${PROMPT_GIT_CLEAN}${SYM_CLEAN}${RESET}"
        fi

        # Ahead/behind indicators
        [ "$_git_ahead" -gt 0 ] 2>/dev/null && PS1+=" ${PROMPT_GIT_AHEAD}${SYM_AHEAD}${_git_ahead}${RESET}"
        [ "$_git_behind" -gt 0 ] 2>/dev/null && PS1+=" ${PROMPT_GIT_BEHIND}${SYM_BEHIND}${_git_behind}${RESET}"

        # Stash indicator
        [ "$_git_stash" -gt 0 ] 2>/dev/null && PS1+=" ${PROMPT_GIT_STASH}${SYM_STASH}${_git_stash}${RESET}"
    fi

    # === Exit code (only on failure) ===
    [ $exit_code -ne 0 ] && PS1+=" ${PROMPT_ERROR}[X ${exit_code}]${RESET}"

    # === Command duration (only if >= 2 seconds) ===
    [ -n "$_last_duration" ] && PS1+=" ${PROMPT_TIMER}(${_last_duration})${RESET}"

    # === Prompt symbol (green=success, red=failure) ===
    if [ $exit_code -eq 0 ]; then
        PS1+="\n${PROMPT_SUCCESS}>${RESET} "
    else
        PS1+="\n${PROMPT_ERROR}>${RESET} "
    fi

    # Reset timer for next command (must be last to avoid DEBUG trap interference)
    _timer_start=
}

# Set prompt command
PROMPT_COMMAND=__prompt_command

# ============================================================================
# COLOR SUPPORT FOR COMMANDS
# ============================================================================
# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# ============================================================================
# ALIASES
# ============================================================================
# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Git aliases for convenience
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

# ============================================================================
# BASH COMPLETION
# ============================================================================
# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# ============================================================================
# PATH CONFIGURATION (edit as needed)
# ============================================================================
export PATH=~/.npm-global/bin:$PATH

# ============================================================================
# CLEANUP
# ============================================================================
unset color_prompt force_color_prompt
