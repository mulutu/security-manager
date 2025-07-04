# Security Manager - One-Line Installers

Production-ready installers that match the PRD requirements for **≤ 60 second installation**.

## 🐧 Linux Installation

### Quick Install (Default Demo)
```bash
curl -fsSL https://raw.githubusercontent.com/mulutu/security-manager/main/installer/install.sh | sudo bash
```

### Production Install
```bash
curl -fsSL https://raw.githubusercontent.com/mulutu/security-manager/main/installer/install.sh | sudo bash -s -- --token "your_token" --org "your_org" --ingest "your_ingest_url"
```

### Options
- `--token TOKEN` - Authentication token (required)
- `--org ORG_ID` - Organization ID (required) 
- `--ingest URL` - Ingest service URL (default: 178.79.139.38:9002)
- `--install-dir DIR` - Installation directory (default: /opt/security-manager)
- `--help` - Show help message

## 🪟 Windows Installation

### Quick Install (Default Demo)
```powershell
irm https://raw.githubusercontent.com/mulutu/security-manager/main/installer/install.ps1 | iex
```

### Production Install
```powershell
irm https://raw.githubusercontent.com/mulutu/security-manager/main/installer/install.ps1 | iex; Install-SM -Token "your_token" -OrgId "your_org"
```

### Parameters
- `-Token` - Authentication token (default: sm_tok_demo123)
- `-OrgId` - Organization ID (default: demo)
- `-IngestUrl` - Ingest service URL (default: 178.79.139.38:9002)
- `-InstallDir` - Installation directory (default: C:\Program Files\Security Manager)
- `-ServiceName` - Windows service name (default: SecurityManagerAgent)

## 🔧 What the Installers Do

### Linux (`install.sh`)
1. ✅ **Detect OS/Architecture** - Supports Linux x64/ARM64
2. ✅ **Install Dependencies** - Go, Git, curl (via apt/yum/brew)
3. ✅ **Clone Repository** - Latest code from GitHub
4. ✅ **Build Agent** - Compile native binary
5. ✅ **Create Service** - systemd service with auto-start
6. ✅ **Test Connection** - Verify connectivity to ingest service
7. ✅ **Start Monitoring** - Service running and protected

### Windows (`install.ps1`)
1. ✅ **Admin Check** - Ensures running as Administrator
2. ✅ **Install Dependencies** - Go, Git (automatic download)
3. ✅ **Clone Repository** - Latest code from GitHub
4. ✅ **Build Agent** - Compile Windows executable
5. ✅ **Create Service** - Windows service with auto-start
6. ✅ **Test Connection** - Verify connectivity to ingest service
7. ✅ **Start Monitoring** - Service running and protected

## 🎯 PRD Compliance

| Requirement | Status | Implementation |
|-------------|--------|----------------|
| **Single command install** | ✅ | One-liner curl/irm |
| **≤ 60 second install** | ✅ | Automated dependency installation |
| **Unattended install** | ✅ | Silent/quiet installation |
| **Service auto-start** | ✅ | systemd/Windows service |
| **Heartbeat every 30s** | ✅ | Built into agent |
| **Token authentication** | ✅ | Required parameter |

## 🚀 Usage Examples

### Development/Testing
```bash
# Linux test environment
curl -fsSL https://raw.githubusercontent.com/mulutu/security-manager/main/installer/install.sh | sudo bash

# Windows test environment
irm https://raw.githubusercontent.com/mulutu/security-manager/main/installer/install.ps1 | iex
```

### Production Deployment
```bash
# Linux production
curl -fsSL https://raw.githubusercontent.com/mulutu/security-manager/main/installer/install.sh | sudo bash -s -- --token "sm_tok_prod_abc123" --org "acme-corp" --ingest "ingest.acme.com:9002"

# Windows production
irm https://raw.githubusercontent.com/mulutu/security-manager/main/installer/install.ps1 | iex; Install-SM -Token "sm_tok_prod_abc123" -OrgId "acme-corp" -IngestUrl "ingest.acme.com:9002"
```

## 🔍 Verification

After installation, verify the agent is working:

```bash
# Linux
systemctl status sm-agent
journalctl -u sm-agent -f

# Windows
Get-Service SecurityManagerAgent
Get-EventLog -LogName Application -Source SecurityManagerAgent -Newest 10
```

## 🆘 Troubleshooting

### Common Issues

1. **Permission Denied**
   - Linux: Run with `sudo`
   - Windows: Run PowerShell as Administrator

2. **Network Connectivity**
   - Check firewall rules for port 9002
   - Verify ingest service is running
   - Test with: `telnet your_ingest_url 9002`

3. **Service Won't Start**
   - Check logs (journalctl/Event Log)
   - Verify configuration file
   - Test agent manually first

### Debug Commands

```bash
# Test connectivity manually
go run tools/test_remote/main.go -ingest your_ingest_url -org your_org -token your_token

# Check configuration
cat /opt/security-manager/sm-agent.conf           # Linux
type "C:\Program Files\Security Manager\sm-agent.conf"  # Windows
```

---

These installers provide the **zero-touch onboarding** experience required by the PRD, with full automation and production-ready service management. 