# tests/shell.sh -- the shell-defaults module (shell_defaults) and PATH.
# shellcheck shell=bash disable=SC2016  # payloads are literal on purpose

# Source new.bashrc in an interactive bash with HOME=$1, run $3 after it;
# $2 runs before sourcing (environment set-up). stderr is kept.
_sd_run() {
    bash --norc --noprofile -i -c "
        export HOME='$1' PATH='$PATH' TERM='xterm-256color' LANG='C.UTF-8'
        unset LS_COLORS XDG_CONFIG_HOME BASHGITAWARE_CONFIG   # default path under the fake HOME
        $2
        source '$REPO/new.bashrc'
        $3
    " 2>&1 | grep -av -e 'cannot set terminal process group' -e 'no job control in this shell'
}

# The facts each check looks at, on one line.
_sd_probe='
    a=no; alias gs >/dev/null 2>&1 && a=yes
    m=no; [ -n "${BGA_TEST_ALIASES_MARK:-}" ] && m=yes
    c=no; [ -n "${LS_COLORS+set}" ] && c=yes
    w=no; shopt -q checkwinsize && w=yes
    echo "alias=$a hist=$HISTSIZE bash_aliases=$m lscolors=$c checkwinsize=$w path=$PATH"'

scenario_shell_defaults() {
    section "shell defaults: shell_defaults gates the module"
    local h; h="$(mktemp -d "${TMPDIR:-/tmp}/bga-sd-XXXXXX")"
    mkdir -p "$h/.config/bash-gitaware"; chmod 700 "$h" "$h/.config" "$h/.config/bash-gitaware"
    printf 'BGA_TEST_ALIASES_MARK=1\n' > "$h/.bash_aliases"
    local pre='HISTSIZE=77' out

    # Unset: 3.0 behavior (on).
    out="$(_sd_run "$h" "$pre" "$_sd_probe")"
    assert_contains "$out" "alias=yes hist=10000 bash_aliases=yes" "unset: module on (3.0 behavior)"
    if command -v dircolors >/dev/null 2>&1 && [ -x /usr/bin/dircolors ]; then
        assert_contains "$out" "lscolors=yes" "unset: dircolors evaluated"
    else
        skip "unset: dircolors evaluated (no /usr/bin/dircolors)"
    fi

    # Off from the environment.
    out="$(_sd_run "$h" "$pre; export BASHGITAWARE_SHELL_DEFAULTS=0" "$_sd_probe")"
    assert_contains "$out" "alias=no hist=77 bash_aliases=no lscolors=no" "env 0: no aliases, history, ~/.bash_aliases or dircolors"
    assert_contains "$out" "checkwinsize=yes" "env 0: checkwinsize still on (the prompt needs COLUMNS)"

    # Off from the config file.
    printf 'shell_defaults = 0\n' > "$h/.config/bash-gitaware/config"; chmod 600 "$h/.config/bash-gitaware/config"
    out="$(_sd_run "$h" "$pre" "$_sd_probe")"
    assert_contains "$out" "alias=no hist=77 bash_aliases=no" "config 0: module off"
    assert_lacks    "$out" "bash-gitaware:" "config 0: no warning"

    # Environment wins over the file.
    out="$(_sd_run "$h" "$pre; export BASHGITAWARE_SHELL_DEFAULTS=1" "$_sd_probe")"
    assert_contains "$out" "alias=yes hist=10000" "env 1 overrides config 0"

    # Invalid value: warned, ignored, so the key stays unset (on).
    printf 'shell_defaults = maybe\n' > "$h/.config/bash-gitaware/config"
    out="$(_sd_run "$h" "$pre" "$_sd_probe")"
    assert_contains "$out" "config:1: invalid value for 'shell_defaults'" "invalid value warned with its line"
    assert_contains "$out" "alias=yes" "invalid value ignored: unset means on"

    # bash-completion only with the module on (where the system has it).
    if [ -f /usr/share/bash-completion/bash_completion ] || [ -f /etc/bash_completion ]; then
        rm -f "$h/.config/bash-gitaware/config"
        out="$(_sd_run "$h" '' 'declare -F _init_completion >/dev/null && echo comp=yes || echo comp=no')"
        assert_contains "$out" "comp=yes" "on: bash-completion loaded"
        out="$(_sd_run "$h" 'export BASHGITAWARE_SHELL_DEFAULTS=0' 'declare -F _init_completion >/dev/null && echo comp=yes || echo comp=no')"
        assert_contains "$out" "comp=no" "off: bash-completion not loaded"
    else
        skip "bash-completion gating (not installed)"
    fi
    rm -rf "$h"
}

scenario_shell_path_untouched() {
    section "shell defaults: PATH is never changed"
    local h; h="$(mktemp -d "${TMPDIR:-/tmp}/bga-sd-XXXXXX")"; chmod 700 "$h"
    local v out
    for v in '' 0 1; do
        out="$(_sd_run "$h" "${v:+export BASHGITAWARE_SHELL_DEFAULTS=$v}" 'echo "path=$PATH"')"
        assert_contains "$out" "path=$PATH" "PATH unchanged (shell_defaults=${v:-unset})"
        assert_lacks    "$out" ".npm-global" "no ~/.npm-global/bin (shell_defaults=${v:-unset})"
    done
    rm -rf "$h"
}
