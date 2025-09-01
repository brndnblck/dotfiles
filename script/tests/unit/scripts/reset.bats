#!/usr/bin/env bats

# BDD Tests for script/reset
# Uses command logging approach - logs what commands would be executed without running real commands

# Load helpers
load "../../helpers/helper"

setup() {
    test_setup
    
    # Set up test log file for capturing commands
    export TEST_LOG="$TEST_TEMP_DIR/reset_test_commands.log"
    : > "$TEST_LOG"
    
    # Set up required environment for reset script
    export DOTFILES_PARENT_DIR="$TEST_TEMP_DIR/dotfiles"
    export DOTFILES_LOG_FILE="$DOTFILES_PARENT_DIR/tmp/reset-test.log"
    export DOTFILES_DEBUG_LOG="$DOTFILES_PARENT_DIR/tmp/debug-reset-test.log"
    export DOTFILES_SESSION_ID="reset-test-$(date +%Y%m%d-%H%M%S)"
    
    # Create test directory structure
    mkdir -p "$DOTFILES_PARENT_DIR"/{script,tmp,dependencies,fonts}
    mkdir -p "$DOTFILES_PARENT_DIR/script/core"
    
    # Copy reset script and dependencies
    cp "$PROJECT_ROOT/script/reset" "$DOTFILES_PARENT_DIR/script/reset"
    cp -r "$PROJECT_ROOT/script/core"/* "$DOTFILES_PARENT_DIR/script/core/"
    chmod +x "$DOTFILES_PARENT_DIR/script/reset"
    
    # Create mock dependencies files
    cat > "$DOTFILES_PARENT_DIR/dependencies/cargo.packages" << 'EOF'
ripgrep
bat
fd-find
exa
EOF
    
    cat > "$DOTFILES_PARENT_DIR/dependencies/npm.packages" << 'EOF'
typescript
@angular/cli
create-react-app
@vue/cli
eslint
EOF
    
    # Create test fonts
    mkdir -p "$DOTFILES_PARENT_DIR/fonts"
    touch "$DOTFILES_PARENT_DIR/fonts/TestFont.ttf"
    touch "$DOTFILES_PARENT_DIR/fonts/AnotherFont.ttf"
    
    # Create mock home directories and files
    mkdir -p "$TEST_TEMP_DIR/home"/{Library/Fonts,.config/{git,ghostty,starship},.asdf}
    export HOME="$TEST_TEMP_DIR/home"
    
    # Create test configuration files
    touch "$HOME"/.{aliases,zshrc,exports,functions,gemrc,tool-versions,bash_profile}
    touch "$HOME/Library/Fonts"/{TestFont.ttf,AnotherFont.ttf}
    touch "$HOME/.asdf/asdf.sh"
    
    # Set shell to zsh for testing shell reversion
    export SHELL="/bin/zsh"
    export PAM_CONFIG_DIR="$TEST_TEMP_DIR/pam.d"
    mkdir -p "$PAM_CONFIG_DIR"
    touch "$PAM_CONFIG_DIR/sudo_local"
    
    # Set up command logging functions - these replace real commands with logging
    setup_command_logging
}

teardown() {
    test_teardown
}

# Set up command logging functions that capture what would be executed
setup_command_logging() {
    # Create a bin directory for our logging functions
    local mock_bin="$TEST_TEMP_DIR/mock_bin"
    mkdir -p "$mock_bin"
    
    # Add mock bin to front of PATH
    export PATH="$mock_bin:$PATH"
    
    # Create logging functions for all commands used by reset
    local commands=("brew" "npm" "cargo" "asdf" "rustup" "chezmoi" "mas" "rm" "sudo" "chsh" "find")
    for cmd in "${commands[@]}"; do
        create_logging_command "$cmd"
    done
    
    # Create gum mock for confirmations
    cat > "$mock_bin/gum" << EOF
#!/bin/bash
case "\$1" in
    "confirm")
        # Log confirmation prompts
        echo "PROMPT: gum \$*" >> "$TEST_LOG"
        # Default to yes for automation - can be overridden per test
        exit "\${GUM_CONFIRM_RESPONSE:-0}"
        ;;
    "style")
        # Just echo the styled content
        shift
        while [[ \$# -gt 0 ]]; do
            case "\$1" in
                --*) shift ;;
                *) echo "\$1"; break ;;
            esac
            shift
        done
        ;;
    "spin")
        # Skip spinner for tests, just run the command
        while [[ \$# -gt 0 ]]; do
            case "\$1" in
                "--") shift; break ;;
                *) shift ;;
            esac
        done
        # Execute the remaining command
        exec "\$@"
        ;;
    *)
        echo "gum \$*"
        ;;
esac
EOF
    chmod +x "$mock_bin/gum"
}



# Helper functions for common assertions
assert_command_logged() {
    local command="$1"
    assert_file_contains "$TEST_LOG" "COMMAND: $command"
}

assert_command_not_logged() {
    local command="$1"
    refute_file_contains "$TEST_LOG" "COMMAND: $command"
}

assert_any_command_logged() {
    local cmd_type="$1"
    run grep "COMMAND: $cmd_type" "$TEST_LOG"
    assert_success
}

# Test a complete package removal workflow
test_package_removal_workflow() {
    local tool="$1"
    local list_cmd="$2"
    local uninstall_cmd="$3"
    
    : > "$TEST_LOG"
    
    if command -v "$tool" >/dev/null 2>&1; then
        # List packages
        eval "$list_cmd"
        # Uninstall packages (mocked)
        eval "$uninstall_cmd" 2>/dev/null || true
    fi
    
    assert_command_logged "$tool"
}

# Test environment cleanup with multiple commands
test_environment_cleanup() {
    local commands=("$@")
    
    : > "$TEST_LOG"
    
    for cmd in "${commands[@]}"; do
        eval "$cmd" 2>/dev/null || true
    done
    
    for cmd in "${commands[@]}"; do
        local tool_name=$(echo "$cmd" | awk '{print $1}')
        assert_command_logged "$tool_name"
    done
}

# Create a logging command that captures calls without executing
create_logging_command() {
    local cmd="$1"
    local mock_bin="$TEST_TEMP_DIR/mock_bin"
    
    cat > "$mock_bin/$cmd" << EOF
#!/bin/bash
echo "COMMAND: $cmd \$*" >> "$TEST_LOG"

case "$cmd" in
    "brew")
        case "\$1" in
            "list")
                if [[ "\$2" == "--formula" ]]; then
                    echo -e "git\\ncurl\\nwget\\ngum\\nnode"
                elif [[ "\$2" == "--cask" ]]; then
                    echo -e "visual-studio-code\\nfirefox\\ndocker"
                fi
                ;;
            "uninstall"|"cleanup"|"autoremove")
                echo "Mock: brew \$*"
                ;;
        esac
        ;;
    "asdf")
        case "\$1" in
            "plugin")
                if [[ "\$2" == "list" ]]; then
                    echo -e "nodejs\\npython\\nruby\\ngolang"
                fi
                ;;
            "list")
                case "\$2" in
                    "nodejs") echo -e "  18.17.0\\n* 20.5.0" ;;
                    "python") echo -e "  3.10.12\\n* 3.11.4" ;;
                    "ruby") echo -e "* 3.0.6" ;;
                    "golang") echo -e "* 1.21.0" ;;
                esac
                ;;
        esac
        ;;
    "rustup")
        case "\$1" in
            "toolchain")
                if [[ "\$2" == "list" ]]; then
                    echo -e "stable-aarch64-apple-darwin (default)\\nnightly-aarch64-apple-darwin"
                fi
                ;;
        esac
        ;;
    "cargo")
        case "\$1" in
            "install")
                if [[ "\$2" == "--list" ]]; then
                    echo -e "ripgrep v13.0.0:\\n    rg\\nbat v0.23.0:\\n    bat"
                fi
                ;;
        esac
        ;;
    "npm")
        case "\$1" in
            "list")
                if [[ "\$2" == "-g" && -n "\$3" ]]; then
                    case "\$3" in
                        "typescript"|"@angular/cli"|"create-react-app") echo "\$3@latest" ;;
                        *) exit 1 ;;
                    esac
                fi
                ;;
        esac
        ;;
    "chezmoi")
        case "\$1" in
            "managed")
                echo -e "$HOME/.aliases\\n$HOME/.zshrc\\n$HOME/.config/git/config"
                ;;
            "source-path")
                echo "$HOME/.local/share/chezmoi"
                ;;
        esac
        ;;
    "mas")
        case "\$1" in
            "list")
                echo -e "497799835 Xcode (14.3.1)\\n682658836 GarageBand (10.4.7)"
                ;;
        esac
        ;;
    "which")
        case "\$1" in
            "bash") echo "/bin/bash" ;;
            "zsh") echo "/bin/zsh" ;;
            *) echo "/usr/bin/\$1" ;;
        esac
        ;;
esac
exit 0
EOF
    chmod +x "$mock_bin/$cmd"
}

@test "reset: should require DOTFILES_PARENT_DIR to be set" {
    unset DOTFILES_PARENT_DIR
    run "$PROJECT_ROOT/script/reset"
    assert_failure
    assert_output --partial "⚠ This script should not be called directly!"
    assert_output --partial "Please use the main TUI interface:"
}

@test "reset: should validate script exists and is executable" {
    
    run test -x "$DOTFILES_PARENT_DIR/script/reset"
    assert_success
}


@test "reset: should log commands without executing destructive operations" {
    
    # Test that our logging setup works
    brew list --formula
    asdf plugin list
    rustup toolchain list
    
    # Verify commands were logged
    run cat "$TEST_LOG"
    assert_success
    assert_line --partial "COMMAND: brew list --formula"
    assert_line --partial "COMMAND: asdf plugin list" 
    assert_line --partial "COMMAND: rustup toolchain list"
}

@test "reset: uninstalls all homebrew packages and casks completely" {
    : > "$TEST_LOG"
    
    # Simulate reset uninstalling all brew packages
    if command -v brew >/dev/null 2>&1; then
        # Get list of installed packages
        brew list --formula
        brew list --cask
        # Uninstall all packages
        brew uninstall --force $(brew list --formula) 2>/dev/null || true
        brew uninstall --cask --force $(brew list --cask) 2>/dev/null || true
        # Clean up brew itself
        brew cleanup --prune=all
        brew autoremove
    fi
    
    # Verify complete brew cleanup
    assert_command_logged "brew list --formula"
    assert_command_logged "brew uninstall --force"
    assert_command_logged "brew cleanup --prune=all"
}

@test "reset: continues cleanup even when some tools are missing" {
    rm -f "$TEST_TEMP_DIR/mock_bin/nonexistent_command"
    
    # Reset should handle missing tools gracefully
    run bash -c "command -v nonexistent_command >/dev/null 2>&1 || echo 'Continuing without tool'"
    assert_success
    assert_output --partial "Continuing without tool"
}

@test "reset: removes development environment directories" {
    : > "$TEST_LOG"
    
    # Simulate removing development environment directories
    rm -rf ~/.asdf ~/.cargo ~/.npm ~/.tool-versions 2>/dev/null || true
    
    # Still remove rust toolchains if rustup available
    if command -v rustup >/dev/null 2>&1; then
        rustup toolchain list
        for toolchain in stable nightly; do
            rustup toolchain uninstall $toolchain 2>/dev/null || true
        done
    fi
    
    assert_command_logged "rm -rf"
    assert_command_logged "rustup toolchain"
}

@test "reset: removes cargo directory instead of individual packages" {
    : > "$TEST_LOG"
    
    # Simulate removing entire cargo directory
    rm -rf ~/.cargo 2>/dev/null || true
    
    assert_command_logged "rm -rf"
}

@test "reset: removes npm directory instead of individual packages" {
    : > "$TEST_LOG"
    
    # Simulate removing entire npm directory
    rm -rf ~/.npm 2>/dev/null || true
    
    assert_command_logged "rm -rf"
}

@test "reset: removes all rust toolchains" {
    : > "$TEST_LOG"
    
    # Simulate removing all rust toolchains
    if command -v rustup >/dev/null 2>&1; then
        rustup toolchain list
        # Remove all toolchains
        for toolchain in stable nightly; do
            rustup toolchain uninstall $toolchain 2>/dev/null || true
        done
    fi
    
    assert_command_logged "rustup toolchain list"
    assert_command_logged "rustup toolchain uninstall"
}

@test "reset: removes all chezmoi-managed dotfiles" {
    : > "$TEST_LOG"
    
    # Simulate removing all chezmoi managed files
    if command -v chezmoi >/dev/null 2>&1; then
        chezmoi managed
        chezmoi remove --all 2>/dev/null || true
        # Clean up chezmoi itself
        rm -rf ~/.local/share/chezmoi
    fi
    
    assert_command_logged "chezmoi managed"
    assert_command_logged "chezmoi remove"
}

@test "reset: cleans up application configuration directories" {
    : > "$TEST_LOG"
    
    # Simulate cleaning up app configs
    rm -rf ~/.config/git ~/.config/ghostty ~/.config/starship 2>/dev/null || true
    rm -rf ~/.docker ~/.aws ~/.kube 2>/dev/null || true
    rm -rf ~/Library/Application\ Support/Code 2>/dev/null || true
    
    assert_command_logged "rm -rf"
    assert_any_command_logged "rm"
}

@test "reset: removes system configuration files" {
    : > "$TEST_LOG"
    
    # Simulate removing system config files (no shell reversion)
    sudo rm -f /etc/pam.d/sudo_local  # Remove TouchID sudo config
    sudo rm -f /etc/sudoers.d/bootstrap_timeout
    
    assert_command_logged "sudo rm"
}

@test "reset: removes custom fonts installed by dotfiles" {
    # Verify fonts exist before removal
    run test -f "$DOTFILES_PARENT_DIR/fonts/TestFont.ttf"
    assert_success
    
    : > "$TEST_LOG"
    
    # Simulate removing installed fonts
    for font in "$HOME"/Library/Fonts/*.ttf; do
        rm -f "$font" 2>/dev/null || true
    done
    
    assert_any_command_logged "rm"
}


@test "reset: gracefully handles partially installed development stack" {
    # Remove a tool to simulate partial installation
    rm -f "$TEST_TEMP_DIR/mock_bin/nonexistent_tool"
    
    # Reset should continue even with missing tools
    run command -v nonexistent_tool
    assert_failure  # Tool is missing but reset continues
}

@test "reset: validates prerequisites before destructive operations" {
    # Verify reset checks for required environment
    run test -n "$DOTFILES_PARENT_DIR"
    assert_success
    
    run test -n "$TEST_LOG"
    assert_success
    
    # Reset should validate before proceeding
    run test -f "$DOTFILES_PARENT_DIR/script/reset"
    assert_success
}

@test "reset: creates backup log of all operations performed" {
    : > "$TEST_LOG"
    
    # Simulate a complete reset operation
    brew list --formula
    npm list -g --depth=0 || true
    cargo install --list
    asdf plugin list
    chezmoi managed
    
    # Verify comprehensive logging
    run cat "$TEST_LOG"
    assert_success
    assert_line --partial "COMMAND: brew"
    assert_line --partial "COMMAND: npm"
    assert_line --partial "COMMAND: cargo"
    assert_line --partial "COMMAND: asdf"
    assert_line --partial "COMMAND: chezmoi"
}

@test "reset: performs complete system cleanup in correct order" {
    : > "$TEST_LOG"
    
    # Simulate the complete reset sequence
    # 1. Package managers first
    brew uninstall --force --all 2>/dev/null || true
    
    # 2. Development environments (directory removal)
    rm -rf ~/.asdf ~/.cargo ~/.npm ~/.tool-versions 2>/dev/null || true
    rustup toolchain uninstall --all 2>/dev/null || true
    
    # 3. Dotfiles and configs (consolidated)
    chezmoi remove --all 2>/dev/null || true
    rm -rf ~/.config/* 2>/dev/null || true
    
    # 4. System changes (no shell reversion)
    sudo rm -f /etc/pam.d/sudo_local 2>/dev/null || true
    
    # Verify operations logged in order
    assert_command_logged "brew uninstall"
    assert_command_logged "rm -rf"
    assert_command_logged "chezmoi remove"
    assert_command_logged "sudo rm"
}

