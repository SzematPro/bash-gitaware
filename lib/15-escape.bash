
# ---------------------------------------------------------------------------
# Escaping untrusted text for PS1.
#
# Branch names, commit subjects, directory names, version files and env names
# are attacker-controlled (any cloned repo). PS1 goes through two layers before
# it is shown: backslash-escape decoding (\u, \w, \\ ...) and then, with
# `shopt -s promptvars` (the default), parameter expansion, command
# substitution and arithmetic expansion. Text pasted raw into PS1 therefore
# runs `$(...)` and backticks on every prompt.
#
# __bga_ps1_lit "<text>" sets REPLY to a form that both layers turn back into
# <text> verbatim:
#   1. control characters (C0, DEL, and C1 in UTF-8 locales) become '?', so the
#      text cannot inject terminal sequences or break readline's width count;
#   2. with promptvars on: \ -> \\, $ -> \$, ` -> \`   (expansion layer);
#   3. \ -> \\  (decoding layer); in posix mode also ! -> !! (history number).
# Sets REPLY instead of printing so callers avoid a subshell per segment.
# ---------------------------------------------------------------------------
__bga_ps1_lit() {
    local s="$1" bs=\\ dl='$' bt='`'
    s="${s//[[:cntrl:]]/?}"
    case "$s" in *$'\xc2'*) __bga_strip_c1 "$s"; s="$REPLY" ;; esac
    if shopt -q promptvars; then
        s="${s//"$bs"/"$bs$bs"}"
        s="${s//"$dl"/"$bs$dl"}"
        s="${s//"$bt"/"$bs$bt"}"
    fi
    s="${s//"$bs"/"$bs$bs"}"
    if shopt -oq posix; then s="${s//!/!!}"; fi
    REPLY="$s"
}

# Strip control characters only (for text written straight to the terminal,
# outside PS1, e.g. the OSC 7 cwd report). Sets REPLY.
__bga_term_safe() {
    REPLY="${1//[[:cntrl:]]/?}"
    case "$REPLY" in *$'\xc2'*) __bga_strip_c1 "$REPLY" ;; esac
}

# C1 controls (U+0080-U+009F, UTF-8 bytes C2 80-9F; C2 9B is CSI) are only
# [[:cntrl:]] in a UTF-8 locale. A shell in the C locale talking to a UTF-8
# terminal would pass them through, so match the bytes under LC_ALL=C.
# Called only when the text contains a C2 byte, which is rare.
__bga_strip_c1() {
    local LC_ALL=C
    REPLY="${1//$'\xc2'[$'\x80'-$'\x9f']/?}"
}

# Read the first line of a small file into REPLY (at most 256 bytes). Only
# regular files: a cloned repo can ship .python-version -> /dev/zero, /dev/tty
# or a FIFO, and an unbounded `read` there hangs every prompt. Returns 1 (and
# empties REPLY) for anything else.
__bga_read_line() {
    REPLY=''
    [ -f "$1" ] && [ -r "$1" ] || return 1
    IFS= read -r -n 256 REPLY < "$1" 2>/dev/null
    REPLY="${REPLY%$'\r'}"
    return 0
}
