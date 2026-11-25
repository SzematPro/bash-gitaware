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

scenario_gitconfig_parser_edge_cases() {
    section "hostile .git/config: git's own parsing decides, not a bash parser"
    local d
    # Deprecated [filter.X] form: git lowercases the name.
    d="$(_gc_repo)"; printf '* filter=evil\n' > "$d/.gitattributes"
    printf '[Filter.EVIL]\n\tclean = touch %s/PWNED; cat\n' "$d" >> "$d/.git/config"
    _gc_render_both "$d"
    if [ -e "$d/PWNED" ]; then fail "[Filter.EVIL] driver ran"; else ok "[Filter.EVIL] driver not run"; fi
    rm -rf "$d"
    # config.worktree (extensions.worktreeConfig).
    d="$(_gc_repo)"
    git -C "$d" config extensions.worktreeConfig true
    printf '[filter "x"]\n\tclean = touch %s/PWNED; cat\n' "$d" > "$d/.git/config.worktree"
    _gc_render_both "$d"
    if [ -e "$d/PWNED" ]; then fail "config.worktree driver ran"; else ok "config.worktree driver not run"; fi
    rm -rf "$d"
}

scenario_gitconfig_hooks_and_partial_clone() {
    section "hostile .git: hooks, partial clones and odd commondir"
    local d
    # post-index-change runs when status rewrites the index.
    d="$(_gc_repo)"; rm -f "$d/.gitattributes"
    printf '#!/bin/sh\ntouch "%s/PWNED"\n' "$d" > "$d/.git/hooks/post-index-change"
    chmod +x "$d/.git/hooks/post-index-change"
    _gc_render_both "$d"
    if [ -e "$d/PWNED" ]; then fail "post-index-change hook ran"; else ok "post-index-change hook not run"; fi
    rm -rf "$d"
    # A partial clone would lazily fetch missing objects (core.sshCommand...):
    # fail closed, keep the branch, drop everything else.
    d="$(_gc_repo)"
    git -C "$d" config extensions.partialClone origin
    git -C "$d" config remote.origin.promisor true
    local out; out="$(bga_render "$d")"
    assert_contains "$out" "main" "partial clone: branch still shown"
    assert_lacks    "$out" "init" "partial clone: no git log (commit subject not shown)"
    rm -rf "$d"
    # A commondir that does not lead to a config file fails closed.
    d="$(_gc_repo)"
    git -C "$d" config filter.x.clean "touch '$d/PWNED'; cat"
    printf 'nowhere\n' > "$d/.git/commondir"
    _gc_render_both "$d"
    if [ -e "$d/PWNED" ]; then fail "odd commondir: filter ran"; else ok "odd commondir: fails closed"; fi
    rm -rf "$d"
}

scenario_gitconfig_linked_worktree() {
    section "hostile .git/config: the common config of a linked worktree is checked"
    local d; d="$(_gc_repo)"
    git -C "$d" worktree add -q "$d.wt" -b wt >/dev/null 2>&1
    git -C "$d" config filter.x.clean "touch '$d/PWNED'; cat"
    touch -t 200101010000 "$d.wt/f.txt"
    bga_render "$d.wt" >/dev/null
    if [ -e "$d/PWNED" ]; then fail "worktree: common-config filter ran"; else ok "worktree: common-config filter not run"; fi
    local out; out="$(bga_render "$d.wt")"
    assert_contains "$out" "wt" "worktree: branch shown"
    rm -rf "$d" "$d.wt"
}

scenario_gitconfig_long_commondir() {
    section "hostile .git/config: a long commondir cannot point the check elsewhere"
    local base; base="$(mktemp -d "${TMPDIR:-/tmp}/bga-gc-XXXXXX")"
    # decoy: a directory whose path is exactly 256 bytes, with a benign config.
    local n=$(( 256 - ${#base} - 1 )) pad=''
    while [ "${#pad}" -lt "$n" ]; do pad+=a; done
    local decoy="$base/$pad" real="$base/$pad/c"
    mkdir -p "$decoy"; printf '[core]\n\tbare = false\n' > "$decoy/config"
    git init -q -b main --separate-git-dir "$real" "$base/main"
    printf 'data\n' > "$base/main/f.txt"; printf '* filter=x\n' > "$base/main/.gitattributes"
    git -C "$base/main" add -A
    git -C "$base/main" -c user.name=t -c user.email=t@t commit -qm init
    git -C "$base/main" worktree add -q "$base/wt" -b wt >/dev/null 2>&1
    printf '%s\n' "$real" > "$real/worktrees/wt/commondir"     # absolute, > 256 bytes
    git -C "$base/main" config filter.x.clean "touch '$base/PWNED'; cat"
    touch -t 200101010000 "$base/wt/f.txt"
    bga_render "$base/wt" >/dev/null
    if [ -e "$base/PWNED" ]; then fail "long commondir: filter ran"; else ok "long commondir: filter not run"; fi
    rm -rf "$base"
}

scenario_gitconfig_newline_paths() {
    section "hostile .git: a newline in the repository path fails closed"
    local base; base="$(mktemp -d "${TMPDIR:-/tmp}/bga-gc-XXXXXX")"
    local d="$base/x"$'\n'"y"
    # From a subdirectory, --git-dir is absolute and carries the newline.
    mkdir -p "$d/sub"; git init -q -b main "$d"
    printf 'data\n' > "$d/sub/f.txt"; printf '* filter=x\n' > "$d/.gitattributes"
    git -C "$d" add -A
    git -C "$d" -c user.name=t -c user.email=t@t commit -qm init
    git -C "$d" config filter.x.clean "touch '$base/PWNED'; cat"
    # Decoy where a newline-shifted field would point: sub/y/.git/config.
    mkdir -p "$d/sub/y/.git"; printf '[core]\n' > "$d/sub/y/.git/config"
    touch -t 200101010000 "$d/sub/f.txt"
    bga_render "$d/sub" >/dev/null 2>&1
    if [ -e "$base/PWNED" ]; then fail "newline path: filter ran"; else ok "newline path: filter not run"; fi
    rm -rf "$base"
}

scenario_gitconfig_trailing_newline_path() {
    section "hostile .git: a path ending in a newline cannot redirect git to a sibling"
    local base; base="$(mktemp -d "${TMPDIR:-/tmp}/bga-gc-XXXXXX")"
    local v="$base/x"$'\n' s="$base/x"
    git init -q -b main "$v"
    git -C "$v" -c user.name=t -c user.email=t@t commit -q --allow-empty -m v
    git init -q -b main "$s"
    printf 'd\n' > "$s/f"; printf '* filter=e\n' > "$s/.gitattributes"
    git -C "$s" add -A
    git -C "$s" -c user.name=t -c user.email=t@t commit -qm e
    git -C "$s" config filter.e.clean "touch '$base/PWNED'; cat"
    touch -t 200101010000 "$s/f"
    bga_render "$v" BASHGITAWARE_ASYNC=1 >/dev/null 2>&1
    bga_render "$v" >/dev/null 2>&1
    local i=0; while [ "$i" -lt 20 ] && [ ! -e "$base/PWNED" ]; do i=$(( i + 1 )); sleep 0.1; done
    if [ -e "$base/PWNED" ]; then fail "sibling repo's filter ran"; else ok "sibling repo's filter not run"; fi
    rm -rf "$base"
}

# Render in a repo whose $2 (path under .git) is a FIFO; $3 = extra shell code
# run after sourcing (e.g. to force the watchdog fallback). Prints the elapsed
# whole seconds, or HANG.
_gc_fifo_render() {
    local base="$1" what="$2" extra="${3-}"
    local TIMEFORMAT=%0R t
    t="$( { time run_bounded 15 bash --norc --noprofile -i -c "
        export HOME='$HOME' PATH='$PATH' TERM=dumb LANG=C.UTF-8 BASHGITAWARE_ASYNC=0
        cd '$base/r' || exit 1
        source '$REPO/new.bashrc'
        $extra
        __bga_prompt" </dev/null >/dev/null 2>&1 || echo HANG >&2; } 2>&1 )"
    printf '%s' "$t"
}

scenario_gitconfig_fifo_no_hang() {
    section "hostile .git: a FIFO where git reads cannot hang the prompt"
    local base what out
    for what in config HEAD index packed-refs; do
        base="$(mktemp -d "${TMPDIR:-/tmp}/bga-gc-XXXXXX")"
        git init -q -b main "$base/r"
        git -C "$base/r" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
        : > "$base/r/f"
        rm -f "$base/r/.git/$what"; mkfifo "$base/r/.git/$what"
        out="$(_gc_fifo_render "$base" "$what")"
        case "$out" in *HANG*) fail "FIFO .git/$what hangs the prompt" ;;
                       *) if [ "${out##*$'\n'}" -le 8 ]; then ok "FIFO .git/$what: prompt returns (${out##*$'\n'}s)"
                          else fail "FIFO .git/$what: prompt took ${out}s"; fi ;; esac
        rm -rf "$base"
    done
    # Same with the watchdog fallback used when timeout(1) is missing.
    base="$(mktemp -d "${TMPDIR:-/tmp}/bga-gc-XXXXXX")"
    git init -q -b main "$base/r"
    git -C "$base/r" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
    rm -f "$base/r/.git/config"; mkfifo "$base/r/.git/config"
    out="$(_gc_fifo_render "$base" config "_bga_tmo=''")"
    case "$out" in *HANG*) fail "watchdog fallback: FIFO hangs the prompt" ;;
                   *) ok "watchdog fallback: prompt returns (${out##*$'\n'}s)" ;; esac
    rm -rf "$base"
}

scenario_gitconfig_trust_cache() {
    section "trust check: cached per repository, invalidated by a config change"
    local d; d="$(_gc_repo)"
    local out
    out="$(bash --norc --noprofile -i -c "
        export HOME='$HOME' PATH='$PATH' TERM=dumb LANG=C.UTF-8 BASHGITAWARE_ASYNC=1 BASHGITAWARE_MODE=full
        cd '$d'; source '$REPO/new.bashrc'
        __bga_prompt; a=\"\${_bga_git_args[*]}\"
        git config filter.x.clean 'touch $d/PWNED; cat'
        touch -t 203001010000 .git/config
        __bga_prompt; b=\"\${_bga_git_args[*]}\"
        printf 'a=%s\nb=%s\n' \"\$a\" \"\$b\"" 2>/dev/null)"
    assert_lacks    "${out%%$'\n'b=*}" "filter.x.clean=" "first prompt: no filter to neutralize"
    assert_contains "$out" "b=--no-optional-locks"$'' "second prompt computed args"
    case "$out" in *$'\n'b=*filter.x.clean=*) ok "config change invalidates the cache" ;;
        *) fail "stale trust cache: $(printf '%q' "$out")" ;; esac
    rm -rf "$d"
}
