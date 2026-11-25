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
    section "width engine: bounded cost on hostile input"
    local TIMEFORMAT=%3R t ms out
    # 10 KB of CJK: past the 512-byte decode cap the engine returns the byte
    # count, an upper bound on the width (each cell takes at least one byte).
    t="$( { time out="$(LANG=C.UTF-8 bash --norc --noprofile -c "source '$REPO/lib/17-width.bash'
        s=''; for ((i=0;i<1000;i++)); do s+=\$'ab\u65e5c'; done; __bga_width \"\$s\"; printf '%s' \"\$REPLY\"")"; echo "R=$out"; } 2>&1 )"
    case "$t" in *R=6000*) ok "10 KB: byte count returned (6000 >= true width 5000)" ;;
        *) fail "10 KB: unexpected width ($t)" ;; esac
    ms="${t%%R=*}"; ms="${ms//[!0-9]/}"; [ -n "$ms" ] || ms="${t#*R=6000}"
    ms="${ms//[!0-9]/}"; ms=$(( 10#${ms:-0} ))
    if [ "$ms" -lt 500 ]; then ok "10 KB measured in ${ms}ms (whole process, including building the string)"
    else fail "10 KB took ${ms}ms"; fi
    # Just under the cap, results are still exact.
    _w_is "$(printf '\u65e5%.0s' $(seq 170))" 340 "170 CJK characters (510 bytes): exact"
}
