
# ---------------------------------------------------------------------------
# vi-mode indicator (3.1, SPEC S5; ADR-0012). readline draws a mode string
# at the start of the last prompt line when show-mode-in-prompt is on, so
# the indicator costs nothing per prompt and readline itself redraws it on
# every mode switch. Insert mode shows nothing; command mode shows a marker
# in the theme's "state" color. The emacs string is emptied, so emacs mode
# looks as before.
#
# Left alone when the user configured any of it (show-mode-in-prompt on, or
# a mode string changed from readline's default), with vi_mode = 0, in plain
# mode, and outside interactive shells (bind needs line editing).
# ---------------------------------------------------------------------------
# True while the readline variables are still the ones we set: the insert
# and emacs strings empty and the indicator on. $1 = `bind -v` output.
__bga_vimode_still_ours() {
    local v="${1-}"
    [ -n "$v" ] || v="$(bind -v 2>/dev/null)"
    case "$v" in *'show-mode-in-prompt on'*) ;; *) return 1 ;; esac
    # An empty value prints as "name " at the end of its line (the last line
    # has no newline once $(...) strips it).
    case "$v" in *$'vi-ins-mode-string \n'* | *'vi-ins-mode-string ') ;; *) return 1 ;; esac
    case "$v" in *$'emacs-mode-string \n'* | *'emacs-mode-string ') ;; *) return 1 ;; esac
}

__bga_vimode_setup() {
    [[ $- == *i* ]] || return 0
    if [ "${BASHGITAWARE_VI_MODE:-auto}" = 0 ] || [ "${_bga_plain:-0}" = 1 ]; then
        # Turned off since an earlier load: put readline's defaults back,
        # unless the user has changed the strings since (see below).
        if [ "${_bga_vimode_set:-0}" = 1 ] && __bga_vimode_still_ours; then
            bind 'set show-mode-in-prompt off' 2>/dev/null
            bind 'set emacs-mode-string "@"' 2>/dev/null
            bind 'set vi-ins-mode-string "(ins)"' 2>/dev/null
            bind 'set vi-cmd-mode-string "(cmd)"' 2>/dev/null
            _bga_vimode_set=0
        fi
        return 0
    fi
    local v
    v="$(bind -v 2>/dev/null)" || return 0
    # Ours from an earlier load (bga reload): set them again for the theme,
    # unless the user changed them after that load.
    if [ "${_bga_vimode_set:-0}" = 1 ] && ! __bga_vimode_still_ours "$v"; then _bga_vimode_set=0; return 0; fi
    if [ "${_bga_vimode_set:-0}" != 1 ]; then
        case "$v" in *'show-mode-in-prompt on'*) return 0 ;; esac
        case "$v" in *'vi-cmd-mode-string (cmd)'*) ;; *) return 0 ;; esac
        case "$v" in *'vi-ins-mode-string (ins)'*) ;; *) return 0 ;; esac
        case "$v" in *'emacs-mode-string @'*) ;; *) return 0 ;; esac
    fi
    local mark=N sgr="${_cr_state:-}" reset="${_Rr:-}" s
    [ "${_bga_glyphs:-ascii}" = nerd ] && mark=$''
    # Colors go inside \1 \2 so readline does not count them as width. The
    # escapes come from the theme tables (fixed SGR codes); ESC is written
    # as \e for bind.
    sgr="${sgr//$'\e'/\\e}" reset="${reset//$'\e'/\\e}"
    if [ -n "$sgr" ]; then s="\\1${sgr}\\2${mark}\\1${reset}\\2 "; else s="${mark} "; fi
    bind 'set show-mode-in-prompt on' 2>/dev/null
    bind 'set emacs-mode-string ""' 2>/dev/null
    bind 'set vi-ins-mode-string ""' 2>/dev/null
    bind "set vi-cmd-mode-string \"$s\"" 2>/dev/null
    _bga_vimode_set=1
}
__bga_vimode_setup
