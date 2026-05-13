
# ---------------------------------------------------------------------------
# Color palette
# ---------------------------------------------------------------------------
if [ "$_bga_color" = 1 ]; then
    _R='\[\033[0m\]'
    _c_dim='\[\033[38;5;244m\]'         # connector words (on / via / took)
    _c_path='\[\033[1;38;5;75m\]'       # path -- bold steel blue
    _c_user='\[\033[38;5;79m\]'         # user -- teal
    _c_host='\[\033[38;5;79m\]'         # host -- teal
    _c_host_ssh='\[\033[1;38;5;215m\]'  # host over SSH -- bold amber
    _c_branch='\[\033[1;38;5;176m\]'    # branch -- bold purple
    _c_hash='\[\033[38;5;244m\]'        # short hash -- grey
    _c_state='\[\033[1;38;5;203m\]'     # in-progress state (rebase/merge) -- bold red
    _c_ahead='\[\033[38;5;179m\]'       # ahead -- yellow
    _c_behind='\[\033[38;5;179m\]'      # behind -- yellow
    _c_dirty='\[\033[38;5;179m\]'       # dirty marker -- yellow
    _c_stash='\[\033[38;5;110m\]'       # stash count -- soft blue
    _c_commit='\[\033[38;5;244m\]'      # "last commit" line -- grey
    _c_node='\[\033[38;5;114m\]'        # node runtime -- green
    _c_py='\[\033[38;5;179m\]'          # python runtime -- yellow
    _c_rust='\[\033[38;5;173m\]'        # rust runtime -- orange
    _c_go='\[\033[38;5;80m\]'           # go runtime -- cyan
    _c_tag='\[\033[38;5;215m\]'         # container / chroot tag -- amber
    _c_timer='\[\033[38;5;179m\]'       # command duration -- yellow
    _c_err='\[\033[1;38;5;203m\]'       # exit code -- bold red
    _c_ok='\[\033[1;38;5;114m\]'        # prompt symbol, success -- bold green
    _c_sym_err='\[\033[1;38;5;203m\]'   # prompt symbol, failure -- bold red
else
    _R=''
    _c_dim='' _c_path='' _c_user='' _c_host='' _c_host_ssh='' _c_branch='' _c_hash=''
    _c_state='' _c_ahead='' _c_behind='' _c_dirty='' _c_stash='' _c_commit=''
    _c_node='' _c_py='' _c_rust='' _c_go='' _c_tag='' _c_timer='' _c_err='' _c_ok='' _c_sym_err=''
fi

# ---------------------------------------------------------------------------
# Glyphs -- tiered: nerd > unicode > ascii
# A UTF-8 locale only tells us the *encoding* works, not that the *font* has the
# glyphs, so auto-detection never picks "nerd": opt in with BASHGITAWARE_NERD_FONT=1.
# ---------------------------------------------------------------------------
if [ -n "${BASHGITAWARE_GLYPHS:-}" ]; then
    _bga_glyphs="$BASHGITAWARE_GLYPHS"
elif [ "${BASHGITAWARE_NERD_FONT:-0}" = 1 ]; then
    _bga_glyphs=nerd
elif [ "$_bga_utf8" = 1 ]; then
    _bga_glyphs=unicode
else
    _bga_glyphs=ascii
fi
case "$_bga_glyphs" in nerd | unicode | ascii) ;; *) _bga_glyphs=ascii ;; esac

case "$_bga_glyphs" in
    nerd)    #  is the Powerline branch glyph -- present in every Nerd Font / Powerline font.
        _g_branch=$' '
        _g_dirty='●' _g_ahead='↑' _g_behind='↓' _g_stash='≡' _g_commit='↳' _g_sym='❯' _g_ell='…'
        ;;
    unicode)
        _g_branch=''
        _g_dirty='●' _g_ahead='↑' _g_behind='↓' _g_stash='≡' _g_commit='↳' _g_sym='❯' _g_ell='…'
        ;;
    ascii)
        _g_branch=''
        _g_dirty='*' _g_ahead='^' _g_behind='v' _g_stash='s' _g_commit='' _g_sym='>' _g_ell='...'
        ;;
esac
[ "$_bga_root" = 1 ] && _g_sym='#'
