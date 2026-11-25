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
#   BASHGITAWARE_RUNTIMES=py,node,...         Runtimes to show (py node rust go ruby deno bun java). Default: all.
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
# Settings files. Both use the same grammar and are parsed as data, never
# sourced:
#
#   # comment
#   preset = minimal          (keys are the BASHGITAWARE_* names, lowercase,
#   glyphs = "unicode"         without the prefix; quotes are optional)
#
# Each key has a fixed set of valid values; anything else is reported on
# stderr with its line number and ignored.
#
#   * Policy: /etc/bash-gitaware/policy, for administrators (ADR-0011). Used
#     only if it and every directory on its physical path are root-owned and
#     not writable by group, others or ACL entries. Its keys are locked: they
#     win over the environment and the user's config.
#   * User config: ${BASHGITAWARE_CONFIG:-${XDG_CONFIG_HOME:-~/.config}/bash-gitaware/config}.
#     Refused when someone else owns it or group/others can write it (a
#     symlink is fine if its target passes). Lines for locked keys are
#     skipped (bga doctor lists them).
#
# Precedence: policy > environment > user config > preset defaults.
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
        runtimes)     # Comma list of runtime names (lib/50-runtime.bash).
                      local rest="$2," x
                      [ "$2" != '' ] || return 1
                      while [ -n "$rest" ]; do
                          x="${rest%%,*}"; rest="${rest#*,}"
                          case "$x" in py | node | rust | go | ruby | deno | bun | java) ;; *) return 1 ;; esac
                      done ;;
        *) return 2 ;;
    esac
}

# __bga_config_parse <file> <label> <policy 0|1>: apply the key = value lines
# of a file already checked by the caller. Warnings say "<label>:N:".
# Policy lines are assigned even over the environment and recorded in
# _bga_policy_locked (" key key "); user lines fill only unset, unlocked keys.
__bga_config_parse() {
    local f="$1" label="$2" pol="$3" line k v n=0 var q=\'
    while IFS= read -r line || [ -n "$line" ]; do
        n=$(( n + 1 ))
        line="${line%$'\r'}"
        # Trim leading/trailing blanks.
        line="${line#"${line%%[![:blank:]]*}"}"; line="${line%"${line##*[![:blank:]]}"}"
        case "$line" in '' | '#'*) continue ;; esac
        case "$line" in *=*) ;; *) __bga_config_warn "$label:$n: expected key = value"; continue ;; esac
        k="${line%%=*}"; v="${line#*=}"
        k="${k%"${k##*[![:blank:]]}"}"; v="${v#"${v%%[![:blank:]]*}"}"
        case "$v" in \"*\") v="${v#\"}"; v="${v%\"}" ;; "$q"*"$q") v="${v#"$q"}"; v="${v%"$q"}" ;; esac
        k="${k,,}"
        __bga_config_valid "$k" "$v"
        case $? in
            0) ;;
            2) __bga_config_warn "$label:$n: unknown key '$k'"; continue ;;
            *) __bga_config_warn "$label:$n: invalid value for '$k'"; continue ;;
        esac
        var="BASHGITAWARE_${k^^}"
        if [ "$pol" = 1 ]; then
            printf -v "$var" '%s' "$v"
            _bga_policy_vars+="$var "
            case "$_bga_policy_locked" in *" $k "*) ;; *) _bga_policy_locked+="$k " ;; esac
        else
            case "$_bga_policy_locked" in *" $k "*) continue ;; esac
            # Environment wins: only fill variables that are not set yet.
            [ -n "${!var+set}" ] || printf -v "$var" '%s' "$v"
        fi
    done < "$f"
}

# __bga_policy_trusted <file>: true if the policy may be used. On failure,
# REPLY says why. Regular file, not a symlink; it and every directory on its
# physical path owned by uid 0 and not writable by group or others (one find
# over all of them: each path that passes is printed, so a find that fails
# or skips one fails closed); on macOS, no ACL entry granting write.
__bga_policy_trusted() {
    local f="$1" d x out n=0
    REPLY=''
    if [ -L "$f" ]; then REPLY='is a symlink'; return 1; fi
    if [ ! -f "$f" ]; then REPLY='is not a regular file'; return 1; fi
    if [ ! -r "$f" ]; then REPLY='is not readable (it should be mode 0644)'; return 1; fi
    d="${f%/*}"; [ -n "$d" ] || d=/
    d="$(CDPATH='' builtin cd -P -- "$d" 2>/dev/null && pwd -P)" || { REPLY='directory not accessible'; return 1; }
    local -a p=("${d%/}/${f##*/}")
    x="$d"
    while [ -n "$x" ] && [ "$x" != / ]; do p+=("$x"); x="${x%/*}"; done
    p+=(/)
    out="$(find "${p[@]}" -maxdepth 0 -user 0 ! -perm -020 ! -perm -002 -print 2>/dev/null)"
    [ -n "$out" ] && { x="${out//[!$'\n']/}"; n=$(( ${#x} + 1 )); }
    if [ "$n" != "${#p[@]}" ]; then
        REPLY='it or a parent directory is not owned by root, or is writable by group or others'
        return 1
    fi
    # POSIX ACLs (Linux) need no separate check: a named entry with write
    # access raises the mask, which shows as group write above, and a masked
    # entry grants nothing. macOS ACLs do not show in the mode bits.
    if [ "$(uname -s 2>/dev/null)" = Darwin ]; then
        # macOS lists ACL entries under each path as " N: who allow perms".
        out="$(ls -lde "${p[@]}" 2>/dev/null)"
        while [ -n "$out" ]; do
            x="${out%%$'\n'*}"
            if [ "$x" = "$out" ]; then out=''; else out="${out#*$'\n'}"; fi
            case "$x" in
                [[:blank:]]*[0-9]': '*' allow '*write* | [[:blank:]]*[0-9]': '*' allow '*append* \
                | [[:blank:]]*[0-9]': '*' allow '*add_* | [[:blank:]]*[0-9]': '*' allow '*delete_child*)
                    REPLY='an ACL entry grants write access'; return 1 ;;
            esac
        done
    fi
}

# The policy path. Only the test suite changes it, through an unexported
# _BGA_POLICY set before this file is sourced (an exported one is ignored,
# like _BGA_CLI); the trust check applies there too (ADR-0011).
__bga_policy_load() {
    _bga_policy_locked=' ' _bga_policy_state=absent _bga_policy_reason='' _bga_policy_vars=''
    _bga_policy_path=/etc/bash-gitaware/policy
    if [ -n "${_BGA_POLICY:-}" ] && [[ "${_BGA_POLICY@a}" != *x* ]]; then _bga_policy_path="$_BGA_POLICY"; fi
    [ -e "$_bga_policy_path" ] || [ -L "$_bga_policy_path" ] || return 0
    local REPLY
    if __bga_policy_trusted "$_bga_policy_path"; then
        _bga_policy_state=applied
        __bga_config_parse "$_bga_policy_path" policy 1
    else
        _bga_policy_state=refused _bga_policy_reason="$REPLY"
        __bga_config_warn "$_bga_policy_path: $REPLY; policy ignored"
    fi
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
    __bga_config_parse "$f" config 0
}
# bga reload re-sources this file. Values that bash-gitaware itself set on
# the previous load (policy, config file, presets, plain-mode defaults) are
# unset first, or they would look like environment and shadow the files; the
# user's own environment is kept. _bga_managed is filled by
# __bga_settings_mark (end of lib/10-detect.bash). ${!prefix@} lists names
# without a subshell.
__bga_settings_reset() {
    local rest="${_bga_managed:-}" v
    while [ -n "$rest" ]; do
        v="${rest%% *}"; rest="${rest#"$v"}"; rest="${rest# }"
        [ -n "$v" ] && unset "$v"
    done
    _bga_managed='' _bga_env_vars=' '
    for v in "${!BASHGITAWARE_@}"; do _bga_env_vars+="$v "; done
}
__bga_settings_mark() {
    local v
    _bga_managed=''
    for v in "${!BASHGITAWARE_@}"; do
        case "$_bga_env_vars" in *" $v "*) ;; *) _bga_managed+="$v " ;; esac
    done
    # Policy values replace the environment's: always ours to reset.
    local rest="${_bga_policy_vars:-}"
    while [ -n "$rest" ]; do
        v="${rest%% *}"; rest="${rest#"$v"}"; rest="${rest# }"
        case " $_bga_managed" in *" $v "*) ;; *) [ -n "$v" ] && _bga_managed+="$v " ;; esac
    done
}
__bga_settings_reset
__bga_policy_load
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
