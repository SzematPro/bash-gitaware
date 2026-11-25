
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
# Color capability (consumed by 20-palette)
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

# Color depth for themes (lib/19-theme.bash): 24 (COLORTERM says so), 256, 16,
# or 0 (no color, NO_COLOR included).
_bga_depth=0
if [ "$_bga_color" = 1 ]; then
    case "${COLORTERM:-}" in
        truecolor | 24bit) _bga_depth=24 ;;
        *)
            case "${TERM:-}" in
                *-256color | *-direct | alacritty* | foot* | wezterm* | kitty* | *ghostty*) _bga_depth=256 ;;
                *) _bga_depth=16 ;;
            esac ;;
    esac
fi

# ---------------------------------------------------------------------------
# Plain mode: a one-line ASCII prompt with no escape sequences, for dumb
# terminals, CI logs and automated agents. Generic signals only:
# TERM=dumb, no terminal on stdin/stderr, CI, AGENT, AI_AGENT.
# BASHGITAWARE_MODE=plain forces it, BASHGITAWARE_MODE=full disables it.
# ---------------------------------------------------------------------------
case "${BASHGITAWARE_MODE:-auto}" in
    plain) _bga_plain=1 ;;
    full)  _bga_plain=0 ;;
    *)
        if [ "${TERM:-dumb}" = dumb ] || [ ! -t 0 ] || [ ! -t 2 ] \
           || [ -n "${CI:-}" ] || [ -n "${AGENT:-}" ] || [ -n "${AI_AGENT:-}" ]; then
            _bga_plain=1
        else
            _bga_plain=0
        fi ;;
esac
if [ "$_bga_plain" = 1 ]; then
    # Every decoration that emits escapes or extra lines is off by default;
    # an explicit BASHGITAWARE_* setting still wins.
    _bga_color=0 _bga_depth=0 _bga_title=0
    : "${BASHGITAWARE_OSC:=0}" "${BASHGITAWARE_TRANSIENT:=0}" "${BASHGITAWARE_ASYNC:=0}"
    : "${BASHGITAWARE_GLYPHS:=ascii}" "${BASHGITAWARE_COMMIT_LINE:=0}"
fi
