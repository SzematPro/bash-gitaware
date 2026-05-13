# tests/scenarios.sh -- prompt rendering scenarios.
#
# Each function below sets up a state, renders the prompt, and asserts on the
# expanded PS1 string. Sourced by run.sh; uses helpers from lib.sh.
# shellcheck shell=bash

scenario_non_git_path() {
    section "non-git path"
    local out; out="$(bga_render /tmp)"
    assert_contains "$out" "tmp"     "/tmp shown"
    # Prompt symbol appears (a reset escape sits between the glyph and the
    # trailing space, so match the glyph alone). The unicode tier uses ❯.
    assert_contains "$out" "❯"       "prompt symbol ❯"
    # No git info expected.
    assert_lacks    "$out" "on "     "no git 'on branch' segment"
}

scenario_clean_git_repo() {
    section "clean git repo"
    local d; d="$(mktemp_repo)"
    (cd "$d" && git commit --allow-empty -qm "initial commit")
    local repo_name; repo_name="$(basename "$d")"

    local out; out="$(bga_render "$d")"
    assert_contains "$out" "$repo_name"  "repo name shown as path lead"
    assert_contains "$out" "on "         "'on' connector"
    assert_contains "$out" "main"        "branch 'main'"
    # Clean tree: no dirty marker (●).
    assert_lacks    "$out" "●"           "no dirty marker"

    rm -rf "$d"
}

scenario_dirty_git_repo() {
    section "dirty git repo"
    local d; d="$(mktemp_repo)"
    (cd "$d" && git commit --allow-empty -qm "initial commit" && printf 'x' > untracked.txt)

    local out; out="$(bga_render "$d")"
    assert_contains "$out" "●"           "dirty marker"

    rm -rf "$d"
}

scenario_ahead_of_remote() {
    section "ahead of remote"
    # Set up: bare 'remote', clone, commit, ahead by 2.
    local remote; remote="$(mktemp -d "${TMPDIR:-/tmp}/bga-remote-XXXXXX")"
    git -C "$remote" init -q --bare -b main
    local d; d="$(mktemp_repo)"
    (
        cd "$d" || exit 1
        git remote add origin "$remote"
        git commit --allow-empty -qm "c1"
        git push -q -u origin main
        git commit --allow-empty -qm "c2"
        git commit --allow-empty -qm "c3"
    ) >/dev/null 2>&1

    local out; out="$(bga_render "$d")"
    assert_contains "$out" "↑2"          "ahead by 2 (↑2)"
    assert_lacks    "$out" "↓"           "not behind"

    rm -rf "$d" "$remote"
}

scenario_detached_head() {
    section "detached HEAD"
    local d; d="$(mktemp_repo)"
    (
        cd "$d" || exit 1
        git commit --allow-empty -qm "c1"
        git commit --allow-empty -qm "c2"
        local first; first="$(git rev-list --max-parents=0 HEAD)"
        git -c advice.detachedHead=false checkout -q "$first"
    ) >/dev/null 2>&1

    local out; out="$(bga_render "$d")"
    assert_contains "$out" "detached@"    "detached@hash shown"

    rm -rf "$d"
}

scenario_rebase_state() {
    section "rebase in progress (state from fs only)"
    local d; d="$(mktemp_repo)"
    (
        cd "$d" || exit 1
        # Simulate a rebase state by creating .git/rebase-merge/ -- the state
        # detector reads from the filesystem and does not invoke git.
        mkdir -p .git/rebase-merge
        printf '2\n' > .git/rebase-merge/msgnum
        printf '5\n' > .git/rebase-merge/end
        git commit --allow-empty -qm "c1"
    ) >/dev/null 2>&1

    local out; out="$(bga_render "$d")"
    assert_contains "$out" "REBASE 2/5"   "REBASE 2/5"

    rm -rf "$d"
}

scenario_no_color() {
    section "NO_COLOR respected"
    local out; out="$(bga_render /tmp "NO_COLOR=1")"
    # No ANSI CSI sequence ESC[ should appear.
    case "$out" in
        *$'\033['*) fail "NO_COLOR: ANSI escape leaked" ;;
        *)          ok   "NO_COLOR: no ANSI escapes" ;;
    esac
    assert_contains "$out" "❯"           "still has prompt symbol"
}

scenario_ascii_glyphs() {
    section "BASHGITAWARE_GLYPHS=ascii"
    local d; d="$(mktemp_repo)"
    (cd "$d" && git commit --allow-empty -qm "init" && printf 'x' > new.txt) >/dev/null 2>&1

    local out; out="$(bga_render "$d" "BASHGITAWARE_GLYPHS=ascii")"
    assert_contains "$out" "*"           "ascii dirty marker (*)"
    assert_lacks    "$out" "●"           "no unicode dirty marker"
    # A reset escape sits between '>' and the trailing space; match the symbol alone.
    assert_contains "$out" ">"           "ascii prompt symbol (>)"

    rm -rf "$d"
}

scenario_preset_minimal() {
    section "BASHGITAWARE_PRESET=minimal"
    local d; d="$(mktemp_repo)"
    (cd "$d" && git commit --allow-empty -qm "init") >/dev/null 2>&1

    local out; out="$(bga_render "$d" "BASHGITAWARE_PRESET=minimal")"
    # minimal sets BASHGITAWARE_GLYPHS=ascii by default.
    assert_contains "$out" ">"   "minimal: ascii prompt symbol"
    assert_lacks    "$out" "❯"   "minimal: no unicode prompt symbol"
    # minimal sets BASHGITAWARE_COMMIT_LINE=0 -- no commit subject line.
    assert_lacks    "$out" "init" "minimal: no last-commit-subject line"

    # User override still wins: explicitly set unicode glyphs.
    out="$(bga_render "$d" "BASHGITAWARE_PRESET=minimal" "BASHGITAWARE_GLYPHS=unicode")"
    assert_contains "$out" "❯"   "minimal + BASHGITAWARE_GLYPHS=unicode: override wins"

    rm -rf "$d"
}

scenario_preset_default() {
    section "BASHGITAWARE_PRESET=default"
    local d; d="$(mktemp_repo)"
    (cd "$d" && git commit --allow-empty -qm "init") >/dev/null 2>&1

    local out; out="$(bga_render "$d" "BASHGITAWARE_PRESET=default")"
    assert_contains "$out" "❯"    "default: unicode prompt symbol"
    assert_contains "$out" "init"  "default: commit line shown"

    rm -rf "$d"
}

scenario_preset_powerline() {
    section "BASHGITAWARE_PRESET=powerline"
    local d; d="$(mktemp_repo)"
    (cd "$d" && git commit --allow-empty -qm "init") >/dev/null 2>&1

    local out; out="$(bga_render "$d" "BASHGITAWARE_PRESET=powerline")"
    # powerline sets BASHGITAWARE_NERD_FONT=1 -- the Powerline branch glyph
    # (U+E0A0, UTF-8: ee 82 a0) appears before the branch name.
    assert_contains "$out" $'\xee\x82\xa0' "powerline: Nerd Font branch glyph "

    rm -rf "$d"
}

scenario_preset_full() {
    section "BASHGITAWARE_PRESET=full"
    local d; d="$(mktemp_repo)"
    (cd "$d" && git commit --allow-empty -qm "init") >/dev/null 2>&1

    local out; out="$(bga_render "$d" "BASHGITAWARE_PRESET=full")"
    # full sets BASHGITAWARE_SHOW_HOST=always -- user@host is shown even
    # outside SSH/root.
    assert_contains "$out" "@"     "full: user@host shown (with '@')"
    # Commit line still shown (default behaviour, full keeps it).
    assert_contains "$out" "init"  "full: commit line shown"

    rm -rf "$d"
}

scenario_osc_default() {
    section "OSC 133 + OSC 7 enabled by default"
    local out; out="$(bga_render /tmp)"
    # OSC 133;A and 133;B wrap the PS1 content. Escape: ESC ] 1 3 3 ; A BEL.
    assert_contains "$out" $'\e]133;A\a' "PS1 emits OSC 133;A"
    assert_contains "$out" $'\e]133;B\a' "PS1 emits OSC 133;B"

    # PS0 (set in lib/70-osc.bash at source time) carries OSC 133;C.
    local ps0
    ps0="$(bash --norc --noprofile -i -c "
        export HOME='$HOME' PATH='$PATH' TERM='xterm-256color' LANG='C.UTF-8' COLUMNS=120
        source '$REPO/new.bashrc'
        printf '%s' \"\$PS0\"
    " 2>/dev/null)"
    assert_contains "$ps0" $'\e]133;C\a' "PS0 emits OSC 133;C"
}

scenario_osc_disabled() {
    section "BASHGITAWARE_OSC=0 disables all OSC 133"
    local out; out="$(bga_render /tmp "BASHGITAWARE_OSC=0")"
    case "$out" in
        *$'\e]133;'*) fail "BASHGITAWARE_OSC=0: 133 leaked" ;;
        *)            ok   "BASHGITAWARE_OSC=0: no 133 sequences" ;;
    esac

    # PS0 stays empty.
    local ps0
    ps0="$(bash --norc --noprofile -i -c "
        export HOME='$HOME' PATH='$PATH' TERM='xterm-256color' LANG='C.UTF-8' COLUMNS=120 BASHGITAWARE_OSC=0
        source '$REPO/new.bashrc'
        printf '%s' \"\$PS0\"
    " 2>/dev/null)"
    case "$ps0" in
        '') ok   "BASHGITAWARE_OSC=0: PS0 stays empty" ;;
        *)  fail "BASHGITAWARE_OSC=0: PS0 leaked: $(printf '%q' "$ps0")" ;;
    esac
}

scenario_transient_basic() {
    section "transient: collapse prints symbol + typed command (exit 0)"
    local out
    out="$(bash --norc --noprofile -i -c "
        export HOME='$HOME' PATH='$PATH' TERM='xterm-256color' LANG='C.UTF-8' COLUMNS=120
        source '$REPO/new.bashrc'
        _bga_transient_lines=3
        _bga_transient_exit=0
        _bga_transient_active=1
        READLINE_LINE='ls -la'
        __bga_transient_collapse
    " 2>/dev/null)"
    # Move up 2 rows (lines - 1 = 2) -> ESC[2A.
    assert_contains "$out" $'\e[2A' "moves cursor up (\e[2A) for 3-line prompt"
    # Clear from cursor to end of screen.
    assert_contains "$out" $'\e[J'  "clears to end of screen (\e[J)"
    # Bold green for success.
    assert_contains "$out" $'\e[1;32m' "bold green symbol on exit 0"
    # The typed command is preserved in scrollback.
    assert_contains "$out" "ls -la" "preserves the typed command"
}

scenario_transient_error_exit() {
    section "transient: red symbol when previous command failed"
    local out
    out="$(bash --norc --noprofile -i -c "
        export HOME='$HOME' PATH='$PATH' TERM='xterm-256color' LANG='C.UTF-8' COLUMNS=120
        source '$REPO/new.bashrc'
        _bga_transient_lines=2
        _bga_transient_exit=1
        _bga_transient_active=1
        READLINE_LINE='false'
        __bga_transient_collapse
    " 2>/dev/null)"
    assert_contains "$out" $'\e[1;31m' "bold red symbol on non-zero exit"
    assert_contains "$out" "false"     "preserves the typed command"
}

scenario_transient_disabled() {
    section "BASHGITAWARE_TRANSIENT=0 short-circuits the collapse"
    local out
    out="$(bash --norc --noprofile -i -c "
        export HOME='$HOME' PATH='$PATH' TERM='xterm-256color' LANG='C.UTF-8' COLUMNS=120 BASHGITAWARE_TRANSIENT=0
        source '$REPO/new.bashrc'
        _bga_transient_lines=3
        _bga_transient_exit=0
        _bga_transient_active=1
        READLINE_LINE='ls -la'
        __bga_transient_collapse
    " 2>/dev/null)"
    case "$out" in
        '') ok   "BASHGITAWARE_TRANSIENT=0: empty output" ;;
        *)  fail "BASHGITAWARE_TRANSIENT=0: produced output: $(printf '%q' "$out")" ;;
    esac
}

scenario_transient_first_prompt() {
    section "transient: no-op until first prompt has been drawn"
    local out
    out="$(bash --norc --noprofile -i -c "
        export HOME='$HOME' PATH='$PATH' TERM='xterm-256color' LANG='C.UTF-8' COLUMNS=120
        source '$REPO/new.bashrc'
        # _bga_transient_active stays 0 -- no prompt has been rendered yet.
        READLINE_LINE='whatever'
        __bga_transient_collapse
    " 2>/dev/null)"
    case "$out" in
        '') ok   "first prompt: no-op (empty output)" ;;
        *)  fail "first prompt: should be no-op but got: $(printf '%q' "$out")" ;;
    esac
}

scenario_async_first_render_no_dirty() {
    section "async (cheap path): first render shows branch but no dirty marker"
    local d; d="$(mktemp_repo)"
    (cd "$d" && git commit --allow-empty -qm "init" && printf 'x' > new.txt) >/dev/null 2>&1

    local out; out="$(bga_render "$d" "BASHGITAWARE_ASYNC=1")"
    assert_contains "$out" "main"        "branch shown via cheap path"
    assert_lacks    "$out" "●"           "dirty marker absent on first render (async pending)"

    rm -rf "$d"
}

scenario_async_two_render_cache_hit() {
    section "async (deferred): second render reads cache and shows dirty"
    local d; d="$(mktemp_repo)"
    (cd "$d" && git commit --allow-empty -qm "init" && printf 'x' > new.txt) >/dev/null 2>&1

    # Two-render sequence: first dispatches, wait for the background job,
    # second reads the cache and renders with full info.
    local out
    out="$(bash --norc --noprofile -i -c "
        export HOME='$HOME' PATH='$PATH' TERM='xterm-256color' LANG='C.UTF-8' COLUMNS=120 BASHGITAWARE_ASYNC=1
        cd '$d' 2>/dev/null
        source '$REPO/new.bashrc'
        __bga_prompt
        [ -n \"\$_bga_async_pid\" ] && wait \"\$_bga_async_pid\" 2>/dev/null
        __bga_prompt
        printf '%s' \"\${PS1@P}\"
    " 2>/dev/null)"
    assert_contains "$out" "●"           "second render picks up dirty marker from cache"

    rm -rf "$d"
}

scenario_async_exit_trap_installed() {
    section "async (default): EXIT trap is installed for cleanup"
    local out
    out="$(bash --norc --noprofile -i -c "
        export HOME='$HOME' PATH='$PATH' TERM='xterm-256color' LANG='C.UTF-8' COLUMNS=120 BASHGITAWARE_ASYNC=1
        source '$REPO/new.bashrc'
        trap -p EXIT
    " 2>/dev/null)"
    assert_contains "$out" "__bga_async_cleanup" "EXIT trap calls __bga_async_cleanup"
}

scenario_async_disabled_no_trap() {
    section "BASHGITAWARE_ASYNC=0: no async EXIT trap installed"
    local out
    out="$(bash --norc --noprofile -i -c "
        export HOME='$HOME' PATH='$PATH' TERM='xterm-256color' LANG='C.UTF-8' COLUMNS=120 BASHGITAWARE_ASYNC=0
        source '$REPO/new.bashrc'
        trap -p EXIT
    " 2>/dev/null)"
    case "$out" in
        *__bga_async_cleanup*) fail "BASHGITAWARE_ASYNC=0 should NOT install async EXIT trap" ;;
        *)                     ok   "BASHGITAWARE_ASYNC=0: no async EXIT trap installed" ;;
    esac
}

scenario_transient_state_tracked() {
    section "transient: __bga_prompt records lines + exit + active"
    local out
    out="$(bash --norc --noprofile -i -c "
        export HOME='$HOME' PATH='$PATH' TERM='xterm-256color' LANG='C.UTF-8' COLUMNS=120
        cd /tmp 2>/dev/null
        source '$REPO/new.bashrc'
        __bga_prompt
        printf 'lines=%d exit=%d active=%d' \"\$_bga_transient_lines\" \"\$_bga_transient_exit\" \"\$_bga_transient_active\"
    " 2>/dev/null)"
    case "$out" in
        *"lines=0 "*) fail "_bga_transient_lines should be > 0 after __bga_prompt (got: $out)" ;;
        *"lines="*)   ok   "_bga_transient_lines set after __bga_prompt ($out)" ;;
        *)            fail "expected 'lines=N' in output: $(printf '%q' "$out")" ;;
    esac
    assert_contains "$out" "active=1" "_bga_transient_active set to 1"
}

scenario_install_replace() {
    section "install.sh --replace (writes new.bashrc to target)"
    local target; target="$(mktemp "${TMPDIR:-/tmp}/bga-install-XXXXXX")"
    bash "$REPO/install.sh" --replace --target "$target" --no-backup >/dev/null 2>&1
    if cmp -s "$REPO/new.bashrc" "$target"; then
        ok   "install.sh --replace: target matches new.bashrc"
    else
        fail "install.sh --replace: target differs from new.bashrc"
    fi
    rm -f "$target"
}

scenario_install_append_idempotent() {
    section "install.sh --append (idempotent + preserves existing content)"
    local target; target="$(mktemp "${TMPDIR:-/tmp}/bga-install-XXXXXX")"
    printf '# pre-existing user content\nexport USER_VAR=42\n' > "$target"

    bash "$REPO/install.sh" --append --target "$target" >/dev/null 2>&1
    local count1; count1="$(grep -c -F "$REPO/new.bashrc" "$target" || true)"
    bash "$REPO/install.sh" --append --target "$target" >/dev/null 2>&1
    local count2; count2="$(grep -c -F "$REPO/new.bashrc" "$target" || true)"

    if [ "$count1" = 1 ] && [ "$count2" = 1 ]; then
        ok   "install.sh --append: source line present exactly once after 2 runs (idempotent)"
    else
        fail "install.sh --append: not idempotent (after first run: $count1, after second: $count2)"
    fi
    if grep -qF "pre-existing user content" "$target"; then
        ok   "install.sh --append: pre-existing content preserved"
    else
        fail "install.sh --append: pre-existing content was lost"
    fi
    rm -f "$target"
}

scenario_install_help() {
    section "install.sh --help (prints usage)"
    local out; out="$(bash "$REPO/install.sh" --help 2>&1)"
    assert_contains "$out" "Usage:"   "install.sh --help shows 'Usage:'"
    assert_contains "$out" "--replace" "install.sh --help mentions --replace"
    assert_contains "$out" "--append"  "install.sh --help mentions --append"
}

scenario_path_maxdepth() {
    section "BASHGITAWARE_PATH_MAXDEPTH"
    # Build a path that is more than 3 components deep.
    local base; base="$(mktemp -d "${TMPDIR:-/tmp}/bga-deep-XXXXXX")"
    local deep="$base/a/b/c/d/e"
    mkdir -p "$deep"

    local out; out="$(bga_render "$deep")"
    assert_contains "$out" "…"           "ellipsis when path exceeds maxdepth"
    assert_contains "$out" "e"           "last component (e) preserved"

    # Explicit maxdepth=0 = unlimited; no ellipsis.
    out="$(bga_render "$deep" "BASHGITAWARE_PATH_MAXDEPTH=0")"
    assert_lacks    "$out" "…"           "no ellipsis with maxdepth=0"

    rm -rf "$base"
}
