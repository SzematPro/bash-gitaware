#!/usr/bin/env bash
# tests/run.sh -- orchestrate the bash-gitaware test suite.
#
# Run as `make test` from the project root, or directly: `bash tests/run.sh`.
# shellcheck source-path=SCRIPTDIR

set -uo pipefail

# Source helpers, scenarios, and perf budget.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$HERE/lib.sh"
# shellcheck source=scenarios.sh
source "$HERE/scenarios.sh"
# shellcheck source=perf.sh
source "$HERE/perf.sh"
# shellcheck source=gitconfig.sh
source "$HERE/gitconfig.sh"
# shellcheck source=security.sh
source "$HERE/security.sh"

# Sanity gates.
lib_syntax_check
build_freshness_check

# Scenario tests.
scenario_non_git_path
scenario_clean_git_repo
scenario_dirty_git_repo
scenario_ahead_of_remote
scenario_detached_head
scenario_rebase_state
scenario_no_color
scenario_ascii_glyphs
scenario_preset_minimal
scenario_preset_default
scenario_preset_powerline
scenario_preset_full
scenario_osc_default
scenario_osc_disabled
scenario_transient_basic
scenario_transient_error_exit
scenario_transient_disabled
scenario_transient_first_prompt
scenario_async_first_render_no_dirty
scenario_async_two_render_cache_hit
scenario_async_exit_trap_installed
scenario_async_disabled_no_trap
scenario_transient_state_tracked
scenario_install_replace
scenario_install_append_idempotent
scenario_install_help
scenario_path_maxdepth

# Security: untrusted text is never evaluated by the prompt.
scenario_security_branch_name
scenario_security_commit_subject
scenario_security_directory_name
scenario_security_version_file
scenario_security_control_chars
scenario_security_special_chars
scenario_security_promptvars_off
scenario_security_async_cache_private
scenario_security_special_files
scenario_security_window_title
scenario_security_fsmonitor
scenario_security_transient_line
scenario_security_c1_in_c_locale
scenario_gitconfig_filter_driver
scenario_gitconfig_include_skips_status
scenario_gitconfig_forged_signature
scenario_gitconfig_submodule_filter
scenario_gitconfig_parser_edge_cases
scenario_gitconfig_hooks_and_partial_clone
scenario_gitconfig_linked_worktree
scenario_gitconfig_long_commondir
scenario_gitconfig_newline_paths
scenario_gitconfig_trailing_newline_path
scenario_gitconfig_fifo_no_hang
scenario_gitconfig_trust_knob

# Performance.
scenario_perf_budget

# Summary.
section "summary"
printf 'passed=%d  failed=%d  skipped=%d\n' "$_passed" "$_failed" "$_skipped"
if [ "$_failed" -gt 0 ]; then
    printf '\nfailures:\n'
    for f in "${_failures[@]}"; do printf '  - %s\n' "$f"; done
    exit 1
fi
exit 0
