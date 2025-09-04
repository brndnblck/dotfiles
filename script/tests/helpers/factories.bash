#!/usr/bin/env bash

# PROPOSED: Mock Factory Functions
# Eliminates duplicate mock creation across test files

# =============================================================================
# SPECIALIZED MOCK FACTORIES - Replace duplicate mock creation
# =============================================================================

# Create comprehensive system mocks (used in status.bats, bootstrap.bats, etc.)
create_system_info_mocks() {
    local os_version="${1:-15.0}"
    local architecture="${2:-arm64}"
    local hostname="${3:-test-macbook-pro.local}"

    # sw_vers with configurable version
    cat >"$MOCK_BREW_PREFIX/bin/sw_vers" <<EOF
#!/bin/bash
case "\$1" in
    "-productVersion")
        echo "$os_version"
        ;;
    *)
        echo "ProductName:	macOS"
        echo "ProductVersion:	$os_version"
        echo "BuildVersion:	24A335"
        ;;
esac
EOF
    chmod +x "$MOCK_BREW_PREFIX/bin/sw_vers"

    # uname with configurable architecture
    create_mock_script "uname" 0 "$architecture"

    # hostname
    create_mock_script "hostname" 0 "$hostname"
}

# Create development tools mocks (used in status.bats, setup.bats)
create_dev_tools_mocks() {
    local git_version="${1:-2.42.0}"
    local node_version="${2:-v20.5.0}"
    local python_version="${3:-3.11.4}"
    local rust_version="${4:-1.71.0}"
    local go_version="${5:-1.20.5}"
    local docker_version="${6:-24.0.5}"

    # Git
    cat >"$MOCK_BREW_PREFIX/bin/git" <<EOF
#!/bin/bash
case "\$1" in
    "--version")
        echo "git version $git_version"
        ;;
    "status")
        if [[ "\$2" == "--porcelain" ]]; then
            echo ""  # Clean status
        fi
        ;;
    *)
        echo "Mock git: \$*"
        ;;
esac
EOF
    chmod +x "$MOCK_BREW_PREFIX/bin/git"

    # Node.js
    create_mock_script "node" 0 "$node_version" "--version"

    # Python
    create_mock_script "python3" 0 "Python $python_version" "--version"

    # Rust
    create_mock_script "rustc" 0 "rustc $rust_version (8ede3aae2 2023-07-12)" "--version"

    # Go
    cat >"$MOCK_BREW_PREFIX/bin/go" <<EOF
#!/bin/bash
case "\$1" in
    "version")
        echo "go version go$go_version darwin/arm64"
        ;;
esac
EOF
    chmod +x "$MOCK_BREW_PREFIX/bin/go"

    # Docker
    create_mock_script "docker" 0 "Docker version $docker_version, build ced0996" "--version"
}

# Enhanced brew mock with package tracking (used in multiple files)
create_package_aware_brew_mock() {
    local formulae_list="${1:-git curl wget node python@3.11}"
    local cask_list="${2:-visual-studio-code firefox docker}"
    local outdated_formulae="${3:-curl wget}"
    local outdated_casks="${4:-firefox}"

    cat >"$MOCK_BREW_PREFIX/bin/brew" <<EOF
#!/bin/bash
case "\$1" in
    "--version")
        echo "Homebrew 4.0.0"
        echo "Homebrew/homebrew-core (git revision 123abc; last commit 2023-01-01)"
        ;;
    "list")
        if [[ "\$2" == "--formula" ]]; then
            echo -e "${formulae_list//[[:space:]]/\\n}"
        elif [[ "\$2" == "--cask" ]]; then
            echo -e "${cask_list//[[:space:]]/\\n}"
        fi
        ;;
    "outdated")
        if [[ "\$2" == "--formula" ]]; then
            for pkg in $outdated_formulae; do
                echo "\$pkg (old) < 8.0.0 (new)"
            done
        elif [[ "\$2" == "--cask" ]]; then
            for pkg in $outdated_casks; do
                echo "\$pkg (old) != (new)"
            done
        fi
        ;;
    "bundle")
        if [[ "\$*" =~ "--file=" ]]; then
            local brewfile=\$(echo "\$*" | sed 's/.*--file=\([^ ]*\).*/\1/' | tr -d '"')
            echo "==> Installing packages from \$brewfile"
            echo "==> All packages installed successfully"
        else
            echo "==> Installing packages from Brewfile"
        fi
        ;;
    *)
        echo "Mock brew: \$*"
        ;;
esac
EOF
    chmod +x "$MOCK_BREW_PREFIX/bin/brew"
}

# Gum mock with standardized behaviors (used in all UI tests)
create_standardized_gum_mock() {
    local default_choice="${1:-first}" # "first", "abort", "confirm"

    cat >"$MOCK_BREW_PREFIX/bin/gum" <<EOF
#!/bin/bash
case "\$1" in
    "choose")
        shift
        # Handle choice behavior
        case "$default_choice" in
            "first")
                while [[ \$# -gt 0 ]]; do
                    case "\$1" in
                        --*) shift ;;
                        *)
                            echo "\$1"
                            exit 0
                            ;;
                    esac
                    shift
                done
                ;;
            "abort")
                exit 1
                ;;
        esac
        ;;
    "confirm")
        case "$default_choice" in
            "confirm") exit 0 ;;
            "abort"|"decline") exit 1 ;;
            *) exit 0 ;;  # Default to confirm
        esac
        ;;
    "style")
        shift
        while [[ \$# -gt 0 ]]; do
            case "\$1" in
                --*) shift ;;
                *)
                    echo "\$1"
                    break
                    ;;
            esac
            shift
        done
        ;;
    "spin")
        shift
        while [[ \$# -gt 0 ]]; do
            case "\$1" in
                "--title")
                    echo "SPINNER: \$2"
                    shift 2
                    ;;
                "--")
                    shift
                    bash -c "\$*"
                    return \$?
                    ;;
                *)
                    shift
                    ;;
            esac
        done
        ;;
    *)
        echo "Mock gum: \$*"
        ;;
esac
exit 0
EOF
    chmod +x "$MOCK_BREW_PREFIX/bin/gum"
}

# =============================================================================
# COMPOSITE MOCK SETUPS - Common combinations
# =============================================================================

# Complete system status mocks (replaces create_status_mocks in status.bats)
setup_status_test_mocks() {
    create_system_info_mocks
    create_dev_tools_mocks
    create_package_aware_brew_mock
    create_standardized_gum_mock

    # Enhanced chezmoi mock
    cat >"$MOCK_BREW_PREFIX/bin/chezmoi" <<EOF
#!/bin/bash
case "\$1" in
    "source-path")
        echo "\$DOTFILES_PARENT_DIR"
        ;;
    *)
        echo "Mock chezmoi: \$*"
        ;;
esac
EOF
    chmod +x "$MOCK_BREW_PREFIX/bin/chezmoi"

    # MAS mock
    create_mock_script "mas" 0 "497799835 Xcode (14.3.1)\\n1295203466 Microsoft Remote Desktop (10.7.7)" "list"
}

# UI testing mocks (for main.bats, ui.bats)
setup_ui_test_mocks() {
    create_standardized_gum_mock "first"
    setup_macos_mocks
}

# Bootstrap testing mocks (specific trigger scenarios)
setup_bootstrap_test_mocks() {
    setup_macos_mocks
    create_standardized_gum_mock "confirm"

    # Add bootstrap-specific mocks
    create_mock_script "fdesetup" 0 "FileVault is On."
}

# =============================================================================
# USAGE EXAMPLES
# =============================================================================

# BEFORE (in status.bats):
# create_status_mocks() {
#     # 50+ lines of duplicate mock creation
# }

# AFTER (in status.bats):
# setup() {
#     setup_script_test "status"
#     setup_status_test_mocks
# }

# BEFORE (in main.bats):
# Long setup with individual mock creation

# AFTER (in main.bats):
# setup() {
#     setup_ui_test "main"
#     setup_ui_test_mocks
# }
