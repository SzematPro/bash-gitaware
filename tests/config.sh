# tests/config.sh -- the config file is parsed as data, validated, never sourced.
# shellcheck shell=bash disable=SC2016  # payloads are literal on purpose

# Source new.bashrc with BASHGITAWARE_CONFIG=$1 and run $2; stderr is kept.
_cf_run() {
    bash --norc --noprofile -i -c "
        export HOME='$HOME' PATH='$PATH' TERM='xterm-256color' LANG='C.UTF-8'
        export BASHGITAWARE_CONFIG='$1'
        ${3-}
        source '$REPO/new.bashrc'
        $2
    " 2>&1 | grep -av -e 'cannot set terminal process group' -e 'no job control in this shell'
}

scenario_config_file() {
    section "config file: parsing and precedence"
    local dir; dir="$(mktemp -d "${TMPDIR:-/tmp}/bga-cfg-XXXXXX")"
    local f="$dir/config" out
    printf '%s\n' '# comment' '' 'preset = minimal' "  glyphs='unicode'  " \
        'path_maxdepth=5' 'timer_threshold = "7"' $'osc = 0\r' > "$f"
    chmod 600 "$f"
    out="$(_cf_run "$f" 'echo "p=$BASHGITAWARE_PRESET g=$BASHGITAWARE_GLYPHS d=$BASHGITAWARE_PATH_MAXDEPTH t=$BASHGITAWARE_TIMER_THRESHOLD o=$BASHGITAWARE_OSC"')"
    assert_contains "$out" "p=minimal g=unicode d=5 t=7 o=0" "values applied (quotes, spaces, CRLF)"
    assert_lacks    "$out" "bash-gitaware:" "no warnings for a valid file"

    out="$(_cf_run "$f" 'echo "g=$BASHGITAWARE_GLYPHS"' 'export BASHGITAWARE_GLYPHS=ascii')"
    assert_contains "$out" "g=ascii" "environment wins over the file"

    out="$(_cf_run "$dir/missing" 'echo loaded')"
    assert_contains "$out" "loaded" "missing file is fine"
    assert_lacks    "$out" "bash-gitaware:" "missing file: no warning"
    rm -rf "$dir"
}

scenario_config_file_validation() {
    section "config file: invalid input is rejected, never executed"
    local dir; dir="$(mktemp -d "${TMPDIR:-/tmp}/bga-cfg-XXXXXX")"
    local f="$dir/config" out
    printf '%s\n' 'colour = red' 'glyphs = $(touch PWNED_CFG)' 'async = maybe' \
        'path_maxdepth = 3; touch PWNED_CFG2' 'no equals sign here' 'show_host = always' > "$f"
    chmod 600 "$f"
    out="$(cd "$dir" && _cf_run "$f" 'echo "h=$BASHGITAWARE_SHOW_HOST g=${BASHGITAWARE_GLYPHS-unset} a=${BASHGITAWARE_ASYNC-unset}"')"
    if [ -e "$dir/PWNED_CFG" ] || [ -e "$dir/PWNED_CFG2" ]; then fail "config payload executed"; else ok "config payload not executed"; fi
    assert_contains "$out" "config:1: unknown key 'colour'"       "unknown key reported with line number"
    assert_contains "$out" "config:2: invalid value for 'glyphs'" "invalid glyphs value reported"
    assert_contains "$out" "config:3: invalid value for 'async'"  "invalid async value reported"
    assert_contains "$out" "config:4: invalid value for 'path_maxdepth'" "trailing junk rejected"
    assert_contains "$out" "config:5: expected key = value"       "malformed line reported"
    assert_contains "$out" "h=always g=unset a=unset"            "valid keys kept, invalid ignored"
    rm -rf "$dir"
}

scenario_config_file_permissions() {
    section "config file: refused when others can write it"
    local dir; dir="$(mktemp -d "${TMPDIR:-/tmp}/bga-cfg-XXXXXX")"
    local f="$dir/config" out
    printf 'preset = minimal\n' > "$f"; chmod 666 "$f"
    out="$(_cf_run "$f" 'echo "p=${BASHGITAWARE_PRESET-unset}"')"
    assert_contains "$out" "p=unset"                "group/world-writable file not loaded"
    assert_contains "$out" "writable by other users" "refusal is reported"
    chmod 600 "$f"; ln -s "$f" "$dir/link"
    out="$(_cf_run "$dir/link" 'echo "p=${BASHGITAWARE_PRESET-unset}"')"
    assert_contains "$out" "p=minimal" "symlink to a private file is accepted"
    rm -rf "$dir"
}

scenario_config_file_sticky_dir() {
    section "config file: accepted in a sticky world-writable directory, refused in a plain one"
    local dir; dir="$(mktemp -d "${TMPDIR:-/tmp}/bga-cfg-XXXXXX")"
    mkdir -m 1777 "$dir/sticky"; mkdir -m 0777 "$dir/open"
    printf 'preset = minimal\n' > "$dir/sticky/config"; chmod 600 "$dir/sticky/config"
    printf 'preset = minimal\n' > "$dir/open/config"; chmod 600 "$dir/open/config"
    local out
    out="$(_cf_run "$dir/sticky/config" 'echo "p=${BASHGITAWARE_PRESET-unset}"')"
    assert_contains "$out" "p=minimal" "sticky directory (like /tmp): accepted"
    out="$(_cf_run "$dir/open/config" 'echo "p=${BASHGITAWARE_PRESET-unset}"')"
    assert_contains "$out" "p=unset" "world-writable, non-sticky directory: refused"
    printf 'preset = minimal\n' > "$dir/mine"; chmod 600 "$dir/mine"
    ln -s "$dir/mine" "$dir/sticky/link"
    out="$(_cf_run "$dir/sticky/link" 'echo "p=${BASHGITAWARE_PRESET-unset}"')"
    assert_contains "$out" "p=unset" "symlink planted in a sticky directory: refused"
    chmod 755 "$dir/open" "$dir/sticky"; rm -rf "$dir"
}

scenario_config_turkish_locale() {
    section "config file: keys work in a Turkish locale (SR5 F3)"
    if ! locale -a 2>/dev/null | grep -qi '^tr_TR\.utf-\?8$'; then skip "tr_TR.UTF-8 locale not installed"; return; fi
    local dir; dir="$(mktemp -d "${TMPDIR:-/tmp}/bga-cfg-XXXXXX")"
    local f="$dir/config" out
    printf 'commit_line = 1\ntimer_threshold = 9\nTheme = light\n' > "$f"; chmod 600 "$f"
    out="$(_cf_run "$f" 'echo "c=$BASHGITAWARE_COMMIT_LINE t=$BASHGITAWARE_TIMER_THRESHOLD th=$BASHGITAWARE_THEME"' 'export LC_ALL=tr_TR.UTF-8')"
    assert_contains "$out" "c=1 t=9 th=light" "keys with i, and an uppercase key, apply under tr_TR"
    assert_lacks    "$out" "not a valid identifier" "no invalid variable name"
    rm -rf "$dir"
}

scenario_config_key_table() {
    section "config: one key table drives validation"
    local out
    out="$(bash --norc --noprofile -i -c "export HOME='$HOME' PATH='$PATH'; source '$REPO/new.bashrc'
        v() { __bga_config_valid \"\$1\" \"\$2\"; printf '%s=%s:%s ' \"\$1\" \"\$2\" \"\$?\"; }
        v preset full; v preset bogus; v clock 1; v clock 2; v path_maxdepth 0; v path_maxdepth -1
        v theme aware; v theme 'a b'; v runtimes py,go; v runtimes py,,go; v runtimes ''; v vi_mode 0
        v nosuch x; v style 'lean classic'; v style '*'" 2>/dev/null)"
    assert_contains "$out" "preset=full:0 preset=bogus:1 clock=1:0 clock=2:1 path_maxdepth=0:0 path_maxdepth=-1:1" "enum, bool and num kinds"
    assert_contains "$out" "theme=aware:0 theme=a b:1 runtimes=py,go:0 runtimes=py,,go:1 runtimes=:1 vi_mode=0:0" "theme and list kinds"
    assert_contains "$out" "nosuch=x:2 style=lean classic:1 style=*:1" "unknown key, spaces and globs"
}

