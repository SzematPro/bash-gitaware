# ~/.bashrc: executed by bash(1) for non-login shells.
#
# bash-gitaware -- a modern, git-aware bash prompt.
# Author: Waldemar Szemat <waldemar@szemat.pro>
# Repo:   https://github.com/SzematPro/bash-gitaware
#
# A clean two-line prompt that surfaces context only when it matters: the
# repository-relative path, the branch, working-tree status, the runtime/version
# of the project you are in (Node, Python, Rust, Go), and how long the last
# command took. Inspired by modern cross-shell prompts; plain bash, no dependencies.
#
# Configuration (export before this file is sourced, e.g. from /etc/profile,
# ~/.profile, or near the top of this file):
#
#   BASHGITAWARE_GLYPHS=nerd|unicode|ascii  Force a glyph set. Default: auto --
#                                           "unicode" if the locale is UTF-8, else "ascii".
#                                           "nerd" is never auto-selected (a UTF-8 locale does not
#                                           mean the font has the glyphs): opt in explicitly.
#   BASHGITAWARE_NERD_FONT=1                 Shorthand for BASHGITAWARE_GLYPHS=nerd.
#   BASHGITAWARE_COMMIT_LINE=0               Hide the "last commit subject" line. Default: 1 (shown).
#   BASHGITAWARE_RUNTIME=0                   Disable the runtime/version modules. Default: 1 (enabled).
#   BASHGITAWARE_TIMER_THRESHOLD=N           Show command duration only if it took >= N seconds. Default: 2.
#   BASHGITAWARE_PATH_MAXDEPTH=N             Show at most N trailing path components (0 = unlimited). Default: 3.
#   BASHGITAWARE_SHOW_HOST=auto|always|never Show user@host. "auto" = only over SSH or as root. Default: auto.
#   NO_COLOR                                 If set (any value), disable all color. https://no-color.org

# If not running interactively, do nothing.
case $- in
    *i*) ;;
      *) return ;;
esac

# ---------------------------------------------------------------------------
# Presets -- BASHGITAWARE_PRESET sets a set of defaults; individual
# BASHGITAWARE_* variables still override anything a preset sets. Use the
# ':=' parameter expansion so an explicit user value wins.
#
#   minimal   -- ascii glyphs, no last-commit line, no runtime modules.
#   default   -- current behaviour (no extra defaults).
#   powerline -- Nerd Font glyphs on by default (works without Nerd glyphs
#                falling back via the standard tier).
#   full      -- last-commit line on, runtime modules on, user@host always.
#
# Presets affect *defaults only*; setting BASHGITAWARE_GLYPHS=ascii after
# choosing the 'powerline' preset still wins.
# ---------------------------------------------------------------------------
case "${BASHGITAWARE_PRESET:-default}" in
    minimal)
        : "${BASHGITAWARE_COMMIT_LINE:=0}"
        : "${BASHGITAWARE_RUNTIME:=0}"
        : "${BASHGITAWARE_GLYPHS:=ascii}"
        ;;
    default)
        : ;;
    powerline)
        : "${BASHGITAWARE_NERD_FONT:=1}"
        ;;
    full)
        : "${BASHGITAWARE_COMMIT_LINE:=1}"
        : "${BASHGITAWARE_RUNTIME:=1}"
        : "${BASHGITAWARE_SHOW_HOST:=always}"
        ;;
    *)
        : ;;
esac
