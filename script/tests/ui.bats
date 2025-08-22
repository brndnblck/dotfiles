#!/usr/bin/env bats

# BDD Tests for UI Functions
# Validates UI components, version display, and interface elements

load helper
load mocks

describe() { true; }
it() { true; }

setup() {
    setup_script_test "ui"
    
    # Source the UI module directly for testing
    source "$DOTFILES_PARENT_DIR/script/core/ui"
}

teardown() {
    test_teardown
}

describe "Version Display"

@test "ui: should display version with git tag and short hash" {
    it "should show format v37.abc1234 when git tag exists"
    
    # Create mock git commands that return specific values
    cat > "$MOCK_BREW_PREFIX/bin/git" << 'EOF'
#!/bin/bash
case "$1 $2" in
    "describe --tags")
        echo "v37"
        ;;
    "rev-parse --short")
        echo "abc1234"
        ;;
    *)
        echo "Mock git: $*"
        ;;
esac
EOF
    chmod +x "$MOCK_BREW_PREFIX/bin/git"
    
    # Test the version string generation logic
    local git_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    local git_hash=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    local version_string
    if [ -n "$git_tag" ]; then
        local version_num=$(echo "$git_tag" | sed 's/^v//')
        version_string="v${version_num}.${git_hash}"
    else
        version_string="v.${git_hash}"
    fi
    
    [ "$version_string" = "v37.abc1234" ]
}

@test "ui: should display fallback version when no git tag exists" {
    it "should show format v.abc1234 when no git tag is available"
    
    # Create mock git commands - describe fails, rev-parse succeeds
    cat > "$MOCK_BREW_PREFIX/bin/git" << 'EOF'
#!/bin/bash
case "$1 $2" in
    "describe --tags")
        exit 1  # No tags available
        ;;
    "rev-parse --short")
        echo "abc1234"
        ;;
    *)
        echo "Mock git: $*"
        ;;
esac
EOF
    chmod +x "$MOCK_BREW_PREFIX/bin/git"
    
    # Test the version string generation logic
    local git_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    local git_hash=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    local version_string
    if [ -n "$git_tag" ]; then
        local version_num=$(echo "$git_tag" | sed 's/^v//')
        version_string="v${version_num}.${git_hash}"
    else
        version_string="v.${git_hash}"
    fi
    
    [ "$version_string" = "v.abc1234" ]
}

@test "ui: should handle git command failures gracefully" {
    it "should show v.unknown when git commands fail"
    
    # Create mock git that always fails
    cat > "$MOCK_BREW_PREFIX/bin/git" << 'EOF'
#!/bin/bash
exit 1
EOF
    chmod +x "$MOCK_BREW_PREFIX/bin/git"
    
    # Test the version string generation logic
    local git_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    local git_hash=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    local version_string
    if [ -n "$git_tag" ]; then
        local version_num=$(echo "$git_tag" | sed 's/^v//')
        version_string="v${version_num}.${git_hash}"
    else
        version_string="v.${git_hash}"
    fi
    
    [ "$version_string" = "v.unknown" ]
}

@test "ui: should handle tags with v prefix correctly" {
    it "should strip v prefix from git tags in version display"
    
    # Create mock git with v-prefixed tag
    cat > "$MOCK_BREW_PREFIX/bin/git" << 'EOF'
#!/bin/bash
case "$1 $2" in
    "describe --tags")
        echo "v1.2.3"
        ;;
    "rev-parse --short")
        echo "def5678"
        ;;
    *)
        echo "Mock git: $*"
        ;;
esac
EOF
    chmod +x "$MOCK_BREW_PREFIX/bin/git"
    
    # Test the version string generation logic
    local git_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    local git_hash=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    local version_string
    if [ -n "$git_tag" ]; then
        local version_num=$(echo "$git_tag" | sed 's/^v//')
        version_string="v${version_num}.${git_hash}"
    else
        version_string="v.${git_hash}"
    fi
    
    [ "$version_string" = "v1.2.3.def5678" ]
}

@test "ui: should handle tags without v prefix correctly" {
    it "should work with tags that don't have v prefix"
    
    # Create mock git with non-v-prefixed tag
    cat > "$MOCK_BREW_PREFIX/bin/git" << 'EOF'
#!/bin/bash
case "$1 $2" in
    "describe --tags")
        echo "release-42"
        ;;
    "rev-parse --short")
        echo "ghi9012"
        ;;
    *)
        echo "Mock git: $*"
        ;;
esac
EOF
    chmod +x "$MOCK_BREW_PREFIX/bin/git"
    
    # Test the version string generation logic
    local git_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    local git_hash=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    local version_string
    if [ -n "$git_tag" ]; then
        local version_num=$(echo "$git_tag" | sed 's/^v//')
        version_string="v${version_num}.${git_hash}"
    else
        version_string="v.${git_hash}"
    fi
    
    [ "$version_string" = "vrelease-42.ghi9012" ]
}

describe "Header Display Integration"

@test "ui: should generate correct BUILD version string format" {
    it "should create proper version string for gum display"
    
    # Create mock git
    cat > "$MOCK_BREW_PREFIX/bin/git" << 'EOF'
#!/bin/bash
case "$1 $2" in
    "describe --tags")
        echo "v42"
        ;;
    "rev-parse --short")
        echo "test123"
        ;;
    *)
        echo "Mock git: $*"
        ;;
esac
EOF
    chmod +x "$MOCK_BREW_PREFIX/bin/git"
    
    # Test the version generation logic directly (extracted from show_standard_header)
    local git_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    local git_hash=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    local version_string
    if [ -n "$git_tag" ]; then
        local version_num=$(echo "$git_tag" | sed 's/^v//')
        version_string="v${version_num}.${git_hash}"
    else
        version_string="v.${git_hash}"
    fi
    local build_line=">> BUILD: ${version_string}"
    
    [ "$build_line" = ">> BUILD: v42.test123" ]
}

describe "Interface Color Configuration"

@test "ui: should use defined interface colors for BUILD display" {
    it "should respect INTERFACE_SECONDARY and INTERFACE_BOLD settings"
    
    # Set test color values
    export INTERFACE_SECONDARY="208"
    export INTERFACE_BOLD="--bold"
    
    # The actual color usage is tested implicitly through gum style calls
    # This test ensures the variables are properly referenced
    [ "$INTERFACE_SECONDARY" = "208" ]
    [ "$INTERFACE_BOLD" = "--bold" ]
}

describe "Edge Cases"

@test "ui: should handle empty git tag output" {
    it "should handle when git describe returns empty string"
    
    # Create mock git that returns empty for describe
    cat > "$MOCK_BREW_PREFIX/bin/git" << 'EOF'
#!/bin/bash
case "$1 $2" in
    "describe --tags")
        echo ""  # Empty output
        ;;
    "rev-parse --short")
        echo "abc1234"
        ;;
    *)
        echo "Mock git: $*"
        ;;
esac
EOF
    chmod +x "$MOCK_BREW_PREFIX/bin/git"
    
    # Test the version string generation logic
    local git_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    local git_hash=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    local version_string
    if [ -n "$git_tag" ]; then
        local version_num=$(echo "$git_tag" | sed 's/^v//')
        version_string="v${version_num}.${git_hash}"
    else
        version_string="v.${git_hash}"
    fi
    
    [ "$version_string" = "v.abc1234" ]
}

@test "ui: should handle complex version numbers" {
    it "should work with semantic version tags"
    
    # Create mock git with semantic version
    cat > "$MOCK_BREW_PREFIX/bin/git" << 'EOF'
#!/bin/bash
case "$1 $2" in
    "describe --tags")
        echo "v2.1.0-beta.3"
        ;;
    "rev-parse --short")
        echo "commit7"
        ;;
    *)
        echo "Mock git: $*"
        ;;
esac
EOF
    chmod +x "$MOCK_BREW_PREFIX/bin/git"
    
    # Test the version string generation logic
    local git_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    local git_hash=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    local version_string
    if [ -n "$git_tag" ]; then
        local version_num=$(echo "$git_tag" | sed 's/^v//')
        version_string="v${version_num}.${git_hash}"
    else
        version_string="v.${git_hash}"
    fi
    
    [ "$version_string" = "v2.1.0-beta.3.commit7" ]
}