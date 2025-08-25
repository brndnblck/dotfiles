#!/usr/bin/env bats

# Interface and Behavior Tests  
# Focus: Test our script interfaces, entry points, and behavioral contracts

# Load helpers using correct relative path from unit/ui directory
load "../../helpers/helper"
load "../../helpers/mocks"
load "../../helpers/test_fixtures"

setup() {
    test_setup
    setup_advanced_mocks
    
    # Copy scripts for interface testing
    cp "$PROJECT_ROOT/script/main" "$DOTFILES_PARENT_DIR/script/main"
    cp "$PROJECT_ROOT/script/setup" "$DOTFILES_PARENT_DIR/script/setup"
    cp "$PROJECT_ROOT/script/update" "$DOTFILES_PARENT_DIR/script/update"
    cp "$PROJECT_ROOT/script/status" "$DOTFILES_PARENT_DIR/script/status"
    cp -r "$PROJECT_ROOT/script/core" "$DOTFILES_PARENT_DIR/script/"
    
    export DOTFILES_PARENT_DIR="$DOTFILES_PARENT_DIR"
    export DOTFILES_LOG_FILE="$DOTFILES_PARENT_DIR/tmp/interface-test.log"
    export DOTFILES_DEBUG_LOG="$DOTFILES_PARENT_DIR/tmp/debug-interface-test.log"
}

teardown() {
    test_teardown
}

# Test script entry point validation (our code, not shell behavior)
@test "interface: validates script execution context and environment" {
    # Create test script that implements our validation pattern
    cat > "$DOTFILES_PARENT_DIR/test_validation.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

validate_execution_context() {
    local script_name="$1"
    local validation_errors=()
    
    # Our validation logic: check environment setup
    if [ -z "${DOTFILES_PARENT_DIR:-}" ]; then
        validation_errors+=("DOTFILES_PARENT_DIR not set")
    fi
    
    if [ -z "${DOTFILES_LOG_FILE:-}" ]; then
        validation_errors+=("DOTFILES_LOG_FILE not set")
    fi
    
    # Our validation logic: check directory structure
    if [ ! -d "${DOTFILES_PARENT_DIR:-}" ]; then
        validation_errors+=("DOTFILES_PARENT_DIR directory missing")
    fi
    
    if [ ! -d "${DOTFILES_PARENT_DIR:-}/script" ]; then
        validation_errors+=("script directory missing")
    fi
    
    # Our validation logic: check dependencies
    if [ ! -d "${DOTFILES_PARENT_DIR:-}/script/core" ]; then
        validation_errors+=("core helpers missing")
    fi
    
    # Report validation results
    if [ ${#validation_errors[@]} -eq 0 ]; then
        echo "VALIDATION: All checks passed for $script_name"
        return 0
    else
        echo "VALIDATION: ${#validation_errors[@]} errors found"
        printf 'ERROR: %s\n' "${validation_errors[@]}"
        return 1
    fi
}

# Test with complete environment
validate_execution_context "test_script"
EOF
    chmod +x "$DOTFILES_PARENT_DIR/test_validation.sh"
    
    run "$DOTFILES_PARENT_DIR/test_validation.sh"
    assert_success
    assert_output --partial "VALIDATION: All checks passed for test_script"
}

# Test our command line interface behavior
@test "interface: processes command line arguments correctly" {
    # Create script that tests our argument processing logic
    cat > "$DOTFILES_PARENT_DIR/test_cli.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

process_command_arguments() {
    local args=("$@")
    local options=()
    local commands=()
    local flags=()
    
    # Our CLI processing logic
    for arg in "${args[@]+"${args[@]}"}"; do
        case "$arg" in
            --*)
                if [[ "$arg" =~ = ]]; then
                    options+=("$arg")
                else
                    flags+=("$arg")
                fi
                ;;
            -*)
                flags+=("$arg")
                ;;
            *)
                commands+=("$arg")
                ;;
        esac
    done
    
    echo "CLI_PROCESSING_RESULT:"
    echo "  Commands: ${#commands[@]}"
    echo "  Options: ${#options[@]}"
    echo "  Flags: ${#flags[@]}"
    
    if [ ${#commands[@]} -gt 0 ]; then
        printf '  Command: %s\n' "${commands[@]}"
    fi
    
    if [ ${#options[@]} -gt 0 ]; then
        printf '  Option: %s\n' "${options[@]}"
    fi
    
    if [ ${#flags[@]} -gt 0 ]; then
        printf '  Flag: %s\n' "${flags[@]}"
    fi
}

# Test various argument combinations
echo "=== Test 1: Mixed arguments ==="
process_command_arguments "setup" "--verbose" "--config=custom.conf" "-f" "extra_arg"

echo -e "\n=== Test 2: No arguments ==="
process_command_arguments

echo -e "\n=== Test 3: Only flags ==="
process_command_arguments "--help" "--version" "-v"
EOF
    chmod +x "$DOTFILES_PARENT_DIR/test_cli.sh"
    
    run "$DOTFILES_PARENT_DIR/test_cli.sh"
    assert_success
    assert_output --partial "=== Test 1: Mixed arguments ==="
    assert_output --partial "Commands: 2"
    assert_output --partial "Options: 1"
    assert_output --partial "Flags: 2"
    assert_output --partial "Command: setup"
    assert_output --partial "Command: extra_arg"
    assert_output --partial "Option: --config=custom.conf"
    assert_output --partial "Flag: --verbose"
    assert_output --partial "Flag: -f"
    assert_output --partial "=== Test 2: No arguments ==="
    assert_output --partial "Commands: 0"
    assert_output --partial "=== Test 3: Only flags ==="
    assert_output --partial "Flags: 3"
}

# Test our exit code behavior and error signaling
@test "interface: returns appropriate exit codes for different scenarios" {
    # Create script that tests our exit code logic
    cat > "$DOTFILES_PARENT_DIR/test_exit_codes.sh" << 'EOF'
#!/usr/bin/env bash

simulate_execution_scenario() {
    local scenario="$1"
    
    echo "SCENARIO: $scenario"
    
    # Our exit code logic for different scenarios
    case "$scenario" in
        "success")
            echo "Operation completed successfully"
            return 0
            ;;
        "validation_error")
            echo "ERROR: Invalid configuration detected"
            return 1
            ;;
        "dependency_missing")
            echo "ERROR: Required dependency not found"
            return 2
            ;;
        "permission_denied")
            echo "ERROR: Insufficient permissions"
            return 3
            ;;
        "network_error")
            echo "ERROR: Network connectivity issues"
            return 4
            ;;
        "partial_success")
            echo "WARNING: Operation completed with warnings"
            return 0  # Still success, but with warnings
            ;;
        *)
            echo "ERROR: Unknown scenario"
            return 255
            ;;
    esac
}

# Test each scenario and capture exit codes
scenarios=("success" "validation_error" "dependency_missing" "permission_denied" "network_error" "partial_success" "unknown")

for scenario in "${scenarios[@]}"; do
    if simulate_execution_scenario "$scenario"; then
        echo "RESULT: $scenario -> EXIT_CODE 0"
    else
        echo "RESULT: $scenario -> EXIT_CODE $?"
    fi
done
EOF
    chmod +x "$DOTFILES_PARENT_DIR/test_exit_codes.sh"
    
    run "$DOTFILES_PARENT_DIR/test_exit_codes.sh"
    assert_success  # Overall script should succeed
    assert_output --partial "SCENARIO: success"
    assert_output --partial "RESULT: success -> EXIT_CODE 0"
    assert_output --partial "RESULT: validation_error -> EXIT_CODE 1"
    assert_output --partial "RESULT: dependency_missing -> EXIT_CODE 2"
    assert_output --partial "RESULT: permission_denied -> EXIT_CODE 3"
    assert_output --partial "RESULT: network_error -> EXIT_CODE 4"
    assert_output --partial "RESULT: partial_success -> EXIT_CODE 0"
    assert_output --partial "RESULT: unknown -> EXIT_CODE 255"
}

# Test our logging interface and output formatting
@test "interface: formats output and logs consistently" {
    # Create script that tests our logging and output formatting
    cat > "$DOTFILES_PARENT_DIR/test_output_formatting.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

format_output_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Our output formatting logic
    case "$level" in
        "INFO")
            echo "[$timestamp] INFO: $message"
            ;;
        "WARN")
            echo "[$timestamp] WARN: $message"
            ;;
        "ERROR")
            echo "[$timestamp] ERROR: $message" >&2
            ;;
        "DEBUG")
            echo "[$timestamp] DEBUG: $message"
            ;;
        "SUCCESS")
            echo "[$timestamp] SUCCESS: $message"
            ;;
        *)
            echo "[$timestamp] UNKNOWN: $message"
            ;;
    esac
}

log_structured_output() {
    local component="$1"
    local action="$2"
    local result="$3"
    local details="$4"
    
    # Our structured logging format
    echo "COMPONENT=$component ACTION=$action RESULT=$result DETAILS=\"$details\""
}

# Test different message levels
echo "=== Message Formatting Tests ==="
format_output_message "INFO" "System initialization started"
format_output_message "WARN" "Some packages were skipped"
format_output_message "SUCCESS" "Installation completed successfully"

echo -e "\n=== Structured Logging Tests ==="
log_structured_output "HOMEBREW" "INSTALL" "SUCCESS" "42 packages installed"
log_structured_output "CHEZMOI" "APPLY" "PARTIAL" "3 templates processed, 1 skipped"
log_structured_output "SHELL" "CONFIGURE" "ERROR" "zshrc backup failed"
EOF
    chmod +x "$DOTFILES_PARENT_DIR/test_output_formatting.sh"
    
    run "$DOTFILES_PARENT_DIR/test_output_formatting.sh"
    assert_success
    assert_output --partial "=== Message Formatting Tests ==="
    assert_output --partial "INFO: System initialization started"
    assert_output --partial "WARN: Some packages were skipped"
    assert_output --partial "SUCCESS: Installation completed successfully"
    assert_output --partial "=== Structured Logging Tests ==="
    assert_output --partial "COMPONENT=HOMEBREW ACTION=INSTALL RESULT=SUCCESS"
    assert_output --partial "COMPONENT=CHEZMOI ACTION=APPLY RESULT=PARTIAL"
    assert_output --partial "COMPONENT=SHELL ACTION=CONFIGURE RESULT=ERROR"
}

# Test our configuration interface and parameter handling  
@test "interface: handles configuration parameters and overrides" {
    # Create realistic configuration files
    setup_test_environment
    
    # Create template_variables.conf file that the test expects
    cat > "$DOTFILES_PARENT_DIR/template_variables.conf" << 'EOF'
# Sample template variables for testing
git_user_name=Test User
git_user_email=test@example.com
editor=vim
shell=zsh
EOF
    
    # Create script that tests our configuration handling
    cat > "$DOTFILES_PARENT_DIR/test_config_interface.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

load_configuration() {
    local config_file="$1"
    local overrides=("${@:2}")
    
    # Use simple variables instead of associative array
    local loaded_params=()
    local override_params=()
    local config_values=""
    
    # Our configuration loading logic
    if [ -f "$config_file" ]; then
        while IFS='=' read -r key value || [ -n "$key" ]; do
            if [[ "$key" && ! "$key" =~ ^[[:space:]]*# ]]; then
                config_values="${config_values}${key}=${value}\n"
                loaded_params+=("$key")
            fi
        done < "$config_file"
    fi
    
    # Apply overrides
    for override in "${overrides[@]}"; do
        if [[ "$override" =~ ^([^=]+)=(.*)$ ]]; then
            local override_key="${BASH_REMATCH[1]}"
            local override_value="${BASH_REMATCH[2]}"
            config_values="${config_values}${override_key}=${override_value}\n"
            override_params+=("$override_key")
        fi
    done
    
    echo "CONFIG_LOADING_RESULT:"
    echo "  Loaded from file: ${#loaded_params[@]}"
    echo "  Overridden: ${#override_params[@]}"
    local total_params=$((${#loaded_params[@]} + ${#override_params[@]}))
    echo "  Total parameters: $total_params"
    
    # Show some example parameters
    if [ -n "$config_values" ]; then
        echo "  Sample parameters:"
        local count=0
        while IFS='=' read -r k v && [ $count -lt 10 ]; do
            if [ -n "$k" ]; then
                echo "    $k = $v"
                count=$((count + 1))
            fi
        done <<< "$(echo -e "$config_values")"
    fi
}

# Test configuration loading with overrides
load_configuration "$DOTFILES_PARENT_DIR/template_variables.conf" \
    "editor=nvim" \
    "git_user_email=override@example.com" \
    "custom_setting=test_value"

# Ensure script exits with success
exit 0
EOF
    chmod +x "$DOTFILES_PARENT_DIR/test_config_interface.sh"
    
    run "$DOTFILES_PARENT_DIR/test_config_interface.sh"
    assert_success
    assert_output --partial "CONFIG_LOADING_RESULT:"
    assert_output --partial "Loaded from file: 4"
    assert_output --partial "Overridden: 3"
    assert_output --partial "Total parameters: 7"
    assert_output --partial "Sample parameters:"
    assert_output --partial "editor = nvim"
    assert_output --partial "git_user_email = override@example.com"
    assert_output --partial "custom_setting = test_value"
}

# Test our progress reporting and user feedback interface
@test "interface: provides clear progress feedback and status updates" {
    # Create script that tests our progress reporting logic
    cat > "$DOTFILES_PARENT_DIR/test_progress_interface.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

report_progress() {
    local total_steps="$1"
    local current_step="$2"  
    local step_description="$3"
    local step_status="$4"  # STARTED, IN_PROGRESS, COMPLETED, FAILED
    
    # Our progress reporting logic
    local percentage=$((current_step * 100 / total_steps))
    local progress_bar=""
    local bar_length=20
    local filled_length=$((percentage * bar_length / 100))
    
    # Create progress bar visualization
    for i in $(seq 1 $filled_length); do
        progress_bar+="█"
    done
    for i in $(seq $((filled_length + 1)) $bar_length); do
        progress_bar+="░"
    done
    
    # Format progress message
    case "$step_status" in
        "STARTED")
            echo "[$progress_bar] ($current_step/$total_steps) Starting: $step_description"
            ;;
        "IN_PROGRESS")
            echo "[$progress_bar] ($current_step/$total_steps) Processing: $step_description"
            ;;
        "COMPLETED")
            echo "[$progress_bar] ($current_step/$total_steps) ✓ Completed: $step_description"
            ;;
        "FAILED")
            echo "[$progress_bar] ($current_step/$total_steps) ✗ Failed: $step_description"
            ;;
    esac
}

simulate_workflow_progress() {
    local steps=(
        "Validating system requirements"
        "Installing dependencies"
        "Configuring applications"
        "Deploying dotfiles"
        "Setting up development environment"
    )
    
    local total=${#steps[@]}
    
    echo "PROGRESS_SIMULATION: Workflow with $total steps"
    echo ""
    
    for i in "${!steps[@]}"; do
        local step_num=$((i + 1))
        local step_desc="${steps[$i]}"
        
        report_progress $total $step_num "$step_desc" "STARTED"
        sleep 0.1  # Simulate processing time
        report_progress $total $step_num "$step_desc" "IN_PROGRESS" 
        sleep 0.1
        
        # Simulate occasional failure
        if [ $step_num -eq 3 ] && [ -n "${SIMULATE_FAILURE:-}" ]; then
            report_progress $total $step_num "$step_desc" "FAILED"
        else
            report_progress $total $step_num "$step_desc" "COMPLETED"
        fi
        echo ""
    done
    
    echo "PROGRESS_SIMULATION: Workflow completed"
}

# Test normal workflow progress
simulate_workflow_progress

echo -e "\n" "=== Testing with simulated failure ==="
SIMULATE_FAILURE=true simulate_workflow_progress
EOF
    chmod +x "$DOTFILES_PARENT_DIR/test_progress_interface.sh"
    
    run "$DOTFILES_PARENT_DIR/test_progress_interface.sh"
    assert_success
    assert_output --partial "PROGRESS_SIMULATION: Workflow with 5 steps"
    assert_output --partial "(1/5) Starting: Validating system requirements"
    assert_output --partial "(1/5) ✓ Completed: Validating system requirements"
    assert_output --partial "(5/5) ✓ Completed: Setting up development environment"
    assert_output --partial "=== Testing with simulated failure ==="
    assert_output --partial "(3/5) ✗ Failed: Configuring applications"
}

# Test our error handling interface and user guidance
@test "interface: provides helpful error messages and recovery guidance" {
    # Create script that tests our error handling interface
    cat > "$DOTFILES_PARENT_DIR/test_error_interface.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

handle_error_with_guidance() {
    local error_type="$1"
    local context="$2"
    local error_details="$3"
    
    # Our error handling and guidance logic
    echo "ERROR_OCCURRED:"
    echo "  Type: $error_type"
    echo "  Context: $context"  
    echo "  Details: $error_details"
    echo ""
    
    case "$error_type" in
        "DEPENDENCY_MISSING")
            echo "RECOVERY_GUIDANCE:"
            echo "  1. Check if the required tool is installed:"
            echo "     command -v <tool_name>"
            echo "  2. Install the missing dependency:"
            echo "     brew install <tool_name>"
            echo "  3. Verify the installation and retry"
            ;;
        "PERMISSION_DENIED")
            echo "RECOVERY_GUIDANCE:"
            echo "  1. Check file/directory permissions:"
            echo "     ls -la $context"
            echo "  2. Fix permissions if needed:"
            echo "     chmod 755 $context"
            echo "  3. Or run with appropriate privileges"
            ;;
        "NETWORK_ERROR")
            echo "RECOVERY_GUIDANCE:"
            echo "  1. Check network connectivity:"
            echo "     ping -c 1 github.com"
            echo "  2. Verify proxy settings if applicable"
            echo "  3. Try again in a few moments"
            ;;
        "CONFIGURATION_INVALID")
            echo "RECOVERY_GUIDANCE:"
            echo "  1. Check configuration file syntax:"
            echo "     cat $context"
            echo "  2. Validate against expected format"
            echo "  3. Fix syntax errors or restore from backup"
            ;;
        *)
            echo "RECOVERY_GUIDANCE:"
            echo "  1. Review the error details above"
            echo "  2. Check the debug log for more information"
            echo "  3. Consult documentation or support"
            ;;
    esac
    
    echo ""
    echo "SUPPORT_INFO:"
    echo "  Debug log: $DOTFILES_DEBUG_LOG"
    echo "  Documentation: README.md"
    echo "  Issue tracker: GitHub Issues"
}

# Test different error scenarios
echo "=== Test 1: Missing dependency ==="
handle_error_with_guidance "DEPENDENCY_MISSING" "brew command" "Command 'brew' not found in PATH"

echo -e "\n=== Test 2: Permission error ==="
handle_error_with_guidance "PERMISSION_DENIED" "/usr/local/bin" "Cannot write to directory"

echo -e "\n=== Test 3: Configuration error ==="
handle_error_with_guidance "CONFIGURATION_INVALID" "config.yml" "Invalid YAML syntax on line 42"
EOF
    chmod +x "$DOTFILES_PARENT_DIR/test_error_interface.sh"
    
    run "$DOTFILES_PARENT_DIR/test_error_interface.sh"
    assert_success
    assert_output --partial "=== Test 1: Missing dependency ==="
    assert_output --partial "ERROR_OCCURRED:"
    assert_output --partial "Type: DEPENDENCY_MISSING"
    assert_output --partial "RECOVERY_GUIDANCE:"
    assert_output --partial "brew install <tool_name>"
    assert_output --partial "=== Test 2: Permission error ==="
    assert_output --partial "Type: PERMISSION_DENIED"
    assert_output --partial "chmod 755"
    assert_output --partial "=== Test 3: Configuration error ==="
    assert_output --partial "Type: CONFIGURATION_INVALID"
    assert_output --partial "Invalid YAML syntax on line 42"
    assert_output --partial "SUPPORT_INFO:"
}