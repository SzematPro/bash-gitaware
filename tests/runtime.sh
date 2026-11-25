# tests/runtime.sh -- Ruby, Deno, Bun, Java runtimes and the runtimes key (3.1, S6).
# shellcheck shell=bash disable=SC2016  # payloads are literal on purpose

# Visible text of a rendered prompt: color/cursor escapes and \001 \002 dropped.
_rt_visible() {
    local s="$1"
    s="$(printf '%s' "$s" | sed -E $'s/\x1b\\[[0-9;]*[A-Za-z]//g; s/\x1b[78]//g; s/\x1b\\][^\a]*\a//g; s/[\x01\x02]//g')"
    printf '%s' "$s"
}

scenario_runtime_new_runtimes() {
    section "runtimes: ruby, deno, bun, java from version files"
    local d out; d="$(mktemp -d "${TMPDIR:-/tmp}/bga-rt-XXXXXX")"
    mkdir -p "$d/rb" "$d/rb2" "$d/dn" "$d/bn" "$d/jv" "$d/jv2" "$d/all"
    printf 'ruby-3.3.0\n' > "$d/rb/.ruby-version"
    : > "$d/rb2/Gemfile"
    printf '{}\n' > "$d/dn/deno.jsonc"
    : > "$d/bn/bun.lock"
    printf '21\n' > "$d/jv/.java-version"
    printf '# sdkman\nmaven=3.9.6\njava=17.0.9-tem\n' > "$d/jv2/.sdkmanrc"
    printf '3.2.2\n' > "$d/all/.ruby-version"; printf '{}\n' > "$d/all/deno.json"
    : > "$d/all/bunfig.toml"; printf '21\n' > "$d/all/.java-version"

    out="$(_rt_visible "$(bga_render "$d/rb")")";  assert_contains "$out" "ruby 3.3.0" "ruby: .ruby-version, ruby- prefix dropped"
    out="$(_rt_visible "$(bga_render "$d/rb2")")"; assert_contains "$out" "ruby" "ruby: Gemfile alone, no version"
    assert_lacks "$out" "ruby 3" "ruby: no version invented without a version file"
    out="$(_rt_visible "$(bga_render "$d/dn")")";  assert_contains "$out" "deno" "deno: deno.jsonc"
    out="$(_rt_visible "$(bga_render "$d/bn")")";  assert_contains "$out" "bun" "bun: bun.lock"
    out="$(_rt_visible "$(bga_render "$d/jv")")";  assert_contains "$out" "java 21" "java: .java-version"
    out="$(_rt_visible "$(bga_render "$d/jv2")")"; assert_contains "$out" "java 17.0.9-tem" "java: java= line of .sdkmanrc"
    out="$(_rt_visible "$(bga_render "$d/all" BASHGITAWARE_STYLE=classic)")"
    assert_contains "$out" "via ruby 3.2.2 via deno via bun via java 21" "classic layout: all four, in order"

    # runtimes key: only the listed ones; runtime = 0 still wins.
    out="$(_rt_visible "$(bga_render "$d/all" BASHGITAWARE_RUNTIMES=java,deno)")"
    assert_contains "$out" "deno" "runtimes=java,deno: deno shown"
    assert_contains "$out" "java 21" "runtimes=java,deno: java shown"
    assert_lacks    "$out" "ruby" "runtimes=java,deno: ruby hidden"
    out="$(_rt_visible "$(bga_render "$d/all" BASHGITAWARE_RUNTIMES=java BASHGITAWARE_RUNTIME=0)")"
    assert_lacks    "$out" "java" "runtime=0 wins over runtimes"
    rm -rf "$d"
}

scenario_runtime_no_exec() {
    section "runtimes: the new ones never run a program"
    local d bin out; d="$(mktemp -d "${TMPDIR:-/tmp}/bga-rt-XXXXXX")"; bin="$d/bin"
    mkdir -p "$bin" "$d/p"
    local t
    for t in ruby deno bun java; do
        printf '#!/bin/sh\n: > "%s/RAN_%s"\necho 9.9.9\n' "$d" "$t" > "$bin/$t"; chmod 755 "$bin/$t"
    done
    : > "$d/p/Gemfile"; printf '{}\n' > "$d/p/deno.json"; : > "$d/p/bun.lockb"; : > "$d/p/.sdkmanrc"
    out="$(PATH="$bin:$PATH" bga_render "$d/p")"
    for t in ruby deno bun java; do
        if [ -e "$d/RAN_$t" ]; then fail "$t was executed"; else ok "$t not executed"; fi
    done
    assert_lacks "$(_rt_visible "$out")" "9.9.9" "no version taken from a program"
    rm -rf "$d"
}

scenario_runtime_hostile_version_files() {
    section "runtimes: hostile version files are shown, never run"
    local d out; d="$(mktemp -d "${TMPDIR:-/tmp}/bga-rt-XXXXXX")"
    mkdir -p "$d/r" "$d/j"
    printf '$(touch %s/PWNED_RB)`touch %s/PWNED_RB2`\e]0;x\a\n' "$d" "$d" > "$d/r/.ruby-version"
    printf 'java=$(touch %s/PWNED_JV)\e[31m\n' "$d" > "$d/j/.sdkmanrc"
    out="$(bga_render "$d/r")"; out+="$(bga_render "$d/j")"
    if [ -e "$d/PWNED_RB" ] || [ -e "$d/PWNED_RB2" ] || [ -e "$d/PWNED_JV" ]; then
        fail "a version file was executed"
    else
        ok "version files with \$(...) and backticks not executed"
    fi
    case "$out" in *$'\e]0;x'* | *$'\e[31m'*) fail "escape sequence from a version file reached the terminal" ;;
                   *) ok "escape sequences from version files stripped" ;; esac
    rm -rf "$d"
}

scenario_runtime_key_validation() {
    section "runtimes: the runtimes key is validated"
    local dir f out; dir="$(mktemp -d "${TMPDIR:-/tmp}/bga-rt-XXXXXX")"; f="$dir/config"
    printf 'runtimes = py,cobol\nruntimes = \nruntimes = node,go\n' > "$f"; chmod 600 "$f"
    out="$(bash --norc --noprofile -i -c "export HOME='$HOME' PATH='$PATH' BASHGITAWARE_CONFIG='$f'; source '$REPO/new.bashrc'; echo \"r=\$BASHGITAWARE_RUNTIMES\"" 2>&1)"
    assert_contains "$out" "config:1: invalid value for 'runtimes'" "unknown runtime name warned"
    assert_contains "$out" "config:2: invalid value for 'runtimes'" "empty list warned"
    assert_contains "$out" "r=node,go" "valid list applied"
    rm -rf "$dir"
}
