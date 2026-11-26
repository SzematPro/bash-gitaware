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
    # shell_defaults unset (ADR-0010): a notice with the fix, exit status 0.
    assert_contains "$out" "note shell-defaults" "doctor: notice when shell_defaults is unset"
    assert_contains "$out" "bga config set shell_defaults" "doctor: notice says how to choose"
    _bga_cmd config set shell_defaults 0 >/dev/null
    out="$(_bga_cmd doctor)"; rc=$?
    assert_contains "$out" "info shell-defaults off" "doctor: shell_defaults = 0 reported as off"
    assert_lacks    "$out" "note shell-defaults" "doctor: no notice once set"
    if [ "$rc" = 0 ]; then ok "doctor exits 0 with shell_defaults set"; else fail "doctor exit $rc with shell_defaults set"; fi
    out="$(BASHGITAWARE_SHELL_DEFAULTS=yes _bga_cmd doctor)"
    assert_contains "$out" "is not 0 or 1" "doctor: an invalid env value is reported, not shown as unset"
    printf 'glyphs = bogus\n' > "$dir/config"
    out="$(_bga_cmd doctor 2>&1)"; rc=$?
    if [ "$rc" = 1 ]; then ok "doctor exits 1 on an invalid config"; else fail "doctor exit $rc on bad config"; fi
    unset BASHGITAWARE_CONFIG
    rm -rf "$dir"
}

scenario_cli_reload_applies_config() {
    section "bga reload applies config changes (3.0 kept the old values)"
    local dir out; dir="$(mktemp -d "${TMPDIR:-/tmp}/bga-cli-XXXXXX")"
    printf 'theme = light\npreset = minimal\n' > "$dir/config"; chmod 600 "$dir/config"
    out="$(BASHGITAWARE_CONFIG="$dir/config" bash --norc --noprofile -i -c "
        export HOME='$HOME' PATH='$PATH'
        source '$REPO/new.bashrc'
        bga theme set contrast >/dev/null; bga config set preset default
        bga reload >/dev/null 2>&1
        echo \"theme=\$BASHGITAWARE_THEME runtime=\${BASHGITAWARE_RUNTIME:-unset}\"" 2>/dev/null)"
    assert_contains "$out" "theme=contrast runtime=unset" "reload: new config value and preset applied"
    out="$(BASHGITAWARE_CONFIG="$dir/config" BASHGITAWARE_THEME=aware bash --norc --noprofile -i -c "
        export HOME='$HOME' PATH='$PATH'; IFS=:
        source '$REPO/new.bashrc'; bga reload >/dev/null 2>&1
        echo \"theme=\$BASHGITAWARE_THEME\"" 2>/dev/null)"
    assert_contains "$out" "theme=aware" "reload: the user's environment still wins (IFS=:)"
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

scenario_cli_config_edit() {
    section "bga config edit: validated before saving"
    local dir f out rc; dir="$(mktemp -d "${TMPDIR:-/tmp}/bga-cli-XXXXXX")"; f="$dir/cfg/config"
    mkdir -m 700 "$dir/cfg"
    out="$(BASHGITAWARE_CONFIG="$f" _bga_cmd config edit </dev/null 2>&1)"; rc=$?
    if [ "$rc" = 2 ]; then ok "no terminal: exit 2"; else fail "no terminal: exit $rc"; fi
    assert_contains "$out" "needs a terminal" "no terminal: says why"
    if ! command -v script >/dev/null 2>&1 || ! script -qc true /dev/null >/dev/null 2>&1; then
        skip "config edit on a terminal (needs util-linux script)"; rm -rf "$dir"; return
    fi
    # Editors: append a valid line; append an invalid one; fail; invalid
    # first, then fixed on the second run.
    printf '#!/bin/sh\nprintf "clock = 1\\n" >> "$1"\n' > "$dir/ed-ok"
    printf '#!/bin/sh\nprintf "glyphs = bogus\\n" >> "$1"\n' > "$dir/ed-bad"
    printf '#!/bin/sh\nexit 3\n' > "$dir/ed-fail"
    {
        printf '#!/bin/sh\n'
        printf 'mark=%s/n\n' "$dir"
        printf '%s\n' 'if [ -e "$mark" ]; then' \
            '  sed "s/bogus/ascii/" "$1" > "$1.n" && cat "$1.n" > "$1" && rm -f "$1.n"' \
            'else' '  : > "$mark"; printf "glyphs = bogus\n" >> "$1"' 'fi'
    } > "$dir/ed-fix"
    chmod 755 "$dir"/ed-*
    printf '# keep this comment\ntheme = light\n' > "$f"; chmod 600 "$f"
    _ce() { printf '%s' "$2" | BASHGITAWARE_CONFIG="$f" EDITOR="$dir/$1" VISUAL='' script -qc "'$REPO/bin/bga' config edit" /dev/null 2>&1; }

    out="$(_ce ed-ok '')"
    assert_contains "$(cat "$f")" "clock = 1" "valid edit saved"
    assert_contains "$(cat "$f")" "# keep this comment" "comments kept"
    if [ -z "$(find "$f" -maxdepth 0 -perm 600 2>/dev/null)" ]; then fail "saved file is not mode 0600"; else ok "saved file is mode 0600"; fi
    assert_contains "$out" "bga reload" "save says how to apply"

    cp "$f" "$dir/before"
    out="$(_ce ed-bad $'d\n')"
    assert_contains "$out" "config:4: invalid value for 'glyphs'" "invalid edit: warning with the line"
    if cmp -s "$f" "$dir/before"; then ok "discard: file unchanged"; else fail "discard changed the file"; fi
    out="$(_ce ed-fix $'e\n')"
    assert_contains "$(cat "$f")" "glyphs = ascii" "edit again: fixed version saved"
    cp "$f" "$dir/before"
    out="$(_ce ed-fail '')"
    assert_contains "$out" "the editor failed" "editor failure reported"
    if cmp -s "$f" "$dir/before"; then ok "editor failure: file unchanged"; else fail "editor failure changed the file"; fi
    local left; left="$(cd "$dir/cfg" && for x in .config.edit.*; do [ -e "$x" ] && printf '%s ' "$x"; done)"
    if [ -n "$left" ]; then fail "temp copy left behind: $left"; else ok "no temp copy left behind"; fi

    # VISUAL wins over EDITOR, and an editor command with arguments gets the
    # file as its last argument.
    printf '#!/bin/sh\nprintf "%%s\\n" "$*" > "%s/args"\nprintf "osc = 0\\n" >> "$3"\n' "$dir" > "$dir/ed-args"; chmod 755 "$dir/ed-args"
    printf '' | BASHGITAWARE_CONFIG="$f" EDITOR="$dir/ed-fail" VISUAL="$dir/ed-args --wait -n" script -qc "'$REPO/bin/bga' config edit" /dev/null >/dev/null 2>&1
    assert_contains "$(cat "$dir/args" 2>/dev/null)" "--wait -n " "VISUAL with arguments used"
    case "$(cat "$dir/args" 2>/dev/null)" in *' -n '*'/.config.edit.'*) ok "the file is the editor's last argument" ;; *) fail "file not passed last" ;; esac
    assert_contains "$(cat "$f")" "osc = 0" "edit through VISUAL saved"
    ln -s "$f" "$dir/link"
    out="$(printf '' | BASHGITAWARE_CONFIG="$dir/link" EDITOR="$dir/ed-ok" script -qc "'$REPO/bin/bga' config edit" /dev/null 2>&1)"
    assert_contains "$out" "is a symlink" "symlinked config refused"
    rm -rf "$dir"
}

scenario_cli_config_unsafe_dir() {
    section "bga config: no writes where other users could swap files (SR6)"
    local dir out rc; dir="$(mktemp -d "${TMPDIR:-/tmp}/bga-cli-XXXXXX")"
    mkdir "$dir/open" "$dir/sticky"; chmod 777 "$dir/open"; chmod 1777 "$dir/sticky"
    out="$(BASHGITAWARE_CONFIG="$dir/open/config" _bga_cmd config set clock 1 2>&1)"; rc=$?
    if [ "$rc" = 1 ] && [ ! -e "$dir/open/config" ]; then ok "set refused in a directory others can write"; else fail "set in an open directory: rc=$rc"; fi
    assert_contains "$out" "writable by other users" "set: says why"
    BASHGITAWARE_CONFIG="$dir/sticky/config" _bga_cmd config set clock 1 >/dev/null 2>&1; rc=$?
    if [ "$rc" = 0 ]; then ok "set allowed in a sticky directory (like /tmp)"; else fail "sticky directory refused ($rc)"; fi
    if command -v script >/dev/null 2>&1 && script -qc true /dev/null >/dev/null 2>&1; then
        out="$(printf '' | BASHGITAWARE_CONFIG="$dir/open/config" EDITOR=true script -qc "'$REPO/bin/bga' config edit" /dev/null 2>&1)"
        assert_contains "$out" "writable by other users" "edit refused in a directory others can write"
        # SR6 F5: an interrupt while the editor runs leaves no temp copy.
        mkdir -m 700 "$dir/cfg"
        printf '#!/bin/sh\nkill -INT 0\nsleep 2\n' > "$dir/ed-int"; chmod 755 "$dir/ed-int"
        printf '' | BASHGITAWARE_CONFIG="$dir/cfg/config" EDITOR="$dir/ed-int" script -qc "'$REPO/bin/bga' config edit" /dev/null >/dev/null 2>&1
        local left; left="$(cd "$dir/cfg" && for x in .config.edit.*; do [ -e "$x" ] && printf '%s ' "$x"; done)"
        if [ -z "$left" ]; then ok "interrupted edit: no temp copy left"; else fail "interrupted edit left: $left"; fi
    else
        skip "config edit refusal and interrupt (needs util-linux script)"
    fi
    rm -rf "$dir"
}

