# Dotfiles Project - Agent Instructions

## Build/Test Commands
- **Setup**: `make setup` - Initialize git submodules and install dependencies (shellcheck, shfmt)
- **Run all tests**: `make test` - Execute all bats test suites
- **Run single test**: `make test-single FILE=bootstrap.bats` - Run specific test file
- **Lint**: `make lint` - Run shellcheck on all shell scripts
- **Format**: `make fmt` - Format shell scripts with shfmt (-i 4 -ci -sr)
- **Check format**: `make fmt-check` - Verify scripts are properly formatted
- **Full check**: `make check` - Run both formatting and linting checks
- **CI pipeline**: `make test-ci` - Run all checks (format, lint, test)

## Code Style
- **No comments**: Avoid extraneous code comments unless absolutely necessary
- **Self-documenting**: Write clear, readable code that explains itself through naming and structure
- **Modular**: Break complex logic into small, focused functions or modules
- **DRY principle**: Don't repeat yourself - extract common patterns into reusable components
- **Clean**: Remove unused code, variables, and imports

## Shell Script Style
- **Safety**: Always use `set -euo pipefail` at script start
- **Quoting**: Quote all variables: `"$var"` not `$var`
- **Functions**: Use functions for repeated code, test with bats framework
- **Error handling**: Check exit codes, provide meaningful error messages
- **POSIX**: Use POSIX-compliant constructs when possible, test on bash/zsh
- **Paths**: Use absolute paths, validate directory existence, handle spaces in filenames

## Testing with Bats
- **Framework**: Uses bats-core with bats-support, bats-assert, bats-mock helpers
- **Test files**: Located in `script/tests/` with `.bats` extension
- **Structure**: Use descriptive test names, test success/failure scenarios, mock external deps
- **Patterns**: Use setup()/teardown() for test preparation, group related tests

## Project Structure
- **Scripts**: Main scripts in `script/` (bootstrap, main, setup, update, status)
- **Helpers**: Modular helpers in `script/core/` (common, ansi, logging, etc.)
- **Config**: XDG-compliant config in `dot_config/`, templates use `.tmpl` extension
- **Dependencies**: Homebrew packages listed in `dependencies/*.brewfile`
- **Chezmoi**: All dotfiles managed through chezmoi, use `chezmoi apply` to sync changes