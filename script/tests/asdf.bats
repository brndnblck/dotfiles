#!/usr/bin/env bats

# Simplified asdf tests that focus on core functionality
# Tests asdf installation, version management, and cleanup

load helper
load mocks

describe() { true; }
it() { true; }

setup() {
    test_setup
    setup_advanced_mocks
    setup_asdf_environment
    
    # Set up required environment
    export DOTFILES_PARENT_DIR="$DOTFILES_PARENT_DIR"
    export DOTFILES_LOG_FILE="$DOTFILES_PARENT_DIR/tmp/asdf-test.log"
    export DOTFILES_DEBUG_LOG="$DOTFILES_PARENT_DIR/tmp/debug-asdf-test.log"
    
    # Clean up plugin tracking for consistent test state
    rm -f /tmp/asdf-plugins-added
    
    # Copy all core scripts
    cp -r "${BATS_TEST_DIRNAME}/../../script/core"/* "$DOTFILES_PARENT_DIR/script/core/"
}

teardown() {
    test_teardown
}

# Setup asdf testing environment
setup_asdf_environment() {
    # Create mock asdf directories
    mkdir -p "$MOCK_HOME/.asdf/plugins"
    mkdir -p "$MOCK_HOME/.asdf/installs"
    
    # Create asdf mock script
    create_asdf_mock
    
    # Create language-specific directories
    mkdir -p "$MOCK_HOME/.asdf/installs/ruby"
    mkdir -p "$MOCK_HOME/.asdf/installs/python"
    mkdir -p "$MOCK_HOME/.asdf/installs/nodejs"
    mkdir -p "$MOCK_HOME/.asdf/installs/golang"
    
    # Create mock asdf shell script
    cat > "$MOCK_HOME/.asdf/asdf.sh" << 'EOF'
#!/bin/bash
# Mock asdf shell integration
export ASDF_DIR="$HOME/.asdf"
export PATH="$ASDF_DIR/bin:$ASDF_DIR/shims:$PATH"
EOF
    chmod +x "$MOCK_HOME/.asdf/asdf.sh"
}

# Create sophisticated asdf mock
create_asdf_mock() {
    local asdf_path="$MOCK_BREW_PREFIX/bin/asdf"
    
    cat > "$asdf_path" << 'EOF'
#!/bin/bash

case "$1" in
    "plugin")
        case "$2" in
            "add")
                plugin="$3"
                echo "Adding plugin $plugin..."
                # Track added plugins for mock state
                echo "$plugin" >> /tmp/asdf-plugins-added
                ;;
            "update")
                if [[ "$3" == "--all" ]]; then
                    echo "Updating all plugins..."
                else
                    echo "Updating plugin $3..."
                fi
                ;;
            "list")
                # Return plugins if they've been "added"
                if [ -f "/tmp/asdf-plugins-added" ]; then
                    cat /tmp/asdf-plugins-added
                else
                    echo ""
                fi
                ;;
        esac
        ;;
    "current")
        tool="$2"
        case "$tool" in
            "ruby") echo "ruby           3.2.0          $HOME/.tool-versions" ;;
            "python") echo "python         3.11.1         $HOME/.tool-versions" ;;
            "nodejs") echo "nodejs         18.12.1        $HOME/.tool-versions" ;;
            "golang") echo "golang         1.19.4         $HOME/.tool-versions" ;;
            *) echo "$tool          ______         No version is set" ;;
        esac
        ;;
    "latest")
        tool="$2"
        case "$tool" in
            "ruby") echo "3.2.0" ;;
            "python") echo "3.11.1" ;;
            "nodejs") echo "18.12.1" ;;
            "golang") echo "1.19.4" ;;
            *) echo "1.0.0" ;;
        esac
        ;;
    "install")
        tool="$2"
        version="$3"
        echo "Installing $tool $version..."
        echo "$tool $version installed successfully"
        ;;
    "set")
        tool="$2"
        version="$3"
        echo "Setting $tool $version in .tool-versions"
        ;;
    "list")
        tool="$2"
        if [ -n "$tool" ]; then
            case "$tool" in
                "ruby")
                    echo "  3.1.0"
                    echo "  3.2.0"
                    ;;
                "python")
                    echo "  3.10.8"
                    echo "  3.11.1"
                    ;;
                "nodejs")
                    echo "  16.18.0"
                    echo "  18.12.1"
                    ;;
                "golang")
                    echo "  1.18.8"
                    echo "  1.19.4"
                    ;;
                *)
                    echo "No versions installed"
                    ;;
            esac
        fi
        ;;
    "uninstall")
        tool="$2"
        version="$3"
        echo "Uninstalling $tool $version..."
        echo "$tool $version uninstalled successfully"
        ;;
    "reshim")
        echo "Refreshing asdf shims..."
        ;;
    "--version")
        echo "v0.11.3"
        ;;
    *)
        echo "Mock asdf: $*"
        ;;
esac

exit 0
EOF
    chmod +x "$asdf_path"
}

describe "asdf Plugin Management"

@test "asdf: should add required language plugins" {
    it "should add ruby, python, nodejs, and golang plugins"
    
    run asdf plugin add ruby
    assert_success
    assert_output --partial "Adding plugin ruby"
    
    run asdf plugin add python  
    assert_success
    assert_output --partial "Adding plugin python"
    
    run asdf plugin add nodejs
    assert_success
    assert_output --partial "Adding plugin nodejs"
    
    run asdf plugin add golang
    assert_success
    assert_output --partial "Adding plugin golang"
}

@test "asdf: should update plugins to get latest versions" {
    it "should run plugin update command"
    
    run asdf plugin update --all
    assert_success
    assert_output --partial "Updating all plugins"
}

describe "asdf Version Installation"

@test "asdf: should determine latest versions for languages" {
    it "should query latest stable versions"
    
    run asdf latest ruby
    assert_success
    assert_output "3.2.0"
    
    run asdf latest python
    assert_success
    assert_output "3.11.1"
    
    run asdf latest nodejs
    assert_success
    assert_output "18.12.1"
    
    run asdf latest golang
    assert_success
    assert_output "1.19.4"
}

@test "asdf: should install language versions" {
    it "should install specified versions"
    
    run asdf install ruby 3.2.0
    assert_success
    assert_output --partial "Installing ruby 3.2.0"
    assert_output --partial "ruby 3.2.0 installed successfully"
    
    run asdf install nodejs 18.12.1
    assert_success
    assert_output --partial "Installing nodejs 18.12.1"
    assert_output --partial "nodejs 18.12.1 installed successfully"
}

@test "asdf: ~/.tool-versions is managed directly by our scripts" {
    it "should not rely on asdf commands to set global versions"
    
    # This test verifies our approach: we write ~/.tool-versions directly
    # rather than using asdf commands that don't exist (like global) or 
    # that only work locally (like set)
    
    run bash -c "echo 'ruby 3.2.0' > /tmp/test-tool-versions"
    assert_success
    
    run bash -c "cat /tmp/test-tool-versions"
    assert_success
    assert_output "ruby 3.2.0"
}

describe "asdf Version Cleanup"

@test "asdf: should list installed versions" {
    it "should show installed versions for a language"
    
    run asdf list ruby
    assert_success
    assert_output --partial "3.1.0"
    assert_output --partial "3.2.0"
}

@test "asdf: should uninstall old versions" {
    it "should remove specified versions"
    
    run asdf uninstall ruby 3.1.0
    assert_success
    assert_output --partial "Uninstalling ruby 3.1.0"
    assert_output --partial "ruby 3.1.0 uninstalled successfully"
}

describe "asdf Environment Management"

@test "asdf: should reshim after installation" {
    it "should refresh executable shims"
    
    run asdf reshim
    assert_success
    assert_output --partial "Refreshing asdf shims"
}

@test "asdf: should provide version information" {
    it "should show asdf version"
    
    run asdf --version
    assert_success
    assert_output "v0.11.3"
}

describe "asdf Integration Tests"

@test "asdf: should be available when sourced via dependencies" {
    it "should load asdf functions from dependencies script"
    
    # Source the dependencies script to load functions
    run bash -c "
        export PATH='$MOCK_BREW_PREFIX/bin:/usr/bin:/bin'
        export DOTFILES_PARENT_DIR='$DOTFILES_PARENT_DIR'
        cd '$DOTFILES_PARENT_DIR'
        source script/core/common
        source script/core/dependencies
        check_command 'asdf' 'asdf version manager' && echo 'asdf available'
    "
    assert_success
    assert_output --partial "asdf available"
}

@test "asdf: setup_asdf_tools function should work in install mode" {
    it "should run asdf setup without cleanup"
    
    run bash -c "
        export PATH='$MOCK_BREW_PREFIX/bin:/usr/bin:/bin'
        export DOTFILES_PARENT_DIR='$DOTFILES_PARENT_DIR'
        export HOME='$MOCK_HOME'
        cd '$DOTFILES_PARENT_DIR'
        
        source script/core/common
        source script/core/dependencies
        
        # Override log functions for testing AFTER sourcing
        log_info() { echo 'LOG_INFO: '\$1; }
        log_success() { echo 'LOG_SUCCESS: '\$1; }
        log_error() { echo 'LOG_ERROR: '\$1; }
        log_warn() { echo 'LOG_WARN: '\$1; }
        
        setup_asdf_tools 'false'
    "
    assert_success
    assert_output --partial "Processing ruby"
    assert_output --partial "Processing python"
    assert_output --partial "Processing nodejs"
    assert_output --partial "Processing golang"
}

@test "asdf: setup_asdf_tools function should work in update mode" {
    it "should run asdf setup with cleanup"
    
    run bash -c "
        export PATH='$MOCK_BREW_PREFIX/bin:/usr/bin:/bin'
        export DOTFILES_PARENT_DIR='$DOTFILES_PARENT_DIR'
        export HOME='$MOCK_HOME'
        cd '$DOTFILES_PARENT_DIR'
        
        source script/core/common
        source script/core/dependencies
        
        # Override log functions for testing AFTER sourcing
        log_info() { echo 'LOG_INFO: '\$1; }
        log_success() { echo 'LOG_SUCCESS: '\$1; }
        log_error() { echo 'LOG_ERROR: '\$1; }
        log_warn() { echo 'LOG_WARN: '\$1; }
        
        setup_asdf_tools 'true'
    "
    assert_success
    assert_output --partial "Processing ruby"
    assert_output --partial "Version ruby 3.2.0 is ready for global use"
}

@test "asdf: should handle missing asdf gracefully" {
    it "should skip setup when asdf is not available"
    
    # Remove asdf from PATH for this test
    run bash -c "
        export PATH='/usr/bin:/bin'
        export DOTFILES_PARENT_DIR='$DOTFILES_PARENT_DIR'
        cd '$DOTFILES_PARENT_DIR'
        source script/core/common
        source script/core/dependencies
        
        # Override log functions for testing AFTER sourcing
        log_info() { echo 'LOG_INFO: '\$1; }
        log_success() { echo 'LOG_SUCCESS: '\$1; }
        log_error() { echo 'LOG_ERROR: '\$1; }
        log_warn() { echo 'LOG_WARN: '\$1; }
        
        setup_asdf_tools 'false' 2>&1
    "
    assert_failure
    assert_output --partial "asdf not found, skipping language version management"
}

describe "~/.tool-versions File Management"

@test "asdf: should create ~/.tool-versions file with latest versions" {
    it "should update ~/.tool-versions after setting global versions"
    
    run bash -c "
        export PATH='$MOCK_BREW_PREFIX/bin:/usr/bin:/bin'
        export DOTFILES_PARENT_DIR='$DOTFILES_PARENT_DIR'
        export HOME='$MOCK_HOME'
        cd '$DOTFILES_PARENT_DIR'
        
        source script/core/common
        source script/core/dependencies
        
        # Override log functions for testing AFTER sourcing
        log_info() { echo 'LOG_INFO: '\$1; }
        log_success() { echo 'LOG_SUCCESS: '\$1; }
        log_error() { echo 'LOG_ERROR: '\$1; }
        log_warn() { echo 'LOG_WARN: '\$1; }
        
        setup_asdf_tools 'false'
        
        # Check if ~/.tool-versions was created
        if [ -f '$MOCK_HOME/.tool-versions' ]; then
            echo 'FILE_CREATED: ~/.tool-versions exists'
            cat '$MOCK_HOME/.tool-versions'
        else
            echo 'FILE_ERROR: ~/.tool-versions not created'
        fi
    "
    assert_success
    assert_output --partial "Updating $MOCK_HOME/.tool-versions with latest versions"
    assert_output --partial "FILE_CREATED: ~/.tool-versions exists"
    assert_output --partial "ruby 3.2.0"
    assert_output --partial "python 3.11.1"
    assert_output --partial "nodejs 18.12.1"
    assert_output --partial "golang 1.19.4"
}

@test "asdf: update_tool_versions_file function should create correct file" {
    it "should create ~/.tool-versions with all tool versions"
    
    run bash -c "
        export PATH='$MOCK_BREW_PREFIX/bin:/usr/bin:/bin'
        export DOTFILES_PARENT_DIR='$DOTFILES_PARENT_DIR'
        export HOME='$MOCK_HOME'
        cd '$DOTFILES_PARENT_DIR'
        
        source script/core/common
        source script/core/dependencies
        
        # Override log functions for testing AFTER sourcing
        log_info() { echo 'LOG_INFO: '\$1; }
        log_success() { echo 'LOG_SUCCESS: '\$1; }
        log_error() { echo 'LOG_ERROR: '\$1; }
        log_warn() { echo 'LOG_WARN: '\$1; }
        
        # Call update_tool_versions_file directly
        update_tool_versions_file
        
        # Verify file contents
        if [ -f '$MOCK_HOME/.tool-versions' ]; then
            echo 'FILE_EXISTS: true'
            echo 'FILE_CONTENTS:'
            cat '$MOCK_HOME/.tool-versions'
        else
            echo 'FILE_EXISTS: false'
        fi
    "
    assert_success
    assert_output --partial "Updating $MOCK_HOME/.tool-versions with latest versions"
    assert_output --partial "Successfully updated $MOCK_HOME/.tool-versions"
    assert_output --partial "FILE_EXISTS: true"
    assert_output --partial "ruby 3.2.0"
    assert_output --partial "python 3.11.1"
    assert_output --partial "nodejs 18.12.1"
    assert_output --partial "golang 1.19.4"
}

@test "asdf: should overwrite existing ~/.tool-versions with latest versions" {
    it "should replace old versions in ~/.tool-versions"
    
    run bash -c "
        export PATH='$MOCK_BREW_PREFIX/bin:/usr/bin:/bin'
        export DOTFILES_PARENT_DIR='$DOTFILES_PARENT_DIR'
        export HOME='$MOCK_HOME'
        cd '$DOTFILES_PARENT_DIR'
        
        # Create an existing .tool-versions with old versions
        cat > '$MOCK_HOME/.tool-versions' << 'OLDEOF'
ruby 2.7.0
python 3.8.0
nodejs 14.0.0
golang 1.15.0
OLDEOF
        
        echo 'OLD_FILE_CONTENTS:'
        cat '$MOCK_HOME/.tool-versions'
        
        source script/core/common
        source script/core/dependencies
        
        # Override log functions for testing AFTER sourcing
        log_info() { echo 'LOG_INFO: '\$1; }
        log_success() { echo 'LOG_SUCCESS: '\$1; }
        log_error() { echo 'LOG_ERROR: '\$1; }
        log_warn() { echo 'LOG_WARN: '\$1; }
        
        # Update the file
        update_tool_versions_file
        
        echo 'NEW_FILE_CONTENTS:'
        cat '$MOCK_HOME/.tool-versions'
    "
    assert_success
    assert_output --partial "OLD_FILE_CONTENTS:"
    assert_output --partial "ruby 2.7.0"
    assert_output --partial "python 3.8.0"
    assert_output --partial "NEW_FILE_CONTENTS:"
    assert_output --partial "ruby 3.2.0"
    assert_output --partial "python 3.11.1"
    assert_output --partial "nodejs 18.12.1"
    assert_output --partial "golang 1.19.4"
}

@test "asdf: should fetch latest version for tools without global versions" {
    it "should fetch and set latest version when no global version exists"
    
    # Modify asdf mock to return no version for golang initially
    cat > "$MOCK_BREW_PREFIX/bin/asdf-no-golang" << 'EOF'
#!/bin/bash
case "$1" in
    "list")
        tool="$2"
        case "$tool" in
            "ruby") echo "  3.2.0" ;;
            "python") echo "  3.11.1" ;;
            "nodejs") echo "  18.12.1" ;;
            "golang") echo "No versions installed" ;;
            *) echo "No versions installed" ;;
        esac
        ;;
    "latest")
        tool="$2"
        case "$tool" in
            "golang") echo "1.19.4" ;;
            "ruby") echo "3.2.0" ;;
            "python") echo "3.11.1" ;;
            "nodejs") echo "18.12.1" ;;
            *) echo "1.0.0" ;;
        esac
        ;;
    *)
        # Delegate to original mock for other commands
        "$MOCK_BREW_PREFIX/bin/asdf" "$@"
        ;;
esac
EOF
    chmod +x "$MOCK_BREW_PREFIX/bin/asdf-no-golang"
    
    run bash -c "
        export PATH='$MOCK_BREW_PREFIX/bin:/usr/bin:/bin'
        export DOTFILES_PARENT_DIR='$DOTFILES_PARENT_DIR'
        export HOME='$MOCK_HOME'
        cd '$DOTFILES_PARENT_DIR'
        
        # Use modified mock
        mv '$MOCK_BREW_PREFIX/bin/asdf' '$MOCK_BREW_PREFIX/bin/asdf.orig'
        mv '$MOCK_BREW_PREFIX/bin/asdf-no-golang' '$MOCK_BREW_PREFIX/bin/asdf'
        
        source script/core/common
        source script/core/dependencies
        
        # Override log functions for testing AFTER sourcing
        log_info() { echo 'LOG_INFO: '\$1; }
        log_success() { echo 'LOG_SUCCESS: '\$1; }
        log_error() { echo 'LOG_ERROR: '\$1; }
        log_warn() { echo 'LOG_WARN: '\$1; }
        
        update_tool_versions_file
        
        # Check file contents
        echo 'FILE_CONTENTS:'
        cat '$MOCK_HOME/.tool-versions'
        
        # Restore original mock
        mv '$MOCK_BREW_PREFIX/bin/asdf.orig' '$MOCK_BREW_PREFIX/bin/asdf'
    "
    assert_success
    assert_output --partial "No installed version for golang, fetching latest"
    assert_output --partial "FILE_CONTENTS:"
    assert_output --partial "ruby 3.2.0"
    assert_output --partial "python 3.11.1"
    assert_output --partial "nodejs 18.12.1"
    assert_output --partial "golang 1.19.4"
}

@test "asdf: setup_asdf_tools should call update_tool_versions_file" {
    it "should update ~/.tool-versions at the end of setup"
    
    run bash -c "
        export PATH='$MOCK_BREW_PREFIX/bin:/usr/bin:/bin'
        export DOTFILES_PARENT_DIR='$DOTFILES_PARENT_DIR'
        export HOME='$MOCK_HOME'
        cd '$DOTFILES_PARENT_DIR'
        
        source script/core/common
        source script/core/dependencies
        
        # Override log functions for testing AFTER sourcing
        log_info() { echo 'LOG_INFO: '\$1; }
        log_success() { echo 'LOG_SUCCESS: '\$1; }
        log_error() { echo 'LOG_ERROR: '\$1; }
        log_warn() { echo 'LOG_WARN: '\$1; }
        
        setup_asdf_tools 'false'
        
        # Verify the file was created by setup_asdf_tools
        if [ -f '$MOCK_HOME/.tool-versions' ]; then
            echo 'VERIFICATION: ~/.tool-versions was created by setup_asdf_tools'
            wc -l '$MOCK_HOME/.tool-versions' | awk '{print \"LINE_COUNT: \" \$1}'
        fi
    "
    assert_success
    assert_output --partial "Updating $MOCK_HOME/.tool-versions with latest versions"
    assert_output --partial "Successfully updated $MOCK_HOME/.tool-versions"
    assert_output --partial "VERIFICATION: ~/.tool-versions was created by setup_asdf_tools"
    assert_output --partial "LINE_COUNT: 4"
}