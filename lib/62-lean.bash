
# ---------------------------------------------------------------------------
# Lean layout: the default style (ADR-0007). BASHGITAWARE_STYLE=classic keeps
# the v2 three-line stack (lib/60-render.bash).
#
#   ❯ make test                     <- ledger line (transient, lib/80)
#   ...output...
#     ✘1 · 3s                       <- result line: failed or slow commands
#   ~/src/repo  main ● ↑1                         python 3.12 · 14:02
#   ❯ _
#
# Untrusted text is escaped once, by __bga_ps1_lit, where each piece is
# added; widths are measured on the raw text with __bga_width. The right
# block is drawn inside \[ \] with save-cursor / column / restore-cursor, so
# readline counts it as zero width and a width error only misplaces it.
# ---------------------------------------------------------------------------

# Result line for the command that just finished: only when one ran (the
# DEBUG trap set the timer; an empty Enter does not) and it failed or reached
# the duration threshold. Printed directly, so it uses raw color tokens.
__bga_lean_result() {
    local code="$1" out='' sep=' · '
    [ -n "${_bga_timer_start:-}" ] || return 0
    [ "$_bga_glyphs" = ascii ] && sep=' | '
    if [ "$code" -ne 0 ]; then
        if [ "$_bga_glyphs" = ascii ]; then out="${_cr_err}exit ${code}${_Rr}"
        else out="${_cr_err}✘${code}${_Rr}"; fi
    fi
    if [ -n "${_bga_last_duration:-}" ]; then
        [ -n "$out" ] && out+="${_cr_dim}${sep}${_Rr}"
        out+="${_cr_timer}${_bga_last_duration}${_Rr}"
    fi
    [ -n "$out" ] && printf '  %s\n' "$out"
    return 0
}

# Append untrusted text $2 in token $1 to the left side: PS1 text in
# _bga_l, raw text in _bga_lr (for the width).
__bga_lean_add() {
    local tok="_c_$1" REPLY
    __bga_ps1_lit "$2"
    _bga_l+="${!tok}${REPLY}${_R}"
    # Measure what is displayed: control characters show as '?'.
    __bga_term_safe "$2"
    _bga_lr+="$REPLY"
}

# Build the left side for path $1 into _bga_l / _bga_lr.
__bga_lean_left() {
    _bga_l='' _bga_lr=''
    [ -n "${debian_chroot:-}" ] && __bga_lean_add tag "(${debian_chroot}) "
    [ "$_bga_container" = 1 ]   && __bga_lean_add tag '[container] '
    local show_host="${BASHGITAWARE_SHOW_HOST:-auto}"
    if [ "$show_host" = always ] || { [ "$show_host" != never ] && { [ "$_bga_ssh" = 1 ] || [ "$_bga_root" = 1 ]; }; }; then
        __bga_lean_add user "${USER:-}"; __bga_lean_add dim '@'
        if [ "$_bga_ssh" = 1 ]; then __bga_lean_add host_ssh "${HOSTNAME%%.*} "
        else __bga_lean_add host "${HOSTNAME%%.*} "; fi
    fi
    __bga_lean_add path "$1"
    if [ "$_bga_in_git" = 1 ]; then
        __bga_lean_add dim '  '
        __bga_lean_add branch "${_g_branch}${_bga_git_branch}"
        [ -n "$_bga_git_state" ]                 && __bga_lean_add state " $_bga_git_state"
        [ "$_bga_git_dirty" = 1 ]                && __bga_lean_add dirty " $_g_dirty"
        [ "$_bga_git_ahead"  -gt 0 ] 2>/dev/null && __bga_lean_add ahead " ${_g_ahead}${_bga_git_ahead}"
        [ "$_bga_git_behind" -gt 0 ] 2>/dev/null && __bga_lean_add behind " ${_g_behind}${_bga_git_behind}"
        [ "$_bga_git_stash"  -gt 0 ] 2>/dev/null && __bga_lean_add stash " ${_g_stash}${_bga_git_stash}"
        [ "${_bga_async_pending:-0}" = 1 ]       && __bga_lean_add dim " $_g_ell"
    fi
    return 0
}

__bga_prompt_lean() {
    local exit_code="$1" REPLY cols="${COLUMNS:-80}" ps1='' path
    case "$cols" in '' | *[!0-9]*) cols=80 ;; esac
    local sep=' · '; [ "$_bga_glyphs" = ascii ] && sep=' | '

    ps1+="$(__bga_osc_ps1 '133;A')"
    __bga_title_ps1; ps1+="$REPLY"

    # --- Left: tags, user@host, path, git -------------------------------------
    path="$(__bga_path)"
    __bga_lean_left "$path"
    __bga_width "$_bga_lr"; local wl="$REPLY"
    # Too wide even without the right block: keep only the last component.
    if [ "$wl" -ge "$cols" ] && [ "$path" != "${path##*/}" ]; then
        __bga_lean_left "${path##*/}"
        __bga_width "$_bga_lr"; wl="$REPLY"
    fi
    ps1+="$_bga_l"

    # --- Right: runtimes, optional clock ---------------------------------------
    local -a rt=() rw=()
    local item tok label rtok
    __bga_runtime
    for item in "${_bga_rt_items[@]}"; do
        tok="${item%%|*}" label="${item#*|}"
        rtok="_cr_$tok"; __bga_ps1_lit "$label"
        rt+=("${!rtok}${REPLY}${_Rr}")
        __bga_term_safe "$label"; __bga_width "$REPLY"; rw+=("$REPLY")
    done
    if [ "${BASHGITAWARE_CLOCK:-0}" = 1 ]; then
        printf -v label '%(%H:%M)T' -1
        rt+=("${_cr_dim}${label}${_Rr}"); rw+=("${#label}")
    fi
    # Drop from the end (clock first, then the last runtimes) until it fits.
    local n="${#rt[@]}" wr i sepw="${#sep}"
    while [ "$n" -gt 0 ]; do
        wr=0; for (( i = 0; i < n; i++ )); do wr=$(( wr + rw[i] )); done
        wr=$(( wr + (n - 1) * sepw ))
        [ $(( wl + wr + 2 )) -le "$cols" ] && break
        n=$(( n - 1 ))
    done
    if [ "$n" -gt 0 ]; then
        local right=''
        for (( i = 0; i < n; i++ )); do
            [ "$i" -gt 0 ] && right+="${_cr_dim}${sep}${_Rr}"
            right+="${rt[i]}"
        done
        ps1+="\\[\\e7\\e[$(( cols - wr + 1 ))G${right}\\e8\\]"
    fi

    # --- Optional commit subject, then the symbol line --------------------------
    # Line 1 can still wrap (one very long path component): count its rows
    # so the transient collapse clears all of them.
    local lines=$(( (wl > 0 ? (wl - 1) / cols : 0) + 2 ))
    if [ "${BASHGITAWARE_COMMIT_LINE:-0}" = 1 ] && [ "$_bga_in_git" = 1 ] && [ -n "$_bga_git_msg" ]; then
        local msg="$_bga_git_msg" w=$(( cols - 3 ))
        [ "$w" -lt 12 ] && w=12
        if [ "${#msg}" -gt "$w" ]; then msg="${msg:0:$(( w - ${#_g_ell} ))}${_g_ell}"; fi
        __bga_ps1_lit "$msg"
        ps1+="\\n${_c_commit}${_g_commit:+$_g_commit }${REPLY}${_R}"
        lines=$(( lines + 1 ))
    fi
    if [ "$exit_code" -eq 0 ]; then ps1+="\\n${_c_ok}${_g_sym}${_R} "
    else                            ps1+="\\n${_c_sym_err}${_g_sym}${_R} "; fi
    ps1+="$(__bga_osc_ps1 '133;B')"
    PS1="$ps1"

    if [ "${BASHGITAWARE_TRANSIENT:-1}" != 0 ]; then
        _bga_transient_lines="$lines"
        _bga_transient_exit="$exit_code"
        _bga_transient_active=1
    fi
}
