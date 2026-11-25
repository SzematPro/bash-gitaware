# tests/theme.sh -- semantic color tokens and themes (lib/19-theme.bash).
# shellcheck shell=bash

# Render /tmp with extra env; prints the expanded PS1.
_th_render() { bga_render "${TMPDIR:-/tmp}" "$@"; }

scenario_theme_depths() {
    section "themes: one escape form per color depth"
    local out
    out="$(_th_render TERM=xterm-256color COLORTERM=truecolor)"
    assert_contains "$out" $'\e[1;38;2;111;168;255m' "24-bit: path token as RGB"
    out="$(_th_render TERM=xterm-256color)"
    assert_contains "$out" $'\e[1;38;5;75m'          "256: path token as xterm-256 index"
    assert_lacks    "$out" '38;2;'                    "256: no RGB escapes"
    out="$(_th_render TERM=xterm)"
    assert_contains "$out" $'\e[1;94m'                "16: path token as bright blue"
    assert_lacks    "$out" '38;5;'                    "16: no 256-color escapes"
    out="$(_th_render NO_COLOR=1 COLORTERM=truecolor)"
    case "$out" in *$'\e['[0-9]*m*) fail "NO_COLOR: SGR escape present" ;; *) ok "NO_COLOR: no SGR escapes" ;; esac
    out="$(_th_render BASHGITAWARE_THEME=nosuchtheme)"
    assert_contains "$out" $'\e[1;38;5;75m'          "unknown theme falls back to aware"
}

scenario_theme_tokens_complete() {
    section "themes: every theme defines every token; no literal colors elsewhere"
    local out
    out="$(bash --norc --noprofile -c "
        source '$REPO/lib/19-theme.bash'
        for v in \$(compgen -v _bga_theme_); do
            [ \"\$v\" = _bga_theme_tokens ] && continue
            for t in \$_bga_theme_tokens; do
                case \"\${!v}\" in *\$'\n'\"\$t \"*) ;; *) echo \"MISSING \$v:\$t\" ;; esac
            done
            echo \"checked \$v\"
        done")"
    assert_contains "$out" "checked _bga_theme_aware" "aware theme checked"
    assert_lacks    "$out" "MISSING"                  "no theme lacks a token"
    # SGR color escapes may only appear in the theme module.
    local hits; hits="$(grep -nE '(\\033|\\e)\[[0-9;]*m' "$REPO"/lib/*.bash | grep -v '/19-theme.bash:')"
    if [ -z "$hits" ]; then ok "no literal color escapes outside lib/19-theme.bash"
    else fail "literal color escapes: $hits"; fi
}
