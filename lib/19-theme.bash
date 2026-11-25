
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
hash     5c6582  60 90 0
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
tag      ff9f5a 215 33 0
timer    e6b450 179 93 0
err      ff6b81 204 91 1
ok       8ccf7e 114 92 1
sym_err  ff6b81 204 91 1
'

# Static defaults (no color) so every token exists even before a theme
# applies; __bga_theme_apply overwrites them.
_R='' _Rr=''
_c_dim='' _c_path='' _c_user='' _c_host='' _c_host_ssh='' _c_branch='' _c_hash=''
_c_state='' _c_ahead='' _c_behind='' _c_dirty='' _c_stash='' _c_commit='' _c_node=''
_c_py='' _c_rust='' _c_go='' _c_tag='' _c_timer='' _c_err='' _c_ok='' _c_sym_err=''
_cr_ok='' _cr_sym_err=''

# Every token a theme must define (the test suite checks each theme).
_bga_theme_tokens='dim path user host host_ssh branch hash state ahead behind dirty stash commit node py rust go tag timer err ok sym_err'

__bga_theme_apply() {
    local name="${1:-aware}" table var line tok sgr
    local IFS=$' \t\n' -
    set -f                       # word splitting below must not glob
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
