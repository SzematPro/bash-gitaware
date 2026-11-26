
# ---------------------------------------------------------------------------
# Themes and semantic color tokens (v3 T1.4, ADR-0007).
#
# Segment code never writes a color escape. It uses tokens: _c_<name> (wrapped
# in \[ \] for PS1) and _cr_<name> (raw, for text printed directly, such as the
# transient line). A theme is a table with one row per token:
#
#   <token> <rrggbb> <xterm-256 index> <16-color SGR> <bold 0|1>
#
# __bga_theme_apply resolves the table for the terminal's color depth
# (_bga_depth from lib/10-detect.bash): 24-bit, 256, 16, or 0 (no color,
# including NO_COLOR). The 256 indices are the nearest xterm-256 colors to
# the hex value, precomputed. Pick a theme with BASHGITAWARE_THEME or
# `theme = ...` in the config file; unknown names fall back to aware.
# ---------------------------------------------------------------------------

# Aware: the signature theme. Calm blues and violets for structure, warm
# amber for "needs attention", green/red only for success/failure.
_bga_theme_aware='
dim      6c7591  66 90 0
path     6fa8ff  75 94 1
user     5ccfe6  80 36 0
host     5ccfe6  80 36 0
host_ssh ff9f5a 215 33 1
branch   b48cf2 141 95 1
hash     6c7591  66 90 0
state    ff6b81 204 91 1
ahead    5ccfe6  80 96 0
behind   5ccfe6  80 96 0
dirty    e6b450 179 93 0
stash    8fb0d9 110 94 0
commit   6c7591  66 90 0
node     8ccf7e 114 92 0
py       e6b450 179 93 0
rust     f29e74 216 33 0
go       5ccfe6  80 96 0
ruby     ff6b81 204 91 0
deno     8fb0d9 110 94 0
bun      ff9f5a 215 33 0
java     e6b450 179 93 0
tag      ff9f5a 215 33 0
timer    e6b450 179 93 0
err      ff6b81 204 91 1
ok       8ccf7e 114 92 1
sym_err  ff6b81 204 91 1
'

# Light: for light backgrounds; darker, saturated tones (WCAG 4.5:1 on white,
# 3:1 for muted tokens; bin/check-contrast.py).
# Contrast: high contrast on dark backgrounds (7:1 on black for every token).
_bga_theme_light='
dim      5f6b7a  60 90 0
path     1d5fd1  26 34 1
user     0b6e83  24 36 0
host     0b6e83  24 36 0
host_ssh a34a06 130 33 1
branch   6d32d8  62 35 1
hash     5f6b7a  60 90 0
state    b5172f 124 31 1
ahead    0b6e83  24 36 0
behind   0b6e83  24 36 0
dirty    8a5300  94 33 0
stash    34538a  60 34 0
commit   5f6b7a  60 90 0
node     26702a  22 32 0
py       8a5300  94 33 0
rust     a34a06 130 33 0
go       0b6e83  24 36 0
ruby     b5172f 124 31 0
deno     34538a  60 34 0
bun      a34a06 130 33 0
java     8a5300  94 33 0
tag      a34a06 130 33 0
timer    8a5300  94 33 0
err      b5172f 124 31 1
ok       26702a  22 32 1
sym_err  b5172f 124 31 1
'

_bga_theme_contrast='
dim      c8c8c8 251 37 0
path     6cb6ff  75 94 1
user     00e5ff  45 96 0
host     00e5ff  45 96 0
host_ssh ffb000 214 93 1
branch   dcb4ff 183 95 1
hash     c8c8c8 251 37 0
state    ff6b6b 203 91 1
ahead    00e5ff  45 96 0
behind   00e5ff  45 96 0
dirty    ffe600 220 93 0
stash    b4d7ff 153 94 0
commit   c8c8c8 251 37 0
node     8cff8c 120 92 0
py       ffe600 220 93 0
rust     ffb46e 215 93 0
go       00e5ff  45 96 0
ruby     ff6b6b 203 91 0
deno     b4d7ff 153 94 0
bun      ffb000 214 93 0
java     ffe600 220 93 0
tag      ffb000 214 93 0
timer    ffe600 220 93 0
err      ff6b6b 203 91 1
ok       8cff8c 120 92 1
sym_err  ff6b6b 203 91 1
'

# Static defaults (no color) so every token exists even before a theme
# applies; __bga_theme_apply overwrites them.
_R='' _Rr=''
_c_dim='' _c_path='' _c_user='' _c_host='' _c_host_ssh='' _c_branch='' _c_hash=''
_c_state='' _c_ahead='' _c_behind='' _c_dirty='' _c_stash='' _c_commit='' _c_node=''
_c_py='' _c_rust='' _c_go='' _c_ruby='' _c_deno='' _c_bun='' _c_java='' _c_tag='' _c_timer='' _c_err='' _c_ok='' _c_sym_err=''
_cr_dim='' _cr_path='' _cr_user='' _cr_host='' _cr_host_ssh='' _cr_branch='' _cr_hash=''
_cr_state='' _cr_ahead='' _cr_behind='' _cr_dirty='' _cr_stash='' _cr_commit='' _cr_node=''
_cr_py='' _cr_rust='' _cr_go='' _cr_ruby='' _cr_deno='' _cr_bun='' _cr_java='' _cr_tag='' _cr_timer='' _cr_err='' _cr_ok='' _cr_sym_err=''

# Every token a theme must define (the test suite checks each theme).
_bga_theme_tokens='dim path user host host_ssh branch hash state ahead behind dirty stash commit node py rust go ruby deno bun java tag timer err ok sym_err'

__bga_theme_apply() {
    local name="${1:-aware}" table var line tok sgr
    local IFS=$' \t\n' -
    set -f                       # word splitting below must not glob
    # The name selects a variable through ${!var}: an array subscript in it
    # would be evaluated (command substitution included). Names are plain.
    case "$name" in '' | *[!a-z0-9_]*) name=aware ;; esac
    var="_bga_theme_$name"
    [ -n "${!var+set}" ] || var=_bga_theme_aware
    table="${!var}"
    for tok in $_bga_theme_tokens; do printf -v "_c_$tok" '%s' ''; printf -v "_cr_$tok" '%s' ''; done
    _R='' _Rr=''
    [ "${_bga_depth:-0}" = 0 ] && return 0
    _R='\[\033[0m\]' _Rr=$'\e[0m'
    # One row per line; split with parameter expansion (no here-documents:
    # they write a temp file before bash 5.1, ruling R-3).
    table="${table#$'\n'}"
    while [ -n "$table" ]; do
        line="${table%%$'\n'*}"
        case "$table" in *$'\n'*) table="${table#*$'\n'}" ;; *) table='' ;; esac
        # shellcheck disable=SC2086  # intentional split of a fixed-format row
        set -- $line
        [ "$#" = 5 ] || continue
        # Every field is checked: a theme table can come from the environment,
        # and its values end up in PS1 (promptvars) and in printf -v names.
        case " $_bga_theme_tokens " in *" $1 "*) ;; *) continue ;; esac
        case "$2" in [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;; *) continue ;; esac
        case "$3" in '' | *[!0-9]*) continue ;; esac
        case "$4" in '' | *[!0-9]*) continue ;; esac
        case "$5" in 0 | 1) ;; *) continue ;; esac
        case "$_bga_depth" in
            24)  sgr="38;2;$(( 16#${2:0:2} ));$(( 16#${2:2:2} ));$(( 16#${2:4:2} ))" ;;
            256) sgr="38;5;$3" ;;
            *)   sgr="$4" ;;
        esac
        [ "$5" = 1 ] && sgr="1;$sgr"
        printf -v "_c_$1" '\\[\\033[%sm\\]' "$sgr"
        printf -v "_cr_$1" '\e[%sm' "$sgr"
    done
}
