
# ---------------------------------------------------------------------------
# Private per-shell state directory.
#
# __bga_state_dir_init creates (once per shell) a fresh directory for caches
# and worker results and stores it in _bga_state_dir, or leaves it empty and
# returns 1 when no safe location exists. The directory is made with mktemp -d
# (mode 0700, a name nobody can predict) under:
#   1. $XDG_RUNTIME_DIR, only if it is a real directory (not a symlink) that we
#      own and that group and others cannot write;
#   2. otherwise ${TMPDIR:-/tmp}.
# The result is checked again (a directory, not a symlink, owned by us, mode
# 0700) before use, so a planted path is refused instead of trusted.
# ---------------------------------------------------------------------------
_bga_state_dir=''

# True when $1 is a real directory owned by us that group/others cannot write.
__bga_dir_private() {
    [ -d "$1" ] && [ ! -L "$1" ] && [ -O "$1" ] || return 1
    [ -z "$(find "$1" -maxdepth 0 \( -perm -020 -o -perm -002 \) 2>/dev/null)" ]
}

__bga_state_dir_init() {
    [ -n "$_bga_state_dir" ] && [ -d "$_bga_state_dir" ] && return 0
    _bga_state_dir=''
    local base="${XDG_RUNTIME_DIR:-}" d
    if [ -z "$base" ] || ! __bga_dir_private "$base"; then base="${TMPDIR:-/tmp}"; fi
    d="$(umask 077 && mktemp -d "${base%/}/bga.XXXXXXXX" 2>/dev/null)" || return 1
    # mktemp -d gives 0700; anything else means a hostile or broken mktemp.
    if ! __bga_dir_private "$d" || [ -n "$(find "$d" -maxdepth 0 ! -perm 700 2>/dev/null)" ]; then
        return 1
    fi
    _bga_state_dir="$d"
}

# Remove the state directory and everything we put in it. Only touches the
# directory this shell created.
__bga_state_dir_cleanup() {
    [ -n "$_bga_state_dir" ] && [ -d "$_bga_state_dir" ] && [ ! -L "$_bga_state_dir" ] || return 0
    rm -f "$_bga_state_dir"/* 2>/dev/null
    rmdir "$_bga_state_dir" 2>/dev/null
    _bga_state_dir=''
}
