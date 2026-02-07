#!/bin/bash
#===============================================================================
# Paqet AutoDevOps - One-Step Installer
# Version: 1.1.0 | Author: oxychain-net | License: MIT
#
# Purpose:
#   Bootstrap the installation by cloning the repo and running the installer.
#   Solves issues with piped execution (curl | bash).
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/oxychain-net/paqet-autodevops/main/install.sh | sudo bash
#
#===============================================================================

set -euo pipefail

# Redirect stdin from tty if available to support interactive prompts when piped
if [ ! -t 0 ] && [ -e /dev/tty ]; then
    exec < /dev/tty
fi

readonly SCRIPT_VERSION="1.1.0"
readonly REPO_URL="https://github.com/oxychain-net/paqet-autodevops.git"
readonly INSTALL_DIR="/opt/paqet-autodevops"

# Colors
readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[1;33m'
readonly C_CYAN='\033[0;36m'
readonly C_RED='\033[0;31m'
readonly C_BOLD='\033[1m'
readonly C_NC='\033[0m'

# Function to check connectivity with IPv4 fallback
check_connectivity() {
    local url=$1
    if curl -s --head --connect-timeout 5 "$url" > /dev/null; then
        return 0
    elif curl -4 -s --head --connect-timeout 5 "$url" > /dev/null; then
        echo -e "${C_YELLOW}Notice: IPv6 connection failed, switching to IPv4 for git operations.${C_NC}"
        git config --global http.postBuffer 524288000
        # Force IPv4 for git
        export GIT_SSH_COMMAND='ssh -o IPQoS=throughput -4'
        return 0
    else
        return 1
    fi
}

check_root() {
    if [[ ${EUID} -ne 0 ]]; then
        echo -e "${C_RED}✗ This script must be run as root${C_NC}"
        exit 1
    fi
}

install_git() {
    if ! command -v git &> /dev/null; then
        echo -e "${C_YELLOW}▶ Installing git...${C_NC}"
        if [ -f /etc/debian_version ]; then
            apt-get update -qq && apt-get install -y -qq git
        elif [ -f /etc/redhat-release ]; then
            yum install -y -q git
        elif [ -f /etc/arch-release ]; then
            pacman -Sy --noconfirm git
        elif [ -f /etc/alpine-release ]; then
            apk add git
        else
            echo -e "${C_RED}✗ Unsupported distribution. Please install git manually.${C_NC}"
            exit 1
        fi
        echo -e "${C_GREEN}✓ Git installed${C_NC}"
    fi
}

clone_repo() {
    echo -e "${C_YELLOW}▶ Preparing installation files...${C_NC}"
    
    # Pre-check connectivity to GitHub
    if ! check_connectivity "https://github.com"; then
         echo -e "${C_YELLOW}Warning: GitHub might be unreachable. Retrying with IPv4 forced...${C_NC}"
    fi

    if [ -d "${INSTALL_DIR}" ]; then
        echo -e "${C_CYAN}  Updating existing repository in ${INSTALL_DIR}...${C_NC}"
        cd "${INSTALL_DIR}"
        git fetch --all --quiet
        git reset --hard origin/main --quiet || git reset --hard origin/master --quiet
    else
        echo -e "${C_CYAN}  Cloning repository to ${INSTALL_DIR}...${C_NC}"
        # Try normal clone first, then IPv4 forced if failed
        if ! git clone --quiet "${REPO_URL}" "${INSTALL_DIR}"; then
             echo -e "${C_YELLOW}Clone failed. Retrying with IPv4...${C_NC}"
             git clone --quiet --config core.sshCommand="ssh -4" "${REPO_URL}" "${INSTALL_DIR}"
        fi
        cd "${INSTALL_DIR}"
    fi
    
    chmod +x *.sh
    echo -e "${C_GREEN}✓ Files prepared${C_NC}"
}

main() {
    check_root
    
    echo ""
    echo -e "${C_CYAN}════════════════════════════════════════════════════${C_NC}"
    echo -e "${C_BOLD}${C_GREEN}Paqet AutoDevOps - One-Step Installer v${SCRIPT_VERSION}${C_NC}"
    echo -e "${C_CYAN}════════════════════════════════════════════════════${C_NC}"
    echo ""
    
    install_git
    clone_repo
    
    echo -e "${C_BOLD}Starting installation process...${C_NC}"
    echo ""
    
    # Run installer
    # Note: --full-install will automatically run paqet-prerequisites.sh if found
    ./paqet-installer.sh --full-install
    
    # Install management scripts
    echo ""
    echo -e "${C_YELLOW}▶ Installing management scripts to /usr/local/bin...${C_NC}"
    cp paqet-*.sh /usr/local/bin/
    
    echo ""
    echo -e "${C_GREEN}${C_BOLD}═══════════════════════════════════════════════════${C_NC}"
    echo -e "${C_GREEN}${C_BOLD}Installation Complete!${C_NC}"
    echo -e "${C_GREEN}${C_BOLD}═══════════════════════════════════════════════════${C_NC}"
    echo ""
    echo "Management commands:"
    echo "  - paqet-manager.sh      (Interactive management)"
    echo "  - paqet-prerequisites.sh (Re-run optimization)"
    echo "  - paqet-installer.sh    (Reconfigure Paqet)"
    echo ""
}

main "$@"
