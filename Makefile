# Makefile for dotfiles project
# Provides targets for testing, linting, and formatting shell scripts

# Configuration
SHELL := /bin/bash
.DEFAULT_GOAL := help
.PHONY: help test lint fmt fmt-check clean setup deps

# Project paths
PROJECT_ROOT := $(shell pwd)
SCRIPT_DIR := $(PROJECT_ROOT)/script
TEST_DIR := $(PROJECT_ROOT)/script/tests
BATS_PATH := $(TEST_DIR)/support/bats-core/bin/bats

# Use ansi helper directly for colored output
ANSI := script/core/ansi

# Common find patterns - centralized to eliminate duplication
FIND_EXCLUDE_PATHS := \( -path "$(TEST_DIR)/support" -o -path "*/vendor" -o -path "*/node_modules" -o -path "*/.git" \) -prune -o
FIND_SHELL_SCRIPTS := find "$(SCRIPT_DIR)" $(FIND_EXCLUDE_PATHS) -type f \( -name "*.sh" -o -name "*.bash" \) -print 2>/dev/null
FIND_EXECUTABLE_SCRIPTS := find "$(SCRIPT_DIR)" $(FIND_EXCLUDE_PATHS) -type f -perm +111 -exec file {} \; 2>/dev/null | grep -E "(shell|bash)" | cut -d: -f1
FIND_TEST_FILES := find "$(TEST_DIR)" -name "*.bats" 2>/dev/null | grep -v "/support/"

# Find all shell scripts to process (excluding vendor directories)
SHELL_SCRIPTS_RAW := $(shell $(FIND_SHELL_SCRIPTS))
SHELL_SCRIPTS_RAW += $(shell $(FIND_EXECUTABLE_SCRIPTS))

# Helper scripts (exclude from some checks)
HELPER_SCRIPTS_RAW := $(shell find "$(SCRIPT_DIR)/core" -type f -print0 2>/dev/null | tr '\0' '\n')

# Test files - only in test directory root, not in subdirectories like support
TEST_FILES_RAW := $(shell $(FIND_TEST_FILES))

# Helper functions
count_lines = $(shell echo "$(1)" | grep -c '^' 2>/dev/null || echo 0)
check_tool = $(if $(shell command -v $(1) 2>/dev/null),,$(error $(1) not found. Run 'make setup' first))
install_tool = if ! command -v $(1) >/dev/null 2>&1; then \
	"$(ANSI)" --yellow --newline "Installing $(1)..."; \
	"$(ANSI)" --newline; \
	if command -v brew >/dev/null 2>&1; then \
		brew install $(1); \
	else \
		"$(ANSI)" --red --bold --newline "Error: $(1) not found and brew not available"; \
		exit 1; \
	fi; \
fi

# Common messaging patterns
define run_header
	@"$(ANSI)" --newline
	@"$(ANSI)" --green --bold "$(1)..."
	$(if $(2),@"$(ANSI)" --newline)
endef

define success_message
	"$(ANSI)" --green --bold $(if $(2),--newline) "$(1)"
endef

define error_message
	"$(ANSI)" --red --bold $(if $(2),--newline) "$(1)"
endef

define warning_message
	"$(ANSI)" --yellow $(if $(2),--newline) "$(1)"
endef

# Common script processing loop
define process_scripts
	@{ \
		error_count=0; \
		while IFS= read -r script; do \
			if [ -n "$$script" ] && [ -f "$$script" ]; then \
				$(2); \
				$(3); \
			fi; \
		done < <(printf "%s\n" $(1) | grep -v '^$$'); \
		$(4); \
	}
endef

# Common test execution function - returns to original implementation due to complexity
define run_bats_tests_common
	@mkdir -p "$(PROJECT_ROOT)/tmp/tests"
	@if [ ! -f "$(BATS_PATH)" ]; then \
		$(call error_message,Error: bats not found. Run 'make setup' first.); \
		exit 1; \
	fi
	@if [ -z "$(TEST_FILES_RAW)" ]; then \
		$(call warning_message,No test files found in $(TEST_DIR)); \
		exit 0; \
	fi
	@"$(ANSI)" --newline
endef

# Unified test runner function - eliminates duplication between test and test-verbose
define run_bats_tests
	@tmpfile=$$(mktemp) && \
	$(FIND_TEST_FILES) > "$$tmpfile" && \
	exit_code=0; \
	while IFS= read -r test_file; do \
		if [ -n "$$test_file" ] && [ -f "$$test_file" ]; then \
			filename=$$(basename "$$test_file"); \
			if [ "$(1)" = "verbose" ]; then \
				"$(ANSI)" --newline; \
				printf "Running $$filename (verbose)..."; \
				"$(ANSI)" --newline; \
				for i in $$(seq $$(expr 25 - $${#filename})); do printf " "; done; \
				"$(ANSI)" --newline; \
				if "$(BATS_PATH)" --show-output-of-passing-tests "$$test_file" | grep -v '^[0-9][0-9]*\.\.[0-9][0-9]*$$'; then \
					"$(ANSI)" --newline; \
					"$(ANSI)" --green --bold "✓ $$filename completed"; \
				else \
					"$(ANSI)" --newline; \
					"$(ANSI)" --red --bold "✗ $$filename failed"; \
					exit_code=1; \
				fi; \
				"$(ANSI)" --newline; \
			else \
				printf "\nRunning $$filename..."; \
				for i in $$(seq $$(expr 25 - $${#filename})); do printf " "; done; \
				if "$(BATS_PATH)" "$$test_file" >/dev/null 2>&1; then \
					"$(ANSI)" --green --bold "✓ $$filename passed"; \
				else \
					"$(ANSI)" --red --bold "✗ $$filename failed"; \
					exit_code=1; \
				fi; \
			fi; \
		fi; \
	done < "$$tmpfile"; \
	rm -f "$$tmpfile"; \
	"$(ANSI)" --newline; \
	"$(ANSI)" --newline; \
	if [ $$exit_code -eq 0 ]; then \
		$(call success_message,All tests passed!,true); \
	else \
		$(call error_message,Some tests failed!,true); \
		exit 1; \
	fi
endef

help: ## Show this help message
	@"$(ANSI)" --green --bold "Dotfiles Testing and Development"
	@"$(ANSI)" --newline
	@"$(ANSI)" --yellow "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-12s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@"$(ANSI)" --newline
	@"$(ANSI)" --yellow "Test files found:"
	@printf "%s\n" $(TEST_FILES_RAW) | grep -v '^$$' | while IFS= read -r file; do [ -n "$$file" ] && echo "  - $$(basename "$$file")"; done
	@"$(ANSI)" --newline
	@"$(ANSI)" --yellow "Shell scripts found: $(call count_lines,$(SHELL_SCRIPTS_RAW)) files"

setup: ## Initialize git submodules and install dependencies
	$(call run_header,Setting up test environment,true)
	@git submodule update --init --recursive
	@$(call install_tool,shellcheck)
	@$(call install_tool,shfmt)
	@"$(ANSI)" --newline
	@$(call success_message,Setup complete!)

test: ## Run all bats tests
	$(call run_header,Running bats tests)
	$(call run_bats_tests_common)
	$(call run_bats_tests,normal)

test-verbose: ## Run tests with verbose output
	$(call run_header,Running bats tests (verbose))
	$(call run_bats_tests_common)
	$(call run_bats_tests,verbose)

test-single: ## Run a single test file (usage: make test-single FILE=bootstrap.bats)
	@if [ -z "$(FILE)" ]; then \
		$(call error_message,Error: FILE parameter required. Usage: make test-single FILE=bootstrap.bats); \
		exit 1; \
	fi
	@test_file_path="$(TEST_DIR)/$(FILE)"; \
	if [ ! -f "$$test_file_path" ]; then \
		$(call error_message,Error: Test file $$test_file_path not found); \
		exit 1; \
	fi
	$(call run_header,Running $(FILE))
	@"$(BATS_PATH)" "$(TEST_DIR)/$(FILE)"

lint: ## Run shellcheck on all shell scripts
	$(call run_header,Running shellcheck,true)
	@$(call check_tool,shellcheck)
	$(call process_scripts,$(SHELL_SCRIPTS_RAW),\
		$(call warning_message,Checking $$(basename "$$script")...,true),\
		if ! shellcheck "$$script"; then error_count=$$((error_count + 1)); fi; "$(ANSI)" --newline,\
		if [ $$error_count -eq 0 ]; then $(call success_message,All shell scripts passed shellcheck!,true); else $(call error_message,Found issues in $$error_count files,true); exit 1; fi)

lint-fix: ## Run shellcheck and attempt to fix simple issues
	$(call run_header,Running shellcheck with fix suggestions,true)
	@printf "%s\n" $(SHELL_SCRIPTS_RAW) | grep -v '^$$' | while IFS= read -r script; do \
		if [ -n "$$script" ] && [ -f "$$script" ]; then \
			$(call warning_message,Checking $$(basename "$$script")...,true); \
			shellcheck -f diff "$$script" | patch -p1 || true; \
		fi; \
	done

fmt: ## Format all shell scripts with shfmt
	$(call run_header,Formatting shell scripts,true)
	@$(call check_tool,shfmt)
	@printf "%s\n" $(SHELL_SCRIPTS_RAW) | grep -v '^$$' | while IFS= read -r script; do \
		if [ -n "$$script" ] && [ -f "$$script" ]; then \
			$(call warning_message,Formatting $$(basename "$$script")...,true); \
			shfmt -i 4 -ci -sr -w "$$script"; \
		fi; \
	done
	@"$(ANSI)" --newline
	@$(call success_message,Formatting complete!)

fmt-check: ## Check if shell scripts are properly formatted
	$(call run_header,Checking shell script formatting,true)
	@$(call check_tool,shfmt)
	@{ \
		error_count=0; \
		while IFS= read -r script; do \
			if [ -n "$$script" ] && [ -f "$$script" ]; then \
				if ! shfmt -i 4 -ci -sr -d "$$script" >/dev/null 2>&1; then \
					$(call error_message,✗ $$(basename "$$script") is not properly formatted,true); \
					error_count=$$((error_count + 1)); \
				else \
					$(call success_message,✓ $$(basename "$$script"),true); \
				fi; \
			fi; \
		done < <(printf "%s\n" $(SHELL_SCRIPTS_RAW) | grep -v '^$$'); \
		if [ $$error_count -eq 0 ]; then \
			"$(ANSI)" --newline; \
			$(call success_message,All shell scripts are properly formatted!); \
		else \
			"$(ANSI)" --newline; \
			$(call error_message,Found formatting issues in $$error_count files,true); \
			$(call warning_message,Run 'make fmt' to fix formatting,true); \
			exit 1; \
		fi; \
	}


check: fmt-check lint ## Run all checks (formatting and linting)

test-ci: check test ## Run all CI checks (format, lint, test)

clean: ## Clean up temporary files and test artifacts
	$(call run_header,Cleaning up)
	@find . -name "*.log" -type f -delete 2>/dev/null || true
	@find . -name "*.tmp" -type f -delete 2>/dev/null || true
	@rm -rf "$(PROJECT_ROOT)/tmp/tests" 2>/dev/null || true
	@rm -rf /tmp/dotfiles-test-* 2>/dev/null || true
	@rm -f /tmp/.bootstrap_* 2>/dev/null || true
	@$(call success_message,Cleanup complete!)

coverage: ## Generate test coverage report (basic)
	$(call run_header,[Test Coverage Report],true)
	@$(call warning_message,Scripts with tests:,true)
	@test_count=0; \
	script_count=0; \
	for script in bootstrap main update setup status starship; do \
		script_count=$$((script_count + 1)); \
		if [ -f "$(TEST_DIR)/$$script.bats" ]; then \
			$(call success_message,  ✓ $$script,true); \
			test_count=$$((test_count + 1)); \
		else \
			$(call error_message,  ✗ $$script,true); \
		fi; \
	done; \
	"$(ANSI)" --newline; \
	$(call warning_message,Coverage: $$test_count/$$script_count scripts ($$((test_count * 100 / script_count))%),true)
