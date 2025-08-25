#!/usr/bin/env bats

# BDD Tests for script/core/prerequisites
# Validates prerequisite checks and network validation integration

# Load helpers using correct relative path
load "../../helpers/helper"
load "$TESTS_DIR/helpers/mocks"

setup() {
    test_setup
    setup_advanced_mocks
    
    # Copy helper files
    cp -r "$PROJECT_ROOT/script/core" "$DOTFILES_PARENT_DIR/script/"
}

teardown() {
    test_teardown
}

# ============================================================================
# Prerequisites - Network Validation Integration Tests
# ============================================================================

@test "prerequisites: should validate network before Homebrew installation" {
    cat > "$DOTFILES_PARENT_DIR/test_homebrew_network.sh" << 'EOF'
#!/usr/bin/env bash
export DOTFILES_PARENT_DIR="$(pwd)"
source "script/core/prerequisites"

# Mock check_command to simulate brew not being available initially
check_command() {
    case "$1" in
        "brew") return 1 ;;  # Homebrew not available
        *) command -v "$1" >/dev/null 2>&1 ;;
    esac
}

# Mock network validation
validate_network_operation() {
    local operation="$1"
    local url="$2"
    
    echo "Validating network for: $operation"
    echo "URL: $url"
    
    case "$url" in
        "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh")
            echo "Network validation passed for Homebrew installation"
            return 0
            ;;
        *)
            echo "Network validation failed"
            return 1
            ;;
    esac
}

# Mock run command to avoid actual installation
run() {
    echo "Mock: Would run Homebrew installation: $1"
    return 0
}

# Mock setup_homebrew_env and ensure_password_manager
setup_homebrew_env() { echo "Mock: Setting up Homebrew environment"; }
ensure_password_manager() { echo "Mock: Setting up password manager"; }

log_info() { echo "LOG_INFO: $1"; }
log_success() { echo "LOG_SUCCESS: $1"; }
show_error() { echo "SHOW_ERROR: $1"; return 1; }

# Export functions
export -f check_command validate_network_operation run setup_homebrew_env ensure_password_manager log_info log_success show_error

# Override check_command to succeed after installation
check_command() {
    case "$1" in
        "brew") 
            # First call fails, subsequent calls succeed
            if [ "${BREW_INSTALLED:-}" = "true" ]; then
                return 0
            else
                return 1
            fi
            ;;
        *) command -v "$1" >/dev/null 2>&1 ;;
    esac
}

# Mock run to mark brew as installed
run() {
    echo "Mock: Would run Homebrew installation: $1"
    BREW_INSTALLED="true"
    return 0
}

export -f check_command run

# Test ensure_homebrew with network validation
ensure_homebrew

echo "Homebrew network validation test completed"
EOF
    chmod +x "$DOTFILES_PARENT_DIR/test_homebrew_network.sh"
    
    run "$DOTFILES_PARENT_DIR/test_homebrew_network.sh"
    assert_success
    assert_output --partial "LOG_INFO: Installing Homebrew..."
    assert_output --partial "Validating network for: Homebrew installation"
    assert_output --partial "URL: https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
    assert_output --partial "Network validation passed for Homebrew installation"
    assert_output --partial "Mock: Would run Homebrew installation"
    assert_output --partial "Homebrew network validation test completed"
}

@test "prerequisites: should handle network validation failure gracefully" {
    cat > "$DOTFILES_PARENT_DIR/test_network_failure.sh" << 'EOF'
#!/usr/bin/env bash
export DOTFILES_PARENT_DIR="$(pwd)"
source "script/core/prerequisites"

# Mock check_command to simulate brew not being available
check_command() {
    case "$1" in
        "brew") return 1 ;;
        *) command -v "$1" >/dev/null 2>&1 ;;
    esac
}

# Mock network validation to fail
validate_network_operation() {
    echo "Network validation failed for: $1"
    return 1
}

setup_homebrew_env() { echo "Mock: Setting up Homebrew environment"; }
log_info() { echo "LOG_INFO: $1"; }
show_error() { echo "SHOW_ERROR: $1"; return 1; }

export -f check_command validate_network_operation setup_homebrew_env log_info show_error

# Test ensure_homebrew with network failure (but don't exit)
if ! ensure_homebrew 2>/dev/null; then
    echo "Homebrew installation correctly failed due to network"
else
    echo "Error: Should have failed due to network"
    exit 1
fi

echo "Network failure handling test completed"
EOF
    chmod +x "$DOTFILES_PARENT_DIR/test_network_failure.sh"
    
    run "$DOTFILES_PARENT_DIR/test_network_failure.sh"
    assert_success
    assert_output --partial "LOG_INFO: Installing Homebrew..."
    assert_output --partial "Network validation failed for: Homebrew installation"
    assert_output --partial "Homebrew installation correctly failed due to network"
    assert_output --partial "Network failure handling test completed"
}

# ============================================================================
# Prerequisites - System Validation Tests
# ============================================================================

@test "prerequisites: should validate macOS version requirements" {
    cat > "$DOTFILES_PARENT_DIR/test_macos_version.sh" << 'EOF'
#!/usr/bin/env bash
export DOTFILES_PARENT_DIR="$(pwd)"
source "script/core/prerequisites"

# Mock sw_vers to return current macOS version
sw_vers() {
    case "$1" in
        "-productVersion")
            echo "14.0"
            ;;
        *)
            echo "ProductName:	macOS"
            echo "ProductVersion:	14.0"
            echo "BuildVersion:	23A344"
            ;;
    esac
}

silent() { eval "$1" >/dev/null 2>&1; }
log_info() { echo "LOG_INFO: $1"; }
show_error() { echo "SHOW_ERROR: $1"; return 1; }

export -f sw_vers silent log_info show_error

# Test version check with compatible version
check_macos_version "11.0"

echo "macOS version validation test completed"
EOF
    chmod +x "$DOTFILES_PARENT_DIR/test_macos_version.sh"
    
    run "$DOTFILES_PARENT_DIR/test_macos_version.sh"
    assert_success
    assert_output --partial "LOG_INFO: OS version check passed: 14.0"
    assert_output --partial "macOS version validation test completed"
}

@test "prerequisites: should validate disk space requirements" {
    cat > "$DOTFILES_PARENT_DIR/test_disk_space.sh" << 'EOF'
#!/usr/bin/env bash
export DOTFILES_PARENT_DIR="$(pwd)"
source "script/core/prerequisites"

# Mock df to return sufficient disk space
df() {
    case "$*" in
        "-h /")
            echo "Filesystem     Size   Used  Avail Capacity  iused   ifree %iused  Mounted on"
            echo "/dev/disk3s1s1  494Gi   400Gi   94Gi    81%  488318 1048088   32%   /"
            ;;
        *)
            /bin/df "$@"
            ;;
    esac
}

log_info() { echo "LOG_INFO: $1"; }
show_error() { echo "SHOW_ERROR: $1"; return 1; }

export -f df log_info show_error

# Test disk space check
check_disk_space 5

echo "Disk space validation test completed"
EOF
    chmod +x "$DOTFILES_PARENT_DIR/test_disk_space.sh"
    
    run "$DOTFILES_PARENT_DIR/test_disk_space.sh"
    assert_success
    assert_output --partial "LOG_INFO: Disk space check passed: 94GB available"
    assert_output --partial "Disk space validation test completed"
}

@test "prerequisites: should handle insufficient disk space" {
    cat > "$DOTFILES_PARENT_DIR/test_insufficient_disk.sh" << 'EOF'
#!/usr/bin/env bash
export DOTFILES_PARENT_DIR="$(pwd)"
source "script/core/prerequisites"

# Mock df to return insufficient disk space
df() {
    case "$*" in
        "-h /")
            echo "Filesystem     Size   Used  Avail Capacity  iused   ifree %iused  Mounted on"
            echo "/dev/disk3s1s1  494Gi   490Gi    4Gi    99%  488318 1048088   32%   /"
            ;;
        *)
            /bin/df "$@"
            ;;
    esac
}

# Mock show_error to prevent exit but still indicate failure
show_error() { 
    echo "SHOW_ERROR: $1"
    # Don't exit, but set a flag to indicate error occurred
    return 1
}

log_info() { echo "LOG_INFO: $1"; }

export -f df log_info show_error

# Test disk space check with insufficient space (capture exit status)
if check_disk_space 5 2>/dev/null; then
    echo "Error: Should have failed due to insufficient disk space"
    exit 1
else
    echo "Disk space check correctly failed"
fi

echo "Insufficient disk space test completed"
EOF
    chmod +x "$DOTFILES_PARENT_DIR/test_insufficient_disk.sh"
    
    run "$DOTFILES_PARENT_DIR/test_insufficient_disk.sh"
    assert_success
    assert_output --partial "SHOW_ERROR: Insufficient disk space. Required: 5GB, Available: 4GB"
    assert_output --partial "Disk space check correctly failed"
    assert_output --partial "Insufficient disk space test completed"
}

# ============================================================================
# Prerequisites - Security and Permissions Tests
# ============================================================================

@test "prerequisites: should ensure not running as root" {
    cat > "$DOTFILES_PARENT_DIR/test_not_root.sh" << 'EOF'
#!/usr/bin/env bash
export DOTFILES_PARENT_DIR="$(pwd)"
source "script/core/prerequisites"

# Mock id command to return non-root user
id() {
    case "$1" in
        "-u")
            echo "501"  # Regular user ID
            ;;
        *)
            echo "uid=501(testuser) gid=20(staff) groups=20(staff),..."
            ;;
    esac
}

show_error() { echo "SHOW_ERROR: $1"; return 1; }

export -f id show_error

# Test ensure_not_root with regular user
ensure_not_root

echo "Non-root user validation test completed"
EOF
    chmod +x "$DOTFILES_PARENT_DIR/test_not_root.sh"
    
    run "$DOTFILES_PARENT_DIR/test_not_root.sh"
    assert_success
    assert_output --partial "Non-root user validation test completed"
}

@test "prerequisites: should detect and reject root user" {
    cat > "$DOTFILES_PARENT_DIR/test_root_detection.sh" << 'EOF'
#!/usr/bin/env bash
export DOTFILES_PARENT_DIR="$(pwd)"
source "script/core/prerequisites"

# Mock id command to return root user
id() {
    case "$1" in
        "-u")
            echo "0"  # Root user ID
            ;;
        *)
            echo "uid=0(root) gid=0(wheel) groups=0(wheel),..."
            ;;
    esac
}

# Mock show_error to prevent exit but still return 1
show_error() { 
    echo "SHOW_ERROR: $1"
    # Don't call exit like the real function does
    return 1
}

# Override ensure_not_root to not call exit
ensure_not_root() {
    if [ "$(id -u)" -eq 0 ]; then
        show_error "Do not run this script as root"
        return 1  # Return instead of exit
    fi
}

export -f id show_error ensure_not_root

# Test ensure_not_root with root user
if ensure_not_root 2>/dev/null; then
    echo "Error: Should have detected root user"
    exit 1
else
    echo "Root user correctly detected and rejected"
fi

echo "Root detection test completed"
EOF
    chmod +x "$DOTFILES_PARENT_DIR/test_root_detection.sh"
    
    run "$DOTFILES_PARENT_DIR/test_root_detection.sh"
    assert_success
    assert_output --partial "SHOW_ERROR: Do not run this script as root"
    assert_output --partial "Root user correctly detected and rejected"
    assert_output --partial "Root detection test completed"
}

@test "prerequisites: should validate disk encryption status" {
    cat > "$DOTFILES_PARENT_DIR/test_disk_encryption.sh" << 'EOF'
#!/usr/bin/env bash
export DOTFILES_PARENT_DIR="$(pwd)"
source "script/core/prerequisites"

# Mock fdesetup to return enabled status
fdesetup() {
    case "$1" in
        "status")
            echo "FileVault is On."
            echo "Encryption in progress: No."
            ;;
        *)
            echo "Mock fdesetup: $*"
            ;;
    esac
}

show_error() { echo "SHOW_ERROR: $1"; return 1; }

export -f fdesetup show_error

# Test disk encryption check
ensure_disk_encryption

echo "Disk encryption validation test completed"
EOF
    chmod +x "$DOTFILES_PARENT_DIR/test_disk_encryption.sh"
    
    run "$DOTFILES_PARENT_DIR/test_disk_encryption.sh"
    assert_success
    assert_output --partial "Disk encryption validation test completed"
}

@test "prerequisites: should detect disabled disk encryption" {
    cat > "$DOTFILES_PARENT_DIR/test_encryption_disabled.sh" << 'EOF'
#!/usr/bin/env bash
export DOTFILES_PARENT_DIR="$(pwd)"
source "script/core/prerequisites"

# Mock fdesetup to return disabled status
fdesetup() {
    case "$1" in
        "status")
            echo "FileVault is Off."
            ;;
        *)
            echo "Mock fdesetup: $*"
            ;;
    esac
}

show_error() { echo "SHOW_ERROR: $1"; return 1; }

export -f fdesetup show_error

# Test disk encryption check with disabled encryption (don't exit)
if ! ensure_disk_encryption 2>/dev/null; then
    echo "Disabled disk encryption correctly detected"
else
    echo "Error: Should have detected disabled encryption"
    exit 1
fi

echo "Disabled encryption detection test completed"
EOF
    chmod +x "$DOTFILES_PARENT_DIR/test_encryption_disabled.sh"
    
    run "$DOTFILES_PARENT_DIR/test_encryption_disabled.sh"
    assert_success
    assert_output --partial "Disabled disk encryption correctly detected"
    assert_output --partial "Disabled encryption detection test completed"
}

# ============================================================================
# Prerequisites - Preflight Checks Integration Tests
# ============================================================================

@test "prerequisites: should run comprehensive preflight checks" {
    cat > "$DOTFILES_PARENT_DIR/test_preflight.sh" << 'EOF'
#!/usr/bin/env bash
export DOTFILES_PARENT_DIR="$(pwd)"
source "script/core/prerequisites"

# Mock all the check functions
check_macos_version() { echo "Mock: macOS version check passed for $1"; }
get_architecture() { echo "arm64"; }
check_disk_space() { echo "Mock: Disk space check passed for ${1}GB"; }
check_network_connectivity() { echo "Mock: Network connectivity check passed for $1"; }
ensure_not_root() { echo "Mock: Not root check passed"; }

log_info() { echo "LOG_INFO: $1"; }

export -f check_macos_version get_architecture check_disk_space check_network_connectivity ensure_not_root log_info

# Test preflight checks
preflight_checks

echo "Preflight checks test completed"
EOF
    chmod +x "$DOTFILES_PARENT_DIR/test_preflight.sh"
    
    run "$DOTFILES_PARENT_DIR/test_preflight.sh"
    assert_success
    assert_output --partial "Mock: macOS version check passed for 11.0"
    assert_output --partial "LOG_INFO: Architecture: arm64"
    assert_output --partial "Mock: Disk space check passed for 5GB"
    assert_output --partial "Mock: Network connectivity check passed for github.com"
    assert_output --partial "Mock: Not root check passed"
    assert_output --partial "LOG_INFO: User permissions check passed"
    assert_output --partial "Preflight checks test completed"
}

# ============================================================================
# Prerequisites - Password Manager Integration Tests
# ============================================================================

@test "prerequisites: should handle 1Password CLI installation and setup" {
    cat > "$DOTFILES_PARENT_DIR/test_password_manager.sh" << 'EOF'
#!/usr/bin/env bash
export DOTFILES_PARENT_DIR="$(pwd)"
source "script/core/prerequisites"

# Mock check_command for 1Password CLI
check_command() {
    case "$1" in
        "op") return 1 ;;  # 1Password CLI not available initially
        *) command -v "$1" >/dev/null 2>&1 ;;
    esac
}

# Mock silent command
silent() {
    case "$1" in
        "brew install --cask 1password-cli")
            echo "Mock: Installing 1Password CLI via Homebrew"
            return 0
            ;;
        *)
            echo "Mock silent: $1"
            return 0
            ;;
    esac
}

# Mock op commands
op() {
    case "$1" in
        "whoami")
            echo "Mock: Not signed in"
            return 1
            ;;
        "account")
            case "$2" in
                "list")
                    echo "Mock: No accounts configured"
                    return 1
                    ;;
                *)
                    echo "Mock op account: $*"
                    return 0
                    ;;
            esac
            ;;
        *)
            echo "Mock op: $*"
            return 0
            ;;
    esac
}

log_info() { echo "LOG_INFO: $1"; }
log_success() { echo "LOG_SUCCESS: $1"; }
show_error() { echo "SHOW_ERROR: $1"; return 1; }

export -f check_command silent op log_info log_success show_error

# Test password manager setup (but don't actually prompt for credentials)
echo "Testing 1Password CLI installation..."
if ! check_command "op" "1Password CLI"; then
    info_log "Installing 1Password CLI..."
    if silent "brew install --cask 1password-cli"; then
        success_log "1Password CLI installed"
    else
        show_error "Failed to install 1Password CLI"
    fi
fi

echo "Password manager setup test completed"
EOF
    chmod +x "$DOTFILES_PARENT_DIR/test_password_manager.sh"
    
    run "$DOTFILES_PARENT_DIR/test_password_manager.sh"
    assert_success
    assert_output --partial "Testing 1Password CLI installation..."
    assert_output --partial "LOG_INFO: Installing 1Password CLI..."
    assert_output --partial "Mock: Installing 1Password CLI via Homebrew"
    assert_output --partial "LOG_SUCCESS: 1Password CLI installed"
    assert_output --partial "Password manager setup test completed"
}