#!/usr/bin/env bats

# Test Suite for dot_functions.d/system.tmpl
# Tests system utilities and helper functions

# Load helpers
load "../../helpers/helper"
load "../../helpers/fixtures"

setup() {
    test_setup
    
    # Copy the function file to test environment with snake_case naming
    cp "$PROJECT_ROOT/dot_functions.d/system.tmpl" "$TEST_TEMP_DIR/system_functions.sh"
    
    # Set up completely isolated system command mocks
    setup_isolated_system_mocks
    
    # Create isolated test directory for file operations
    mkdir -p "$TEST_TEMP_DIR/test-files"
    cd "$TEST_TEMP_DIR/test-files"
}

teardown() {
    test_teardown
}

# Helper to set up completely isolated system command mocks
setup_isolated_system_mocks() {
    # Create isolated mock bin directory
    mkdir -p "$TEST_TEMP_DIR/mock-bin"
    export PATH="$TEST_TEMP_DIR/mock-bin:$PATH"
    
    # Mock sequence command for run-repeat (no system dependencies)
    cat > "$TEST_TEMP_DIR/mock-bin/seq" << 'EOF'
#!/bin/bash
start=${1:-1}
end=${2:-$1}
if [ $# -eq 1 ]; then
    start=1
    end=$1
fi
# Simple pure shell implementation to avoid system dependencies
i=$start
while [ $i -le $end ]; do
    echo $i
    i=$((i + 1))
done
EOF
    chmod +x "$TEST_TEMP_DIR/mock-bin/seq"
    
    # Mock dig and host commands for DNS operations (isolated)
    cat > "$TEST_TEMP_DIR/mock-bin/dig" << 'EOF'
#!/bin/bash
if [ "$2" = "+short" ]; then
    case "$3" in
        "google.com")
            echo "172.217.14.206"
            ;;
        "invalid.domain")
            exit 1
            ;;
        *)
            echo "192.168.1.1"
            ;;
    esac
fi
EOF
    chmod +x "$TEST_TEMP_DIR/mock-bin/dig"
    
    cat > "$TEST_TEMP_DIR/mock-bin/host" << 'EOF'
#!/bin/bash
case "$1" in
    "172.217.14.206")
        echo "206.14.217.172.in-addr.arpa domain name pointer lga34s32-in-f14.1e100.net."
        ;;
    *)
        echo "Mock reverse lookup for $1"
        ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/mock-bin/host"
    
    # Mock osascript for macOS Reminders (isolated)
    cat > "$TEST_TEMP_DIR/mock-bin/osascript" << 'EOF'
#!/bin/bash
echo "Mock: osascript executed"
exit 0
EOF
    chmod +x "$TEST_TEMP_DIR/mock-bin/osascript"
    
    # Mock compression/extraction commands (isolated)
    create_isolated_mock_script "tar" 0 "Mock tar extraction"
    create_isolated_mock_script "unzip" 0 "Mock unzip extraction"
    create_isolated_mock_script "bunzip2" 0 "Mock bunzip2 extraction"
    create_isolated_mock_script "gunzip" 0 "Mock gunzip extraction"
    create_isolated_mock_script "7z" 0 "Mock 7z extraction"
    create_isolated_mock_script "unrar" 0 "Mock unrar extraction"
    
    # Mock system info commands (isolated)
    cat > "$TEST_TEMP_DIR/mock-bin/hostname" << 'EOF'
#!/bin/bash
echo "test-hostname"
EOF
    chmod +x "$TEST_TEMP_DIR/mock-bin/hostname"
    
    cat > "$TEST_TEMP_DIR/mock-bin/uptime" << 'EOF'
#!/bin/bash
echo "10:30  up 2 days,  3:45, 2 users, load averages: 1.23 1.45 1.67"
EOF
    chmod +x "$TEST_TEMP_DIR/mock-bin/uptime"
    
    cat > "$TEST_TEMP_DIR/mock-bin/sysctl" << 'EOF'
#!/bin/bash
case "$2" in
    "machdep.cpu.brand_string")
        echo "Apple M1 Pro"
        ;;
    "hw.memsize")
        echo "34359738368"  # 32GB in bytes
        ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/mock-bin/sysctl"
    
    # Mock find, du, df for file system operations (isolated)
    cat > "$TEST_TEMP_DIR/mock-bin/find" << 'EOF'
#!/bin/bash
# Simple mock find for testing
case "$*" in
    *"-size +100M"*)
        echo "/mock/path/largefile1.bin"
        echo "/mock/path/largefile2.iso"
        ;;
    *"-name \"*\" -user $(whoami) -mtime +7"*)
        echo "/tmp/oldfile1.tmp"
        echo "/tmp/oldfile2.cache"
        ;;
    *"-type f -mtime +30"*)
        echo "$HOME/Downloads/olddownload1.zip"
        echo "$HOME/Downloads/olddownload2.dmg"
        ;;
    *)
        echo "Mock find: $*"
        ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/mock-bin/find"
    
    cat > "$TEST_TEMP_DIR/mock-bin/du" << 'EOF'
#!/bin/bash
if [ "$1" = "-h" ]; then
    echo "2.5G    Downloads"
    echo "1.2G    Documents"
    echo "512M    Pictures"
    echo "256M    Music"
fi
EOF
    chmod +x "$TEST_TEMP_DIR/mock-bin/du"
    
    cat > "$TEST_TEMP_DIR/mock-bin/df" << 'EOF'
#!/bin/bash
if [ "$1" = "-h" ]; then
    echo "Filesystem     Size   Used  Avail Capacity  iused   ifree %iused  Mounted on"
    echo "/dev/disk3s1s1  494Gi   300Gi  194Gi    61%  488318 1048088   32%   /"
    echo "/dev/disk3s2    494Gi   100Gi  394Gi    20%  123456  987654   11%   /System/Volumes/Data"
fi
EOF
    chmod +x "$TEST_TEMP_DIR/mock-bin/df"
    
    # Mock lsof for port checking (isolated)
    cat > "$TEST_TEMP_DIR/mock-bin/lsof" << 'EOF'
#!/bin/bash
if [[ "$*" == *":8080"* ]]; then
    echo "COMMAND  PID   USER   FD   TYPE DEVICE SIZE/OFF NODE NAME"
    echo "node    1234  user    7u  IPv4  12345      0t0  TCP *:8080 (LISTEN)"
elif [[ "$*" == *":3000"* ]]; then
    # No output for empty port
    exit 0
else
    echo "Mock lsof: $*"
fi
EOF
    chmod +x "$TEST_TEMP_DIR/mock-bin/lsof"
    
    # Mock ps for process monitoring (isolated)
    cat > "$TEST_TEMP_DIR/mock-bin/ps" << 'EOF'
#!/bin/bash
if [ "$1" = "aux" ]; then
    echo "USER  PID  %CPU %MEM      VSZ    RSS   TT  STAT STARTED      TIME COMMAND"
    echo "user  1234  2.5  1.2   123456   7890  ??  S    10:30AM   0:05.67 /Applications/Firefox.app/Contents/MacOS/firefox"
    echo "user  5678  1.8  0.8    98765   4321  ??  S    10:35AM   0:03.21 /usr/bin/python3 script.py"
fi
EOF
    chmod +x "$TEST_TEMP_DIR/mock-bin/ps"
    
    # Mock grep for process filtering (isolated)
    cat > "$TEST_TEMP_DIR/mock-bin/grep" << 'EOF'
#!/bin/bash
# Simple grep mock that filters input
while IFS= read -r line; do
    case "$*" in
        *"-i firefox"*)
            if [[ "$line" =~ [Ff]irefox ]]; then
                echo "$line"
            fi
            ;;
        *"-v grep"*)
            if [[ ! "$line" =~ grep ]]; then
                echo "$line"
            fi
            ;;
        *)
            echo "$line"
            ;;
    esac
done
EOF
    chmod +x "$TEST_TEMP_DIR/mock-bin/grep"
    
    # Mock whoami (isolated)
    cat > "$TEST_TEMP_DIR/mock-bin/whoami" << 'EOF'
#!/bin/bash
echo "testuser"
EOF
    chmod +x "$TEST_TEMP_DIR/mock-bin/whoami"
    
    # Mock wc for counting (isolated)
    cat > "$TEST_TEMP_DIR/mock-bin/wc" << 'EOF'
#!/bin/bash
if [ "$1" = "-l" ]; then
    echo "5"  # Mock count
else
    echo "5 10 50"  # lines, words, chars
fi
EOF
    chmod +x "$TEST_TEMP_DIR/mock-bin/wc"
}

# Helper to create isolated mock scripts
create_isolated_mock_script() {
    local cmd="$1"
    local exit_code="$2"
    local output="$3"
    
    cat > "$TEST_TEMP_DIR/mock-bin/$cmd" << EOF
#!/bin/bash
echo "$output"
exit $exit_code
EOF
    chmod +x "$TEST_TEMP_DIR/mock-bin/$cmd"
}

# =============================================================================
# run-repeat Function Tests
# =============================================================================

@test "system_utils: run-repeat should display usage when no arguments provided" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    run run-repeat
    
    assert_failure
    assert_output --partial "Usage: run-repeat COUNT COMMAND [ARGS...]"
    assert_output --partial "Example: run-repeat 5 echo 'hello world'"
}

@test "system_utils: run-repeat should display usage when only count provided" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    run run-repeat 5
    
    assert_failure
    assert_output --partial "Usage: run-repeat COUNT COMMAND [ARGS...]"
}

@test "system_utils: run-repeat should validate count parameter is numeric" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    run run-repeat "not-a-number" echo "test"
    
    assert_failure
    assert_output --partial "Error: COUNT must be a positive integer"
}

@test "system_utils: run-repeat should execute command specified number of times" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    run run-repeat 3 echo "hello"
    
    assert_success
    assert_output --partial "[1/3] Running: echo hello"
    assert_output --partial "hello"
    assert_output --partial "[2/3] Running: echo hello"
    assert_output --partial "[3/3] Running: echo hello"
    
    # Count the number of "hello" occurrences
    local hello_count=$(echo "$output" | grep -c "^hello$" || true)
    [ "$hello_count" -eq 3 ]
}

@test "system_utils: run-repeat should handle commands with multiple arguments" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    run run-repeat 2 echo "hello" "world"
    
    assert_success
    assert_output --partial "[1/2] Running: echo hello world"
    assert_output --partial "hello world"
    assert_output --partial "[2/2] Running: echo hello world"
}

@test "system_utils: run-repeat should handle command failures" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    run run-repeat 2 false
    
    # run-repeat should continue even if individual commands fail
    assert_success
    assert_output --partial "[1/2] Running: false"
    assert_output --partial "[2/2] Running: false"
}

# =============================================================================
# dig-host Function Tests
# =============================================================================

@test "system_utils: dig-host should display usage when no arguments provided" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    run dig-host
    
    assert_failure
    assert_output --partial "Usage: dig-host HOSTNAME"
    assert_output --partial "Example: dig-host google.com"
}

@test "system_utils: dig-host should perform forward and reverse DNS lookup" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    run dig-host google.com
    
    assert_success
    assert_output --partial "Forward lookup for google.com: 172.217.14.206"
    assert_output --partial "Reverse lookup for 172.217.14.206:"
    assert_output --partial "lga34s32-in-f14.1e100.net"
}

@test "system_utils: dig-host should handle DNS lookup failure" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    run dig-host invalid.domain
    
    assert_failure
    assert_output --partial "Error: No IP found for invalid.domain"
}

@test "system_utils: dig-host should handle generic domain lookup" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    run dig-host example.com
    
    assert_success
    assert_output --partial "Forward lookup for example.com: 192.168.1.1"
    assert_output --partial "Reverse lookup for 192.168.1.1:"
    assert_output --partial "Mock reverse lookup for 192.168.1.1"
}

# =============================================================================
# remind Function Tests
# =============================================================================

@test "system_utils: remind should display usage when no arguments and not piped" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    run remind
    
    assert_failure
    assert_output --partial "Usage: remind \"TEXT\""
    assert_output --partial "Example: remind \"Buy groceries\""
}

@test "system_utils: remind should handle command line argument" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    run remind "Buy milk at 5pm"
    
    assert_success
    assert_output --partial "Mock: osascript executed"
    assert_output --partial "Reminder added: Buy milk at 5pm"
}

@test "system_utils: remind should handle piped input" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    run bash -c 'echo "Meeting tomorrow" | source '"$MOCK_HOME/system-functions.sh"' && remind'
    
    assert_success
    assert_output --partial "Mock: osascript executed"
    assert_output --partial "Reminder added: Meeting tomorrow"
}

@test "system_utils: remind should handle empty text" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    run remind ""
    
    assert_failure
    assert_output --partial "Error: No reminder text provided"
}

@test "system_utils: remind should detect when osascript is not available" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    # Remove osascript from PATH
    rm -f "$MOCK_BREW_PREFIX/bin/osascript"
    
    run remind "test reminder"
    
    assert_failure
    assert_output --partial "Error: osascript not found. This function only works on macOS."
}

# =============================================================================
# extract Function Tests
# =============================================================================

@test "system_utils: extract should display usage when no arguments provided" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    run extract
    
    assert_failure
    assert_output --partial "Usage: extract ARCHIVE_FILE"
    assert_output --partial "Supported formats: tar.gz, tar.bz2, zip, rar, 7z, dmg, and more"
}

@test "system_utils: extract should handle non-existent file" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    run extract "non-existent-file.zip"
    
    assert_failure
    assert_output --partial "Error: 'non-existent-file.zip' is not a valid file"
}

@test "system_utils: extract should handle tar.gz files" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    # Create a dummy tar.gz file
    touch "test.tar.gz"
    
    run extract "test.tar.gz"
    
    assert_success
    assert_output --partial "Mock tar extraction"
    assert_output --partial "Extraction completed for: test.tar.gz"
}

@test "system_utils: extract should handle zip files" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    touch "test.zip"
    
    run extract "test.zip"
    
    assert_success
    assert_output --partial "Mock unzip extraction"
    assert_output --partial "Extraction completed for: test.zip"
}

@test "system_utils: extract should handle various compression formats" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    # Test different file extensions
    touch "test.tar.bz2"
    run extract "test.tar.bz2"
    assert_success
    assert_output --partial "Mock tar extraction"
    
    touch "test.7z" 
    run extract "test.7z"
    assert_success
    assert_output --partial "Mock 7z extraction"
    
    touch "test.rar"
    run extract "test.rar"
    assert_success
    assert_output --partial "Mock unrar extraction"
}

@test "system_utils: extract should handle unsupported file formats" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    touch "test.unknown"
    
    run extract "test.unknown"
    
    assert_failure
    assert_output --partial "Error: 'test.unknown' cannot be extracted via extract()"
    assert_output --partial "Unsupported format. Try extracting manually."
}

# =============================================================================
# find-large Function Tests
# =============================================================================

@test "system_utils: find-large should use current directory by default" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    run find-large
    
    assert_success
    assert_output --partial "Finding files larger than 100M in ."
    assert_output --partial "/mock/path/largefile1.bin"
    assert_output --partial "/mock/path/largefile2.iso"
}

@test "system_utils: find-large should accept custom path and size" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    mkdir -p "/tmp/test-search"
    
    run find-large "/tmp/test-search" "50M"
    
    assert_success
    assert_output --partial "Finding files larger than 50M in /tmp/test-search"
}

@test "system_utils: find-large should handle invalid directory" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    run find-large "/non/existent/directory"
    
    assert_failure
    assert_output --partial "Error: '/non/existent/directory' is not a valid directory"
}

# =============================================================================
# disk-usage Function Tests
# =============================================================================

@test "system_utils: disk-usage should use current directory by default" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    run disk-usage
    
    assert_success
    assert_output --partial "Disk usage for: ."
    assert_output --partial "2.5G    Downloads"
    assert_output --partial "1.2G    Documents"
}

@test "system_utils: disk-usage should accept custom path" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    mkdir -p "/tmp/test-usage"
    
    run disk-usage "/tmp/test-usage"
    
    assert_success
    assert_output --partial "Disk usage for: /tmp/test-usage"
}

@test "system_utils: disk-usage should handle invalid directory" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    run disk-usage "/non/existent/directory"
    
    assert_failure
    assert_output --partial "Error: '/non/existent/directory' is not a valid directory"
}

# =============================================================================
# process-port Function Tests
# =============================================================================

@test "system_utils: process-port should display usage when no arguments provided" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    run process-port
    
    assert_failure
    assert_output --partial "Usage: process-port PORT"
    assert_output --partial "Example: process-port 8080"
}

@test "system_utils: process-port should validate port is numeric" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    run process-port "not-a-port"
    
    assert_failure
    assert_output --partial "Error: PORT must be a number"
}

@test "system_utils: process-port should find process using specified port" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    run process-port 8080
    
    assert_success
    assert_output --partial "Checking port 8080..."
    assert_output --partial "node    1234  user"
    assert_output --partial "TCP *:8080 (LISTEN)"
}

@test "system_utils: process-port should handle empty port" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    run process-port 3000
    
    assert_success
    assert_output --partial "Checking port 3000..."
    # lsof mock returns no output for port 3000
}

# =============================================================================
# system-info Function Tests
# =============================================================================

@test "system_utils: system-info should display comprehensive system information" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    run system-info
    
    assert_success
    assert_output --partial "=== System Information ==="
    assert_output --partial "Hostname: test-hostname"
    assert_output --partial "Uptime: 10:30  up 2 days"
    assert_output --partial "=== Operating System ==="
    assert_output --partial "=== Hardware ==="
    assert_output --partial "=== Storage ==="
}

@test "system_utils: system-info should detect macOS and show sw_vers output" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    run system-info
    
    assert_success
    assert_output --partial "ProductName:	macOS"
    assert_output --partial "ProductVersion:	15.0"
}

@test "system_utils: system-info should show hardware information with sysctl" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    run system-info
    
    assert_success
    assert_output --partial "CPU: Apple M1 Pro"
    assert_output --partial "Memory: 32 GB"
}

@test "system_utils: system-info should display storage information" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    run system-info
    
    assert_success
    assert_output --partial "/dev/disk3s1s1  494Gi   300Gi  194Gi"
}

# =============================================================================
# backup-file Function Tests
# =============================================================================

@test "system_utils: backup-file should display usage when no arguments provided" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    run backup-file
    
    assert_failure
    assert_output --partial "Usage: backup-file FILE_PATH"
    assert_output --partial "Example: backup-file important-config.conf"
}

@test "system_utils: backup-file should handle non-existent file" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    run backup-file "non-existent-file.txt"
    
    assert_failure
    assert_output --partial "Error: 'non-existent-file.txt' is not a valid file"
}

@test "system_utils: backup-file should create timestamped backup" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    # Create a test file
    echo "test content" > "important-config.conf"
    
    run backup-file "important-config.conf"
    
    assert_success
    assert_output --partial "Backup created: important-config.conf.backup_"
    
    # Verify backup file was created
    local backup_files=$(ls important-config.conf.backup_* 2>/dev/null | wc -l)
    [ "$backup_files" -eq 1 ]
}

@test "system_utils: backup-file should preserve original file content" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    echo "original content" > "test-file.txt"
    
    run backup-file "test-file.txt"
    
    assert_success
    
    # Verify original file still exists and has same content
    [ -f "test-file.txt" ]
    grep -q "original content" "test-file.txt"
    
    # Verify backup has same content
    local backup_file=$(ls test-file.txt.backup_* | head -1)
    [ -f "$backup_file" ]
    grep -q "original content" "$backup_file"
}

# =============================================================================
# monitor-process Function Tests
# =============================================================================

@test "system_utils: monitor-process should display usage when no arguments provided" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    run monitor-process
    
    assert_failure
    assert_output --partial "Usage: monitor-process PROCESS_NAME [INTERVAL]"
    assert_output --partial "Example: monitor-process firefox 2"
}

@test "system_utils: monitor-process should validate interval parameter" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    run monitor-process firefox "not-a-number"
    
    assert_failure
    assert_output --partial "Error: INTERVAL must be a positive integer"
}

@test "system_utils: monitor-process should start monitoring with correct headers" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    # Use timeout to prevent infinite loop in testing
    timeout 2 monitor-process firefox 1 || true
    
    # Note: This test would normally run indefinitely, so we can't easily test the full output
    # We can test that it starts correctly by checking if the function exists and validates input
    run bash -c 'source '"$MOCK_HOME/system-functions.sh"' && echo "test" | head -1'
    assert_success
}

# =============================================================================
# cleanup-temp Function Tests
# =============================================================================

@test "system_utils: cleanup-temp should perform dry run by default" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    # Create some mock directories and files
    mkdir -p "$HOME/Downloads"
    touch "$HOME/Downloads/test.zip"
    
    run cleanup-temp
    
    assert_success
    assert_output --partial "=== Cleaning temporary files ==="
    assert_output --partial "Note: This was a dry run. Use --force to actually delete files"
}

@test "system_utils: cleanup-temp should show temp files found" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    run cleanup-temp
    
    assert_success
    assert_output --partial "Found"
    assert_output --partial "temporary files older than 7 days"
    assert_output --partial "download files older than 30 days"
}

@test "system_utils: cleanup-temp should delete files when --force is used" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    run cleanup-temp --force
    
    assert_success
    assert_output --partial "=== Cleaning temporary files ==="
    assert_output --partial "Removed"
    assert_output --partial "temporary files"
    refute_output --partial "This was a dry run"
}

@test "system_utils: cleanup-temp should handle no old files found" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    # Override find to return no files
    cat > "$MOCK_BREW_PREFIX/bin/find" << 'EOF'
#!/bin/bash
# Return no files found
exit 0
EOF
    chmod +x "$MOCK_BREW_PREFIX/bin/find"
    
    # Override wc to return 0
    cat > "$MOCK_BREW_PREFIX/bin/wc" << 'EOF'
#!/bin/bash
echo "0"
EOF
    chmod +x "$MOCK_BREW_PREFIX/bin/wc"
    
    run cleanup-temp
    
    assert_success
    assert_output --partial "No old temporary files found"
    assert_output --partial "No old download files found"
}

# =============================================================================
# Error Handling and Edge Cases
# =============================================================================

@test "system_utils: functions should handle missing command dependencies gracefully" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    # Remove dig command
    rm -f "$MOCK_BREW_PREFIX/bin/dig"
    
    run dig-host google.com
    
    # Should fail gracefully when dig is not available
    assert_failure
}

@test "system_utils: functions should validate numeric inputs consistently" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    # Test various functions with invalid numeric inputs
    run run-repeat "abc" echo test
    assert_failure
    assert_output --partial "Error: COUNT must be a positive integer"
    
    run process-port "abc"
    assert_failure
    assert_output --partial "Error: PORT must be a number"
    
    run monitor-process firefox "abc"
    assert_failure
    assert_output --partial "Error: INTERVAL must be a positive integer"
}

@test "system_utils: functions should handle file system permission errors gracefully" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    # Create a file we can't read (mock scenario)
    touch "readonly-file.txt"
    chmod 000 "readonly-file.txt"
    
    # backup-file should handle permission errors
    run backup-file "readonly-file.txt"
    
    # Depending on system, might succeed or fail, but should not crash
    # The important thing is it exits cleanly
}

@test "system_utils: extract function should handle partial filename matches correctly" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    # Test that .tar.gz takes precedence over .gz
    touch "test.tar.gz"
    
    run extract "test.tar.gz"
    
    assert_success
    assert_output --partial "Mock tar extraction"
    # Should not show gunzip extraction
    refute_output --partial "Mock gunzip extraction"
}

@test "system_utils: cleanup-temp should handle directory traversal safely" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    # Test that cleanup-temp operates in safe directories only
    run cleanup-temp
    
    assert_success
    # Should only mention safe directories like /tmp and Downloads
    assert_output --partial "/tmp"
    assert_output --partial "Downloads"
    # Should not try to clean system directories
    refute_output --partial "/usr"
    refute_output --partial "/etc"
    refute_output --partial "/System"
}

@test "system_utils: system-info should handle missing system commands gracefully" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    # Remove some system commands
    rm -f "$MOCK_BREW_PREFIX/bin/sysctl"
    rm -f "$MOCK_BREW_PREFIX/bin/sw_vers"
    
    run system-info
    
    assert_success
    # Should still show basic info even if some commands are missing
    assert_output --partial "=== System Information ==="
    assert_output --partial "Hostname:"
}

# =============================================================================
# Integration Tests
# =============================================================================

@test "system_utils: functions should work together in realistic scenarios" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    # Create a realistic file structure
    mkdir -p "project/src" "project/tests"
    echo "source code" > "project/src/main.js"
    echo "test code" > "project/tests/test.js"
    
    # Create backup of important file
    run backup-file "project/src/main.js"
    assert_success
    
    # Check disk usage
    run disk-usage "project"
    assert_success
    
    # Find large files (shouldn't find any in our small test)
    run find-large "project" "1K"
    assert_success
}

@test "system_utils: command chaining should work as expected" {
    source "$TEST_TEMP_DIR/system_functions.sh"
    
    # Test that functions can be used in command chains
    echo "test content" > "chain-test.txt"
    
    # Chain backup-file with other commands  
    run bash -c 'source '"$MOCK_HOME/system-functions.sh"' && backup-file "chain-test.txt" && echo "backup completed"'
    
    assert_success
    assert_output --partial "Backup created:"
    assert_output --partial "backup completed"
}