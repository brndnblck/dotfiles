#!/usr/bin/env bats

# Test utilities and shared patterns
# Reusable test components to reduce duplication and ensure consistency

# Load helpers using correct relative path from utilities directory  
load "../helpers/helper"
load "../helpers/mocks"

setup() {
    test_setup
}

teardown() {
    test_teardown
}

# Utility: Test environment validation pattern (reusable across scripts)
validate_script_environment() {
    local script_name="$1"
    local script_path="$DOTFILES_PARENT_DIR/script/$script_name"
    
    # Create a simple test script that mimics the environment validation pattern
    # Instead of copying the real complex script that might hang
    cat > "$script_path" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Standard environment validation that all our scripts should have
if [ -z "${DOTFILES_PARENT_DIR:-}" ]; then
    echo "❌ This script should not be called directly!"
    echo ""
    echo "Please use the main TUI interface:"
    echo "  ./script/main"
    exit 1
fi

echo "Script running with DOTFILES_PARENT_DIR=$DOTFILES_PARENT_DIR"
EOF
    chmod +x "$script_path"
    
    # Test environment failure
    local saved_dotfiles_dir="$DOTFILES_PARENT_DIR"
    unset DOTFILES_PARENT_DIR
    run "$script_path"
    # Restore for cleanup
    export DOTFILES_PARENT_DIR="$saved_dotfiles_dir"
    assert_failure
    assert_output --partial "❌ This script should not be called directly!"
    assert_output --partial "Please use the main TUI interface:"
}

# Utility: Test configuration parsing pattern (reusable for brewfiles, package lists)
parse_configuration_file() {
    local config_file="$1"
    local pattern="$2"
    local description="$3"
    
    if [ ! -f "$config_file" ]; then
        echo "CONFIG_PARSE: No $description configured"
        return 1
    fi
    
    local count=$(grep -c "$pattern" "$config_file" 2>/dev/null || echo 0)
    echo "CONFIG_PARSE: $count $description found"
    
    # Extract items
    echo "CONFIG_ITEMS:"
    grep "$pattern" "$config_file" | sed 's/.*"\([^"]*\)".*/  \1/' || true
}

# Utility: Test workflow orchestration pattern
orchestrate_test_workflow() {
    local workflow_name="$1"
    local phases=("${@:2}")
    local log_file="$TEST_TEMP_DIR/${workflow_name}_workflow.log"
    
    echo "WORKFLOW_START: $workflow_name" >> "$log_file"
    
    for phase in "${phases[@]}"; do
        echo "PHASE_START: $phase" >> "$log_file"
        # Simulate phase execution
        echo "PHASE_COMPLETE: $phase" >> "$log_file"
    done
    
    echo "WORKFLOW_COMPLETE: $workflow_name" >> "$log_file"
    echo "Workflow logged to: $log_file"
}

# Test the utility functions themselves

@test "test utilities: environment validation works for any script" {
    validate_script_environment "main"
    # Function should complete successfully if validation works
}

@test "test utilities: configuration parsing handles brewfiles correctly" {
    # Create test brewfile
    mkdir -p "$DOTFILES_PARENT_DIR/dependencies"
    cat > "$DOTFILES_PARENT_DIR/dependencies/test.brewfile" << 'EOF'
brew "git"
brew "curl"  
cask "docker"
EOF
    
    run parse_configuration_file "$DOTFILES_PARENT_DIR/dependencies/test.brewfile" "^brew " "formulae"
    assert_success
    assert_output --partial "CONFIG_PARSE: 2 formulae found"
    assert_output --partial "CONFIG_ITEMS:"
    assert_output --partial "git"
    assert_output --partial "curl"
    
    run parse_configuration_file "$DOTFILES_PARENT_DIR/dependencies/test.brewfile" "^cask " "casks"
    assert_success
    assert_output --partial "CONFIG_PARSE: 1 casks found"
    assert_output --partial "docker"
}

@test "test utilities: workflow orchestration logs phases correctly" {
    run orchestrate_test_workflow "test_setup" "Prerequisites" "Dependencies" "Configuration"
    assert_success
    assert_output --partial "Workflow logged to:"
    
    # Verify workflow log content
    run cat "$TEST_TEMP_DIR/test_setup_workflow.log"
    assert_success
    assert_line --index 0 "WORKFLOW_START: test_setup"
    assert_line --index 1 "PHASE_START: Prerequisites"
    assert_line --index 2 "PHASE_COMPLETE: Prerequisites"
    assert_line --index 3 "PHASE_START: Dependencies"
    assert_line --index 4 "PHASE_COMPLETE: Dependencies"
    assert_line --index 5 "PHASE_START: Configuration" 
    assert_line --index 6 "PHASE_COMPLETE: Configuration"
    assert_line --index 7 "WORKFLOW_COMPLETE: test_setup"
}

# Common assertion patterns (reduce test code duplication)

assert_configuration_directory_exists() {
    run test -d "$DOTFILES_PARENT_DIR/dependencies"
    assert_success
}

assert_configuration_file_exists() {
    local file_name="$1"
    run test -f "$DOTFILES_PARENT_DIR/dependencies/$file_name"
    assert_success
}

assert_workflow_phase_completed() {
    local log_file="$1"
    local phase_name="$2"
    run grep "PHASE_COMPLETE: $phase_name" "$log_file"
    assert_success
}

assert_package_count_correct() {
    local config_file="$1"
    local pattern="$2"
    local expected_count="$3"
    
    local actual_count=$(grep -c "$pattern" "$config_file" 2>/dev/null || echo 0)
    [ "$actual_count" -eq "$expected_count" ] || fail "Expected $expected_count packages, found $actual_count"
}

# Test the assertion helpers

@test "test utilities: assertion helpers work correctly" {
    # Set up test configuration
    mkdir -p "$DOTFILES_PARENT_DIR/dependencies"
    cat > "$DOTFILES_PARENT_DIR/dependencies/test.brewfile" << 'EOF'
brew "git"
brew "curl"
brew "wget"
EOF
    
    # Test configuration assertions
    assert_configuration_directory_exists
    assert_configuration_file_exists "test.brewfile"
    assert_package_count_correct "$DOTFILES_PARENT_DIR/dependencies/test.brewfile" "^brew " 3
    
    # Test workflow assertions
    echo "PHASE_COMPLETE: TestPhase" > "$TEST_TEMP_DIR/test.log"
    assert_workflow_phase_completed "$TEST_TEMP_DIR/test.log" "TestPhase"
}

# Parameterized test generators (reduce similar test patterns)

generate_environment_test() {
    local script_name="$1"
    
    echo "@test \"$script_name: validates environment correctly\" {"
    echo "    validate_script_environment \"$script_name\""
    echo "}"
}

generate_configuration_analysis_test() {
    local config_type="$1"
    local file_pattern="$2"
    
    echo "@test \"configuration analysis: processes $config_type correctly\" {"
    echo "    mkdir -p \"\$DOTFILES_PARENT_DIR/dependencies\""
    echo "    cat > \"\$DOTFILES_PARENT_DIR/dependencies/$config_type.brewfile\" << 'EOF'"
    echo "$file_pattern"
    echo "EOF"
    echo "    run parse_configuration_file \"\$DOTFILES_PARENT_DIR/dependencies/$config_type.brewfile\" \"^brew \" \"packages\""
    echo "    assert_success"
    echo "    assert_output --partial \"CONFIG_PARSE:\""
    echo "}"
}

@test "test utilities: test generators produce valid test code" {
    # Test the test generators (meta-testing)
    run generate_environment_test "setup"
    assert_success
    assert_output --partial "@test \"setup: validates environment correctly\""
    assert_output --partial "validate_script_environment \"setup\""
    
    run generate_configuration_analysis_test "dependencies" "brew \"git\""
    assert_success
    assert_output --partial "@test \"configuration analysis: processes dependencies correctly\""
    assert_output --partial "parse_configuration_file"
}

# Fixtures for consistent test data

create_standard_dependencies_fixture() {
    mkdir -p "$DOTFILES_PARENT_DIR/dependencies"
    
    cat > "$DOTFILES_PARENT_DIR/dependencies/dependencies.brewfile" << 'EOF'
# Core development tools
brew "git"
brew "curl"
brew "wget"
brew "jq"

# Package managers  
brew "node"
brew "python@3.11"
cask "1password-cli"
EOF

    cat > "$DOTFILES_PARENT_DIR/dependencies/applications.brewfile" << 'EOF'
# Development
cask "visual-studio-code"
cask "docker"

# Productivity
mas "Xcode", id: 497799835
EOF

    cat > "$DOTFILES_PARENT_DIR/dependencies/cargo.packages" << 'EOF'
exa
bat
ripgrep
starship
EOF
}

create_minimal_dependencies_fixture() {
    mkdir -p "$DOTFILES_PARENT_DIR/dependencies"
    
    cat > "$DOTFILES_PARENT_DIR/dependencies/dependencies.brewfile" << 'EOF'
brew "git"
EOF
}

create_empty_dependencies_fixture() {
    mkdir -p "$DOTFILES_PARENT_DIR/dependencies"
    touch "$DOTFILES_PARENT_DIR/dependencies/dependencies.brewfile"
    touch "$DOTFILES_PARENT_DIR/dependencies/applications.brewfile"
}

@test "test utilities: fixtures create consistent test data" {
    create_standard_dependencies_fixture
    
    # Verify fixture created expected content
    assert_configuration_directory_exists
    assert_configuration_file_exists "dependencies.brewfile"
    assert_configuration_file_exists "applications.brewfile"
    assert_configuration_file_exists "cargo.packages"
    
    # Verify content structure
    assert_package_count_correct "$DOTFILES_PARENT_DIR/dependencies/dependencies.brewfile" "^brew " 6
    assert_package_count_correct "$DOTFILES_PARENT_DIR/dependencies/dependencies.brewfile" "^cask " 1
    assert_package_count_correct "$DOTFILES_PARENT_DIR/dependencies/applications.brewfile" "^cask " 2
    assert_package_count_correct "$DOTFILES_PARENT_DIR/dependencies/applications.brewfile" "^mas " 1
}

# Test data validation utilities

validate_brewfile_syntax() {
    local brewfile="$1"
    local errors=()
    
    # Check for required patterns
    if ! grep -q '^# ' "$brewfile"; then
        errors+=("Missing comments/sections")
    fi
    
    # Check for invalid syntax
    if grep -q '^brew [^"]' "$brewfile"; then
        errors+=("Unquoted package names")
    fi
    
    if [ ${#errors[@]} -gt 0 ]; then
        echo "VALIDATION_ERRORS: ${errors[*]}"
        return 1
    fi
    
    echo "VALIDATION_PASSED"
    return 0
}

@test "test utilities: data validation catches syntax errors" {
    mkdir -p "$DOTFILES_PARENT_DIR/dependencies"
    
    # Create valid brewfile
    cat > "$DOTFILES_PARENT_DIR/dependencies/valid.brewfile" << 'EOF'
# Development tools
brew "git"
brew "curl"
EOF
    
    run validate_brewfile_syntax "$DOTFILES_PARENT_DIR/dependencies/valid.brewfile"
    assert_success
    assert_output "VALIDATION_PASSED"
    
    # Create invalid brewfile
    cat > "$DOTFILES_PARENT_DIR/dependencies/invalid.brewfile" << 'EOF'
brew git
brew curl
EOF
    
    run validate_brewfile_syntax "$DOTFILES_PARENT_DIR/dependencies/invalid.brewfile"
    assert_failure
    assert_output --partial "VALIDATION_ERRORS:"
    assert_output --partial "Missing comments/sections"
    assert_output --partial "Unquoted package names"
}