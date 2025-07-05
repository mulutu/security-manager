# Security Manager - Linux Agent Installer

Production-ready installer for Linux systems that provides **≤ 60 second installation**.

## 🐧 Linux Installation

### Quick Install (Default Demo)
```bash
curl -fsSL https://raw.githubusercontent.com/mulutu/security-manager/main/installer/install-linux.sh | sudo bash
```

### Production Install
```bash
export SM_ORG_ID="your_org"
export SM_TOKEN="your_token"
export SM_INGEST_URL="your_ingest_url"
curl -fsSL https://raw.githubusercontent.com/mulutu/security-manager/main/installer/install-linux.sh | sudo bash
```

### Environment Variables
- `SM_ORG_ID` - Organization ID (default: "demo")
- `SM_TOKEN` - Authentication token (default: "sm_tok_demo123")
- `SM_INGEST_URL` - Ingest service URL (default: "178.79.139.38:9002")

## 🔧 What the Installer Does

### Linux (`install-linux.sh`)
1. ✅ **Detect OS/Architecture** - Supports Ubuntu/Debian, CentOS/RHEL, Fedora
2. ✅ **Install Dependencies** - Go, Git (via apt/yum/dnf)
3. ✅ **Clone Repository** - Latest code from GitHub
4. ✅ **Build Agent** - Compile native Linux binary
5. ✅ **Create Service** - systemd service with auto-start
6. ✅ **Test Connection** - Verify connectivity to ingest service
7. ✅ **Start Monitoring** - Service running and protected

## 🎯 PRD Compliance

| Requirement | Status | Implementation |
|-------------|--------|----------------|
| **Single command install** | ✅ | One-liner curl |
| **≤ 60 second install** | ✅ | Automated dependency installation |
| **Unattended install** | ✅ | Silent installation |
| **Service auto-start** | ✅ | systemd service |
| **Heartbeat every 30s** | ✅ | Built into agent |
| **Token authentication** | ✅ | Environment variable |

## 🚀 Usage Examples

### Development/Testing
```bash
# Linux test environment
curl -fsSL https://raw.githubusercontent.com/mulutu/security-manager/main/installer/install-linux.sh | sudo bash
```

### Production Deployment
```bash
# Linux production
export SM_ORG_ID="acme-corp"
export SM_TOKEN="sm_tok_prod_abc123"
export SM_INGEST_URL="ingest.acme.com:9002"
curl -fsSL https://raw.githubusercontent.com/mulutu/security-manager/main/installer/install-linux.sh | sudo bash
```

## 🔍 Verification

After installation, verify the agent is working:

```bash
# Check service status
sudo systemctl status security-manager-agent

# View logs
sudo journalctl -u security-manager-agent -f

# Test connectivity
sudo systemctl is-active security-manager-agent
```

## 🛠️ Service Management

The agent runs as a systemd service:

```bash
# Start service
sudo systemctl start security-manager-agent

# Stop service
sudo systemctl stop security-manager-agent

# Restart service
sudo systemctl restart security-manager-agent

# Enable auto-start
sudo systemctl enable security-manager-agent

# Disable auto-start
sudo systemctl disable security-manager-agent

# View service configuration
sudo systemctl cat security-manager-agent
```

## 🆘 Troubleshooting

### Common Issues

1. **Permission Denied**
   - Run with `sudo`
   - Check file permissions in `/opt/security-manager/`

2. **Network Connectivity**
   - Check firewall rules for port 9002
   - Verify ingest service is running
   - Test with: `telnet your_ingest_url 9002`

3. **Service Won't Start**
   - Check logs: `sudo journalctl -u security-manager-agent`
   - Verify configuration
   - Test agent manually: `/opt/security-manager/sm-agent -org demo -token sm_tok_demo123 -ingest 178.79.139.38:9002`

4. **Build Issues**
   - Ensure Go is installed: `go version`
   - Check internet connectivity for downloading dependencies
   - Verify GitHub access

### Debug Commands

```bash
# Test connectivity manually
cd /opt/security-manager
./sm-agent -org demo -token sm_tok_demo123 -ingest 178.79.139.38:9002

# Check service logs
sudo journalctl -u security-manager-agent --since "1 hour ago"

# Check installation directory
ls -la /opt/security-manager/

# Check service file
sudo systemctl cat security-manager-agent
```

### Supported Distributions

- **Ubuntu/Debian**: Uses `apt-get` package manager
- **CentOS/RHEL**: Uses `yum` package manager  
- **Fedora**: Uses `dnf` package manager

### Files Created

- `/opt/security-manager/sm-agent` - Agent binary
- `/etc/systemd/system/security-manager-agent.service` - Service definition
- System logs via journald

---

This installer provides the **zero-touch onboarding** experience for Linux systems, with full automation and production-ready service management. 