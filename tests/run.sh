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
# shellcheck source=width.sh
source "$HERE/width.sh"
# shellcheck source=theme.sh
source "$HERE/theme.sh"
# shellcheck source=lean.sh
source "$HERE/lean.sh"
# shellcheck source=cli.sh
source "$HERE/cli.sh"
# shellcheck source=install.sh
source "$HERE/install.sh"
# shellcheck source=shell.sh
source "$HERE/shell.sh"
# shellcheck source=policy.sh
source "$HERE/policy.sh"
# shellcheck source=runtime.sh
source "$HERE/runtime.sh"
# shellcheck source=progress.sh
source "$HERE/progress.sh"
# shellcheck source=vimode.sh
source "$HERE/vimode.sh"
# shellcheck source=security.sh
source "$HERE/security.sh"

# Hermetic environment, then sanity gates.
sandbox_scrub
scenario_sandbox_clean
# Tests run without a tty, which would auto-select plain mode; plain mode has
# its own scenarios (tests/plain.sh) that unset this.
export BASHGITAWARE_MODE=full
# The scenarios written for v2 assert the classic layout; tests/lean.sh unsets this.
export BASHGITAWARE_STYLE=classic
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
scenario_async_stale_result_discarded
scenario_async_refreshes_after_command
scenario_async_exit_trap_installed
scenario_async_disabled_no_trap
scenario_transient_state_tracked
scenario_install_replace
scenario_install_append_idempotent
scenario_install_help
scenario_install_tamper_check
scenario_install_uninstall
scenario_install_hostile_path
scenario_install_interactive
scenario_install_shell_defaults
scenario_path_maxdepth
scenario_runtime_cache
scenario_runtime_new_runtimes
scenario_runtime_no_exec
scenario_runtime_hostile_version_files
scenario_runtime_key_validation
scenario_runtime_sr6_version_files
scenario_runtime_sr6_c1_bytes
scenario_progress_osc94
scenario_vimode_setup
scenario_vimode_pty

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
scenario_security_theme_from_env
scenario_security_commit_subject_bounded
scenario_security_control_chars_width
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
scenario_gitconfig_trust_cache
scenario_gitconfig_trust_cache_multibyte
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
scenario_config_file_sticky_dir
scenario_config_turkish_locale
scenario_shell_defaults
scenario_shell_path_untouched
scenario_policy_untrusted_user_file
scenario_policy_applied
scenario_policy_refused

# Plain mode.
scenario_plain_mode
scenario_plain_mode_escaping

# Width engine.
scenario_width_engine
scenario_width_engine_linear

# Themes.
scenario_theme_depths
scenario_theme_tokens_complete
scenario_theme_contrast
scenario_doc_parity

# Lean layout.
scenario_lean_layout
scenario_lean_right_block
scenario_lean_wide_path
scenario_lean_result_line
scenario_lean_untrusted
scenario_lean_powerline

# bga CLI.
scenario_cli_basics
scenario_cli_config
scenario_cli_theme_and_doctor
scenario_cli_reload_applies_config
scenario_cli_config_edit
scenario_cli_shell_function
scenario_cli_reload_keeps_runtime

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
