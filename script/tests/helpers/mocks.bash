#!/usr/bin/env bash

# Advanced mocking utilities for complex interactions
# Extends the base helper.bash with sophisticated mocking capabilities

# Mock state tracking
export MOCK_STATE_DIR="$TEST_TEMP_DIR/mock_state"

# Initialize mock state tracking
init_mock_state() {
    mkdir -p "$MOCK_STATE_DIR"
    echo "0" > "$MOCK_STATE_DIR/call_count"
}

# Record a mock call with context
record_mock_call() {
    local command="$1"
    local args="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Increment call count
    local count_file="$MOCK_STATE_DIR/call_count"
    local current_count
    current_count=$(cat "$count_file" 2> /dev/null || echo "0")
    local new_count=$((current_count + 1))
    echo "$new_count" > "$count_file"

    # Record detailed call information
    echo "$timestamp|$command|$args" >> "$MOCK_STATE_DIR/call_history"
}

# Create sophisticated brew mock with state
create_brew_mock() {
    local brew_path="$MOCK_BREW_PREFIX/bin/brew"

    cat > "$brew_path" << 'EOF'
#!/bin/bash

# Source mock state functions
MOCK_STATE_DIR="MOCK_STATE_PLACEHOLDER"
record_call() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$timestamp|brew|$*" >> "$MOCK_STATE_DIR/call_history"
}

# Record this call
record_call "$@"

case "$1" in
    "--version")
        echo "Homebrew 4.0.0"
        ;;
    "shellenv")
        echo 'export HOMEBREW_PREFIX="HOMEBREW_PREFIX_PLACEHOLDER"'
        echo 'export HOMEBREW_CELLAR="HOMEBREW_PREFIX_PLACEHOLDER/Cellar"'
        echo 'export HOMEBREW_REPOSITORY="HOMEBREW_PREFIX_PLACEHOLDER"'
        echo 'export PATH="HOMEBREW_PREFIX_PLACEHOLDER/bin:HOMEBREW_PREFIX_PLACEHOLDER/sbin:$PATH"'
        ;;
    "install")
        if [[ "$*" =~ "--cask" ]]; then
            echo "==> Downloading cask $3"
            echo "==> Installing cask $3"
        else
            echo "==> Downloading $2"
            echo "==> Installing $2"
        fi
        ;;
    "bundle")
        if [[ "$*" =~ "--file=" ]]; then
            local brewfile=$(echo "$*" | sed 's/.*--file=\([^ ]*\).*/\1/' | tr -d '"')
            echo "==> Installing packages from $brewfile"
            echo "==> All packages installed successfully"
        else
            echo "==> Installing packages from Brewfile"
        fi
        ;;
    "update")
        echo "==> Updating Homebrew..."
        echo "Already up-to-date."
        ;;
    "upgrade")
        if [[ "$*" =~ "--cask" ]]; then
            echo "==> Upgrading casks"
            echo "==> All casks up-to-date"
        else
            echo "==> Upgrading packages"
            echo "==> All packages up-to-date"
        fi
        ;;
    *)
        echo "Mock brew executed with: $*"
        ;;
esac

exit 0
EOF

    # Replace placeholders
    sed -i '' "s|MOCK_STATE_PLACEHOLDER|$MOCK_STATE_DIR|g" "$brew_path"
    sed -i '' "s|HOMEBREW_PREFIX_PLACEHOLDER|$MOCK_BREW_PREFIX|g" "$brew_path"
    chmod +x "$brew_path"
}

# Create gum mock with TUI simulation
create_gum_mock() {
    local gum_path="$MOCK_BREW_PREFIX/bin/gum"

    cat > "$gum_path" << 'EOF'
#!/bin/bash

# Mock gum TUI tool
case "$1" in
    "choose")
        # Return first option for automated testing
        shift
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --*) shift ;;
                *)
                    echo "$1"
                    exit 0
                    ;;
            esac
            shift
        done
        ;;
    "confirm")
        # Default to yes for automated testing
        exit 0
        ;;
    "style")
        # Just echo the content without styling
        shift
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --*) shift ;;
                *)
                    echo "$1"
                    break
                    ;;
            esac
            shift
        done
        ;;
    *)
        echo "Mock gum: $*"
        ;;
esac

exit 0
EOF
    chmod +x "$gum_path"
}

# Create mas mock with App Store simulation
create_mas_mock() {
    local mas_path="$MOCK_BREW_PREFIX/bin/mas"

    cat > "$mas_path" << 'EOF'
#!/bin/bash

case "$1" in
    "account")
        # Simulate authenticated state
        echo "user@example.com"
        ;;
    "signin")
        echo "Signed in as $2"
        ;;
    "upgrade")
        echo "==> Checking for app updates"
        echo "Everything is up-to-date"
        ;;
    "list")
        echo "12345 TestApp (1.0)"
        echo "67890 AnotherApp (2.0)"
        ;;
    *)
        echo "Mock mas: $*"
        ;;
esac

exit 0
EOF
    chmod +x "$mas_path"
}

# Create 1Password CLI mock
create_op_mock() {
    local op_path="$MOCK_BREW_PREFIX/bin/op"

    cat > "$op_path" << 'EOF'
#!/bin/bash

case "$1" in
    "whoami")
        echo "user@example.com"
        ;;
    "account")
        case "$2" in
            "list")
                echo "my.1password.com user@example.com"
                ;;
            "add")
                echo "Account added successfully"
                ;;
        esac
        ;;
    "signin")
        echo "Signed in successfully"
        ;;
    *)
        echo "Mock op: $*"
        ;;
esac

exit 0
EOF
    chmod +x "$op_path"
}

# Create chezmoi mock
create_chezmoi_mock() {
    local chezmoi_path="$MOCK_BREW_PREFIX/bin/chezmoi"

    cat > "$chezmoi_path" << 'EOF'
#!/bin/bash

case "$1" in
    "update")
        echo "==> Updating dotfiles"
        echo "Nothing to update"
        ;;
    "execute-template")
        # Just pass through stdin to stdout for template processing
        cat
        ;;
    "apply")
        echo "==> Applying changes"
        echo "Nothing to apply"
        ;;
    *)
        echo "Mock chezmoi: $*"
        ;;
esac

exit 0
EOF
    chmod +x "$chezmoi_path"
}

# Create sudo mock with authentication simulation
create_sudo_mock() {
    local sudo_path="$MOCK_BREW_PREFIX/bin/sudo"

    cat > "$sudo_path" << 'EOF'
#!/bin/bash

# Track sudo state
SUDO_STATE_FILE="MOCK_STATE_PLACEHOLDER/sudo_state"

case "$1" in
    "-n")
        # Non-interactive mode
        if [[ "$2" == "true" ]]; then
            # Check if we have cached credentials
            if [ -f "$SUDO_STATE_FILE" ]; then
                exit 0
            else
                exit 1
            fi
        fi
        shift
        # Execute the command without prompting
        "$@"
        ;;
    "-S")
        # Read password from stdin and cache authentication
        echo "authenticated" > "$SUDO_STATE_FILE"
        shift
        if [[ "$1" == "-v" ]]; then
            # Validate credentials
            exit 0
        fi
        shift
        # Execute the command
        "$@"
        ;;
    "-v")
        # Validate credentials
        if [ -f "$SUDO_STATE_FILE" ]; then
            exit 0
        else
            exit 1
        fi
        ;;
    *)
        # Regular sudo execution
        echo "authenticated" > "$SUDO_STATE_FILE"
        "$@"
        ;;
esac

exit 0
EOF

    sed -i '' "s|MOCK_STATE_PLACEHOLDER|$MOCK_STATE_DIR|g" "$sudo_path"
    chmod +x "$sudo_path"
}

# Setup all sophisticated mocks
setup_advanced_mocks() {
    init_mock_state
    create_brew_mock
    create_gum_mock
    create_mas_mock
    create_op_mock
    create_chezmoi_mock
    create_sudo_mock
}

# Verify specific brew command was called
assert_brew_called_with() {
    local expected_command="$1"
    local call_history="$MOCK_STATE_DIR/call_history"

    if [ ! -f "$call_history" ]; then
        fail "No brew calls recorded"
    fi

    if ! grep -q "brew|.*$expected_command" "$call_history"; then
        echo "Expected: brew $expected_command"
        echo "Actual calls:"
        cat "$call_history" | grep "brew|" || echo "No brew calls found"
        fail "brew was not called with expected command: $expected_command"
    fi
}

# Verify number of calls to a command
assert_call_count() {
    local command="$1"
    local expected_count="$2"
    local call_history="$MOCK_STATE_DIR/call_history"

    if [ ! -f "$call_history" ]; then
        fail "No calls recorded"
    fi

    local actual_count
    actual_count=$(grep -c "$command|" "$call_history" 2> /dev/null || echo "0")

    if [ "$actual_count" -ne "$expected_count" ]; then
        fail "Expected $expected_count calls to $command, but got $actual_count"
    fi
}

# Create a file that will trigger specific behavior
create_trigger_file() {
    local trigger_type="$1"
    # Second parameter is reserved for future use
    # local value="${2:-}"

    case "$trigger_type" in
        "sudo_authenticated")
            touch "/tmp/.bootstrap_sudo_authenticated"
            ;;
        "no_disk_encryption")
            # Override fdesetup mock to return "off"
            create_mock_script "fdesetup" 0 "FileVault is Off."
            ;;
        "insufficient_disk_space")
            # Override df mock to return low space
            create_mock_script "df" 0 "Filesystem     Size   Used  Avail Capacity  iused   ifree %iused  Mounted on\n/dev/disk3s1s1  494Gi   490Gi    1Gi    99%  488318 1048088   32%   /"
            ;;
        "old_macos_version")
            # Override sw_vers to return old version with proper argument handling
            cat > "$MOCK_BREW_PREFIX/bin/sw_vers" << 'EOF'
#!/bin/bash
case "$1" in
    "-productVersion")
        echo "10.14"
        ;;
    *)
        echo "ProductName:	macOS"
        echo "ProductVersion:	10.14"
        echo "BuildVersion:	18A391"
        ;;
esac
EOF
            chmod +x "$MOCK_BREW_PREFIX/bin/sw_vers"
            ;;
    esac
}

# =============================================================================
# MOCK FACTORIES - Eliminate duplicate mock creation across test files
# =============================================================================

# System information mocks (used in status, bootstrap, update tests)
create_system_mocks() {
    local os_version="${1:-15.0}"
    local architecture="${2:-arm64}"
    local hostname="${3:-test-macbook-pro.local}"

    # Enhanced sw_vers mock
    cat > "$MOCK_BREW_PREFIX/bin/sw_vers" << EOF
#!/bin/bash
case "\$1" in
    "-productVersion")
        echo "$os_version"
        ;;
    *)
        echo "ProductName:	macOS"
        echo "ProductVersion:	$os_version"  
        echo "BuildVersion:	24A335"
        ;;
esac
EOF
    chmod +x "$MOCK_BREW_PREFIX/bin/sw_vers"

    create_mock_script "uname" 0 "$architecture"
    create_mock_script "hostname" 0 "$hostname"
}

# Development tools mock factory
create_dev_tools_mocks() {
    local git_version="${1:-2.42.0}"
    local node_version="${2:-v20.5.0}"
    local python_version="${3:-3.11.4}"

    # Git with status support
    cat > "$MOCK_BREW_PREFIX/bin/git" << EOF
#!/bin/bash
case "\$1" in
    "--version")
        echo "git version $git_version"
        ;;
    "status")
        if [[ "\$2" == "--porcelain" ]]; then
            echo ""  # Clean status
        fi
        ;;
    *)
        echo "Mock git: \$*"
        ;;
esac
EOF
    chmod +x "$MOCK_BREW_PREFIX/bin/git"

    create_mock_script "node" 0 "$node_version" "--version"
    create_mock_script "python3" 0 "Python $python_version" "--version"
    create_mock_script "rustc" 0 "rustc 1.71.0 (8ede3aae2 2023-07-12)" "--version"
    create_mock_script "go" 0 "go version go1.20.5 darwin/arm64" "version"
    create_mock_script "docker" 0 "Docker version 24.0.5, build ced0996" "--version"
}

# Package-aware brew mock factory
create_package_aware_brew() {
    local formulae="${1:-git curl wget node python@3.11}"
    local casks="${2:-visual-studio-code firefox docker}"
    local outdated_formulae="${3:-curl wget}"
    local outdated_casks="${4:-firefox}"

    cat > "$MOCK_BREW_PREFIX/bin/brew" << EOF
#!/bin/bash
case "\$1" in
    "--version")
        echo "Homebrew 4.0.0"
        ;;
    "list")
        if [[ "\$2" == "--formula" ]]; then
            echo -e "${formulae// /\\n}"
        elif [[ "\$2" == "--cask" ]]; then
            echo -e "${casks// /\\n}"
        fi
        ;;
    "outdated")
        if [[ "\$2" == "--formula" && -n "$outdated_formulae" ]]; then
            for pkg in $outdated_formulae; do
                echo "\$pkg (old) < 8.0.0 (new)"
            done
        elif [[ "\$2" == "--cask" && -n "$outdated_casks" ]]; then
            for pkg in $outdated_casks; do
                echo "\$pkg (old) != (new)"
            done
        fi
        ;;
    "bundle")
        echo "==> Installing packages from Brewfile"
        ;;
    *)
        echo "Mock brew: \$*"
        ;;
esac
EOF
    chmod +x "$MOCK_BREW_PREFIX/bin/brew"
}

# Complete status testing mock suite
create_status_test_mocks() {
    create_system_mocks
    create_dev_tools_mocks
    create_package_aware_brew

    # Chezmoi mock
    cat > "$MOCK_BREW_PREFIX/bin/chezmoi" << 'EOF'
#!/bin/bash
case "$1" in
    "source-path")
        echo "$DOTFILES_PARENT_DIR"
        ;;
esac
EOF
    chmod +x "$MOCK_BREW_PREFIX/bin/chezmoi"

    create_mock_script "mas" 0 "497799835 Xcode (14.3.1)\n1295203466 Microsoft Remote Desktop (10.7.7)" "list"
}
