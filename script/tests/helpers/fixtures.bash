#!/usr/bin/env bash

# Test Fixtures for Dotfiles Testing
# Provides realistic test data and utilities for testing our business logic

# Create realistic brewfile fixtures
create_brewfile_fixture() {
    local fixture_type="${1:-minimal}"
    local target_file="${2:-$DOTFILES_PARENT_DIR/dependencies/dependencies.brewfile}"

    mkdir -p "$(dirname "$target_file")"

    case "$fixture_type" in
        "minimal")
            cat > "$target_file" << 'EOF'
brew "git"
brew "curl"
brew "wget"
EOF
            ;;
        "complex")
            cat > "$target_file" << 'EOF'
tap "homebrew/bundle"

# Core utilities
brew "git"
brew "curl"
brew "wget"
brew "jq"
brew "yq"

# Development tools  
brew "node"
brew "python@3.11"
brew "rustup"
EOF
            ;;
        "missing-deps")
            cat > "$target_file" << 'EOF'
brew "git"
brew "nonexistent-package"
brew "another-missing-tool"
EOF
            ;;
    esac
}

# Create realistic applications brewfile
create_applications_fixture() {
    local fixture_type="${1:-minimal}"
    local target_file="${2:-$DOTFILES_PARENT_DIR/dependencies/applications.brewfile}"

    mkdir -p "$(dirname "$target_file")"

    case "$fixture_type" in
        "minimal")
            cat > "$target_file" << 'EOF'
cask "visual-studio-code"
cask "firefox"
mas "Xcode", id: 497799835
EOF
            ;;
        "complex")
            cat > "$target_file" << 'EOF'
tap "homebrew/bundle"

# Development apps
cask "visual-studio-code"
cask "docker"
cask "postman"

# Browsers
cask "firefox"
cask "brave-browser"

# App Store apps
mas "Xcode", id: 497799835
mas "Keynote", id: 409183694
EOF
            ;;
    esac
}

# Create package list fixtures (what's "installed")
create_installed_packages_fixture() {
    local type="$1"

    case "$type" in
        "brew-formula")
            echo -e "git\ncurl\nwget\njq\nnode"
            ;;
        "brew-cask")
            echo -e "visual-studio-code\nfirefox\ndocker"
            ;;
        "npm-global")
            echo -e "fast-cli\n@commitlint/cli\naicommits2"
            ;;
        "cargo")
            echo -e "basalt-tui\nbandwhich\ncsvlens"
            ;;
        "mas")
            echo "497799835 Xcode (14.3.1)"
            echo "409183694 Keynote (12.2.1)"
            ;;
    esac
}

# Mock package managers with realistic responses
mock_package_managers() {
    # Mock brew with controlled responses
    cat > "$MOCK_BREW_PREFIX/bin/brew" << 'EOF'
#!/bin/bash
case "$1" in
    "list")
        if [[ "$2" == "--formula" ]]; then
            create_installed_packages_fixture "brew-formula"
        elif [[ "$2" == "--cask" ]]; then
            create_installed_packages_fixture "brew-cask"
        fi
        ;;
    "bundle")
        if [[ "$2" == "check" ]]; then
            echo "The Brewfile's dependencies are satisfied."
        fi
        ;;
    "--version")
        echo "Homebrew 4.0.0"
        ;;
esac
EOF
    chmod +x "$MOCK_BREW_PREFIX/bin/brew"

    # Mock npm with controlled responses
    cat > "$MOCK_BREW_PREFIX/bin/npm" << 'EOF'
#!/bin/bash
case "$1" in
    "list")
        if [[ "$2" == "-g" ]]; then
            create_installed_packages_fixture "npm-global"
        fi
        ;;
esac
EOF
    chmod +x "$MOCK_BREW_PREFIX/bin/npm"

    # Mock cargo with controlled responses
    cat > "$MOCK_BREW_PREFIX/bin/cargo" << 'EOF'
#!/bin/bash
case "$1" in
    "install")
        if [[ "$2" == "--list" ]]; then
            create_installed_packages_fixture "cargo"
        fi
        ;;
esac
EOF
    chmod +x "$MOCK_BREW_PREFIX/bin/cargo"

    # Mock mas with controlled responses
    cat > "$MOCK_BREW_PREFIX/bin/mas" << 'EOF'
#!/bin/bash
case "$1" in
    "list")
        create_installed_packages_fixture "mas"
        ;;
esac
EOF
    chmod +x "$MOCK_BREW_PREFIX/bin/mas"
}

# Test our configuration processing logic
test_config_processing() {
    local config_content="$1"
    local expected_result="$2"

    # Test that our processing logic works correctly
    # This tests OUR code, not the config format itself
    local actual_result
    actual_result=$(echo "$config_content" | our_config_parser)

    if [ -n "$expected_result" ]; then
        [ "$actual_result" = "$expected_result" ]
    else
        echo "$actual_result"
    fi
}

# Validate test focuses on our business logic
assert_tests_our_logic() {
    local test_name="$1"

    # Helper to ensure tests focus on our interfaces/behaviors
    # Not on third-party tool functionality
    if [[ "$test_name" =~ (brew|npm|cargo|git).*version ]]; then
        echo "WARNING: Test '$test_name' may be testing third-party tool behavior"
        return 1
    fi

    if [[ "$test_name" =~ should.*work|should.*exist ]]; then
        echo "WARNING: Test '$test_name' may be testing obvious functionality"
        return 1
    fi

    return 0
}

# Alias for backward compatibility with test files that use create_sample_brewfile
create_sample_brewfile() {
    local target_file="$1"
    local type="${2:-dependencies}"

    mkdir -p "$(dirname "$target_file")"

    case "$type" in
        "dependencies")
            # Create a brewfile with both formulae and casks for comprehensive testing
            cat > "$target_file" << 'EOF'
# Core utilities
brew "git"
brew "curl"
brew "wget"
brew "node"

# Development tools as casks
cask "visual-studio-code"
cask "docker"
EOF
            ;;
        "applications")
            create_applications_fixture "complex" "$target_file"
            ;;
        *)
            create_brewfile_fixture "minimal" "$target_file"
            ;;
    esac
}
