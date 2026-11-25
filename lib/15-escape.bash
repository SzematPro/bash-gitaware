
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
}
