
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
    case "$s" in *$'\xe2'*) __bga_strip_bidi "$s"; s="$REPLY" ;; esac
    if [ "${_bga_utf8:-0}" != 1 ]; then __bga_strip_c1_raw "$s"; s="$REPLY"; fi
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
    case "$REPLY" in *$'\xe2'*) __bga_strip_bidi "$REPLY" ;; esac
    if [ "${_bga_utf8:-0}" != 1 ]; then __bga_strip_c1_raw "$REPLY"; fi
}

# C1 controls (U+0080-U+009F, UTF-8 bytes C2 80-9F; C2 9B is CSI) are only
# [[:cntrl:]] in a UTF-8 locale. A shell in the C locale talking to a UTF-8
# terminal would pass them through, so match the bytes under LC_ALL=C.
# Called only when the text contains a C2 byte, which is rare.
__bga_strip_c1() {
    local LC_ALL=C
    REPLY="${1//$'\xc2'[$'\x80'-$'\x9f']/?}"
}

# Bidi and invisible format controls: U+200E/U+200F (marks), U+202A-U+202E
# (embeddings and overrides; U+202E reverses text), U+2066-U+2069
# (isolates). They are not [[:cntrl:]], terminals draw them as zero width
# while the width table counted one cell, and with bidi support they can
# reorder a branch or context name on screen (SR7 F6). Matched as bytes.
__bga_strip_bidi() {
    local LC_ALL=C s="$1"
    s="${s//$'\xe2\x80'[$'\x8e'$'\x8f'$'\xaa'-$'\xae']/?}"
    REPLY="${s//$'\xe2\x81'[$'\xa6'-$'\xa9']/?}"
}

# Outside a UTF-8 locale the terminal may be 8-bit, where a lone byte 0x9B is
# CSI. In UTF-8 those bytes are continuation bytes of normal characters, so
# this runs only when the locale is not UTF-8 (SR6 F4).
__bga_strip_c1_raw() {
    local LC_ALL=C
    REPLY="${1//[$'\x80'-$'\x9f']/?}"
}

# Read the first line of a small file into REPLY (at most 256 bytes). Only
# regular files: a cloned repo can ship .python-version -> /dev/zero, /dev/tty
# or a FIFO, and an unbounded `read` there hangs every prompt. Returns 1 (and
# empties REPLY) for anything else.
# -d '': bash drops NUL bytes without counting them against -n, so a file
# of NULs (cheap to ship: git stores it compressed) was read to the end on
# every prompt, and Ctrl-C did not stop it (SR6 F2). A NUL now ends the read.
__bga_read_line() {
    REPLY=''
    [ -f "$1" ] && [ -r "$1" ] || return 1
    IFS= read -r -d '' -n 256 REPLY < "$1" 2>/dev/null
    REPLY="${REPLY%%$'\n'*}"
    REPLY="${REPLY%$'\r'}"
    return 0
}

# A version from version file $1 into REPLY, or return 1. A symlink is
# followed only to a file inside the repository (or the current directory
# outside one): a cloned repo could point .ruby-version at
# ~/.git-credentials and show it in the prompt (SR6 F3). The value must look
# like a version: its first word, at most 32 characters of [A-Za-z0-9._+@/:-].
# True if $1 is not a symlink, or is one whose target is inside the
# repository (the current directory outside one). One readlink fork, only
# for symlinks; the result is cached with the runtimes per directory.
__bga_link_inside() {
    [ -L "$1" ] || return 0
    local t top="${_bga_git_top:-$PWD}"
    command -v readlink >/dev/null 2>&1 || return 1
    t="$(readlink -f -- "$1" 2>/dev/null)" || return 1
    case "$t" in "${top%/}"/*) return 0 ;; esac
    return 1
}

__bga_read_version() {
    REPLY=''
    __bga_link_inside "$1" || return 1
    __bga_read_line "$1" || return 1
    local v="$REPLY" LC_ALL=C
    v="${v#"${v%%[![:blank:]]*}"}"; v="${v%%[[:blank:]]*}"
    REPLY=''
    [ -n "$v" ] && [ "${#v}" -le 32 ] || return 1
    case "$v" in *[!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._+@/:-]*) return 1 ;; esac
    REPLY="$v"
}
