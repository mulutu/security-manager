# Security Manager - Agent Installer

This directory contains the installation script for the Security Manager Agent.

## Quick Installation

**One-line installation command:**
```bash
curl -fsSL https://raw.githubusercontent.com/mulutu/security-manager/main/installer/install.sh | sudo bash
```

## What It Does

The installer:
1. **Downloads pre-compiled binary** for your architecture (linux-amd64, linux-arm64, linux-arm)
2. **Verifies binary integrity** using SHA256 checksums
3. **Installs to `/opt/security-manager/`**
4. **Creates systemd service** for automatic startup
5. **Starts the agent immediately**

## Supported Platforms

- **Linux x86_64** (amd64) - Intel/AMD 64-bit
- **Linux ARM64** (aarch64) - ARM 64-bit (Raspberry Pi 4, AWS Graviton, etc.)
- **Linux ARM** (armv7l) - ARM 32-bit (Raspberry Pi 3, etc.)

## Configuration

The installer uses these default values (can be overridden with environment variables):

```bash
# Default configuration
ORG_ID="demo"                    # Override with SM_ORG_ID
TOKEN="sm_tok_demo123"          # Override with SM_TOKEN  
INGEST_URL="178.79.139.38:9002" # Override with SM_INGEST_URL
```

### Custom Configuration Example

```bash
# Install with custom configuration
export SM_ORG_ID="mycompany"
export SM_TOKEN="sm_tok_abc123"
export SM_INGEST_URL="my-server.com:9002"
curl -fsSL https://raw.githubusercontent.com/mulutu/security-manager/main/installer/install.sh | sudo bash
```

## Service Management

After installation, manage the service with:

```bash
# Check status
sudo systemctl status security-manager-agent

# View logs
sudo journalctl -u security-manager-agent -f

# Start/stop/restart
sudo systemctl start security-manager-agent
sudo systemctl stop security-manager-agent
sudo systemctl restart security-manager-agent
```

## Installation Requirements

- **Linux operating system**
- **Root access** (sudo)
- **Internet connection** for downloading binaries
- **curl or wget** for downloading (usually pre-installed)

## Installation Speed

- **Pre-compiled binary**: ~5-10 seconds
- **No compilation required**
- **No Go toolchain needed**

## Troubleshooting

### Unsupported Architecture
If you get an "Unsupported architecture" error, the installer only supports:
- x86_64 (amd64)
- aarch64/arm64
- armv7l (arm)

### Download Failed
If binary download fails:
1. Check internet connection
2. Verify GitHub releases are accessible
3. Try again (temporary network issues)

### Service Won't Start
Check logs for details:
```bash
sudo journalctl -u security-manager-agent --no-pager
```

Common issues:
- Invalid token or organization ID
- Network connectivity to ingest server
- Firewall blocking outbound connections

## Files

- `install.sh` - Main installer script (pre-compiled binaries only)
- `install-agent.sh` - Legacy source compilation installer (for development)

## Security

- Binaries are downloaded from official GitHub releases
- SHA256 checksums are verified when available
- Service runs as root (required for system monitoring)
- All communication can be configured for TLS 