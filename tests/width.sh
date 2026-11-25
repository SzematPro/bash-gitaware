# tests/width.sh -- display-width engine (lib/17-width.bash, ADR-0007).
# shellcheck shell=bash

# Width of $1 computed in a clean bash with the module sourced alone.
_w() {
    LANG=C.UTF-8 bash --norc --noprofile -c "source '$REPO/lib/17-width.bash'; __bga_width \"\$1\"; printf '%s' \"\$REPLY\"" _ "$1"
}

_w_is() {
    local got; got="$(_w "$1")"
    if [ "$got" = "$2" ]; then ok "width $(printf '%q' "$1") = $2"
    else fail "width $(printf '%q' "$1") = $got, expected $2 ($3)"; fi
}

scenario_width_engine() {
    section "width engine: known widths"
    _w_is ''                                0 "empty"
    _w_is 'hello world'                     11 "ASCII"
    _w_is $'été'                  3 "precomposed accents"
    _w_is $'é'                        1 "combining acute"
    _w_is $'日本語'             6 "CJK wide"
    _w_is $'Ａ　'                   4 "fullwidth A and ideographic space"
    _w_is $'\U0001F600'                     2 "emoji"
    _w_is $'✓ ✗'                  3 "check and cross marks are narrow"
    _w_is $'a‍b'                       2 "zero-width joiner"
    _w_is $'❤️'                   1 "variation selector is zero width"
    _w_is $'x\ty'                           2 "tab (control) counts 0"
    _w_is $'\xff'                           1 "invalid byte"
    _w_is $'\xe2\x82'                       2 "truncated sequence"
    _w_is $'\xc0\xaf'                       2 "overlong two-byte form"
    _w_is $'\xe0\x80\xaf'                   3 "overlong three-byte form"
    _w_is $'\xed\xa0\x80'                   3 "UTF-16 surrogate"
    _w_is $'\xf4\x90\x80\x80'               4 "above U+10FFFF"
    _w_is $'\xe6\x97\xa5x\xff\xe6\x97\xa5'  6 "mixed valid, invalid, ASCII"
}

scenario_width_engine_linear() {
    section "width engine: linear time"
    local TIMEFORMAT=%3R t1 t2 a b
    # 10 KB and 20 KB of mostly-CJK text; time should roughly double.
    t1="$( { time LANG=C.UTF-8 bash --norc --noprofile -c "source '$REPO/lib/17-width.bash'
        s=''; for ((i=0;i<1000;i++)); do s+=\$'ab日c'; done; __bga_width \"\$s\"
        [ \"\$REPLY\" = 5000 ] || echo BAD >&2"; } 2>&1 )"
    t2="$( { time LANG=C.UTF-8 bash --norc --noprofile -c "source '$REPO/lib/17-width.bash'
        s=''; for ((i=0;i<2000;i++)); do s+=\$'ab日c'; done; __bga_width \"\$s\"
        [ \"\$REPLY\" = 10000 ] || echo BAD >&2"; } 2>&1 )"
    case "$t1$t2" in *BAD*) fail "width of repeated text is wrong"; return ;; esac
    a="${t1//[!0-9]/}"; b="${t2//[!0-9]/}"; a=$(( 10#$a )); b=$(( 10#$b ))
    [ "$a" -lt 1 ] && a=1
    if [ "$b" -le $(( a * 3 + 50 )) ]; then ok "10 KB ${a}ms, 20 KB ${b}ms (linear)"
    else fail "not linear: 10 KB ${a}ms, 20 KB ${b}ms"; fi
}
