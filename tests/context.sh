# tests/context.sh -- context segments: kube, aws, tf (3.2, X1; ADR-0014).
# shellcheck shell=bash disable=SC2016  # payloads are literal on purpose

_cx_visible() { printf '%s' "$1" | sed -E $'s/\x1b\\[[0-9;]*[A-Za-z]//g; s/\x1b[78]//g; s/\x1b\\][^\a]*\a//g; s/[\x01\x02]//g'; }

scenario_context_segments() {
    section "contexts: kube, aws, tf (opt-in)"
    local d out; d="$(mktemp -d "${TMPDIR:-/tmp}/bga-cx-XXXXXX")"
    mkdir -p "$d/p/.terraform" "$d/kube"
    printf 'apiVersion: v1\nclusters: []\ncurrent-context: "dev-cluster"\nkind: Config\n' > "$d/kube/config"
    printf 'staging\n' > "$d/p/.terraform/environment"
    out="$(_cx_visible "$(AWS_PROFILE=prod KUBECONFIG="$d/kube/config" bga_render "$d/p")")"
    assert_lacks "$out" "aws prod" "off by default"
    out="$(_cx_visible "$(AWS_PROFILE=prod KUBECONFIG="$d/kube/config:/nonexistent" bga_render "$d/p" BASHGITAWARE_CONTEXTS=kube,aws,tf)")"
    assert_contains "$out" "k8s dev-cluster" "kube: current-context of the first KUBECONFIG file"
    assert_contains "$out" "aws prod" "aws: AWS_PROFILE"
    assert_contains "$out" "tf staging" "tf: .terraform/environment"
    out="$(_cx_visible "$(env -u AWS_PROFILE AWS_VAULT=vaulted bash -c "source '$REPO/tests/lib.sh'; REPO='$REPO'; bga_render '$d/p' BASHGITAWARE_CONTEXTS=aws")")"
    assert_contains "$out" "aws vaulted" "aws: AWS_VAULT when no AWS_PROFILE"
    printf 'current-context: arn:aws:eks:eu-west-1:123456789012:cluster/a-very-long-cluster-name\n' > "$d/kube/long"
    out="$(_cx_visible "$(KUBECONFIG="$d/kube/long" bga_render "$d/p" BASHGITAWARE_CONTEXTS=kube)")"
    assert_contains "$out" "k8s …" "long names shortened from the start"
    assert_contains "$out" "cluster/a-very-long-cluster-name" "long names keep their end"
    out="$(_cx_visible "$(KUBECONFIG="$d/kube/config" bga_render "$d/p" BASHGITAWARE_CONTEXTS=kube BASHGITAWARE_STYLE=classic)")"
    assert_contains "$out" "[k8s dev-cluster]" "classic layout"
    rm -rf "$d"
}

scenario_context_kube_cache_and_noexec() {
    section "contexts: kubeconfig read only when it changes; no programs run"
    local d out; d="$(mktemp -d "${TMPDIR:-/tmp}/bga-cx-XXXXXX")"; mkdir -p "$d/bin"
    printf 'current-context: one\n' > "$d/config"; touch -t 200001010000 "$d/config"
    for t in kubectl aws terraform; do printf '#!/bin/sh\n: > "%s/RAN_%s"\n' "$d" "$t" > "$d/bin/$t"; chmod 755 "$d/bin/$t"; done
    out="$(bash --norc --noprofile -i -c "
        export HOME='$HOME' PATH='$d/bin:$PATH' TERM=xterm-256color LANG=C.UTF-8 COLUMNS=120 BASHGITAWARE_MODE=full BASHGITAWARE_ASYNC=1 BASHGITAWARE_CONTEXTS=kube,aws,tf KUBECONFIG='$d/config' AWS_PROFILE=x
        cd '$d'; source '$REPO/new.bashrc'
        __bga_context; printf 'a=%s ' \"\$_bga_kube_ctx\"
        printf 'current-context: two\n' > '$d/config'; touch -t 200001010000 '$d/config'
        __bga_context; printf 'b=%s ' \"\$_bga_kube_ctx\"
        touch '$d/config'
        __bga_context; printf 'c=%s' \"\$_bga_kube_ctx\"" 2>/dev/null)"
    assert_contains "$out" "a=one b=one c=two" "cached until the file is newer than the marker"
    local t
    for t in kubectl aws terraform; do
        if [ -e "$d/RAN_$t" ]; then fail "$t was executed"; else ok "$t not executed"; fi
    done
    rm -rf "$d"
}

scenario_context_tf_hostile() {
    section "contexts: a hostile .terraform/environment (SR7 surface)"
    local d out t0 rc; d="$(mktemp -d "${TMPDIR:-/tmp}/bga-cx-XXXXXX")"
    mkdir -p "$d/a/.terraform" "$d/b/.terraform" "$d/c/.terraform"
    printf 'SECRET42\n' > "$d/secret"; ln -s "$d/secret" "$d/a/.terraform/environment"
    dd if=/dev/zero of="$d/b/.terraform/environment" bs=1048576 count=32 2>/dev/null
    printf '$(touch %s/PWNED)\e]0;x\a\n' "$d" > "$d/c/.terraform/environment"
    out="$(bga_render "$d/a" BASHGITAWARE_CONTEXTS=tf)"
    assert_lacks "$out" "SECRET42" "symlink out of the directory: not followed"
    t0=$SECONDS; out="$(run_bounded 20 bga_render "$d/b" BASHGITAWARE_CONTEXTS=tf)"; rc=$?
    if [ "$rc" != 124 ] && [ $(( SECONDS - t0 )) -le 3 ]; then ok "NUL file: immediate"; else fail "NUL file: slow or hung"; fi
    out="$(bga_render "$d/c" BASHGITAWARE_CONTEXTS=tf)"
    if [ -e "$d/PWNED" ]; then fail "workspace file executed"; else ok "workspace file not executed"; fi
    assert_lacks "$out" $'\e]0;x' "escape sequence not passed"
    rm -rf "$d"
}

scenario_context_layout() {
    section "contexts: dropped before runtimes when space runs out"
    local d out; d="$(mktemp -d "${TMPDIR:-/tmp}/bga-cx-XXXXXX")"
    printf '{}\n' > "$d/package.json"; printf '20.1.0\n' > "$d/.nvmrc"
    out="$(_cx_visible "$(cd "$d" && AWS_PROFILE=production-account-with-a-long-name bash --norc --noprofile -i -c "export HOME='$HOME' PATH='$PATH' TERM=xterm-256color LANG=C.UTF-8 COLUMNS=60 BASHGITAWARE_MODE=full BASHGITAWARE_ASYNC=0 BASHGITAWARE_STYLE=lean BASHGITAWARE_CONTEXTS=aws; source '$REPO/new.bashrc'; __bga_prompt; printf '%s' \"\${PS1@P}\"" 2>/dev/null)")"
    assert_contains "$out" "node 20.1.0" "narrow terminal: runtime kept"
    assert_lacks    "$out" "aws production" "narrow terminal: context dropped first"
    rm -rf "$d"
}
