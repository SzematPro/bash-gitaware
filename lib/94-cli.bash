
# ---------------------------------------------------------------------------
# bga: the command-line tool (v3, ADR-0009).
#
# Defined as a shell function, so `bga reload` and `bga theme set` can apply
# to the running shell; bin/bga runs the same code as a script (it sources
# this file with _BGA_CLI=1). Subcommands:
#
#   bga help | version
#   bga config path | list | get KEY | set KEY VALUE | unset KEY
#   bga theme list | preview [NAME] | set NAME
#   bga doctor
#   bga reload                      (shell function only)
#
# Exit status: 0 ok, 1 a check or operation failed, 2 usage error.
# ---------------------------------------------------------------------------
_bga_version='3.0.0'

__bga_cli_err() { printf 'bga: %s\n' "$*" >&2; }

__bga_cli_usage() {
    cat <<'EOF_USAGE'
usage: bga <command> [args]

  config path                 print the config file path
  config list                 print the settings in the config file
  config get KEY              print one setting
  config set KEY VALUE        validate and store a setting
  config unset KEY            remove a setting
  theme list                  list the themes
  theme preview [NAME]        show a sample prompt in a theme
  theme set NAME              store the theme in the config file
  doctor                      check the environment, exit 1 on problems
  reload                      re-source bash-gitaware (shell function only)
  version                     print the version
  help                        this text

Settings take effect in new shells, or after `bga reload`.
EOF_USAGE
}

bga() {
    local cmd="${1:-help}"
    [ "$#" -gt 0 ] && shift
    case "$cmd" in
        help | -h | --help) __bga_cli_usage ;;
        version | --version) printf 'bash-gitaware %s\n' "$_bga_version" ;;
        config)  __bga_cli_config "$@" ;;
        theme)   __bga_cli_theme "$@" ;;
        doctor)  __bga_cli_doctor "$@" ;;
        reload)
            if [ -n "${_BGA_CLI:-}" ]; then __bga_cli_err "reload only works in an interactive shell"; return 1; fi
            # shellcheck disable=SC1090  # the file this function came from
            source "$_bga_src"
            ;;
        *) __bga_cli_err "unknown command '$cmd'"; __bga_cli_usage >&2; return 2 ;;
    esac
}

# --- config ------------------------------------------------------------------

__bga_cli_cfg_path() {
    REPLY="${BASHGITAWARE_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/bash-gitaware/config}"
}

# True (and an error printed) when key $1 is locked by the policy (ADR-0011).
__bga_cli_locked() {
    case "${_bga_policy_locked:- }" in *" $1 "*) ;; *) return 1 ;; esac
    __bga_term_safe "$_bga_policy_path"
    __bga_cli_err "'$1' is set by the administrator policy ($REPLY); your config cannot change it"
}

__bga_cli_config() {
    local sub="${1:-list}" f key line k
    [ "$#" -gt 0 ] && shift
    local REPLY; __bga_cli_cfg_path; f="$REPLY"
    case "$sub" in
        path) printf '%s\n' "$f" ;;
        list)
            [ -f "$f" ] || return 0
            while IFS= read -r line || [ -n "$line" ]; do
                line="${line%$'\r'}"
                case "$line" in '' | [[:blank:]]*'#'* | '#'*) continue ;; *=*) ;; *) continue ;; esac
                k="${line%%=*}"; k="${k#"${k%%[![:blank:]]*}"}"; k="${k%"${k##*[![:blank:]]}"}"; k="${k,,}"
                __bga_term_safe "$line"
                case "${_bga_policy_locked:- }" in
                    *" $k "*) printf '%s   (ignored: locked by policy)\n' "$REPLY" ;;
                    *)        printf '%s\n' "$REPLY" ;;
                esac
            done < "$f" ;;
        get)
            [ "$#" = 1 ] || { __bga_cli_err "usage: bga config get KEY"; return 2; }
            __bga_cli_cfg_find "$f" "$1" || return 1
            __bga_term_safe "$REPLY"; printf '%s\n' "$REPLY" ;;
        set)
            [ "$#" = 2 ] || { __bga_cli_err "usage: bga config set KEY VALUE"; return 2; }
            key="${1,,}"
            __bga_config_valid "$key" "$2"
            case $? in
                0) ;;
                2) __bga_cli_err "unknown key '$key'"; return 2 ;;
                *) __bga_cli_err "invalid value for '$key': $2"; return 2 ;;
            esac
            __bga_cli_locked "$key" && return 1
            __bga_cli_cfg_write "$f" "$key" "$2" ;;
        unset)
            [ "$#" = 1 ] || { __bga_cli_err "usage: bga config unset KEY"; return 2; }
            key="${1,,}"
            __bga_cli_locked "$key" && return 1
            __bga_cli_cfg_write "$f" "$key" ;;
        *) __bga_cli_err "unknown config command '$sub'"; return 2 ;;
    esac
}

# Value of KEY in file $1 into REPLY (last occurrence wins, like the loader).
__bga_cli_cfg_find() {
    local f="$1" want="${2,,}" line k v found=1
    REPLY=''
    [ -f "$f" ] || return 1
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%$'\r'}"
        line="${line#"${line%%[![:blank:]]*}"}"
        case "$line" in '' | '#'*) continue ;; *=*) ;; *) continue ;; esac
        k="${line%%=*}"; k="${k%"${k##*[![:blank:]]}"}"
        [ "${k,,}" = "$want" ] || continue
        v="${line#*=}"; v="${v#"${v%%[![:blank:]]*}"}"; v="${v%"${v##*[![:blank:]]}"}"
        case "$v" in \"*\") v="${v#\"}"; v="${v%\"}" ;; \'*\') v="${v#\'}"; v="${v%\'}" ;; esac
        REPLY="$v" found=0
    done < "$f"
    return "$found"
}

# Rewrite file $1 with KEY $2 set to $3 (or removed when $3 is absent).
# Comments, other keys and their order are kept. The write is atomic (temp
# file in the same directory, then mv) and the file stays 0600. A symlinked
# config is not replaced: the link would silently become a regular file.
__bga_cli_cfg_write() {
    local f="$1" key="$2" dir tmp line k done_=0 set_=0 out=''
    [ "$#" = 3 ] && set_=1
    if [ -L "$f" ]; then __bga_cli_err "$f is a symlink; edit its target by hand"; return 1; fi
    if [ -e "$f" ] && [ ! -f "$f" ]; then __bga_cli_err "$f is not a regular file"; return 1; fi
    dir="${f%/*}"; [ "$dir" = "$f" ] && dir=.
    ( umask 077; mkdir -p "$dir" ) || { __bga_cli_err "cannot create $dir"; return 1; }
    # Build the new content first, then write it with one printf whose
    # status is checked: a full disk must not leave a truncated config.
    if [ -f "$f" ]; then
        while IFS= read -r line || [ -n "$line" ]; do
            k="${line%$'\r'}"; k="${k#"${k%%[![:blank:]]*}"}"
            case "$k" in
                '#'* | '') out+="$line"$'\n'; continue ;;
                *=*) k="${k%%=*}"; k="${k%"${k##*[![:blank:]]}"}" ;;
                *) out+="$line"$'\n'; continue ;;
            esac
            if [ "${k,,}" = "$key" ]; then
                if [ "$set_" = 1 ] && [ "$done_" = 0 ]; then out+="$key = $3"$'\n'; fi
                done_=1
                continue
            fi
            out+="$line"$'\n'
        done < "$f"
    fi
    if [ "$set_" = 1 ] && [ "$done_" = 0 ]; then out+="$key = $3"$'\n'; fi
    tmp="$(umask 077; mktemp "$dir/.config.XXXXXX")" || { __bga_cli_err "cannot write in $dir"; return 1; }
    if ! printf '%s' "$out" > "$tmp"; then rm -f "$tmp"; __bga_cli_err "write failed; $f unchanged"; return 1; fi
    mv -f "$tmp" "$f" || { rm -f "$tmp"; __bga_cli_err "cannot replace $f"; return 1; }
}

# --- theme -------------------------------------------------------------------

__bga_cli_theme() {
    local sub="${1:-list}" v name
    [ "$#" -gt 0 ] && shift
    case "$sub" in
        list)
            for v in $(compgen -v _bga_theme_); do
                [ "$v" = _bga_theme_tokens ] && continue
                name="${v#_bga_theme_}"
                if [ "$name" = "${BASHGITAWARE_THEME:-aware}" ]; then printf '%s (current)\n' "$name"
                else printf '%s\n' "$name"; fi
            done ;;
        preview)
            name="${1:-${BASHGITAWARE_THEME:-aware}}"
            __bga_cli_theme_known "$name" || { __bga_cli_err "unknown theme '$name'"; return 2; }
            __bga_cli_theme_preview "$name" ;;
        set)
            [ "$#" = 1 ] || { __bga_cli_err "usage: bga theme set NAME"; return 2; }
            __bga_cli_theme_known "$1" || { __bga_cli_err "unknown theme '$1'"; return 2; }
            __bga_cli_config set theme "$1" || return 1
            printf 'theme set to %s; open a new shell or run: bga reload\n' "$1" ;;
        *) __bga_cli_err "unknown theme command '$sub'"; return 2 ;;
    esac
}

__bga_cli_theme_known() {
    case "$1" in '' | *[!a-z0-9_]* | tokens) return 1 ;; esac
    local v="_bga_theme_$1"
    [ -n "${!v+set}" ]
}

# A sample Lean prompt in theme $1, printed with raw tokens. The current
# shell's colors are restored afterwards.
__bga_cli_theme_preview() {
    local cur="${BASHGITAWARE_THEME:-aware}" sep=' · ' l1 l2 l3
    __bga_theme_apply "$1"
    l1="${_cr_path}~/src/project${_Rr}  ${_cr_branch}main${_Rr} ${_cr_dirty}●${_Rr} ${_cr_ahead}↑1${_Rr}"
    l1+="        ${_cr_py}python 3.12${_Rr}${_cr_dim}${sep}14:02${_Rr}"
    l2="${_cr_ok}❯${_Rr} make test"
    l3="  ${_cr_err}✘1${_Rr}${_cr_dim}${sep}${_Rr}${_cr_timer}3s${_Rr}"
    printf '\n%s\n%s\n%s\n%s\n\n' "$l1" "$l2" "$l3" "${_cr_sym_err}❯${_Rr}"
    __bga_theme_apply "$cur"
}

# --- doctor ------------------------------------------------------------------

__bga_cli_doctor() {
    local bad=0 v REPLY f k
    __bga_doc() { printf '  %-4s %-14s %s\n' "$1" "$2" "$3"; }
    printf 'bash-gitaware %s\n' "$_bga_version"
    if [ "${BASH_VERSINFO[0]}" -gt 4 ] || { [ "${BASH_VERSINFO[0]}" = 4 ] && [ "${BASH_VERSINFO[1]}" -ge 4 ]; }; then
        __bga_doc ok bash "$BASH_VERSION"
    else
        __bga_doc FAIL bash "$BASH_VERSION (4.4 or newer required)"; bad=1
    fi
    if command -v git >/dev/null 2>&1; then
        v="$(git --version 2>/dev/null)"; v="${v#git version }"
        local maj="${v%%.*}" rest="${v#*.}"; local min="${rest%%.*}"
        case "$maj$min" in *[!0-9]*) maj=0 min=0 ;; esac
        if [ "$maj" -gt 2 ] || { [ "$maj" = 2 ] && [ "$min" -ge 11 ]; }; then __bga_doc ok git "$v"
        else __bga_doc FAIL git "$v (2.11 or newer required)"; bad=1; fi
    else
        __bga_doc FAIL git "not found"; bad=1
    fi
    __bga_doc info locale "${LC_ALL:-${LC_CTYPE:-${LANG:-unset}}} (utf8=$_bga_utf8)"
    __bga_doc info glyphs "$_bga_glyphs"
    __bga_doc info colors "depth=$_bga_depth TERM=${TERM:-unset}${COLORTERM:+ COLORTERM=$COLORTERM}"
    __bga_doc info style "${BASHGITAWARE_STYLE:-lean}, theme ${BASHGITAWARE_THEME:-aware}"
    if [ "${_bga_plain:-0}" = 1 ]; then __bga_doc info mode "plain (dumb terminal, no tty, CI or agent detected)"
    else __bga_doc info mode "full"; fi
    if [ -n "${_bga_tmo:-}" ]; then __bga_doc ok timeouts "$_bga_tmo"
    else __bga_doc ok timeouts "watchdog (no timeout(1))"; fi
    if [ -n "${_bga_state_dir:-}" ]; then __bga_doc ok state "$_bga_state_dir"
    else __bga_doc info state "none (async off or non-interactive)"; fi
    __bga_cli_cfg_path; f="$REPLY"
    if [ -e "$f" ]; then
        local msgs; msgs="$( { BASHGITAWARE_CONFIG="$f" __bga_config_load; } 2>&1 >/dev/null )"
        if [ -z "$msgs" ]; then __bga_doc ok config "$f"
        else __bga_doc FAIL config "$f"; printf '%s\n' "$msgs" | sed 's/^/         /'; bad=1; fi
    else
        __bga_doc info config "$f (not present, defaults in use)"
    fi
    # Administrator policy (ADR-0011).
    __bga_term_safe "${_bga_policy_path:-}"; v="$REPLY"
    case "${_bga_policy_state:-absent}" in
        applied)
            k="${_bga_policy_locked# }"; k="${k% }"
            if [ -n "$k" ]; then k="${k// /, }"; else k=none; fi
            __bga_doc ok policy "$v (locks: $k)"
            if [ -f "$f" ]; then
                # Split on spaces whatever the caller's IFS (shell-state rule).
                local IFS=' '
                for k in $_bga_policy_locked; do
                    __bga_cli_cfg_find "$f" "$k" && printf '         your config sets %s; the policy wins\n' "$k"
                done
            fi ;;
        refused)
            __bga_term_safe "$_bga_policy_reason"
            __bga_doc FAIL policy "$v: $REPLY; ignored"; bad=1 ;;
        *) __bga_doc info policy "none" ;;
    esac
    # Unset means on until 4.0 (ADR-0010): say so, and how to choose. Not a
    # problem, so the exit status is unchanged.
    case "${BASHGITAWARE_SHELL_DEFAULTS:-}" in
        0) __bga_doc info shell-defaults "off" ;;
        1) __bga_doc info shell-defaults "on (history, ls colors, aliases, completion)" ;;
        '') __bga_doc note shell-defaults "not set: on, as in 3.0; 4.0 turns it off when unset"
            printf '         choose with: bga config set shell_defaults 1   (or 0)\n' ;;
        *) __bga_term_safe "$BASHGITAWARE_SHELL_DEFAULTS"
           __bga_doc note shell-defaults "on: BASHGITAWARE_SHELL_DEFAULTS='$REPLY' is not 0 or 1" ;;
    esac
    return "$bad"
}
