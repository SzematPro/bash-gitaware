# tests/gitdetail.sh -- git_status = detail and "upstream gone" (3.2, G1).
# shellcheck shell=bash disable=SC2016  # payloads are literal on purpose

_gd_visible() { printf '%s' "$1" | sed -E $'s/\x1b\\[[0-9;]*[A-Za-z]//g; s/\x1b[78]//g; s/\x1b\\][^\a]*\a//g; s/[\x01\x02]//g'; }
_gd_git() { git -c user.email=t@t -c user.name=t -c init.defaultBranch=main "$@"; }

scenario_gitdetail_counts() {
    section "git detail: staged, unstaged, untracked and conflicts"
    local d out; d="$(mktemp_repo)"
    printf 'a\n' > "$d/a"; printf 'b\n' > "$d/b"; printf 'c\n' > "$d/c"
    _gd_git -C "$d" add a b c >/dev/null; _gd_git -C "$d" commit -qm init
    # A conflict on c.
    _gd_git -C "$d" checkout -qb other; printf 'c2\n' > "$d/c"; _gd_git -C "$d" commit -qam other
    _gd_git -C "$d" checkout -q main;  printf 'c3\n' > "$d/c"; _gd_git -C "$d" commit -qam main
    _gd_git -C "$d" merge -q other >/dev/null 2>&1
    printf 'a2\n' > "$d/a"; _gd_git -C "$d" add a      # staged
    printf 'b2\n' > "$d/b"                             # unstaged
    printf 'n\n' > "$d/new"                            # untracked
    out="$(_gd_visible "$(bga_render "$d" BASHGITAWARE_GIT_STATUS=detail)")"
    assert_contains "$out" "+1 !1 ?1 ✘1" "Lean: each kind counted"
    assert_lacks    "$out" "●" "Lean: no compact mark in detail mode"
    out="$(_gd_visible "$(bga_render "$d" BASHGITAWARE_GIT_STATUS=detail BASHGITAWARE_STYLE=classic)")"
    assert_contains "$out" "+1 !1 ?1 ✘1" "classic: each kind counted"
    out="$(_gd_visible "$(bga_render "$d" BASHGITAWARE_GIT_STATUS=detail BASHGITAWARE_GLYPHS=ascii)")"
    assert_contains "$out" "+1 !1 ?1 x1" "ascii tier"
    # The async worker gives the same counts (second render reads the cache).
    out="$(bash --norc --noprofile -i -c "
        export HOME='$HOME' PATH='$PATH' TERM=xterm-256color LANG=C.UTF-8 BASHGITAWARE_MODE=full BASHGITAWARE_ASYNC=1 BASHGITAWARE_GIT_STATUS=detail
        cd '$d'; source '$REPO/new.bashrc'; __bga_prompt >/dev/null
        for i in 1 2 3 4 5 6 7 8 9 10; do [ -s \"\$_bga_async_cache\" ] && break; sleep 0.3; done
        __bga_prompt >/dev/null; printf '%s' \"\${PS1@P}\"" 2>/dev/null)"
    assert_contains "$(_gd_visible "$out")" "+1 !1 ?1 ✘1" "async worker: same counts"
    rm -rf "$d"
}

scenario_gitdetail_cap_and_compact() {
    section "git detail: 2000-entry cap; compact unchanged from 3.1"
    local d out i; d="$(mktemp_repo)"
    _gd_git -C "$d" commit -q --allow-empty -m init
    for i in $(seq 1 2005); do : > "$d/f$i"; done
    out="$(_gd_visible "$(bga_render "$d" BASHGITAWARE_GIT_STATUS=detail)")"
    assert_contains "$out" "?2000+" "capped count shows N+"
    # The worker's parse is linear: it took 17 s for 2000 entries when it cut
    # lines off a captured string, past the worker's 10 s git limit.
    local t
    t="$(cd "$d" && bash --norc --noprofile -i -c "export HOME='$HOME' PATH='$PATH' BASHGITAWARE_GIT_STATUS=detail; source '$REPO/new.bashrc'; __bga_git_info_cheap; s=\$SECONDS; __bga_git_info_expensive_compute >/dev/null; echo \$(( SECONDS - s ))" 2>/dev/null)"
    if [ "${t:-99}" -le 3 ]; then ok "detail worker on 2005 entries: ${t}s"; else fail "detail worker took ${t}s"; fi
    rm -f "$d"/f*; printf 'x\n' > "$d/x"
    # compact: the rendered PS1 is byte-identical to 3.1.0's.
    local old; old="$(mktemp "${TMPDIR:-/tmp}/bga-nb-XXXXXX")"
    if git -C "$REPO" show v3.1.0:new.bashrc > "$old" 2>/dev/null; then
        local a b
        a="$(cd "$d" && bash --norc --noprofile -i -c "export HOME='$HOME' PATH='$PATH' TERM=xterm-256color LANG=C.UTF-8 COLUMNS=100 BASHGITAWARE_MODE=full BASHGITAWARE_ASYNC=0; source '$old'; __bga_prompt; printf '%s' \"\${PS1@P}\"" 2>/dev/null)"
        b="$(cd "$d" && bash --norc --noprofile -i -c "export HOME='$HOME' PATH='$PATH' TERM=xterm-256color LANG=C.UTF-8 COLUMNS=100 BASHGITAWARE_MODE=full BASHGITAWARE_ASYNC=0; source '$REPO/new.bashrc'; __bga_prompt; printf '%s' \"\${PS1@P}\"" 2>/dev/null)"
        if [ -n "$a" ] && [ "$a" = "$b" ]; then ok "compact PS1 byte-identical to 3.1.0"; else fail "compact PS1 differs from 3.1.0"; fi
    else
        skip "compact vs 3.1.0 (no v3.1.0 tag in this checkout)"
    fi
    rm -f "$old"; rm -rf "$d"
}

scenario_gitdetail_upstream_gone() {
    section "git detail: upstream gone"
    local base out; base="$(mktemp -d "${TMPDIR:-/tmp}/bga-gd-XXXXXX")"
    _gd_git init -q --bare "$base/remote.git"
    _gd_git clone -q "$base/remote.git" "$base/w" 2>/dev/null
    _gd_git -C "$base/w" commit -q --allow-empty -m init
    _gd_git -C "$base/w" push -q origin main 2>/dev/null
    _gd_git -C "$base/w" checkout -qb feat; _gd_git -C "$base/w" push -q -u origin feat 2>/dev/null
    out="$(_gd_visible "$(bga_render "$base/w")")"
    assert_lacks "$out" "gone" "tracked branch with upstream: no mark"
    _gd_git -C "$base/w" push -q origin --delete feat 2>/dev/null; _gd_git -C "$base/w" fetch -q --prune 2>/dev/null
    out="$(_gd_visible "$(bga_render "$base/w")")"
    assert_contains "$out" "⇣gone" "deleted upstream: gone mark (compact)"
    out="$(_gd_visible "$(bga_render "$base/w" BASHGITAWARE_GLYPHS=ascii BASHGITAWARE_GIT_STATUS=detail)")"
    assert_contains "$out" " gone" "deleted upstream: ascii mark (detail)"
    rm -rf "$base"
}

scenario_gitdetail_old_cache() {
    section "git detail: an old-format cache is not misread"
    local d out; d="$(mktemp_repo)"
    _gd_git -C "$d" commit -q --allow-empty -m init
    out="$(bash --norc --noprofile -i -c "
        export HOME='$HOME' PATH='$PATH' TERM=xterm-256color LANG=C.UTF-8 BASHGITAWARE_MODE=full BASHGITAWARE_ASYNC=1
        cd '$d'; source '$REPO/new.bashrc'; __bga_git_info_cheap
        printf '_bga_async_key=\"%s\"\n_bga_async_dirty=1\n_bga_async_ahead=7\n_bga_async_behind=0\n' \"\$PWD|\$_bga_git_dir|compact\" > \"\$_bga_async_cache\"
        __bga_async_apply_or_dispatch; echo \"ahead=\$_bga_git_ahead pending=\$_bga_async_pending\"" 2>/dev/null)"
    assert_contains "$out" "ahead=0 pending=1" "3.1 cache (no version) treated as a miss"
    rm -rf "$d"
}
