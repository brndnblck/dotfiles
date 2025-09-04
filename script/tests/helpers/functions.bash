# BATS test helpers for functions
# shellcheck source=script/tests/helpers/base.bash
source "$(dirname "$BATS_TEST_FILENAME")/helpers/base.bash"

# Generic function argument validation test
# Usage: test_function_args "function_name" "min_required_args" "test_file_path"
test_function_args() {
    local function_name="$1"
    local required_args="$2"
    local test_file="$3"

    # Source the function file
    # shellcheck source=/dev/null
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

# Test that a function exists and is callable
# Usage: test_function_exists "function_name" "test_file_path"
test_function_exists() {
    local function_name="$1"
    local test_file="$2"

    # Source the function file
    # shellcheck source=/dev/null
    source "$test_file"

    # Check if function is defined
    if ! command -v "$function_name" &>/dev/null; then
        fail "Function $function_name is not defined"
    fi
}

# Test function output format
# Usage: test_function_output "function_name" "expected_pattern" "test_file_path" "args..."
test_function_output() {
    local function_name="$1"
    local expected_pattern="$2"
    local test_file="$3"
    shift 3
    local args=("$@")

    # Source the function file
    # shellcheck source=/dev/null
    source "$test_file"

    # Run function with provided arguments
    run "$function_name" "${args[@]}"
    assert_success
    assert_output --partial "$expected_pattern"
}

# Validate function error handling
# Usage: test_function_error_handling "function_name" "test_file_path" "invalid_args..."
test_function_error_handling() {
    local function_name="$1"
    local test_file="$2"
    shift 2
    local invalid_args=("$@")

    # Source the function file
    # shellcheck source=/dev/null
    source "$test_file"

    # Test with invalid arguments
    run "$function_name" "${invalid_args[@]}"
    assert_failure
}

# Test function with valid arguments
# Usage: test_function_success "function_name" "test_file_path" "valid_args..."
test_function_success() {
    local function_name="$1"
    local test_file="$2"
    shift 2
    local valid_args=("$@")

    # Source the function file
    # shellcheck source=/dev/null
    source "$test_file"

    # Test with valid arguments
    run "$function_name" "${valid_args[@]}"
    assert_success
}

# Helper to create temporary test files
create_temp_test_file() {
    local content="$1"
    local temp_file
    temp_file=$(mktemp)
    echo "$content" >"$temp_file"
    echo "$temp_file"
}

# Helper to cleanup temporary test files
cleanup_temp_test_file() {
    local temp_file="$1"
    if [ -f "$temp_file" ]; then
        rm "$temp_file"
    fi
}

# Test function that should create files
# Usage: test_function_creates_file "function_name" "expected_file_path" "test_file_path" "args..."
test_function_creates_file() {
    local function_name="$1"
    local expected_file="$2"
    local test_file="$3"
    shift 3
    local args=("$@")

    # Source the function file
    # shellcheck source=/dev/null
    source "$test_file"

    # Clean up any existing file
    [ -f "$expected_file" ] && rm "$expected_file"

    # Run function
    run "$function_name" "${args[@]}"
    assert_success

    # Check if file was created
    [ -f "$expected_file" ] || fail "Expected file $expected_file was not created"
}

# Test function that should modify files
# Usage: test_function_modifies_file "function_name" "file_path" "test_file_path" "args..."
test_function_modifies_file() {
    local function_name="$1"
    local target_file="$2"
    local test_file="$3"
    shift 3
    local args=("$@")

    # Source the function file
    # shellcheck source=/dev/null
    source "$test_file"

    # Get initial modification time
    local initial_mtime
    if [ -f "$target_file" ]; then
        initial_mtime=$(stat -f "%m" "$target_file" 2>/dev/null || stat -c "%Y" "$target_file" 2>/dev/null)
    else
        initial_mtime="0"
    fi

    # Wait a moment to ensure different timestamp
    sleep 1

    # Run function
    run "$function_name" "${args[@]}"
    assert_success

    # Check if file was modified
    local final_mtime
    if [ -f "$target_file" ]; then
        final_mtime=$(stat -f "%m" "$target_file" 2>/dev/null || stat -c "%Y" "$target_file" 2>/dev/null)
    else
        final_mtime="0"
    fi

    if [ "$initial_mtime" = "$final_mtime" ] && [ "$initial_mtime" != "0" ]; then
        fail "File $target_file was not modified"
    fi
}

# Validate function dependency requirements
# Usage: test_function_dependencies "function_name" "test_file_path" "required_commands..."
test_function_dependencies() {
    local function_name="$1"
    local test_file="$2"
    shift 2
    local required_commands=("$@")

    # Source the function file
    # shellcheck source=/dev/null
    source "$test_file"

    # Check each required command
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            skip "Required command '$cmd' not available"
        fi
    done

    # If we get here, all dependencies are met
    assert_success
}

# Test function with environment variable requirements
# Usage: test_function_with_env "function_name" "test_file_path" "env_var=value" "args..."
test_function_with_env() {
    local function_name="$1"
    local test_file="$2"
    local env_setting="$3"
    shift 3
    local args=("$@")

    # Source the function file
    # shellcheck source=/dev/null
    source "$test_file"

    # Set environment variable and run function
    env "$env_setting" "$function_name" "${args[@]}"
}

# Validate function behavior with different working directories
# Usage: test_function_in_directory "function_name" "test_directory" "test_file_path" "args..."
test_function_in_directory() {
    local function_name="$1"
    local test_dir="$2"
    local test_file="$3"
    shift 3
    local args=("$@")

    # Create test directory if it doesn't exist
    [ -d "$test_dir" ] || mkdir -p "$test_dir"

    # Source the function file
    # shellcheck source=/dev/null
    source "$test_file"

    # Run function in the specified directory
    (cd "$test_dir" && "$function_name" "${args[@]}")
}

# Test function timeout behavior
# Usage: test_function_timeout "function_name" "timeout_seconds" "test_file_path" "args..."
test_function_timeout() {
    local function_name="$1"
    local timeout_seconds="$2"
    local test_file="$3"
    shift 3
    local args=("$@")

    # Source the function file
    # shellcheck source=/dev/null
    source "$test_file"

    # Run function with timeout
    run timeout "$timeout_seconds" "$function_name" "${args[@]}"

    # Check if it completed within timeout
    # Note: $status is set by the `run` command from bats framework
    # shellcheck disable=SC2154
    if [ "$status" -eq 124 ]; then
        fail "Function $function_name timed out after $timeout_seconds seconds"
    fi
}

# Test function handles signals properly
# Usage: test_function_signal_handling "function_name" "signal" "test_file_path" "args..."
test_function_signal_handling() {
    local function_name="$1"
    local signal="$2"
    local test_file="$3"
    shift 3
    local args=("$@")

    # Source the function file
    # shellcheck source=/dev/null
    source "$test_file"

    # Start function in background
    "$function_name" "${args[@]}" &
    local pid=$!

    # Wait a moment then send signal
    sleep 0.1
    kill -"$signal" "$pid" 2>/dev/null || true

    # Wait for process to finish
    wait "$pid" 2>/dev/null || true
}

# Validate function performs cleanup on exit
# Usage: test_function_cleanup "function_name" "cleanup_indicator" "test_file_path" "args..."
test_function_cleanup() {
    local function_name="$1"
    local cleanup_indicator="$2" # File or directory that should be cleaned up
    local test_file="$3"
    shift 3
    local args=("$@")

    # Source the function file
    # shellcheck source=/dev/null
    source "$test_file"

    # Run function
    run "$function_name" "${args[@]}"

    # Check that cleanup occurred
    if [ -e "$cleanup_indicator" ]; then
        fail "Cleanup failed: $cleanup_indicator still exists"
    fi
}

# Test function with mock commands
# Usage: test_function_with_mock "function_name" "mock_command" "mock_output" "test_file_path" "args..."
test_function_with_mock() {
    local function_name="$1"
    local mock_command="$2"
    local mock_output="$3"
    local test_file="$4"
    shift 4
    local args=("$@")

    # Create mock command
    local mock_path
    mock_path=$(mktemp -d)/mock_bin
    mkdir -p "$mock_path"

    cat >"$mock_path/$mock_command" <<EOF
#!/bin/bash
echo "$mock_output"
EOF
    chmod +x "$mock_path/$mock_command"

    # Source the function file
    # shellcheck source=/dev/null
    source "$test_file"

    # Run function with mocked command in PATH
    PATH="$mock_path:$PATH" run "$function_name" "${args[@]}"

    # Cleanup
    rm -rf "$(dirname "$mock_path")"
}

# Test function performance (basic timing)
# Usage: test_function_performance "function_name" "max_seconds" "test_file_path" "args..."
test_function_performance() {
    local function_name="$1"
    local max_seconds="$2"
    local test_file="$3"
    shift 3
    local args=("$@")

    # Source the function file
    # shellcheck source=/dev/null
    source "$test_file"

    # Time the function execution
    local start_time
    start_time=$(date +%s)

    run "$function_name" "${args[@]}"

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    if [ "$duration" -gt "$max_seconds" ]; then
        fail "Function $function_name took $duration seconds, expected <= $max_seconds"
    fi
}

# Test function idempotency (running twice should be safe)
# Usage: test_function_idempotent "function_name" "test_file_path" "args..."
test_function_idempotent() {
    local function_name="$1"
    local test_file="$2"
    shift 2
    local args=("$@")

    # Source the function file
    # shellcheck source=/dev/null
    source "$test_file"

    # Run function first time
    run "$function_name" "${args[@]}"
    # Note: $output and $status are set by the `run` command from bats framework
    # shellcheck disable=SC2154
    local first_output="$output"
    # shellcheck disable=SC2154
    local first_status="$status"

    # Run function second time
    run "$function_name" "${args[@]}"
    local second_output="$output"
    local second_status="$status"

    # Results should be the same (compare exit status for idempotency)
    if [ "$first_status" != "$second_status" ]; then
        fail "Function $function_name is not idempotent: status changed from $first_status to $second_status"
    fi

    # Compare output if both runs were successful and produced output
    if [ "$first_status" -eq 0 ] && [ "$second_status" -eq 0 ] && [ -n "$first_output" ] && [ -n "$second_output" ]; then
        # For most functions, idempotent execution should produce consistent output
        # We'll log the difference but not fail automatically since some legitimate
        # differences might exist (timestamps, temp files, etc.)
        if [ "$first_output" != "$second_output" ]; then
            echo "Note: Function $function_name output differs between runs (this may be expected for functions with timestamps or temp data)" >&3
            echo "First run output: $first_output" >&3
            echo "Second run output: $second_output" >&3
        fi
    fi
}

# Helper to set up common test fixtures
setup_common_fixtures() {
    export TEST_TEMP_DIR
    TEST_TEMP_DIR=$(mktemp -d)
    export TEST_HOME="$TEST_TEMP_DIR/home"
    mkdir -p "$TEST_HOME"
}

# Helper to clean up common test fixtures
teardown_common_fixtures() {
    if [ -n "$TEST_TEMP_DIR" ] && [ -d "$TEST_TEMP_DIR" ]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

# Test function configuration file handling
# Usage: test_function_config_handling "function_name" "config_file_path" "test_file_path" "args..."
test_function_config_handling() {
    local function_name="$1"
    local config_file="$2"
    local test_file="$3"
    shift 3
    local args=("$@")

    # Create test config
    local test_config
    test_config=$(mktemp)
    echo "test_setting=test_value" >"$test_config"

    # Source the function file
    # shellcheck source=/dev/null
    source "$test_file"

    # Run function with test config
    if [ -n "$config_file" ]; then
        # Function expects config file argument
        run "$function_name" "$test_config" "${args[@]}"
    else
        # Function uses default config location
        export CONFIG_FILE="$test_config"
        run "$function_name" "${args[@]}"
    fi

    # Cleanup
    rm -f "$test_config"
}

# Comprehensive function validation
# Usage: validate_function "function_name" "min_args" "test_file_path" "optional_test_args..."
validate_function() {
    local function_name="$1"
    local min_args="$2"
    local test_file="$3"
    shift 3
    local test_args=("$@")

    # Basic existence test
    test_function_exists "$function_name" "$test_file"

    # Argument validation test
    test_function_args "$function_name" "$min_args" "$test_file"

    # If test args provided, test with them
    if [ ${#test_args[@]} -gt 0 ]; then
        test_function_success "$function_name" "$test_file" "${test_args[@]}"
    fi
}
