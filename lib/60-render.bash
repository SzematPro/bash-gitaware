
# ---------------------------------------------------------------------------
# Prompt
# ---------------------------------------------------------------------------
__bga_prompt() {
    local exit_code=$?

    # Elapsed wall-clock time of the command that just finished.
    _bga_last_duration=''
    if [ -n "$_bga_timer_start" ]; then
        local e=$(( SECONDS - _bga_timer_start ))
        local thr="${BASHGITAWARE_TIMER_THRESHOLD:-2}"; case "$thr" in '' | *[!0-9]*) thr=2 ;; esac
        if [ "$e" -ge "$thr" ]; then
            if   [ "$e" -ge 3600 ]; then _bga_last_duration="$(( e / 3600 ))h$(( e % 3600 / 60 ))m"
            elif [ "$e" -ge 60 ];   then _bga_last_duration="$(( e / 60 ))m$(( e % 60 ))s"
            else                         _bga_last_duration="${e}s"
            fi
        fi
    fi

    __bga_git_info

    local ps1=""

    # Optional OSC window title.
    if [ "$_bga_title" = 1 ]; then
        ps1="\[\033]0;${debian_chroot:+($debian_chroot) }\u@\h: \w\007\]"
    fi

    # --- Line 1: context ----------------------------------------------------
    [ -n "${debian_chroot:-}" ] && ps1+="${_c_tag}(${debian_chroot})${_R} "
    [ "$_bga_container" = 1 ]   && ps1+="${_c_tag}[container]${_R} "

    # user@host -- shown only when it matters, unless overridden.
    local show_host="${BASHGITAWARE_SHOW_HOST:-auto}"
    if [ "$show_host" = always ] || { [ "$show_host" != never ] && { [ "$_bga_ssh" = 1 ] || [ "$_bga_root" = 1 ]; }; }; then
        ps1+="${_c_user}\u${_R}@"
        if [ "$_bga_ssh" = 1 ]; then ps1+="${_c_host_ssh}\h${_R} "; else ps1+="${_c_host}\h${_R} "; fi
    fi

    # Path (repo-relative when inside a repo).
    local pwd_str; pwd_str="$(__bga_path)"
    ps1+="${_c_path}${pwd_str}${_R}"

    # Git: " on [glyph]branch[@hash][ STATE][ ^ahead][ vbehind][ dirty][ stashN]"
    if [ "$_bga_in_git" = 1 ]; then
        ps1+=" ${_c_dim}on ${_R}${_c_branch}${_g_branch}${_bga_git_branch}${_R}"
        if [ -n "$_bga_git_hash" ] && [ "$_bga_git_branch" != "detached@${_bga_git_hash}" ]; then
            ps1+="${_c_hash}@${_bga_git_hash}${_R}"
        fi
        [ -n "$_bga_git_state" ]                  && ps1+=" ${_c_state}${_bga_git_state}${_R}"
        [ "$_bga_git_ahead"  -gt 0 ] 2>/dev/null  && ps1+=" ${_c_ahead}${_g_ahead}${_bga_git_ahead}${_R}"
        [ "$_bga_git_behind" -gt 0 ] 2>/dev/null  && ps1+=" ${_c_behind}${_g_behind}${_bga_git_behind}${_R}"
        [ "$_bga_git_dirty"  = 1 ]                && ps1+=" ${_c_dirty}${_g_dirty}${_R}"
        [ "$_bga_git_stash"  -gt 0 ] 2>/dev/null  && ps1+=" ${_c_stash}${_g_stash}${_bga_git_stash}${_R}"
    fi

    # Runtime / version module(s), only when the directory calls for it.
    local rt; rt="$(__bga_runtime)"
    [ -n "$rt" ] && ps1+="$rt"

    # Command duration (if slow), then exit code (on failure only).
    [ -n "$_bga_last_duration" ] && ps1+=" ${_c_dim}took ${_R}${_c_timer}${_bga_last_duration}${_R}"
    if [ "$exit_code" -ne 0 ]; then
        if [ "$_bga_glyphs" = ascii ]; then ps1+=" ${_c_err}exit ${exit_code}${_R}"
        else ps1+=" ${_c_err}✘${exit_code}${_R}"; fi
    fi

    # --- Line 2: last commit subject (optional) -----------------------------
    if [ "${BASHGITAWARE_COMMIT_LINE:-1}" != 0 ] && [ "$_bga_in_git" = 1 ] && [ -n "$_bga_git_msg" ]; then
        local msg="$_bga_git_msg" w=$(( ${COLUMNS:-80} - 3 ))
        [ "$w" -lt 12 ] && w=12
        if [ "${#msg}" -gt "$w" ]; then msg="${msg:0:$(( w - ${#_g_ell} ))}${_g_ell}"; fi
        if [ -n "$_g_commit" ]; then ps1+="\n${_c_commit}${_g_commit} ${msg}${_R}"
        else                         ps1+="\n${_c_commit}commit: ${msg}${_R}"
        fi
    fi

    # --- Line 3: the prompt symbol ------------------------------------------
    if [ "$exit_code" -eq 0 ]; then ps1+="\n${_c_ok}${_g_sym}${_R} "
    else                            ps1+="\n${_c_sym_err}${_g_sym}${_R} "
    fi

    PS1="$ps1"
    _bga_timer_start=''      # reset for the next command (must be the last thing here)
}
