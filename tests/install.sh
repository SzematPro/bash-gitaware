# tests/install.sh -- installer: tamper check, uninstall, --yes, interactive.
# shellcheck shell=bash

# A private copy of the files install.sh needs, so permissions can be changed.
_in_copy() {
    local c; c="$(mktemp -d "${TMPDIR:-/tmp}/bga-inst-XXXXXX")"
    mkdir -p "$c/repo/bin"
    cp "$REPO/install.sh" "$REPO/new.bashrc" "$c/repo/"
    cp "$REPO/bin/bga" "$c/repo/bin/"
    chmod 755 "$c/repo"
    printf '%s' "$c"
}

scenario_install_tamper_check() {
    section "install.sh: refuses a new.bashrc other users can change"
    local c rc out; c="$(_in_copy)"
    chmod o+w "$c/repo/new.bashrc"
    out="$(bash "$c/repo/install.sh" --append --target "$c/rc" 2>&1)"; rc=$?
    if [ "$rc" != 0 ] && [ ! -e "$c/rc" ]; then ok "world-writable new.bashrc refused"; else fail "world-writable accepted ($rc)"; fi
    assert_contains "$out" "writable by any user" "reason reported"
    chmod o-w "$c/repo/new.bashrc"; chmod o+w "$c/repo"
    bash "$c/repo/install.sh" --append --target "$c/rc" >/dev/null 2>&1; rc=$?
    if [ "$rc" != 0 ]; then ok "world-writable directory refused"; else fail "world-writable directory accepted"; fi
    chmod o-w "$c/repo"; chmod g+w "$c/repo/new.bashrc"
    bash "$c/repo/install.sh" --append --target "$c/rc" >/dev/null 2>&1; rc=$?
    if [ "$rc" = 0 ]; then ok "writable by own primary group accepted (L-37)"; else fail "own-group writable refused ($rc)"; fi
    rm -rf "$c"
}

scenario_install_uninstall() {
    section "install.sh --uninstall: removes the source block or restores the backup"
    local c out; c="$(_in_copy)"
    printf 'export KEEP=1\n' > "$c/rc"
    bash "$c/repo/install.sh" --append --target "$c/rc" >/dev/null 2>&1
    bash "$c/repo/install.sh" --uninstall --target "$c/rc" >/dev/null 2>&1
    out="$(cat "$c/rc")"
    assert_contains "$out" "export KEEP=1" "user content kept"
    assert_lacks    "$out" "new.bashrc"    "source block removed"
    printf 'original\n' > "$c/rc2"
    bash "$c/repo/install.sh" --replace --target "$c/rc2" >/dev/null 2>&1
    bash "$c/repo/install.sh" --uninstall --target "$c/rc2" >/dev/null 2>&1
    assert_contains "$(cat "$c/rc2")" "original" "replaced file restored from its backup"
    out="$(bash "$c/repo/install.sh" --uninstall --target "$c/rc2" 2>&1)"
    assert_contains "$out" "nothing to do" "uninstall twice is a no-op"
    rm -rf "$c"
}

scenario_install_interactive() {
    section "install.sh: questions on a terminal, none with --yes"
    local c out; c="$(_in_copy)"
    out="$(bash "$c/repo/install.sh" --yes --target "$c/rc" --no-backup </dev/null 2>&1)"
    assert_lacks "$out" "Install mode" "--yes asks nothing"
    if ! command -v script >/dev/null 2>&1 || ! script -qc true /dev/null >/dev/null 2>&1; then
        skip "interactive installer (needs util-linux script)"; rm -rf "$c"; return
    fi
    printf 'append\naware\nascii\n' | BASHGITAWARE_CONFIG="$c/cfg" \
        script -qc "bash '$c/repo/install.sh' --target '$c/rc3'" /dev/null >/dev/null 2>&1
    assert_contains "$(cat "$c/rc3" 2>/dev/null)" "new.bashrc" "answer 'append' wrote a source line"
    assert_contains "$(cat "$c/cfg" 2>/dev/null)" "theme = aware"  "theme answer stored in the config"
    assert_contains "$(cat "$c/cfg" 2>/dev/null)" "glyphs = ascii" "glyph answer stored in the config"
    rm -rf "$c"
}
