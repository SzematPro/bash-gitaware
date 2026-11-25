
# ---------------------------------------------------------------------------
# Prompt
# ---------------------------------------------------------------------------
__bga_prompt() {
    local exit_code=$?
    # __bga_pre (first in PROMPT_COMMAND) saved the status before other hooks
    # could change it.
    if [ -n "${_bga_exit:-}" ]; then exit_code="$_bga_exit"; _bga_exit=''; fi

    # OSC 133;D + OSC 7: must be emitted before PS1 is assembled, so the
    # terminal sees the just-finished command's exit and the new cwd before
    # the next prompt is drawn. No-op if BASHGITAWARE_OSC=0.
    __bga_osc_prompt_cycle_start "$exit_code"
    __bga_osc_progress_end "$exit_code" "${_bga_timer_start:+1}"

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

    if [ "${_bga_plain:-0}" = 1 ]; then
        __bga_prompt_plain "$exit_code"
        _bga_timer_start='' _bga_in_pc=''
        return
    fi

    if [ "${BASHGITAWARE_STYLE:-lean}" != classic ]; then
        __bga_lean_result "$exit_code"
        __bga_prompt_lean "$exit_code"
        _bga_timer_start='' _bga_in_pc=''
        return
    fi

    local ps1="" nl=0   # nl: number of "\n" line breaks added (transient)

    # OSC 133;A: prompt begin (wrapped in \[ \] for readline width arithmetic).
    __bga_osc_ps1 '133;A'; ps1+="$REPLY"

    # Optional OSC window title.
    local REPLY
    __bga_title_ps1; ps1+="$REPLY"

    # --- Line 1: context ----------------------------------------------------
    # Untrusted text (paths, git refs, commit subjects, ...) is embedded only
    # through __bga_ps1_lit (lib/15-escape.bash): never paste it raw.
    local REPLY
    if [ -n "${debian_chroot:-}" ]; then
        __bga_ps1_lit "$debian_chroot"; ps1+="${_c_tag}(${REPLY})${_R} "
    fi
    [ "$_bga_container" = 1 ]   && ps1+="${_c_tag}[container]${_R} "

    # user@host -- shown only when it matters, unless overridden.
    local show_host="${BASHGITAWARE_SHOW_HOST:-auto}"
    if [ "$show_host" = always ] || { [ "$show_host" != never ] && { [ "$_bga_ssh" = 1 ] || [ "$_bga_root" = 1 ]; }; }; then
        ps1+="${_c_user}\u${_R}@"
        if [ "$_bga_ssh" = 1 ]; then ps1+="${_c_host_ssh}\h${_R} "; else ps1+="${_c_host}\h${_R} "; fi
    fi

    # Path (repo-relative when inside a repo).
    local pwd_str; __bga_path; pwd_str="$REPLY"
    __bga_ps1_lit "$pwd_str"; ps1+="${_c_path}${REPLY}${_R}"

    # Git: " on [glyph]branch[@hash][ STATE][ ^ahead][ vbehind][ dirty][ stashN]"
    if [ "$_bga_in_git" = 1 ]; then
        __bga_ps1_lit "$_bga_git_branch"
        ps1+=" ${_c_dim}on ${_R}${_c_branch}${_g_branch}${REPLY}${_R}"
        if [ -n "$_bga_git_hash" ] && [ "$_bga_git_branch" != "detached@${_bga_git_hash}" ]; then
            __bga_ps1_lit "$_bga_git_hash"; ps1+="${_c_hash}@${REPLY}${_R}"
        fi
        if [ -n "$_bga_git_state" ]; then
            __bga_ps1_lit "$_bga_git_state"; ps1+=" ${_c_state}${REPLY}${_R}"
        fi
        [ "$_bga_git_ahead"  -gt 0 ] 2>/dev/null  && ps1+=" ${_c_ahead}${_g_ahead}${_bga_git_ahead}${_R}"
        [ "$_bga_git_behind" -gt 0 ] 2>/dev/null  && ps1+=" ${_c_behind}${_g_behind}${_bga_git_behind}${_R}"
        [ "$_bga_git_dirty"  = 1 ]                && ps1+=" ${_c_dirty}${_g_dirty}${_R}"
        [ "$_bga_git_stash"  -gt 0 ] 2>/dev/null  && ps1+=" ${_c_stash}${_g_stash}${_bga_git_stash}${_R}"
        # M5 async: subtle placeholder while the expensive info is still being
        # computed in the background. Cleared on the next prompt cycle once
        # the cache lands.
        [ "${_bga_async_pending:-0}" = 1 ]        && ps1+=" ${_c_dim}${_g_ell}${_R}"
    fi

    # Runtime / version module(s), only when the directory calls for it.
    __bga_runtime; local rt="$_bga_rt_str"
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
        __bga_ps1_lit "$msg"; msg="$REPLY"; nl=$(( nl + 1 ))
        if [ -n "$_g_commit" ]; then ps1+="\n${_c_commit}${_g_commit} ${msg}${_R}"
        else                         ps1+="\n${_c_commit}commit: ${msg}${_R}"
        fi
    fi

    # --- Line 3: the prompt symbol ------------------------------------------
    nl=$(( nl + 1 ))
    if [ "$exit_code" -eq 0 ]; then ps1+="\n${_c_ok}${_g_sym}${_R} "
    else                            ps1+="\n${_c_sym_err}${_g_sym}${_R} "
    fi

    # OSC 133;B: prompt end / "user types here". Goes after the prompt symbol
    # so the terminal-marked cursor position matches where readline puts it.
    __bga_osc_ps1 '133;B'; ps1+="$REPLY"

    PS1="$ps1"

    # M4 transient: record the just-built prompt's physical line count and
    # exit code so __bga_transient_collapse (bind -x on Enter) can move the
    # cursor up the right number of rows and pick the matching symbol color.
    if [ "${BASHGITAWARE_TRANSIENT:-1}" != 0 ]; then
        # Count our own line breaks: escaped untrusted text may contain a
        # literal backslash-n, so scanning PS1 for "\n" would over-count.
        _bga_transient_lines=$(( nl + 1 ))
        _bga_transient_exit="$exit_code"
        _bga_transient_active=1
    fi

    _bga_timer_start='' _bga_in_pc=''      # reset for the next command (must be the last thing here)
}

# Plain mode (lib/10-detect.bash): "<path> (<branch>[ *])[ [exit N]] $ ".
# No colors, no escape sequences, one line; untrusted text still escaped.
__bga_prompt_plain() {
    local exit_code="$1" ps1="" REPLY
    __bga_path; __bga_ps1_lit "$REPLY"; ps1="$REPLY"
    if [ "$_bga_in_git" = 1 ]; then
        __bga_ps1_lit "$_bga_git_branch"; ps1+=" ($REPLY"
        [ "$_bga_git_dirty" = 1 ] && ps1+=" *"
        ps1+=")"
    fi
    [ "$exit_code" -ne 0 ] && ps1+=" [exit $exit_code]"
    if [ "$_bga_root" = 1 ]; then ps1+=" # "; else ps1+=" \$ "; fi
    PS1="$ps1"
    _bga_transient_active=0
}

# Window title (OSC 0) as PS1 text in REPLY; empty when the terminal has none.
# Not \w: bash 4.4-5.1 pass control characters in it through, so a directory
# name could end the title early and inject other OSC sequences (e.g. a
# clipboard write). The escaped path is used instead.
__bga_title_ps1() {
    REPLY=''
    [ "$_bga_title" = 1 ] || return 0
    local t_path="$PWD" t_chroot=''
    case "$t_path" in "$HOME" | "$HOME"/*) t_path="~${t_path#"$HOME"}" ;; esac
    [ -n "${debian_chroot:-}" ] && { __bga_ps1_lit "$debian_chroot"; t_chroot="($REPLY) "; }
    __bga_ps1_lit "$t_path"
    REPLY="\[\033]0;${t_chroot}\u@\h: ${REPLY}\007\]"
}
