# tests/install.sh -- installer: tamper check, uninstall, --yes, interactive.
# shellcheck shell=bash

# A private copy of the files install.sh needs, so permissions can be changed.
_in_copy() {
    local c; c="$(mktemp -d "${TMPDIR:-/tmp}/bga-inst-XXXXXX")"
    # Normalize like install.sh does (pwd): macOS TMPDIR ends in '/', which
    # would leave '//' in the path and break comparisons with its output.
    c="$(CDPATH='' builtin cd -- "$c" && pwd)"
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
    printf 'ORIGINAL-RC-MARKER\n' > "$c/rc2"
    bash "$c/repo/install.sh" --replace --target "$c/rc2" >/dev/null 2>&1
    bash "$c/repo/install.sh" --uninstall --target "$c/rc2" >/dev/null 2>&1
    assert_contains "$(cat "$c/rc2")" "ORIGINAL-RC-MARKER" "replaced file restored from its backup"
    out="$(bash "$c/repo/install.sh" --uninstall --target "$c/rc2" 2>&1)"
    assert_contains "$out" "nothing to do" "uninstall twice is a no-op"
    # SR4: lines that merely mention bash-gitaware are the user's and stay.
    printf 'alias x=1  # bash-gitaware tweak, keep\n' > "$c/rc4"
    bash "$c/repo/install.sh" --append --target "$c/rc4" >/dev/null 2>&1
    bash "$c/repo/install.sh" --uninstall --target "$c/rc4" >/dev/null 2>&1
    assert_contains "$(cat "$c/rc4")" "alias x=1  # bash-gitaware tweak, keep" "user line mentioning bash-gitaware kept"
    # SR4: a backup someone else could have written is not restored.
    printf 'ORIGINAL-RC-MARKER\n' > "$c/rc5"
    bash "$c/repo/install.sh" --replace --target "$c/rc5" >/dev/null 2>&1
    printf 'echo EVIL\n' > "$c/rc5.bak-9999999999"; chmod 666 "$c/rc5.bak-9999999999"
    bash "$c/repo/install.sh" --uninstall --target "$c/rc5" >/dev/null 2>&1
    assert_lacks "$(cat "$c/rc5")" "echo EVIL" "world-writable planted backup not restored"
    rm -rf "$c"
}

scenario_install_hostile_path() {
    section "install.sh --append: a repository path with \$(...) is quoted"
    local base; base="$(mktemp -d "${TMPDIR:-/tmp}/bga-inst-XXXXXX")"
    local c="$base/x\$(touch \$HOME/PWNED_INST)y"
    mkdir -p "$c/bin"; cp "$REPO/install.sh" "$REPO/new.bashrc" "$c/"; cp "$REPO/bin/bga" "$c/bin/"
    chmod 755 "$c"
    bash "$c/install.sh" --append --target "$base/rc" >/dev/null 2>&1
    assert_contains "$(cat "$base/rc" 2>/dev/null)" "new.bashrc" "append happened for the odd path"
    HOME="$base" bash --norc --noprofile -c "source '$base/rc'" >/dev/null 2>&1
    if [ -e "$base/PWNED_INST" ]; then fail "source line executed the path"; else ok "source line quotes the path"; fi
    rm -rf "$base"
}

scenario_install_interactive() {
    section "install.sh: questions on a terminal, none with --yes"
    local c out; c="$(_in_copy)"
    out="$(bash "$c/repo/install.sh" --yes --target "$c/rc" --no-backup </dev/null 2>&1)"
    assert_lacks "$out" "Install mode" "--yes asks nothing"
    if ! pty_ok; then
        skip "interactive installer (needs script(1))"; rm -rf "$c"; return
    fi
    printf 'append\naware\nascii\nyes\n' | BASHGITAWARE_CONFIG="$c/cfg" \
        pty_run "bash '$c/repo/install.sh' --target '$c/rc3'" >/dev/null 2>&1
    assert_contains "$(cat "$c/rc3" 2>/dev/null)" "new.bashrc" "answer 'append' wrote a source line"
    assert_contains "$(cat "$c/cfg" 2>/dev/null)" "theme = aware"  "theme answer stored in the config"
    assert_contains "$(cat "$c/cfg" 2>/dev/null)" "glyphs = ascii" "glyph answer stored in the config"
    assert_contains "$(cat "$c/cfg" 2>/dev/null)" "shell_defaults = 1" "shell-defaults answer stored (yes over the append default)"
    rm -rf "$c"
}

scenario_install_shell_defaults() {
    section "install.sh: always writes shell_defaults (ADR-0010)"
    local c rc out; c="$(_in_copy)"
    BASHGITAWARE_CONFIG="$c/cfg-a" bash "$c/repo/install.sh" --append --target "$c/rc-a" >/dev/null 2>&1
    assert_contains "$(cat "$c/cfg-a" 2>/dev/null)" "shell_defaults = 0" "--append writes 0"
    BASHGITAWARE_CONFIG="$c/cfg-r" bash "$c/repo/install.sh" --replace --no-backup --target "$c/rc-r" >/dev/null 2>&1
    assert_contains "$(cat "$c/cfg-r" 2>/dev/null)" "shell_defaults = 1" "--replace writes 1"
    BASHGITAWARE_CONFIG="$c/cfg-y" bash "$c/repo/install.sh" --yes --no-backup --target "$c/rc-y" </dev/null >/dev/null 2>&1
    assert_contains "$(cat "$c/cfg-y" 2>/dev/null)" "shell_defaults = 1" "--yes takes the default mode's value (replace: 1)"
    # A re-run keeps what the user chose.
    printf 'shell_defaults = 1\n' > "$c/cfg-k"; chmod 600 "$c/cfg-k"
    BASHGITAWARE_CONFIG="$c/cfg-k" bash "$c/repo/install.sh" --append --target "$c/rc-k" >/dev/null 2>&1
    out="$(cat "$c/cfg-k")"
    assert_contains "$out" "shell_defaults = 1" "re-run keeps an existing value"
    assert_lacks    "$out" "shell_defaults = 0" "re-run does not add a second value"
    # A config that cannot be written does not fail the install.
    # A path through a regular file cannot be created, not even by root.
    : > "$c/not-a-dir"
    out="$(BASHGITAWARE_CONFIG="$c/not-a-dir/cfg" bash "$c/repo/install.sh" --append --target "$c/rc-n" 2>&1)"; rc=$?
    if [ "$rc" = 0 ]; then ok "unwritable config: install still succeeds"; else fail "unwritable config failed the install ($rc)"; fi
    assert_contains "$out" "could not store shell_defaults" "unwritable config: warning with the fix"
    assert_contains "$(cat "$c/rc-n" 2>/dev/null)" "new.bashrc" "unwritable config: source line written"
    # --uninstall skips the tamper check, so it must not run repository code
    # (bin/bga sources new.bashrc) to read shell_defaults.
    bash "$c/repo/install.sh" --append --target "$c/rc-u" >/dev/null 2>&1
    printf 'touch %q\n' "$c/PWNED_UNINST" >> "$c/repo/new.bashrc"; chmod o+w "$c/repo/new.bashrc"
    BASHGITAWARE_CONFIG="$c/cfg-u" bash "$c/repo/install.sh" --uninstall --target "$c/rc-u" >/dev/null 2>&1
    if [ -e "$c/PWNED_UNINST" ]; then fail "--uninstall ran new.bashrc"; else ok "--uninstall does not run new.bashrc"; fi
    rm -rf "$c"
}
