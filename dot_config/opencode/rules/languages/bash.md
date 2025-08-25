# Bash Scripting Rules

## Script Safety
- Use `set -euo pipefail` at the beginning of scripts
- Quote all variables to handle spaces in file paths
- Check for command existence before using (command -v)
- Validate required arguments and environment variables
- Use shellcheck to verify script correctness

## POSIX Compliance
- Use POSIX-compliant constructs when possible
- Avoid bash-specific features unless necessary
- Test scripts on different shells (bash, zsh, dash)
- Use portable command options
- Document shell-specific requirements

## File Path Handling
- Always quote file paths: `"$path"` not `$path`
- Use absolute paths when possible
- Validate directory existence before operations
- Handle spaces and special characters in filenames
- Use `realpath` or equivalent for canonical paths

## Error Handling
- Check exit codes of important commands
- Provide meaningful error messages
- Clean up temporary files on script exit
- Use trap for cleanup functions
- Log errors appropriately

## Best Practices
- Use functions for repeated code
- Make scripts idempotent when possible
- Provide usage information (--help flag)
- Use consistent indentation (2 or 4 spaces)
- Comment complex logic and non-obvious operations

## XDG Compliance
- Respect XDG Base Directory specification
- Use $XDG_CONFIG_HOME, $XDG_DATA_HOME, $XDG_CACHE_HOME
- Provide fallbacks for systems without XDG variables
- Store configuration in appropriate XDG directories

## Testing with Bats
- Use the bats-* ecosystem for testing non-trivial shell scripts
- **bats-core**: The main testing framework for bash scripts
- **bats-support**: Helper functions for common testing patterns
- **bats-assert**: Assertion functions for readable test output
- **bats-file**: File system testing helpers
- **bats-mock**: Mocking and stubbing for external commands

### Bats Testing Best Practices
- Write tests before implementing complex bash functions
- Test both success and failure scenarios
- Use descriptive test names that explain the expected behavior
- Mock external dependencies to ensure tests are deterministic
- Test edge cases like empty inputs, special characters, and missing files
- Use setup() and teardown() functions for test environment preparation
- Group related tests in separate .bats files
- Run tests in CI/CD pipelines to catch regressions

### Example Test Structure
```bash
#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
load 'test_helper/bats-file/load'

@test "function handles valid input correctly" {
  run my_function "valid_input"
  assert_success
  assert_output "expected_output"
}

@test "function fails gracefully with invalid input" {
  run my_function "invalid_input"
  assert_failure
  assert_output --partial "Error:"
}
```