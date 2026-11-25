# tests/cli.sh -- the bga command-line tool (lib/94-cli.bash, bin/bga).
# shellcheck shell=bash disable=SC2016  # payloads are literal on purpose

_bga_cmd() { "$REPO/bin/bga" "$@"; }

scenario_cli_basics() {
    section "bga: help, version, usage errors"
    local out rc
    out="$(_bga_cmd version)";           assert_contains "$out" "bash-gitaware 3." "version"
    out="$(_bga_cmd help)";              assert_contains "$out" "usage: bga" "help"
    _bga_cmd nosuch >/dev/null 2>&1; rc=$?
    if [ "$rc" = 2 ]; then ok "unknown command exits 2"; else fail "unknown command exit $rc"; fi
    _bga_cmd reload >/dev/null 2>&1; rc=$?
    if [ "$rc" = 1 ]; then ok "reload refused outside an interactive shell"; else fail "reload exit $rc"; fi
}

scenario_cli_config() {
    section "bga config: validated, atomic, keeps comments"
    local dir; dir="$(mktemp -d "${TMPDIR:-/tmp}/bga-cli-XXXXXX")"
    local f="$dir/sub/config" out rc
    export BASHGITAWARE_CONFIG="$f"
    _bga_cmd config set glyphs ascii;   rc=$?
    if [ "$rc" = 0 ] && [ -f "$f" ]; then ok "set creates the file"; else fail "set failed ($rc)"; fi
    case "$(stat -c '%a' "$f" 2>/dev/null || stat -f '%Lp' "$f")" in 600) ok "file is 0600" ;; *) fail "file mode not 0600" ;; esac
    printf '# my comment\nstyle = classic\n' >> "$f"
    _bga_cmd config set glyphs unicode; rc=$?
    if [ "$rc" = 0 ]; then ok "set on an existing key exits 0"; else fail "set on an existing key exit $rc"; fi
    out="$(cat "$f")"
    assert_contains "$out" "# my comment"     "comment kept"
    assert_contains "$out" "style = classic"  "other key kept"
    assert_contains "$out" "glyphs = unicode" "value replaced in place"
    out="$(_bga_cmd config get glyphs)";  assert_contains "$out" "unicode" "get"
    _bga_cmd config set glyphs bogus 2>/dev/null; rc=$?
    if [ "$rc" = 2 ]; then ok "invalid value exits 2"; else fail "invalid value exit $rc"; fi
    _bga_cmd config set colour red 2>/dev/null; rc=$?
    if [ "$rc" = 2 ]; then ok "unknown key exits 2"; else fail "unknown key exit $rc"; fi
    _bga_cmd config set glyphs '$(touch PWNED_CLI)' 2>/dev/null
    if [ -e PWNED_CLI ] || [ -e "$dir/PWNED_CLI" ]; then fail "value executed"; else ok "value not executed"; fi
    _bga_cmd config unset glyphs
    out="$(_bga_cmd config list)"
    assert_lacks    "$out" "glyphs"           "unset removes the key"
    assert_contains "$out" "style = classic"  "list shows the rest"
    ln -s "$f" "$dir/link"
    BASHGITAWARE_CONFIG="$dir/link" _bga_cmd config set glyphs ascii 2>/dev/null; rc=$?
    if [ "$rc" = 1 ] && [ -L "$dir/link" ]; then ok "symlinked config not replaced"; else fail "symlink handling ($rc)"; fi
    # SR4: a directory at the config path is refused; control characters in
    # the file never reach the terminal through list or loader warnings.
    mkdir -p "$dir/isdir/config"
    BASHGITAWARE_CONFIG="$dir/isdir/config" _bga_cmd config set glyphs ascii 2>/dev/null; rc=$?
    if [ "$rc" = 1 ]; then ok "directory at the config path refused"; else fail "directory path exit $rc"; fi
    printf 'style = classic\n\033]0;PWN\a = 1\n' > "$dir/esc"; chmod 600 "$dir/esc"
    out="$(BASHGITAWARE_CONFIG="$dir/esc" _bga_cmd config list 2>&1; BASHGITAWARE_CONFIG="$dir/esc" _bga_cmd doctor 2>&1)"
    assert_lacks "$out" $'\e]0;PWN' "no raw escape from the config file"
    unset BASHGITAWARE_CONFIG
    rm -rf "$dir"
}

scenario_cli_theme_and_doctor() {
    section "bga theme and doctor"
    local dir; dir="$(mktemp -d "${TMPDIR:-/tmp}/bga-cli-XXXXXX")"
    local out rc
    export BASHGITAWARE_CONFIG="$dir/config"
    out="$(_bga_cmd theme list)";       assert_contains "$out" "aware" "theme list"
    _bga_cmd theme set nosuch 2>/dev/null; rc=$?
    if [ "$rc" = 2 ]; then ok "unknown theme exits 2"; else fail "unknown theme exit $rc"; fi
    _bga_cmd theme set aware >/dev/null
    assert_contains "$(cat "$dir/config")" "theme = aware" "theme set writes the config"
    out="$(TERM=xterm-256color BASHGITAWARE_MODE=full _bga_cmd theme preview aware)"
    assert_contains "$out" $'\e[1;38;5;75m' "preview uses the theme colors"
    out="$(_bga_cmd doctor)"; rc=$?
    assert_contains "$out" "bash " "doctor reports bash"
    if [ "$rc" = 0 ]; then ok "doctor exits 0 on a healthy setup"; else fail "doctor exit $rc"; fi
    printf 'glyphs = bogus\n' > "$dir/config"
    out="$(_bga_cmd doctor 2>&1)"; rc=$?
    if [ "$rc" = 1 ]; then ok "doctor exits 1 on an invalid config"; else fail "doctor exit $rc on bad config"; fi
    unset BASHGITAWARE_CONFIG
    rm -rf "$dir"
}

scenario_cli_shell_function() {
    section "bga as a shell function: available, reload is idempotent"
    local out
    out="$(bash --norc --noprofile -i -c "
        export HOME='$HOME' PATH='$PATH' TERM=dumb LANG=C.UTF-8 BASHGITAWARE_MODE=full
        source '$REPO/new.bashrc'
        bga version; a=\"\$PROMPT_COMMAND|\$(trap -p EXIT)\"
        bga reload; b=\"\$PROMPT_COMMAND|\$(trap -p EXIT)\"
        [ \"\$a\" = \"\$b\" ] && echo reload-same" 2>/dev/null)"
    assert_contains "$out" "bash-gitaware 3." "bga function in an interactive shell"
    assert_contains "$out" "reload-same"      "reload leaves hooks unchanged"
}

scenario_cli_reload_keeps_runtime() {
    section "bga reload: runtimes still shown afterwards"
    local base; base="$(mktemp -d "${TMPDIR:-/tmp}/bga-cli-XXXXXX")"
    mkdir -p "$base/bin"; printf '{}\n' > "$base/package.json"
    printf '#!/bin/sh\necho v20.1.0\n' > "$base/bin/node"; chmod +x "$base/bin/node"
    local out
    out="$(env -u BASHGITAWARE_STYLE bash --norc --noprofile -i -c "
        export HOME='$HOME' PATH='$base/bin:$PATH' TERM=xterm-256color LANG=C.UTF-8 BASHGITAWARE_MODE=full COLUMNS=80
        cd '$base'; source '$REPO/new.bashrc'; __bga_prompt
        bga reload; __bga_prompt; printf '%s' \"\${PS1@P}\"" 2>/dev/null)"
    assert_contains "$out" "node 20.1.0" "runtime shown after reload"
    rm -rf "$base"
}
