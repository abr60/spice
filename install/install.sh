#!/usr/bin/env bash
# =============================================================================
# spice - Bootstrap Installer
# Sourced from: https://github.com/abr60/spice.git
# Usage: curl -fsSL https://raw.githubusercontent.com/abr60/spice/main/install | bash
# =============================================================================

set -uo pipefail

TARGET_DIR="$HOME/spice"
REPO_URL="https://github.com/abr60/spice.git"

# Text Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Spice Dotfiles Installer ===${NC}"

# Ensure git is installed
if ! command -v git &>/dev/null; then
    echo -e "${RED}Error: git is required to install spice. Please install git and run this script again.${NC}" >&2
    exit 1
fi

# Clone or update the repository
if [ -d "$TARGET_DIR" ]; then
    echo -e "${BLUE}Spice directory already exists at $TARGET_DIR. Updating repository...${NC}"
    if git -C "$TARGET_DIR" pull; then
        echo -e "${GREEN}Repository updated successfully.${NC}"
    else
        echo -e "${RED}Warning: Failed to update the git repository. Proceeding with existing files.${NC}" >&2
    fi
else
    echo -e "${BLUE}Cloning spice repository into $TARGET_DIR...${NC}"
    if git clone "$REPO_URL" "$TARGET_DIR"; then
        echo -e "${GREEN}Repository cloned successfully.${NC}"
    else
        echo -e "${RED}Error: Failed to clone the repository.${NC}" >&2
        exit 1
    fi
fi

# Run the setup script
echo -e "${BLUE}Transitioning to spice setup...${NC}"
cd "$TARGET_DIR" || exit 1

# Ensure setup.sh is executable
chmod +x setup.sh

# Run setup.sh, replacing the current process so it receives inputs correctly
exec ./setup.sh
