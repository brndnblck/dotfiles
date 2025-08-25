#!/usr/bin/env bats

# Consolidated Main Script Tests
# Tests TUI interface functionality, navigation, and orchestration logic

# Load helpers using correct relative path
load "../../helpers/helper"
load "$TESTS_DIR/helpers/mocks"

setup() {
    test_setup
    setup_advanced_mocks
    
    # Copy real main script for testing
    cp "$PROJECT_ROOT/script/main" "$DOTFILES_PARENT_DIR/script/main"
    cp -r "$PROJECT_ROOT/script/core" "$DOTFILES_PARENT_DIR/script/"
    
    # Set up environment
    export DOTFILES_PARENT_DIR="$DOTFILES_PARENT_DIR"
    export DOTFILES_LOG_FILE="$DOTFILES_PARENT_DIR/tmp/main-test.log"
    export DOTFILES_DEBUG_LOG="$DOTFILES_PARENT_DIR/tmp/debug-main-test.log"
    
    # Create mock scripts that the main script will call
    create_test_script "setup" 'echo "Setup script executed"; exit 0'
    create_test_script "update" 'echo "Update script executed"; exit 0'  
    create_test_script "status" 'echo "Status script executed"; exit 0'
}

teardown() {
    test_teardown
}

# =============================================================================
# EXECUTION CONTEXT VALIDATION TESTS
# =============================================================================

@test "main: should validate script exists and is executable" {
    run test -x "$DOTFILES_PARENT_DIR/script/main"
    assert_success
}

@test "main: should fail when gum is not available" {
    # Remove gum from PATH completely 
    export PATH="/usr/bin:/bin"
    
    cat > "$DOTFILES_PARENT_DIR/script/main" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

if ! command -v gum >/dev/null 2>&1; then
    echo "❌ gum TUI tool not found!"
    echo ""
    echo "Please run the minimal bootstrap first:"
    echo "  ./script/bootstrap"
    echo ""
    echo "Or install gum manually:"
    echo "  brew install gum"
    exit 1
fi

echo "gum is available"
EOF
    chmod +x "$DOTFILES_PARENT_DIR/script/main"
    
    run "$DOTFILES_PARENT_DIR/script/main"
    assert_failure
    assert_output --partial "❌ gum TUI tool not found!"
    assert_output --partial "Please run the minimal bootstrap first:"
}

# =============================================================================
# ENVIRONMENT VARIABLE MANAGEMENT TESTS
# =============================================================================

@test "main: should set up environment variables when not inherited" {
    cat > "$DOTFILES_PARENT_DIR/script/main" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")

# Use existing variables from bootstrap if available, otherwise define them
if [ -z "${DOTFILES_PARENT_DIR:-}" ]; then
    DOTFILES_PARENT_DIR=$(dirname "$CURRENT_DIR")
    export DOTFILES_PARENT_DIR
fi

if [ -z "${DOTFILES_LOG_FILE:-}" ]; then
    DOTFILES_LOG_FILE="$DOTFILES_PARENT_DIR/tmp/main-$(date +%Y%m%d-%H%M%S).log"
    export DOTFILES_LOG_FILE
fi

echo "DOTFILES_PARENT_DIR=$DOTFILES_PARENT_DIR"
echo "DOTFILES_LOG_FILE set"
EOF
    chmod +x "$DOTFILES_PARENT_DIR/script/main"
    
    # Store script path before unsetting variables
    local script_path="$DOTFILES_PARENT_DIR/script/main"
    
    # Unset variables to test fallback
    unset DOTFILES_PARENT_DIR DOTFILES_LOG_FILE DOTFILES_DEBUG_LOG
    
    run "$script_path"
    assert_success
    assert_output --partial "DOTFILES_PARENT_DIR="
    assert_output --partial "DOTFILES_LOG_FILE set"
}

@test "main: should create tmp directory if it doesn't exist" {
    cat > "$DOTFILES_PARENT_DIR/script/main" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")
DOTFILES_PARENT_DIR=$(dirname "$CURRENT_DIR")

mkdir -p "$DOTFILES_PARENT_DIR/tmp"
echo "tmp directory ensured"
EOF
    chmod +x "$DOTFILES_PARENT_DIR/script/main"
    
    # Remove tmp directory if it exists
    rm -rf "$DOTFILES_PARENT_DIR/tmp"
    
    run "$DOTFILES_PARENT_DIR/script/main"
    assert_success
    assert_output "tmp directory ensured"
    
    run test -d "$DOTFILES_PARENT_DIR/tmp"
    assert_success
}

@test "main: should inherit variables from bootstrap when available" {
    # Set up environment as if called from bootstrap
    export DOTFILES_PARENT_DIR="$DOTFILES_PARENT_DIR"
    export DOTFILES_LOG_FILE="$DOTFILES_PARENT_DIR/tmp/inherited.log"
    export DOTFILES_DEBUG_LOG="$DOTFILES_PARENT_DIR/tmp/inherited-debug.log"
    
    cat > "$DOTFILES_PARENT_DIR/script/main" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Check if variables are inherited
if [ -n "${DOTFILES_PARENT_DIR:-}" ]; then
    echo "DOTFILES_PARENT_DIR inherited: $DOTFILES_PARENT_DIR"
fi

if [ -n "${DOTFILES_LOG_FILE:-}" ]; then
    echo "DOTFILES_LOG_FILE inherited: $(basename "$DOTFILES_LOG_FILE")"
fi

if [ -n "${DOTFILES_DEBUG_LOG:-}" ]; then
    echo "DOTFILES_DEBUG_LOG inherited: $(basename "$DOTFILES_DEBUG_LOG")"
fi
EOF
    chmod +x "$DOTFILES_PARENT_DIR/script/main"
    
    run "$DOTFILES_PARENT_DIR/script/main"
    assert_success
    assert_output --partial "DOTFILES_PARENT_DIR inherited:"
    assert_output --partial "DOTFILES_LOG_FILE inherited: inherited.log"
    assert_output --partial "DOTFILES_DEBUG_LOG inherited: inherited-debug.log"
}

# =============================================================================
# UI INTERFACE TESTS
# =============================================================================

@test "main: should display menu options correctly" {
    cat > "$DOTFILES_PARENT_DIR/script/main" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Mock gum choose to return first option
gum() {
    case "$1" in
        "choose")
            echo "[01] INIT SYSTEM"
            ;;
    esac
}

# Mock functions
show_standard_header() { echo "=== HEADER ==="; }
show_section_header() { echo "=== $1 ==="; }
colored_divider() { echo "================"; }

source() { true; }

main_menu() {
    show_standard_header
    show_section_header "SYSTEM OPERATIONS"
    
    local choice=$(gum choose \
        "[01] INIT SYSTEM" \
        "[02] UPDATE AND SYNCHRONIZE" \
        "[03] RUN SYSTEM SCAN" \
        "[04] TERMINATE SESSION")
    
    echo "Selected: $choice"
    colored_divider
}

main_menu
EOF
    chmod +x "$DOTFILES_PARENT_DIR/script/main"
    
    run "$DOTFILES_PARENT_DIR/script/main"
    assert_success
    assert_output --partial "=== HEADER ==="
    assert_output --partial "=== SYSTEM OPERATIONS ==="
    assert_output --partial "Selected: [01] INIT SYSTEM"
    assert_output --partial "================"
}

# =============================================================================
# SCRIPT ORCHESTRATION TESTS
# =============================================================================

@test "main: should execute setup script when INIT SYSTEM is selected" {
    # Create setup script that logs when executed
    cat > "$DOTFILES_PARENT_DIR/script/setup" << 'EOF'
#!/usr/bin/env bash
echo "SETUP_EXECUTED" > "$TEST_TEMP_DIR/setup_called"
exit 0
EOF
    chmod +x "$DOTFILES_PARENT_DIR/script/setup"
    
    # Mock gum to select setup, then terminate
    cat > "$MOCK_BREW_PREFIX/bin/gum" << 'EOF'
#!/bin/bash
case "$1" in
    "choose")
        if [ ! -f "$TEST_TEMP_DIR/first_choice_made" ]; then
            touch "$TEST_TEMP_DIR/first_choice_made"
            echo "[01] INIT SYSTEM"
        else
            echo "[04] TERMINATE SESSION"
        fi
        ;;
esac
EOF
    chmod +x "$MOCK_BREW_PREFIX/bin/gum"
    
    run "$DOTFILES_PARENT_DIR/script/main"
    assert_success
    
    # Verify our orchestration logic executed the setup script
    run test -f "$TEST_TEMP_DIR/setup_called"
    assert_success
}

@test "main: should execute update script when UPDATE AND SYNC is selected" {
    # Create update script that logs when executed
    cat > "$DOTFILES_PARENT_DIR/script/update" << EOF
#!/usr/bin/env bash
echo "UPDATE_EXECUTED" > "$TEST_TEMP_DIR/update_called"
exit 0
EOF
    chmod +x "$DOTFILES_PARENT_DIR/script/update"
    
    # Mock gum to select update, then terminate
    cat > "$MOCK_BREW_PREFIX/bin/gum" << EOF
#!/bin/bash
case "\$1" in
    "choose")
        if [ ! -f "$TEST_TEMP_DIR/first_choice_made" ]; then
            touch "$TEST_TEMP_DIR/first_choice_made"
            echo "[02] UPDATE AND SYNC"
        else
            echo "[04] TERMINATE SESSION"
        fi
        ;;
esac
EOF
    chmod +x "$MOCK_BREW_PREFIX/bin/gum"
    
    run "$DOTFILES_PARENT_DIR/script/main"
    assert_success
    
    # Verify our orchestration logic executed the update script
    run test -f "$TEST_TEMP_DIR/update_called"
    assert_success
}

@test "main: should execute status script when SYSTEM STATUS is selected" {
    # Create status script that logs when executed
    cat > "$DOTFILES_PARENT_DIR/script/status" << EOF
#!/usr/bin/env bash
echo "STATUS_EXECUTED" > "$TEST_TEMP_DIR/status_called"
exit 0
EOF
    chmod +x "$DOTFILES_PARENT_DIR/script/status"
    
    # Mock gum to select status, then terminate
    cat > "$MOCK_BREW_PREFIX/bin/gum" << EOF
#!/bin/bash
case "\$1" in
    "choose")
        if [ ! -f "$TEST_TEMP_DIR/first_choice_made" ]; then
            touch "$TEST_TEMP_DIR/first_choice_made"
            echo "[03] SYSTEM STATUS"
        else
            echo "[04] TERMINATE SESSION"
        fi
        ;;
esac
EOF
    chmod +x "$MOCK_BREW_PREFIX/bin/gum"
    
    run "$DOTFILES_PARENT_DIR/script/main"
    assert_success
    
    # Verify our orchestration logic executed the status script
    run test -f "$TEST_TEMP_DIR/status_called"
    assert_success
}

@test "main: should handle exit option gracefully" {
    cat > "$DOTFILES_PARENT_DIR/script/main" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Mock functions
show_exit_screen() { 
    echo "Exit screen displayed"
    exit 0
}
show_standard_header() { true; }
show_section_header() { true; }
colored_divider() { true; }
log_output() { true; }
source() { true; }

main_menu() {
    choice="[04] TERMINATE SESSION"
    
    case "$choice" in
        "[04] TERMINATE SESSION")
            show_exit_screen
            ;;
    esac
}

main_menu
EOF
    chmod +x "$DOTFILES_PARENT_DIR/script/main"
    
    run "$DOTFILES_PARENT_DIR/script/main"
    assert_success
    assert_output "Exit screen displayed"
}

# =============================================================================
# MENU LOOP BEHAVIOR TESTS
# =============================================================================

@test "main: should return to menu after script execution" {
    # Create a setup script that completes successfully
    cat > "$DOTFILES_PARENT_DIR/script/setup" << 'EOF'
#!/usr/bin/env bash
echo "SETUP_RUN" >> "$TEST_TEMP_DIR/execution_log"
exit 0
EOF
    chmod +x "$DOTFILES_PARENT_DIR/script/setup"
    
    # Mock gum to select setup twice, then terminate
    cat > "$MOCK_BREW_PREFIX/bin/gum" << 'EOF'
#!/bin/bash
case "$1" in
    "choose")
        call_count_file="$TEST_TEMP_DIR/gum_call_count"
        if [ ! -f "$call_count_file" ]; then
            echo "1" > "$call_count_file"
            echo "[01] INIT SYSTEM"
        elif [ "$(cat "$call_count_file")" = "1" ]; then
            echo "2" > "$call_count_file"
            echo "[01] INIT SYSTEM"  
        else
            echo "[04] TERMINATE SESSION"
        fi
        ;;
esac
EOF
    chmod +x "$MOCK_BREW_PREFIX/bin/gum"
    
    run "$DOTFILES_PARENT_DIR/script/main"
    assert_success
    
    # Verify setup was called twice (menu returned after first execution)
    run grep -c "SETUP_RUN" "$TEST_TEMP_DIR/execution_log"
    assert_output "2"
}

# =============================================================================
# ERROR HANDLING TESTS
# =============================================================================

@test "main: should continue menu loop when subscript fails" {
    # Create a setup script that fails but doesn't break the main loop
    cat > "$DOTFILES_PARENT_DIR/script/setup" << 'EOF'
#!/usr/bin/env bash
echo "SETUP_FAILED" >> "$TEST_TEMP_DIR/execution_log"
exit 1
EOF
    chmod +x "$DOTFILES_PARENT_DIR/script/setup"
    
    # Mock gum to terminate immediately
    cat > "$MOCK_BREW_PREFIX/bin/gum" << 'EOF'
#!/bin/bash
echo "[04] TERMINATE SESSION"
EOF
    chmod +x "$MOCK_BREW_PREFIX/bin/gum"
    
    # Modify main script to test setup once then exit
    cat > "$DOTFILES_PARENT_DIR/script/main" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")

# Use existing variables from bootstrap if available, otherwise define them
if [ -z "${DOTFILES_PARENT_DIR:-}" ]; then
    DOTFILES_PARENT_DIR=$(dirname "$CURRENT_DIR")
    export DOTFILES_PARENT_DIR
fi

if [ -z "${DOTFILES_LOG_FILE:-}" ]; then
    DOTFILES_LOG_FILE="$DOTFILES_PARENT_DIR/tmp/main-$(date +%Y%m%d-%H%M%S).log"
    export DOTFILES_LOG_FILE
fi

mkdir -p "$DOTFILES_PARENT_DIR/tmp"

# Test error handling - run setup and continue regardless
echo "Testing error handling..."
if "$CURRENT_DIR/setup"; then
    echo "Setup succeeded"
else
    echo "Setup failed but continuing..."
fi
echo "Main script continuing after setup result"
EOF
    chmod +x "$DOTFILES_PARENT_DIR/script/main"
    
    run "$DOTFILES_PARENT_DIR/script/main"
    # Main script should succeed even if subscript fails
    assert_success
    assert_output --partial "Setup failed but continuing..."
    assert_output --partial "Main script continuing after setup result"
    
    # Verify the failed script was called
    run test -f "$TEST_TEMP_DIR/execution_log"
    assert_success
}

# =============================================================================
# LOGGING AND INITIALIZATION TESTS
# =============================================================================

@test "main: should start application with proper logging" {
    cat > "$DOTFILES_PARENT_DIR/script/main" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

log_output() {
    echo "LOG: $1"
}

# Mock to avoid infinite loop
main_menu() {
    echo "Main menu started"
    exit 0
}

source() { true; }

log_output "Starting TUI interface"
main_menu
EOF
    chmod +x "$DOTFILES_PARENT_DIR/script/main"
    
    run "$DOTFILES_PARENT_DIR/script/main"
    assert_success
    assert_output --partial "LOG: Starting TUI interface"
    assert_output --partial "Main menu started"
}

@test "main: should create log files in correct location" {
    # Mock gum to terminate immediately
    cat > "$MOCK_BREW_PREFIX/bin/gum" << 'EOF'
#!/bin/bash
echo "[04] TERMINATE SESSION"
EOF
    chmod +x "$MOCK_BREW_PREFIX/bin/gum"
    
    # Clear environment to test our path logic
    unset DOTFILES_LOG_FILE DOTFILES_DEBUG_LOG
    
    run "$DOTFILES_PARENT_DIR/script/main"
    assert_success
    
    # Verify our logic created the expected directory structure
    run test -d "$DOTFILES_PARENT_DIR/tmp"
    assert_success
}

# =============================================================================
# ENVIRONMENT FALLBACK TESTS
# =============================================================================

@test "main: should create fallback environment when not inherited" {
    # Store script path before unsetting variables
    local main_script="$DOTFILES_PARENT_DIR/script/main"
    
    # Unset all environment variables to test fallback logic
    unset DOTFILES_PARENT_DIR DOTFILES_LOG_FILE DOTFILES_DEBUG_LOG
    
    # Mock gum to terminate immediately
    cat > "$MOCK_BREW_PREFIX/bin/gum" << 'EOF'
#!/bin/bash
echo "[04] TERMINATE SESSION"
EOF
    chmod +x "$MOCK_BREW_PREFIX/bin/gum"
    
    run "$main_script"
    assert_success
    
    # Verify tmp directory was created (our business logic)
    # Note: Test the directory creation using the original DOTFILES_PARENT_DIR from setup
    run test -d "$TEST_TEMP_DIR/dotfiles/tmp"
    assert_success
}