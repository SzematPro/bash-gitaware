
# ---------------------------------------------------------------------------
# Path: repo-name + path-within-repo when inside a repo; ~-relative otherwise.
# Trimmed to the last N components (the dropped prefix becomes an ellipsis).
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
    [ -z "$rest" ] && { printf '%s' "${lead:-/}"; return; }

    local IFS=/ ; local -a p; read -ra p <<< "$rest"; local n=${#p[@]}
    if [ "$max" -ne 0 ] && [ "$n" -gt "$max" ]; then
        local out="" i
        for (( i = n - max ; i < n ; i++ )); do out="$out/${p[i]}"; done
        if [ -n "$lead" ]; then printf '%s/%s%s' "$lead" "$_g_ell" "$out"
        else printf '%s%s' "$_g_ell" "$out"; fi
        return
    fi
    if [ -n "$lead" ]; then printf '%s/%s' "$lead" "$rest"; else printf '/%s' "$rest"; fi
}
