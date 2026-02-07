#!/bin/bash
#===============================================================================
# Paqet AutoDevOps - Service Manager & Monitor
# Version: 1.0.0 | Author: oxychain-net | License: MIT
#
# Features:
#   ✓ Service management (start/stop/restart/status)
#   ✓ Configuration editor with validation
#   ✓ Real-time log viewer
#   ✓ Health monitoring
#   ✓ Performance metrics
#   ✓ Backup & restore
#   ✓ Secret key rotation
#   ✓ Firewall rule management
#   ✓ Auto-healing watchdog
#
# Usage:
#   sudo ./paqet-manager.sh
#
#===============================================================================

set -euo pipefail
IFS=$'\n\t'

#===============================================================================
# CONSTANTS
#===============================================================================

readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME="Paqet Manager"
readonly LOG_DIR="/var/log/paqet-autodevops"
readonly LOG_FILE="${LOG_DIR}/manager.log"
readonly STATE_DIR="/var/lib/paqet-autodevops"
readonly CONFIG_DIR="/etc/paqet"
readonly BIN_DIR="/usr/local/bin"
readonly BACKUP_DIR="${STATE_DIR}/backups"
readonly WATCHDOG_SCRIPT="/usr/local/bin/paqet-watchdog"
readonly WATCHDOG_LOG="/var/log/paqet-watchdog.log"

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
declare -g SERVICE_NAME=""
declare -g CONFIG_FILE=""
declare -g ROLE=""

#===============================================================================
# UTILITIES
#===============================================================================

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"
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
}

print_error() {
    echo -e "${C_RED}✗ $*${C_NC}"
}

print_info() {
    echo -e "${C_BLUE}ℹ $*${C_NC}"
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

detect_service() {
    if systemctl list-units --type=service --all | grep -q paqet-client; then
        SERVICE_NAME="paqet-client"
        ROLE="client"
        CONFIG_FILE="${CONFIG_DIR}/client.yaml"
    elif systemctl list-units --type=service --all | grep -q paqet-server; then
        SERVICE_NAME="paqet-server"
        ROLE="server"
        CONFIG_FILE="${CONFIG_DIR}/server.yaml"
    else
        print_error "No Paqet service found"
        print_info "Please run paqet-installer.sh first"
        exit 1
    fi
}

#===============================================================================
# SERVICE MANAGEMENT
#===============================================================================

service_status() {
    print_header "Service Status"
    
    echo -e "${C_BOLD}Service:${C_NC} ${SERVICE_NAME}"
    echo -e "${C_BOLD}Role:${C_NC} ${ROLE}"
    echo -e "${C_BOLD}Config:${C_NC} ${CONFIG_FILE}"
    echo ""
    
    systemctl status "${SERVICE_NAME}" --no-pager -l
    echo ""
}

service_start() {
    print_step "Starting ${SERVICE_NAME}..."
    
    if systemctl is-active --quiet "${SERVICE_NAME}"; then
        print_error "Service is already running"
        return 1
    fi
    
    systemctl start "${SERVICE_NAME}"
    sleep 2
    
    if systemctl is-active --quiet "${SERVICE_NAME}"; then
        print_success "Service started successfully"
    else
        print_error "Service failed to start"
        print_step "Showing recent logs:"
        journalctl -u "${SERVICE_NAME}" -n 20 --no-pager
    fi
}

service_stop() {
    print_step "Stopping ${SERVICE_NAME}..."
    
    if ! systemctl is-active --quiet "${SERVICE_NAME}"; then
        print_error "Service is not running"
        return 1
    fi
    
    systemctl stop "${SERVICE_NAME}"
    sleep 1
    
    if ! systemctl is-active --quiet "${SERVICE_NAME}"; then
        print_success "Service stopped successfully"
    else
        print_error "Service failed to stop"
    fi
}

service_restart() {
    print_step "Restarting ${SERVICE_NAME}..."
    
    systemctl restart "${SERVICE_NAME}"
    sleep 2
    
    if systemctl is-active --quiet "${SERVICE_NAME}"; then
        print_success "Service restarted successfully"
    else
        print_error "Service failed to restart"
        print_step "Showing recent logs:"
        journalctl -u "${SERVICE_NAME}" -n 20 --no-pager
    fi
}

service_enable() {
    print_step "Enabling ${SERVICE_NAME} to start on boot..."
    
    systemctl enable "${SERVICE_NAME}"
    print_success "Service enabled"
}

service_disable() {
    print_step "Disabling ${SERVICE_NAME} from starting on boot..."
    
    systemctl disable "${SERVICE_NAME}"
    print_success "Service disabled"
}

#===============================================================================
# LOG MANAGEMENT
#===============================================================================

view_logs_live() {
    print_header "Live Logs (Ctrl+C to exit)"
    echo ""
    journalctl -u "${SERVICE_NAME}" -f
}

view_logs_recent() {
    print_header "Recent Logs (Last 50 Lines)"
    echo ""
    journalctl -u "${SERVICE_NAME}" -n 50 --no-pager
    echo ""
    read -p "Press Enter to continue..."
}

view_logs_errors() {
    print_header "Error Logs"
    echo ""
    journalctl -u "${SERVICE_NAME}" -p err --no-pager
    echo ""
    read -p "Press Enter to continue..."
}

export_logs() {
    print_header "Export Logs"
    
    local export_file="${BACKUP_DIR}/logs_${SERVICE_NAME}_$(date +%Y%m%d_%H%M%S).log"
    
    print_step "Exporting logs to ${export_file}..."
    journalctl -u "${SERVICE_NAME}" --no-pager > "${export_file}"
    
    print_success "Logs exported successfully"
    echo "File: ${export_file}"
    echo "Size: $(du -h "${export_file}" | awk '{print $1}')"
    echo ""
    read -p "Press Enter to continue..."
}

#===============================================================================
# CONFIGURATION MANAGEMENT
#===============================================================================

view_config() {
    print_header "Current Configuration"
    
    if [[ ! -f "${CONFIG_FILE}" ]]; then
        print_error "Configuration file not found: ${CONFIG_FILE}"
        read -p "Press Enter to continue..."
        return 1
    fi
    
    cat "${CONFIG_FILE}"
    echo ""
    read -p "Press Enter to continue..."
}

edit_config() {
    print_header "Edit Configuration"
    
    if [[ ! -f "${CONFIG_FILE}" ]]; then
        print_error "Configuration file not found: ${CONFIG_FILE}"
        read -p "Press Enter to continue..."
        return 1
    fi
    
    # Backup current config
    local backup_file="${BACKUP_DIR}/$(basename "${CONFIG_FILE}").$(date +%s).bak"
    cp "${CONFIG_FILE}" "${backup_file}"
    print_success "Backup created: ${backup_file}"
    
    # Detect editor
    local editor="${EDITOR:-nano}"
    if ! command -v "${editor}" &>/dev/null; then
        editor="vi"
    fi
    
    # Edit
    ${editor} "${CONFIG_FILE}"
    
    # Validate
    print_step "Validating configuration..."
    if "${BIN_DIR}/paqet" run -c "${CONFIG_FILE}" --help &>/dev/null; then
        print_success "Configuration is valid"
        
        if systemctl is-active --quiet "${SERVICE_NAME}"; then
            if confirm_action "Restart service to apply changes?"; then
                service_restart
            fi
        fi
    else
        print_error "Configuration validation failed"
        
        if confirm_action "Restore backup?"; then
            cp "${backup_file}" "${CONFIG_FILE}"
            print_success "Backup restored"
        fi
    fi
    
    read -p "Press Enter to continue..."
}

rotate_secret_key() {
    print_header "Rotate Secret Key"
    
    echo -e "${C_YELLOW}WARNING: Rotating the secret key will break existing connections!${C_NC}"
    echo ""
    
    if [[ "${ROLE}" == "server" ]]; then
        echo "After rotation, you MUST update all client configurations."
    else
        echo "The new key must match your server's secret key."
    fi
    
    echo ""
    
    if ! confirm_action "Continue with key rotation?"; then
        return 0
    fi
    
    # Generate new key
    local new_key
    new_key=$(head -c 32 /dev/urandom | xxd -p -c 32)
    
    echo ""
    echo -e "${C_BOLD}New Secret Key:${C_NC}"
    echo -e "${C_GREEN}${new_key}${C_NC}"
    echo ""
    
    if ! confirm_action "Apply this key to configuration?"; then
        return 0
    fi
    
    # Backup
    local backup_file="${BACKUP_DIR}/$(basename "${CONFIG_FILE}").$(date +%s).bak"
    cp "${CONFIG_FILE}" "${backup_file}"
    
    # Update config
    if grep -q "key:" "${CONFIG_FILE}"; then
        sed -i "s/key: \".*\"/key: \"${new_key}\"/" "${CONFIG_FILE}"
        print_success "Secret key rotated in configuration"
        
        if systemctl is-active --quiet "${SERVICE_NAME}"; then
            service_restart
        fi
    else
        print_error "Could not find 'key:' field in configuration"
        print_step "Please update manually"
    fi
    
    echo ""
    print_step "SAVE THIS KEY SECURELY!"
    echo -e "${C_GREEN}${new_key}${C_NC}"
    echo ""
    read -p "Press Enter to continue..."
}

#===============================================================================
# MONITORING & HEALTH
#===============================================================================

show_health_dashboard() {
    print_header "Health Dashboard"
    
    # Service status
    if systemctl is-active --quiet "${SERVICE_NAME}"; then
        echo -e "${C_BOLD}Service Status:${C_NC} ${C_GREEN}Running${C_NC}"
    else
        echo -e "${C_BOLD}Service Status:${C_NC} ${C_RED}Stopped${C_NC}"
    fi
    
    # Uptime
    if systemctl is-active --quiet "${SERVICE_NAME}"; then
        local uptime
        uptime=$(systemctl show "${SERVICE_NAME}" --property=ActiveEnterTimestamp | cut -d= -f2)
        echo -e "${C_BOLD}Started:${C_NC} ${uptime}"
    fi
    
    # CPU & Memory
    echo ""
    echo -e "${C_BOLD}Resource Usage:${C_NC}"
    
    local pid
    pid=$(systemctl show "${SERVICE_NAME}" --property=MainPID | cut -d= -f2)
    
    if [[ "${pid}" != "0" ]]; then
        local cpu mem
        cpu=$(ps -p "${pid}" -o %cpu --no-headers 2>/dev/null || echo "N/A")
        mem=$(ps -p "${pid}" -o %mem --no-headers 2>/dev/null || echo "N/A")
        
        echo "  CPU: ${cpu}%"
        echo "  Memory: ${mem}%"
    else
        echo "  Process not found"
    fi
    
    # Network interface status
    echo ""
    echo -e "${C_BOLD}Network Configuration:${C_NC}"
    
    if [[ -f "${CONFIG_FILE}" ]]; then
        local interface
        interface=$(grep "interface:" "${CONFIG_FILE}" | awk '{print $2}' | tr -d '"')
        
        if [[ -n "${interface}" ]]; then
            echo "  Interface: ${interface}"
            
            if ip link show "${interface}" &>/dev/null; then
                local status
                status=$(ip link show "${interface}" | grep -oP '(?<=state )\w+')
                echo "  Status: ${status}"
                
                local ip4
                ip4=$(ip -4 addr show "${interface}" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
                [[ -n "${ip4}" ]] && echo "  IPv4: ${ip4}"
            else
                echo -e "  ${C_RED}Interface not found${C_NC}"
            fi
        fi
    fi
    
    # Recent errors
    echo ""
    echo -e "${C_BOLD}Recent Errors (Last 24h):${C_NC}"
    
    local error_count
    error_count=$(journalctl -u "${SERVICE_NAME}" -p err --since "24 hours ago" --no-pager | grep -c "ERROR" || echo "0")
    
    if [[ ${error_count} -eq 0 ]]; then
        echo -e "  ${C_GREEN}No errors${C_NC}"
    else
        echo -e "  ${C_RED}${error_count} errors found${C_NC}"
        echo "  View with: journalctl -u ${SERVICE_NAME} -p err"
    fi
    
    # Firewall status (server only)
    if [[ "${ROLE}" == "server" ]]; then
        echo ""
        echo -e "${C_BOLD}Firewall Rules:${C_NC}"
        
        local port
        port=$(grep "addr:" "${CONFIG_FILE}" | grep -oP ':\K\d+' | head -n1)
        
        if [[ -n "${port}" ]]; then
            local rule_count
            rule_count=$(iptables -t raw -L PREROUTING -n | grep -c "tcp dpt:${port}" || echo "0")
            
            if [[ ${rule_count} -gt 0 ]]; then
                echo -e "  Port ${port}: ${C_GREEN}Protected${C_NC}"
            else
                echo -e "  Port ${port}: ${C_RED}Not protected${C_NC}"
                echo "  Run: iptables -t raw -A PREROUTING -p tcp --dport ${port} -j NOTRACK"
            fi
        fi
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

show_connection_stats() {
    print_header "Connection Statistics"
    
    if [[ "${ROLE}" == "client" ]]; then
        echo -e "${C_BOLD}SOCKS5 Proxy Connections:${C_NC}"
        
        local socks_port
        socks_port=$(grep "listen:" "${CONFIG_FILE}" | grep -oP ':\K\d+' | head -n1)
        
        if [[ -n "${socks_port}" ]]; then
            local conn_count
            conn_count=$(ss -tn | grep -c ":${socks_port}" || echo "0")
            echo "  Active connections: ${conn_count}"
            
            if [[ ${conn_count} -gt 0 ]]; then
                echo ""
                echo "  Recent connections:"
                ss -tn | grep ":${socks_port}" | head -n 10
            fi
        fi
    else
        echo -e "${C_BOLD}Server Connections:${C_NC}"
        
        local listen_port
        listen_port=$(grep "addr:" "${CONFIG_FILE}" | grep -oP ':\K\d+' | head -n1)
        
        if [[ -n "${listen_port}" ]]; then
            local conn_count
            conn_count=$(ss -tn | grep -c ":${listen_port}" || echo "0")
            echo "  Active connections: ${conn_count}"
            
            if [[ ${conn_count} -gt 0 ]]; then
                echo ""
                echo "  Client IPs:"
                ss -tn | grep ":${listen_port}" | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -rn
            fi
        fi
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

test_connection() {
    print_header "Connection Test"
    
    if [[ "${ROLE}" == "client" ]]; then
        local socks_port
        socks_port=$(grep "listen:" "${CONFIG_FILE}" | grep -oP ':\K\d+' | head -n1)
        
        print_step "Testing SOCKS5 proxy on port ${socks_port}..."
        echo ""
        
        if command -v curl &>/dev/null; then
            echo "Public IP test:"
            curl -x "socks5h://127.0.0.1:${socks_port}" https://ifconfig.me 2>&1
            echo ""
            
            echo ""
            echo "CloudFlare trace test:"
            curl -x "socks5h://127.0.0.1:${socks_port}" https://www.cloudflare.com/cdn-cgi/trace 2>&1
        else
            print_error "curl not installed"
        fi
    else
        local listen_port
        listen_port=$(grep "addr:" "${CONFIG_FILE}" | grep -oP ':\K\d+' | head -n1)
        
        print_step "Checking server listener on port ${listen_port}..."
        echo ""
        
        if ss -tnl | grep -q ":${listen_port}"; then
            print_success "Server is listening on port ${listen_port}"
        else
            print_error "Server is NOT listening on port ${listen_port}"
        fi
        
        echo ""
        print_step "Checking iptables rules..."
        
        if iptables -t raw -L PREROUTING -n | grep -q "tcp dpt:${listen_port}"; then
            print_success "iptables NOTRACK rule active"
        else
            print_error "iptables NOTRACK rule missing"
        fi
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

#===============================================================================
# BACKUP & RESTORE
#===============================================================================

create_backup() {
    print_header "Create Backup"
    
    local backup_name="paqet_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    local backup_path="${BACKUP_DIR}/${backup_name}"
    
    print_step "Creating backup..."
    
    tar -czf "${backup_path}" \
        -C "${CONFIG_DIR}" . \
        2>/dev/null || true
    
    if [[ -f "${backup_path}" ]]; then
        print_success "Backup created successfully"
        echo "Location: ${backup_path}"
        echo "Size: $(du -h "${backup_path}" | awk '{print $1}')"
    else
        print_error "Backup creation failed"
    fi
    
    # Cleanup old backups (keep last 10)
    print_step "Cleaning up old backups..."
    ls -t "${BACKUP_DIR}"/paqet_backup_*.tar.gz 2>/dev/null | tail -n +11 | xargs -r rm
    
    echo ""
    read -p "Press Enter to continue..."
}

list_backups() {
    print_header "Available Backups"
    
    local backups
    backups=$(ls -t "${BACKUP_DIR}"/paqet_backup_*.tar.gz 2>/dev/null || true)
    
    if [[ -z "${backups}" ]]; then
        print_error "No backups found"
        read -p "Press Enter to continue..."
        return 0
    fi
    
    echo ""
    local i=1
    while IFS= read -r backup; do
        local size
        size=$(du -h "${backup}" | awk '{print $1}')
        local date
        date=$(basename "${backup}" | sed 's/paqet_backup_//; s/.tar.gz//')
        
        echo "${i}) ${date} (${size})"
        ((i++))
    done <<< "${backups}"
    
    echo ""
    read -p "Press Enter to continue..."
}

restore_backup() {
    print_header "Restore Backup"
    
    local backups
    backups=$(ls -t "${BACKUP_DIR}"/paqet_backup_*.tar.gz 2>/dev/null || true)
    
    if [[ -z "${backups}" ]]; then
        print_error "No backups found"
        read -p "Press Enter to continue..."
        return 0
    fi
    
    echo "Available backups:"
    echo ""
    
    local i=1
    while IFS= read -r backup; do
        local size
        size=$(du -h "${backup}" | awk '{print $1}')
        local date
        date=$(basename "${backup}" | sed 's/paqet_backup_//; s/.tar.gz//')
        
        echo "${i}) ${date} (${size})"
        ((i++))
    done <<< "${backups}"
    
    echo ""
    read -p "Select backup to restore (1-$((i-1))): " selection
    
    local selected_backup
    selected_backup=$(echo "${backups}" | sed -n "${selection}p")
    
    if [[ ! -f "${selected_backup}" ]]; then
        print_error "Invalid selection"
        read -p "Press Enter to continue..."
        return 1
    fi
    
    echo ""
    echo -e "${C_YELLOW}WARNING: This will overwrite current configuration!${C_NC}"
    echo ""
    
    if ! confirm_action "Continue with restore?"; then
        return 0
    fi
    
    # Stop service
    if systemctl is-active --quiet "${SERVICE_NAME}"; then
        print_step "Stopping service..."
        systemctl stop "${SERVICE_NAME}"
    fi
    
    # Restore
    print_step "Restoring backup..."
    tar -xzf "${selected_backup}" -C "${CONFIG_DIR}"
    
    print_success "Backup restored successfully"
    
    # Restart service
    if confirm_action "Restart service?"; then
        systemctl start "${SERVICE_NAME}"
    fi
    
    read -p "Press Enter to continue..."
}

#===============================================================================
# WATCHDOG
#===============================================================================

install_watchdog() {
    print_header "Install Auto-Healing Watchdog"
    
    print_step "Creating watchdog script..."
    
    cat > "${WATCHDOG_SCRIPT}" <<'WATCHDOG_EOF'
#!/bin/bash
set -euo pipefail

SERVICE_NAME="__SERVICE_NAME__"
LOG_FILE="__LOG_FILE__"
CONFIG_FILE="__CONFIG_FILE__"
MAX_RESTARTS=3
RESTART_WINDOW=300  # 5 minutes

STATE_FILE="/tmp/paqet-watchdog.state"
RESTART_COUNT=0
LAST_RESTART=0

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "${LOG_FILE}"
}

check_service() {
    systemctl is-active --quiet "${SERVICE_NAME}"
}

restart_service() {
    local now
    now=$(date +%s)
    
    # Reset counter if outside restart window
    if [[ $((now - LAST_RESTART)) -gt ${RESTART_WINDOW} ]]; then
        RESTART_COUNT=0
    fi
    
    # Check max restarts
    if [[ ${RESTART_COUNT} -ge ${MAX_RESTARTS} ]]; then
        log "ERROR: Max restarts (${MAX_RESTARTS}) reached within ${RESTART_WINDOW}s - manual intervention required"
        return 1
    fi
    
    log "Service down - initiating restart (attempt $((RESTART_COUNT + 1))/${MAX_RESTARTS})"
    
    systemctl restart "${SERVICE_NAME}"
    sleep 3
    
    if check_service; then
        log "Service restarted successfully"
        RESTART_COUNT=$((RESTART_COUNT + 1))
        LAST_RESTART=${now}
        echo "${RESTART_COUNT} ${LAST_RESTART}" > "${STATE_FILE}"
        return 0
    else
        log "ERROR: Service restart failed"
        return 1
    fi
}

# Load state
if [[ -f "${STATE_FILE}" ]]; then
    read RESTART_COUNT LAST_RESTART < "${STATE_FILE}"
fi

# Check service
if ! check_service; then
    restart_service
else
    log "Service OK"
fi
WATCHDOG_EOF
    
    # Replace placeholders
    sed -i "s|__SERVICE_NAME__|${SERVICE_NAME}|g" "${WATCHDOG_SCRIPT}"
    sed -i "s|__LOG_FILE__|${WATCHDOG_LOG}|g" "${WATCHDOG_SCRIPT}"
    sed -i "s|__CONFIG_FILE__|${CONFIG_FILE}|g" "${WATCHDOG_SCRIPT}"
    
    chmod +x "${WATCHDOG_SCRIPT}"
    
    # Add to crontab
    (crontab -l 2>/dev/null | grep -v "${WATCHDOG_SCRIPT}"; echo "*/2 * * * * ${WATCHDOG_SCRIPT}") | crontab -
    
    print_success "Watchdog installed (checks every 2 minutes)"
    echo ""
    echo "Watchdog script: ${WATCHDOG_SCRIPT}"
    echo "Watchdog log: ${WATCHDOG_LOG}"
    echo ""
    read -p "Press Enter to continue..."
}

remove_watchdog() {
    print_header "Remove Watchdog"
    
    if ! confirm_action "Remove auto-healing watchdog?"; then
        return 0
    fi
    
    # Remove from crontab
    crontab -l 2>/dev/null | grep -v "${WATCHDOG_SCRIPT}" | crontab -
    
    # Remove script
    rm -f "${WATCHDOG_SCRIPT}"
    
    print_success "Watchdog removed"
    read -p "Press Enter to continue..."
}

view_watchdog_log() {
    print_header "Watchdog Log"
    
    if [[ ! -f "${WATCHDOG_LOG}" ]]; then
        print_error "Watchdog log not found"
        read -p "Press Enter to continue..."
        return 0
    fi
    
    tail -n 50 "${WATCHDOG_LOG}"
    echo ""
    read -p "Press Enter to continue..."
}

#===============================================================================
# FIREWALL MANAGEMENT (SERVER)
#===============================================================================

configure_firewall_rules() {
    if [[ "${ROLE}" != "server" ]]; then
        print_error "Firewall configuration only available for server role"
        read -p "Press Enter to continue..."
        return 0
    fi
    
    print_header "Configure Firewall Rules"
    
    local port
    port=$(grep "addr:" "${CONFIG_FILE}" | grep -oP ':\K\d+' | head -n1)
    
    if [[ -z "${port}" ]]; then
        print_error "Could not detect listen port from configuration"
        read -p "Press Enter to continue..."
        return 1
    fi
    
    echo "Port: ${port}"
    echo ""
    echo "Required iptables rules:"
    echo ""
    echo -e "${C_CYAN}1)${C_NC} iptables -t raw -A PREROUTING -p tcp --dport ${port} -j NOTRACK"
    echo -e "${C_CYAN}2)${C_NC} iptables -t raw -A OUTPUT -p tcp --sport ${port} -j NOTRACK"
    echo -e "${C_CYAN}3)${C_NC} iptables -t mangle -A OUTPUT -p tcp --sport ${port} --tcp-flags RST RST -j DROP"
    echo ""
    
    if ! confirm_action "Apply these rules?"; then
        return 0
    fi
    
    # Apply rules
    iptables -t raw -C PREROUTING -p tcp --dport "${port}" -j NOTRACK 2>/dev/null || \
        iptables -t raw -A PREROUTING -p tcp --dport "${port}" -j NOTRACK
    
    iptables -t raw -C OUTPUT -p tcp --sport "${port}" -j NOTRACK 2>/dev/null || \
        iptables -t raw -A OUTPUT -p tcp --sport "${port}" -j NOTRACK
    
    iptables -t mangle -C OUTPUT -p tcp --sport "${port}" --tcp-flags RST RST -j DROP 2>/dev/null || \
        iptables -t mangle -A OUTPUT -p tcp --sport "${port}" --tcp-flags RST RST -j DROP
    
    print_success "Firewall rules applied"
    
    # Make persistent
    if confirm_action "Make rules persistent?"; then
        if command -v iptables-save &>/dev/null; then
            iptables-save > /etc/iptables/rules.v4 2>/dev/null || service iptables save 2>/dev/null || true
            print_success "Rules saved"
        fi
    fi
    
    read -p "Press Enter to continue..."
}

show_firewall_rules() {
    if [[ "${ROLE}" != "server" ]]; then
        print_error "Firewall rules only applicable for server role"
        read -p "Press Enter to continue..."
        return 0
    fi
    
    print_header "Current Firewall Rules"
    
    local port
    port=$(grep "addr:" "${CONFIG_FILE}" | grep -oP ':\K\d+' | head -n1)
    
    echo -e "${C_BOLD}RAW Table (PREROUTING):${C_NC}"
    iptables -t raw -L PREROUTING -n -v | grep -E "(Chain|${port}|pkts)" || echo "  No rules found"
    
    echo ""
    echo -e "${C_BOLD}RAW Table (OUTPUT):${C_NC}"
    iptables -t raw -L OUTPUT -n -v | grep -E "(Chain|${port}|pkts)" || echo "  No rules found"
    
    echo ""
    echo -e "${C_BOLD}MANGLE Table (OUTPUT):${C_NC}"
    iptables -t mangle -L OUTPUT -n -v | grep -E "(Chain|${port}|RST|pkts)" || echo "  No rules found"
    
    echo ""
    read -p "Press Enter to continue..."
}

#===============================================================================
# UNINSTALL
#===============================================================================

uninstall_paqet() {
    print_header "Uninstall Paqet"
    
    echo -e "${C_RED}${C_BOLD}WARNING: This will completely remove Paqet from your system!${C_NC}"
    echo ""
    echo "The following will be removed:"
    echo "  - Paqet service (${SERVICE_NAME})"
    echo "  - Configuration files"
    echo "  - Binary (${BIN_DIR}/paqet)"
    echo "  - Systemd service files"
    echo "  - Watchdog (if installed)"
    echo ""
    echo "Backups will be preserved in: ${BACKUP_DIR}"
    echo ""
    
    if ! confirm_action "Continue with uninstallation?"; then
        return 0
    fi
    
    # Create final backup
    print_step "Creating final backup..."
    create_backup
    
    # Stop and disable service
    print_step "Stopping and disabling service..."
    systemctl stop "${SERVICE_NAME}" 2>/dev/null || true
    systemctl disable "${SERVICE_NAME}" 2>/dev/null || true
    
    # Remove systemd service
    print_step "Removing systemd service..."
    rm -f "${SYSTEMD_DIR}/${SERVICE_NAME}.service"
    systemctl daemon-reload
    
    # Remove watchdog
    print_step "Removing watchdog..."
    crontab -l 2>/dev/null | grep -v "${WATCHDOG_SCRIPT}" | crontab - 2>/dev/null || true
    rm -f "${WATCHDOG_SCRIPT}"
    
    # Remove binary
    print_step "Removing binary..."
    rm -f "${BIN_DIR}/paqet"
    
    # Remove configuration
    print_step "Removing configuration..."
    rm -f "${CONFIG_FILE}"
    
    # Remove firewall rules (server)
    if [[ "${ROLE}" == "server" ]]; then
        print_step "Removing firewall rules..."
        local port
        port=$(grep "addr:" "${CONFIG_FILE}" 2>/dev/null | grep -oP ':\K\d+' | head -n1 || echo "")
        
        if [[ -n "${port}" ]]; then
            iptables -t raw -D PREROUTING -p tcp --dport "${port}" -j NOTRACK 2>/dev/null || true
            iptables -t raw -D OUTPUT -p tcp --sport "${port}" -j NOTRACK 2>/dev/null || true
            iptables -t mangle -D OUTPUT -p tcp --sport "${port}" --tcp-flags RST RST -j DROP 2>/dev/null || true
        fi
    fi
    
    print_success "Uninstallation complete"
    echo ""
    echo "Backups preserved in: ${BACKUP_DIR}"
    echo ""
    read -p "Press Enter to exit..."
    exit 0
}

#===============================================================================
# MAIN MENU
#===============================================================================

show_main_menu() {
    print_header "${SCRIPT_NAME} v${SCRIPT_VERSION}"
    
    echo -e "${C_BOLD}Service:${C_NC} ${SERVICE_NAME}"
    echo -e "${C_BOLD}Role:${C_NC} ${ROLE}"
    
    if systemctl is-active --quiet "${SERVICE_NAME}"; then
        echo -e "${C_BOLD}Status:${C_NC} ${C_GREEN}Running${C_NC}"
    else
        echo -e "${C_BOLD}Status:${C_NC} ${C_RED}Stopped${C_NC}"
    fi
    
    echo ""
    echo -e "${C_CYAN}═══════════════════ Service Control ═══════════════════${C_NC}"
    echo " 1) Start Service"
    echo " 2) Stop Service"
    echo " 3) Restart Service"
    echo " 4) Service Status"
    echo " 5) Enable on Boot"
    echo " 6) Disable on Boot"
    
    echo ""
    echo -e "${C_CYAN}═══════════════════ Logs & Monitoring ═══════════════════${C_NC}"
    echo " 7) View Live Logs"
    echo " 8) View Recent Logs"
    echo " 9) View Error Logs"
    echo "10) Export Logs"
    
    echo ""
    echo -e "${C_CYAN}═══════════════════ Configuration ═══════════════════${C_NC}"
    echo "11) View Configuration"
    echo "12) Edit Configuration"
    echo "13) Rotate Secret Key"
    
    echo ""
    echo -e "${C_CYAN}═══════════════════ Health & Testing ═══════════════════${C_NC}"
    echo "14) Health Dashboard"
    echo "15) Connection Statistics"
    echo "16) Test Connection"
    
    echo ""
    echo -e "${C_CYAN}═══════════════════ Backup & Restore ═══════════════════${C_NC}"
    echo "17) Create Backup"
    echo "18) List Backups"
    echo "19) Restore Backup"
    
    echo ""
    echo -e "${C_CYAN}═══════════════════ Advanced ═══════════════════${C_NC}"
    echo "20) Install Watchdog"
    echo "21) Remove Watchdog"
    echo "22) View Watchdog Log"
    
    if [[ "${ROLE}" == "server" ]]; then
        echo "23) Configure Firewall Rules"
        echo "24) Show Firewall Rules"
    fi
    
    echo ""
    echo -e "${C_CYAN}═══════════════════ System ═══════════════════${C_NC}"
    echo "98) Uninstall Paqet"
    echo " 0) Exit"
    
    echo ""
}

main_menu_loop() {
    while true; do
        show_main_menu
        
        read -p "Select option: " choice
        
        case "${choice}" in
            1) service_start; read -p "Press Enter to continue..." ;;
            2) service_stop; read -p "Press Enter to continue..." ;;
            3) service_restart; read -p "Press Enter to continue..." ;;
            4) service_status; read -p "Press Enter to continue..." ;;
            5) service_enable; read -p "Press Enter to continue..." ;;
            6) service_disable; read -p "Press Enter to continue..." ;;
            7) view_logs_live ;;
            8) view_logs_recent ;;
            9) view_logs_errors ;;
            10) export_logs ;;
            11) view_config ;;
            12) edit_config ;;
            13) rotate_secret_key ;;
            14) show_health_dashboard ;;
            15) show_connection_stats ;;
            16) test_connection ;;
            17) create_backup ;;
            18) list_backups ;;
            19) restore_backup ;;
            20) install_watchdog ;;
            21) remove_watchdog ;;
            22) view_watchdog_log ;;
            23) 
                if [[ "${ROLE}" == "server" ]]; then
                    configure_firewall_rules
                else
                    print_error "Invalid option"
                    sleep 1
                fi
                ;;
            24)
                if [[ "${ROLE}" == "server" ]]; then
                    show_firewall_rules
                else
                    print_error "Invalid option"
                    sleep 1
                fi
                ;;
            98) uninstall_paqet ;;
            0) print_step "Exiting..."; exit 0 ;;
            *) print_error "Invalid option"; sleep 1 ;;
        esac
    done
}

#===============================================================================
# MAIN
#===============================================================================

main() {
    check_root
    detect_service
    
    mkdir -p "${LOG_DIR}" "${STATE_DIR}" "${BACKUP_DIR}"
    touch "${LOG_FILE}"
    
    main_menu_loop
}

main "$@"
