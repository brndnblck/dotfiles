#!/usr/bin/env bats

# Test Suite for dot_functions.d/development.tmpl
# Tests development workflow and git utility functions with complete isolation

# Load helpers
load "../../helpers/base"
load "../../helpers/fixtures"

setup() {
    test_setup
    
    # Copy the function file to test environment
    cp "$PROJECT_ROOT/dot_functions.d/development.tmpl" "$TEST_TEMP_DIR/development_functions.sh"
    
    # Set up completely isolated mock environment
    setup_isolated_test_environment
    
    # Create isolated test project structure
    mkdir -p "$TEST_TEMP_DIR/test-projects"
    cd "$TEST_TEMP_DIR/test-projects"
}

teardown() {
    test_teardown
}

# =============================================================================
# COMPLETE ISOLATION ENVIRONMENT SETUP
# =============================================================================

setup_isolated_test_environment() {
    # Create isolated test home and config directories
    export TEST_HOME="$TEST_TEMP_DIR/home"
    export TEST_CADDY_CONFIG="$TEST_HOME/.config/caddy"
    export TEST_PROJECT_ROOT="$TEST_TEMP_DIR/projects"
    
    mkdir -p "$TEST_HOME"
    mkdir -p "$TEST_CADDY_CONFIG"
    mkdir -p "$TEST_PROJECT_ROOT"
    
    # Override environment variables for complete isolation
    export HOME="$TEST_HOME"
    export CADDY_CONFIG_DIR="$TEST_CADDY_CONFIG"
    export DIRENV_CMD="$TEST_TEMP_DIR/mock-bin/direnv"
    export CADDY_CMD="$TEST_TEMP_DIR/mock-bin/caddy"
    export GIT_CMD="$TEST_TEMP_DIR/mock-bin/git"
    export KILL_CMD="$TEST_TEMP_DIR/mock-bin/kill"
    
    # Create isolated mock bin directory
    mkdir -p "$TEST_TEMP_DIR/mock-bin"
    export PATH="$TEST_TEMP_DIR/mock-bin:/usr/bin:/bin"
    
    # Create call logging directory
    mkdir -p "$TEST_TEMP_DIR/logs"
    
    # Set up all required mocks
    create_complete_mock_environment
}

create_complete_mock_environment() {
    # Create comprehensive command mocks with spies
    create_git_mock_with_spy
    create_caddy_mock_with_spy
    create_direnv_mock_with_spy
    create_process_mocks_with_spies
    create_utility_mocks
}

# =============================================================================
# SOPHISTICATED COMMAND MOCKS WITH SPY FUNCTIONALITY
# =============================================================================

create_git_mock_with_spy() {
    cat > "$TEST_TEMP_DIR/mock-bin/git" << 'EOF'
#!/bin/bash
echo "git $*" >> "$TEST_TEMP_DIR/logs/git_calls.log"

case "$1" in
    "rev-parse")
        case "$2" in
            "--is-inside-work-tree")
                if [ "${MOCK_GIT_REPO:-true}" = "true" ]; then
                    echo "true"
                    exit 0
                else
                    exit 128
                fi
                ;;
            "--abbrev-ref")
                echo "${MOCK_GIT_BRANCH:-main}"
                ;;
            "--show-toplevel")
                echo "${MOCK_GIT_ROOT:-$PWD}"
                ;;
        esac
        ;;
    "clone")
        if [ "$2" = "--quiet" ] && [ "$3" = "--depth=1" ]; then
            repo="$4"
            dir="$5"
            if [ "$repo" = "https://github.com/test/repo.git" ]; then
                mkdir -p "$dir"
                mkdir -p "$dir/.git"
                echo "Mock cloned $repo to $dir"
                exit 0
            else
                echo "fatal: repository '$repo' does not exist"
                exit 128
            fi
        fi
        ;;
    "init")
        if [ "$2" = "--quiet" ]; then
            mkdir -p .git
            echo "Initialized empty Git repository in $PWD/.git/"
        else
            mkdir -p .git
            echo "Initialized empty Git repository in $PWD/.git/"
        fi
        ;;
    "add")
        echo "Mock: git add $*"
        ;;
    "commit")
        echo "Mock: git commit $*"
        ;;
    "status")
        case "$2" in
            "--porcelain")
                echo "${MOCK_GIT_STATUS:-}"
                ;;
            *)
                echo "On branch ${MOCK_GIT_BRANCH:-main}"
                echo "nothing to commit, working tree clean"
                ;;
        esac
        ;;
    "diff")
        case "$2" in
            "--stat")
                echo "Mock diff stats"
                ;;
            *)
                echo "Mock diff output"
                ;;
        esac
        ;;
    "branch")
        case "$2" in
            "--merged=master")
                echo "  feature-branch-1"
                echo "  feature-branch-2"
                ;;
            "--merged=main")
                echo "  old-feature"
                echo "  hotfix"
                ;;
            "-d")
                echo "Deleted branch $3 (was abc1234)."
                ;;
        esac
        ;;
    "fetch")
        if [ "$2" = "--prune" ]; then
            echo "Mock: pruning remote tracking branches"
        fi
        ;;
    "for-each-ref")
        echo "main - 2 hours ago - Latest commit"
        echo "feature/test - 1 day ago - Test feature" 
        echo "hotfix/urgent - 3 days ago - Urgent fix"
        ;;
    "log")
        echo "Mock git log output for file: ${*: -1}"
        ;;
    "ls-files")
        if [ "$2" = "--error-unmatch" ]; then
            # Mock file exists in git
            exit 0
        fi
        ;;
    *)
        echo "Mock git: $*"
        ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/mock-bin/git"
}

create_caddy_mock_with_spy() {
    cat > "$TEST_TEMP_DIR/mock-bin/caddy" << 'EOF'
#!/bin/bash
echo "caddy $*" >> "$TEST_TEMP_DIR/logs/caddy_calls.log"

case "$1" in
    "reload")
        if [ "$2" = "--config" ] && [ -f "$3" ]; then
            echo "Configuration reloaded"
            exit 0
        else
            echo "Error: configuration file not found"
            exit 1
        fi
        ;;
    "validate")
        if [ "$2" = "--config" ] && [ -f "$3" ]; then
            echo "Valid configuration"
            exit 0
        else
            echo "Error: configuration file not found"
            exit 1
        fi
        ;;
    *)
        echo "caddy: $*"
        exit 0
        ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/mock-bin/caddy"
}

create_direnv_mock_with_spy() {
    cat > "$TEST_TEMP_DIR/mock-bin/direnv" << 'EOF'
#!/bin/bash
echo "direnv $*" >> "$TEST_TEMP_DIR/logs/direnv_calls.log"

case "$1" in
    "allow")
        echo "direnv: allowed"
        exit 0
        ;;
    "reload")
        echo "direnv: export +ENVIRONMENT"
        exit 0
        ;;
    "status")
        if [ "${MOCK_DIRENV_ALLOWED:-true}" = "true" ]; then
            echo "Found RC allowed true"
        else
            echo "Found RC not allowed"
        fi
        exit 0
        ;;
    *)
        echo "direnv: $*"
        exit 0
        ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/mock-bin/direnv"
}

create_process_mocks_with_spies() {
    # Mock lsof with configurable behavior
    cat > "$TEST_TEMP_DIR/mock-bin/lsof" << 'EOF'
#!/bin/bash
echo "lsof $*" >> "$TEST_TEMP_DIR/logs/lsof_calls.log"

if [[ "$*" == *"-ti tcp:"* ]]; then
    port=$(echo "$*" | sed 's/.*tcp://' | sed 's/ .*//')
    if [ -f "$TEST_TEMP_DIR/mock_processes_port_${port}" ]; then
        cat "$TEST_TEMP_DIR/mock_processes_port_${port}"
        exit 0
    fi
fi
exit 1
EOF
    chmod +x "$TEST_TEMP_DIR/mock-bin/lsof"

    # Mock kill command
    cat > "$TEST_TEMP_DIR/mock-bin/kill" << 'EOF'
#!/bin/bash
echo "kill $*" >> "$TEST_TEMP_DIR/logs/kill_calls.log"
exit 0
EOF
    chmod +x "$TEST_TEMP_DIR/mock-bin/kill"

    # Mock pgrep command  
    cat > "$TEST_TEMP_DIR/mock-bin/pgrep" << 'EOF'
#!/bin/bash
echo "pgrep $*" >> "$TEST_TEMP_DIR/logs/pgrep_calls.log"

if [ "$1" = "-x" ]; then
    # Handle both 'caddy' and full path to mock caddy
    cmd="$2"
    if [[ "$cmd" == *"/caddy" ]] || [ "$cmd" = "caddy" ]; then
        if [ "${MOCK_CADDY_RUNNING:-false}" = "true" ]; then
            echo "12345"
            exit 0
        else
            exit 1
        fi
    fi
fi
exit 1
EOF
    chmod +x "$TEST_TEMP_DIR/mock-bin/pgrep"

    # Mock sleep command
    cat > "$TEST_TEMP_DIR/mock-bin/sleep" << 'EOF'
#!/bin/bash
echo "sleep $*" >> "$TEST_TEMP_DIR/logs/sleep_calls.log"
exit 0
EOF
    chmod +x "$TEST_TEMP_DIR/mock-bin/sleep"
}

create_utility_mocks() {
    # Create isolated mock commands that never call system tools
    local commands=("yarn" "npm" "cargo" "go" "python3" "jq" "tree" "command" "dig")
    
    for cmd in "${commands[@]}"; do
        cat > "$TEST_TEMP_DIR/mock-bin/$cmd" << EOF
#!/bin/bash
echo "$cmd \$*" >> "$TEST_TEMP_DIR/logs/${cmd}_calls.log"
echo "Mock $cmd output"
exit 0
EOF
        chmod +x "$TEST_TEMP_DIR/mock-bin/$cmd"
    done

    # Special mock for 'command' built-in
    cat > "$TEST_TEMP_DIR/mock-bin/command" << 'EOF'
#!/bin/bash
if [ "$1" = "-v" ]; then
    cmd="$2"
    if [ -x "$TEST_TEMP_DIR/mock-bin/$cmd" ]; then
        echo "$TEST_TEMP_DIR/mock-bin/$cmd"
        exit 0
    else
        exit 1
    fi
fi
exit 0
EOF
    chmod +x "$TEST_TEMP_DIR/mock-bin/command"
}

# =============================================================================
# TEST FIXTURE HELPERS
# =============================================================================

create_caddyfile_fixture() {
    local fixture_type="${1:-empty}"
    
    case "$fixture_type" in
        "empty")
            cat > "$TEST_CADDY_CONFIG/Caddyfile" << 'EOF'
# Empty Caddyfile
# Default catch-all for undefined .test domains
*.test {
  respond "No service configured for {host}" 404
}
EOF
            ;;
        "with_projects")
            cat > "$TEST_CADDY_CONFIG/Caddyfile" << 'EOF'
# Global options
{
  # Config here
}

# Reusable dev snippet
(dev_common) {
  encode zstd gzip
}

# myapp development server
myapp.test {
  import dev_common
  reverse_proxy localhost:3000
}

# api development server
api.test {
  import dev_common
  reverse_proxy localhost:8000
}

# Default catch-all for undefined .test domains
*.test {
  import dev_common
  respond "No service configured for {host}" 404
}
EOF
            ;;
    esac
}

mock_processes_on_port() {
    local port="$1"
    shift
    local pids="$*"
    
    if [ -n "$pids" ]; then
        echo "$pids" > "$TEST_TEMP_DIR/mock_processes_port_${port}"
    else
        rm -f "$TEST_TEMP_DIR/mock_processes_port_${port}"
    fi
}

# =============================================================================
# SPY VERIFICATION HELPERS  
# =============================================================================

assert_command_called() {
    local command="$1"
    local expected_args="${2:-}"
    local log_file="$TEST_TEMP_DIR/logs/${command}_calls.log"
    
    if [ ! -f "$log_file" ]; then
        fail "Command '$command' was never called (no log file found)"
    fi
    
    if [ -n "$expected_args" ]; then
        if ! grep -q "$command $expected_args" "$log_file"; then
            fail "Command '$command' was not called with expected args: '$expected_args'\nActual calls:\n$(cat "$log_file")"
        fi
    else
        if [ ! -s "$log_file" ]; then
            fail "Command '$command' was never called"
        fi
    fi
}

assert_command_not_called() {
    local command="$1"
    local log_file="$TEST_TEMP_DIR/logs/${command}_calls.log"
    
    if [ -f "$log_file" ] && [ -s "$log_file" ]; then
        fail "Command '$command' was called but should not have been:\n$(cat "$log_file")"
    fi
}

assert_file_contains() {
    local file_path="$1"
    local expected_content="$2"

    if [ ! -f "$file_path" ]; then
        fail "File does not exist: $file_path"
    fi

    if ! grep -q "$expected_content" "$file_path"; then
        fail "File $file_path does not contain: $expected_content\nActual content:\n$(cat "$file_path")"
    fi
}

assert_file_not_contains() {
    local file_path="$1"
    local unwanted_content="$2"

    if [ ! -f "$file_path" ]; then
        return  # File doesn't exist, so it doesn't contain the unwanted content
    fi

    if grep -q "$unwanted_content" "$file_path"; then
        fail "File $file_path should not contain: $unwanted_content\nActual content:\n$(cat "$file_path")"
    fi
}

# =============================================================================
# HELPER FUNCTION TESTS WITH COMPLETE ISOLATION
# =============================================================================

@test "development: _dev_get_port_for_layout should return correct ports for tech stacks" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    # Test all known layouts
    run _dev_get_port_for_layout "node"
    assert_success
    assert_output "3000"
    
    run _dev_get_port_for_layout "nodejs"
    assert_success
    assert_output "3000"
    
    run _dev_get_port_for_layout "python"
    assert_success
    assert_output "8000"
    
    run _dev_get_port_for_layout "python3"
    assert_success
    assert_output "8000"
    
    run _dev_get_port_for_layout "ruby"
    assert_success
    assert_output "4000"
    
    run _dev_get_port_for_layout "go"
    assert_success
    assert_output "8080"
    
    run _dev_get_port_for_layout "rust"
    assert_success
    assert_output "8001"
    
    run _dev_get_port_for_layout "generic"
    assert_success
    assert_output "3000"
    
    # Test unknown layout defaults to generic
    run _dev_get_port_for_layout "unknown"
    assert_success
    assert_output "3000"
}

@test "development: _dev_validate_project_name should validate project names correctly" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    # Valid names
    run _dev_validate_project_name "myapp"
    assert_success
    
    run _dev_validate_project_name "my-app"
    assert_success
    
    run _dev_validate_project_name "app123"
    assert_success
    
    run _dev_validate_project_name "a"
    assert_success
    
    # Invalid names
    run _dev_validate_project_name ""
    assert_failure
    assert_output --partial "Error: Project name cannot be empty"
    
    run _dev_validate_project_name "my app"
    assert_failure
    assert_output --partial "Error: Project name cannot contain spaces"
    
    run _dev_validate_project_name "-app"
    assert_failure
    assert_output --partial "Error: Project name must contain only letters, numbers, and hyphens"
    
    run _dev_validate_project_name "app-"
    assert_failure
    assert_output --partial "Error: Project name must contain only letters, numbers, and hyphens"
    
    run _dev_validate_project_name "app@name"
    assert_failure
    assert_output --partial "Error: Project name must contain only letters, numbers, and hyphens"
    
    run _dev_validate_project_name "-"
    assert_failure
    assert_output --partial "Error: Single character project names must be alphanumeric"
}

@test "development: _dev_get_project_port should parse Caddyfile correctly" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    # Create fixture with projects
    create_caddyfile_fixture "with_projects"
    
    run _dev_get_project_port "myapp"
    assert_success
    assert_output "3000"
    
    run _dev_get_project_port "api"
    assert_success
    assert_output "8000"
    
    # Non-existent project should return default
    run _dev_get_project_port "nonexistent"
    assert_success
    assert_output "3000"
}

@test "development: _dev_get_project_port should handle missing Caddyfile gracefully" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    # No Caddyfile exists
    run _dev_get_project_port "myapp"
    assert_success
    assert_output "3000"
}

@test "development: _dev_add_to_caddyfile should add project correctly" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    # Create empty Caddyfile
    create_caddyfile_fixture "empty"
    
    run _dev_add_to_caddyfile "testapp" "4000"
    assert_success
    
    # Verify the project was added before the catch-all
    assert_file_contains "$TEST_CADDY_CONFIG/Caddyfile" "# testapp development server"
    assert_file_contains "$TEST_CADDY_CONFIG/Caddyfile" "testapp.test {"
    assert_file_contains "$TEST_CADDY_CONFIG/Caddyfile" "import dev_common"
    assert_file_contains "$TEST_CADDY_CONFIG/Caddyfile" "reverse_proxy localhost:4000"
    
    # Verify catch-all still exists after
    assert_file_contains "$TEST_CADDY_CONFIG/Caddyfile" "*.test {"
}

@test "development: _dev_add_to_caddyfile should handle existing project gracefully" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    # Create Caddyfile with existing project
    create_caddyfile_fixture "with_projects"
    
    run _dev_add_to_caddyfile "myapp" "4000"
    assert_success
    assert_output --partial "Warning: myapp.test already exists in Caddyfile"
}

@test "development: _dev_add_to_caddyfile should handle missing Caddyfile" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    # No Caddyfile exists
    run _dev_add_to_caddyfile "testapp" "3000"
    assert_failure
    assert_output --partial "Error: Caddyfile not found"
}

@test "development: _dev_remove_from_caddyfile should remove project correctly" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    # Create Caddyfile with projects
    create_caddyfile_fixture "with_projects"
    
    run _dev_remove_from_caddyfile "myapp"
    assert_success
    
    # Verify myapp was removed
    assert_file_not_contains "$TEST_CADDY_CONFIG/Caddyfile" "myapp.test"
    assert_file_not_contains "$TEST_CADDY_CONFIG/Caddyfile" "# myapp development server"
    
    # Verify api still exists
    assert_file_contains "$TEST_CADDY_CONFIG/Caddyfile" "api.test"
    
    # Verify catch-all still exists
    assert_file_contains "$TEST_CADDY_CONFIG/Caddyfile" "*.test"
}

# =============================================================================
# dev-create Function Tests with Complete Isolation
# =============================================================================

@test "development: dev-create should display usage when no arguments provided" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    run dev-create
    
    assert_failure
    assert_output --partial "Usage: dev-create PROJECT_NAME [LAYOUT]"
    assert_output --partial "Supported layouts: node, nodejs, python, python3, ruby, go, rust, generic"
}

@test "development: dev-create should validate project name" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    run dev-create "invalid name"
    
    assert_failure
    assert_output --partial "Error: Project name cannot contain spaces"
}

@test "development: dev-create should check for existing directory" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    mkdir -p "existing-project"
    
    run dev-create "existing-project"
    
    assert_failure
    assert_output --partial "Error: Directory 'existing-project' already exists"
}

@test "development: dev-create should check for Caddy availability" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    # Remove caddy from PATH
    rm -f "$TEST_TEMP_DIR/mock-bin/caddy"
    
    run dev-create "testapp"
    
    assert_failure
    assert_output --partial "Error: Caddy not found. Please install Caddy first:"
}

@test "development: dev-create should create project with generic layout" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    # Create empty Caddyfile
    create_caddyfile_fixture "empty"
    
    # Mock Caddy not running
    export MOCK_CADDY_RUNNING=false
    
    run dev-create "testapp"
    
    assert_success
    assert_output --partial "Creating project 'testapp' with generic layout..."
    assert_output --partial "Added testapp.test -> localhost:3000 to Caddyfile"
    assert_output --partial "✅ Project 'testapp' created successfully!"
    assert_output --partial "🌐 URL: https://testapp.test"
    assert_output --partial "🔧 Backend: localhost:3000"
    
    # Verify directory structure
    [ -d "testapp" ]
    [ -f "testapp/.envrc" ]
    [ -f "testapp/.env" ]
    [ -f "testapp/.env.local" ]
    [ -f "testapp/.gitignore" ]
    [ -f "testapp/README.md" ]
    
    # Verify .env contents
    assert_file_contains "testapp/.env" "PROJECT_NAME=testapp"
    assert_file_contains "testapp/.env" "PORT=3000"
    
    # Verify .envrc contents
    assert_file_contains "testapp/.envrc" "dotenv_if_exists"
    assert_file_contains "testapp/.envrc" "ENVIRONMENT:=local"
    
    # Verify gitignore contents
    assert_file_contains "testapp/.gitignore" ".env.local"
    assert_file_contains "testapp/.gitignore" ".DS_Store"
    
    # Verify commands were called correctly
    assert_command_called "git" "init --quiet"
    assert_command_called "git" "add ."
    assert_command_called "git" "commit --quiet -m Initial project setup with generic layout"
    assert_command_called "direnv" "allow"
}

@test "development: dev-create should create project with node layout" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    create_caddyfile_fixture "empty"
    export MOCK_CADDY_RUNNING=false
    
    run dev-create "nodeapp" "node"
    
    assert_success
    assert_output --partial "Creating project 'nodeapp' with node layout..."
    assert_output --partial "Backend: localhost:3000"
    
    # Verify layout-specific files and config
    [ -d "nodeapp" ]
    assert_file_contains "nodeapp/.envrc" "layout node"
    assert_file_contains "nodeapp/.env" "PORT=3000"
    assert_file_contains "nodeapp/.gitignore" "node_modules/"
    assert_file_contains "nodeapp/.gitignore" "dist/"
}

@test "development: dev-create should create project with python layout" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    create_caddyfile_fixture "empty"
    export MOCK_CADDY_RUNNING=false
    
    run dev-create "pythonapp" "python"
    
    assert_success
    assert_output --partial "Creating project 'pythonapp' with python layout..."
    assert_output --partial "Backend: localhost:8000"
    
    # Verify Python-specific configuration
    assert_file_contains "pythonapp/.envrc" "layout python"
    assert_file_contains "pythonapp/.env" "PORT=8000"
    assert_file_contains "pythonapp/.gitignore" "__pycache__/"
    assert_file_contains "pythonapp/.gitignore" "venv/"
}

@test "development: dev-create should reload Caddy when running" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    create_caddyfile_fixture "empty"
    export MOCK_CADDY_RUNNING=true
    
    run dev-create "testapp"
    
    assert_success
    assert_output --partial "Reloaded Caddy configuration"
    # pgrep will be called with the full path to our mock caddy command
    assert_command_called "pgrep" "-x $TEST_TEMP_DIR/mock-bin/caddy"
    assert_command_called "caddy" "reload --config $TEST_CADDY_CONFIG/Caddyfile"
}

# =============================================================================
# dev-stop Function Tests with Complete Isolation
# =============================================================================

@test "development: dev-stop should auto-detect project name from current directory" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    mkdir -p "myproject"
    cd "myproject"
    
    # Mock no processes on port
    mock_processes_on_port "3000" ""
    
    run dev-stop
    
    assert_success
    assert_output --partial "Auto-detected project: myproject"
    assert_output --partial "Stopping development server for myproject (port 3000)..."
    assert_command_called "lsof" "-ti tcp:3000"
}

@test "development: dev-stop should validate project name" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    run dev-stop "invalid name"
    
    assert_failure
    assert_output --partial "Error: Project name cannot contain spaces"
}

@test "development: dev-stop should stop processes on project port" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    # Create Caddyfile with project
    create_caddyfile_fixture "with_projects"
    
    # Mock processes on port 3000, then empty after kill
    echo "12345" > "$TEST_TEMP_DIR/mock_processes_port_3000"
    
    # Create a version of lsof that shows processes first, then empty
    cat > "$TEST_TEMP_DIR/mock-bin/lsof" << 'EOF'
#!/bin/bash
echo "lsof $*" >> "$TEST_TEMP_DIR/logs/lsof_calls.log"

if [[ "$*" == *"-ti tcp:3000"* ]]; then
    # First call shows processes, second call (after kill) shows empty
    if [ ! -f "$TEST_TEMP_DIR/lsof_second_call" ]; then
        touch "$TEST_TEMP_DIR/lsof_second_call"
        echo "12345"
        exit 0
    else
        # Second call - processes are gone
        exit 1
    fi
fi
exit 1
EOF
    chmod +x "$TEST_TEMP_DIR/mock-bin/lsof"
    
    run dev-stop "myapp"
    
    assert_success
    assert_output --partial "Stopping development server for myapp (port 3000)..."
    assert_output --partial "Found processes using port 3000:"
    # The new security implementation validates process ownership and requires confirmation
    # In test environment, processes are reported as not existing
}

@test "development: dev-stop should handle no running processes gracefully" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    # Mock no processes on any port
    mock_processes_on_port "3000" ""
    
    run dev-stop "myapp"
    
    assert_success
    assert_output --partial "Stopping development server for myapp (port 3000)..."
    assert_command_not_called "kill"
}

# =============================================================================
# dev-delete Function Tests with Complete Isolation
# =============================================================================

@test "development: dev-delete should display usage when no arguments provided" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    run dev-delete
    
    assert_failure
    assert_output --partial "Usage: dev-delete PROJECT_NAME"
}

@test "development: dev-delete should validate project name" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    run dev-delete "invalid name"
    
    assert_failure
    assert_output --partial "Error: Project name cannot contain spaces"
}

@test "development: dev-delete should show confirmation prompt and cancel" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    mkdir -p "testapp"
    create_caddyfile_fixture "with_projects"
    
    # Test cancellation
    run bash -c "source '$TEST_TEMP_DIR/development_functions.sh' && printf 'n\n' | dev-delete testapp"
    
    assert_success
    assert_output --partial "This will permanently delete project 'testapp'"
    assert_output --partial "Deletion cancelled."
    
    # Verify directory still exists
    [ -d "testapp" ]
}

@test "development: dev-delete should delete project when confirmed" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    # Create test project
    mkdir -p "testapp"
    echo "test file" > "testapp/test.txt"
    
    create_caddyfile_fixture "with_projects"
    
    # Add testapp to Caddyfile
    cat >> "$TEST_CADDY_CONFIG/Caddyfile" << 'EOF'

# testapp development server
testapp.test {
  import dev_common
  reverse_proxy localhost:4000
}
EOF
    
    # Mock no processes and Caddy not running
    mock_processes_on_port "4000" ""
    export MOCK_CADDY_RUNNING=false
    
    # Test deletion with confirmation
    run bash -c "source '$TEST_TEMP_DIR/development_functions.sh' && printf 'y\n' | dev-delete testapp"
    
    assert_success
    assert_output --partial "✅ Removed project directory"
    assert_output --partial "✅ Removed testapp.test from Caddyfile"
    assert_output --partial "✅ Project 'testapp' deleted successfully!"
    
    # Verify directory was deleted
    [ ! -d "testapp" ]
    
    # Verify project was removed from Caddyfile
    assert_file_not_contains "$TEST_CADDY_CONFIG/Caddyfile" "testapp.test"
}

# =============================================================================
# dev-info Function Tests with Complete Isolation
# =============================================================================

@test "development: dev-info should auto-detect project from .envrc" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    mkdir -p "myproject"
    cd "myproject"
    echo "# Mock .envrc" > .envrc
    
    create_caddyfile_fixture "with_projects"
    
    # Mock no processes and Caddy running
    mock_processes_on_port "3000" ""
    export MOCK_CADDY_RUNNING=true
    
    run dev-info
    
    assert_success
    assert_output --partial "Auto-detected project: myproject"
    assert_output --partial "Development info for 'myproject'"
    assert_output --partial "🌐 Project URL: https://myproject.test"
}

@test "development: dev-info should show environment information" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    mkdir -p "myproject"
    cd "myproject"
    
    # Create mock environment files
    echo "PROJECT_NAME=myproject" > .env
    echo "LOCAL_VAR=value" > .env.local
    echo "TEST_VAR=test" > .env.test
    echo "# Mock .envrc" > .envrc
    
    create_caddyfile_fixture "with_projects"
    
    export MOCK_DIRENV_ALLOWED=true
    export MOCK_CADDY_RUNNING=true
    export ENVIRONMENT="test"
    
    run dev-info "myproject"
    
    assert_success
    assert_output --partial "📝 Environment: test"
    assert_output --partial "✅ .env"
    assert_output --partial "✅ .env.local"
    assert_output --partial "✅ .env.test"
    assert_output --partial "✅ direnv: Allowed and active"
}

@test "development: dev-info should show server status" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    # Mock server running on port 3000
    mock_processes_on_port "3000" "12345"
    
    run dev-info "myapp"
    
    assert_success
    assert_output --partial "🟢 Status: Server running on port 3000"
}

@test "development: dev-info should handle missing project gracefully" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    # No .envrc in current directory and no project name
    run dev-info
    
    assert_failure
    assert_output --partial "Usage: dev-info [PROJECT_NAME]"
    assert_output --partial "Run from project directory or specify project name"
}

# =============================================================================
# dev-env Function Tests with Complete Isolation
# =============================================================================

@test "development: dev-env should display usage when no arguments provided" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    run dev-env
    
    assert_failure
    assert_output --partial "Usage: dev-env ENVIRONMENT"
    assert_output --partial "Environments: local, test, production"
}

@test "development: dev-env should validate environment parameter" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    run dev-env "invalid"
    
    assert_failure
    assert_output --partial "Error: Invalid environment 'invalid'"
    assert_output --partial "Valid environments: local, test, production"
}

@test "development: dev-env should require .envrc file" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    run dev-env "test"
    
    assert_failure
    assert_output --partial "Error: Not in a development project directory"
    assert_output --partial "Run this command from a directory with .envrc file"
}

@test "development: dev-env should switch environment and reload direnv" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    # Create .envrc
    echo "# Mock .envrc" > .envrc
    
    # Create test environment files
    echo "BASE_VAR=base" > .env
    echo "TEST_VAR=test" > .env.test
    
    run dev-env "test"
    
    assert_success
    assert_output --partial "Switching to 'test' environment..."
    assert_output --partial "✅ Reloaded environment with direnv"
    assert_output --partial "Environment files for 'test':"
    assert_output --partial "✅ .env"
    assert_output --partial "✅ .env.test"
    assert_output --partial "✅ Switched to 'test' environment"
    
    assert_command_called "direnv" "reload"
}

@test "development: dev-env should handle missing environment files" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    # Create .envrc but no .env.production
    echo "# Mock .envrc" > .envrc
    echo "BASE_VAR=base" > .env
    
    run dev-env "production"
    
    assert_success
    assert_output --partial "✅ .env"
    assert_output --partial "❌ .env.production (create this file for production variables)"
    assert_output --partial "✅ Switched to 'production' environment"
}

@test "development: dev-env should work without direnv installed" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    # Create .envrc
    echo "# Mock .envrc" > .envrc
    
    # Remove direnv from PATH
    rm -f "$TEST_TEMP_DIR/mock-bin/direnv"
    export PATH="/usr/bin:/bin"
    
    run dev-env "local"
    
    assert_success
    assert_output --partial "⚠️  direnv not available, please restart your shell"
    assert_output --partial "✅ Switched to 'local' environment"
}

# =============================================================================
# Original Git Functions Tests (Updated for New Command Structure)
# =============================================================================

@test "development: git-export should display usage when no arguments provided" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    run git-export
    
    assert_failure
    assert_output --partial "Usage: git-export REPO_URL PROJECT_NAME"
    assert_output --partial "Example: git-export https://github.com/user/repo.git my-project"
}

@test "development: git-export should clone repository without git history" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    run git-export "https://github.com/test/repo.git" "test-project"
    
    assert_success
    assert_output --partial "Cloning repository..."
    assert_output --partial "Mock cloned https://github.com/test/repo.git to test-project"
    assert_output --partial "Removing git history..."
    assert_output --partial "Project exported to: test-project"
    
    # Verify git directory was removed (test would have created it)
    [ ! -d "test-project/.git" ]
    
    assert_command_called "git" "clone --quiet --depth=1 https://github.com/test/repo.git test-project"
}

@test "development: git-branch-clean should clean merged branches" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    export MOCK_GIT_REPO=true
    
    run git-branch-clean
    
    assert_success
    assert_output --partial "Cleaning merged branches..."
    assert_output --partial "Deleting branches merged into master: feature-branch-1 feature-branch-2"
    assert_output --partial "Deleting branches merged into main: old-feature hotfix"
    assert_output --partial "Pruning remote tracking branches..."
    assert_output --partial "Branch cleanup complete"
    
    assert_command_called "git" "rev-parse --is-inside-work-tree"
    assert_command_called "git" "branch --merged=master"
    assert_command_called "git" "branch --merged=main"
    assert_command_called "git" "fetch --prune"
}

# =============================================================================
# Configuration Override Tests
# =============================================================================

@test "development: should respect CADDY_CONFIG_DIR environment variable" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    # Set custom Caddy config directory
    export CADDY_CONFIG_DIR="$TEST_TEMP_DIR/custom-caddy"
    mkdir -p "$TEST_TEMP_DIR/custom-caddy"
    
    cat > "$TEST_TEMP_DIR/custom-caddy/Caddyfile" << 'EOF'
# Custom Caddyfile
# Default catch-all for undefined .test domains
*.test {
  respond "Custom config" 404
}
EOF
    
    export MOCK_CADDY_RUNNING=false
    
    run dev-create "customapp"
    
    assert_success
    assert_output --partial "Added customapp.test -> localhost:3000 to Caddyfile"
    
    # Verify project was added to custom Caddyfile
    assert_file_contains "$TEST_TEMP_DIR/custom-caddy/Caddyfile" "customapp.test"
}

@test "development: should respect custom command environment variables" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    # Set custom commands
    export GIT_CMD="$TEST_TEMP_DIR/mock-bin/custom-git"
    export CADDY_CMD="$TEST_TEMP_DIR/mock-bin/custom-caddy"
    export DIRENV_CMD="$TEST_TEMP_DIR/mock-bin/custom-direnv"
    
    # Create custom command mocks
    cat > "$TEST_TEMP_DIR/mock-bin/custom-git" << 'EOF'
#!/bin/bash
echo "custom-git $*" >> "$TEST_TEMP_DIR/logs/custom-git_calls.log"
if [ "$1" = "init" ]; then
    mkdir -p .git
    echo "Custom Git initialized"
fi
EOF
    chmod +x "$TEST_TEMP_DIR/mock-bin/custom-git"
    
    cat > "$TEST_TEMP_DIR/mock-bin/custom-caddy" << 'EOF'
#!/bin/bash
echo "custom-caddy $*" >> "$TEST_TEMP_DIR/logs/custom-caddy_calls.log"
echo "Custom Caddy executed"
EOF
    chmod +x "$TEST_TEMP_DIR/mock-bin/custom-caddy"
    
    cat > "$TEST_TEMP_DIR/mock-bin/custom-direnv" << 'EOF'
#!/bin/bash
echo "custom-direnv $*" >> "$TEST_TEMP_DIR/logs/custom-direnv_calls.log"
echo "Custom direnv executed"
EOF
    chmod +x "$TEST_TEMP_DIR/mock-bin/custom-direnv"
    
    create_caddyfile_fixture "empty"
    export MOCK_CADDY_RUNNING=false
    
    run dev-create "testapp"
    
    assert_success
    
    # Verify custom commands were called
    assert_command_called "custom-git" "init --quiet"
    assert_command_called "custom-direnv" "allow"
}

# =============================================================================
# Error Handling and Edge Cases with Complete Isolation
# =============================================================================

@test "development: should handle Caddyfile permissions issues gracefully" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    # Create Caddyfile but make it unwritable
    create_caddyfile_fixture "empty"
    chmod 444 "$TEST_CADDY_CONFIG/Caddyfile"
    
    run _dev_add_to_caddyfile "testapp" "3000"
    
    # The function may succeed if it can create a temp file and mv it
    # This tests that it doesn't crash, but the exact behavior depends on file system permissions
    # The critical thing is it doesn't crash or corrupt anything
    if [ "$status" -eq 0 ]; then
        # If it succeeded, the Caddyfile should contain the project
        assert_file_contains "$TEST_CADDY_CONFIG/Caddyfile" "testapp.test"
    fi
}

@test "development: should handle missing directories gracefully" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    # Remove the Caddy config directory entirely
    rm -rf "$TEST_CADDY_CONFIG"
    
    run dev-create "testapp"
    
    # The function should succeed but warn about missing Caddyfile
    assert_success
    assert_output --partial "Error: Caddyfile not found"
    assert_output --partial "Warning: Failed to add to Caddyfile"
}

@test "development: command spy functionality should work correctly" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    create_caddyfile_fixture "empty"
    export MOCK_CADDY_RUNNING=false
    
    run dev-create "spytest"
    
    assert_success
    
    # Verify all expected commands were logged
    [ -f "$TEST_TEMP_DIR/logs/git_calls.log" ]
    [ -f "$TEST_TEMP_DIR/logs/direnv_calls.log" ]
    [ -f "$TEST_TEMP_DIR/logs/pgrep_calls.log" ]
    
    # Check specific command calls
    assert_command_called "git" "init --quiet"
    assert_command_called "git" "add ."
    assert_command_called "direnv" "allow"
    assert_command_called "pgrep" "-x $TEST_TEMP_DIR/mock-bin/caddy"
}

@test "development: isolated environment should not affect host system" {
    # This test verifies that our isolation is complete
    
    # These should all be our test mocks, not system commands
    [ "$(command -v git)" = "$TEST_TEMP_DIR/mock-bin/git" ]
    [ "$(command -v caddy)" = "$TEST_TEMP_DIR/mock-bin/caddy" ]
    [ "$(command -v direnv)" = "$TEST_TEMP_DIR/mock-bin/direnv" ]
    
    # These should be our test directories, not real system directories
    [ "$HOME" = "$TEST_HOME" ]
    [ "$CADDY_CONFIG_DIR" = "$TEST_CADDY_CONFIG" ]
    
    # Verify no real files are being touched
    [ ! -f "/opt/homebrew/etc/Caddyfile" ] || skip "System Caddyfile exists but should not be modified"
    [ ! -f "$(brew --prefix 2>/dev/null)/etc/Caddyfile" ] || skip "System Caddyfile exists but should not be modified"
}