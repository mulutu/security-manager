#!/bin/bash
# Security Manager Agent Installer for Linux
# This script downloads and installs the Security Manager agent

set -e

# Parse command line arguments
ORG_ID=""
TOKEN=""
HOST_ID=""
INGEST_URL="178.79.139.38:9002"

while [[ $# -gt 0 ]]; do
  case $1 in
    --org=*)
      ORG_ID="${1#*=}"
      shift
      ;;
    --token=*)
      TOKEN="${1#*=}"
      shift
      ;;
    --host=*)
      HOST_ID="${1#*=}"
      shift
      ;;
    --ingest=*)
      INGEST_URL="${1#*=}"
      shift
      ;;
    *)
      echo "Unknown parameter: $1"
      exit 1
      ;;
  esac
done

# Validate required parameters
if [[ -z "$ORG_ID" || -z "$TOKEN" || -z "$HOST_ID" ]]; then
    echo "❌ Missing required parameters. Usage:"
    echo "curl -fsSL <url> | sudo bash -s -- --org=<org_id> --token=<token> --host=<host_id>"
    exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}🛡️  Security Manager Agent Installer${NC}"
echo -e "${BLUE}   Organization: $ORG_ID${NC}"
echo -e "${BLUE}   Host ID: $HOST_ID${NC}"
echo -e "${BLUE}   Ingest URL: $INGEST_URL${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ This script must be run as root (use sudo)${NC}"
   exit 1
fi

# Detect system architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        BINARY_ARCH="amd64"
        ;;
    aarch64|arm64)
        BINARY_ARCH="arm64"
        ;;
    *)
        echo -e "${RED}❌ Unsupported architecture: $ARCH${NC}"
        exit 1
        ;;
esac

# Installation directory
INSTALL_DIR="/usr/local/bin"
SERVICE_DIR="/etc/systemd/system"
SERVICE_NAME="security-manager-agent"

echo -e "${BLUE}📥 Downloading Security Manager Agent...${NC}"

# Download the Linux agent binary
AGENT_URL="https://github.com/mulutu/security-manager/releases/latest/download/sm-agent-linux-${BINARY_ARCH}"
curl -fsSL -o "${INSTALL_DIR}/sm-agent" "${AGENT_URL}"
chmod +x "${INSTALL_DIR}/sm-agent"

echo -e "${GREEN}✅ Agent downloaded successfully${NC}"

# Create systemd service
echo -e "${BLUE}🔧 Creating systemd service...${NC}"

cat > "${SERVICE_DIR}/${SERVICE_NAME}.service" << EOF
[Unit]
Description=Security Manager Agent
After=network.target
Wants=network.target

[Service]
Type=simple
ExecStart=${INSTALL_DIR}/sm-agent -org="${ORG_ID}" -token="${TOKEN}" -host="${HOST_ID}" -ingest="${INGEST_URL}"
Restart=always
RestartSec=5
User=root
Group=root

# Environment variables
Environment=SM_ORG_ID="${ORG_ID}"
Environment=SM_TOKEN="${TOKEN}"
Environment=SM_HOST_ID="${HOST_ID}"
Environment=SM_INGEST_URL="${INGEST_URL}"

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=security-manager-agent

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and start service
systemctl daemon-reload
systemctl enable ${SERVICE_NAME}
systemctl start ${SERVICE_NAME}

# Verify installation
echo -e "${BLUE}🔍 Verifying installation...${NC}"
sleep 3

if systemctl is-active --quiet ${SERVICE_NAME}; then
    echo -e "${GREEN}✅ Security Manager Agent installed and running successfully!${NC}"
    echo -e "${GREEN}   Service: ${SERVICE_NAME}${NC}"
    echo -e "${GREEN}   Status: $(systemctl is-active ${SERVICE_NAME})${NC}"
    echo ""
    echo -e "${BLUE}📊 Management commands:${NC}"
    echo "  Start:   systemctl start ${SERVICE_NAME}"
    echo "  Stop:    systemctl stop ${SERVICE_NAME}"
    echo "  Status:  systemctl status ${SERVICE_NAME}"
    echo "  Logs:    journalctl -u ${SERVICE_NAME} -f"
    echo "  Restart: systemctl restart ${SERVICE_NAME}"
else
    echo -e "${RED}❌ Installation failed. Check logs with: journalctl -u ${SERVICE_NAME}${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}🎉 Installation complete! Your server is now being monitored.${NC}"
echo -e "${BLUE}   Check your dashboard for real-time status updates.${NC}" 