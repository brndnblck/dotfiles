# Dotfiles Repository Agent Instructions

## Build/Test/Lint Commands
- `make test` - Run all bats tests
- `make test-single FILE=<name>.bats` - Run single test file (e.g., `make test-single FILE=bootstrap.bats`)
- `make test-verbose` - Run tests with verbose output
- `make lint` - Run shellcheck on all shell scripts
- `make fmt` - Format shell scripts with shfmt (4-space indent, compact if, space redirects)
- `make fmt-check` - Check formatting without changing files
- `make check` - Run both format check and lint
- `make test-ci` - Full CI pipeline (format, lint, test)
- `make setup` - Initialize dependencies (git submodules, shellcheck, shfmt)

## Code Style & Conventions
- **Shell Scripts**: POSIX-compliant, use `set -euo pipefail`, quote all variables
- **Formatting**: 4-space indentation, compact if statements, space around redirects
- **Testing**: Use bats framework with bats-support, bats-assert, bats-file helpers
- **Linting**: Follow shellcheck rules (see `.shellcheckrc` for disabled warnings)
- **File Paths**: Always quote paths, use absolute paths, handle spaces/special chars
- **Error Handling**: Check exit codes, provide meaningful errors, use trap for cleanup

## Project Structure
- `script/` - Core shell scripts and utilities
- `script/tests/` - Bats test files
- `dot_config/` - XDG-compliant configuration templates
- Chezmoi templates use `.tmpl` extension for dynamic content