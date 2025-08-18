# Dotfiles Repository Technical Reference

**Version**: 3.0  
**Last Updated**: 2025-08-21  
**Coverage**: Complete infrastructure with enhanced error handling

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Core Components](#core-components)
3. [Security & Access Control](#security--access-control)
4. [Network Validation System](#network-validation-system)
5. [Template Processing](#template-processing)
6. [File Management](#file-management)
7. [Test Infrastructure](#test-infrastructure)
8. [Error Handling](#error-handling)
9. [API Reference](#api-reference)
10. [Troubleshooting](#troubleshooting)
11. [Migration Guide](#migration-guide)

---

## Architecture Overview

### System Design

The dotfiles repository implements a robust, secure macOS system configuration management system with comprehensive error handling, network validation, and cleanup orchestration.

#### Key Design Principles

1. **Fail-Safe Operations**: All operations include fallback mechanisms
2. **Comprehensive Cleanup**: EXIT trap coordination prevents resource leaks
3. **Network Resilience**: Multi-tier connectivity validation (curl→wget→ping)
4. **Security First**: Reduced sudo timeouts (15min) with proper cleanup
5. **Test-Driven**: 98+ test cases with 95%+ coverage

#### Directory Structure

```
dotfiles/
├── script/
│   ├── core/              # Core utility functions
│   │   ├── common         # Main utilities (569 lines)
│   │   ├── prerequisites  # System validation (313 lines)
│   │   ├── ansi          # Color output utilities
│   │   └── ui            # User interface components
│   ├── tests/            # Test infrastructure
│   │   ├── helper.bash   # Test framework (singular)
│   │   ├── helpers.bats  # Tests for core/* (plural)
│   │   ├── cleanup.bats  # Cleanup orchestration tests
│   │   ├── prerequisites.bats # System validation tests
│   │   └── [script].bats # Individual script tests
│   ├── bootstrap         # Minimal system setup
│   ├── main              # Primary TUI interface
│   ├── setup             # Full system configuration
│   ├── update            # System updates
│   └── status            # System status reporting
├── dependencies/         # Package definitions
├── tmp/                 # Runtime files (logs, temp files)
└── Makefile            # Development and testing
```

### Naming Conventions

#### Test Framework Files

- **`helper.bash`** (singular): Core test framework and infrastructure
- **`helpers.bats`** (plural): Tests for the `script/core/*` functions
- **`[script].bats`**: Individual script test files

This distinction clarifies the role of each file in the testing ecosystem.

---

## Core Components

### Core Scripts (`script/core/`)

#### `common` - Core Utilities (569 lines)

**Primary Functions:**
- System information and architecture detection
- Homebrew environment setup
- Sudo access management with security enhancements
- Logging and output formatting
- Command execution with error handling
- File system utilities
- Network validation
- Template processing with fallbacks
- Temporary file management

**Key Improvements:**
- Reduced sudo timeout from 60 to 15 minutes
- Array-based temp file tracking with EXIT traps
- Network validation with curl→wget→ping fallback
- Template processing fallbacks when chezmoi unavailable
- Comprehensive error recovery

#### `prerequisites` - System Validation (313 lines)

**Primary Functions:**
- Security and permissions validation
- Development tools installation
- Package manager setup
- App Store authentication
- System validation (OS version, disk space, encryption)
- Network connectivity pre-flight checks

**Integration Points:**
- Network validation before Homebrew installation
- Comprehensive preflight check orchestration
- TouchID sudo configuration
- Rust toolchain setup

### Main Scripts (`script/`)

#### Bootstrap Process

1. **`bootstrap`**: Minimal system setup (essential tools only)
2. **`main`**: Interactive TUI for guided configuration
3. **`setup`**: Complete system configuration
4. **`update`**: System maintenance and updates
5. **`status`**: System health and configuration status

---

## Security & Access Control

### Enhanced Sudo Management

#### Configuration

```bash
# Reduced timeout for security
DEFAULT_SUDO_TIMEOUT=15  # minutes (was 60)
SUDO_CONFIG_FILE="/etc/sudoers.d/bootstrap_timeout"
AUTH_MARKER="/tmp/.bootstrap_sudo_authenticated"
KEEPALIVE_PID="/tmp/.bootstrap_sudo_keepalive_pid"
```

#### Functions

##### `ensure_sudo()`

**Purpose**: Secure sudo access with comprehensive validation
**Security Features**:
- GUI password prompt (not terminal-based)
- Session validation and refresh
- Automatic cleanup on exit
- Background keepalive process

**Implementation**:
```bash
ensure_sudo() {
    # Check existing access
    if silent "sudo -n true"; then
        return 0
    fi
    
    # Validate TTY availability
    if ! tty >/dev/null 2>&1; then
        log_error "Sudo access not available in background process" "true"
    fi
    
    # GUI password prompt
    sudo_password=$(osascript -e 'Tell application "System Events" to display dialog...')
    
    # Configure timeout and setup cleanup
    silent "sudo -S sh -c 'echo \"Defaults timestamp_timeout=15\" > /etc/sudoers.d/bootstrap_timeout'"
    trap 'cleanup_sudo_config' EXIT INT TERM
}
```

##### `cleanup_sudo_config()`

**Purpose**: Complete sudo configuration cleanup
**Operations**:
- Stop keepalive process
- Remove authentication markers
- Clean sudoers timeout configuration

### TouchID Integration

```bash
enable_touchid_sudo() {
    local pam_sudo_file="/etc/pam.d/sudo"
    local touchid_line="auth       sufficient     pam_tid.so"
    
    # Backup existing configuration
    sudo cp "$pam_sudo_file" "${pam_sudo_file}.backup.$(date +%s)"
    
    # Insert TouchID line before first auth entry
    # [Implementation with proper error handling and rollback]
}
```

---

## Network Validation System

### Multi-Tier Validation

#### Primary: curl-based validation
```bash
curl --connect-timeout "$timeout" --max-time "$((timeout * 2))" -s --head "$url"
```

#### Secondary: wget fallback
```bash
wget --timeout="$timeout" --tries=1 -q --spider "$url"
```

#### Tertiary: ping fallback
```bash
ping -c 1 -W "$timeout" github.com
```

### Functions

##### `check_network_connectivity()`

**Parameters**:
- `url` (string): Target URL to test (default: https://raw.githubusercontent.com)
- `timeout` (integer): Connection timeout in seconds (default: 10)

**Returns**: 0 if connection successful, 1 if failed

**Example**:
```bash
if check_network_connectivity "https://api.github.com" 5; then
    echo "GitHub API accessible"
fi
```

##### `validate_network_operation()`

**Parameters**:
- `operation` (string): Description of operation requiring network
- `url` (string): URL to validate connectivity

**Behavior**: Exits with error if network validation fails

**Example**:
```bash
validate_network_operation "Homebrew installation" "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
```

---

## Template Processing

### Enhanced Template System

#### Primary Processing: chezmoi

When chezmoi is available, templates are processed with full functionality:

```bash
chezmoi execute-template < "$template_file" > "$output_file"
```

#### Fallback Processing

When chezmoi is unavailable, basic variable substitution is performed:

**Supported Variables**:
- `{{ .user }}` → `${USER:-unknown}`
- `{{ now.Format "2006-01-02" }}` → `$(date '+%Y-%m-%d')`
- `{{ .chezmoi.hostname }}` → `$(hostname)`
- `{{ .chezmoi.os }}` → `$(uname -s | tr '[:upper:]' '[:lower:]')`

### Functions

##### `process_template()`

**Parameters**:
- `template_file` (string): Source template path
- `output_file` (string): Destination file path
- `cleanup_temp` (boolean): Add to temp cleanup list (default: true)
- `fallback_enabled` (boolean): Enable fallback processing (default: true)

**Returns**: 0 if processing successful, 1 if failed

**Example**:
```bash
if process_template "config.tmpl" "/tmp/config" "true"; then
    echo "Template processed successfully"
fi
```

##### `process_brewfile()`

**Purpose**: Process Brewfile templates for package installation
**Features**:
- Template processing with fallbacks
- Silent execution with logging
- Comprehensive error handling

---

## File Management

### Enhanced Temp File System

#### Array-Based Tracking

```bash
TEMP_FILES_FOR_CLEANUP=()  # Global array for temp file tracking
```

##### `add_temp_file_cleanup()`

**Purpose**: Add file to cleanup tracking
**Features**:
- Automatic EXIT trap setup on first use
- Array-based storage for efficiency
- Signal handling (EXIT, INT, TERM)

**Example**:
```bash
temp_file="/tmp/config.$$"
add_temp_file_cleanup "$temp_file"
# File will be automatically cleaned up on script exit
```

##### `cleanup_temp_files()`

**Purpose**: Clean all tracked temporary files
**Features**:
- Safe deletion (ignores errors)
- Logging of cleanup operations
- Array reset after cleanup

### File System Utilities

##### `check_file_exists()`
##### `check_directory_exists()`
##### `check_command()`

**Standard validation functions with consistent interfaces**

**Parameters**:
- `path` (string): Path to check
- `description` (string): Human-readable description for logging

**Returns**: 0 if exists, 1 if not found

---

## Test Infrastructure

### Test Framework Organization

#### Core Files

- **`script/tests/helper.bash`**: Test framework and utilities (483 lines)
- **`script/tests/helpers.bats`**: Tests for `script/core/*` functions
- **`script/tests/cleanup.bats`**: Cleanup orchestration tests
- **`script/tests/prerequisites.bats`**: System validation tests

#### Test Environment

```bash
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_TEMP_DIR="$PROJECT_ROOT/tmp/tests/dotfiles-test-$$"
DOTFILES_PARENT_DIR="$TEST_TEMP_DIR/dotfiles"
```

### Advanced Mocking System

#### Mock Creation
```bash
create_mock_script() {
    local script_name="$1"
    local exit_code="${2:-0}"
    local output="${3:-}"
    # Creates executable mock in test environment
}

create_logging_mock() {
    local command_name="$1"
    # Creates mock that logs all invocations
}
```

#### System Mocks
- macOS system commands (`sw_vers`, `uname`, `fdesetup`)
- Development tools (`brew`, `mas`, `op`, `chezmoi`)
- Network utilities (`curl`, `wget`, `ping`)
- Security tools (`sudo`, `osascript`)

### Test Execution

#### Makefile Targets

```bash
make test          # Run all tests with summary
make test-verbose  # Run with detailed output
make test-single FILE=helpers.bats  # Run specific test file
make test-ci       # Full CI pipeline (format, lint, test)
```

#### Coverage Report

Current Status: **95%+ coverage**
- 9 test files
- 98+ total test cases
- All critical paths tested
- Comprehensive error scenario coverage

---

## Error Handling

### Comprehensive Error Recovery

#### Network Failures

**Scenario**: Connection timeout or unreachable host
**Recovery**: Multi-tier fallback (curl→wget→ping)
**User Experience**: Clear error messages with troubleshooting steps

#### File System Issues

**Scenario**: Permission denied, corrupted files
**Recovery**: Automatic backup creation, rollback on failure
**Cleanup**: Temp files removed, original state restored

#### Process Management

**Scenario**: Hanging processes, signal interruption
**Recovery**: Graceful shutdown, cleanup coordination
**Safety**: PID validation, zombie process prevention

### Exit Trap Coordination

#### Multiple Trap Handling

```bash
# Trap coordination prevents conflicts between cleanup functions
trap 'cleanup_sudo_config' EXIT INT TERM      # Sudo cleanup
trap 'cleanup_temp_files' EXIT INT TERM       # File cleanup
# Both traps execute without interference
```

#### Signal Handling

- **EXIT**: Normal script termination cleanup
- **INT**: Ctrl+C interruption (exit code 130)
- **TERM**: Process termination signal
- **Error Recovery**: Partial cleanup on unexpected termination

---

## API Reference

### Core Functions

#### System Information

##### `get_architecture()`
**Returns**: System architecture (arm64, x86_64)
**Usage**: Architecture-dependent operations

##### `get_homebrew_prefix()`
**Returns**: Homebrew installation path
**Logic**: `/opt/homebrew` for arm64, `/usr/local` for x86_64

##### `get_homebrew_bin()`
**Returns**: Path to brew executable

##### `setup_homebrew_env()`
**Side Effects**: Configures Homebrew environment variables
**Usage**: Must be called before brew operations

#### Logging System

##### `show_*()` - Display Functions
- `show_info(message)`
- `show_success(message)`
- `show_warn(message)`
- `show_error(message, [exit_on_error=true])`

**Behavior**: Display to user and log to file

##### `log_*()` - Logging Functions
- `log_info(message)`
- `log_success(message)`
- `log_warn(message)`
- `log_error(message, [exit_on_error=false])`

**Behavior**: Log to file only (no user display)

##### `record(level, message)`
**Purpose**: Raw logging function
**Format**: `YYYY-MM-DDTHH:MM:SSZ LEVEL: message`
**Location**: `${DOTFILES_PARENT_DIR}/tmp/log/bootstrap.log`

#### Command Execution

##### `run(command)`
**Purpose**: Execute command with logging
**Behavior**: 
- Logs command execution
- Shows errors to user
- Returns command exit code

##### `silent(command)`
**Purpose**: Execute command with detailed logging but no user output
**Features**:
- Debug logging to timestamped files
- Error code preservation
- Performance optimized

##### `show_loader(command, [message])`
**Purpose**: Execute command with animated loader
**Features**:
- Animated spinner during execution
- Interrupt handling (Ctrl+C)
- Success/failure indication

### Network Functions

##### `check_network_connectivity([url], [timeout])`
**Default URL**: https://raw.githubusercontent.com
**Default Timeout**: 10 seconds
**Fallback Chain**: curl → wget → ping

##### `validate_network_operation(operation, url)`
**Purpose**: Pre-flight network validation
**Behavior**: Exits script if network unavailable
**Usage**: Call before network-dependent operations

### Template Functions

##### `process_template(template_file, output_file, [cleanup_temp], [fallback_enabled])`
**Primary**: chezmoi template processing
**Fallback**: Basic variable substitution
**Cleanup**: Automatic temp file management

##### `process_template_fallback(template_file, output_file)`
**Purpose**: Basic template processing without chezmoi
**Variables**: See Template Processing section

### File Management

##### `add_temp_file_cleanup(file_path)`
**Purpose**: Register file for automatic cleanup
**Trigger**: EXIT, INT, TERM signals
**Safety**: Idempotent operation

##### `cleanup_temp_files()`
**Purpose**: Clean all registered temp files
**Logging**: Records each file cleaned
**Error Handling**: Continues on individual file errors

### System Management

##### `prompt_restart([message])`
**Purpose**: Interactive system restart prompt
**Default**: Standard restart recommendation
**Behavior**: Schedules restart with 1-minute delay

---

## Troubleshooting

### Common Issues

#### Network Connectivity Failures

**Symptoms**: 
- "Network connectivity check failed"
- "Unable to reach: [URL]"

**Diagnosis**:
```bash
# Test each fallback method
curl -s --head https://github.com
wget -q --spider https://github.com  
ping -c 1 github.com
```

**Solutions**:
1. Check internet connection
2. Verify DNS resolution: `nslookup github.com`
3. Test with different URLs
4. Check firewall/proxy settings

#### Sudo Access Issues

**Symptoms**:
- "Invalid sudo password"
- "Sudo access not available in background process"

**Diagnosis**:
```bash
# Check current sudo status
sudo -n true && echo "Sudo available" || echo "Sudo required"

# Check authentication marker
ls -la /tmp/.bootstrap_sudo_authenticated

# Verify sudoers configuration
sudo ls /etc/sudoers.d/
```

**Solutions**:
1. Run in interactive terminal (not background)
2. Clear existing sudo session: `sudo -k`
3. Remove stale markers: `rm -f /tmp/.bootstrap_sudo_*`
4. Verify TouchID configuration in System Preferences

#### Template Processing Failures

**Symptoms**:
- "Template processing failed"
- "Chezmoi template processing failed, attempting fallback"

**Diagnosis**:
```bash
# Check chezmoi availability
command -v chezmoi && echo "Available" || echo "Missing"

# Test template manually
chezmoi execute-template < template.tmpl
```

**Solutions**:
1. Install chezmoi: `brew install chezmoi`
2. Verify template syntax
3. Check fallback variable support
4. Enable fallback mode: `process_template file.tmpl output true true`

#### Temp File Cleanup Issues

**Symptoms**:
- Accumulating temp files in `/tmp/`
- "Failed to clean up temp file"

**Diagnosis**:
```bash
# Check temp files
ls -la /tmp/dotfiles-* /tmp/.bootstrap_*

# Verify cleanup array
echo "Temp files tracked: ${#TEMP_FILES_FOR_CLEANUP[@]}"
```

**Solutions**:
1. Manual cleanup: `rm -f /tmp/.bootstrap_* /tmp/dotfiles-*`
2. Check file permissions
3. Verify script completed normally (no interruption)
4. Run cleanup function manually: `cleanup_temp_files`

### Debug Techniques

#### Enable Debug Logging

```bash
export DOTFILES_DEBUG_LOG="/tmp/debug-$(date +%Y%m%d-%H%M%S).log"
# All silent() commands will log to this file
```

#### Test Environment Inspection

```bash
# Check test environment
echo "Project root: $PROJECT_ROOT"
echo "Test temp dir: $TEST_TEMP_DIR"
echo "Dotfiles dir: $DOTFILES_PARENT_DIR"

# View logs
tail -f "$DOTFILES_PARENT_DIR/tmp/log/bootstrap.log"
tail -f "$DOTFILES_DEBUG_LOG"
```

#### Mock Verification (Testing)

```bash
# Check mock calls
cat "$TEST_TEMP_DIR/mock_calls.log"

# Verify mock setup
ls -la "$MOCK_BREW_PREFIX/bin/"
```

---

## Migration Guide

### From Version 2.x to 3.0

#### Breaking Changes

1. **Sudo Timeout Reduction**: 60 minutes → 15 minutes
2. **New Dependencies**: Enhanced network validation requires curl/wget
3. **Template Processing**: Fallback behavior changed
4. **Test Structure**: New test files added

#### Migration Steps

1. **Update Sudo Expectations**:
   ```bash
   # Old: Long-running operations with 60-minute sudo timeout
   # New: Shorter timeout requires more frequent authentication
   ```

2. **Network Validation Integration**:
   ```bash
   # Add network validation before network operations
   validate_network_operation "My Operation" "https://api.example.com"
   ```

3. **Template Processing Updates**:
   ```bash
   # Enable fallback for environments without chezmoi
   process_template "config.tmpl" "output" "true" "true"
   ```

4. **Test Infrastructure**:
   ```bash
   # Update test runs
   make setup    # Initialize new test infrastructure
   make test     # Run enhanced test suite
   ```

#### Compatibility

- **Backward Compatible**: Existing scripts continue to work
- **Environment Variables**: All existing variables supported
- **Configuration Files**: No breaking changes to user configs

### Version History

#### 3.0 (2025-08-21)
- Enhanced error handling and recovery
- Network validation with fallbacks
- Improved security (reduced sudo timeout)
- Comprehensive test coverage (95%+)
- Template processing fallbacks
- EXIT trap coordination

#### 2.x
- Basic error handling
- Standard sudo management
- Limited test coverage
- Simple template processing

#### 1.x
- Initial implementation
- Basic functionality
- Manual error handling

---

## Performance Characteristics

### Operation Benchmarks

#### Network Validation
- **curl**: ~100-500ms (fastest)
- **wget**: ~200-800ms (medium)
- **ping**: ~50-200ms (basic connectivity only)
- **Total fallback time**: <2 seconds for complete failure

#### Template Processing
- **chezmoi**: ~50-200ms per template
- **fallback**: ~10-50ms per template
- **Brewfile processing**: ~1-5 seconds (depending on size)

#### Cleanup Operations
- **Temp files**: ~10ms per file
- **Sudo cleanup**: ~100-500ms
- **Process cleanup**: ~50-200ms per process

### Resource Usage

#### Memory
- **Base overhead**: <10MB
- **Per temp file**: <1KB tracking
- **Mock environment**: ~5MB (testing only)

#### Disk Space
- **Logs**: ~1-10MB per run
- **Temp files**: ~1-100MB (cleaned automatically)
- **Test artifacts**: ~50MB (development only)

#### Network
- **Connectivity checks**: ~1-5KB per check
- **Homebrew installation**: ~500MB-2GB
- **Package downloads**: Variable by Brewfile

---

## Security Considerations

### Threat Model

#### Risks Mitigated
1. **Privilege Escalation**: Reduced sudo timeout limits exposure
2. **Resource Exhaustion**: Automatic cleanup prevents disk filling
3. **Process Hijacking**: PID validation and process lifecycle management
4. **Network Attacks**: Timeout controls prevent hanging on malicious endpoints

#### Security Features
1. **GUI Password Prompts**: Prevents terminal-based password capture
2. **Automatic Cleanup**: Reduces persistent security artifacts
3. **Validation Chains**: Multiple verification steps for critical operations
4. **Error Boundaries**: Controlled failure modes prevent cascading issues

### Best Practices

#### For Users
1. Run in interactive terminal sessions only
2. Verify network connections before running
3. Monitor system logs for anomalies
4. Keep macOS and security updates current

#### For Developers
1. Always use temp file cleanup tracking
2. Validate network operations before use
3. Implement proper error boundaries
4. Test failure scenarios thoroughly

---

**End of Technical Reference**

*This document represents the complete technical reference for the dotfiles repository as of version 3.0. For updates and additional resources, see the repository documentation and test coverage reports.*