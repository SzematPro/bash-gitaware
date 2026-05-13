
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
