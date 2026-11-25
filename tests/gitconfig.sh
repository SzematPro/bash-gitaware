# tests/gitconfig.sh -- a hostile .git/config (e.g. from an extracted archive)
# must not make the prompt run commands.
#
# `git clone` never copies .git/config, but a tarball or zip can ship a whole
# .git directory. Each scenario plants a command-valued setting that git would
# run during the prompt's own git calls, renders the prompt, and checks the
# canary was not created.
# shellcheck shell=bash

# A repo whose f.txt has stale stat data, so `git status` re-reads it.
_gc_repo() {
    local d; d="$(mktemp_repo)"
    printf 'data\n' > "$d/f.txt"; printf '* filter=x\n' > "$d/.gitattributes"
    git -C "$d" add -A; git -C "$d" commit -qm init
    touch -t 200101010000 "$d/f.txt"
    printf '%s' "$d"
}

_gc_render_both() {
    bga_render "$1" >/dev/null
    touch -t 200201010000 "$1/f.txt"
    bga_render "$1" BASHGITAWARE_ASYNC=1 >/dev/null
    touch -t 200301010000 "$1/f.txt"
    # The async job runs in the background; give it a moment to finish.
    local i=0; while [ "$i" -lt 20 ] && [ ! -e "$1/PWNED" ]; do i=$(( i + 1 )); sleep 0.1; done
}

scenario_gitconfig_filter_driver() {
    section "hostile .git/config: filter drivers are not run"
    local d; d="$(_gc_repo)"
    git -C "$d" config filter.x.clean "touch '$d/PWNED'; cat"
    git -C "$d" config filter.x.process "touch '$d/PWNED'"
    _gc_render_both "$d"
    if [ -e "$d/PWNED" ]; then fail "filter driver ran"; else ok "filter driver not run"; fi
    rm -rf "$d"
}

scenario_gitconfig_include_skips_status() {
    section "hostile .git/config: include makes the prompt skip git status"
    local d; d="$(_gc_repo)"
    printf '[filter "x"]\n\tclean = touch %s/PWNED; cat\n' "$d" > "$d/.git/extra"
    printf '[include]\n\tpath = extra\n' >> "$d/.git/config"
    _gc_render_both "$d"
    if [ -e "$d/PWNED" ]; then fail "included filter ran"; else ok "included filter not run"; fi
    rm -rf "$d"
}

scenario_gitconfig_forged_signature() {
    section "hostile .git/config: gpg.program is not run for a forged signature"
    local d; d="$(mktemp_repo)"
    git -C "$d" commit --allow-empty -qm init
    printf '#!/bin/sh\ntouch "%s/PWNED"\n' "$d" > "$d/.git/evil"; chmod +x "$d/.git/evil"
    git -C "$d" config log.showSignature true
    git -C "$d" config gpg.program "$d/.git/evil"
    local t c
    t="$(git -C "$d" rev-parse 'HEAD^{tree}')"
    c="$(printf 'tree %s\nauthor t <t@t> 1 +0000\ncommitter t <t@t> 1 +0000\ngpgsig -----BEGIN PGP SIGNATURE-----\n \n x\n -----END PGP SIGNATURE-----\n\nsigned\n' "$t" \
        | git -C "$d" hash-object -t commit -w --stdin)"
    git -C "$d" update-ref HEAD "$c"
    bga_render "$d" >/dev/null
    if [ -e "$d/PWNED" ]; then fail "gpg.program ran"; else ok "gpg.program not run"; fi
    rm -rf "$d"
}

scenario_gitconfig_submodule_filter() {
    section "hostile submodule config: no git runs inside submodules"
    local base; base="$(mktemp -d "${TMPDIR:-/tmp}/bga-gc-XXXXXX")"
    git init -q -b main "$base/sub"
    printf 'd\n' > "$base/sub/a"; printf '* filter=y\n' > "$base/sub/.gitattributes"
    git -C "$base/sub" add -A
    git -C "$base/sub" -c user.name=t -c user.email=t@t commit -qm s
    git init -q -b main "$base/top"
    git -C "$base/top" -c protocol.file.allow=always submodule add -q ../sub s >/dev/null 2>&1
    git -C "$base/top" -c user.name=t -c user.email=t@t commit -qm t
    git -C "$base/top/s" config filter.y.clean "touch '$base/PWNED'; cat"
    touch -t 200101010000 "$base/top/s/a"
    bga_render "$base/top" >/dev/null
    if [ -e "$base/PWNED" ]; then fail "submodule filter ran"; else ok "submodule filter not run"; fi
    rm -rf "$base"
}

scenario_gitconfig_trust_knob() {
    section "BASHGITAWARE_TRUST_REPO_CONFIG=1 keeps local filters working"
    local d; d="$(_gc_repo)"
    git -C "$d" config filter.x.clean "touch '$d/RAN'; cat"
    bga_render "$d" BASHGITAWARE_TRUST_REPO_CONFIG=1 >/dev/null
    if [ -e "$d/RAN" ]; then ok "trusted local filter runs"; else fail "trusted local filter did not run"; fi
    rm -rf "$d"
}
