
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
