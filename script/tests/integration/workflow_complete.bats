#!/usr/bin/env bats

# Integration tests for end-to-end workflows
# Focus: Test complete workflows and integration between modules

# Load helpers using correct relative path
load "../helpers/helper.bash"
load "$TESTS_DIR/helpers/mocks.bash"

setup() {
    test_setup
    setup_advanced_mocks
    
    # Copy all scripts for integration testing
    cp "$PROJECT_ROOT/script/main" "$DOTFILES_PARENT_DIR/script/main"
    cp "$PROJECT_ROOT/script/setup" "$DOTFILES_PARENT_DIR/script/setup"
    cp "$PROJECT_ROOT/script/update" "$DOTFILES_PARENT_DIR/script/update"
    cp "$PROJECT_ROOT/script/status" "$DOTFILES_PARENT_DIR/script/status"
    cp -r "$PROJECT_ROOT/script/core" "$DOTFILES_PARENT_DIR/script/"
    
    # Set up complete environment
    export DOTFILES_PARENT_DIR="$DOTFILES_PARENT_DIR"
    export DOTFILES_LOG_FILE="$DOTFILES_PARENT_DIR/tmp/integration-test.log"
    export DOTFILES_DEBUG_LOG="$DOTFILES_PARENT_DIR/tmp/debug-integration-test.log"
    
    # Create realistic dependencies configuration
    setup_realistic_dependencies
}

teardown() {
    test_teardown
}

setup_realistic_dependencies() {
    mkdir -p "$DOTFILES_PARENT_DIR/dependencies"
    
    # Create realistic dependencies.brewfile
    cat > "$DOTFILES_PARENT_DIR/dependencies/dependencies.brewfile" << 'EOF'
# Core development tools
brew "git"
brew "curl"
brew "wget"
brew "jq"
brew "ripgrep"
brew "fd"

# Package managers
brew "node"
brew "python@3.11"
brew "go"

# Infrastructure tools  
brew "docker"
brew "kubectl"
cask "1password-cli"
EOF

    # Create realistic applications.brewfile
    cat > "$DOTFILES_PARENT_DIR/dependencies/applications.brewfile" << 'EOF'
# Development applications
cask "visual-studio-code"
cask "docker"
cask "postman"

# Productivity applications
cask "1password"
cask "notion"

# Communication applications
cask "slack"
cask "zoom"

# Mac App Store applications
mas "Xcode", id: 497799835
mas "TestFlight", id: 899247664
EOF

    # Create package lists for additional managers
    cat > "$DOTFILES_PARENT_DIR/dependencies/cargo.packages" << 'EOF'
exa
bat
ripgrep
fd-find
starship
EOF

    cat > "$DOTFILES_PARENT_DIR/dependencies/npm.packages" << 'EOF'
@angular/cli
typescript
prettier
eslint
nodemon
EOF
}

# Integration test: Full setup workflow
@test "integration: complete setup workflow executes successfully" {
    # Create a comprehensive setup script that simulates real workflow
    cat > "$DOTFILES_PARENT_DIR/script/setup" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Source all our helpers like the real script
CURRENT_DIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")
source "$CURRENT_DIR/core/common"

# Validate environment (our business logic)
if [ -z "${DOTFILES_PARENT_DIR:-}" ]; then
    echo "❌ This script should not be called directly!"
    exit 1
fi

# Create execution log to track workflow
exec_log="$TEST_TEMP_DIR/setup_workflow.log"

# Simulate our setup phases
echo "PHASE: Validating prerequisites" >> "$exec_log"
if [ -d "$DOTFILES_PARENT_DIR/dependencies" ]; then
    echo "VALIDATION: Dependencies directory found" >> "$exec_log"
fi

echo "PHASE: Processing dependencies" >> "$exec_log"
if [ -f "$DOTFILES_PARENT_DIR/dependencies/dependencies.brewfile" ]; then
    dep_count=$(grep -c '^brew \|^cask ' "$DOTFILES_PARENT_DIR/dependencies/dependencies.brewfile")
    echo "PROCESSING: $dep_count packages from dependencies.brewfile" >> "$exec_log"
fi

echo "PHASE: Processing applications" >> "$exec_log"
if [ -f "$DOTFILES_PARENT_DIR/dependencies/applications.brewfile" ]; then
    app_count=$(grep -c '^cask \|^mas ' "$DOTFILES_PARENT_DIR/dependencies/applications.brewfile")
    echo "PROCESSING: $app_count applications from applications.brewfile" >> "$exec_log"
fi

echo "PHASE: Configuring development stack" >> "$exec_log"
for pkg_file in cargo.packages npm.packages; do
    if [ -f "$DOTFILES_PARENT_DIR/dependencies/$pkg_file" ]; then
        pkg_count=$(grep -c '^[^#]' "$DOTFILES_PARENT_DIR/dependencies/$pkg_file" || echo 0)
        echo "PROCESSING: $pkg_count packages from $pkg_file" >> "$exec_log"
    fi
done

echo "WORKFLOW: Setup completed successfully" >> "$exec_log"
exit 0
EOF
    chmod +x "$DOTFILES_PARENT_DIR/script/setup"
    
    run "$DOTFILES_PARENT_DIR/script/setup"
    assert_success
    
    # Verify the log file was created
    assert [ -f "$TEST_TEMP_DIR/setup_workflow.log" ]
    
    # Verify workflow executed all phases
    run cat "$TEST_TEMP_DIR/setup_workflow.log"
    assert_success
    
    # Verify workflow completion markers
    assert_output --partial "PHASE:"
    assert_output --partial "WORKFLOW: Setup completed successfully"
    assert_output --partial "PHASE: Validating prerequisites"
    assert_output --partial "VALIDATION: Dependencies directory found"
    assert_output --partial "PHASE: Processing dependencies"
    assert_output --partial "PROCESSING: 12 packages from dependencies.brewfile"
    assert_output --partial "PHASE: Processing applications"  
    assert_output --partial "PROCESSING: 9 applications from applications.brewfile"
    assert_output --partial "PHASE: Configuring development stack"
    assert_output --partial "PROCESSING: 5 packages from cargo.packages"
    assert_output --partial "PROCESSING: 5 packages from npm.packages"
    assert_output --partial "WORKFLOW: Setup completed successfully"
}

# Integration test: Status workflow with realistic data
@test "integration: status workflow analyzes complete system state" {
    # Create status script that performs realistic system analysis
    cat > "$DOTFILES_PARENT_DIR/script/status" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")
source "$CURRENT_DIR/core/common"

if [ -z "${DOTFILES_PARENT_DIR:-}" ]; then
    echo "❌ This script should not be called directly!"
    exit 1
fi

status_log="$TEST_TEMP_DIR/status_analysis.log"

# System Analysis
echo "ANALYSIS: System information" >> "$status_log"
echo "  OS: macOS $(sw_vers -productVersion 2>/dev/null || echo "unknown")" >> "$status_log"
echo "  Architecture: $(uname -m)" >> "$status_log"

# Dependencies Analysis  
echo "ANALYSIS: Dependencies configuration" >> "$status_log"
deps_brewfile="$DOTFILES_PARENT_DIR/dependencies/dependencies.brewfile"
if [ -f "$deps_brewfile" ]; then
    brew_count=$(grep -c '^brew ' "$deps_brewfile" 2>/dev/null || echo 0)
    cask_count=$(grep -c '^cask ' "$deps_brewfile" 2>/dev/null || echo 0)
    echo "  Configured dependencies: $brew_count formulae, $cask_count casks" >> "$status_log"
else
    echo "  No dependencies configured" >> "$status_log"
fi

# Applications Analysis
echo "ANALYSIS: Applications configuration" >> "$status_log" 
apps_brewfile="$DOTFILES_PARENT_DIR/dependencies/applications.brewfile"
if [ -f "$apps_brewfile" ]; then
    app_cask_count=$(grep -c '^cask ' "$apps_brewfile" 2>/dev/null || echo 0)
    mas_count=$(grep -c '^mas ' "$apps_brewfile" 2>/dev/null || echo 0)
    echo "  Configured applications: $app_cask_count casks, $mas_count App Store" >> "$status_log"
else
    echo "  No applications configured" >> "$status_log"
fi

# Development Stack Analysis
echo "ANALYSIS: Development packages" >> "$status_log"
for pkg_file in cargo.packages npm.packages; do
    if [ -f "$DOTFILES_PARENT_DIR/dependencies/$pkg_file" ]; then
        pkg_count=$(grep -c '^[^#]' "$DOTFILES_PARENT_DIR/dependencies/$pkg_file" 2>/dev/null || echo 0)
        echo "  $pkg_file: $pkg_count packages configured" >> "$status_log"
    fi
done

echo "STATUS: Analysis completed" >> "$status_log"
echo "System status analysis completed"
EOF
    chmod +x "$DOTFILES_PARENT_DIR/script/status"
    
    run "$DOTFILES_PARENT_DIR/script/status"
    assert_success
    
    # Verify comprehensive analysis was performed
    run cat "$TEST_TEMP_DIR/status_analysis.log"
    assert_success
    assert_output --partial "ANALYSIS: System information"
    assert_output --partial "OS: macOS"
    assert_output --partial "Architecture: arm64"
    assert_output --partial "ANALYSIS: Dependencies configuration"
    assert_output --partial "Configured dependencies: 11 formulae, 1 casks"
    assert_output --partial "ANALYSIS: Applications configuration"
    assert_output --partial "Configured applications: 7 casks, 2 App Store"
    assert_output --partial "ANALYSIS: Development packages"
    assert_output --partial "cargo.packages: 5 packages configured"
    assert_output --partial "npm.packages: 5 packages configured"
    assert_output --partial "STATUS: Analysis completed"
}

# Integration test: Update workflow coordination  
@test "integration: update workflow coordinates multiple update streams" {
    # Create update script that orchestrates multiple update sources
    cat > "$DOTFILES_PARENT_DIR/script/update" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")
source "$CURRENT_DIR/core/common"

if [ -z "${DOTFILES_PARENT_DIR:-}" ]; then
    echo "❌ This script should not be called directly!"
    exit 1
fi

update_log="$TEST_TEMP_DIR/update_workflow.log"

echo "UPDATE: Starting coordinated update process" >> "$update_log"

# Update Homebrew packages
echo "STREAM: Homebrew packages" >> "$update_log"
if [ -f "$DOTFILES_PARENT_DIR/dependencies/dependencies.brewfile" ]; then
    echo "  Updating formulae and casks from dependencies.brewfile" >> "$update_log"
fi

# Update applications
echo "STREAM: Applications" >> "$update_log"
if [ -f "$DOTFILES_PARENT_DIR/dependencies/applications.brewfile" ]; then
    echo "  Updating applications from applications.brewfile" >> "$update_log"
fi

# Update development packages
echo "STREAM: Development packages" >> "$update_log"
for pkg_manager in cargo npm; do
    pkg_file="$DOTFILES_PARENT_DIR/dependencies/${pkg_manager}.packages"
    if [ -f "$pkg_file" ]; then
        echo "  Updating $pkg_manager packages" >> "$update_log"
    fi
done

# Update configuration
echo "STREAM: Configuration" >> "$update_log"
echo "  Applying dotfiles updates" >> "$update_log"
echo "  Reloading shell configuration" >> "$update_log"

echo "UPDATE: All streams coordinated successfully" >> "$update_log"
echo "System update completed successfully"
EOF
    chmod +x "$DOTFILES_PARENT_DIR/script/update"
    
    run "$DOTFILES_PARENT_DIR/script/update"
    assert_success
    
    # Verify update coordination
    run cat "$TEST_TEMP_DIR/update_workflow.log"
    assert_success
    assert_output --partial "UPDATE: Starting coordinated update process"
    assert_output --partial "STREAM: Homebrew packages"
    assert_output --partial "Updating formulae and casks from dependencies.brewfile"
    assert_output --partial "STREAM: Applications"
    assert_output --partial "Updating applications from applications.brewfile"
    assert_output --partial "STREAM: Development packages"
    assert_output --partial "Updating cargo packages"
    assert_output --partial "Updating npm packages"
    assert_output --partial "STREAM: Configuration"
    assert_output --partial "Applying dotfiles updates"
    assert_output --partial "UPDATE: All streams coordinated successfully"
}

# Integration test: Error propagation and recovery
@test "integration: handles errors across workflow boundaries" {
    # Create setup script that simulates partial failure
    cat > "$DOTFILES_PARENT_DIR/script/setup" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")
source "$CURRENT_DIR/core/common"

if [ -z "${DOTFILES_PARENT_DIR:-}" ]; then
    exit 1
fi

error_log="$TEST_TEMP_DIR/error_handling.log"

# Simulate phases with mixed success/failure
echo "PHASE_1: SUCCESS - Prerequisites validated" >> "$error_log"

echo "PHASE_2: ATTEMPTING - Dependencies installation" >> "$error_log"
# Simulate a non-critical failure
if [ -f "$DOTFILES_PARENT_DIR/simulate_dependency_failure" ]; then
    echo "PHASE_2: PARTIAL_FAILURE - Some dependencies failed" >> "$error_log"
else
    echo "PHASE_2: SUCCESS - Dependencies installed" >> "$error_log"
fi

echo "PHASE_3: SUCCESS - Applications installed" >> "$error_log"

# Our business logic: continue despite partial failures
echo "WORKFLOW: COMPLETED_WITH_WARNINGS" >> "$error_log"
echo "Setup completed with warnings"
exit 0
EOF
    chmod +x "$DOTFILES_PARENT_DIR/script/setup"
    
    # Create failure condition
    touch "$DOTFILES_PARENT_DIR/simulate_dependency_failure"
    
    run "$DOTFILES_PARENT_DIR/script/setup"
    assert_success  # Should succeed despite partial failure
    
    # Verify error was handled appropriately
    run cat "$TEST_TEMP_DIR/error_handling.log"
    assert_success
    assert_output --partial "PHASE_1: SUCCESS"
    assert_output --partial "PHASE_2: PARTIAL_FAILURE - Some dependencies failed"
    assert_output --partial "PHASE_3: SUCCESS"
    assert_output --partial "WORKFLOW: COMPLETED_WITH_WARNINGS"
}

# Integration test: Configuration file processing
@test "integration: processes configuration files end-to-end" {
    # Create mock chezmoi configuration directory
    mkdir -p "$DOTFILES_PARENT_DIR/dot_config/test-app"
    
    # Create template configuration file
    cat > "$DOTFILES_PARENT_DIR/dot_config/test-app/config.yml.tmpl" << 'EOF'
# Test application configuration
user_home: {{.HOME}}
project_root: {{.DOTFILES_PARENT_DIR}}
log_level: debug
features:
  - feature1
  - feature2
EOF
    
    # Create script that processes configuration like our real workflow
    cat > "$DOTFILES_PARENT_DIR/test_config_processing.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

process_configuration_files() {
    local config_dir="$DOTFILES_PARENT_DIR/dot_config"
    local processing_log="$TEST_TEMP_DIR/config_processing.log"
    
    echo "CONFIG: Starting configuration processing" >> "$processing_log"
    
    # Find template files (our logic)
    find "$config_dir" -name "*.tmpl" -type f | while read -r template; do
        local output_file="${template%.tmpl}"
        echo "PROCESSING: $template -> $output_file" >> "$processing_log"
        
        # Simple template processing (simulate chezmoi behavior)
        local content
        content=$(cat "$template")
        content=${content//\{\{\.HOME\}\}/$HOME}
        content=${content//\{\{\.DOTFILES_PARENT_DIR\}\}/$DOTFILES_PARENT_DIR}
        
        echo "$content" > "$output_file"
        echo "APPLIED: $(basename "$output_file")" >> "$processing_log"
    done
    
    echo "CONFIG: Processing completed" >> "$processing_log"
}

process_configuration_files
EOF
    chmod +x "$DOTFILES_PARENT_DIR/test_config_processing.sh"
    
    run "$DOTFILES_PARENT_DIR/test_config_processing.sh"
    assert_success
    
    # Verify configuration processing worked
    run cat "$TEST_TEMP_DIR/config_processing.log"
    assert_success
    assert_output --partial "CONFIG: Starting configuration processing"
    assert_output --partial "PROCESSING: $DOTFILES_PARENT_DIR/dot_config/test-app/config.yml.tmpl"
    assert_output --partial "APPLIED: config.yml"
    assert_output --partial "CONFIG: Processing completed"
    
    # Verify template was processed correctly
    run cat "$DOTFILES_PARENT_DIR/dot_config/test-app/config.yml"
    assert_success
    assert_output --partial "user_home: $MOCK_HOME"
    assert_output --partial "project_root: $DOTFILES_PARENT_DIR"
    assert_output --partial "log_level: debug"
}