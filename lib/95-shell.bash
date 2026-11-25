
# bin/bga (_BGA_CLI=1) stops here: shell defaults, aliases and completion are
# for interactive shells only.
if [ -n "${_BGA_CLI:-}" ]; then return 0; fi

# The prompt itself needs these, whatever shell_defaults says: checkwinsize
# keeps COLUMNS current for the right-aligned block (bash 4.4 does not enable
# it by default), and the chroot name is shown as a tag on line 1.
shopt -s checkwinsize
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot="$(cat /etc/debian_chroot)"
fi

# ---------------------------------------------------------------------------
# Shell defaults (shell_defaults = 1): the settings a stock Debian/Ubuntu
# ~/.bashrc has, plus git aliases. Unset means on, so a 3.0 install updated
# with `git pull` keeps them; the 3.1 installer always writes the key
# (ADR-0010). An `if` block and not a function: bash-completion must be
# sourced at top level, or its declarations would become function locals.
# bash-gitaware never changes PATH.
# ---------------------------------------------------------------------------
if [ "${BASHGITAWARE_SHELL_DEFAULTS:-1}" = 1 ]; then
    HISTCONTROL=ignoreboth
    HISTSIZE=10000
    HISTFILESIZE=20000
    shopt -s histappend

    [ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

    # ls / grep colors
    if [ -x /usr/bin/dircolors ]; then
        if [ -r ~/.dircolors ]; then eval "$(dircolors -b ~/.dircolors)"; else eval "$(dircolors -b)"; fi
        alias ls='ls --color=auto'
        alias grep='grep --color=auto'
        alias fgrep='fgrep --color=auto'
        alias egrep='egrep --color=auto'
    fi

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

    # User overrides and bash completion
    # shellcheck source=/dev/null
    [ -f ~/.bash_aliases ] && . ~/.bash_aliases

    # shellcheck source=/dev/null
    if ! shopt -oq posix; then
        if   [ -f /usr/share/bash-completion/bash_completion ]; then . /usr/share/bash-completion/bash_completion
        elif [ -f /etc/bash_completion ]; then . /etc/bash_completion
        fi
    fi
fi

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------
unset _bga_color
