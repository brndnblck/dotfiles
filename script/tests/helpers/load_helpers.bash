#!/usr/bin/env bash

# Common helper loading function for all test files
# This ensures consistent helper loading across the reorganized test structure

load_test_helpers() {
    local helper_names=("${@:-helper mocks}")
    
    # Find tests directory - handle empty BATS_TEST_DIRNAME and prevent infinite loops
    local CURRENT_DIR="${BATS_TEST_DIRNAME:-$(dirname "${BASH_SOURCE[1]}")}"
    local TESTS_DIR=""
    local iteration_count=0
    local max_iterations=20  # Prevent infinite loops
    
    while [[ "$CURRENT_DIR" != "/" && $iteration_count -lt $max_iterations ]]; do
        if [[ -d "$CURRENT_DIR/helpers" ]]; then
            TESTS_DIR="$CURRENT_DIR"
            break
        fi
        local NEW_DIR="$(dirname "$CURRENT_DIR")"
        # Prevent infinite loops when dirname doesn't change
        if [[ "$NEW_DIR" == "$CURRENT_DIR" ]]; then
            break
        fi
        CURRENT_DIR="$NEW_DIR"
        ((iteration_count++))
    done

    # Fallback if not found
    if [[ -z "$TESTS_DIR" ]]; then
        # Try to find helpers directory from current script location
        local SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
        while [[ "$SCRIPT_DIR" != "/" ]]; do
            if [[ -d "$SCRIPT_DIR/helpers" ]]; then
                TESTS_DIR="$SCRIPT_DIR"
                break
            fi
            if [[ -d "$SCRIPT_DIR/script/tests/helpers" ]]; then
                TESTS_DIR="$SCRIPT_DIR/script/tests"
                break
            fi
            SCRIPT_DIR="$(dirname "$SCRIPT_DIR")"
        done
    fi

    # Final fallback - use absolute path
    if [[ -z "$TESTS_DIR" ]]; then
        # Find the actual tests directory in the project
        local PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
        if [[ -d "$PROJECT_ROOT/script/tests/helpers" ]]; then
            TESTS_DIR="$PROJECT_ROOT/script/tests"
        else
            echo "ERROR: Could not locate tests helpers directory" >&2
            return 1
        fi
    fi

    # Load the helpers
    for helper_name in "${helper_names[@]}"; do
        if [[ -f "$TESTS_DIR/helpers/${helper_name}.bash" ]]; then
            load "$TESTS_DIR/helpers/${helper_name}.bash"
        elif [[ -f "$TESTS_DIR/helpers/${helper_name}" ]]; then
            load "$TESTS_DIR/helpers/${helper_name}"
        else
            echo "WARNING: Helper not found: $TESTS_DIR/helpers/${helper_name}" >&2
        fi
    done
    
    # Export for use in tests
    export TESTS_DIR
}

# For backward compatibility, auto-load common helpers
load_test_helpers