#!/usr/bin/env bash
# shellcheck disable=SC2016
# (markdown-style backticks appear in usage/error strings, not command subs.)
# install.sh -- install bash-gitaware as ~/.bashrc (or merge by `source`).
#
# Two modes:
#   --replace   (default) copy new.bashrc on top of ~/.bashrc (after a backup).
#               The shipped new.bashrc is a complete sensible .bashrc
#               (history, ls colors, aliases, completion, PATH) so this just
#               works for most setups.
#   --append    append a `source <repo>/new.bashrc` line to your existing
#               ~/.bashrc, leaving the rest of your config untouched.
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
mode='replace'
do_backup=1
target="$HOME/.bashrc"

usage() {
    cat <<EOF
Usage: install.sh [options]

Modes (mutually exclusive):
  --replace        Replace \$HOME/.bashrc with new.bashrc (default).
  --append         Append a 'source <repo>/new.bashrc' line to \$HOME/.bashrc.

Options:
  --no-backup      Skip the timestamped backup before --replace.
  --target FILE    Write to FILE instead of \$HOME/.bashrc (testing).
  -h, --help       Show this help.
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --replace)   mode='replace'  ;;
        --append)    mode='append'   ;;
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
case "$mode" in
    replace)
        cp -p -- "$artifact" "$target"
        printf 'install: wrote %s (%d bytes)\n' "$target" "$(wc -c < "$target")"
        ;;
    append)
        source_line="source \"$artifact\"  # bash-gitaware"
        if [ -f "$target" ] && grep -qF "$artifact" "$target"; then
            printf 'install: %s already sources %s; no change.\n' "$target" "$artifact"
        else
            {
                printf '\n# bash-gitaware -- modern, git-aware bash prompt.\n'
                printf '# Repo: https://github.com/SzematPro/bash-gitaware\n'
                printf '%s\n' "$source_line"
            } >> "$target"
            printf 'install: appended source line to %s\n' "$target"
        fi
        ;;
esac

# ---------------------------------------------------------------------------
# Next steps.
# ---------------------------------------------------------------------------
cat <<EOF

Next steps:
  - Open a new terminal, or run: source "$target"
  - Try a preset:    export BASHGITAWARE_PRESET=minimal|default|powerline|full
  - Nerd Font glyph: export BASHGITAWARE_NERD_FONT=1   (requires a Nerd Font)
  - See README.md and lib/00-options.bash for all BASHGITAWARE_* knobs.

EOF
