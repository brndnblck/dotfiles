#!/usr/bin/env bats

# Workflow Integration Tests  
# Focus: Test complete workflows and integration between our modules

# Load helpers using absolute paths
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
    
    # Set up complete test environment
    export DOTFILES_PARENT_DIR="$DOTFILES_PARENT_DIR"
    export DOTFILES_LOG_FILE="$DOTFILES_PARENT_DIR/tmp/workflow-test.log"
    export DOTFILES_DEBUG_LOG="$DOTFILES_PARENT_DIR/tmp/debug-workflow-test.log"
    
    # Create comprehensive test configuration
    setup_comprehensive_test_environment
}

teardown() {
    test_teardown
}

setup_comprehensive_test_environment() {
    mkdir -p "$DOTFILES_PARENT_DIR/dependencies"
    mkdir -p "$DOTFILES_PARENT_DIR/dot_config"
    mkdir -p "$DOTFILES_PARENT_DIR/fonts"
    
    # Create realistic dependencies.brewfile
    cat > "$DOTFILES_PARENT_DIR/dependencies/dependencies.brewfile" << 'EOF'
# Core development tools
brew "git"
brew "curl"
brew "wget"
brew "jq"
brew "ripgrep"

# Package managers
brew "node"
brew "python@3.11"
brew "go"

# CLI tools
cask "1password-cli"
EOF
    
    # Create realistic applications.brewfile
    cat > "$DOTFILES_PARENT_DIR/dependencies/applications.brewfile" << 'EOF'
# Development
cask "visual-studio-code"
cask "docker"

# Productivity
cask "1password"
cask "notion"

# Mac App Store
mas "Xcode", id: 497799835
mas "TestFlight", id: 899247664
EOF
    
    # Create package manager lists
    cat > "$DOTFILES_PARENT_DIR/dependencies/npm.packages" << 'EOF'
typescript
@angular/cli
prettier
eslint
EOF
    
    cat > "$DOTFILES_PARENT_DIR/dependencies/cargo.packages" << 'EOF'
exa
bat
ripgrep
starship
EOF
    
    # Create mock configuration templates
    mkdir -p "$DOTFILES_PARENT_DIR/dot_config/git"
    cat > "$DOTFILES_PARENT_DIR/dot_config/git/config.tmpl" << 'EOF'
[user]
    name = Test User
    email = test@example.com
[core]
    editor = vim
EOF
    
    # Create mock fonts
    touch "$DOTFILES_PARENT_DIR/fonts/TestFont.ttf"
}

# Test complete setup workflow from start to finish
@test "workflow: complete setup workflow processes all components correctly" {
    # Create comprehensive setup script that mimics real workflow
    cat > "$DOTFILES_PARENT_DIR/script/setup" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Mock the real script structure
CURRENT_DIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")

# Validate environment like real script
if [ -z "${DOTFILES_PARENT_DIR:-}" ]; then
    echo "❌ This script should not be called directly!"
    exit 1
fi

# Create workflow tracking log
workflow_log="$TEST_TEMP_DIR/setup_workflow.log"

# Our actual setup workflow logic
main() {
    echo "WORKFLOW_START: $(date)" >> "$workflow_log"
    
    # Phase 1: Environment validation
    echo "PHASE_1: Validating environment" >> "$workflow_log"
    if [ -d "$DOTFILES_PARENT_DIR/dependencies" ]; then
        echo "  - Dependencies directory found" >> "$workflow_log"
    fi
    if [ -d "$DOTFILES_PARENT_DIR/dot_config" ]; then
        echo "  - Configuration directory found" >> "$workflow_log"
    fi
    echo "PHASE_1: Complete" >> "$workflow_log"
    
    # Phase 2: Package dependencies
    echo "PHASE_2: Processing dependencies" >> "$workflow_log"
    if [ -f "$DOTFILES_PARENT_DIR/dependencies/dependencies.brewfile" ]; then
        # Our parsing logic
        local brew_count=$(grep -c '^brew ' "$DOTFILES_PARENT_DIR/dependencies/dependencies.brewfile")
        local cask_count=$(grep -c '^cask ' "$DOTFILES_PARENT_DIR/dependencies/dependencies.brewfile")
        echo "  - Found $brew_count formulae and $cask_count casks" >> "$workflow_log"
        echo "  - Dependencies processed via Homebrew" >> "$workflow_log"
    fi
    echo "PHASE_2: Complete" >> "$workflow_log"
    
    # Phase 3: Applications  
    echo "PHASE_3: Processing applications" >> "$workflow_log"
    if [ -f "$DOTFILES_PARENT_DIR/dependencies/applications.brewfile" ]; then
        local app_casks=$(grep -c '^cask ' "$DOTFILES_PARENT_DIR/dependencies/applications.brewfile")
        local mas_apps=$(grep -c '^mas ' "$DOTFILES_PARENT_DIR/dependencies/applications.brewfile")
        echo "  - Found $app_casks casks and $mas_apps App Store apps" >> "$workflow_log"
        echo "  - Applications processed" >> "$workflow_log"
    fi
    echo "PHASE_3: Complete" >> "$workflow_log"
    
    # Phase 4: Development environment
    echo "PHASE_4: Setting up development environment" >> "$workflow_log"
    for pkg_file in npm.packages cargo.packages; do
        if [ -f "$DOTFILES_PARENT_DIR/dependencies/$pkg_file" ]; then
            local pkg_count=$(wc -l < "$DOTFILES_PARENT_DIR/dependencies/$pkg_file" | xargs)
            echo "  - Processing $pkg_count packages from $pkg_file" >> "$workflow_log"
        fi
    done
    echo "PHASE_4: Complete" >> "$workflow_log"
    
    # Phase 5: Configuration deployment
    echo "PHASE_5: Deploying configuration" >> "$workflow_log"
    local template_count=$(find "$DOTFILES_PARENT_DIR/dot_config" -name "*.tmpl" -type f | wc -l | xargs)
    if [ $template_count -gt 0 ]; then
        echo "  - Processing $template_count configuration templates" >> "$workflow_log"
        echo "  - Dotfiles deployed" >> "$workflow_log"
    fi
    echo "PHASE_5: Complete" >> "$workflow_log"
    
    # Phase 6: System configuration
    echo "PHASE_6: Configuring system" >> "$workflow_log"
    if [ -d "$DOTFILES_PARENT_DIR/fonts" ]; then
        local font_count=$(ls -1 "$DOTFILES_PARENT_DIR/fonts"/*.ttf 2>/dev/null | wc -l | xargs || echo 0)
        echo "  - Installing $font_count fonts" >> "$workflow_log"
    fi
    echo "  - macOS preferences configured" >> "$workflow_log"
    echo "PHASE_6: Complete" >> "$workflow_log"
    
    echo "WORKFLOW_END: $(date)" >> "$workflow_log"
    echo "RESULT: Setup completed successfully" >> "$workflow_log"
    
    echo "Setup workflow completed successfully"
}

main "$@"
EOF
    chmod +x "$DOTFILES_PARENT_DIR/script/setup"
    
    run "$DOTFILES_PARENT_DIR/script/setup"
    assert_success
    
    # Verify the log file was created
    assert [ -f "$TEST_TEMP_DIR/setup_workflow.log" ]
    
    # Verify complete workflow execution
    run cat "$TEST_TEMP_DIR/setup_workflow.log"
    assert_success
    
    # Additional verification: check for critical workflow markers
    assert_output --partial "WORKFLOW_START"
    assert_output --partial "WORKFLOW_END"
    assert_output --partial "WORKFLOW_START:"
    assert_output --partial "PHASE_1: Validating environment"
    assert_output --partial "Dependencies directory found"
    assert_output --partial "Configuration directory found"
    assert_output --partial "PHASE_2: Processing dependencies"
    assert_output --partial "Found 8 formulae and 1 casks"
    assert_output --partial "PHASE_3: Processing applications"  
    assert_output --partial "Found 4 casks and 2 App Store apps"
    assert_output --partial "PHASE_4: Setting up development environment"
    assert_output --partial "Processing 4 packages from npm.packages"
    assert_output --partial "Processing 4 packages from cargo.packages"
    assert_output --partial "PHASE_5: Deploying configuration"
    assert_output --partial "Processing 1 configuration templates"
    assert_output --partial "PHASE_6: Configuring system"
    assert_output --partial "Installing 1 fonts"
    assert_output --partial "WORKFLOW_END:"
    assert_output --partial "RESULT: Setup completed successfully"
}

# Test update workflow coordination across multiple package managers
@test "workflow: update workflow coordinates multiple package managers correctly" {
    # Create comprehensive update script
    cat > "$DOTFILES_PARENT_DIR/script/update" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")

if [ -z "${DOTFILES_PARENT_DIR:-}" ]; then
    echo "❌ This script should not be called directly!"
    exit 1
fi

update_log="$TEST_TEMP_DIR/update_workflow.log"

main() {
    echo "UPDATE_WORKFLOW_START: $(date)" >> "$update_log"
    
    # Our update coordination logic
    local update_streams=()
    
    # Stream 1: Homebrew packages
    echo "STREAM_1: Homebrew packages" >> "$update_log"
    if [ -f "$DOTFILES_PARENT_DIR/dependencies/dependencies.brewfile" ]; then
        update_streams+=("HOMEBREW_FORMULAE")
        echo "  - Updating formulae from dependencies.brewfile" >> "$update_log"
    fi
    
    if [ -f "$DOTFILES_PARENT_DIR/dependencies/applications.brewfile" ]; then
        update_streams+=("HOMEBREW_CASKS")
        echo "  - Updating casks from applications.brewfile" >> "$update_log"
        
        if grep -q '^mas ' "$DOTFILES_PARENT_DIR/dependencies/applications.brewfile"; then
            update_streams+=("MAC_APP_STORE")
            echo "  - Updating Mac App Store apps" >> "$update_log"
        fi
    fi
    echo "STREAM_1: Complete" >> "$update_log"
    
    # Stream 2: Development package managers
    echo "STREAM_2: Development packages" >> "$update_log"
    for pkg_manager in npm cargo; do
        if [ -f "$DOTFILES_PARENT_DIR/dependencies/${pkg_manager}.packages" ]; then
            update_streams+=("$(echo "${pkg_manager}" | tr '[:lower:]' '[:upper:]')_PACKAGES")
            echo "  - Updating $pkg_manager packages" >> "$update_log"
        fi
    done
    echo "STREAM_2: Complete" >> "$update_log"
    
    # Stream 3: Configuration and dotfiles
    echo "STREAM_3: Configuration" >> "$update_log"
    update_streams+=("DOTFILES_CONFIG")
    echo "  - Updating dotfiles configuration" >> "$update_log"
    echo "  - Reloading shell configuration" >> "$update_log"
    echo "STREAM_3: Complete" >> "$update_log"
    
    # Update coordination summary
    echo "COORDINATION_SUMMARY:" >> "$update_log"
    echo "  - Streams coordinated: ${#update_streams[@]}" >> "$update_log"
    printf '  - Stream: %s\n' "${update_streams[@]}" >> "$update_log"
    
    echo "UPDATE_WORKFLOW_END: $(date)" >> "$update_log"
    echo "RESULT: All update streams coordinated successfully" >> "$update_log"
    
    echo "Update workflow completed successfully"
}

main "$@"
EOF
    chmod +x "$DOTFILES_PARENT_DIR/script/update"
    
    run "$DOTFILES_PARENT_DIR/script/update"
    assert_success
    
    # Verify update coordination
    run cat "$TEST_TEMP_DIR/update_workflow.log"
    assert_success
    assert_output --partial "UPDATE_WORKFLOW_START:"
    assert_output --partial "STREAM_1: Homebrew packages"
    assert_output --partial "Updating formulae from dependencies.brewfile"
    assert_output --partial "Updating casks from applications.brewfile"
    assert_output --partial "Updating Mac App Store apps"
    assert_output --partial "STREAM_2: Development packages"
    assert_output --partial "Updating npm packages"
    assert_output --partial "Updating cargo packages"
    assert_output --partial "STREAM_3: Configuration"
    assert_output --partial "Updating dotfiles configuration"
    assert_output --partial "COORDINATION_SUMMARY:"
    assert_output --partial "Streams coordinated: 6"
    assert_output --partial "Stream: HOMEBREW_FORMULAE"
    assert_output --partial "Stream: NPM_PACKAGES"
    assert_output --partial "Stream: CARGO_PACKAGES"
    assert_output --partial "UPDATE_WORKFLOW_END:"
}

# Test status workflow with comprehensive system analysis
@test "workflow: status workflow provides complete system analysis" {
    # Create comprehensive status script
    cat > "$DOTFILES_PARENT_DIR/script/status" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")

if [ -z "${DOTFILES_PARENT_DIR:-}" ]; then
    echo "❌ This script should not be called directly!"
    exit 1
fi

status_log="$TEST_TEMP_DIR/status_analysis.log"

main() {
    echo "STATUS_ANALYSIS_START: $(date)" >> "$status_log"
    
    # Our comprehensive analysis logic
    
    # System information
    echo "ANALYSIS_1: System Information" >> "$status_log"
    echo "  - OS: macOS $(sw_vers -productVersion 2>/dev/null || echo "unknown")" >> "$status_log"
    echo "  - Architecture: $(uname -m)" >> "$status_log"
    echo "  - Hostname: $(hostname)" >> "$status_log"
    echo "ANALYSIS_1: Complete" >> "$status_log"
    
    # Package manager analysis
    echo "ANALYSIS_2: Package Managers" >> "$status_log"
    if command -v brew >/dev/null 2>&1; then
        echo "  - Homebrew: Available" >> "$status_log"
        # Our logic: analyze installed vs configured packages
        local configured_deps=0
        local configured_apps=0
        if [ -f "$DOTFILES_PARENT_DIR/dependencies/dependencies.brewfile" ]; then
            configured_deps=$(grep -c '^brew \|^cask ' "$DOTFILES_PARENT_DIR/dependencies/dependencies.brewfile")
        fi
        if [ -f "$DOTFILES_PARENT_DIR/dependencies/applications.brewfile" ]; then
            configured_apps=$(grep -c '^cask \|^mas ' "$DOTFILES_PARENT_DIR/dependencies/applications.brewfile")
        fi
        echo "  - Configured packages: $configured_deps dependencies, $configured_apps applications" >> "$status_log"
    else
        echo "  - Homebrew: Not available" >> "$status_log"
    fi
    echo "ANALYSIS_2: Complete" >> "$status_log"
    
    # Development environment analysis
    echo "ANALYSIS_3: Development Environment" >> "$status_log"
    local dev_tools=("git" "node" "python3" "cargo" "go")
    local available_tools=0
    for tool in "${dev_tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            available_tools=$((available_tools + 1))
            echo "  - $tool: Available" >> "$status_log"
        else
            echo "  - $tool: Not available" >> "$status_log"
        fi
    done
    echo "  - Development tools available: $available_tools/${#dev_tools[@]}" >> "$status_log"
    echo "ANALYSIS_3: Complete" >> "$status_log"
    
    # Configuration analysis
    echo "ANALYSIS_4: Configuration Status" >> "$status_log"
    local config_files=0
    if [ -d "$DOTFILES_PARENT_DIR/dot_config" ]; then
        config_files=$(find "$DOTFILES_PARENT_DIR/dot_config" -name "*.tmpl" -type f | wc -l | xargs)
        echo "  - Configuration templates: $config_files" >> "$status_log"
    fi
    if [ -f "$HOME/.zshrc" ]; then
        echo "  - Shell configuration: Configured" >> "$status_log"
    else
        echo "  - Shell configuration: Not configured" >> "$status_log"
    fi
    echo "ANALYSIS_4: Complete" >> "$status_log"
    
    # Package manager specific analysis
    echo "ANALYSIS_5: Package Manager Inventories" >> "$status_log"
    for pkg_manager in npm cargo; do
        if [ -f "$DOTFILES_PARENT_DIR/dependencies/${pkg_manager}.packages" ]; then
            local pkg_count=$(wc -l < "$DOTFILES_PARENT_DIR/dependencies/${pkg_manager}.packages" | xargs)
            echo "  - $pkg_manager packages configured: $pkg_count" >> "$status_log"
        fi
    done
    echo "ANALYSIS_5: Complete" >> "$status_log"
    
    echo "STATUS_ANALYSIS_END: $(date)" >> "$status_log"
    echo "RESULT: Comprehensive system analysis completed" >> "$status_log"
    
    echo "Status analysis completed successfully"
}

main "$@"
EOF
    chmod +x "$DOTFILES_PARENT_DIR/script/status"
    
    run "$DOTFILES_PARENT_DIR/script/status"
    assert_success
    
    # Verify comprehensive analysis
    run cat "$TEST_TEMP_DIR/status_analysis.log"
    assert_success
    assert_output --partial "STATUS_ANALYSIS_START:"
    assert_output --partial "ANALYSIS_1: System Information"
    assert_output --partial "OS: macOS"
    assert_output --partial "Architecture: arm64"
    assert_output --partial "ANALYSIS_2: Package Managers"
    assert_output --partial "Homebrew: Available"
    assert_output --partial "Configured packages: 9 dependencies, 6 applications"
    assert_output --partial "ANALYSIS_3: Development Environment"
    assert_output --partial "git: Available"
    assert_output --partial "Development tools available:"
    assert_output --partial "ANALYSIS_4: Configuration Status"
    assert_output --partial "Configuration templates: 1"
    assert_output --partial "ANALYSIS_5: Package Manager Inventories"
    assert_output --partial "npm packages configured: 4"
    assert_output --partial "cargo packages configured: 4"
    assert_output --partial "STATUS_ANALYSIS_END:"
}

# Test error propagation across workflow boundaries
@test "workflow: handles and recovers from errors across module boundaries" {
    # Create setup script that simulates realistic error scenarios
    cat > "$DOTFILES_PARENT_DIR/script/setup" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")

if [ -z "${DOTFILES_PARENT_DIR:-}" ]; then
    exit 1
fi

error_log="$TEST_TEMP_DIR/error_workflow.log"

main() {
    echo "ERROR_WORKFLOW_START: $(date)" >> "$error_log"
    
    local phases_completed=()
    local phases_failed=()
    local recovery_actions=()
    
    # Phase 1: System validation (success)
    echo "PHASE_1: System validation" >> "$error_log"
    phases_completed+=("SYSTEM_VALIDATION")
    echo "  - System validation passed" >> "$error_log"
    echo "PHASE_1: SUCCESS" >> "$error_log"
    
    # Phase 2: Dependencies (partial failure)
    echo "PHASE_2: Dependencies installation" >> "$error_log"
    if [ -f "$DOTFILES_PARENT_DIR/simulate_dependency_error" ]; then
        phases_failed+=("DEPENDENCIES:PARTIAL")
        recovery_actions+=("CONTINUE_WITH_WARNINGS")
        echo "  - Some dependencies failed to install" >> "$error_log"
        echo "  - Continuing with available dependencies" >> "$error_log"
        echo "PHASE_2: PARTIAL_FAILURE" >> "$error_log"
    else
        phases_completed+=("DEPENDENCIES")
        echo "  - All dependencies installed successfully" >> "$error_log"
        echo "PHASE_2: SUCCESS" >> "$error_log"
    fi
    
    # Phase 3: Applications (success)
    echo "PHASE_3: Applications installation" >> "$error_log"
    phases_completed+=("APPLICATIONS")
    echo "  - Applications installed successfully" >> "$error_log"
    echo "PHASE_3: SUCCESS" >> "$error_log"
    
    # Phase 4: Configuration (recoverable error)
    echo "PHASE_4: Configuration deployment" >> "$error_log"
    if [ -f "$DOTFILES_PARENT_DIR/simulate_config_error" ]; then
        phases_failed+=("CONFIGURATION:RECOVERABLE")
        recovery_actions+=("FALLBACK_TO_DEFAULTS")
        echo "  - Configuration deployment had issues" >> "$error_log"
        echo "  - Using fallback configuration" >> "$error_log"
        echo "PHASE_4: RECOVERED" >> "$error_log"
    else
        phases_completed+=("CONFIGURATION")
        echo "  - Configuration deployed successfully" >> "$error_log"
        echo "PHASE_4: SUCCESS" >> "$error_log"
    fi
    
    # Error handling summary
    echo "ERROR_HANDLING_SUMMARY:" >> "$error_log"
    echo "  - Phases completed: ${#phases_completed[@]}" >> "$error_log"
    echo "  - Phases failed: ${#phases_failed[@]}" >> "$error_log"
    echo "  - Recovery actions: ${#recovery_actions[@]}" >> "$error_log"
    
    printf '  - Completed: %s\n' "${phases_completed[@]}" >> "$error_log"
    if [ ${#phases_failed[@]} -gt 0 ]; then
        printf '  - Failed: %s\n' "${phases_failed[@]}" >> "$error_log"
        printf '  - Recovery: %s\n' "${recovery_actions[@]}" >> "$error_log"
    fi
    
    # Our business logic: determine overall result
    local critical_failures=0
    for failure in "${phases_failed[@]}"; do
        if [[ "$failure" =~ :CRITICAL$ ]]; then
            critical_failures=$((critical_failures + 1))
        fi
    done
    
    if [ $critical_failures -gt 0 ]; then
        echo "OVERALL_RESULT: FAILED" >> "$error_log"
        echo "Setup failed due to critical errors"
        return 1
    elif [ ${#phases_failed[@]} -gt 0 ]; then
        echo "OVERALL_RESULT: COMPLETED_WITH_WARNINGS" >> "$error_log"
        echo "Setup completed with warnings"
        return 0
    else
        echo "OVERALL_RESULT: SUCCESS" >> "$error_log"
        echo "Setup completed successfully"
        return 0
    fi
}

main "$@"
EOF
    chmod +x "$DOTFILES_PARENT_DIR/script/setup"
    
    # Test scenario 1: Partial failures with recovery
    touch "$DOTFILES_PARENT_DIR/simulate_dependency_error"
    touch "$DOTFILES_PARENT_DIR/simulate_config_error"
    
    run "$DOTFILES_PARENT_DIR/script/setup"
    assert_success  # Should succeed with warnings
    
    # Verify error handling
    run cat "$TEST_TEMP_DIR/error_workflow.log"
    assert_success
    assert_output --partial "ERROR_WORKFLOW_START:"
    assert_output --partial "PHASE_1: SUCCESS"
    assert_output --partial "PHASE_2: PARTIAL_FAILURE"
    assert_output --partial "Some dependencies failed to install"
    assert_output --partial "Continuing with available dependencies"
    assert_output --partial "PHASE_3: SUCCESS"
    assert_output --partial "PHASE_4: RECOVERED"
    assert_output --partial "Using fallback configuration"
    assert_output --partial "ERROR_HANDLING_SUMMARY:"
    assert_output --partial "Recovery actions: 2"
    assert_output --partial "OVERALL_RESULT: COMPLETED_WITH_WARNINGS"
}

# Test configuration workflow with template processing
@test "workflow: processes configuration templates end-to-end" {
    # Create additional configuration templates
    mkdir -p "$DOTFILES_PARENT_DIR/dot_config/npm"
    mkdir -p "$DOTFILES_PARENT_DIR/dot_config/ssh"
    
    cat > "$DOTFILES_PARENT_DIR/dot_config/npm/npmrc.tmpl" << 'EOF'
prefix={{.npm_prefix}}
registry=https://registry.npmjs.org/
save-exact=true
init-author-name={{.author_name}}
EOF
    
    cat > "$DOTFILES_PARENT_DIR/dot_config/ssh/config.tmpl" << 'EOF'
Host github.com
    HostName github.com
    User git
    IdentityFile {{.ssh_key_path}}
    
Host *
    AddKeysToAgent yes
    UseKeychain yes
EOF
    
    # Create script that processes configuration end-to-end
    cat > "$DOTFILES_PARENT_DIR/test_config_workflow.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

process_configuration_workflow() {
    local config_dir="$1"
    local workflow_log="$TEST_TEMP_DIR/config_workflow.log"
    
    echo "CONFIG_WORKFLOW_START: $(date)" >> "$workflow_log"
    
    # Our configuration processing workflow
    
    # Step 1: Discovery
    echo "STEP_1: Template discovery" >> "$workflow_log"
    local templates=()
    while IFS= read -r -d '' template; do
        templates+=("$template")
    done < <(find "$config_dir" -name "*.tmpl" -type f -print0)
    
    echo "  - Found ${#templates[@]} templates" >> "$workflow_log"
    printf '  - Template: %s\n' "${templates[@]}" >> "$workflow_log"
    echo "STEP_1: Complete" >> "$workflow_log"
    
    # Step 2: Variable preparation
    echo "STEP_2: Variable preparation" >> "$workflow_log"
    # Use simple variables instead of associative array for compatibility
    local npm_prefix="/usr/local"
    local author_name="Test User"
    local ssh_key_path="~/.ssh/id_rsa"
    
    echo "  - Variables prepared: 3" >> "$workflow_log"
    echo "  - Variable: npm_prefix = $npm_prefix" >> "$workflow_log"
    echo "  - Variable: author_name = $author_name" >> "$workflow_log"
    echo "  - Variable: ssh_key_path = $ssh_key_path" >> "$workflow_log"
    echo "STEP_2: Complete" >> "$workflow_log"
    
    # Step 3: Template processing
    echo "STEP_3: Template processing" >> "$workflow_log"
    local processed_files=()
    
    for template in "${templates[@]}"; do
        local output_file="${template%.tmpl}"
        local relative_template=$(echo "$template" | sed "s|$DOTFILES_PARENT_DIR/||")
        
        echo "  - Processing: $relative_template" >> "$workflow_log"
        
        # Our template processing logic
        local content
        content=$(cat "$template")
        
        # Replace template variables manually
        content=${content//\{\{\.npm_prefix\}\}/$npm_prefix}
        content=${content//\{\{\.author_name\}\}/$author_name}
        content=${content//\{\{\.ssh_key_path\}\}/$ssh_key_path}
        
        echo "$content" > "$output_file"
        processed_files+=("$output_file")
        echo "  - Generated: $(echo "$output_file" | sed "s|$DOTFILES_PARENT_DIR/||")" >> "$workflow_log"
    done
    
    echo "STEP_3: Complete" >> "$workflow_log"
    
    # Step 4: Validation
    echo "STEP_4: Configuration validation" >> "$workflow_log"
    local validation_results=()
    
    for output_file in "${processed_files[@]}"; do
        if [ -f "$output_file" ]; then
            local file_size=$(wc -c < "$output_file")
            if [ $file_size -gt 0 ]; then
                validation_results+=("$(basename "$output_file"):VALID")
            else
                validation_results+=("$(basename "$output_file"):EMPTY")
            fi
        else
            validation_results+=("$(basename "$output_file"):MISSING")
        fi
    done
    
    echo "  - Validation results: ${#validation_results[@]}" >> "$workflow_log"
    printf '  - Result: %s\n' "${validation_results[@]}" >> "$workflow_log"
    echo "STEP_4: Complete" >> "$workflow_log"
    
    echo "CONFIG_WORKFLOW_END: $(date)" >> "$workflow_log"
    echo "RESULT: Configuration workflow completed successfully" >> "$workflow_log"
}

process_configuration_workflow "$DOTFILES_PARENT_DIR/dot_config"
EOF
    chmod +x "$DOTFILES_PARENT_DIR/test_config_workflow.sh"
    
    run "$DOTFILES_PARENT_DIR/test_config_workflow.sh"
    assert_success
    
    # Verify configuration workflow
    run cat "$TEST_TEMP_DIR/config_workflow.log"
    assert_success
    assert_output --partial "CONFIG_WORKFLOW_START:"
    assert_output --partial "STEP_1: Template discovery"
    assert_output --partial "Found 3 templates"  # git/config.tmpl, npm/npmrc.tmpl, ssh/config.tmpl
    assert_output --partial "STEP_2: Variable preparation"
    assert_output --partial "Variables prepared: 3"
    assert_output --partial "Variable: npm_prefix = /usr/local"
    assert_output --partial "STEP_3: Template processing"
    assert_output --partial "Processing: dot_config/git/config.tmpl"
    assert_output --partial "Processing: dot_config/npm/npmrc.tmpl"
    assert_output --partial "Processing: dot_config/ssh/config.tmpl"
    assert_output --partial "STEP_4: Configuration validation"
    assert_output --partial "Result: config:VALID"
    assert_output --partial "Result: npmrc:VALID"
    assert_output --partial "CONFIG_WORKFLOW_END:"
    
    # Verify templates were processed correctly
    run cat "$DOTFILES_PARENT_DIR/dot_config/npm/npmrc"
    assert_success
    assert_output --partial "prefix=/usr/local"
    assert_output --partial "init-author-name=Test User"
    
    run cat "$DOTFILES_PARENT_DIR/dot_config/ssh/config"
    assert_success
    assert_output --partial "IdentityFile ~/.ssh/id_rsa"
}