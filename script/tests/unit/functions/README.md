# Functions Test Suite

This directory contains comprehensive test suites for the dotfiles functions system. The tests cover all function modules and ensure reliable, well-documented functionality.

## Test Structure

### Unit Tests
- **`help_core.bats`** - Tests for the centralized help and search system
- **`dev_workflow.bats`** - Tests for development workflow and git utility functions
- **`system_utils.bats`** - Tests for system utilities and helper functions
- **`alias_validation.bats`** - Tests for alias syntax validation and loading

### Integration Tests
- **`../integration/functions.bats`** - Integration tests for complete workflow scenarios

### Test Helpers
- **`../helpers/functions.bash`** - Specialized utilities for function testing

## Test Coverage

### Help Core Functions (`help-core.tmpl`)
- ✅ `_render_aliases()` - Alias rendering with formatting
- ✅ `_render_functions()` - Function documentation rendering
- ✅ `alias-help()` - Search and display help for aliases
- ✅ `alias-search()` - Search aliases by name/command  
- ✅ `function-help()` - Display help for functions
- ✅ `alias-list()` - List all aliases
- ✅ `function-list()` - List all functions
- ✅ Error handling and edge cases
- ✅ Integration with alias files

### Development Workflow Functions (`development.tmpl`)
- ✅ `git-export()` - Clone repo without history
- ✅ `git-branch-clean()` - Clean merged branches
- ✅ `git-current-branch()` - Get current git branch
- ✅ `git-root()` - Get git repository root
- ✅ `git-uncommitted()` - Show uncommitted changes
- ✅ `git-recent-branches()` - Show recent branches
- ✅ `git-file-history()` - Show git history for files
- ✅ `project-init()` - Initialize projects with templates
- ✅ `dev-server()` - Start development server
- ✅ `code-stats()` - Project code statistics
- ✅ Git repository detection
- ✅ Project type detection (JavaScript, Python, Rust, Go)
- ✅ Error handling for missing dependencies

### System Utilities Functions (`system.tmpl`)
- ✅ `run-repeat()` - Execute command multiple times
- ✅ `dig-host()` - DNS lookup and reverse lookup
- ✅ `remind()` - Add reminder (macOS)
- ✅ `extract()` - Extract various archive formats
- ✅ `find-large()` - Find large files
- ✅ `disk-usage()` - Show disk usage
- ✅ `process-port()` - Find process using port
- ✅ `system-info()` - System information
- ✅ `backup-file()` - Create file backups
- ✅ `monitor-process()` - Monitor process usage
- ✅ `cleanup-temp()` - Clean temporary files
- ✅ Input validation and error handling
- ✅ Platform-specific functionality

### Alias System Validation
- ✅ Syntax validation for all alias files
- ✅ Loading without errors
- ✅ Naming conflict detection
- ✅ Security validation (dangerous commands)
- ✅ Documentation standards
- ✅ Cross-platform compatibility
- ✅ Performance testing
- ✅ Integration with help system

## Test Categories

### 1. Unit Tests
- Individual function behavior
- Input validation and error handling
- Output format verification
- Edge cases and boundary conditions

### 2. Integration Tests
- Functions working together
- Help system integration
- Real-world workflow scenarios
- Cross-module functionality

### 3. Documentation Tests
- Function documentation completeness
- Help system discoverability
- Consistent documentation format
- Example accuracy

### 4. Validation Tests
- Alias syntax validation
- No naming conflicts
- Security considerations
- Loading performance

### 5. Mock Strategy
- External commands (git, curl, system tools)
- File system operations
- macOS-specific functionality
- Network operations

## Running Tests

### Run All Function Tests
```bash
# Run all function-related tests
make test-single FILE=unit/functions/*.bats

# Or run specific test suites
make test-single FILE=unit/functions/help_core.bats
make test-single FILE=unit/functions/dev_workflow.bats  
make test-single FILE=unit/functions/system_utils.bats
make test-single FILE=unit/functions/alias_validation.bats
```

### Run Integration Tests
```bash
make test-single FILE=integration/functions_integration.bats
```

### Run All Tests
```bash
make test
```

## Test Helpers and Utilities

### Mock System Commands
The test suite includes comprehensive mocks for:
- Git operations (clone, status, branch, etc.)
- DNS resolution (dig, host)
- File system operations (find, du, df)
- Process monitoring (ps, lsof)
- Compression tools (tar, zip, etc.)
- System info commands (uptime, sysctl, etc.)

### Test Data Creation
Helper functions create realistic test environments:
- Git repositories with proper structure
- Project templates for different languages
- Mock alias and function files
- Test file hierarchies

### Assertion Helpers
Specialized assertions for:
- Function documentation format validation
- Alias syntax checking
- Error message consistency
- Output formatting verification

## Test Quality Standards

### Coverage Requirements
- ✅ All public functions have tests
- ✅ Error conditions are tested
- ✅ Edge cases are covered
- ✅ Integration scenarios work
- ✅ Documentation is validated

### Testing Principles
- **Isolated**: Tests don't depend on external state
- **Repeatable**: Tests produce consistent results
- **Fast**: Tests complete quickly for rapid feedback
- **Comprehensive**: Both happy path and error cases
- **Realistic**: Mock realistic command behavior

### Mock Strategy
- Mock external dependencies (git, curl, system commands)
- Use temporary directories for file operations
- Mock macOS-specific functionality for portability
- Ensure mocks behave realistically

## Test Maintenance

### Adding New Functions
When adding new functions to the dotfiles system:

1. **Create unit tests** in the appropriate `.bats` file
2. **Add integration scenarios** for workflow testing  
3. **Update documentation tests** if adding help content
4. **Add mocks** for any new external dependencies
5. **Test error handling** and edge cases

### Test Organization
- Keep related tests together in the same file
- Use descriptive test names that explain the behavior
- Group tests by functionality with clear comments
- Include both positive and negative test cases

### Mock Maintenance
- Keep mocks synchronized with real command behavior
- Update mocks when external tools change
- Ensure mocks handle edge cases realistically
- Document any platform-specific mock behavior

## Known Issues and Limitations

### Current Test Issues
Some tests may fail due to:
- Mock command syntax issues in different shell contexts
- Path handling differences between test and runtime environments
- Platform-specific command variations

### Future Improvements
- Add performance benchmarking tests
- Expand cross-shell compatibility testing
- Add more complex integration scenarios
- Include tests for template variable substitution

## Contributing

When contributing to the function system:

1. **Write tests first** for new functionality
2. **Update existing tests** when modifying functions
3. **Ensure all tests pass** before submitting changes
4. **Add documentation** for new functions and features
5. **Test on multiple platforms** when possible

The test suite is designed to catch regressions early and ensure the dotfiles functions remain reliable and well-documented for all users.