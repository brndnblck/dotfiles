#!/usr/bin/env bash

# PROPOSED: Parameterized Assertion Patterns
# Eliminates repeated assertion logic across test files

# =============================================================================
# STANDARD ASSERTION PATTERNS - Replace duplicate assertion blocks
# =============================================================================

# Environment failure assertions (used in 10+ files)
assert_environment_setup_failure() {
    local script_name="${1:-script}"
    local expected_message="${2:-❌ This script should not be called directly!}"

    assert_failure
    assert_output --partial "$expected_message"
    assert_output --partial "Please use the main TUI interface:"
    assert_output --partial "./script/main"
}

# UI output structure assertions (used in 8+ files)
assert_standard_ui_structure() {
    local section_name="${1:-}"

    assert_output --partial "=== HEADER ==="
    if [ -n "$section_name" ]; then
        assert_output --partial "=== $section_name ==="
    fi
    assert_output --partial "================"
}

# Environment variable setup assertions (used in 6+ files)
assert_environment_variables_set() {
    local include_debug="${1:-true}"

    assert_output --partial "DOTFILES_PARENT_DIR="
    assert_output --partial "Log files configured"

    if [ "$include_debug" = "true" ]; then
        assert_output --partial "DOTFILES_DEBUG_LOG"
    fi
}

# Package installation assertions (setup.bats, update.bats, etc.)
assert_package_installation_sequence() {
    local package_type="$1" # "DEPENDENCY MATRIX", "APPLICATION REGISTRY", etc.

    assert_output --partial "EXECUTING: DEPLOYING $package_type..."
    assert_success
}

# Development stack version assertions (status.bats)
assert_development_stack_versions() {
    local tools=("git" "node" "python" "rust" "go" "docker")

    assert_output --partial "▶ DEVELOPMENT STACK:"

    for tool in "${tools[@]}"; do
        # Only assert if tool should be present
        if command -v "$tool" > /dev/null 2>&1; then
            assert_output --partial "✓ $tool"
        fi
    done
}

# Spinner usage assertions (status.bats, update.bats)
assert_spinner_used() {
    local spinner_title="$1"

    assert_output --partial "SPINNER: $spinner_title"
    assert_success
}

# Gum confirmation flow assertions (setup.bats, update.bats)
assert_confirmation_flow() {
    local confirmation_type="$1"          # "DEPLOYMENT", "REBOOT", "UPDATE", etc.
    local expected_action="${2:-ABORTED}" # "ABORTED", "INITIATED", "CONFIRMED"

    case "$expected_action" in
        "ABORTED")
            assert_output --partial "$confirmation_type SEQUENCE ABORTED"
            ;;
        "INITIATED" | "CONFIRMED")
            assert_output --partial "$confirmation_type SEQUENCE $expected_action"
            ;;
    esac
}

# File/directory existence assertions with meaningful messages
assert_file_structure() {
    local base_dir="$1"
    shift
    local required_paths=("$@")

    for path in "${required_paths[@]}"; do
        local full_path="$base_dir/$path"
        if [[ "$path" == */ ]]; then
            # Directory
            run test -d "$full_path"
            assert_success "Directory should exist: $full_path"
        else
            # File
            run test -f "$full_path"
            assert_success "File should exist: $full_path"
        fi
    done
}

# Log file content assertions
assert_log_entries() {
    local log_file="$1"
    shift
    local expected_entries=("$@")

    run test -f "$log_file"
    assert_success "Log file should exist: $log_file"

    for entry in "${expected_entries[@]}"; do
        run grep -q "$entry" "$log_file"
        assert_success "Log should contain: $entry"
    done
}

# =============================================================================
# COMPOUND ASSERTIONS - Test multiple related conditions
# =============================================================================

# Complete script execution validation
assert_script_execution_success() {
    local script_type="$1" # "bootstrap", "setup", "update", "status"
    local expected_completion_message="${2:-}"

    assert_success
    assert_standard_ui_structure

    case "$script_type" in
        "bootstrap")
            assert_output --partial "Bootstrap complete! Launching main interface..."
            ;;
        "setup")
            assert_output --partial "SYSTEM INIT COMPLETE"
            ;;
        "update")
            assert_output --partial "SYSTEM UPDATE COMPLETE"
            ;;
        "status")
            assert_output --partial "SYSTEM SCAN COMPLETE"
            ;;
    esac

    if [ -n "$expected_completion_message" ]; then
        assert_output --partial "$expected_completion_message"
    fi
}

# Package manager status validation
assert_package_manager_status() {
    local package_manager="$1"              # "brew", "npm", "cargo", "mas"
    local expected_status="${2:-installed}" # "installed", "not_installed", "outdated"

    assert_output --partial "▶ PACKAGE MANAGER STATUS:"
    assert_output --partial "$package_manager"

    case "$expected_status" in
        "installed")
            assert_output --partial "Version:"
            refute_output --partial "Not installed"
            ;;
        "not_installed")
            assert_output --partial "Not installed"
            ;;
        "outdated")
            assert_output --partial "Outdated:"
            ;;
    esac
}

# Dependency tracking validation
assert_dependency_tracking() {
    local total_configured="$1"
    local total_installed="$2"
    local missing_packages="${3:-}"

    assert_output --partial "▶ DEPENDENCY TRACKING:"
    assert_output --partial "Total configured: $total_configured"
    assert_output --partial "Installed: $total_installed/$total_configured"

    if [ -n "$missing_packages" ]; then
        assert_output --partial "Missing: $missing_packages"
    else
        refute_output --partial "Missing:"
    fi
}

# =============================================================================
# PARAMETERIZED TEST GENERATORS - Create similar tests with different data
# =============================================================================

# Generate environment failure tests for any script
test_environment_failure() {
    local script_name="$1"
    local script_path="$DOTFILES_PARENT_DIR/script/$script_name"

    # Create standard environment check script
    create_script_from_template "$script_name" "env_check_fail"

    # Unset environment
    unset DOTFILES_PARENT_DIR

    run "$script_path"
    assert_environment_setup_failure "$script_name"
}

# Generate version check tests for development tools
test_tool_version_detection() {
    local tool_name="$1"
    local expected_version="$2"
    local version_flag="${3:---version}"

    if command -v "$tool_name" > /dev/null 2>&1; then
        run "$tool_name" "$version_flag"
        assert_success
        assert_output --partial "$expected_version"
    else
        skip "$tool_name not available in test environment"
    fi
}

# =============================================================================
# USAGE EXAMPLES - How to reduce test code
# =============================================================================

# BEFORE (in multiple .bats files):
# @test "script: should fail when called directly" {
#     unset DOTFILES_PARENT_DIR
#     run "$script_path"
#     assert_failure
#     assert_output --partial "❌ This script should not be called directly!"
#     assert_output --partial "Please use the main TUI interface:"
#     assert_output --partial "./script/main"
# }

# AFTER:
# @test "script: should fail when called directly" {
#     test_environment_failure "script_name"
# }

# BEFORE (in status.bats):
# assert_output --partial "▶ DEPENDENCY TRACKING:"
# assert_output --partial "Total configured: 4 formulae"
# assert_output --partial "Installed: 3/4"
# assert_output --partial "Missing: missing-package"

# AFTER:
# assert_dependency_tracking "4" "3" "missing-package"
