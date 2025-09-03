#!/usr/bin/env bats

# Test Suite for dot_functions.d/development.tmpl
# Tests development workflow and git utility functions

# Load helpers
load "../../helpers/helper"
load "../../helpers/fixtures"

setup() {
    test_setup
    
    # Copy the function file to test environment
    cp "$PROJECT_ROOT/dot_functions.d/development.tmpl" "$TEST_TEMP_DIR/development_functions.sh"
    
    # Set up completely isolated mock environment
    setup_isolated_mocks
    
    # Create isolated test project structure
    mkdir -p "$TEST_TEMP_DIR/test-projects"
    cd "$TEST_TEMP_DIR/test-projects"
}

teardown() {
    test_teardown
}

# Helper to set up completely isolated mock environment
setup_isolated_mocks() {
    # Create isolated mock bin directory
    mkdir -p "$TEST_TEMP_DIR/mock-bin"
    export PATH="$TEST_TEMP_DIR/mock-bin:$PATH"
    
    # Mock git command that never touches real git or system
    cat > "$TEST_TEMP_DIR/mock-bin/git" << 'EOF'
#!/bin/bash
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
        mkdir -p .git
        echo "Initialized empty Git repository in $PWD/.git/"
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
    
    # Create isolated mock commands that never call system tools
    create_isolated_mock_script "yarn" 0 "Mock yarn output"
    create_isolated_mock_script "npm" 0 "Mock npm output"
    create_isolated_mock_script "cargo" 0 "Mock cargo output" 
    create_isolated_mock_script "go" 0 "Mock go output"
    create_isolated_mock_script "python3" 0 "Mock python3 output"
    create_isolated_mock_script "jq" 0 "Mock jq output"
    create_isolated_mock_script "tree" 0 "Mock tree output"
}

# Helper to create isolated mock scripts
create_isolated_mock_script() {
    local cmd="$1"
    local exit_code="$2"
    local output="$3"
    
    cat > "$TEST_TEMP_DIR/mock-bin/$cmd" << EOF
#!/bin/bash
echo "$output"
exit $exit_code
EOF
    chmod +x "$TEST_TEMP_DIR/mock-bin/$cmd"
}

# =============================================================================
# git-export Function Tests
# =============================================================================

@test "development: git-export should display usage when no arguments provided" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    run git-export
    
    assert_failure
    assert_output --partial "Usage: git-export REPO_URL PROJECT_NAME"
    assert_output --partial "Example: git-export https://github.com/user/repo.git my-project"
}

@test "development: git-export should display usage when only one argument provided" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    run git-export "https://github.com/test/repo.git"
    
    assert_failure
    assert_output --partial "Usage: git-export REPO_URL PROJECT_NAME"
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
}

@test "development: git-export should handle existing directory error" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    mkdir -p "existing-project"
    
    run git-export "https://github.com/test/repo.git" "existing-project"
    
    assert_failure
    assert_output --partial "Error: Directory 'existing-project' already exists"
}

@test "development: git-export should handle clone failure" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    run git-export "https://github.com/nonexistent/repo.git" "test-project"
    
    assert_failure
    assert_output --partial "Cloning repository..."
    assert_output --partial "Error: Failed to clone repository"
}

# =============================================================================
# git-branch-clean Function Tests  
# =============================================================================

@test "development: git-branch-clean should verify it's in a git repository" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    export MOCK_GIT_REPO=false
    
    run git-branch-clean
    
    assert_failure
    assert_output --partial "Error: Not in a git repository"
}

@test "development: git-branch-clean should clean merged branches from master and main" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    export MOCK_GIT_REPO=true
    
    run git-branch-clean
    
    assert_success
    assert_output --partial "Cleaning merged branches..."
    assert_output --partial "Deleting branches merged into master: feature-branch-1 feature-branch-2"
    assert_output --partial "Deleting branches merged into main: old-feature hotfix"
    assert_output --partial "Pruning remote tracking branches..."
    assert_output --partial "Branch cleanup complete"
}

@test "development: git-branch-clean should handle no merged branches" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    # Override git mock to return no merged branches
    cat > "$TEST_TEMP_DIR/mock-bin/git" << 'EOF'
#!/bin/bash
case "$1" in
    "rev-parse")
        if [ "$2" = "--is-inside-work-tree" ]; then
            echo "true"
            exit 0
        fi
        ;;
    "branch")
        case "$2" in
            "--merged=master"|"--merged=main")
                # Return empty (no merged branches)
                exit 0
                ;;
        esac
        ;;
    "fetch")
        if [ "$2" = "--prune" ]; then
            echo "Mock: pruning remote tracking branches"
        fi
        ;;
    *)
        echo "Mock git: $*"
        ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/mock-bin/git"
    
    export MOCK_GIT_REPO=true
    
    run git-branch-clean
    
    assert_success
    assert_output --partial "Cleaning merged branches..."
    assert_output --partial "Pruning remote tracking branches..."
    assert_output --partial "Branch cleanup complete"
}

# =============================================================================
# git-current-branch Function Tests
# =============================================================================

@test "development: git-current-branch should verify it's in a git repository" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    export MOCK_GIT_REPO=false
    
    run git-current-branch
    
    assert_failure
    assert_output --partial "Error: Not in a git repository"
}

@test "development: git-current-branch should return current branch name" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    export MOCK_GIT_REPO=true
    export MOCK_GIT_BRANCH="feature/test-branch"
    
    run git-current-branch
    
    assert_success
    assert_output "feature/test-branch"
}

# =============================================================================
# git-root Function Tests
# =============================================================================

@test "development: git-root should verify it's in a git repository" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    export MOCK_GIT_REPO=false
    
    run git-root
    
    assert_failure
    assert_output --partial "Error: Not in a git repository"
}

@test "development: git-root should navigate to repository root" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    export MOCK_GIT_REPO=true
    # Use the test temp directory as the mock root (it exists)
    export MOCK_GIT_ROOT="$TEST_TEMP_DIR/repo-root"
    mkdir -p "$MOCK_GIT_ROOT"
    
    # Create subdirectory structure
    mkdir -p subdir/deep
    cd subdir/deep
    
    # Source functions in the subdirectory context
    source "$TEST_TEMP_DIR/development_functions.sh"
    git-root
    
    # Should have changed to the git root directory
    [ "$PWD" = "$MOCK_GIT_ROOT" ]
}

# =============================================================================
# git-uncommitted Function Tests
# =============================================================================

@test "development: git-uncommitted should verify it's in a git repository" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    export MOCK_GIT_REPO=false
    
    run git-uncommitted
    
    assert_failure
    assert_output --partial "Error: Not in a git repository"
}

@test "development: git-uncommitted should show uncommitted changes" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    export MOCK_GIT_REPO=true
    export MOCK_GIT_STATUS=" M file1.txt
?? file2.txt
 D file3.txt"
    
    run git-uncommitted
    
    assert_success
    assert_output --partial "=== Uncommitted Changes ==="
    assert_output --partial "[M] file1.txt"
    assert_output --partial "[??] file2.txt"
    assert_output --partial "[D] file3.txt"
    assert_output --partial "=== Diff Summary ==="
    assert_output --partial "Mock diff stats"
}

@test "development: git-uncommitted should handle clean working directory" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    export MOCK_GIT_REPO=true
    export MOCK_GIT_STATUS=""
    
    run git-uncommitted
    
    assert_success
    assert_output --partial "=== Uncommitted Changes ==="
    assert_output --partial "No uncommitted changes found."
}

# =============================================================================
# git-recent-branches Function Tests
# =============================================================================

@test "development: git-recent-branches should verify it's in a git repository" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    export MOCK_GIT_REPO=false
    
    run git-recent-branches
    
    assert_failure
    assert_output --partial "Error: Not in a git repository"
}

@test "development: git-recent-branches should show default 10 recent branches" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    export MOCK_GIT_REPO=true
    
    run git-recent-branches
    
    assert_success
    assert_output --partial "Recently used branches:"
    assert_output --partial "main - 2 hours ago - Latest commit"
    assert_output --partial "feature/test - 1 day ago - Test feature"
    assert_output --partial "hotfix/urgent - 3 days ago - Urgent fix"
}

@test "development: git-recent-branches should accept custom count parameter" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    export MOCK_GIT_REPO=true
    
    run git-recent-branches 5
    
    assert_success
    assert_output --partial "Recently used branches:"
}

@test "development: git-recent-branches should validate count parameter" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    export MOCK_GIT_REPO=true
    
    run git-recent-branches "not-a-number"
    
    assert_failure
    assert_output --partial "Error: COUNT must be a positive integer"
}

# =============================================================================
# git-file-history Function Tests
# =============================================================================

@test "development: git-file-history should display usage when no arguments provided" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    run git-file-history
    
    assert_failure
    assert_output --partial "Usage: git-file-history FILE_PATH"
    assert_output --partial "Example: git-file-history src/main.js"
}

@test "development: git-file-history should verify it's in a git repository" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    export MOCK_GIT_REPO=false
    
    run git-file-history "test.txt"
    
    assert_failure
    assert_output --partial "Error: Not in a git repository"
}

@test "development: git-file-history should show file history for existing file" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    export MOCK_GIT_REPO=true
    
    # Create a test file
    echo "test content" > test-file.txt
    
    run git-file-history "test-file.txt"
    
    assert_success
    assert_output --partial "Git history for: test-file.txt"
    assert_output --partial "Mock git log output for file: test-file.txt"
}

@test "development: git-file-history should handle non-existent file" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    export MOCK_GIT_REPO=true
    
    # Mock git ls-files to return error for non-existent file
    cat > "$TEST_TEMP_DIR/mock-bin/git" << 'EOF'
#!/bin/bash
case "$1" in
    "rev-parse")
        if [ "$2" = "--is-inside-work-tree" ]; then
            echo "true"
            exit 0
        fi
        ;;
    "ls-files")
        if [ "$2" = "--error-unmatch" ]; then
            exit 1
        fi
        ;;
    *)
        echo "Mock git: $*"
        ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/mock-bin/git"
    
    run git-file-history "non-existent-file.txt"
    
    assert_failure
    assert_output --partial "Error: File 'non-existent-file.txt' not found in git repository"
}

# =============================================================================
# project-init Function Tests  
# =============================================================================

@test "development: project-init should display usage when no arguments provided" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    run project-init
    
    assert_failure
    assert_output --partial "Usage: project-init PROJECT_NAME [LANGUAGE]"
    assert_output --partial "Supported languages: javascript, python, rust, go, generic (default)"
}

@test "development: project-init should create generic project structure" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    run project-init "test-project"
    
    assert_success
    assert_output --partial "Project 'test-project' initialized with generic template"
    
    # Verify directory structure was created
    [ -d "test-project" ]
    [ -f "test-project/README.md" ]
    [ -f "test-project/.gitignore" ]
    
    # Verify README content
    grep -q "# test-project" "test-project/README.md"
    
    # Verify gitignore content
    grep -q "node_modules/" "test-project/.gitignore"
    grep -q ".env" "test-project/.gitignore"
}

@test "development: project-init should create JavaScript project structure" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    run project-init "js-project" "javascript"
    
    assert_success
    assert_output --partial "Project 'js-project' initialized with javascript template"
    
    # Verify JavaScript-specific files
    [ -f "js-project/package.json" ]
    [ -f "js-project/index.js" ]
    
    # Verify JavaScript-specific gitignore entries
    grep -q "dist/" "js-project/.gitignore"
    grep -q "coverage/" "js-project/.gitignore"
}

@test "development: project-init should create Python project structure" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    run project-init "py-project" "python"
    
    assert_success
    assert_output --partial "Project 'py-project' initialized with python template"
    
    # Verify Python-specific files
    [ -f "py-project/main.py" ]
    [ -f "py-project/requirements.txt" ]
    
    # Verify Python-specific gitignore entries
    grep -q "__pycache__/" "py-project/.gitignore"
    grep -q "*.pyc" "py-project/.gitignore"
    grep -q "venv/" "py-project/.gitignore"
}

@test "development: project-init should handle existing directory error" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    mkdir -p "existing-project"
    
    run project-init "existing-project"
    
    assert_failure
    assert_output --partial "Error: Directory 'existing-project' already exists"
}

# =============================================================================
# dev-server Function Tests
# =============================================================================

@test "development: dev-server should validate port parameter" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    run dev-server "not-a-port"
    
    assert_failure
    assert_output --partial "Error: Port must be a number between 1 and 65535"
}

@test "development: dev-server should validate port range" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    run dev-server "70000"
    
    assert_failure
    assert_output --partial "Error: Port must be a number between 1 and 65535"
}

@test "development: dev-server should detect Node.js project and use npm" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    # Create package.json to simulate Node.js project
    echo '{"name": "test", "scripts": {"start": "node index.js"}}' > package.json
    
    run dev-server
    
    assert_success
    assert_output --partial "Detected Node.js project..."
    assert_output --partial "Starting with npm..."
    assert_output --partial "Mock npm output"
}

@test "development: dev-server should detect Node.js project and prefer yarn when yarn.lock exists" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    # Create package.json and yarn.lock
    echo '{"name": "test"}' > package.json
    touch yarn.lock
    
    run dev-server
    
    assert_success
    assert_output --partial "Detected Node.js project..."
    assert_output --partial "Starting with yarn..."
    assert_output --partial "Mock yarn output"
}

@test "development: dev-server should detect Rust project" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    # Create Cargo.toml to simulate Rust project
    echo '[package]
name = "test"
version = "0.1.0"' > Cargo.toml
    
    run dev-server
    
    assert_success
    assert_output --partial "Detected Rust project..."
    assert_output --partial "Starting with cargo..."
    assert_output --partial "Mock cargo output"
}

@test "development: dev-server should detect Go project" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    # Create go.mod to simulate Go project
    echo 'module test' > go.mod
    
    run dev-server
    
    assert_success
    assert_output --partial "Detected Go project..."
    assert_output --partial "Starting Go application..."
    assert_output --partial "Mock go output"
}

@test "development: dev-server should detect Python project" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    # Create requirements.txt to simulate Python project
    echo 'flask==2.0.0' > requirements.txt
    
    run dev-server 8080
    
    assert_success
    assert_output --partial "Detected Python project..."
    assert_output --partial "Starting Python development server on port 8080..."
}

@test "development: dev-server should fall back to generic HTTP server" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    run dev-server 9000
    
    assert_success
    assert_output --partial "No specific project type detected."
    assert_output --partial "Starting generic HTTP server on port 9000..."
}

# =============================================================================
# code-stats Function Tests
# =============================================================================

@test "development: code-stats should validate directory parameter" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    run code-stats "/non/existent/directory"
    
    assert_failure
    assert_output --partial "Error: '/non/existent/directory' is not a valid directory"
}

@test "development: code-stats should analyze current directory by default" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    # Create some test files
    mkdir -p src test
    touch src/main.js src/utils.js test/test.js README.md
    
    run code-stats
    
    assert_success
    assert_output --partial "Code statistics for:"
    assert_output --partial "Files by extension:"
    assert_output --partial "Total lines of code:"
    assert_output --partial "Directory structure:"
}

@test "development: code-stats should analyze specified directory" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    mkdir -p target-dir
    touch target-dir/file1.py target-dir/file2.py
    
    run code-stats "target-dir"
    
    assert_success
    assert_output --partial "Code statistics for:"
    assert_output --partial "target-dir"
}

@test "development: code-stats should use tree command when available" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    # Mock tree command to be available
    cat > "$MOCK_BREW_PREFIX/bin/tree" << 'EOF'
#!/bin/bash
echo "Mock tree output"
echo "├── src/"
echo "│   └── main.js"
echo "└── README.md"
EOF
    chmod +x "$MOCK_BREW_PREFIX/bin/tree"
    
    run code-stats
    
    assert_success
    assert_output --partial "Directory structure:"
    assert_output --partial "Mock tree output"
}

@test "development: code-stats should fall back to find when tree not available" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    # Ensure tree is not available
    rm -f "$MOCK_BREW_PREFIX/bin/tree"
    
    mkdir -p test-structure/subdir
    
    run code-stats
    
    assert_success
    assert_output --partial "Directory structure:"
    # Should show directories found with find command
}

# =============================================================================
# Error Handling and Edge Cases
# =============================================================================

@test "development: functions should handle git repository detection consistently" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    export MOCK_GIT_REPO=false
    
    # Test multiple git functions with consistent error handling
    run git-current-branch
    assert_failure
    assert_output --partial "Error: Not in a git repository"
    
    run git-root
    assert_failure
    assert_output --partial "Error: Not in a git repository"
    
    run git-uncommitted  
    assert_failure
    assert_output --partial "Error: Not in a git repository"
}

@test "development: project-init should handle different language variations" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    # Test language aliases
    run project-init "js-test" "js"
    assert_success
    assert_output --partial "js template"
    
    # Clean up 
    rm -rf "js-test"
    
    run project-init "py-test" "py"
    assert_success
    assert_output --partial "python template"
}

@test "development: functions should handle missing command dependencies gracefully" {
    source "$TEST_TEMP_DIR/development_functions.sh"
    
    # Remove commands from isolated mock PATH
    rm -f "$TEST_TEMP_DIR/mock-bin/cargo"
    
    # Should detect Rust project but handle missing cargo gracefully
    echo '[package]' > Cargo.toml
    
    run dev-server
    assert_success
    assert_output --partial "Error: cargo not found"
}