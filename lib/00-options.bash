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
#   BASHGITAWARE_SHELL_DEFAULTS=0|1          History settings, ls/grep colors, aliases, completion.
#                                           Unset = on (3.0 behavior); the installer writes it (ADR-0010).
#   NO_COLOR                                 If set (any value), disable all color. https://no-color.org

# Where this file lives (bga reload re-sources it).
_bga_src="${BASH_SOURCE[0]}"

# If not running interactively, do nothing -- except for bin/bga, which sets
# _BGA_CLI=1 to load the CLI and the settings it reports on.
case $- in
    *i*) ;;
      # Only a plain (unexported) _BGA_CLI counts: an exported one would
      # change every non-interactive script that sources this file.
      *) { [ -n "${_BGA_CLI:-}" ] && [[ "${_BGA_CLI@a}" != *x* ]]; } || return ;;
esac

# ---------------------------------------------------------------------------
# Config file: ${BASHGITAWARE_CONFIG:-${XDG_CONFIG_HOME:-~/.config}/bash-gitaware/config}
#
#   # comment
#   preset = minimal          (keys are the BASHGITAWARE_* names, lowercase,
#   glyphs = "unicode"         without the prefix; quotes are optional)
#
# The file is parsed as data and never sourced. Each key has a fixed set of
# valid values; anything else is reported on stderr with its line number and
# ignored. Precedence: environment > config file > preset defaults. The file is
# refused when someone else owns it or group/others can write it (a symlink is
# fine if its target passes).
# ---------------------------------------------------------------------------
# Warnings echo keys and paths from the file: strip control characters so a
# hostile config cannot send escape sequences to the terminal.
__bga_config_warn() { local m="$*"; printf 'bash-gitaware: %s\n' "${m//[[:cntrl:]]/?}" >&2; }

# Valid values per key, as a case pattern. Echoes nothing; returns 1 if invalid.
__bga_config_valid() {
    case "$1" in
        preset)       case "$2" in minimal | default | powerline | full) ;; *) return 1 ;; esac ;;
        glyphs)       case "$2" in nerd | unicode | ascii) ;; *) return 1 ;; esac ;;
        show_host)    case "$2" in auto | always | never) ;; *) return 1 ;; esac ;;
        mode)         case "$2" in auto | plain | full) ;; *) return 1 ;; esac ;;
        theme)        case "$2" in '' | *[!a-z0-9_]*) return 1 ;; esac ;;
        style)        case "$2" in lean | classic) ;; *) return 1 ;; esac ;;
        nerd_font | async | osc | transient | commit_line | runtime | trust_repo_config | clock | powerline \
        | shell_defaults)
                      case "$2" in 0 | 1) ;; *) return 1 ;; esac ;;
        timer_threshold | path_maxdepth)
                      case "$2" in '' | *[!0-9]*) return 1 ;; esac ;;
        *) return 2 ;;
    esac
}

__bga_config_load() {
    local f="${BASHGITAWARE_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/bash-gitaware/config}"
    [ -e "$f" ] || return 0
    if [ ! -f "$f" ] || [ ! -r "$f" ]; then
        __bga_config_warn "$f: not a readable file, ignored"; return 0
    fi
    # The directory matters too: if others can write it they can swap the
    # file between this check and the read.
    # The file: ours, and nobody else may write it. Its directory: nobody
    # else may write it either, unless it is sticky (like /tmp), where other
    # users cannot replace a file they do not own -- but they can plant a
    # symlink there, so a symlinked config in such a directory is refused.
    if [ ! -O "$f" ] || [ -n "$(find -L "$f" -maxdepth 0 \( -perm -020 -o -perm -002 \) 2>/dev/null)" ] \
       || [ -n "$(find -L "${f%/*}" -maxdepth 0 \( -perm -020 -o -perm -002 \) ! -perm -1000 2>/dev/null)" ] \
       || { [ -L "$f" ] && [ -n "$(find -L "${f%/*}" -maxdepth 0 \( -perm -020 -o -perm -002 \) 2>/dev/null)" ]; }; then
        __bga_config_warn "$f: owned or writable by other users, ignored"; return 0
    fi
    local line k v n=0 var q=\'
    while IFS= read -r line || [ -n "$line" ]; do
        n=$(( n + 1 ))
        line="${line%$'\r'}"
        # Trim leading/trailing blanks.
        line="${line#"${line%%[![:blank:]]*}"}"; line="${line%"${line##*[![:blank:]]}"}"
        case "$line" in '' | '#'*) continue ;; esac
        case "$line" in *=*) ;; *) __bga_config_warn "config:$n: expected key = value"; continue ;; esac
        k="${line%%=*}"; v="${line#*=}"
        k="${k%"${k##*[![:blank:]]}"}"; v="${v#"${v%%[![:blank:]]*}"}"
        case "$v" in \"*\") v="${v#\"}"; v="${v%\"}" ;; "$q"*"$q") v="${v#"$q"}"; v="${v%"$q"}" ;; esac
        k="${k,,}"
        __bga_config_valid "$k" "$v"
        case $? in
            0) ;;
            2) __bga_config_warn "config:$n: unknown key '$k'"; continue ;;
            *) __bga_config_warn "config:$n: invalid value for '$k'"; continue ;;
        esac
        var="BASHGITAWARE_${k^^}"
        # Environment wins: only fill variables that are not set yet.
        [ -n "${!var+set}" ] || printf -v "$var" '%s' "$v"
    done < "$f"
}
__bga_config_load

# ---------------------------------------------------------------------------
# Presets -- BASHGITAWARE_PRESET sets a set of defaults; individual
# BASHGITAWARE_* variables still override anything a preset sets. Use the
# ':=' parameter expansion so an explicit user value wins.
#
#   minimal   -- ascii glyphs, no last-commit line, no runtime modules.
#   default   -- current behaviour (no extra defaults).
#   powerline -- Nerd Font glyphs on by default (works without Nerd glyphs
#                falling back via the standard tier).
#   full      -- last-commit line on, runtime modules on, user@host always.
#
# Presets affect *defaults only*; setting BASHGITAWARE_GLYPHS=ascii after
# choosing the 'powerline' preset still wins.
# ---------------------------------------------------------------------------
case "${BASHGITAWARE_PRESET:-default}" in
    minimal)
        : "${BASHGITAWARE_COMMIT_LINE:=0}"
        : "${BASHGITAWARE_RUNTIME:=0}"
        : "${BASHGITAWARE_GLYPHS:=ascii}"
        ;;
    default)
        : ;;
    powerline)
        : "${BASHGITAWARE_NERD_FONT:=1}"
        ;;
    full)
        : "${BASHGITAWARE_COMMIT_LINE:=1}"
        : "${BASHGITAWARE_RUNTIME:=1}"
        : "${BASHGITAWARE_SHOW_HOST:=always}"
        ;;
    *)
        : ;;
esac
