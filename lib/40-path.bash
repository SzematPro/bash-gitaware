
# ---------------------------------------------------------------------------
# Path: repo-name + path-within-repo when inside a repo; ~-relative otherwise.
# Trimmed to the last N components (the dropped prefix becomes an ellipsis).
# Sets REPLY (no subshell).
# ---------------------------------------------------------------------------
__bga_path() {
    local max="${BASHGITAWARE_PATH_MAXDEPTH:-3}"; case "$max" in '' | *[!0-9]*) max=3 ;; esac
    local lead="" rest=""
    if [ -n "${_bga_git_top:-}" ] && case "$PWD/" in "$_bga_git_top"/*) true ;; *) false ;; esac; then
        lead="${_bga_git_top##*/}"                       # repository name
        rest="${PWD#"$_bga_git_top"}"; rest="${rest#/}"  # path within the repo
    elif case "$PWD/" in "$HOME"/*) true ;; *) false ;; esac; then
        lead="~"
        rest="${PWD#"$HOME"}"; rest="${rest#/}"
    else
        lead=""                                          # absolute path with no useful "lead"
        rest="${PWD#/}"
    fi
    [ -z "$rest" ] && { REPLY="${lead:-/}"; return; }

    # Keep the last $max components, cutting from the right with parameter
    # expansion (no here-string: it writes a temp file before bash 5.1).
    if [ "$max" -ne 0 ]; then
        local out="" r="$rest" i=0
        while [ "$i" -lt "$max" ] && [ -n "$r" ]; do
            out="/${r##*/}$out"
            case "$r" in */*) r="${r%/*}" ;; *) r='' ;; esac
            i=$(( i + 1 ))
        done
        if [ -n "$r" ]; then
            if [ -n "$lead" ]; then REPLY="$lead/$_g_ell$out"
            else REPLY="$_g_ell$out"; fi
            return
        fi
    fi
    if [ -n "$lead" ]; then REPLY="$lead/$rest"; else REPLY="/$rest"; fi
}
