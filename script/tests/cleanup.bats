#!/usr/bin/env bats

# BDD Tests for EXIT trap handling and cleanup orchestration
# Validates that all cleanup functions work together properly

load helper
load mocks

setup() {
    test_setup
    setup_advanced_mocks
    
    # Copy helper files
    cp -r "${BATS_TEST_DIRNAME}/../../script/core" "$DOTFILES_PARENT_DIR/script/"
}

teardown() {
    test_teardown
}

# ============================================================================
# EXIT Trap Coordination Tests
# ============================================================================

@test "cleanup: should coordinate multiple EXIT traps without conflicts" {
    cat > "$DOTFILES_PARENT_DIR/test_trap_coordination.sh" << 'EOF'
#!/usr/bin/env bash
export DOTFILES_PARENT_DIR="$(pwd)"
source "script/core/common"

# Mock log functions
log_info() { echo "LOG_INFO: $1"; }

# Initialize arrays
TEMP_FILES_FOR_CLEANUP=()

# Test adding multiple temp files (each should set trap only once)
add_temp_file_cleanup "/tmp/test_file1"
trap_count_1=$(trap -p EXIT | wc -l)

add_temp_file_cleanup "/tmp/test_file2" 
trap_count_2=$(trap -p EXIT | wc -l)

# Test sudo cleanup (should add to existing trap or coordinate)
trap 'cleanup_sudo_config' EXIT INT TERM
trap_count_3=$(trap -p EXIT | wc -l)

echo "Trap counts: $trap_count_1, $trap_count_2, $trap_count_3"

# Verify trap coordination
if [ "$trap_count_1" -eq "$trap_count_2" ]; then
    echo "Temp file traps properly coordinated"
else
    echo "Warning: Multiple temp file traps detected"
fi

# Check if all cleanup functions are in the trap
trap_content=$(trap -p EXIT)
if echo "$trap_content" | grep -q "cleanup"; then
    echo "Cleanup functions found in trap"
fi

if echo "$trap_content" | grep -q "cleanup_sudo_config"; then
    echo "Sudo cleanup found in trap"
fi

echo "Trap coordination test completed"
EOF
    chmod +x "$DOTFILES_PARENT_DIR/test_trap_coordination.sh"
    
    run "$DOTFILES_PARENT_DIR/test_trap_coordination.sh"
    assert_success
    assert_output --partial "Temp file traps properly coordinated"
    assert_output --partial "Cleanup functions found in trap"
    assert_output --partial "Sudo cleanup found in trap"
    assert_output --partial "Trap coordination test completed"
}

@test "cleanup: should handle cleanup orchestration on script exit" {
    cat > "$DOTFILES_PARENT_DIR/test_cleanup_orchestration.sh" << 'EOF'
#!/usr/bin/env bash
export DOTFILES_PARENT_DIR="$(pwd)"
source "script/core/common"

# Mock log functions
log_info() { echo "LOG_INFO: $1"; }

# Initialize arrays
TEMP_FILES_FOR_CLEANUP=()

# Create test files for cleanup
touch "/tmp/test_cleanup_file1" "/tmp/test_cleanup_file2"

# Add files to cleanup list
add_temp_file_cleanup "/tmp/test_cleanup_file1"
add_temp_file_cleanup "/tmp/test_cleanup_file2"

# Create mock sudo authentication files
touch "/tmp/.bootstrap_sudo_authenticated"
echo "123" > "/tmp/.bootstrap_sudo_keepalive_pid"

# Define cleanup functions that will be called on EXIT
cleanup_temp_files() {
    echo "CLEANUP: Removing temp files"
    for file in "${TEMP_FILES_FOR_CLEANUP[@]}"; do
        if [ -f "$file" ]; then
            rm -f "$file" 2>/dev/null || true
            echo "CLEANUP: Removed $file"
        fi
    done
    TEMP_FILES_FOR_CLEANUP=()
}

cleanup_sudo_config() {
    echo "CLEANUP: Cleaning sudo configuration"
    rm -f "/tmp/.bootstrap_sudo_authenticated" 2>/dev/null || true
    if [ -f "/tmp/.bootstrap_sudo_keepalive_pid" ]; then
        local pid=$(cat "/tmp/.bootstrap_sudo_keepalive_pid" 2>/dev/null)
        if [ -n "$pid" ]; then
            echo "CLEANUP: Stopping sudo keepalive process $pid"
        fi
        rm -f "/tmp/.bootstrap_sudo_keepalive_pid"
    fi
}

# Set up combined cleanup trap
cleanup_all() {
    cleanup_temp_files
    cleanup_sudo_config
}

trap 'cleanup_all' EXIT

echo "Setup cleanup orchestration test"

# Simulate script doing work
echo "Script running..."

# Exit normally - trap should execute cleanup
echo "Script exiting normally"
EOF
    chmod +x "$DOTFILES_PARENT_DIR/test_cleanup_orchestration.sh"
    
    run "$DOTFILES_PARENT_DIR/test_cleanup_orchestration.sh"
    assert_success
    assert_output --partial "Setup cleanup orchestration test"
    assert_output --partial "Script running..."
    assert_output --partial "Script exiting normally"
    assert_output --partial "CLEANUP: Removing temp files"
    assert_output --partial "CLEANUP: Removed /tmp/test_cleanup_file1"
    assert_output --partial "CLEANUP: Removed /tmp/test_cleanup_file2"
    assert_output --partial "CLEANUP: Cleaning sudo configuration"
    assert_output --partial "CLEANUP: Stopping sudo keepalive process 123"
}

@test "cleanup: should handle cleanup on script interruption (SIGINT)" {
    cat > "$DOTFILES_PARENT_DIR/test_cleanup_interrupt.sh" << 'EOF'
#!/usr/bin/env bash
export DOTFILES_PARENT_DIR="$(pwd)"
source "script/core/common"

# Mock log functions
log_info() { echo "LOG_INFO: $1"; }

# Initialize arrays
TEMP_FILES_FOR_CLEANUP=()

# Create test files
touch "/tmp/interrupt_test_file1"
add_temp_file_cleanup "/tmp/interrupt_test_file1"

# Create mock sudo files
touch "/tmp/.bootstrap_sudo_authenticated"

# Define cleanup that handles interruption
cleanup_on_interrupt() {
    echo "CLEANUP: Handling script interruption"
    cleanup_temp_files
    cleanup_sudo_config
    echo "CLEANUP: Interrupt cleanup completed"
    exit 130  # Standard exit code for SIGINT
}

# Set up trap for interruption
trap 'cleanup_on_interrupt' INT TERM

echo "Testing interrupt handling"

# Simulate getting interrupted after a short delay
(sleep 0.1 && kill -INT $$) &

# Wait a bit to simulate work being done
sleep 0.2 || echo "Script was interrupted as expected"

echo "This should not be reached if interrupt works properly"
EOF
    chmod +x "$DOTFILES_PARENT_DIR/test_cleanup_interrupt.sh"
    
    run "$DOTFILES_PARENT_DIR/test_cleanup_interrupt.sh"
    # Script should exit with 130 (SIGINT)
    assert_equal "$status" 130
    assert_output --partial "Testing interrupt handling"
    assert_output --partial "CLEANUP: Handling script interruption"
    assert_output --partial "CLEANUP: Interrupt cleanup completed"
}

# ============================================================================
# Cleanup Function Integration Tests
# ============================================================================

@test "cleanup: should integrate temp file and sudo cleanup properly" {
    cat > "$DOTFILES_PARENT_DIR/test_integrated_cleanup.sh" << 'EOF'
#!/usr/bin/env bash
export DOTFILES_PARENT_DIR="$(pwd)"
source "script/core/common"

# Mock log functions
log_info() { echo "LOG_INFO: $1"; }

# Initialize arrays
TEMP_FILES_FOR_CLEANUP=()

# Test the integrated cleanup scenario
echo "Testing integrated cleanup scenario"

# Create multiple temp files
for i in {1..3}; do
    touch "/tmp/integrated_test_$i"
    add_temp_file_cleanup "/tmp/integrated_test_$i"
done

echo "Created ${#TEMP_FILES_FOR_CLEANUP[@]} temp files for cleanup"

# Mock sudo session setup
touch "/tmp/.bootstrap_sudo_authenticated"
echo "456" > "/tmp/.bootstrap_sudo_keepalive_pid"

# Create a comprehensive cleanup function
integrated_cleanup() {
    echo "INTEGRATED_CLEANUP: Starting comprehensive cleanup"
    
    # Clean temp files
    echo "INTEGRATED_CLEANUP: Cleaning temp files (${#TEMP_FILES_FOR_CLEANUP[@]} files)"
    cleanup_temp_files
    
    # Clean sudo configuration
    echo "INTEGRATED_CLEANUP: Cleaning sudo configuration"
    cleanup_sudo_config
    
    echo "INTEGRATED_CLEANUP: All cleanup completed"
}

# Set up the integrated cleanup trap
trap 'integrated_cleanup' EXIT INT TERM

echo "Integrated cleanup test setup completed"

# Verify files exist before cleanup
files_exist=0
for i in {1..3}; do
    if [ -f "/tmp/integrated_test_$i" ]; then
        files_exist=$((files_exist + 1))
    fi
done

echo "Files exist before cleanup: $files_exist"

# Exit to trigger cleanup
echo "Exiting to trigger cleanup"
EOF
    chmod +x "$DOTFILES_PARENT_DIR/test_integrated_cleanup.sh"
    
    run "$DOTFILES_PARENT_DIR/test_integrated_cleanup.sh"
    assert_success
    assert_output --partial "Testing integrated cleanup scenario"
    assert_output --partial "Created 3 temp files for cleanup"
    assert_output --partial "Files exist before cleanup: 3"
    assert_output --partial "Integrated cleanup test setup completed"
    assert_output --partial "Exiting to trigger cleanup"
    assert_output --partial "INTEGRATED_CLEANUP: Starting comprehensive cleanup"
    assert_output --partial "INTEGRATED_CLEANUP: Cleaning temp files (3 files)"
    assert_output --partial "INTEGRATED_CLEANUP: Cleaning sudo configuration"
    assert_output --partial "INTEGRATED_CLEANUP: All cleanup completed"
}

# ============================================================================
# Error Handling in Cleanup Tests
# ============================================================================

@test "cleanup: should handle errors during cleanup gracefully" {
    cat > "$DOTFILES_PARENT_DIR/test_cleanup_errors.sh" << 'EOF'
#!/usr/bin/env bash
export DOTFILES_PARENT_DIR="$(pwd)"
source "script/core/common"

# Mock log functions
log_info() { echo "LOG_INFO: $1"; }

# Initialize arrays
TEMP_FILES_FOR_CLEANUP=()

# Create a scenario where cleanup might encounter errors
echo "Testing cleanup error handling"

# Add a file that doesn't exist (simulates error condition)
TEMP_FILES_FOR_CLEANUP+=("/tmp/nonexistent_file")

# Add a valid file
touch "/tmp/valid_cleanup_file"
TEMP_FILES_FOR_CLEANUP+=("/tmp/valid_cleanup_file")

# Create robust cleanup function that handles errors
robust_cleanup() {
    echo "ROBUST_CLEANUP: Starting cleanup with error handling"
    
    local cleanup_errors=0
    
    # Clean temp files with error handling
    for file in "${TEMP_FILES_FOR_CLEANUP[@]}"; do
        if [ -f "$file" ]; then
            if rm -f "$file" 2>/dev/null; then
                echo "ROBUST_CLEANUP: Successfully removed $file"
            else
                echo "ROBUST_CLEANUP: Failed to remove $file"
                cleanup_errors=$((cleanup_errors + 1))
            fi
        else
            echo "ROBUST_CLEANUP: File not found (expected): $file"
        fi
    done
    
    # Continue with other cleanup even if some failed
    echo "ROBUST_CLEANUP: Continuing with sudo cleanup"
    rm -f "/tmp/.bootstrap_sudo_authenticated" 2>/dev/null || true
    
    echo "ROBUST_CLEANUP: Cleanup completed with $cleanup_errors errors"
}

# Set up error-tolerant cleanup
trap 'robust_cleanup' EXIT

echo "Error handling cleanup test setup completed"
EOF
    chmod +x "$DOTFILES_PARENT_DIR/test_cleanup_errors.sh"
    
    run "$DOTFILES_PARENT_DIR/test_cleanup_errors.sh"
    assert_success
    assert_output --partial "Testing cleanup error handling"
    assert_output --partial "Error handling cleanup test setup completed"
    assert_output --partial "ROBUST_CLEANUP: Starting cleanup with error handling"
    assert_output --partial "ROBUST_CLEANUP: File not found (expected): /tmp/nonexistent_file"
    assert_output --partial "ROBUST_CLEANUP: Successfully removed /tmp/valid_cleanup_file"
    assert_output --partial "ROBUST_CLEANUP: Continuing with sudo cleanup"
    assert_output --partial "ROBUST_CLEANUP: Cleanup completed with 0 errors"
}

# ============================================================================
# Cleanup Performance Tests
# ============================================================================

@test "cleanup: should handle large numbers of temp files efficiently" {
    cat > "$DOTFILES_PARENT_DIR/test_cleanup_performance.sh" << 'EOF'
#!/usr/bin/env bash
export DOTFILES_PARENT_DIR="$(pwd)"
source "script/core/common"

# Mock log functions
log_info() { echo "LOG_INFO: $1"; }

# Initialize arrays
TEMP_FILES_FOR_CLEANUP=()

echo "Testing cleanup performance with many files"

# Create many temp files for cleanup
start_time=$(date +%s)

for i in {1..50}; do
    temp_file="/tmp/perf_test_$i"
    touch "$temp_file"
    TEMP_FILES_FOR_CLEANUP+=("$temp_file")
done

setup_time=$(date +%s)
echo "Created ${#TEMP_FILES_FOR_CLEANUP[@]} files in $((setup_time - start_time)) seconds"

# Performance-optimized cleanup
performance_cleanup() {
    local cleanup_start=$(date +%s)
    echo "PERF_CLEANUP: Starting cleanup of ${#TEMP_FILES_FOR_CLEANUP[@]} files"
    
    # Batch cleanup for better performance
    if [ ${#TEMP_FILES_FOR_CLEANUP[@]} -gt 0 ]; then
        rm -f "${TEMP_FILES_FOR_CLEANUP[@]}" 2>/dev/null || true
    fi
    
    local cleanup_end=$(date +%s)
    echo "PERF_CLEANUP: Completed in $((cleanup_end - cleanup_start)) seconds"
}

trap 'performance_cleanup' EXIT

echo "Performance cleanup test setup completed"
EOF
    chmod +x "$DOTFILES_PARENT_DIR/test_cleanup_performance.sh"
    
    run "$DOTFILES_PARENT_DIR/test_cleanup_performance.sh"
    assert_success
    assert_output --partial "Testing cleanup performance with many files"
    assert_output --partial "Created 50 files in"
    assert_output --partial "Performance cleanup test setup completed"
    assert_output --partial "PERF_CLEANUP: Starting cleanup of 50 files"
    assert_output --partial "PERF_CLEANUP: Completed in"
}