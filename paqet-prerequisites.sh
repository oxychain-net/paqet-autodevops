#!/bin/bash
#===============================================================================
# Paqet AutoDevOps - Prerequisites & System Optimization
# Version: 1.0.0 | Author: oxychain-net | License: MIT
#
# Purpose:
#   - Install system dependencies (libpcap, Go, build tools)
#   - Optimize Linux kernel for high-performance networking
#   - Configure firewall rules for Paqet
#   - Prepare system for Paqet installation
#
# Usage:
#   sudo ./paqet-prerequisites.sh [--skip-optimization]
#
#===============================================================================

set -euo pipefail
IFS=$'\n\t'

#===============================================================================
# CONSTANTS
#===============================================================================

readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME="Paqet Prerequisites Installer"
readonly LOG_DIR="/var/log/paqet-autodevops"
readonly LOG_FILE="${LOG_DIR}/prerequisites.log"
readonly STATE_FILE="/var/lib/paqet-autodevops/prerequisites.state"
readonly BACKUP_DIR="/var/lib/paqet-autodevops/backups"

# Required Go version
readonly GO_REQUIRED_VERSION="1.25"
readonly GO_DOWNLOAD_VERSION="1.25.0"

# Colors
readonly C_RED='\033[0;31m'
readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[1;33m'
readonly C_BLUE='\033[0;34m'
readonly C_CYAN='\033[0;36m'
readonly C_BOLD='\033[1m'
readonly C_NC='\033[0m'

# Flags
SKIP_OPTIMIZATION=false

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
        DISTRO_VERSION="${VERSION_ID}"
        case "${DISTRO}" in
            ubuntu|debian)
                PKG_MANAGER="apt"
                ;;
            centos|rhel|rocky|alma|almalinux|fedora)
                if command -v dnf &>/dev/null; then
                    PKG_MANAGER="dnf"
                else
                    PKG_MANAGER="yum"
                fi
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
    log "Detected: ${DISTRO} ${DISTRO_VERSION} (${PKG_MANAGER})"
}

init_directories() {
    mkdir -p "${LOG_DIR}" "${BACKUP_DIR}" "$(dirname "${STATE_FILE}")"
    chmod 700 "${BACKUP_DIR}" "$(dirname "${STATE_FILE}")"
    touch "${LOG_FILE}" "${STATE_FILE}"
}

save_state() {
    local component="$1"
    local status="$2"
    echo "${component}=${status}" >> "${STATE_FILE}"
}

check_state() {
    local component="$1"
    grep -q "^${component}=installed$" "${STATE_FILE}" 2>/dev/null
}

#===============================================================================
# PACKAGE INSTALLATION
#===============================================================================

update_system() {
    print_step "Updating system packages"
    
    case "${PKG_MANAGER}" in
        apt)
            export DEBIAN_FRONTEND=noninteractive
            apt-get update -qq
            apt-get upgrade -y -qq
            ;;
        dnf|yum)
            ${PKG_MANAGER} update -y -q
            ;;
    esac
    
    print_success "System updated"
}

install_build_tools() {
    print_step "Installing build tools"
    
    case "${PKG_MANAGER}" in
        apt)
            apt-get install -y -qq \
                build-essential \
                git \
                curl \
                wget \
                ca-certificates \
                gnupg \
                lsb-release
            ;;
        dnf|yum)
            ${PKG_MANAGER} groupinstall -y -q "Development Tools"
            ${PKG_MANAGER} install -y -q git curl wget ca-certificates gnupg
            ;;
    esac
    
    save_state "build_tools" "installed"
    print_success "Build tools installed"
}

install_libpcap() {
    print_step "Installing libpcap development libraries"
    
    if check_state "libpcap"; then
        print_success "libpcap already installed"
        return 0
    fi
    
    case "${PKG_MANAGER}" in
        apt)
            apt-get install -y -qq libpcap-dev
            ;;
        dnf|yum)
            ${PKG_MANAGER} install -y -q libpcap-devel
            ;;
    esac
    
    # Verify installation
    if ldconfig -p | grep -q libpcap; then
        save_state "libpcap" "installed"
        print_success "libpcap installed successfully"
    else
        print_error "libpcap installation failed"
        return 1
    fi
}

install_golang() {
    print_step "Checking Go installation"
    
    if command -v go &>/dev/null; then
        local current_version
        current_version=$(go version | awk '{print $3}' | sed 's/go//')
        
        if [[ "$(printf '%s\n' "${GO_REQUIRED_VERSION}" "${current_version}" | sort -V | head -n1)" == "${GO_REQUIRED_VERSION}" ]]; then
            print_success "Go ${current_version} already installed (>= ${GO_REQUIRED_VERSION})"
            save_state "golang" "installed"
            return 0
        else
            print_step "Go ${current_version} found, but ${GO_REQUIRED_VERSION}+ required. Upgrading..."
        fi
    fi
    
    print_step "Installing Go ${GO_DOWNLOAD_VERSION}"
    
    local arch
    arch="$(uname -m)"
    case "${arch}" in
        x86_64) arch="amd64" ;;
        aarch64) arch="arm64" ;;
        armv7l) arch="armv6l" ;;
        *) 
            print_error "Unsupported architecture: ${arch}"
            return 1
            ;;
    esac
    
    local go_tar="go${GO_DOWNLOAD_VERSION}.linux-${arch}.tar.gz"
    local go_url="https://go.dev/dl/${go_tar}"
    
    # Remove old installation
    rm -rf /usr/local/go
    
    # Download and extract
    cd /tmp
    curl -fsSL "${go_url}" -o "${go_tar}"
    tar -C /usr/local -xzf "${go_tar}"
    rm -f "${go_tar}"
    
    # Add to PATH
    if ! grep -q '/usr/local/go/bin' /etc/profile; then
        echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
    fi
    
    if ! grep -q '/usr/local/go/bin' ~/.bashrc 2>/dev/null; then
        echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
    fi
    
    export PATH=$PATH:/usr/local/go/bin
    
    # Verify installation
    if command -v go &>/dev/null; then
        local installed_version
        installed_version=$(go version | awk '{print $3}')
        save_state "golang" "installed"
        print_success "Go ${installed_version} installed successfully"
    else
        print_error "Go installation failed"
        return 1
    fi
}

install_additional_tools() {
    print_step "Installing additional tools"
    
    case "${PKG_MANAGER}" in
        apt)
            apt-get install -y -qq \
                net-tools \
                iproute2 \
                iptables \
                iptables-persistent \
                ethtool \
                jq \
                htop \
                iotop \
                sysstat \
                haveged \
                chrony
            ;;
        dnf|yum)
            ${PKG_MANAGER} install -y -q \
                net-tools \
                iproute \
                iptables \
                iptables-services \
                ethtool \
                jq \
                htop \
                iotop \
                sysstat \
                haveged \
                chrony
            ;;
    esac
    
    save_state "additional_tools" "installed"
    print_success "Additional tools installed"
}

#===============================================================================
# SYSTEM OPTIMIZATION
#===============================================================================

optimize_kernel() {
    if [[ "${SKIP_OPTIMIZATION}" == "true" ]]; then
        print_step "Skipping kernel optimization (--skip-optimization flag)"
        return 0
    fi
    
    print_step "Optimizing kernel parameters for Paqet"
    
    local sysctl_file="/etc/sysctl.d/99-paqet.conf"
    
    # Backup existing file
    if [[ -f "${sysctl_file}" ]]; then
        cp "${sysctl_file}" "${BACKUP_DIR}/99-paqet.conf.$(date +%s).bak"
    fi
    
    # Calculate optimal values
    local ram_kb
    ram_kb=$(awk '/MemTotal:/{print $2}' /proc/meminfo)
    local rmem_max=$((ram_kb * 256))
    local wmem_max=$((ram_kb * 256))
    
    cat > "${sysctl_file}" <<EOF
# Paqet AutoDevOps - Kernel Optimization
# Generated: $(date)

# BBR Congestion Control (Critical for Paqet)
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# TCP Fast Open
net.ipv4.tcp_fastopen = 3

# Anti-Bufferbloat (Critical for low latency)
net.ipv4.tcp_notsent_lowat = 16384

# Network Buffers (Dynamic based on RAM)
net.core.rmem_max = ${rmem_max}
net.core.wmem_max = ${wmem_max}
net.ipv4.tcp_rmem = 4096 87380 ${rmem_max}
net.ipv4.tcp_wmem = 4096 65536 ${wmem_max}
net.core.netdev_max_backlog = 16384
net.core.somaxconn = 32768

# Connection Limits
fs.file-max = 1000000
net.ipv4.ip_local_port_range = 1024 65535

# TCP Optimization
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_sack = 1

# Security
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.icmp_echo_ignore_bogus_error_responses = 1

# IPv6
net.ipv6.conf.all.forwarding = 1
net.ipv4.ip_forward = 1

# Memory
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
EOF
    
    # Apply settings
    sysctl -p "${sysctl_file}" >/dev/null 2>&1
    
    # Load BBR module
    modprobe tcp_bbr 2>/dev/null || true
    echo "tcp_bbr" > /etc/modules-load.d/bbr.conf
    
    # Verify BBR
    local congestion
    congestion=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    if [[ "${congestion}" == "bbr" ]]; then
        print_success "Kernel optimized (BBR active)"
    else
        print_error "BBR not active (kernel may not support it)"
    fi
    
    save_state "kernel_optimization" "installed"
}

configure_system_limits() {
    if [[ "${SKIP_OPTIMIZATION}" == "true" ]]; then
        return 0
    fi
    
    print_step "Configuring system limits"
    
    local limits_file="/etc/security/limits.d/99-paqet.conf"
    
    cat > "${limits_file}" <<EOF
# Paqet AutoDevOps - System Limits
* soft nofile 1000000
* hard nofile 1000000
* soft nproc 1000000
* hard nproc 1000000
root soft nofile 1000000
root hard nofile 1000000
root soft nproc 1000000
root hard nproc 1000000
EOF
    
    # Systemd limits
    if [[ -d /etc/systemd ]]; then
        mkdir -p /etc/systemd/system.conf.d
        cat > /etc/systemd/system.conf.d/paqet-limits.conf <<EOF
[Manager]
DefaultLimitNOFILE=1000000
DefaultLimitNPROC=1000000
EOF
        systemctl daemon-reload
    fi
    
    save_state "system_limits" "installed"
    print_success "System limits configured"
}

optimize_network_interface() {
    if [[ "${SKIP_OPTIMIZATION}" == "true" ]]; then
        return 0
    fi
    
    print_step "Optimizing network interface"
    
    local iface
    iface=$(ip route get 8.8.8.8 2>/dev/null | awk '{print $5; exit}')
    
    if [[ -z "${iface}" ]]; then
        print_error "Could not detect primary network interface"
        return 1
    fi
    
    # Disable offloading for better performance
    ethtool -K "${iface}" tso off gso off gro off sg off 2>/dev/null || true
    ethtool -G "${iface}" rx 4096 tx 4096 2>/dev/null || true
    ip link set dev "${iface}" txqueuelen 10000 2>/dev/null || true
    
    # MTU Discovery
    local optimal_mtu=1400
    if command -v ping &>/dev/null; then
        if ping -c 1 -M do -s 1472 1.1.1.1 &>/dev/null; then
            optimal_mtu=$((1500 - 60))
        elif ping -c 1 -M do -s 1372 1.1.1.1 &>/dev/null; then
            optimal_mtu=$((1400 - 60))
        else
            optimal_mtu=$((1280 - 60))
        fi
    fi
    
    ip link set dev "${iface}" mtu "${optimal_mtu}" 2>/dev/null || true
    
    print_success "Network interface ${iface} optimized (MTU: ${optimal_mtu})"
    save_state "network_optimization" "installed"
}

#===============================================================================
# TIME & ENTROPY
#===============================================================================

configure_time_sync() {
    if [[ "${SKIP_OPTIMIZATION}" == "true" ]]; then
        return 0
    fi
    
    print_step "Configuring time synchronization"
    
    if command -v chronyd &>/dev/null; then
        systemctl enable chronyd
        systemctl start chronyd
        chronyc -a makestep &>/dev/null || true
        print_success "Chrony configured and synchronized"
    elif systemctl is-active --quiet systemd-timesyncd; then
        print_success "systemd-timesyncd already active"
    else
        print_error "No time synchronization service available"
    fi
    
    save_state "time_sync" "installed"
}

configure_entropy() {
    if [[ "${SKIP_OPTIMIZATION}" == "true" ]]; then
        return 0
    fi
    
    print_step "Configuring entropy generation"
    
    if command -v haveged &>/dev/null; then
        systemctl enable haveged
        systemctl start haveged
        
        local entropy
        entropy=$(cat /proc/sys/kernel/random/entropy_avail)
        
        if [[ ${entropy} -gt 2000 ]]; then
            print_success "Entropy configured (${entropy} bits - excellent)"
        else
            print_success "Entropy configured (${entropy} bits)"
        fi
    fi
    
    save_state "entropy" "installed"
}

#===============================================================================
# VERIFICATION
#===============================================================================

verify_installation() {
    print_header "Verifying Installation"
    
    local checks_passed=0
    local checks_total=0
    
    # Check libpcap
    ((checks_total++))
    if ldconfig -p | grep -q libpcap; then
        print_success "libpcap: Installed"
        ((checks_passed++))
    else
        print_error "libpcap: Not found"
    fi
    
    # Check Go
    ((checks_total++))
    if command -v go &>/dev/null; then
        local go_version
        go_version=$(go version | awk '{print $3}')
        print_success "Go: ${go_version}"
        ((checks_passed++))
    else
        print_error "Go: Not found"
    fi
    
    # Check BBR
    ((checks_total++))
    if sysctl net.ipv4.tcp_congestion_control 2>/dev/null | grep -q bbr; then
        print_success "BBR: Active"
        ((checks_passed++))
    else
        print_error "BBR: Not active"
    fi
    
    # Check Entropy
    ((checks_total++))
    local entropy
    entropy=$(cat /proc/sys/kernel/random/entropy_avail)
    if [[ ${entropy} -gt 1000 ]]; then
        print_success "Entropy: ${entropy} bits (good)"
        ((checks_passed++))
    else
        print_error "Entropy: ${entropy} bits (low)"
    fi
    
    echo ""
    print_step "Verification: ${checks_passed}/${checks_total} checks passed"
    echo ""
    
    if [[ ${checks_passed} -eq ${checks_total} ]]; then
        return 0
    else
        return 1
    fi
}

#===============================================================================
# MAIN
#===============================================================================

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-optimization)
                SKIP_OPTIMIZATION=true
                shift
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    check_root
    init_directories
    
    print_header "${SCRIPT_NAME} v${SCRIPT_VERSION}"
    
    detect_distro
    
    print_header "PHASE 1: System Preparation"
    update_system
    install_build_tools
    install_libpcap
    install_golang
    install_additional_tools
    
    print_header "PHASE 2: System Optimization"
    optimize_kernel
    configure_system_limits
    optimize_network_interface
    configure_time_sync
    configure_entropy
    
    print_header "PHASE 3: Verification"
    if verify_installation; then
        print_success "All prerequisites installed successfully!"
        print_step "System is ready for Paqet installation"
        print_step "Run: sudo ./paqet-installer.sh"
    else
        print_error "Some checks failed. Please review the output above."
        exit 1
    fi
}

main "$@"
