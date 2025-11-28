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
# COLOR DETECTION
# ============================================================================
# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
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
if [ "$color_prompt" = yes ] || ([ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null); then
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
    
    # Modern color scheme
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
    PROMPT_MESSAGE_BOX="${BRIGHT_BLACK}"
    PROMPT_SUCCESS="${BRIGHT_GREEN}"
    PROMPT_ERROR="${BRIGHT_RED}"
    PROMPT_SYMBOL="${BRIGHT_WHITE}"
else
    color_prompt=
    RESET=''
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
    PROMPT_MESSAGE_BOX=''
    PROMPT_SUCCESS=''
    PROMPT_ERROR=''
    PROMPT_SYMBOL=''
fi

# ============================================================================
# GIT FUNCTIONS FOR PROMPT
# ============================================================================
# Get current git branch name
parse_git_branch() {
    git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/'
}

# Get git status information
parse_git_status() {
    local git_status="$(git status --porcelain 2> /dev/null)"
    local git_branch="$(parse_git_branch)"
    
    if [ -z "$git_branch" ]; then
        return
    fi
    
    local status=""
    local ahead_behind=""
    
    # Check if working directory is dirty
    if [ -n "$git_status" ]; then
        status="${PROMPT_GIT_DIRTY}*${RESET}"
    else
        status="${PROMPT_GIT_CLEAN}OK${RESET}"
    fi
    
    # Check if branch is ahead/behind remote
    local remote_info="$(git rev-list --left-right --count @{upstream}...HEAD 2>/dev/null)"
    if [ -n "$remote_info" ]; then
        local ahead=$(echo $remote_info | awk '{print $2}')
        local behind=$(echo $remote_info | awk '{print $1}')
        
        if [ "$ahead" -gt 0 ] && [ "$behind" -gt 0 ]; then
            ahead_behind="${PROMPT_GIT_AHEAD}^${ahead}${RESET} ${PROMPT_GIT_BEHIND}v${behind}${RESET}"
        elif [ "$ahead" -gt 0 ]; then
            ahead_behind="${PROMPT_GIT_AHEAD}^${ahead}${RESET}"
        elif [ "$behind" -gt 0 ]; then
            ahead_behind="${PROMPT_GIT_BEHIND}v${behind}${RESET}"
        fi
    fi
    
    # Get short commit hash (first 7 characters)
    local commit_hash="$(git rev-parse --short HEAD 2>/dev/null)"
    
    # Format: [branch:commit] status [ahead/behind]
    echo -n "${PROMPT_GIT_BRANCH}[${git_branch}"
    if [ -n "$commit_hash" ]; then
        echo -n ":${PROMPT_GIT_COMMIT}${commit_hash}${RESET}"
    fi
    echo -n "${PROMPT_GIT_BRANCH}]${RESET}"
    
    # Add status and ahead/behind
    echo -n " ${status}"
    if [ -n "$ahead_behind" ]; then
        echo -n " ${ahead_behind}"
    fi
}

# Get commit message for display on separate line
get_git_commit_message() {
    local commit_hash="$(git rev-parse --short HEAD 2>/dev/null)"
    
    if [ -z "$commit_hash" ]; then
        return
    fi
    
    # Get commit message (first line only)
    local commit_message="$(git log -1 --pretty=format:'%s' 2>/dev/null)"
    
    if [ -n "$commit_message" ]; then
        echo "$commit_message"
    fi
}

# ============================================================================
# MODERN PROMPT
# ============================================================================
# Build the prompt with exit code indicator
__prompt_command() {
    local exit_code=$?
    
    # Start building prompt
    PS1=""
    
    # Get git commit message if in a git repo
    local git_message="$(get_git_commit_message)"
    
    # If we have a commit message, display it on its own decorated line
    if [ -n "$git_message" ]; then
        # Calculate terminal width (default to 80 if not available)
        local term_width=${COLUMNS:-80}
        
        # Create a decorative box around the commit message (using ASCII characters)
        # Top border
        PS1+="${PROMPT_MESSAGE_BOX}+-${RESET}"
        PS1+="${PROMPT_GIT_COMMIT} Commit${RESET}"
        PS1+="${PROMPT_MESSAGE_BOX}${RESET}"
        
        # Fill remaining width with dashes
        local used_width=9  # "+- Commit" = 9 chars
        local remaining=$((term_width - used_width - 1))
        if [ $remaining -gt 0 ]; then
            PS1+="$(printf '%*s' $remaining '' | tr ' ' '-')"
        fi
        PS1+="${PROMPT_MESSAGE_BOX}+${RESET}\n"
        
        # Commit message line with side borders
        PS1+="${PROMPT_MESSAGE_BOX}|${RESET} "
        PS1+="${PROMPT_GIT_MESSAGE}${git_message}${RESET}"
        
        # Fill remaining width with spaces
        local msg_length=${#git_message}
        local used_width=$((msg_length + 3))  # "| " + message + " "
        local remaining=$((term_width - used_width - 1))
        if [ $remaining -gt 0 ]; then
            PS1+="$(printf '%*s' $remaining '')"
        fi
        PS1+=" ${PROMPT_MESSAGE_BOX}|${RESET}\n"
        
        # Bottom border
        PS1+="${PROMPT_MESSAGE_BOX}+${RESET}"
        PS1+="$(printf '%*s' $((term_width - 1)) '' | tr ' ' '-')"
        PS1+="${PROMPT_MESSAGE_BOX}+${RESET}\n"
    fi
    
    # Debian chroot indicator
    if [ -n "${debian_chroot:-}" ]; then
        PS1+="${BRIGHT_BLACK}(${debian_chroot})${RESET} "
    fi
    
    # User@Host
    PS1+="${PROMPT_USER}\u${RESET}@${PROMPT_HOST}\h${RESET}"
    
    # Current directory
    PS1+=":${PROMPT_PATH}\w${RESET}"
    
    # Git information
    local git_info="$(parse_git_status)"
    if [ -n "$git_info" ]; then
        PS1+=" ${git_info}"
    fi
    
    # Exit code indicator (only show if command failed)
    if [ $exit_code -ne 0 ]; then
        PS1+=" ${PROMPT_ERROR}[X ${exit_code}]${RESET}"
    fi
    
    # Prompt symbol with color based on exit code
    if [ $exit_code -eq 0 ]; then
        PS1+="\n${PROMPT_SUCCESS}>${RESET} "
    else
        PS1+="\n${PROMPT_ERROR}>${RESET} "
    fi
}

# Set prompt command
PROMPT_COMMAND=__prompt_command

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*|screen*|tmux*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

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
