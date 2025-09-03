#!/usr/bin/env bats

# Integration Tests for Functions System
# Tests the complete functions and aliases system working together in isolation

# Load helpers
load "../helpers/helper"
load "../helpers/fixtures" 
load "../helpers/functions"

setup() {
    test_setup
    
    # Set up completely isolated function and alias system for integration testing
    mkdir -p "$TEST_TEMP_DIR/.aliases.d"
    mkdir -p "$TEST_TEMP_DIR/.functions.d"
    
    # Copy actual function files for realistic testing (with snake_case naming)
    cp "$PROJECT_ROOT/dot_functions.d/support.tmpl" "$TEST_TEMP_DIR/.functions.d/support.tmpl"
     cp "$PROJECT_ROOT/dot_functions.d/development.tmpl" "$TEST_TEMP_DIR/.functions.d/development.tmpl"
    cp "$PROJECT_ROOT/dot_functions.d/system.tmpl" "$TEST_TEMP_DIR/.functions.d/system.tmpl"
    
    # Create comprehensive test alias files in isolated environment
    create_isolated_test_alias_files "$TEST_TEMP_DIR/.aliases.d"
    
    # Set up completely isolated mock commands 
    setup_isolated_integration_mocks
    
    # Set up isolated test environment (no system HOME pollution)
    export HOME="$TEST_TEMP_DIR"
    cd "$TEST_TEMP_DIR"
}

teardown() {
    test_teardown
}

# Helper to set up completely isolated mocks for integration testing
setup_isolated_integration_mocks() {
    # Create isolated mock bin directory
    mkdir -p "$TEST_TEMP_DIR/mock-bin"
    export PATH="$TEST_TEMP_DIR/mock-bin:$PATH"
    
    cat > "$TEST_TEMP_DIR/mock-bin/git" << 'EOF'
#!/bin/bash
case "$1 $2" in
    "rev-parse --is-inside-work-tree")
        echo "true"
        exit 0
        ;;
    "rev-parse --abbrev-ref")
        echo "main"
        ;;
    "rev-parse --show-toplevel") 
        echo "$PWD"
        ;;
    "clone --quiet")
        local repo="$4"
        local dir="$5"
        if [[ "$repo" =~ github\.com ]]; then
            mkdir -p "$dir/.git"
            echo "Cloning into '$dir'..."
            exit 0
        else
            echo "fatal: repository '$repo' does not exist"
            exit 128
        fi
        ;;
    "status --porcelain")
        echo " M modified-file.txt"
        echo "?? new-file.txt"
        ;;
    "diff --stat")
        echo " modified-file.txt | 10 +++++++---"
        echo " 1 file changed, 7 insertions(+), 3 deletions(-)"
        ;;
    "branch --merged=main")
        echo "  old-feature"
        echo "  completed-task"
        ;;
    "branch -d")
        echo "Deleted branch $3 (was abc1234)."
        ;;
    "fetch --prune")
        echo "Pruning origin"
        ;;
    "for-each-ref --count="*)
        echo "main - 2 hours ago - Latest commit"
        echo "feature/new - 1 day ago - New feature"
        echo "hotfix/urgent - 3 days ago - Critical fix"
        ;;
    "log --follow")
        echo "commit abc123"
        echo "Author: Test User <test@example.com>"
        echo "Date: $(date)"
        echo ""
        echo "    Test commit message"
        ;;
    "init")
        mkdir -p .git
        echo "Initialized empty Git repository"
        ;;
    "add .")
        echo "Mock: Added all files"
        ;;
    "commit -m")
        echo "Mock: Created commit with message: $4"
        ;;
    *)
        echo "Mock git: $*"
        exit 0
        ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/mock-bin/git"
    
    # Add other essential mock commands for integration
    create_isolated_mock_command "seq" 'for i in $(seq 1 ${1:-5}); do echo $i; done'
    create_isolated_mock_command "dig" 'echo "192.168.1.1"'
    create_isolated_mock_command "host" 'echo "Mock reverse lookup for $1"'
    create_isolated_mock_command "osascript" 'echo "Mock osascript: $*"'
}

# Helper to create isolated mock commands for integration
create_isolated_mock_command() {
    local cmd="$1"
    local behavior="$2"
    cat > "$TEST_TEMP_DIR/mock-bin/$cmd" << EOF
#!/bin/bash
$behavior
EOF
    chmod +x "$TEST_TEMP_DIR/mock-bin/$cmd"
}

# Helper to create isolated test alias files
create_isolated_test_alias_files() {
    local alias_dir="$1"
    
    cat > "$alias_dir/dev_tools.tmpl" << 'EOF'
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

    cat > "$alias_dir/file_ops.tmpl" << 'EOF'
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
}

# =============================================================================
# Help System Integration Tests
# =============================================================================

@test "integration: help system should integrate aliases and functions" {
    # Source all help functions from isolated environment
    source "$TEST_TEMP_DIR/.functions.d/support.tmpl"
    
    # Test that alias search finds content from multiple modules
    run alias-search "git"
    
    assert_success
    assert_output --partial "=== DEV TOOLS ==="
    assert_output --partial "gs"
    assert_output --partial "git status"
    assert_output --partial "gp"
    assert_output --partial "git push"
}

@test "integration: function help should work with actual function files" {
    source "$TEST_TEMP_DIR/.functions.d/support.tmpl"
    
    run function-help "git"
    
    assert_success
    assert_output --partial "=== DEV WORKFLOW ==="
    assert_output --partial "git-export"
    assert_output --partial "Description: Clone a git repository without git history"
    assert_output --partial "git-branch-clean"
    assert_output --partial "Description: Delete merged local branches"
}

@test "integration: help system should handle mixed content search" {
    source "$TEST_TEMP_DIR/.functions.d/help-core.tmpl"
    
    # Search for term that exists in both aliases and functions
    run alias-help "docker"
    
    assert_success
    assert_output --partial "=== DEV TOOLS ==="
    assert_output --partial "dps"
    assert_output --partial "docker ps"
}

@test "integration: help system should provide comprehensive listings" {
    source "$TEST_TEMP_DIR/.functions.d/help-core.tmpl"
    
    # Test complete alias listing
    run alias-list
    
    assert_success
    assert_output --partial "=== DEV TOOLS ==="
    assert_output --partial "=== FILE OPS ==="
    assert_output --partial "=== INFRASTRUCTURE ==="
    
    # Test complete function listing  
    run function-list
    
    assert_success
    assert_output --partial "=== DEV WORKFLOW ==="
    assert_output --partial "=== SYSTEM ==="
    refute_output --partial "=== HELP CORE ===" # help-core functions are mostly private
}

# =============================================================================
# Development Workflow Integration Tests  
# =============================================================================

@test "integration: git functions should work together in realistic workflow" {
    # Source development workflow functions
    source "$TEST_TEMP_DIR/.functions.d/development.tmpl"
    
    # Set up a mock git repository
    setup_git_repository_mock "$TEST_TEMP_DIR/test-repo"
    cd "$TEST_TEMP_DIR/test-repo"
    
    # Test git workflow functions in sequence
    run git-current-branch
    assert_success
    assert_output "main"
    
    run git-uncommitted
    assert_success
    assert_output --partial "=== Uncommitted Changes ==="
    assert_output --partial "[ M] modified-file.txt"
    assert_output --partial "[??] new-file.txt"
    
    run git-recent-branches 5
    assert_success
    assert_output --partial "Recently used branches:"
    assert_output --partial "main - 2 hours ago"
    assert_output --partial "feature/new - 1 day ago"
}

@test "integration: project initialization should work with different languages" {
    source "$TEST_TEMP_DIR/.functions.d/development.tmpl"
    
    # Test JavaScript project initialization
    run project-init "js-test" "javascript"
    
    assert_success
    assert_output --partial "Project 'js-test' initialized with javascript template"
    
    # Verify files were created
    [ -d "js-test" ]
    [ -f "js-test/package.json" ]
    [ -f "js-test/index.js" ]
    [ -f "js-test/.gitignore" ]
    
    # Verify package.json has expected content
    grep -q "js-test" "js-test/package.json"
    grep -q "node_modules/" "js-test/.gitignore"
}

@test "integration: development server should detect project types correctly" {
    source "$TEST_TEMP_DIR/.functions.d/development.tmpl"
    
    # Create Node.js project structure
    create_test_project_structure "javascript" "node-project"
    cd "node-project"
    
    # Mock npm command
    cat > "$MOCK_BREW_PREFIX/bin/npm" << 'EOF'
#!/bin/bash
case "$1" in
    "start")
        echo "Mock: Starting Node.js development server"
        exit 0
        ;;
    *)
        echo "Mock npm: $*"
        ;;
esac
EOF
    chmod +x "$MOCK_BREW_PREFIX/bin/npm"
    
    run dev-server
    
    assert_success
    assert_output --partial "Detected Node.js project..."
    assert_output --partial "Starting with npm..."
    assert_output --partial "Mock: Starting Node.js development server"
}

@test "integration: code statistics should analyze real project structure" {
    source "$TEST_TEMP_DIR/.functions.d/development.tmpl"
    
    # Create a comprehensive test project
    create_comprehensive_test_project "test-project"
    
    run code-stats "test-project"
    
    assert_success
    assert_output --partial "Code statistics for:"
    assert_output --partial "Files by extension:"
    assert_output --partial "Total lines of code:"
    assert_output --partial "Directory structure:"
}

# =============================================================================
# System Utilities Integration Tests
# =============================================================================

@test "integration: system functions should work with real-world scenarios" {
    source "$TEST_TEMP_DIR/.functions.d/system.tmpl"
    
    # Test DNS resolution with multiple domains
    run dig-host "google.com"
    
    assert_success
    assert_output --partial "Forward lookup for google.com:"
    assert_output --partial "Reverse lookup for"
    
    # Test file operations
    echo "test file content" > "test-backup.txt"
    
    run backup-file "test-backup.txt"
    
    assert_success
    assert_output --partial "Backup created: test-backup.txt.backup_"
    
    # Verify backup was actually created
    local backup_count=$(ls test-backup.txt.backup_* 2>/dev/null | wc -l)
    [ "$backup_count" -eq 1 ]
}

@test "integration: system monitoring functions should provide useful information" {
    source "$TEST_TEMP_DIR/.functions.d/system.tmpl"
    
    run system-info
    
    assert_success
    assert_output --partial "=== System Information ==="
    assert_output --partial "Hostname:"
    assert_output --partial "Uptime:"
    assert_output --partial "=== Operating System ==="
    assert_output --partial "=== Hardware ==="
    assert_output --partial "=== Storage ==="
}

@test "integration: port checking should identify running services" {
    source "$TEST_TEMP_DIR/.functions.d/system.tmpl"
    
    # Test port with running service
    run process-port 8080
    
    assert_success
    assert_output --partial "Checking port 8080..."
    assert_output --partial "node"
    assert_output --partial "TCP *:8080 (LISTEN)"
    
    # Test empty port
    run process-port 3000
    
    assert_success
    assert_output --partial "Checking port 3000..."
}

# =============================================================================
# Cross-Function Integration Tests
# =============================================================================

@test "integration: functions should work together in complex workflows" {
    # Source all function modules
    source "$TEST_TEMP_DIR/.functions.d/development.tmpl"
    source "$TEST_TEMP_DIR/.functions.d/system.tmpl"
    
    # Create a project, initialize it, and analyze it
    run project-init "integration-test" "python"
    assert_success
    
    cd "integration-test"
    
    # Create backup of important file
    run backup-file "main.py"
    assert_success
    
    # Check project statistics
    run code-stats
    assert_success
    assert_output --partial "Code statistics for:"
    
    # Navigate to git root (should be current directory)
    run git-root
    # Should complete without error since we're in the project root
}

@test "integration: help system should find functions across all modules" {
    source "$TEST_TEMP_DIR/.functions.d/help-core.tmpl"
    
    # Search for functions that exist in different modules
    run function-help "git"
    assert_success
    assert_output --partial "git-export"
    assert_output --partial "git-branch-clean" 
    assert_output --partial "git-current-branch"
    
    run function-help "system"
    assert_success
    assert_output --partial "system-info"
    
    run function-help "run"
    assert_success  
    assert_output --partial "run-repeat"
}

@test "integration: error handling should be consistent across function modules" {
    source "$TEST_TEMP_DIR/.functions.d/development.tmpl"
    source "$TEST_TEMP_DIR/.functions.d/system.tmpl"
    
    # Test git functions outside of git repository
    export MOCK_GIT_REPO=false
    cat > "$MOCK_BREW_PREFIX/bin/git" << 'EOF'
#!/bin/bash
case "$1 $2" in
    "rev-parse --is-inside-work-tree")
        exit 128
        ;;
    *)
        echo "Mock git: $*"
        ;;
esac
EOF
    chmod +x "$MOCK_BREW_PREFIX/bin/git"
    
    # Multiple git functions should all fail with consistent error
    run git-current-branch
    assert_failure
    assert_output --partial "Error: Not in a git repository"
    
    run git-uncommitted
    assert_failure
    assert_output --partial "Error: Not in a git repository"
    
    run git-branch-clean
    assert_failure
    assert_output --partial "Error: Not in a git repository"
}

# =============================================================================
# Real-World Usage Scenarios
# =============================================================================

@test "integration: complete development workflow simulation" {
    # This test simulates a complete development workflow
    source "$TEST_TEMP_DIR/.functions.d/development.tmpl"
    source "$TEST_TEMP_DIR/.functions.d/system.tmpl"
    source "$TEST_TEMP_DIR/.functions.d/help-core.tmpl"
    
    # 1. Create a new project
    run project-init "workflow-test" "javascript"
    assert_success
    
    cd "workflow-test"
    
    # 2. Check current git branch
    run git-current-branch
    assert_success
    assert_output "main"
    
    # 3. Check for uncommitted changes
    run git-uncommitted
    assert_success
    assert_output --partial "=== Uncommitted Changes ==="
    
    # 4. Get project statistics
    run code-stats
    assert_success
    assert_output --partial "Code statistics"
    
    # 5. Create backup of important file
    run backup-file "package.json"
    assert_success
    assert_output --partial "Backup created"
    
    # 6. Check system info
    run system-info
    assert_success
    assert_output --partial "System Information"
}

@test "integration: help system provides useful guidance for new users" {
    source "$TEST_TEMP_DIR/.functions.d/help-core.tmpl"
    
    # A new user searches for common development tasks
    
    # Search for git-related functionality
    run alias-search git
    assert_success
    assert_output --partial "gs"
    assert_output --partial "git status"
    
    run function-help git
    assert_success
    assert_output --partial "git-export"
    assert_output --partial "Usage:"
    assert_output --partial "Example:"
    
    # Search for file operations
    run alias-search file
    assert_success
    assert_output --partial "=== FILE OPS ==="
    
    # Get comprehensive listings
    run function-list
    assert_success
    # Should see functions from multiple modules
    assert_output --partial "=== DEV WORKFLOW ==="
    assert_output --partial "=== SYSTEM ==="
}

@test "integration: functions handle missing dependencies gracefully" {
    source "$TEST_TEMP_DIR/.functions.d/development.tmpl"
    source "$TEST_TEMP_DIR/.functions.d/system.tmpl"
    
    # Remove some commands and test graceful degradation
    rm -f "$MOCK_BREW_PREFIX/bin/git"
    rm -f "$MOCK_BREW_PREFIX/bin/dig"
    rm -f "$MOCK_BREW_PREFIX/bin/cargo"
    
    # Functions should detect missing dependencies and provide helpful errors
    run git-current-branch
    assert_failure
    # Should fail gracefully (command not found rather than script error)
    
    run dig-host "google.com"  
    assert_failure
    # Should fail gracefully
    
    # Project initialization should work even with missing optional tools
    run project-init "test-graceful" "rust"
    assert_success
    assert_output --partial "cargo not found, manual Cargo.toml creation needed"
}

# =============================================================================
# Performance and Scalability Tests
# =============================================================================

@test "integration: functions should perform well with large data sets" {
    source "$TEST_TEMP_DIR/.functions.d/help-core.tmpl"
    
    # Create many alias files to test performance
    for i in {1..10}; do
        cat > "$MOCK_HOME/.aliases.d/test-module-$i.tmpl" << EOF
# Test Module $i
alias test$i='echo test $i'
alias another$i='echo another $i'
alias more$i='echo more $i'
EOF
    done
    
    # Function should still complete quickly
    run alias-list
    
    assert_success
    # Should show content from multiple modules
    assert_output --partial "=== TEST MODULE 1 ==="
    assert_output --partial "=== TEST MODULE 10 ==="
}

@test "integration: help system should handle complex search patterns" {
    source "$TEST_TEMP_DIR/.functions.d/help-core.tmpl"
    
    # Test complex search scenarios
    run alias-search "docker"
    assert_success
    assert_output --partial "dps"
    assert_output --partial "docker ps"
    
    # Test case insensitive search
    run alias-search "DOCKER"
    assert_success
    assert_output --partial "dps"
    
    # Test partial matches
    run alias-search "doc"
    assert_success
    assert_output --partial "docker"
}

@test "integration: functions maintain consistency in edge cases" {
    source "$TEST_TEMP_DIR/.functions.d/development.tmpl"
    source "$TEST_TEMP_DIR/.functions.d/system.tmpl"
    
    # Test functions with unusual but valid inputs
    
    # Very long project name  
    local long_name="very-very-very-long-project-name-that-exceeds-normal-length"
    run project-init "$long_name"
    assert_success
    assert_output --partial "Project '$long_name' initialized"
    
    # Very high repeat count (should work but be practical)
    run run-repeat 100 echo "test"
    assert_success
    # Should show [1/100] through [100/100]
    assert_output --partial "[1/100]"
    assert_output --partial "[100/100]"
}