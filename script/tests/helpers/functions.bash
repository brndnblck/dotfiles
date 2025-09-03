#!/usr/bin/env bash

# Function Test Helpers for Dotfiles Testing
# Provides specialized utilities for testing function files

# Create mock alias files with realistic content
create_test_alias_files() {
    local aliases_dir="$1"
    mkdir -p "$aliases_dir"

    # Development tools aliases
    cat > "$aliases_dir/dev-tools.tmpl" << 'EOF'
# Development Tools Aliases
# Common tools and shortcuts for development work

# Basic file operations
alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'

# Git shortcuts
alias gs='git status'
alias gp='git push'
alias gl='git pull'
alias gc='git commit -m'
alias gco='git checkout'
alias gb='git branch'
alias gd='git diff'

# Docker shortcuts  
alias dps='docker ps'
alias dimg='docker images'
alias dstop='docker stop $(docker ps -q)'
alias drm='docker rm $(docker ps -aq)'

# Node.js shortcuts
alias ni='npm install'
alias ns='npm start'
alias nt='npm test'
alias nb='npm run build'
EOF

    # File operations aliases
    cat > "$aliases_dir/file-ops.tmpl" << 'EOF'
# File Operations Aliases
# Shortcuts for common file operations

# Navigation shortcuts
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'

# Safety aliases
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias ln='ln -i'

# Directory operations
alias md='mkdir -p'
alias rd='rmdir'

# File viewing
alias cat='cat -n'
alias less='less -R'
alias tree='tree -C'
EOF

    # Infrastructure aliases
    cat > "$aliases_dir/infrastructure.tmpl" << 'EOF'
# Infrastructure Aliases
# Tools for managing infrastructure and deployments

# SSH shortcuts
alias ssh-config='vim ~/.ssh/config'
alias ssh-keys='ls -la ~/.ssh/'

# Network tools
alias myip='curl -s https://ipinfo.io/ip'
alias ports='netstat -tulanp'
alias listening='lsof -i -P -n | grep LISTEN'

# System monitoring
alias top='htop'
alias df='df -h'
alias du='du -h'
alias free='free -h'
EOF
}

# Create mock function files with realistic content
create_test_function_files() {
    local functions_dir="$1"
    mkdir -p "$functions_dir"

    # Development workflow functions
    cat > "$functions_dir/dev-workflow.tmpl" << 'EOF'
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

git-current-branch() {
    # Description: Get the current git branch name
    # Usage: git-current-branch  
    # Example: git-current-branch
    echo "main"
}

project-init() {
    # Description: Initialize a new project with common development files
    # Usage: project-init PROJECT_NAME [LANGUAGE]
    # Example: project-init my-app javascript
    echo "Mock project initialization"
}

_private_helper_function() {
    # Description: This is a private function and should not appear in listings
    # Usage: _private_helper_function
    # Example: _private_helper_function  
    echo "This is private"
}
EOF

    # System utilities functions
    cat > "$functions_dir/system.tmpl" << 'EOF'
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

remind() {
    # Description: Add a reminder to the Reminders.app (macOS only)
    # Usage: remind "TEXT" or echo "text" | remind
    # Example: remind "Buy milk at 5pm" or echo "Meeting tomorrow" | remind
    echo "Mock reminder function"
}

system-info() {
    # Description: Display comprehensive system information
    # Usage: system-info
    # Example: system-info
    echo "Mock system info"
}
EOF

    # Help core functions (smaller subset for testing)
    cat > "$functions_dir/help-core.tmpl" << 'EOF'
# Help and documentation functions

_render_aliases() {
    # Description: Internal function to render alias matches with formatting
    # Usage: _render_aliases MODULE_NAME MATCHES [SHOW_COMMENTS] 
    # Example: _render_aliases "DEV TOOLS" "$matches" true
    echo "Mock render aliases"
}

alias-help() {
    # Description: Search for and display help for specific aliases with context
    # Usage: alias-help SEARCH_TERM
    # Example: alias-help git
    echo "Mock alias help"
}

function-help() {
    # Description: Display help for all custom functions
    # Usage: function-help [SEARCH_TERM] 
    # Example: function-help git
    echo "Mock function help"
}
EOF
}

# Set up git repository mock for testing git functions
setup_git_repository_mock() {
    local test_dir="$1"
    mkdir -p "$test_dir/.git"

    # Create mock git config
    cat > "$test_dir/.git/config" << 'EOF'
[core]
	repositoryformatversion = 0
	filemode = true
	bare = false
	logallrefupdates = true
[remote "origin"]
	url = https://github.com/test/repo.git
	fetch = +refs/heads/*:refs/remotes/origin/*
EOF

    # Create mock HEAD file
    echo "ref: refs/heads/main" > "$test_dir/.git/HEAD"

    # Create refs structure
    mkdir -p "$test_dir/.git/refs/heads"
    echo "abc123def456" > "$test_dir/.git/refs/heads/main"
    echo "def456abc123" > "$test_dir/.git/refs/heads/feature"
}

# Create mock project structures for testing project functions
create_test_project_structure() {
    local project_type="$1"
    local project_dir="$2"

    mkdir -p "$project_dir"

    case "$project_type" in
        "javascript" | "js" | "node")
            cat > "$project_dir/package.json" << 'EOF'
{
  "name": "test-project",
  "version": "1.0.0", 
  "scripts": {
    "start": "node index.js",
    "test": "jest",
    "build": "webpack"
  },
  "dependencies": {
    "express": "^4.18.0"
  }
}
EOF
            echo "console.log('Hello World');" > "$project_dir/index.js"
            mkdir -p "$project_dir/src" "$project_dir/test"
            ;;
        "python" | "py")
            echo "flask==2.0.0" > "$project_dir/requirements.txt"
            echo "print('Hello World')" > "$project_dir/main.py"
            mkdir -p "$project_dir/src" "$project_dir/tests"
            ;;
        "rust")
            cat > "$project_dir/Cargo.toml" << 'EOF'
[package]
name = "test-project"
version = "0.1.0"
edition = "2021"

[dependencies]
EOF
            mkdir -p "$project_dir/src"
            echo 'fn main() { println!("Hello World"); }' > "$project_dir/src/main.rs"
            ;;
        "go")
            echo "module test-project" > "$project_dir/go.mod"
            echo 'package main
import "fmt"
func main() { fmt.Println("Hello World") }' > "$project_dir/main.go"
            ;;
    esac
}

# Mock system command responses for different scenarios
setup_system_command_mocks() {
    local mock_dir="$1"

    # DNS resolution mocks
    cat > "$mock_dir/dig" << 'EOF'
#!/bin/bash
case "$*" in
    "+short google.com")
        echo "172.217.14.206"
        ;;
    "+short github.com")
        echo "140.82.112.4"
        ;;  
    "+short invalid.domain")
        exit 1
        ;;
    *)
        echo "192.168.1.1"
        ;;
esac
EOF
    chmod +x "$mock_dir/dig"

    # File system mocks
    cat > "$mock_dir/find" << 'EOF'
#!/bin/bash
if [[ "$*" == *"-size +100M"* ]]; then
    echo "/tmp/largefile1.bin"
    echo "/tmp/largefile2.iso"
elif [[ "$*" == *"-mtime +7"* ]]; then
    echo "/tmp/oldfile1.tmp"
    echo "/tmp/oldfile2.cache"  
elif [[ "$*" == *"-mtime +30"* ]]; then
    echo "$HOME/Downloads/old1.zip"
    echo "$HOME/Downloads/old2.dmg"
fi
EOF
    chmod +x "$mock_dir/find"

    # Process monitoring mocks
    cat > "$mock_dir/lsof" << 'EOF'
#!/bin/bash
if [[ "$*" == *":8080"* ]]; then
    echo "COMMAND  PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME"
    echo "node    1234  user   20u  IPv4  0x1234      0t0  TCP *:8080 (LISTEN)"
elif [[ "$*" == *":3000"* ]]; then
    # Empty response - no process using port
    exit 0
else
    echo "Mock lsof output for $*"
fi
EOF
    chmod +x "$mock_dir/lsof"

    # System information mocks
    cat > "$mock_dir/uptime" << 'EOF'
#!/bin/bash
echo " 10:30AM  up 2 days, 14:45,  2 users,  load average: 1.23, 1.45, 1.67"
EOF
    chmod +x "$mock_dir/uptime"

    cat > "$mock_dir/hostname" << 'EOF'
#!/bin/bash  
echo "test-macbook-pro.local"
EOF
    chmod +x "$mock_dir/hostname"
}

# Assert function documentation format is correct
assert_function_documentation() {
    local function_name="$1"
    local output="$2"

    # Check that function name appears
    if ! echo "$output" | grep -q "$function_name"; then
        fail "Function name '$function_name' not found in output"
    fi

    # Check for required documentation elements
    if ! echo "$output" | grep -q "Description:"; then
        fail "Function '$function_name' missing Description in documentation"
    fi

    if ! echo "$output" | grep -q "Usage:"; then
        fail "Function '$function_name' missing Usage in documentation"
    fi

    if ! echo "$output" | grep -q "Example:"; then
        fail "Function '$function_name' missing Example in documentation"
    fi
}

# Assert alias formatting is consistent
assert_alias_formatting() {
    local output="$1"

    # Check for section headers
    if ! echo "$output" | grep -q "===.*==="; then
        fail "Missing section headers in alias output"
    fi

    # Check for alias entries (basic format validation)
    if echo "$output" | grep -q "alias.*="; then
        # Good - found alias entries
        :
    else
        fail "No properly formatted alias entries found"
    fi
}

# Validate that private functions are excluded from listings
assert_no_private_functions() {
    local output="$1"

    if echo "$output" | grep -q "_.*function"; then
        fail "Private functions (starting with _) should not appear in listings"
    fi
}

# Create temporary function source file for testing
create_temp_function_file() {
    local temp_file="$1"
    local function_content="$2"

    cat > "$temp_file" << EOF
#!/usr/bin/env bash
# Temporary function file for testing

$function_content
EOF
}

# Test function argument validation helper
test_function_argument_validation() {
    local function_name="$1"
    local required_args="$2"
    local test_file="$3"

    # Source the function file
    source "$test_file"

    # Test with no arguments
    run "$function_name"
    assert_failure
    assert_output --partial "Usage:"

    # Test with insufficient arguments if required_args > 1
    if [ "$required_args" -gt 1 ]; then
        run "$function_name" "single_arg"
        assert_failure
        assert_output --partial "Usage:"
    fi
}

# Setup mock environment variables for testing
setup_test_environment_vars() {
    export TEST_MODE=true
    export MOCK_COMMANDS=true
    export DISABLE_INTERACTIVE=true
    export NO_COLOR=true
}

# Clean up test environment variables
cleanup_test_environment_vars() {
    unset TEST_MODE
    unset MOCK_COMMANDS
    unset DISABLE_INTERACTIVE
    unset NO_COLOR
}

# Verify command exists in mocked environment
assert_mock_command_available() {
    local command_name="$1"
    local mock_bin_dir="$2"

    if [ ! -x "$mock_bin_dir/$command_name" ]; then
        fail "Mock command '$command_name' not found in $mock_bin_dir"
    fi
}

# Create comprehensive test project with multiple file types
create_comprehensive_test_project() {
    local project_dir="$1"

    mkdir -p "$project_dir/src/components"
    mkdir -p "$project_dir/tests/unit"
    mkdir -p "$project_dir/docs"

    # JavaScript files
    echo "console.log('main');" > "$project_dir/src/main.js"
    echo "export const utils = {};" > "$project_dir/src/utils.js"
    echo "import React from 'react';" > "$project_dir/src/components/App.jsx"

    # Python files
    echo "def main(): pass" > "$project_dir/src/main.py"
    echo "import unittest" > "$project_dir/tests/unit/test_main.py"

    # Go files
    echo "package main" > "$project_dir/main.go"
    echo "package utils" > "$project_dir/src/utils.go"

    # Rust files
    echo "fn main() {}" > "$project_dir/src/main.rs"
    echo "#[cfg(test)]" > "$project_dir/src/lib.rs"

    # Configuration files
    echo "{}" > "$project_dir/package.json"
    echo "requirements.txt content" > "$project_dir/requirements.txt"
    echo "# README" > "$project_dir/README.md"
    echo ".env" > "$project_dir/.gitignore"
}

# Export all functions for use in test files
export -f create_test_alias_files
export -f create_test_function_files
export -f setup_git_repository_mock
export -f create_test_project_structure
export -f setup_system_command_mocks
export -f assert_function_documentation
export -f assert_alias_formatting
export -f assert_no_private_functions
export -f create_temp_function_file
export -f test_function_argument_validation
export -f setup_test_environment_vars
export -f cleanup_test_environment_vars
export -f assert_mock_command_available
export -f create_comprehensive_test_project
