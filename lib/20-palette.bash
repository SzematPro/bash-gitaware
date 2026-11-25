
# ---------------------------------------------------------------------------
# Color palette
# ---------------------------------------------------------------------------
# Tokens come from the theme (lib/19-theme.bash); no literal colors here.
__bga_theme_apply "${BASHGITAWARE_THEME:-aware}"

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
