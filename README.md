# 🚀 Paqet AutoDevOps – Enterprise Installation & Management Suite

**Production-grade automated installation, configuration, and lifecycle management system for Paqet**

---

## Overview

Paqet AutoDevOps is a comprehensive DevOps automation suite designed to simplify the deployment, configuration, and ongoing management of the Paqet network system. It targets both enterprise and individual operators who require a reliable, secure, and repeatable installation process without deep Linux or networking expertise.

The project encapsulates best practices in system hardening, network optimization, service supervision, and operational monitoring, delivering a turnkey Paqet environment suitable for production use.

---

## Key Capabilities

### Automated Installation & System Preparation

- Automated installation of Go (1.25+)
- Installation and configuration of libpcap
- Linux kernel optimization (BBR, TCP tuning)
- Automatic detection of network interface, IP address, and MAC address
- Secure generation of cryptographic secret keys
- Firewall configuration for server environments
- systemd service creation and enablement

### Service Management

- Interactive management console (start, stop, restart, status)
- Real-time service and health monitoring
- Configuration editor with validation
- Centralized log viewing and export
- Automated secret key rotation
- Backup and restore workflows
- Self-healing watchdog support

### Monitoring & Diagnostics

- Live connection statistics
- SOCKS5 and server connectivity testing
- CPU and memory utilization tracking
- Firewall status verification
- Error and anomaly reporting

---

## Supported Platforms

### Operating Systems

- Ubuntu 18.04+
- Debian 10+
- CentOS 7+
- RHEL 7+
- Rocky Linux / AlmaLinux

### Minimum System Requirements

- CPU: 1 core or higher
- RAM: 512 MB minimum (1 GB recommended)
- Disk: 1 GB free space
- Network: IPv4 or IPv6 connectivity
- Privileges: Root access required

---

## Quick Installation

### One‑Step Installation (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/oxychain-net/paqet-autodevops/main/install.sh | sudo bash
```

### Manual Installation

```bash
wget https://raw.githubusercontent.com/oxychain-net/paqet-autodevops/main/paqet-prerequisites.sh
wget https://raw.githubusercontent.com/oxychain-net/paqet-autodevops/main/paqet-installer.sh
wget https://raw.githubusercontent.com/oxychain-net/paqet-autodevops/main/paqet-manager.sh

chmod +x paqet-*.sh

sudo ./paqet-prerequisites.sh
sudo ./paqet-installer.sh
```

---

## Usage Workflow

### Step 1: Install System Prerequisites

```bash
sudo ./paqet-prerequisites.sh
```

This stage prepares the operating system by installing dependencies, optimizing kernel parameters, enabling BBR congestion control, configuring system limits, and ensuring time synchronization.

### Step 2: Install Paqet

```bash
sudo ./paqet-installer.sh
```

An interactive wizard guides the user through:

- Role selection (Client or Server)
- Network interface confirmation
- Automatic IP and MAC discovery
- Secure secret key generation
- Configuration review and confirmation

### Step 3: Service Management

```bash
sudo ./paqet-manager.sh
```

The management console provides structured access to service control, monitoring, configuration, backups, and advanced security features.

---

## Configuration

### Client Configuration

Location: `/etc/paqet/client.yaml`

```yaml
role: client
log:
  level: info
socks5:
  - listen: 127.0.0.1:1080
network:
  interface: eth0
  ipv4:
    addr: 192.168.1.100:0
    router_mac: aa:bb:cc:dd:ee:ff
server:
  addr: SERVER_IP:9999
transport:
  protocol: kcp
  kcp:
    mode: fast
    key: YOUR_SECRET_KEY
```

### Server Configuration

Location: `/etc/paqet/server.yaml`

```yaml
role: server
log:
  level: info
listen:
  addr: :9999
network:
  interface: eth0
  ipv4:
    addr: 10.0.0.100:9999
    router_mac: aa:bb:cc:dd:ee:ff
transport:
  protocol: kcp
  kcp:
    mode: fast
    key: YOUR_SECRET_KEY
```

---

## Firewall Integration

Firewall rules can be applied automatically via the manager or manually using iptables to ensure optimal packet handling and reduced latency for Paqet traffic.

---

## Troubleshooting

Common issues such as service startup failures, connectivity problems, firewall misconfiguration, and disabled BBR support are addressed through structured diagnostic steps using logs, manual test runs, and configuration validation.

---

## Security Best Practices

- Use strong, randomly generated secret keys
- Restrict firewall access to essential ports only
- Rotate encryption keys periodically
- Perform regular configuration backups
- Monitor logs and connection statistics continuously

---

## Updates

Before upgrading, always create a backup. Updates can be applied by re-running the installer or deploying updated binaries as provided in the repository.

---

## Support & Contributions

- Official Paqet documentation
- GitHub Issues for bug reports and feature requests
- Community contributions via pull requests are welcome

---

## License

This project is licensed under the MIT License.

---

Maintained by **oxychain-net**

