#!/usr/bin/env bats

# Test Suite for dot_functions.d/help_core.tmpl
# Tests the centralized help and search system for aliases and functions

# Load helpers
load "../../helpers/helper"
load "../../helpers/test_fixtures"

setup() {
    test_setup
    
    # Create isolated test directories for aliases and functions
    mkdir -p "$TEST_TEMP_DIR/.aliases.d"
    mkdir -p "$TEST_TEMP_DIR/.functions.d"
    
    # Create test fixture alias files (no real aliases, just test data)
    cat > "$TEST_TEMP_DIR/.aliases.d/dev_tools.tmpl" << 'EOF'
# Development Tools Aliases
# Common tools and shortcuts for development work

alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'

# Git shortcuts
alias gs='git status'
alias gp='git push'
alias gl='git pull'
alias gc='git commit -m'

# Docker shortcuts  
alias dps='docker ps'
alias dimg='docker images'
alias dstop='docker stop'
EOF

    cat > "$TEST_TEMP_DIR/.aliases.d/file_ops.tmpl" << 'EOF'
# File Operations Aliases
# Shortcuts for common file operations

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Safety aliases
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
EOF

    # Create test fixture function files (no real functions, just test data)
    cat > "$TEST_TEMP_DIR/.functions.d/dev_workflow.tmpl" << 'EOF'
# Development workflow and git utility functions

git-export() {
    # Description: Clone a git repository without git history (export for templates)
    # Usage: git-export REPO_URL PROJECT_NAME
    # Example: git-export https://github.com/user/template.git my-new-project
    echo "Mock git-export function"
}

git-branch-clean() {
    # Description: Delete merged local branches and prune remote tracking branches
    # Usage: git-branch-clean
    # Example: git-branch-clean
    echo "Mock git-branch-clean function"
}

_private_function() {
    # Description: This is a private function and should not appear in listings
    # Usage: _private_function
    # Example: _private_function
    echo "Private function"
}
EOF

    cat > "$TEST_TEMP_DIR/.functions.d/system.tmpl" << 'EOF'
# System utilities and helper functions

run-repeat() {
    # Description: Execute a command multiple times with optional delay
    # Usage: run-repeat COUNT COMMAND [ARGS...]
    # Example: run-repeat 5 echo "hello world"
    echo "Mock run-repeat function"
}

dig-host() {
    # Description: Perform DNS lookup and reverse DNS lookup for a hostname
    # Usage: dig-host HOSTNAME
    # Example: dig-host google.com
    echo "Mock dig-host function"
}
EOF

    # Copy and modify the actual functions to use our test directory
    cp "$PROJECT_ROOT/dot_functions.d/help_core.tmpl" "$TEST_TEMP_DIR/help_core_functions.sh"
    
    # Override HOME to point to our test directory for isolated testing
    export HOME="$TEST_TEMP_DIR"
}

teardown() {
    test_teardown
}

# =============================================================================
# Helper Function Tests - _render-aliases
# =============================================================================

@test "help_core: _render-aliases should format aliases with consistent spacing" {
    source "$TEST_TEMP_DIR/help_core_functions.sh"
    
    local test_matches="alias gs='git status'
alias gp='git push'
alias gl='git pull'"
    
    run _render-aliases "TEST MODULE" "$test_matches" false
    
    assert_success
    assert_output --partial "=== TEST MODULE ==="
    assert_output --partial "gs"
    assert_output --partial "git status"
    assert_output --partial "gp"
    assert_output --partial "git push"
    assert_output --partial "gl" 
    assert_output --partial "git pull"
}

@test "help_core: _render-aliases should handle comments when requested" {
    source "$TEST_TEMP_DIR/help_core_functions.sh"
    
    local test_matches="# Git shortcuts
alias gs='git status'
alias gp='git push'"
    
    run _render-aliases "TEST MODULE" "$test_matches" true
    
    assert_success
    assert_output --partial "=== TEST MODULE ==="
    assert_output --partial "# Git shortcuts"
    assert_output --partial "gs"
    assert_output --partial "git status"
}

@test "help_core: _render-aliases should truncate long alias commands" {
    source "$TEST_TEMP_DIR/help_core_functions.sh"
    
    local long_command=$(printf 'a%.0s' {1..100})
    local test_matches="alias longtest='$long_command'"
    
    run _render-aliases "TEST MODULE" "$test_matches" false
    
    assert_success
    assert_output --partial "=== TEST MODULE ==="
    assert_output --partial "longtest"
    assert_output --partial "..."
}

@test "help_core: _render-aliases should handle multiline aliases" {
    source "$TEST_TEMP_DIR/help_core_functions.sh"
    
    local test_matches="alias multiline='command1 && \\
command2 && \\
command3'"
    
    run _render-aliases "TEST MODULE" "$test_matches" false
    
    assert_success
    assert_output --partial "=== TEST MODULE ==="
    assert_output --partial "multiline"
}

# =============================================================================
# Helper Function Tests - _render-functions
# =============================================================================

@test "help_core: _render-functions should format function documentation" {
    source "$TEST_TEMP_DIR/help_core_functions.sh"
    
    local test_blocks="FUNCTION:git-export
    # Description: Clone a git repository without git history
    # Usage: git-export REPO_URL PROJECT_NAME
    # Example: git-export https://github.com/user/repo.git my-project

FUNCTION:git-branch-clean
    # Description: Delete merged local branches
    # Usage: git-branch-clean
    # Example: git-branch-clean
"
    
    run _render-functions "DEV WORKFLOW" "$test_blocks"
    
    assert_success
    assert_output --partial "=== DEV WORKFLOW ==="
    assert_output --partial "git-export"
    assert_output --partial "Description: Clone a git repository without git history"
    assert_output --partial "Usage: git-export REPO_URL PROJECT_NAME"
    assert_output --partial "Example: git-export https://github.com/user/repo.git my-project"
    assert_output --partial "git-branch-clean"
    assert_output --partial "Description: Delete merged local branches"
}

@test "help_core: _render-functions should handle empty function blocks" {
    source "$TEST_TEMP_DIR/help_core_functions.sh"
    
    run _render-functions "EMPTY MODULE" ""
    
    assert_success
    refute_output --partial "=== EMPTY MODULE ==="
}

# =============================================================================
# Main Function Tests - alias-help
# =============================================================================

@test "help_core: alias-help should display usage when no arguments provided" {
    source "$TEST_TEMP_DIR/help_core_functions.sh"
    
    run alias-help
    
    assert_failure
    assert_output --partial "Usage: alias-help SEARCH_TERM"
}

@test "help_core: alias-help should search aliases and show context" {
    source "$TEST_TEMP_DIR/help_core_functions.sh"
    
    run alias-help git
    
    assert_success
    assert_output --partial "=== DEV TOOLS ==="
    assert_output --partial "gs"
    assert_output --partial "git status"
    assert_output --partial "gp"
    assert_output --partial "git push"
    assert_output --partial "# Git shortcuts"
}

@test "help_core: alias-help should handle case insensitive search" {
    source "$TEST_TEMP_DIR/help_core_functions.sh"
    
    run alias-help GIT
    
    assert_success
    assert_output --partial "=== DEV TOOLS ==="
    assert_output --partial "gs"
    assert_output --partial "git status"
}

@test "help_core: alias-help should handle searches with no matches" {
    source "$TEST_TEMP_DIR/help_core_functions.sh"
    
    run alias-help nonexistent
    
    assert_success
    # Should complete without errors but produce no output sections
    refute_output --partial "=== "
}

# =============================================================================
# Main Function Tests - alias-search
# =============================================================================

@test "help_core: alias-search should display usage when no arguments provided" {
    source "$TEST_TEMP_DIR/help_core_functions.sh"
    
    run alias-search
    
    assert_failure
    assert_output --partial "Usage: alias-search SEARCH_TERM"
}

@test "help_core: alias-search should find aliases by name" {
    source "$TEST_TEMP_DIR/help_core_functions.sh"
    
    run alias-search gs
    
    assert_success
    assert_output --partial "=== DEV TOOLS ==="
    assert_output --partial "gs"
    assert_output --partial "git status"
}

@test "help_core: alias-search should find aliases by command content" {
    source "$TEST_TEMP_DIR/help_core_functions.sh"
    
    run alias-search "git status"
    
    assert_success
    assert_output --partial "=== DEV TOOLS ==="
    assert_output --partial "gs"
    assert_output --partial "git status"
}

@test "help_core: alias-search should search by module name" {
    source "$TEST_TEMP_DIR/help_core_functions.sh"
    
    run alias-search dev
    
    assert_success
    assert_output --partial "=== DEV TOOLS ==="
    # Should show all aliases from dev-tools module
    assert_output --partial "ll"
    assert_output --partial "ls -la"
    assert_output --partial "gs"
    assert_output --partial "git status"
}

@test "help_core: alias-search should be case insensitive" {
    source "$TEST_TEMP_DIR/help_core_functions.sh"
    
    run alias-search DOCKER
    
    assert_success
    assert_output --partial "=== DEV TOOLS ==="
    assert_output --partial "dps"
    assert_output --partial "docker ps"
}

# =============================================================================
# Main Function Tests - function-help
# =============================================================================

@test "help_core: function-help should display all functions when no search term" {
    source "$TEST_TEMP_DIR/help_core_functions.sh"
    
    run function-help
    
    assert_success
    assert_output --partial "=== DEV WORKFLOW ==="
    assert_output --partial "git-export"
    assert_output --partial "Description: Clone a git repository without git history"
    assert_output --partial "=== SYSTEM ==="
    assert_output --partial "run-repeat"
    assert_output --partial "Description: Execute a command multiple times"
}

@test "help_core: function-help should filter functions by search term" {
    source "$TEST_TEMP_DIR/help_core_functions.sh"
    
    run function-help git
    
    assert_success
    assert_output --partial "=== DEV WORKFLOW ==="
    assert_output --partial "git-export"
    assert_output --partial "git-branch-clean"
    refute_output --partial "run-repeat"
}

@test "help_core: function-help should exclude private functions (starting with _)" {
    source "$TEST_TEMP_DIR/help_core_functions.sh"
    
    run function-help
    
    assert_success
    refute_output --partial "_private_function"
    refute_output --partial "Private function"
}

@test "help_core: function-help should handle case insensitive search" {
    source "$TEST_TEMP_DIR/help_core_functions.sh"
    
    run function-help GIT
    
    assert_success
    assert_output --partial "git-export"
    assert_output --partial "git-branch-clean"
}

@test "help_core: function-help should show complete function documentation" {
    source "$TEST_TEMP_DIR/help_core_functions.sh"
    
    run function-help git-export
    
    assert_success
    assert_output --partial "git-export"
    assert_output --partial "Description: Clone a git repository without git history"
    assert_output --partial "Usage: git-export REPO_URL PROJECT_NAME"
    assert_output --partial "Example: git-export https://github.com/user/template.git my-new-project"
}

# =============================================================================
# Main Function Tests - alias-list
# =============================================================================

@test "help_core: alias-list should show all aliases when no category specified" {
    source "$TEST_TEMP_DIR/help_core_functions.sh"
    
    run alias-list
    
    assert_success
    assert_output --partial "=== DEV TOOLS ==="
    assert_output --partial "ll"
    assert_output --partial "gs"
    assert_output --partial "=== FILE OPS ==="
    assert_output --partial ".."
    assert_output --partial "rm"
}

@test "help_core: alias-list should filter by category" {
    source "$TEST_TEMP_DIR/help_core_functions.sh"
    
    run alias-list dev
    
    assert_success
    assert_output --partial "=== DEV TOOLS ==="
    assert_output --partial "ll"
    assert_output --partial "gs"
    refute_output --partial "=== FILE OPS ==="
}

@test "help_core: alias-list should handle partial category matches" {
    source "$TEST_TEMP_DIR/help_core_functions.sh"
    
    run alias-list file
    
    assert_success
    assert_output --partial "=== FILE OPS ==="
    assert_output --partial ".."
    assert_output --partial "rm"
    refute_output --partial "=== DEV TOOLS ==="
}

# =============================================================================
# Main Function Tests - function-list  
# =============================================================================

@test "help_core: function-list should show all functions when no category specified" {
    source "$TEST_TEMP_DIR/help_core_functions.sh"
    
    run function-list
    
    assert_success
    assert_output --partial "=== DEV WORKFLOW ==="
    assert_output --partial "git-export"
    assert_output --partial "=== SYSTEM ==="
    assert_output --partial "run-repeat"
}

@test "help_core: function-list should filter by category" {
    source "$TEST_TEMP_DIR/help_core_functions.sh"
    
    run function-list dev
    
    assert_success
    assert_output --partial "=== DEV WORKFLOW ==="
    assert_output --partial "git-export"
    refute_output --partial "=== SYSTEM ==="
}

@test "help_core: function-list should exclude private functions from listings" {
    source "$TEST_TEMP_DIR/help_core_functions.sh"
    
    run function-list
    
    assert_success
    refute_output --partial "_private_function"
}

# =============================================================================
# Error Handling and Edge Cases
# =============================================================================

@test "help_core: functions should handle missing aliases directory gracefully" {
    source "$TEST_TEMP_DIR/help_core_functions.sh"
    
    # Remove aliases directory
    rm -rf "$TEST_TEMP_DIR/.aliases.d"
    
    run alias-list
    
    assert_success
    # Should complete without errors but produce no output
}

@test "help_core: functions should handle missing functions directory gracefully" {
    source "$TEST_TEMP_DIR/help_core_functions.sh"
    
    # Remove functions directory
    rm -rf "$TEST_TEMP_DIR/.functions.d"
    
    run function-list
    
    assert_success
    # Should complete without errors but produce no output
}

@test "help_core: functions should handle unreadable files gracefully" {
    source "$TEST_TEMP_DIR/help_core_functions.sh"
    
    # Create an unreadable file
    touch "$TEST_TEMP_DIR/.aliases.d/unreadable.tmpl"
    chmod 000 "$TEST_TEMP_DIR/.aliases.d/unreadable.tmpl"
    
    run alias-list
    
    assert_success
    # Should still show other aliases
    assert_output --partial "=== DEV TOOLS ==="
}

@test "help_core: functions should handle empty alias files" {
    source "$TEST_TEMP_DIR/help_core_functions.sh"
    
    # Create empty alias file
    touch "$TEST_TEMP_DIR/.aliases.d/empty.tmpl"
    
    run alias-list
    
    assert_success
    # Should still show other aliases without errors
    assert_output --partial "=== DEV TOOLS ==="
}

@test "help_core: functions should handle malformed alias syntax" {
    source "$TEST_TEMP_DIR/help_core_functions.sh"
    
    # Create file with malformed aliases
    cat > "$TEST_TEMP_DIR/.aliases.d/malformed.tmpl" << 'EOF'
alias good='ls -la'
malformed line without alias prefix
alias broken=
alias another='echo test'
EOF
    
    run alias-list
    
    assert_success
    # Should show valid aliases and skip malformed ones
    assert_output --partial "good"
    assert_output --partial "another"
}

# =============================================================================
# Integration Tests
# =============================================================================

@test "help_core: alias search and help integration should work together" {
    source "$TEST_TEMP_DIR/help_core_functions.sh"
    
    # First search for git aliases
    run alias-search git
    assert_success
    assert_output --partial "gs"
    
    # Then get help for git aliases
    run alias-help git
    assert_success
    assert_output --partial "# Git shortcuts"
}

@test "help_core: function help should parse complex function documentation" {
    # Create a complex function with edge case documentation
    cat > "$TEST_TEMP_DIR/.functions.d/complex.tmpl" << 'EOF'
complex-function() {
    # Description: A complex function with multiple parameters and edge cases
    # Usage: complex-function [--flag] REQUIRED_ARG [OPTIONAL_ARG]
    # Example: complex-function --verbose /path/to/file backup
    # Example: complex-function /simple/path
    echo "Complex function"
}
EOF
    
    source "$TEST_TEMP_DIR/help_core_functions.sh"
    
    run function-help complex
    
    assert_success
    assert_output --partial "complex-function"
    assert_output --partial "Description: A complex function with multiple parameters"
    assert_output --partial "Usage: complex-function [--flag] REQUIRED_ARG [OPTIONAL_ARG]"
    assert_output --partial "Example: complex-function --verbose /path/to/file backup"
    assert_output --partial "Example: complex-function /simple/path"
}