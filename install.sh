#!/bin/bash
#===============================================================================
# Paqet AutoDevOps - One-Step Installer
# Version: 1.0.0 | Author: oxychain-net | License: MIT
#
# Purpose:
#   Complete automated installation of Paqet with prerequisites
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/oxychain-net/paqet-autodevops/main/install.sh | sudo bash
#
#===============================================================================

set -euo pipefail

readonly SCRIPT_VERSION="1.0.0"
readonly BASE_URL="https://raw.githubusercontent.com/oxychain-net/paqet-autodevops/main"

# Colors
readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[1;33m'
readonly C_CYAN='\033[0;36m'
readonly C_BOLD='\033[1m'
readonly C_NC='\033[0m'

check_root() {
    if [[ ${EUID} -ne 0 ]]; then
        echo -e "${C_RED}✗ This script must be run as root${C_NC}"
        exit 1
    fi
}

print_header() {
    clear
    echo ""
    echo -e "${C_CYAN}════════════════════════════════════════════════════${C_NC}"
    echo -e "${C_BOLD}${C_GREEN}Paqet AutoDevOps - One-Step Installer v${SCRIPT_VERSION}${C_NC}"
    echo -e "${C_CYAN}════════════════════════════════════════════════════${C_NC}"
    echo ""
}

download_script() {
    local script_name="$1"
    local url="${BASE_URL}/${script_name}"
    
    echo -e "${C_YELLOW}▶ Downloading ${script_name}...${C_NC}"
    
    curl -fsSL "${url}" -o "/tmp/${script_name}"
    chmod +x "/tmp/${script_name}"
    
    echo -e "${C_GREEN}✓ ${script_name} downloaded${C_NC}"
}

main() {
    check_root
    print_header
    
    echo "This will install Paqet with all prerequisites."
    echo ""
    echo "Installation steps:"
    echo "  1. Install system dependencies (Go, libpcap, etc.)"
    echo "  2. Optimize Linux kernel for networking"
    echo "  3. Install Paqet"
    echo "  4. Configure Paqet (interactive wizard)"
    echo ""
    
    read -p "Press Enter to continue or Ctrl+C to cancel..."
    
    # Download scripts
    echo ""
    echo "Downloading installer scripts..."
    echo ""
    
    download_script "paqet-prerequisites.sh"
    download_script "paqet-installer.sh"
    download_script "paqet-manager.sh"
    
    echo ""
    echo -e "${C_BOLD}Starting installation...${C_NC}"
    echo ""
    
    # Run prerequisites
    bash /tmp/paqet-prerequisites.sh
    
    # Run installer
    bash /tmp/paqet-installer.sh --full-install
    
    # Install scripts permanently
    echo ""
    echo "Installing management scripts..."
    cp /tmp/paqet-*.sh /usr/local/bin/
    
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