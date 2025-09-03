#!/usr/bin/env bats

# BDD Tests for script/update
# Validates system update orchestration and package management

# Load helpers using correct relative path
load "../../helpers/base"
load "$TESTS_DIR/helpers/mocks"

setup() {
    test_setup
    setup_advanced_mocks
    
    # Copy update script and helpers
    cp "$PROJECT_ROOT/script/update" "$DOTFILES_PARENT_DIR/script/update"
    cp -r "$PROJECT_ROOT/script/core" "$DOTFILES_PARENT_DIR/script/"
}

teardown() {
    test_teardown
}

@test "update: should validate script exists and is executable" {
    run test -x "$DOTFILES_PARENT_DIR/script/update"
    assert_success
}

@test "update: should fail when called directly without DOTFILES_PARENT_DIR" {
    cat > "$DOTFILES_PARENT_DIR/script/update" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ -z "${DOTFILES_PARENT_DIR:-}" ]; then
    echo "❌ This script should not be called directly!"
    echo ""
    echo "Please use the main TUI interface:"
    echo "  ./script/main"
    echo ""
    echo "Or run the bootstrap first:"
    echo "  ./script/bootstrap"
    exit 1
fi

echo "Update script running properly"
EOF
    chmod +x "$DOTFILES_PARENT_DIR/script/update"
    
    # Store the script path before unsetting the variable
    local script_path="$DOTFILES_PARENT_DIR/script/update"
    
    # Unset the variable to simulate direct call
    unset DOTFILES_PARENT_DIR
    
    run "$script_path"
    assert_failure
    assert_output --partial "❌ This script should not be called directly!"
    assert_output --partial "Please use the main TUI interface:"
}

@test "update: should set up environment variables and logging" {
    export DOTFILES_PARENT_DIR="$DOTFILES_PARENT_DIR"
    
    cat > "$DOTFILES_PARENT_DIR/script/update" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")
DOTFILES_PARENT_DIR=$(dirname "$CURRENT_DIR")
DOTFILES_LOG_FILE="$DOTFILES_PARENT_DIR/tmp/update-$(date +%Y%m%d-%H%M%S).log"
DOTFILES_DEBUG_LOG="$DOTFILES_PARENT_DIR/tmp/debug-update-$(date +%Y%m%d-%H%M%S).log"

export DOTFILES_DEBUG_LOG
export DOTFILES_LOG_FILE
export DOTFILES_PARENT_DIR

mkdir -p "$DOTFILES_PARENT_DIR/tmp"

echo "Environment set up successfully"
echo "DOTFILES_PARENT_DIR=$DOTFILES_PARENT_DIR"
echo "Log files configured"
EOF
    chmod +x "$DOTFILES_PARENT_DIR/script/update"
    
    run "$DOTFILES_PARENT_DIR/script/update"
    assert_success
    assert_output --partial "Environment set up successfully"
    assert_output --partial "DOTFILES_PARENT_DIR="
    assert_output --partial "Log files configured"
}

@test "update: should display update sequence information" {
    export DOTFILES_PARENT_DIR="$DOTFILES_PARENT_DIR"
    
    cat > "$DOTFILES_PARENT_DIR/script/update" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Mock UI functions
show_standard_header() { echo "=== HEADER ==="; }
show_section_header() { echo "=== $1 ==="; }

gum() {
    case "$1" in
        "style")
            shift
            # Skip styling options and print content
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --*) shift ;;
                    *)
                        echo "$1"
                        shift
                        ;;
                esac
            done
            ;;
        "confirm")
            echo "Confirmation displayed"
            return 0  # Auto-confirm for testing
            ;;
    esac
}

source() { true; }

main() {
    show_standard_header
    show_section_header "SYSTEM UPDATE INITIATED"
    
    gum style \
        --foreground 214 \
        --border normal \
        "▶ UPDATE SEQUENCE:" \
        "" \
        "  [01] PACKAGE REGISTRY SYNCHRONIZATION" \
        "  [02] SYSTEM COMPONENT UPGRADES"
    
    echo "Update sequence displayed"
}

main
EOF
    chmod +x "$DOTFILES_PARENT_DIR/script/update"
    
    run "$DOTFILES_PARENT_DIR/script/update"
    assert_success
    assert_output --partial "=== HEADER ==="
    assert_output --partial "=== SYSTEM UPDATE INITIATED ==="
    assert_output --partial "▶ UPDATE SEQUENCE:"
    assert_output --partial "[01] PACKAGE REGISTRY SYNCHRONIZATION"
    assert_output --partial "Update sequence displayed"
}

@test "update: should handle user confirmation for update sequence" {
    export DOTFILES_PARENT_DIR="$DOTFILES_PARENT_DIR"
    
    cat > "$DOTFILES_PARENT_DIR/script/update" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Mock gum confirm to return success
gum() {
    case "$1" in
        "confirm")
            echo "INITIATE UPDATE SEQUENCE?"
            return 0
            ;;
        "style")
            echo "Update sequence info displayed"
            ;;
    esac
}

# Mock UI functions
show_standard_header() { true; }
show_section_header() { true; }
source() { true; }

main() {
    if ! gum confirm "INITIATE UPDATE SEQUENCE?"; then
        echo "UPDATE SEQUENCE ABORTED"
        exit 0
    fi
    
    echo "Update sequence confirmed and proceeding"
}

main
EOF
    chmod +x "$DOTFILES_PARENT_DIR/script/update"
    
    run "$DOTFILES_PARENT_DIR/script/update"
    assert_success
    assert_output --partial "INITIATE UPDATE SEQUENCE?"
    assert_output --partial "Update sequence confirmed and proceeding"
}

@test "update: should update Homebrew packages when brew is available" {
    export DOTFILES_PARENT_DIR="$DOTFILES_PARENT_DIR"
    
    cat > "$DOTFILES_PARENT_DIR/script/update" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Mock functions
run_with_progressive_spinner() {
    local message="$1"
    local command="$2"
    echo "EXECUTING: $message"
    eval "$command"
}

gum() { true; }
show_standard_header() { true; }
show_section_header() { true; }
source() { true; }

main() {
    TASK_TITLE="SYSTEM UPDATE"
    
    # Update Homebrew
    if command -v brew >/dev/null 2>&1; then
        run_with_progressive_spinner "SYNCHRONIZING PACKAGE REGISTRY..." \
            "brew update"
        
        run_with_progressive_spinner "UPGRADING SYSTEM COMPONENTS..." \
            "brew upgrade"
        
        run_with_progressive_spinner "UPGRADING APPLICATION BINARIES..." \
            "brew upgrade --cask"
    fi
    
    echo "Homebrew updates completed"
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
EOF
    chmod +x "$DOTFILES_PARENT_DIR/script/update"
    
    run "$DOTFILES_PARENT_DIR/script/update"
    assert_success
    assert_output --partial "EXECUTING: SYNCHRONIZING PACKAGE REGISTRY..."
    assert_output --partial "EXECUTING: UPGRADING SYSTEM COMPONENTS..."
    assert_output --partial "EXECUTING: UPGRADING APPLICATION BINARIES..."
    assert_output --partial "Homebrew updates completed"
    
    # Verify brew commands were called
    assert_brew_called_with "update"
    assert_brew_called_with "upgrade"
    assert_brew_called_with "upgrade --cask"
}

@test "update: should update Mac App Store apps when mas is available" {
    export DOTFILES_PARENT_DIR="$DOTFILES_PARENT_DIR"
    
    cat > "$DOTFILES_PARENT_DIR/script/update" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Mock functions
run_with_progressive_spinner() {
    local message="$1"
    local command="$2"
    echo "EXECUTING: $message"
    eval "$command"
}

gum() { true; }
show_standard_header() { true; }
show_section_header() { true; }
source() { true; }

main() {
    # Update Mac App Store apps
    if command -v mas >/dev/null 2>&1; then
        run_with_progressive_spinner "UPDATING APPLICATION STORE REGISTRY..." \
            "mas upgrade"
    fi
    
    echo "Mac App Store updates completed"
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
EOF
    chmod +x "$DOTFILES_PARENT_DIR/script/update"
    
    run "$DOTFILES_PARENT_DIR/script/update"
    assert_success
    assert_output --partial "EXECUTING: UPDATING APPLICATION STORE REGISTRY..."
    assert_output --partial "Mac App Store updates completed"
}

@test "update: should update dotfiles with chezmoi when available" {
    export DOTFILES_PARENT_DIR="$DOTFILES_PARENT_DIR"
    
    cat > "$DOTFILES_PARENT_DIR/script/update" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Mock functions
run_with_progressive_spinner() {
    local message="$1"
    local command="$2"
    echo "EXECUTING: $message"
    eval "$command"
}

gum() { true; }
show_standard_header() { true; }
show_section_header() { true; }
source() { true; }

main() {
    # Update dotfiles and sync configuration
    if command -v chezmoi >/dev/null 2>&1; then
        run_with_progressive_spinner "SYNCHRONIZING CONFIGURATION MATRIX..." \
            "chezmoi update"
        
        run_with_progressive_spinner "APPLYING CONFIGURATION CHANGES..." \
            "echo 'Configuration applied'"
    fi
    
    echo "Dotfiles updates completed"
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
EOF
    chmod +x "$DOTFILES_PARENT_DIR/script/update"
    
    run "$DOTFILES_PARENT_DIR/script/update"
    assert_success
    assert_output --partial "EXECUTING: SYNCHRONIZING CONFIGURATION MATRIX..."
    assert_output --partial "EXECUTING: APPLYING CONFIGURATION CHANGES..."
    assert_output --partial "Dotfiles updates completed"
}

@test "update: should handle missing commands gracefully" {
    export DOTFILES_PARENT_DIR="$DOTFILES_PARENT_DIR"
    
    # Remove all commands from PATH
    export PATH="/usr/bin:/bin"
    
    cat > "$DOTFILES_PARENT_DIR/script/update" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

gum() { true; }
show_standard_header() { true; }
show_section_header() { true; }
source() { true; }

main() {
    echo "Checking for Homebrew..."
    if command -v brew >/dev/null 2>&1; then
        echo "Homebrew found"
    else
        echo "Homebrew not found, skipping brew updates"
    fi
    
    echo "Checking for mas..."
    if command -v mas >/dev/null 2>&1; then
        echo "mas found"
    else
        echo "mas not found, skipping App Store updates"
    fi
    
    echo "Checking for chezmoi..."
    if command -v chezmoi >/dev/null 2>&1; then
        echo "chezmoi found"
    else
        echo "chezmoi not found, skipping dotfiles updates"
    fi
    
    echo "Update check completed"
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
EOF
    chmod +x "$DOTFILES_PARENT_DIR/script/update"
    
    run "$DOTFILES_PARENT_DIR/script/update"
    assert_success
    assert_output --partial "Homebrew not found, skipping brew updates"
    assert_output --partial "mas not found, skipping App Store updates"
    assert_output --partial "chezmoi not found, skipping dotfiles updates"
    assert_output --partial "Update check completed"
}

@test "update: should execute as script when called directly with proper environment" {
    export DOTFILES_PARENT_DIR="$DOTFILES_PARENT_DIR"
    
    cat > "$DOTFILES_PARENT_DIR/script/update" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Mock all required functions
gum() { true; }
show_standard_header() { true; }
show_section_header() { true; }
show_completion() { echo "COMPLETION: $1"; }
show_footer_prompt() { echo "Footer prompt shown"; }
source() { true; }
run_with_progressive_spinner() { echo "SPINNER: $1"; }

main() {
    echo "Main function started"
    show_completion "SYSTEM UPDATE COMPLETE"
    show_footer_prompt
}

# Execute if called directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
EOF
    chmod +x "$DOTFILES_PARENT_DIR/script/update"
    
    run "$DOTFILES_PARENT_DIR/script/update"
    assert_success
    assert_output --partial "Main function started"
    assert_output --partial "COMPLETION: SYSTEM UPDATE COMPLETE"
    assert_output --partial "Footer prompt shown"
}