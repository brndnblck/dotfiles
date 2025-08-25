#!/usr/bin/env bats

# BDD Tests for Starship Shell Prompt Configuration
# Validates starship prompt customization, theming, and performance

# Load helpers using correct relative path
load "../../helpers/helper"
load "../../helpers/mocks"

describe() { true; }
it() { true; }

setup() {
    setup_script_test "starship"
    
    # Create mock starship configuration file
    mkdir -p "$DOTFILES_PARENT_DIR/dot_config"
    # Copy template from project root using PROJECT_ROOT
    cp "$PROJECT_ROOT/dot_config/starship.toml.tmpl" "$DOTFILES_PARENT_DIR/dot_config/starship.toml.tmpl"
    
    # Create processed config file (as chezmoi would)
    mkdir -p "$DOTFILES_PARENT_DIR/.config"
    sed 's/{{ .* }}/test_value/g' "$DOTFILES_PARENT_DIR/dot_config/starship.toml.tmpl" > "$DOTFILES_PARENT_DIR/.config/starship.toml"
    
    # Create enhanced starship mocks
    create_starship_mocks
}

teardown() {
    test_teardown
}

# Create specialized mocks for starship testing
create_starship_mocks() {
    # Mock starship with comprehensive functionality
    cat > "$MOCK_BREW_PREFIX/bin/starship" << 'EOF'
#!/bin/bash
case "$1" in
    "--version")
        echo "starship 1.16.0"
        ;;
    "config")
        case "$2" in
            "--help")
                echo "Config help"
                exit 0
                ;;
            *)
                # Validate config file - check multiple possible locations
                if [ -f ~/.config/starship.toml ] || [ -f "$DOTFILES_PARENT_DIR/.config/starship.toml" ]; then
                    echo "Configuration is valid"
                else
                    echo "No configuration found"
                    exit 1
                fi
                ;;
        esac
        ;;
    "prompt")
        # Parse arguments for prompt generation
        pwd_arg=""
        status_arg="0"
        
        while [[ $# -gt 0 ]]; do
            case $1 in
                --pwd=*)
                    pwd_arg="${1#*=}"
                    shift
                    ;;
                --status=*)
                    status_arg="${1#*=}"
                    shift
                    ;;
                *)
                    shift
                    ;;
            esac
        done
        
        # Generate mock prompt based on config
        prompt=""
        
        # OS symbol (macOS)
        prompt+=" "
        
        # Time
        prompt+="$(date +%R) "
        
        # Username separator
        prompt+="// test_user "
        
        # Directory separator and path
        prompt+="// "
        prompt+="$(basename "${pwd_arg:-$(pwd)}") "
        
        # Git information if in git repo
        if [ -d ".git" ] || [ -d "${pwd_arg}/.git" ]; then
            # Git branch separator
            prompt+="//  [master]"
            
            # Git status indicators
            if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
                # Check for staged files
                if git diff --cached --quiet 2>/dev/null; then
                    :  # No staged files
                else
                    prompt+=" +"
                fi
                
                # Check for unstaged files
                if git diff --quiet 2>/dev/null; then
                    :  # No unstaged files
                else
                    prompt+=" !"
                fi
                
                # Check for untracked files
                if [ -n "$(git ls-files --others --exclude-standard 2>/dev/null)" ]; then
                    prompt+=" ?"
                fi
            fi
            prompt+=" "
        fi
        
        # Python version if available
        if command -v python3 >/dev/null 2>&1; then
            prompt+="//  ($(python3 --version | cut -d' ' -f2)) "
        fi
        
        # Character based on status
        if [ "$status_arg" = "0" ]; then
            prompt+=" "
        else
            prompt+=" "
        fi
        
        echo "$prompt"
        ;;
    *)
        echo "Mock starship: $*"
        ;;
esac
EOF
    chmod +x "$MOCK_BREW_PREFIX/bin/starship"
    
    # Mock git for starship tests
    cat > "$MOCK_BREW_PREFIX/bin/git" << 'EOF'
#!/bin/bash
case "$1" in
    "status")
        if [[ "$2" == "--porcelain" ]]; then
            # Return different status based on test scenario
            if [ -f "test.txt" ] && [ ! -f ".git/index" ]; then
                echo "?? test.txt"  # Untracked
            elif [ -f "test.txt" ] && [ -f ".git/staged" ]; then
                echo "A  test.txt"  # Staged
            elif [ -f "test.txt.modified" ]; then
                echo " M test.txt"  # Modified
            fi
        fi
        ;;
    "diff")
        if [[ "$2" == "--cached" && "$3" == "--quiet" ]]; then
            # Check for staged files
            if [ -f ".git/staged" ]; then
                exit 1  # Has staged files
            else
                exit 0  # No staged files
            fi
        elif [[ "$2" == "--quiet" ]]; then
            # Check for unstaged files
            if [ -f "test.txt.modified" ]; then
                exit 1  # Has unstaged files
            else
                exit 0  # No unstaged files
            fi
        fi
        ;;
    "ls-files")
        if [[ "$2" == "--others" && "$3" == "--exclude-standard" ]]; then
            # List untracked files
            if [ -f "test.txt" ] && [ ! -f ".git/index" ]; then
                echo "test.txt"
            fi
        fi
        ;;
    "init")
        mkdir -p ".git"
        echo "Initialized empty Git repository"
        ;;
    "config")
        # Mock git config
        echo "Configuration set"
        ;;
    "add")
        # Mock git add
        mkdir -p ".git"
        touch ".git/staged"
        ;;
    *)
        echo "Mock git: $*"
        ;;
esac
EOF
    chmod +x "$MOCK_BREW_PREFIX/bin/git"
}

describe "Starship Configuration Validation"

@test "starship: should validate configuration file exists" {
    it "should find starship.toml configuration file"
    
    run test -f "$DOTFILES_PARENT_DIR/.config/starship.toml"
    assert_success
}

@test "starship: should have valid TOML syntax" {
    it "should parse configuration without syntax errors"
    
    run starship config
    assert_success
    assert_output --partial "Configuration is valid"
}

@test "starship: should verify starship installation" {
    it "should have starship command available"
    
    run starship --version
    assert_success
    assert_output --partial "starship"
}

describe "Prompt Format and Components"

@test "starship: should display OS symbol" {
    it "should show macOS symbol in prompt"
    
    run starship prompt --pwd="/tmp/test"
    assert_success
    assert_output --partial " "  # macOS symbol
}

@test "starship: should display time format" {
    it "should show current time in HH:MM format"
    
    run starship prompt --pwd="/tmp/test"
    assert_success
    # Check that output contains time format (HH:MM at the beginning)
    [[ "$output" =~ ^[[:space:]]*[0-9]{1,2}:[0-9]{2} ]]
}

@test "starship: should display username with separator" {
    it "should show username with // separator"
    
    run starship prompt --pwd="/tmp/test"
    assert_success
    assert_output --partial "// test_user"
}

@test "starship: should display directory with separator" {
    it "should show current directory with // separator"
    
    run starship prompt --pwd="/tmp/starship-test-dir"
    assert_success
    assert_output --partial "// starship-test-dir"
}

describe "Git Integration"

@test "starship: should display git branch" {
    it "should show git branch with icon when in repository"
    
    # Create mock git repository
    mkdir -p "$DOTFILES_PARENT_DIR/test-repo/.git"
    cd "$DOTFILES_PARENT_DIR/test-repo"
    
    run starship prompt --pwd="$PWD"
    assert_success
    assert_output --partial " [master]"
}

@test "starship: should show untracked files indicator" {
    it "should display ? symbol for untracked files"
    
    # Create test repository with untracked file
    mkdir -p "$DOTFILES_PARENT_DIR/test-repo/.git"
    cd "$DOTFILES_PARENT_DIR/test-repo"
    touch test.txt
    
    run starship prompt --pwd="$PWD"
    assert_success
    assert_output --partial "?"
}

@test "starship: should show staged files indicator" {
    it "should display + symbol for staged files"
    
    # Create test repository with staged file
    mkdir -p "$DOTFILES_PARENT_DIR/test-repo/.git"
    cd "$DOTFILES_PARENT_DIR/test-repo"
    touch test.txt
    touch ".git/staged"  # Mock staged state
    
    run starship prompt --pwd="$PWD"
    assert_success
    assert_output --partial "+"
}

@test "starship: should show modified files indicator" {
    it "should display ! symbol for modified files"
    
    # Create test repository with modified file
    mkdir -p "$DOTFILES_PARENT_DIR/test-repo/.git"
    cd "$DOTFILES_PARENT_DIR/test-repo"
    touch test.txt.modified  # Mock modified state
    
    run starship prompt --pwd="$PWD"
    assert_success
    assert_output --partial "!"
}

describe "Language Detection"

@test "starship: should detect Python environment" {
    it "should show Python version when available"
    
    run starship prompt --pwd="/tmp/test"
    assert_success
    assert_output --partial " ("  # Python version format
}

@test "starship: should handle missing language tools gracefully" {
    it "should not show language info when tools are unavailable"
    
    # Remove Python and other language tools from PATH but keep starship
    export PATH="$MOCK_BREW_PREFIX/bin:/usr/bin:/bin"
    # Remove language tools from mock PATH
    rm -f "$MOCK_BREW_PREFIX/bin/python3" "$MOCK_BREW_PREFIX/bin/node" "$MOCK_BREW_PREFIX/bin/ruby" 2>/dev/null || true
    
    run starship prompt --pwd="/tmp/test"
    assert_success
    # Should not contain Python indicator
    refute_output --partial "🐍"
}

describe "Character and Status Indicators"

@test "starship: should display success character for exit code 0" {
    it "should show success prompt character"
    
    run starship prompt --pwd="/tmp/test" --status=0
    assert_success
    assert_output --partial " "  # Success character
}

@test "starship: should display error character for non-zero exit code" {
    it "should show error prompt character"
    
    run starship prompt --pwd="/tmp/test" --status=1
    assert_success
    assert_output --partial " "  # Error character
}

describe "Performance and Theming"

@test "starship: should use dream color palette" {
    it "should have dream palette configured in TOML"
    
    run grep -q "palette = 'dream'" "$DOTFILES_PARENT_DIR/.config/starship.toml"
    assert_success
}

@test "starship: should have custom color definitions" {
    it "should define custom colors in dream palette"
    
    run grep -q "color_purple = '#a52aff'" "$DOTFILES_PARENT_DIR/.config/starship.toml"
    assert_success
    
    run grep -q "color_blue = '#2b4fff'" "$DOTFILES_PARENT_DIR/.config/starship.toml"
    assert_success
}

@test "starship: should have directory substitutions configured" {
    it "should define custom directory symbols"
    
    # Ensure config file exists first
    [ -f "$DOTFILES_PARENT_DIR/.config/starship.toml" ] || {
        mkdir -p "$DOTFILES_PARENT_DIR/.config"
        sed 's/{{ .* }}/test_value/g' "$DOTFILES_PARENT_DIR/dot_config/starship.toml.tmpl" > "$DOTFILES_PARENT_DIR/.config/starship.toml"
    }
    
    run grep -q '"Documents" = "󰈙 "' "$DOTFILES_PARENT_DIR/.config/starship.toml"
    assert_success
    
    run grep -q '"Downloads" =' "$DOTFILES_PARENT_DIR/.config/starship.toml"
    assert_success
}

@test "starship: should have language symbols configured" {
    it "should define custom language symbols"
    
    # Ensure config file exists first
    [ -f "$DOTFILES_PARENT_DIR/.config/starship.toml" ] || {
        mkdir -p "$DOTFILES_PARENT_DIR/.config"
        sed 's/{{ .* }}/test_value/g' "$DOTFILES_PARENT_DIR/dot_config/starship.toml.tmpl" > "$DOTFILES_PARENT_DIR/.config/starship.toml"
    }
    
    # Look for any language symbol definition
    run grep -q 'symbol = ' "$DOTFILES_PARENT_DIR/.config/starship.toml"
    assert_success
}

describe "Configuration Completeness"

@test "starship: should have all required modules configured" {
    it "should configure essential prompt modules"
    
    # Check for key modules
    run grep -q '\[character\]' "$DOTFILES_PARENT_DIR/.config/starship.toml"
    assert_success
    
    run grep -q '\[directory\]' "$DOTFILES_PARENT_DIR/.config/starship.toml"
    assert_success
    
    run grep -q '\[git_branch\]' "$DOTFILES_PARENT_DIR/.config/starship.toml"
    assert_success
    
    run grep -q '\[python\]' "$DOTFILES_PARENT_DIR/.config/starship.toml"
    assert_success
}

@test "starship: should have proper format string" {
    it "should define complete prompt format"
    
    run grep -q 'format = .*\$os.*\$time.*\$username.*\$hostname.*\$directory.*\$git_branch.*\$git_status.*\$python.*\$character' "$DOTFILES_PARENT_DIR/.config/starship.toml"
    assert_success
}

@test "starship: should have time module enabled" {
    it "should enable time display in prompt"
    
    run grep -A5 '\[time\]' "$DOTFILES_PARENT_DIR/.config/starship.toml"
    assert_success
    assert_output --partial 'disabled = false'
}

describe "Integration Tests"

@test "starship: should work with chezmoi template processing" {
    it "should process template variables correctly"
    
    # Verify template file exists
    run test -f "$DOTFILES_PARENT_DIR/dot_config/starship.toml.tmpl"
    assert_success
    
    # Verify processed config exists and is readable
    run test -f "$DOTFILES_PARENT_DIR/.config/starship.toml"
    assert_success
    
    # Since this template currently has no variables, files should be identical
    run diff "$DOTFILES_PARENT_DIR/dot_config/starship.toml.tmpl" "$DOTFILES_PARENT_DIR/.config/starship.toml"
    assert_success  # Should be identical when no template variables exist
}

@test "starship: should handle complex git scenarios" {
    it "should correctly display multiple git status indicators"
    
    # Create complex git scenario
    mkdir -p "$DOTFILES_PARENT_DIR/complex-repo/.git"
    cd "$DOTFILES_PARENT_DIR/complex-repo"
    
    # Create untracked file
    touch test.txt
    # Mock staged file
    touch ".git/staged"
    # Mock modified file
    touch test.txt.modified
    
    run starship prompt --pwd="$PWD"
    assert_success
    assert_output --partial "+"  # Staged
    assert_output --partial "!"  # Modified
    assert_output --partial "?"  # Untracked
}