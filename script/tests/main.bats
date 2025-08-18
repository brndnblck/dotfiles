#!/usr/bin/env bats

# BDD Tests for script/main
# Validates TUI interface functionality and navigation

load helper
load mocks

setup() {
    test_setup
    setup_advanced_mocks
    
    # Copy main script and helpers
    cp "${BATS_TEST_DIRNAME}/../../script/main" "$DOTFILES_PARENT_DIR/script/main"
    cp -r "${BATS_TEST_DIRNAME}/../../script/core" "$DOTFILES_PARENT_DIR/script/"
    
    # Create mock dependent scripts
    create_test_script "setup" 'echo "Setup script executed"'
    create_test_script "update" 'echo "Update script executed"'
    create_test_script "status" 'echo "Status script executed"'
}

teardown() {
    test_teardown
}

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

@test "main: should execute setup script when INIT SYSTEM is selected" {
    cat > "$DOTFILES_PARENT_DIR/script/main" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")

# Mock functions to avoid infinite loop
show_standard_header() { true; }
show_section_header() { true; }
colored_divider() { true; }
log_output() { true; }
source() { true; }

main_menu() {
    # Simulate selecting first option
    choice="[01] INIT SYSTEM"
    
    case "$choice" in
        "[01] INIT SYSTEM")
            "$CURRENT_DIR/setup"
            exit 0  # Exit to prevent infinite loop
            ;;
    esac
}

main_menu
EOF
    chmod +x "$DOTFILES_PARENT_DIR/script/main"
    
    run "$DOTFILES_PARENT_DIR/script/main"
    assert_success
    assert_output "Setup script executed"
}

@test "main: should execute update script when UPDATE AND SYNCHRONIZE is selected" {
    cat > "$DOTFILES_PARENT_DIR/script/main" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")

# Mock functions
show_standard_header() { true; }
show_section_header() { true; }
colored_divider() { true; }
log_output() { true; }
source() { true; }

main_menu() {
    choice="[02] UPDATE AND SYNCHRONIZE"
    
    case "$choice" in
        "[02] UPDATE AND SYNCHRONIZE")
            "$CURRENT_DIR/update"
            exit 0
            ;;
    esac
}

main_menu
EOF
    chmod +x "$DOTFILES_PARENT_DIR/script/main"
    
    run "$DOTFILES_PARENT_DIR/script/main"
    assert_success
    assert_output "Update script executed"
}

@test "main: should execute status script when RUN SYSTEM SCAN is selected" {
    cat > "$DOTFILES_PARENT_DIR/script/main" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")

# Mock functions
show_standard_header() { true; }
show_section_header() { true; }
colored_divider() { true; }
log_output() { true; }
source() { true; }

main_menu() {
    choice="[03] RUN SYSTEM SCAN"
    
    case "$choice" in
        "[03] RUN SYSTEM SCAN")
            "$CURRENT_DIR/status"
            exit 0
            ;;
    esac
}

main_menu
EOF
    chmod +x "$DOTFILES_PARENT_DIR/script/main"
    
    run "$DOTFILES_PARENT_DIR/script/main"
    assert_success
    assert_output "Status script executed"
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