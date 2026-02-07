#!/bin/bash
#===============================================================================
# Paqet AutoDevOps - Intelligent Installer
# Version: 1.0.0 | Author: oxychain-net | License: MIT
#
# Features:
#   ✓ Interactive menu-driven configuration
#   ✓ Automatic network detection (interface, IP, MAC)
#   ✓ Secret key generation
#   ✓ Role-based configuration (Client/Server)
#   ✓ Firewall auto-configuration
#   ✓ Service management (systemd)
#   ✓ Configuration validation
#   ✓ Backup and rollback support
#
# Usage:
#   sudo ./paqet-installer.sh [--full-install|--client|--server]
#
#===============================================================================

set -euo pipefail
IFS=$'\n\t'

#===============================================================================
# CONSTANTS
#===============================================================================

readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME="Paqet Installer"
readonly LOG_DIR="/var/log/paqet-autodevops"
readonly LOG_FILE="${LOG_DIR}/installer.log"
readonly STATE_DIR="/var/lib/paqet-autodevops"
readonly STATE_FILE="${STATE_DIR}/installer.state"
readonly CONFIG_DIR="/etc/paqet"
readonly INSTALL_DIR="/opt/paqet"
readonly BIN_DIR="/usr/local/bin"
readonly SYSTEMD_DIR="/etc/systemd/system"
readonly BACKUP_DIR="${STATE_DIR}/backups"

# GitHub
readonly GITHUB_REPO="https://github.com/oxychain-net/paqet"
readonly GITHUB_API="https://api.github.com/repos/oxychain-net/paqet/releases/latest"

# Colors
readonly C_RED='\033[0;31m'
readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[1;33m'
readonly C_BLUE='\033[0;34m'
readonly C_CYAN='\033[0;36m'
readonly C_MAGENTA='\033[0;35m'
readonly C_BOLD='\033[1m'
readonly C_NC='\033[0m'

# Global state
declare -g ROLE=""
declare -g INTERFACE=""
declare -g INTERFACE_GUID=""
declare -g IPV4_ADDR=""
declare -g IPV4_PORT=""
declare -g IPV6_ADDR=""
declare -g IPV6_PORT=""
declare -g ROUTER_MAC_IPV4=""
declare -g ROUTER_MAC_IPV6=""
declare -g SERVER_ADDR=""
declare -g SECRET_KEY=""
declare -g SOCKS5_PORT="1080"
declare -g LISTEN_PORT="9999"
declare -g DISTRO=""
declare -g PKG_MANAGER=""

#===============================================================================
# UTILITIES
#===============================================================================

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" | tee -a "${LOG_FILE}" >&2
}

print_header() {
    clear
    echo ""
    echo -e "${C_CYAN}════════════════════════════════════════════════════${C_NC}"
    echo -e "${C_BOLD}${C_GREEN}$*${C_NC}"
    echo -e "${C_CYAN}════════════════════════════════════════════════════${C_NC}"
    echo ""
}

print_step() {
    echo -e "${C_YELLOW}▶ $*${C_NC}"
    log "Step: $*"
}

print_success() {
    echo -e "${C_GREEN}✓ $*${C_NC}"
    log "Success: $*"
}

print_error() {
    echo -e "${C_RED}✗ $*${C_NC}"
    log_error "$*"
}

print_info() {
    echo -e "${C_BLUE}ℹ $*${C_NC}"
}

prompt_input() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    local value
    
    if [[ -n "${default}" ]]; then
        read -p "$(echo -e "${C_CYAN}${prompt} [${default}]: ${C_NC}")" value
        value="${value:-${default}}"
    else
        read -p "$(echo -e "${C_CYAN}${prompt}: ${C_NC}")" value
    fi
    
    eval "${var_name}='${value}'"
}

confirm_action() {
    local prompt="$1"
    local default="${2:-n}"
    local reply
    
    if [[ "${default}" == "y" ]]; then
        read -p "$(echo -e "${C_YELLOW}${prompt} [Y/n]: ${C_NC}")" reply
        reply="${reply:-y}"
    else
        read -p "$(echo -e "${C_YELLOW}${prompt} [y/N]: ${C_NC}")" reply
        reply="${reply:-n}"
    fi
    
    [[ "${reply,,}" =~ ^y(es)?$ ]]
}

check_root() {
    if [[ ${EUID} -ne 0 ]]; then
        print_error "This script must be run as root"
        exit 1
    fi
}

detect_distro() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        DISTRO="${ID}"
        case "${DISTRO}" in
            ubuntu|debian)
                PKG_MANAGER="apt"
                ;;
            centos|rhel|rocky|alma|almalinux|fedora)
                PKG_MANAGER="yum"
                ;;
            *)
                print_error "Unsupported distribution: ${DISTRO}"
                exit 1
                ;;
        esac
    else
        print_error "Cannot detect Linux distribution"
        exit 1
    fi
}

init_directories() {
    mkdir -p "${LOG_DIR}" "${STATE_DIR}" "${CONFIG_DIR}" "${INSTALL_DIR}" "${BACKUP_DIR}"
    chmod 700 "${STATE_DIR}" "${CONFIG_DIR}" "${BACKUP_DIR}"
    touch "${LOG_FILE}" "${STATE_FILE}"
}

#===============================================================================
# NETWORK DETECTION
#===============================================================================

detect_network_interfaces() {
    print_step "Detecting network interfaces..."
    
    local interfaces
    interfaces=$(ip -o link show | awk -F': ' '$2 !~ /^lo$/ {print $2}')
    
    if [[ -z "${interfaces}" ]]; then
        print_error "No network interfaces found"
        return 1
    fi
    
    echo ""
    echo "Available interfaces:"
    local i=1
    while IFS= read -r iface; do
        local ip4
        ip4=$(ip -4 addr show "${iface}" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
        local mac
        mac=$(cat "/sys/class/net/${iface}/address" 2>/dev/null)
        
        echo -e "${C_CYAN}$i)${C_NC} ${iface}"
        echo "   MAC: ${mac}"
        [[ -n "${ip4}" ]] && echo "   IPv4: ${ip4}"
        ((i++))
    done <<< "${interfaces}"
    
    echo ""
}

select_network_interface() {
    detect_network_interfaces
    
    local iface_list
    iface_list=$(ip -o link show | awk -F': ' '$2 !~ /^lo$/ {print $2}')
    local count
    count=$(echo "${iface_list}" | wc -l)
    
    local selection
    while true; do
        read -p "$(echo -e "${C_CYAN}Select interface (1-${count}): ${C_NC}")" selection
        
        if [[ "${selection}" =~ ^[0-9]+$ ]] && [[ ${selection} -ge 1 ]] && [[ ${selection} -le ${count} ]]; then
            INTERFACE=$(echo "${iface_list}" | sed -n "${selection}p")
            break
        else
            print_error "Invalid selection. Please enter a number between 1 and ${count}."
        fi
    done
    
    # Detect Windows GUID if needed
    if [[ "$(uname -s)" == *"MINGW"* ]] || [[ "$(uname -s)" == *"CYGWIN"* ]]; then
        print_step "Detecting Npcap GUID for Windows..."
        # This would need PowerShell integration
        prompt_input "Enter Npcap GUID (e.g., \\Device\\NPF_{...})" "" "INTERFACE_GUID"
    fi
    
    print_success "Selected interface: ${INTERFACE}"
}

detect_ip_and_mac() {
    print_step "Detecting IP addresses and gateway MAC..."
    
    # IPv4
    IPV4_ADDR=$(ip -4 addr show "${INTERFACE}" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
    
    if [[ -n "${IPV4_ADDR}" ]]; then
        print_success "IPv4: ${IPV4_ADDR}"
        
        # Detect gateway
        local gateway4
        gateway4=$(ip route | grep default | grep "${INTERFACE}" | awk '{print $3}' | head -n1)
        
        if [[ -n "${gateway4}" ]]; then
            # Get MAC address of gateway
            ping -c 1 "${gateway4}" >/dev/null 2>&1 || true
            ROUTER_MAC_IPV4=$(arp -n "${gateway4}" 2>/dev/null | awk '/ether/{print $3}' | head -n1)
            
            if [[ -n "${ROUTER_MAC_IPV4}" ]]; then
                print_success "Gateway IPv4: ${gateway4} (MAC: ${ROUTER_MAC_IPV4})"
            else
                print_error "Could not detect gateway MAC address"
                prompt_input "Enter gateway MAC address (format: aa:bb:cc:dd:ee:ff)" "" "ROUTER_MAC_IPV4"
            fi
        fi
    else
        print_info "No IPv4 address configured on ${INTERFACE}"
    fi
    
    # IPv6
    IPV6_ADDR=$(ip -6 addr show "${INTERFACE}" 2>/dev/null | grep -oP '(?<=inet6\s)[0-9a-f:]+' | grep -v '^fe80' | head -n1)
    
    if [[ -n "${IPV6_ADDR}" ]]; then
        print_success "IPv6: ${IPV6_ADDR}"
        
        # For IPv6, gateway MAC detection is more complex
        prompt_input "Enter IPv6 gateway MAC address (or press Enter to skip)" "" "ROUTER_MAC_IPV6"
    fi
}

#===============================================================================
# CONFIGURATION WIZARD
#===============================================================================

wizard_role_selection() {
    print_header "Paqet Role Selection"
    
    echo "Select the role for this instance:"
    echo ""
    echo -e "${C_CYAN}1)${C_NC} Client (SOCKS5 Proxy - connects to server)"
    echo -e "${C_CYAN}2)${C_NC} Server (Receives connections from clients)"
    echo ""
    
    local selection
    while true; do
        read -p "$(echo -e "${C_CYAN}Select role (1-2): ${C_NC}")" selection
        
        case "${selection}" in
            1)
                ROLE="client"
                print_success "Role: Client"
                break
                ;;
            2)
                ROLE="server"
                print_success "Role: Server"
                break
                ;;
            *)
                print_error "Invalid selection"
                ;;
        esac
    done
}

wizard_network_configuration() {
    print_header "Network Configuration"
    
    select_network_interface
    detect_ip_and_mac
    
    # Port configuration
    if [[ "${ROLE}" == "client" ]]; then
        IPV4_PORT="0"  # Random port for client
        IPV6_PORT="0"
        
        prompt_input "SOCKS5 Listen Port" "1080" "SOCKS5_PORT"
        prompt_input "Server Address (IP:Port)" "" "SERVER_ADDR"
        
        # Validate server address
        if [[ ! "${SERVER_ADDR}" =~ ^[0-9a-fA-F.:]+:[0-9]+$ ]]; then
            print_error "Invalid server address format. Expected IP:Port"
            wizard_network_configuration
            return
        fi
    else
        prompt_input "Listen Port" "9999" "LISTEN_PORT"
        IPV4_PORT="${LISTEN_PORT}"
        IPV6_PORT="${LISTEN_PORT}"
    fi
    
    echo ""
    print_success "Network configuration completed"
    sleep 1
}

wizard_security_configuration() {
    print_header "Security Configuration"
    
    echo "Generating cryptographic secret key..."
    SECRET_KEY=$(head -c 32 /dev/urandom | xxd -p -c 32)
    
    print_success "Secret key generated: ${SECRET_KEY:0:16}... (truncated for display)"
    
    if confirm_action "Would you like to use a custom secret key?"; then
        prompt_input "Enter secret key (hex format, 64 characters)" "${SECRET_KEY}" "SECRET_KEY"
        
        if [[ ${#SECRET_KEY} -ne 64 ]]; then
            print_error "Invalid key length. Using auto-generated key."
            SECRET_KEY=$(head -c 32 /dev/urandom | xxd -p -c 32)
        fi
    fi
    
    echo ""
    print_step "IMPORTANT: Save this secret key securely!"
    echo -e "${C_YELLOW}Secret Key: ${SECRET_KEY}${C_NC}"
    echo ""
    
    if [[ "${ROLE}" == "server" ]]; then
        echo "You must use this SAME key on all client configurations."
    else
        echo "This key must match the server's secret key."
    fi
    
    read -p "Press Enter to continue..."
}

wizard_configuration_review() {
    print_header "Configuration Review"
    
    echo -e "${C_BOLD}Role:${C_NC} ${ROLE}"
    echo -e "${C_BOLD}Interface:${C_NC} ${INTERFACE}"
    
    if [[ -n "${INTERFACE_GUID}" ]]; then
        echo -e "${C_BOLD}GUID:${C_NC} ${INTERFACE_GUID}"
    fi
    
    if [[ -n "${IPV4_ADDR}" ]]; then
        echo -e "${C_BOLD}IPv4:${C_NC} ${IPV4_ADDR}:${IPV4_PORT}"
        echo -e "${C_BOLD}Gateway MAC (IPv4):${C_NC} ${ROUTER_MAC_IPV4}"
    fi
    
    if [[ -n "${IPV6_ADDR}" ]]; then
        echo -e "${C_BOLD}IPv6:${C_NC} [${IPV6_ADDR}]:${IPV6_PORT}"
        if [[ -n "${ROUTER_MAC_IPV6}" ]]; then
            echo -e "${C_BOLD}Gateway MAC (IPv6):${C_NC} ${ROUTER_MAC_IPV6}"
        fi
    fi
    
    if [[ "${ROLE}" == "client" ]]; then
        echo -e "${C_BOLD}SOCKS5 Port:${C_NC} ${SOCKS5_PORT}"
        echo -e "${C_BOLD}Server:${C_NC} ${SERVER_ADDR}"
    else
        echo -e "${C_BOLD}Listen Port:${C_NC} ${LISTEN_PORT}"
    fi
    
    echo -e "${C_BOLD}Secret Key:${C_NC} ${SECRET_KEY:0:16}... (truncated)"
    echo ""
    
    if ! confirm_action "Is this configuration correct?" "y"; then
        wizard_main_menu
        return 1
    fi
    
    return 0
}

#===============================================================================
# INSTALLATION
#===============================================================================

download_paqet() {
    print_step "Downloading Paqet..."
    
    # Check if binary already exists
    if [[ -f "${BIN_DIR}/paqet" ]]; then
        if confirm_action "Paqet binary already exists. Re-download?"; then
            rm -f "${BIN_DIR}/paqet"
        else
            print_success "Using existing Paqet binary"
            return 0
        fi
    fi
    
    # Try to download pre-compiled binary
    local arch
    arch="$(uname -m)"
    case "${arch}" in
        x86_64) arch="amd64" ;;
        aarch64) arch="arm64" ;;
        *) 
            print_error "Unsupported architecture: ${arch}"
            print_step "Will compile from source instead"
            compile_paqet
            return $?
            ;;
    esac
    
    local os
    os="$(uname -s | tr '[:upper:]' '[:lower:]')"
    
    # Get latest release
    print_step "Fetching latest release info..."
    local release_url
    release_url=$(curl -fsSL "${GITHUB_API}" 2>/dev/null | grep "browser_download_url.*${os}_${arch}" | cut -d '"' -f 4 | head -n1)
    
    if [[ -z "${release_url}" ]]; then
        print_error "No pre-compiled binary found for ${os}/${arch}"
        print_step "Compiling from source..."
        compile_paqet
        return $?
    fi
    
    curl -fsSL "${release_url}" -o "${BIN_DIR}/paqet"
    chmod +x "${BIN_DIR}/paqet"
    
    if "${BIN_DIR}/paqet" version >/dev/null 2>&1; then
        local version
        version=$("${BIN_DIR}/paqet" version | head -n1)
        print_success "Paqet downloaded: ${version}"
    else
        print_error "Downloaded binary is not functional"
        return 1
    fi
}

compile_paqet() {
    print_step "Compiling Paqet from source..."
    
    # Check Go installation
    if ! command -v go &>/dev/null; then
        print_error "Go is not installed. Run prerequisites installer first."
        return 1
    fi
    
    local build_dir="${INSTALL_DIR}/build"
    mkdir -p "${build_dir}"
    cd "${build_dir}"
    
    # Clone repository
    if [[ -d "paqet" ]]; then
        cd paqet
        git pull
    else
        git clone "${GITHUB_REPO}" paqet
        cd paqet
    fi
    
    # Build
    print_step "Building Paqet (this may take a few minutes)..."
    go build -o paqet ./cmd/main.go
    
    if [[ ! -f "paqet" ]]; then
        print_error "Compilation failed"
        return 1
    fi
    
    # Install binary
    cp paqet "${BIN_DIR}/paqet"
    chmod +x "${BIN_DIR}/paqet"
    
    local version
    version=$("${BIN_DIR}/paqet" version | head -n1)
    print_success "Paqet compiled and installed: ${version}"
    
    cd - >/dev/null
}

generate_config_file() {
    print_step "Generating configuration file..."
    
    local config_file
    if [[ "${ROLE}" == "client" ]]; then
        config_file="${CONFIG_DIR}/client.yaml"
    else
        config_file="${CONFIG_DIR}/server.yaml"
    fi
    
    # Backup existing config
    if [[ -f "${config_file}" ]]; then
        cp "${config_file}" "${BACKUP_DIR}/$(basename "${config_file}").$(date +%s).bak"
    fi
    
    if [[ "${ROLE}" == "client" ]]; then
        cat > "${config_file}" <<EOF
# Paqet Client Configuration
# Auto-generated by Paqet AutoDevOps
# Generated: $(date)

role: "client"

log:
  level: "info"

socks5:
  - listen: "127.0.0.1:${SOCKS5_PORT}"

network:
  interface: "${INTERFACE}"
EOF

        if [[ -n "${INTERFACE_GUID}" ]]; then
            echo "  guid: \"${INTERFACE_GUID}\"" >> "${config_file}"
        fi
        
        if [[ -n "${IPV4_ADDR}" ]]; then
            cat >> "${config_file}" <<EOF
  ipv4:
    addr: "${IPV4_ADDR}:${IPV4_PORT}"
    router_mac: "${ROUTER_MAC_IPV4}"
EOF
        fi
        
        if [[ -n "${IPV6_ADDR}" && -n "${ROUTER_MAC_IPV6}" ]]; then
            cat >> "${config_file}" <<EOF
  ipv6:
    addr: "[${IPV6_ADDR}]:${IPV6_PORT}"
    router_mac: "${ROUTER_MAC_IPV6}"
EOF
        fi
        
        cat >> "${config_file}" <<EOF
  tcp:
    local_flag: ["PA"]
    remote_flag: ["PA"]

server:
  addr: "${SERVER_ADDR}"

transport:
  protocol: "kcp"
  conn: 1
  kcp:
    mode: "fast"
    key: "${SECRET_KEY}"
EOF
    else
        # Server configuration
        cat > "${config_file}" <<EOF
# Paqet Server Configuration
# Auto-generated by Paqet AutoDevOps
# Generated: $(date)

role: "server"

log:
  level: "info"

listen:
  addr: ":${LISTEN_PORT}"

network:
  interface: "${INTERFACE}"
EOF

        if [[ -n "${INTERFACE_GUID}" ]]; then
            echo "  guid: \"${INTERFACE_GUID}\"" >> "${config_file}"
        fi
        
        if [[ -n "${IPV4_ADDR}" ]]; then
            cat >> "${config_file}" <<EOF
  ipv4:
    addr: "${IPV4_ADDR}:${IPV4_PORT}"
    router_mac: "${ROUTER_MAC_IPV4}"
EOF
        fi
        
        if [[ -n "${IPV6_ADDR}" && -n "${ROUTER_MAC_IPV6}" ]]; then
            cat >> "${config_file}" <<EOF
  ipv6:
    addr: "[${IPV6_ADDR}]:${IPV6_PORT}"
    router_mac: "${ROUTER_MAC_IPV6}"
EOF
        fi
        
        cat >> "${config_file}" <<EOF
  tcp:
    local_flag: ["PA"]

transport:
  protocol: "kcp"
  conn: 1
  kcp:
    mode: "fast"
    key: "${SECRET_KEY}"
EOF
    fi
    
    chmod 600 "${config_file}"
    print_success "Configuration file created: ${config_file}"
}

configure_firewall_server() {
    if [[ "${ROLE}" != "server" ]]; then
        return 0
    fi
    
    print_header "Firewall Configuration (Server)"
    
    echo "Configuring iptables rules for Paqet server..."
    echo ""
    print_step "CRITICAL: These rules prevent kernel interference with raw packets"
    echo ""
    
    local port="${LISTEN_PORT}"
    
    # Apply iptables rules
    iptables -t raw -C PREROUTING -p tcp --dport "${port}" -j NOTRACK 2>/dev/null || \
        iptables -t raw -A PREROUTING -p tcp --dport "${port}" -j NOTRACK
    
    iptables -t raw -C OUTPUT -p tcp --sport "${port}" -j NOTRACK 2>/dev/null || \
        iptables -t raw -A OUTPUT -p tcp --sport "${port}" -j NOTRACK
    
    iptables -t mangle -C OUTPUT -p tcp --sport "${port}" --tcp-flags RST RST -j DROP 2>/dev/null || \
        iptables -t mangle -A OUTPUT -p tcp --sport "${port}" --tcp-flags RST RST -j DROP
    
    print_success "iptables rules applied for port ${port}"
    
    # Make persistent
    case "${PKG_MANAGER}" in
        apt)
            if command -v iptables-save &>/dev/null; then
                iptables-save > /etc/iptables/rules.v4
                print_success "iptables rules saved (persistent)"
            fi
            ;;
        yum)
            if command -v iptables-save &>/dev/null; then
                service iptables save
                print_success "iptables rules saved (persistent)"
            fi
            ;;
    esac
}

create_systemd_service() {
    print_step "Creating systemd service..."
    
    local service_name
    if [[ "${ROLE}" == "client" ]]; then
        service_name="paqet-client"
    else
        service_name="paqet-server"
    fi
    
    local service_file="${SYSTEMD_DIR}/${service_name}.service"
    local config_file="${CONFIG_DIR}/${ROLE}.yaml"
    
    cat > "${service_file}" <<EOF
[Unit]
Description=Paqet ${ROLE^} Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=${INSTALL_DIR}
ExecStart=${BIN_DIR}/paqet run -c ${config_file}
Restart=always
RestartSec=5
LimitNOFILE=1000000
LimitNPROC=1000000

# Security
NoNewPrivileges=false
PrivateTmp=true
ProtectSystem=full
ProtectHome=true

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    print_success "Systemd service created: ${service_name}"
    
    if confirm_action "Enable ${service_name} to start on boot?" "y"; then
        systemctl enable "${service_name}"
        print_success "Service enabled"
    fi
    
    if confirm_action "Start ${service_name} now?" "y"; then
        systemctl start "${service_name}"
        sleep 2
        
        if systemctl is-active --quiet "${service_name}"; then
            print_success "Service started successfully"
        else
            print_error "Service failed to start. Check logs: journalctl -u ${service_name} -f"
        fi
    fi
}

#===============================================================================
# WIZARD MAIN MENU
#===============================================================================

wizard_main_menu() {
    while true; do
        print_header "Paqet Installation Wizard"
        
        echo -e "${C_BOLD}Current Configuration:${C_NC}"
        echo -e "  Role: ${ROLE:-Not set}"
        echo -e "  Interface: ${INTERFACE:-Not set}"
        echo -e "  IPv4: ${IPV4_ADDR:-Not set}"
        
        if [[ "${ROLE}" == "client" ]]; then
            echo -e "  Server: ${SERVER_ADDR:-Not set}"
        fi
        
        echo ""
        echo "Menu:"
        echo -e "${C_CYAN}1)${C_NC} Configure Role (Client/Server)"
        echo -e "${C_CYAN}2)${C_NC} Configure Network"
        echo -e "${C_CYAN}3)${C_NC} Configure Security (Secret Key)"
        echo -e "${C_CYAN}4)${C_NC} Review Configuration"
        echo -e "${C_CYAN}5)${C_NC} Install Paqet"
        echo -e "${C_CYAN}6)${C_NC} Exit"
        echo ""
        
        local choice
        read -p "$(echo -e "${C_CYAN}Select option (1-6): ${C_NC}")" choice
        
        case "${choice}" in
            1) wizard_role_selection ;;
            2) 
                if [[ -z "${ROLE}" ]]; then
                    print_error "Please select a role first (option 1)"
                else
                    wizard_network_configuration
                fi
                ;;
            3) wizard_security_configuration ;;
            4) wizard_configuration_review ;;
            5)
                if wizard_configuration_review; then
                    perform_installation
                    return 0
                fi
                ;;
            6)
                print_step "Exiting..."
                exit 0
                ;;
            *)
                print_error "Invalid option"
                ;;
        esac
    done
}

perform_installation() {
    print_header "Installing Paqet"
    
    download_paqet || return 1
    generate_config_file
    
    if [[ "${ROLE}" == "server" ]]; then
        configure_firewall_server
    fi
    
    create_systemd_service
    
    print_header "Installation Complete!"
    
    echo ""
    print_success "Paqet ${ROLE} installed successfully"
    echo ""
    echo "Next steps:"
    
    if [[ "${ROLE}" == "client" ]]; then
        echo "  1. Verify service: systemctl status paqet-client"
        echo "  2. Test SOCKS5 proxy: curl -x socks5h://127.0.0.1:${SOCKS5_PORT} https://ifconfig.me"
        echo "  3. View logs: journalctl -u paqet-client -f"
    else
        echo "  1. Verify service: systemctl status paqet-server"
        echo "  2. Check iptables: iptables -t raw -L -n -v"
        echo "  3. View logs: journalctl -u paqet-server -f"
        echo ""
        echo -e "${C_YELLOW}IMPORTANT:${C_NC} Share this secret key with clients:"
        echo -e "${C_GREEN}${SECRET_KEY}${C_NC}"
    fi
    
    echo ""
    echo "Configuration file: ${CONFIG_DIR}/${ROLE}.yaml"
    echo "Binary location: ${BIN_DIR}/paqet"
    echo ""
    
    read -p "Press Enter to exit..."
}

#===============================================================================
# MAIN
#===============================================================================

main() {
    check_root
    detect_distro
    init_directories
    
    # Parse arguments
    if [[ $# -gt 0 ]]; then
        case "$1" in
            --full-install)
                # Run prerequisites first
                if [[ -f "./paqet-prerequisites.sh" ]]; then
                    print_step "Running prerequisites installer..."
                    bash ./paqet-prerequisites.sh
                fi
                wizard_main_menu
                ;;
            --client)
                ROLE="client"
                wizard_main_menu
                ;;
            --server)
                ROLE="server"
                wizard_main_menu
                ;;
            *)
                echo "Usage: $0 [--full-install|--client|--server]"
                exit 1
                ;;
        esac
    else
        wizard_main_menu
    fi
}

main "$@"