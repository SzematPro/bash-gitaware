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
# shellcheck source=shellstate.sh
source "$HERE/shellstate.sh"
# shellcheck source=hooks.sh
source "$HERE/hooks.sh"
# shellcheck source=plain.sh
source "$HERE/plain.sh"
# shellcheck source=config.sh
source "$HERE/config.sh"
# shellcheck source=gitconfig.sh
source "$HERE/gitconfig.sh"
# shellcheck source=security.sh
source "$HERE/security.sh"

# Hermetic environment, then sanity gates.
sandbox_scrub
scenario_sandbox_clean
# Tests run without a tty, which would auto-select plain mode; plain mode has
# its own scenarios (tests/plain.sh) that unset this.
export BASHGITAWARE_MODE=full
# Never read the developer's own config file; tests/config.sh sets its own.
export BASHGITAWARE_CONFIG=/nonexistent/bash-gitaware-test-config
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
scenario_security_state_dir
scenario_async_without_state_dir_falls_back
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
scenario_gitconfig_trust_knob

# Coexistence with the user's hooks.
scenario_hooks_prompt_command_string
scenario_hooks_prompt_command_comment
scenario_hooks_prompt_command_array
scenario_hooks_idempotent
scenario_hooks_traps_chained
scenario_hooks_bash_preexec
scenario_hooks_async_exit_chained
scenario_hooks_ps0_and_exports

# Config file.
scenario_config_file
scenario_config_file_validation
scenario_config_file_permissions

# Plain mode.
scenario_plain_mode
scenario_plain_mode_escaping

# Shell-state independence.
scenario_shell_state_independence

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
