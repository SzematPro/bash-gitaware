#!/usr/bin/env bash
# shellcheck disable=SC2016
# (markdown-style backticks appear in usage/error strings, not command subs.)
# install.sh -- install bash-gitaware as ~/.bashrc (or merge by `source`).
#
# Modes:
#   --replace   (default) copy new.bashrc on top of ~/.bashrc (after a backup).
#               The shipped new.bashrc is a complete sensible .bashrc: with
#               shell_defaults = 1 (the default for this mode) it also sets
#               history options, ls colors, aliases and completion.
#   --append    append a `source <repo>/new.bashrc` line to your existing
#               ~/.bashrc, leaving the rest of your config untouched
#               (shell_defaults = 0 by default: your ~/.bashrc has its own).
#   --uninstall remove the appended source block, or restore the newest
#               backup over a replaced ~/.bashrc.
#
# Without a mode flag, on a terminal, the script asks for the mode, theme,
# glyph set and shell defaults (stored in the config file through bin/bga).
# --yes skips the questions and uses the defaults. shell_defaults is always
# written: an existing value is kept, otherwise the mode's default (ADR-0010).
#
# Tamper check: new.bashrc and its directory must not be writable by other
# users (writable by your own primary group is accepted, ruling L-37), since
# every shell you open would run whatever someone writes there.
#
# Examples:
#   ./install.sh                 # replace ~/.bashrc with new.bashrc (backup first)
#   ./install.sh --append        # source new.bashrc from your existing ~/.bashrc
#   ./install.sh --no-backup     # skip the timestamped backup
#   ./install.sh --target /tmp/x # write to a different file (testing)
#
# The script is idempotent: --append checks for an existing source line and
# does nothing if it already exists; --replace creates a fresh backup each
# run (with a timestamp suffix) so running twice does not destroy the
# original.
#
# Requires bash 4.4+ (the prompt uses PS0 and parameter transformations
# introduced in 4.4). macOS ships bash 3.2; install a newer one with
# `brew install bash`. The script warns if the version is too old but does
# not refuse to install -- the .bashrc itself is harmless on older shells,
# it just will not render the prompt correctly.

set -euo pipefail

# ---------------------------------------------------------------------------
# Locate the repo root + the new.bashrc artifact.
# ---------------------------------------------------------------------------
script_dir="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
artifact="$script_dir/new.bashrc"

if [ ! -f "$artifact" ]; then
    printf 'install: new.bashrc not found at %s\n' "$artifact" >&2
    printf 'install: run install.sh from the bash-gitaware repo root, or `make build` first.\n' >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Defaults + arg parsing.
# ---------------------------------------------------------------------------
mode=''
do_backup=1
assume_yes=0
target="$HOME/.bashrc"

usage() {
    cat <<EOF
Usage: install.sh [options]

Modes (mutually exclusive):
  --replace        Replace \$HOME/.bashrc with new.bashrc (default).
  --append         Append a 'source <repo>/new.bashrc' line to \$HOME/.bashrc.
  --uninstall      Remove the source block, or restore the newest backup.

Options:
  --yes            Do not ask questions; use the defaults.
  --no-backup      Skip the timestamped backup before --replace.
  --target FILE    Write to FILE instead of \$HOME/.bashrc (testing).
  -h, --help       Show this help.
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --replace)   mode='replace'  ;;
        --append)    mode='append'   ;;
        --uninstall) mode='uninstall' ;;
        --yes | -y)  assume_yes=1    ;;
        --no-backup) do_backup=0     ;;
        --target)
            shift
            [ $# -ge 1 ] || { printf 'install: --target requires an argument\n' >&2; exit 2; }
            target="$1"
            ;;
        -h | --help) usage; exit 0  ;;
        *)
            printf 'install: unknown argument: %s\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

# ---------------------------------------------------------------------------
# Bash version warning (informational only -- does not abort).
# ---------------------------------------------------------------------------
if [ "${BASH_VERSINFO[0]:-0}" -lt 4 ] \
   || { [ "${BASH_VERSINFO[0]}" -eq 4 ] && [ "${BASH_VERSINFO[1]:-0}" -lt 4 ]; }; then
    printf 'install: warning: detected bash %s; bash-gitaware needs bash 4.4+.\n' "$BASH_VERSION" >&2
    printf 'install: macOS ships bash 3.2; install a current bash with `brew install bash`,\n' >&2
    printf 'install: then `chsh -s $(brew --prefix)/bin/bash` to make it your login shell.\n' >&2
    printf 'install: proceeding anyway -- the prompt will not render until bash is upgraded.\n' >&2
fi

# ---------------------------------------------------------------------------
# Tamper check (ruling L-37): refuse a new.bashrc that other users can change.
# ---------------------------------------------------------------------------
# Prints "uid gid mode" for $1 (GNU or BSD stat).
perm_of() { stat -c '%u %g %a' -- "$1" 2>/dev/null || stat -f '%u %g %Lp' -- "$1"; }

check_private() {
    local p="$1" uid gid m me mygid
    read -r uid gid m <<< "$(perm_of "$p")"
    me="$(id -u)"; mygid="$(id -g)"
    if [ "$uid" != "$me" ] && [ "$uid" != 0 ]; then
        printf 'install: refusing: %s is owned by uid %s, not you or root\n' "$p" "$uid" >&2; return 1
    fi
    if [ $(( 8#$m & 2 )) -ne 0 ]; then
        printf 'install: refusing: %s is writable by any user (mode %s)\n' "$p" "$m" >&2; return 1
    fi
    if [ $(( 8#$m & 16 )) -ne 0 ] && [ "$gid" != "$mygid" ]; then
        printf 'install: refusing: %s is writable by group %s, not your primary group\n' "$p" "$gid" >&2; return 1
    fi
}

# Named ACL entries can grant write access that the mode bits do not show.
check_acl() {
    command -v getfacl >/dev/null 2>&1 || return 0
    if getfacl -cp -- "$1" 2>/dev/null | grep -Eq '^(user|group):[^:]+:.w'; then
        printf 'install: refusing: %s has ACL entries granting write access\n' "$1" >&2; return 1
    fi
}

# Every ancestor directory up to / must not let others swap the path: owned
# by root or you; group-writable only by your primary group; writable by
# others only with the sticky bit (like /tmp); no ACL write grants.
check_ancestors() {
    local d="$1" uid gid m me mygid; me="$(id -u)"; mygid="$(id -g)"
    while :; do
        d="$(dirname -- "$d")"
        read -r uid gid m <<< "$(perm_of "$d")"
        if [ "$uid" != 0 ] && [ "$uid" != "$me" ]; then
            printf 'install: refusing: ancestor %s is owned by uid %s\n' "$d" "$uid" >&2; return 1
        fi
        if [ $(( 8#$m & 16 )) -ne 0 ] && [ "$gid" != "$mygid" ] && [ $(( 8#$m & 512 )) -eq 0 ]; then
            printf 'install: refusing: ancestor %s is writable by group %s\n' "$d" "$gid" >&2; return 1
        fi
        if [ $(( 8#$m & 2 )) -ne 0 ] && [ $(( 8#$m & 512 )) -eq 0 ]; then
            printf 'install: refusing: ancestor %s is writable by any user\n' "$d" >&2; return 1
        fi
        check_acl "$d" || return 1
        [ "$d" = / ] && return 0
    done
}

if [ "$mode" != uninstall ]; then
    { check_private "$artifact" && check_private "$script_dir" \
      && check_acl "$artifact" && check_acl "$script_dir" && check_ancestors "$script_dir"; } || exit 1
fi

# ---------------------------------------------------------------------------
# Interactive choices (a terminal, no mode flag, no --yes).
# ---------------------------------------------------------------------------
want_theme='' want_glyphs='' want_sd=''
# shell_defaults already in the config file (kept on a re-run), or empty.
cur_sd="$("$script_dir/bin/bga" config get shell_defaults 2>/dev/null)" || cur_sd=''
case "$cur_sd" in 0 | 1) ;; *) cur_sd='' ;; esac
# The mode's default: replace takes over the file that had these settings,
# append leaves the user's own ~/.bashrc in charge of them.
sd_default() { case "$1" in replace) echo 1 ;; *) echo 0 ;; esac; }
if [ -z "$mode" ] && [ "$assume_yes" = 0 ] && [ -t 0 ] && [ -t 1 ]; then
    ask() {  # ask <prompt> <default> -> REPLY
        local a; printf '%s [%s]: ' "$1" "$2"; IFS= read -r a || a=''
        REPLY="${a:-$2}"
    }
    while :; do
        ask 'Install mode: append (source from your ~/.bashrc) or replace (backup first)' append
        case "$REPLY" in append | replace) mode="$REPLY"; break ;; *) echo "  answer append or replace" ;; esac
    done
    themes="$(grep -o '^_bga_theme_[a-z0-9_]*=' "$artifact" | sed 's/^_bga_theme_//; s/=$//' | grep -vx tokens | tr '\n' ' ')"
    while :; do
        ask "Theme (${themes% })" aware
        case " $themes " in *" $REPLY "*) want_theme="$REPLY"; break ;; *) echo "  unknown theme" ;; esac
    done
    while :; do
        ask 'Glyphs: auto, unicode, nerd (needs a Nerd Font) or ascii' auto
        case "$REPLY" in auto) break ;; unicode | nerd | ascii) want_glyphs="$REPLY"; break ;; *) echo "  answer auto, unicode, nerd or ascii" ;; esac
    done
    d="${cur_sd:-$(sd_default "$mode")}"; [ "$d" = 1 ] && d=yes || d=no
    while :; do
        ask 'Shell defaults (history options, ls colors, aliases, completion): yes or no' "$d"
        case "$REPLY" in yes) want_sd=1; break ;; no) want_sd=0; break ;; *) echo "  answer yes or no" ;; esac
    done
fi
[ -n "$mode" ] || mode='replace'
[ -n "$want_sd" ] || want_sd="${cur_sd:-$(sd_default "$mode")}"

# ---------------------------------------------------------------------------
# Uninstall.
# ---------------------------------------------------------------------------
if [ "$mode" = uninstall ]; then
    if [ -f "$target" ] && grep -qE '^# (>>> )?bash-gitaware' "$target" && grep -qF 'new.bashrc' "$target"; then
        # Drop only what --append wrote: the marked block (v3), or the exact
        # three lines of the v2 block. Other lines, even ones mentioning
        # bash-gitaware, are kept.
        out='' skip=0 c1='# bash-gitaware -- modern, git-aware bash prompt.'
        c2='# Repo: https://github.com/SzematPro/bash-gitaware'
        while IFS= read -r line || [ -n "$line" ]; do
            case "$line" in
                '# >>> bash-gitaware >>>') skip=1; continue ;;
                '# <<< bash-gitaware <<<') skip=0; continue ;;
            esac
            [ "$skip" = 1 ] && continue
            [ "$line" = "$c1" ] || [ "$line" = "$c2" ] && continue
            case "$line" in 'source "'*'/new.bashrc"  # bash-gitaware') continue ;; esac
            out+="$line"$'\n'
        done < "$target"
        printf '%s' "$out" > "$target"
        printf 'install: removed the bash-gitaware source block from %s\n' "$target"
        exit 0
    fi
    if [ -f "$target" ] && head -n 1 "$target" | grep -qF 'Generated by bin/build.sh'; then
        newest=''
        for b in "$target".bak-*; do
            if [ ! -f "$b" ] || [ -L "$b" ] || [ ! -O "$b" ]; then continue; fi
            # Same rule as the tamper check: nobody else may have written it.
            read -r _ bg bm <<< "$(perm_of "$b")"
            [ $(( 8#$bm & 2 )) -eq 0 ] || continue
            if [ $(( 8#$bm & 16 )) -ne 0 ] && [ "$bg" != "$(id -g)" ]; then continue; fi
            if [ -z "$newest" ] || [ "$b" -nt "$newest" ]; then newest="$b"; fi
        done
        if [ -n "$newest" ]; then
            cp -p -- "$newest" "$target"
            printf 'install: restored %s from %s\n' "$target" "$newest"
            exit 0
        fi
        printf 'install: %s is the bash-gitaware file but there is no backup to restore;\n' "$target" >&2
        printf 'install: move it away by hand (e.g. mv %s %s.bga)\n' "$target" "$target" >&2
        exit 1
    fi
    printf 'install: %s does not use bash-gitaware; nothing to do.\n' "$target"
    exit 0
fi

# ---------------------------------------------------------------------------
# Optional backup.
# ---------------------------------------------------------------------------
if [ "$do_backup" = 1 ] && [ "$mode" = 'replace' ] && [ -e "$target" ]; then
    backup="$target.bak-$(date +%s)"
    cp -p -- "$target" "$backup"
    printf 'install: backed up %s -> %s\n' "$target" "$backup"
fi

# ---------------------------------------------------------------------------
# Install.
# ---------------------------------------------------------------------------
if [ -L "$target" ]; then
    printf 'install: refusing: %s is a symlink; point --target at the real file\n' "$target" >&2
    exit 1
fi

case "$mode" in
    replace)
        cp -p -- "$artifact" "$target"
        printf 'install: wrote %s (%d bytes)\n' "$target" "$(wc -c < "$target")"
        ;;
    append)
        # %q quotes the path for the shell: a repository directory named
        # with $(...), backticks, quotes or newlines must not run anything.
        printf -v source_line 'source %q' "$artifact"
        if [ -f "$target" ] && { grep -qxF "$source_line" "$target" || grep -qF "$artifact" "$target"; }; then
            printf 'install: %s already sources %s; no change.\n' "$target" "$artifact"
        else
            {
                printf '\n# >>> bash-gitaware >>>\n'
                printf '# Repo: https://github.com/SzematPro/bash-gitaware\n'
                printf '%s\n' "$source_line"
                printf '# <<< bash-gitaware <<<\n'
            } >> "$target"
            printf 'install: appended source line to %s\n' "$target"
        fi
        ;;
esac

# Store the interactive choices in the config file.
if [ -n "$want_theme" ]; then "$script_dir/bin/bga" config set theme "$want_theme"; fi
if [ -n "$want_glyphs" ]; then "$script_dir/bin/bga" config set glyphs "$want_glyphs"; fi
# Not fatal: the install itself is done, and an unset key keeps 3.0 behavior.
if [ "$want_sd" != "$cur_sd" ]; then
    "$script_dir/bin/bga" config set shell_defaults "$want_sd" \
        || printf 'install: could not store shell_defaults; run: %s/bin/bga config set shell_defaults %s\n' "$script_dir" "$want_sd" >&2
fi

# ---------------------------------------------------------------------------
# Next steps.
# ---------------------------------------------------------------------------
cat <<EOF

Next steps:
  - Open a new terminal, or run: source "$target"
  - Check the setup: $script_dir/bin/bga doctor
  - Change settings: $script_dir/bin/bga config set KEY VALUE   (bga theme list)
  - Undo:            $script_dir/install.sh --uninstall

EOF
