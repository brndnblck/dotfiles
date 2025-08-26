#!/usr/bin/env bash

# Minimal Dotfiles Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/username/dotfiles/main/install.sh | bash

set -euo pipefail

# Configuration
REPO="https://github.com/brandon/dotfiles.git"  # Update with your GitHub username
TEMP_DIR="/tmp/dotfiles-install-$$"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

error() {
    echo -e "${RED}Error: $1${NC}" >&2
    cleanup
    exit 1
}

success() {
    echo -e "${GREEN}$1${NC}"
}

cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}

# Trap to ensure cleanup on exit
trap cleanup EXIT

# Check macOS
[[ "$OSTYPE" == "darwin"* ]] || error "macOS required"

echo "Installing dotfiles system..."

# Install Command Line Tools if needed
if ! xcode-select -p >/dev/null 2>&1; then
    echo "Installing Xcode Command Line Tools..."
    echo "Click 'Install' in the popup dialog"
    xcode-select --install
    
    # Wait for installation
    until xcode-select -p >/dev/null 2>&1; do
        sleep 5
    done
    
    success "Command Line Tools installed"
fi

# Verify git
command -v git >/dev/null 2>&1 || error "Git not available"

# Clone to temp directory
echo "Downloading dotfiles..."
git clone "$REPO" "$TEMP_DIR" || error "Failed to clone repository"

# Hand off to bootstrap
cd "$TEMP_DIR"
exec ./script/bootstrap