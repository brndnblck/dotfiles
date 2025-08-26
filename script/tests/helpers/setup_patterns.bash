#!/usr/bin/env bash

# PROPOSED: Standardized Setup Patterns for Test Files
# This eliminates 90% of setup/teardown duplication

# =============================================================================
# STANDARD SETUP PATTERNS - Replace repetitive setup() functions
# =============================================================================

# Standard script test setup - most common pattern (used in 15+ files)
setup_script_test() {
    local script_name="$1"
    local include_core="${2:-true}"

    test_setup
    setup_advanced_mocks

    # Copy the main script under test
    if [ -f "$PROJECT_ROOT/script/$script_name" ]; then
        cp "$PROJECT_ROOT/script/$script_name" "$DOTFILES_PARENT_DIR/script/$script_name"
    fi

    # Copy core helpers if needed (default: yes)
    if [ "$include_core" = "true" ] && [ -d "$PROJECT_ROOT/script/core" ]; then
        cp -r "$PROJECT_ROOT/script/core" "$DOTFILES_PARENT_DIR/script/"
    fi

    # Set up standard environment
    setup_standard_environment "$script_name"
}

# Environment setup for specific script types
setup_standard_environment() {
    local script_name="$1"
    export DOTFILES_PARENT_DIR="$DOTFILES_PARENT_DIR"

    case "$script_name" in
        "setup")
            export DOTFILES_LOG_FILE="$DOTFILES_PARENT_DIR/tmp/setup-test.log"
            export DOTFILES_DEBUG_LOG="$DOTFILES_PARENT_DIR/tmp/debug-setup-test.log"
            ;;
        "status")
            export DOTFILES_DEBUG_LOG="$DOTFILES_PARENT_DIR/tmp/debug-status-test.log"
            ;;
        "update")
            export DOTFILES_LOG_FILE="$DOTFILES_PARENT_DIR/tmp/update-test.log"
            export DOTFILES_DEBUG_LOG="$DOTFILES_PARENT_DIR/tmp/debug-update-test.log"
            ;;
        *)
            export DOTFILES_LOG_FILE
            export DOTFILES_DEBUG_LOG
            DOTFILES_LOG_FILE="$DOTFILES_PARENT_DIR/tmp/test-$(date +%Y%m%d-%H%M%S).log"
            DOTFILES_DEBUG_LOG="$DOTFILES_PARENT_DIR/tmp/debug-test-$(date +%Y%m%d-%H%M%S).log"
            ;;
    esac
}

# UI test setup pattern (for main.bats, ui.bats)
setup_ui_test() {
    local script_name="$1"
    setup_script_test "$script_name"

    # Create additional mock scripts often needed by UI tests
    create_test_script "setup" 'echo "Setup script executed"'
    create_test_script "update" 'echo "Update script executed"'
    create_test_script "status" 'echo "Status script executed"'
}

# Business logic test setup (for package_management_logic.bats, etc.)
setup_business_logic_test() {
    test_setup
    setup_advanced_mocks
    # No script copying needed - testing pure logic
    setup_standard_environment "business_logic"
}

# Integration test setup
setup_integration_test() {
    local primary_script="$1"
    setup_script_test "$primary_script"

    # Copy additional scripts for integration testing
    local scripts=("bootstrap" "setup" "update" "status" "main")
    for script in "${scripts[@]}"; do
        if [ "$script" != "$primary_script" ] && [ -f "$PROJECT_ROOT/script/$script" ]; then
            cp "$PROJECT_ROOT/script/$script" "$DOTFILES_PARENT_DIR/script/$script"
        fi
    done
}

# =============================================================================
# USAGE EXAMPLES - How test files would use these patterns
# =============================================================================

# BEFORE (in each .bats file):
# setup() {
#     test_setup
#     setup_advanced_mocks
#     cp "${BATS_TEST_DIRNAME}/../../script/bootstrap" "$DOTFILES_PARENT_DIR/script/bootstrap"
#     cp -r "${BATS_TEST_DIRNAME}/../../script/core" "$DOTFILES_PARENT_DIR/script/"
# }

# AFTER (in each .bats file):
# setup() { setup_script_test "bootstrap"; }

# OR for UI tests:
# setup() { setup_ui_test "main"; }

# OR for business logic tests:
# setup() { setup_business_logic_test; }
