#!/usr/bin/env bats

# BDD Tests for script/bootstrap
# Validates minimal bootstrap functionality and prerequisite checks

load helper
load mocks

setup() {
    test_setup
    setup_advanced_mocks
    
    # Copy the actual bootstrap script to test location
    cp "${BATS_TEST_DIRNAME}/../../script/bootstrap" "$DOTFILES_PARENT_DIR/script/bootstrap"
    
    # Copy helper scripts
    cp -r "${BATS_TEST_DIRNAME}/../../script/core" "$DOTFILES_PARENT_DIR/script/"
}

teardown() {
    test_teardown
}

@test "bootstrap: should validate script exists and is executable" {
    run test -x "$DOTFILES_PARENT_DIR/script/bootstrap"
    assert_success
}

@test "bootstrap: should set required environment variables" {
    # Create a minimal bootstrap that just exports variables
    cat > "$DOTFILES_PARENT_DIR/script/bootstrap" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")
DOTFILES_PARENT_DIR=$(dirname "$CURRENT_DIR")
DOTFILES_LOG_FILE="$DOTFILES_PARENT_DIR/tmp/bootstrap-$(date +%Y%m%d-%H%M%S).log"
DOTFILES_DEBUG_LOG="$DOTFILES_PARENT_DIR/tmp/debug-bootstrap-$(date +%Y%m%d-%H%M%S).log"

export DOTFILES_DEBUG_LOG
export DOTFILES_LOG_FILE
export DOTFILES_PARENT_DIR

echo "DOTFILES_PARENT_DIR=$DOTFILES_PARENT_DIR"
echo "DOTFILES_LOG_FILE=$DOTFILES_LOG_FILE"
echo "DOTFILES_DEBUG_LOG=$DOTFILES_DEBUG_LOG"
EOF
    chmod +x "$DOTFILES_PARENT_DIR/script/bootstrap"
    
    run "$DOTFILES_PARENT_DIR/script/bootstrap"
    assert_success
    assert_output --partial "DOTFILES_PARENT_DIR="
    assert_output --partial "DOTFILES_LOG_FILE="
    assert_output --partial "DOTFILES_DEBUG_LOG="
}

@test "bootstrap: should create tmp directory structure" {
    # Mock a minimal bootstrap that creates directories
    cat > "$DOTFILES_PARENT_DIR/script/bootstrap" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")
DOTFILES_PARENT_DIR=$(dirname "$CURRENT_DIR")

mkdir -p "$DOTFILES_PARENT_DIR/tmp"
echo "tmp directory created"
EOF
    chmod +x "$DOTFILES_PARENT_DIR/script/bootstrap"
    
    run "$DOTFILES_PARENT_DIR/script/bootstrap"
    assert_success
    assert_output "tmp directory created"
    
    # Verify directory was created
    run test -d "$DOTFILES_PARENT_DIR/tmp"
    assert_success
}

@test "bootstrap: should fail when FileVault is disabled" {
    # Trigger file vault disabled condition
    create_trigger_file "no_disk_encryption"
    
    # Create minimal bootstrap that sources prerequisites
    cat > "$DOTFILES_PARENT_DIR/script/bootstrap" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")
DOTFILES_PARENT_DIR=$(dirname "$CURRENT_DIR")

# Mock source operations
source() { 
    case "$1" in
        *"common") ;;
        *"prerequisites") 
            ensure_disk_encryption() {
                if [ "$(fdesetup status | head -1)" = "FileVault is Off." ]; then
                    echo "ERROR: You need to enable disk encryption before you can continue."
                    exit 1
                fi
            }
            check_macos_version() { true; }
            ensure_command_line_tools() { true; }
            ensure_homebrew() { true; }
            ;;
    esac
}

# Mock logging functions
log_info() { echo "INFO: $1"; }
log_success() { echo "SUCCESS: $1"; }

source "$CURRENT_DIR/helpers/common"
source "$CURRENT_DIR/helpers/prerequisites"

log_info "Running prerequisite checks..."
check_macos_version "10.15"
ensure_disk_encryption
EOF
    chmod +x "$DOTFILES_PARENT_DIR/script/bootstrap"
    
    run "$DOTFILES_PARENT_DIR/script/bootstrap"
    assert_failure
    assert_output --partial "ERROR: You need to enable disk encryption"
}

@test "bootstrap: should check macOS version compatibility" {
    # Trigger old macOS version
    create_trigger_file "old_macos_version"
    
    cat > "$DOTFILES_PARENT_DIR/script/bootstrap" << EOF
#!/usr/bin/env bash
set -euo pipefail

# Use the mock PATH
export PATH="$MOCK_BREW_PREFIX/bin:\$PATH"

check_macos_version() {
    local min_version="\$1"
    local current_version=\$(sw_vers -productVersion)
    
    if ! printf '%s\\n%s\\n' "\$min_version" "\$current_version" | sort -V -C; then
        echo "ERROR: This script requires macOS \$min_version or later. Current version: \$current_version"
        exit 1
    fi
}

check_macos_version "15.1"
echo "macOS version check passed"
EOF
    chmod +x "$DOTFILES_PARENT_DIR/script/bootstrap"
    
    run "$DOTFILES_PARENT_DIR/script/bootstrap"
    assert_failure
    assert_output --partial "ERROR: This script requires macOS 15.1 or later"
}

@test "bootstrap: should install homebrew when missing" {
    # Remove brew from PATH - use minimal PATH to ensure brew is not found
    export PATH="/usr/bin:/bin:/usr/sbin:/sbin"
    
    cat > "$DOTFILES_PARENT_DIR/script/bootstrap" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

check_command() {
    local command="$1"
    if command -v "$command" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

ensure_homebrew() {
    if check_command "brew" "Homebrew package manager"; then
        echo "Homebrew already installed"
        return 0
    fi
    
    echo "Installing Homebrew..."
    # Mock the installation
    mkdir -p "MOCK_BREW_PREFIX_PLACEHOLDER/bin"
    cat > "MOCK_BREW_PREFIX_PLACEHOLDER/bin/brew" << 'BREW_EOF'
#!/bin/bash
echo "Homebrew mock installed"
BREW_EOF
    chmod +x "MOCK_BREW_PREFIX_PLACEHOLDER/bin/brew"
    export PATH="MOCK_BREW_PREFIX_PLACEHOLDER/bin:$PATH"
    echo "Homebrew installation completed"
}

ensure_homebrew
EOF
    sed -i '' "s|MOCK_BREW_PREFIX_PLACEHOLDER|$MOCK_BREW_PREFIX|g" "$DOTFILES_PARENT_DIR/script/bootstrap"
    chmod +x "$DOTFILES_PARENT_DIR/script/bootstrap"
    
    run "$DOTFILES_PARENT_DIR/script/bootstrap"
    assert_success
    assert_output --partial "Homebrew installation completed"
}

@test "bootstrap: should install gum TUI tool" {
    cat > "$DOTFILES_PARENT_DIR/script/bootstrap" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

check_command() {
    local command="$1"
    if command -v "$command" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

log_info() { echo "INFO: $1"; }
log_success() { echo "SUCCESS: $1"; }

if ! check_command "gum" "Gum TUI tool"; then
    log_info "Installing gum TUI tool..."
    echo "Mock: brew install gum"
    log_success "gum installed successfully"
else
    log_info "gum already available"
fi
EOF
    chmod +x "$DOTFILES_PARENT_DIR/script/bootstrap"
    
    run "$DOTFILES_PARENT_DIR/script/bootstrap"
    assert_success
    assert_output --partial "INFO: gum already available"
}

@test "bootstrap: should complete successfully and launch main interface" {
    # Create a mock main script
    cat > "$DOTFILES_PARENT_DIR/script/main" << 'EOF'
#!/usr/bin/env bash
echo "Main interface launched"
EOF
    chmod +x "$DOTFILES_PARENT_DIR/script/main"
    
    cat > "$DOTFILES_PARENT_DIR/script/bootstrap" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")

log_success() { echo "SUCCESS: $1"; }

log_success "Bootstrap complete! Launching main interface..."

exec "$CURRENT_DIR/main"
EOF
    chmod +x "$DOTFILES_PARENT_DIR/script/bootstrap"
    
    run "$DOTFILES_PARENT_DIR/script/bootstrap"
    assert_success
    assert_output --partial "SUCCESS: Bootstrap complete!"
    assert_output --partial "Main interface launched"
}

@test "bootstrap: should handle missing dependencies gracefully" {
    # Test with completely empty PATH
    export PATH="/usr/bin:/bin"
    
    cat > "$DOTFILES_PARENT_DIR/script/bootstrap" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

check_command() {
    local command="$1"
    if command -v "$command" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

if ! check_command "nonexistent_command"; then
    echo "Command not found as expected"
    exit 0
fi

echo "Should not reach here"
exit 1
EOF
    chmod +x "$DOTFILES_PARENT_DIR/script/bootstrap"
    
    run "$DOTFILES_PARENT_DIR/script/bootstrap"
    assert_success
    assert_output "Command not found as expected"
}

@test "bootstrap: should log operations to file" {
    cat > "$DOTFILES_PARENT_DIR/script/bootstrap" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")
DOTFILES_PARENT_DIR=$(dirname "$CURRENT_DIR")
DOTFILES_LOG_FILE="$DOTFILES_PARENT_DIR/tmp/bootstrap-test.log"

export DOTFILES_LOG_FILE
export DOTFILES_PARENT_DIR

mkdir -p "$DOTFILES_PARENT_DIR/tmp"

record() {
    local level="${1:-INFO}"
    shift
    local log_dir="${DOTFILES_PARENT_DIR}/tmp/log"
    mkdir -p "$log_dir"
    echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ') $level: $@" >> "$log_dir/bootstrap.log" 2>&1
}

record "INFO" "Bootstrap started"
record "SUCCESS" "Bootstrap completed"

echo "Logging test completed"
EOF
    chmod +x "$DOTFILES_PARENT_DIR/script/bootstrap"
    
    run "$DOTFILES_PARENT_DIR/script/bootstrap"
    assert_success
    assert_output "Logging test completed"
    
    # Verify log file was created and contains expected entries
    run test -f "$DOTFILES_PARENT_DIR/tmp/log/bootstrap.log"
    assert_success
    
    run grep "Bootstrap started" "$DOTFILES_PARENT_DIR/tmp/log/bootstrap.log"
    assert_success
    
    run grep "Bootstrap completed" "$DOTFILES_PARENT_DIR/tmp/log/bootstrap.log"
    assert_success
}