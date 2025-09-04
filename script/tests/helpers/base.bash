#!/usr/bin/env bash

# Test helper functions for the dotfiles project
# Provides common setup, teardown, and utility functions for bats tests

# Load bats ecosystem libraries using absolute paths from project root
# Find the tests directory by walking up from BATS_TEST_DIRNAME until we find 'helpers' and 'support'
CURRENT_DIR="${BATS_TEST_DIRNAME}"
while [[ "$CURRENT_DIR" != "/" ]]; do
    if [[ -d "$CURRENT_DIR/helpers" && -d "$CURRENT_DIR/support" ]]; then
        TESTS_DIR="$CURRENT_DIR"
        break
    fi
    CURRENT_DIR="$(dirname "$CURRENT_DIR")"
done

# Load support libraries with absolute paths
load "$TESTS_DIR/support/bats-support/load"
load "$TESTS_DIR/support/bats-assert/load"

# Test environment variables - use project tmp/tests directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
export PROJECT_ROOT
export TEST_TEMP_DIR="$PROJECT_ROOT/tmp/tests/dotfiles-test-$$"
export DOTFILES_PARENT_DIR="$TEST_TEMP_DIR/dotfiles"
export DOTFILES_LOG_FILE="$TEST_TEMP_DIR/test.log"
export DOTFILES_DEBUG_LOG="$TEST_TEMP_DIR/debug.log"

# Mock directories and files
export MOCK_HOME="$TEST_TEMP_DIR/home"
export MOCK_BREW_PREFIX="$TEST_TEMP_DIR/homebrew"
export MOCK_APPLICATIONS_DIR="$TEST_TEMP_DIR/Applications"

# Initialize test environment
setup_test_environment() {
    # Create test directory structure
    mkdir -p "$TEST_TEMP_DIR"
    mkdir -p "$DOTFILES_PARENT_DIR"
    mkdir -p "$DOTFILES_PARENT_DIR/tmp"
    mkdir -p "$DOTFILES_PARENT_DIR/script/core"
    mkdir -p "$MOCK_HOME"
    mkdir -p "$MOCK_BREW_PREFIX/bin"
    mkdir -p "$MOCK_APPLICATIONS_DIR"

    # Create mock log files
    touch "$DOTFILES_LOG_FILE"
    touch "$DOTFILES_DEBUG_LOG"

    # Export paths for scripts under test
    export PATH="$MOCK_BREW_PREFIX/bin:/usr/bin:/bin:$PATH"
    export HOME="$MOCK_HOME"
}

# Clean up test environment
teardown_test_environment() {
    if [ -d "$TEST_TEMP_DIR" ]; then
        rm -rf "$TEST_TEMP_DIR"
    fi

    # Clean up any background processes
    if [ -f "/tmp/.bootstrap_sudo_keepalive_pid" ]; then
        local pid
        pid=$(cat "/tmp/.bootstrap_sudo_keepalive_pid" 2>/dev/null)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
            # Wait a moment for graceful shutdown
            sleep 0.1
            # Force kill if still running
            if kill -0 "$pid" 2>/dev/null; then
                kill -9 "$pid" 2>/dev/null || true
            fi
        fi
        rm -f "/tmp/.bootstrap_sudo_keepalive_pid"
    fi

    # Clean up any other test-related background processes
    # Only target specific patterns and avoid the current test process
    local test_pids pid
    test_pids=$(pgrep -f "dotfiles.*bootstrap.*sudo" 2>/dev/null || true)
    if [ -n "$test_pids" ]; then
        for pid in $test_pids; do
            if [ -n "$pid" ] && [ "$pid" != "$$" ] && [ "$pid" != "$PPID" ] && kill -0 "$pid" 2>/dev/null; then
                kill "$pid" 2>/dev/null || true
            fi
        done
    fi

    # Clean up sudo authentication marker
    rm -f "/tmp/.bootstrap_sudo_authenticated"
}

# Create a mock script with specified behavior
create_mock_script() {
    local script_name="$1"
    local exit_code="${2:-0}"
    local output="${3:-}"
    local script_path="$MOCK_BREW_PREFIX/bin/$script_name"

    cat >"$script_path" <<EOF
#!/bin/bash
echo "$output"
exit $exit_code
EOF
    chmod +x "$script_path"
}

# Create a mock executable that logs its invocation
create_logging_mock() {
    local command_name="$1"
    local log_file="$TEST_TEMP_DIR/mock_calls.log"
    local script_path="$MOCK_BREW_PREFIX/bin/$command_name"

    cat >"$script_path" <<'EOF'
#!/bin/bash
echo "$(date '+%H:%M:%S') MOCK_CALL: $0 $*" >> "LOG_FILE_PLACEHOLDER"
case "$1" in
    --version|version) echo "mock-version-1.0.0" ;;
    --help|help) echo "Mock $0 help" ;;
    *) echo "Mock $0 executed with args: $*" ;;
esac
exit 0
EOF
    sed -i '' "s|LOG_FILE_PLACEHOLDER|$log_file|g" "$script_path"
    chmod +x "$script_path"
}

# Mock macOS system commands
setup_macos_mocks() {
    # System information commands
    create_mock_script "sw_vers" 0 "ProductName:	macOS\nProductVersion:	15.0\nBuildVersion:	24A335"
    create_mock_script "uname" 0 "arm64"
    create_mock_script "fdesetup" 0 "FileVault is On."
    create_mock_script "df" 0 "Filesystem     Size   Used  Avail Capacity  iused   ifree %iused  Mounted on\n/dev/disk3s1s1  494Gi   15Gi  100Gi    14%  488318 1048088   32%   /"

    # Development tools
    create_mock_script "xcode-select" 0 "/Applications/Xcode.app/Contents/Developer"
    create_mock_script "softwareupdate" 0 "Software Update Tool"

    # Network connectivity
    create_mock_script "ping" 0 "PING github.com (140.82.113.4): 56 data bytes\n64 bytes from 140.82.113.4: icmp_seq=0 ttl=52 time=25.050 ms"
    create_mock_script "curl" 0 "# Homebrew install script mock"

    # Package managers and tools
    create_logging_mock "brew"
    create_logging_mock "mas"
    create_logging_mock "op"
    create_logging_mock "chezmoi"
    create_logging_mock "gum"
    create_logging_mock "cargo"
    create_logging_mock "rustup-init"

    # System utilities
    create_mock_script "osascript" 0 "user@example.com"
    create_mock_script "sudo" 0 ""
    create_mock_script "id" 0 "uid=501(user) gid=20(staff)"
}

# Setup fake filesystem structure
setup_fake_filesystem() {
    # Create common directories
    mkdir -p "$MOCK_HOME/.config"
    mkdir -p "$MOCK_HOME/.ssh"
    mkdir -p "$MOCK_HOME/.cargo"

    # Create dependencies directory structure
    mkdir -p "$DOTFILES_PARENT_DIR/dependencies"

    # Create mock PAM directory
    mkdir -p "$TEST_TEMP_DIR/etc/pam.d"
    cat >"$TEST_TEMP_DIR/etc/pam.d/sudo" <<'EOF'
# sudo: auth account password session
auth       sufficient     pam_smartcard.so
auth       required       pam_opendirectory.so
account    required       pam_permit.so
password   required       pam_deny.so
session    required       pam_permit.so
EOF

    # Create mock Brewfiles
    cat >"$DOTFILES_PARENT_DIR/dependencies/dependencies.brewfile" <<'EOF'
# Essential dependencies
brew "git"
brew "curl"
brew "wget"
cask "1password-cli"
EOF

    cat >"$DOTFILES_PARENT_DIR/dependencies/applications.brewfile" <<'EOF'
# Applications
cask "visual-studio-code"
cask "firefox"
EOF
}

# Verify mock call was made
assert_mock_called() {
    local command_name="$1"
    local expected_args="${2:-}"
    local log_file="$TEST_TEMP_DIR/mock_calls.log"

    if [ ! -f "$log_file" ]; then
        fail "Mock calls log file not found"
    fi

    if [ -n "$expected_args" ]; then
        assert_file_contains "$log_file" "MOCK_CALL: $MOCK_BREW_PREFIX/bin/$command_name $expected_args"
    else
        assert_file_contains "$log_file" "MOCK_CALL: $MOCK_BREW_PREFIX/bin/$command_name"
    fi
}

# Verify file contains expected content
assert_file_contains() {
    local file_path="$1"
    local expected_content="$2"

    if [ ! -f "$file_path" ]; then
        fail "File does not exist: $file_path"
    fi

    if ! grep -q "$expected_content" "$file_path"; then
        fail "File $file_path does not contain: $expected_content"
    fi
}

# Verify log file contains message
assert_log_contains() {
    local level="$1"
    local message="$2"
    local log_file="${3:-$DOTFILES_LOG_FILE}"

    assert_file_contains "$log_file" "$level: $message"
}

# Setup PATH to use mocked commands
setup_mock_path() {
    export PATH="$MOCK_BREW_PREFIX/bin:/usr/bin:/bin:$PATH"
}

# Create minimal test script
create_test_script() {
    local script_name="$1"
    local content="$2"
    local script_path="$DOTFILES_PARENT_DIR/script/$script_name"

    cat >"$script_path" <<EOF
#!/usr/bin/env bash
set -euo pipefail
$content
EOF
    chmod +x "$script_path"
}

# Standard test setup function
test_setup() {
    setup_test_environment
    setup_macos_mocks
    setup_fake_filesystem
    setup_mock_path
}

# Standard test teardown function
test_teardown() {
    teardown_test_environment
}

# =============================================================================
# DRY HELPER FUNCTIONS - Reduce repetition across test files
# =============================================================================

# Standard script test setup - replaces repeated setup() functions
setup_script_test() {
    local script_name="$1"
    test_setup
    setup_advanced_mocks
    copy_test_scripts "$script_name"
    setup_test_environment_vars
}

# Copy required scripts and helpers to test environment
copy_test_scripts() {
    local script_name="$1"
    # Use PROJECT_ROOT instead of relative paths to handle reorganized test structure
    if [ -f "$PROJECT_ROOT/script/$script_name" ]; then
        cp "$PROJECT_ROOT/script/$script_name" "$DOTFILES_PARENT_DIR/script/$script_name"
    fi

    # Always copy helpers directory
    if [ -d "$PROJECT_ROOT/script/core" ]; then
        cp -r "$PROJECT_ROOT/script/core" "$DOTFILES_PARENT_DIR/script/"
    fi
}

# Setup standard environment variables for tests
setup_test_environment_vars() {
    export DOTFILES_PARENT_DIR="$DOTFILES_PARENT_DIR"
    DOTFILES_LOG_FILE="$DOTFILES_PARENT_DIR/tmp/tests/test-$(date +%Y%m%d-%H%M%S).log"
    DOTFILES_DEBUG_LOG="$DOTFILES_PARENT_DIR/tmp/debug-test-$(date +%Y%m%d-%H%M%S).log"
    export DOTFILES_LOG_FILE
    export DOTFILES_DEBUG_LOG

    # Ensure log directories exist
    mkdir -p "$DOTFILES_PARENT_DIR/tmp/tests"
    touch "$DOTFILES_LOG_FILE" "$DOTFILES_DEBUG_LOG"
}

# Create script from common templates to reduce inline script duplication
create_script_from_template() {
    local script_name="$1"
    local template_name="$2"
    local script_path="$DOTFILES_PARENT_DIR/script/$script_name"

    case "$template_name" in
        "env_check_fail")
            create_env_check_script "$script_path" "fail"
            ;;
        "env_check_pass")
            create_env_check_script "$script_path" "pass"
            ;;
        "gum_check_fail")
            create_gum_check_script "$script_path" "fail"
            ;;
        "minimal_ui")
            create_minimal_ui_script "$script_path"
            ;;
        *)
            echo "Unknown template: $template_name" >&2
            return 1
            ;;
    esac
}

# Template: Environment check script
create_env_check_script() {
    local script_path="$1"
    local mode="$2"

    cat >"$script_path" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ -z "${DOTFILES_PARENT_DIR:-}" ]; then
    echo "❌ This script should not be called directly!"
    echo ""
    echo "Please use the main TUI interface:"
    echo "  ./script/main"
    exit 1
fi

echo "DOTFILES_PARENT_DIR=$DOTFILES_PARENT_DIR"
echo "Log files configured properly"
EOF

    if [ "$mode" = "pass" ]; then
        cat >>"$script_path" <<'EOF'
echo "Script running successfully"
EOF
    fi

    chmod +x "$script_path"
}

# Template: Gum availability check script
create_gum_check_script() {
    local script_path="$1"
    local mode="$2"

    cat >"$script_path" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if ! command -v gum > /dev/null 2>&1; then
    echo "❌ gum TUI tool not found!"
    echo ""
    echo "Please run the minimal bootstrap first:"
    echo "  ./script/bootstrap"
    echo ""
    echo "Or install gum manually:"
    echo "  brew install gum"
    exit 1
fi
EOF

    if [ "$mode" = "pass" ]; then
        cat >>"$script_path" <<'EOF'
echo "Gum is available and working"
EOF
    fi

    chmod +x "$script_path"
}

# Template: Minimal UI script with standard interface
create_minimal_ui_script() {
    local script_path="$1"

    cat >"$script_path" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers/ui"

show_standard_header
show_section_header "TEST UI"
echo "Script completed successfully"
EOF

    chmod +x "$script_path"
}

# =============================================================================
# COMMON ASSERTION HELPERS - Standardize repeated assertion patterns
# =============================================================================

# Assert script exists and is executable
assert_script_executable() {
    local script_name="$1"
    run test -x "$DOTFILES_PARENT_DIR/script/$script_name"
    assert_success
}

# Assert standard environment failure pattern
assert_environment_failure() {
    local expected_message="${1:-❌ This script should not be called directly!}"
    assert_failure
    assert_output --partial "$expected_message"
    assert_output --partial "Please use the main TUI interface:"
}

# Assert gum missing error pattern
assert_gum_missing_error() {
    assert_failure
    assert_output --partial "❌ gum TUI tool not found!"
    assert_output --partial "Please run the minimal bootstrap first:"
    assert_output --partial "Or install gum manually:"
}

# Assert standard UI output structure
assert_standard_ui_output() {
    assert_output --partial "=== HEADER ==="
    assert_output --partial "================"
}

# Assert environment variables are properly set
assert_environment_setup() {
    assert_output --partial "DOTFILES_PARENT_DIR="
    assert_output --partial "Log files configured"
}

# Assert script completion message
assert_script_success() {
    local script_type="${1:-script}"
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
        *)
            assert_output --partial "completed successfully"
            ;;
    esac
}

# Remove command from PATH for testing missing dependencies
remove_command_from_path() {
    local command_name="$1"
    PATH=$(echo "$PATH" | tr ':' '\n' | grep -v "$command_name" | tr '\n' ':')
    export PATH
}

# =============================================================================
# STANDARDIZED SETUP PATTERNS - Eliminate 90% of setup/teardown duplication
# =============================================================================

# Standard script test setup - replaces most common setup pattern
setup_for_script() {
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

    # Set up environment for specific scripts
    setup_script_environment "$script_name"
}

# Environment setup for specific script types
setup_script_environment() {
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

# UI test setup pattern
setup_for_ui_script() {
    local script_name="$1"
    setup_for_script "$script_name"

    # Create additional mock scripts often needed by UI tests
    create_test_script "setup" 'echo "Setup script executed"'
    create_test_script "update" 'echo "Update script executed"'
    create_test_script "status" 'echo "Status script executed"'
}

# Business logic test setup (no script copying needed)
setup_for_business_logic() {
    test_setup
    setup_advanced_mocks
    setup_script_environment "business_logic"
}

# =============================================================================
# PARAMETERIZED TEST HELPERS - Generate similar tests with different data
# =============================================================================

# Test environment failure for any script
test_environment_failure_for_script() {
    local script_name="$1"
    local script_path="$DOTFILES_PARENT_DIR/script/$script_name"

    create_script_from_template "$script_name" "env_check_fail"
    unset DOTFILES_PARENT_DIR

    run "$script_path"
    assert_environment_failure
}

# Test basic script validation (existence and executability)
test_basic_script_validation() {
    local script_name="$1"
    assert_script_executable "$script_name"
}
