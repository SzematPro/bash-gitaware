# tests/scenarios.sh -- prompt rendering scenarios.
#
# Each function below sets up a state, renders the prompt, and asserts on the
# expanded PS1 string. Sourced by run.sh; uses helpers from lib.sh.

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
