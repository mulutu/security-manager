#!/bin/bash

# Security Manager - One-Line Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/mulutu/security-manager/main/installer/install.sh | bash -s -- [OPTIONS]
# Example: curl -fsSL https://raw.githubusercontent.com/mulutu/security-manager/main/installer/install.sh | bash -s -- --token sm_tok_demo123 --org demo --ingest 178.79.139.38:9002

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
DEFAULT_INGEST_URL="178.79.139.38:9002"
DEFAULT_ORG_ID="demo"
DEFAULT_TOKEN="sm_tok_demo123"

# Parse command line arguments
INGEST_URL="${DEFAULT_INGEST_URL}"
ORG_ID="${DEFAULT_ORG_ID}"
TOKEN="${DEFAULT_TOKEN}"
INSTALL_DIR="/opt/security-manager"
SERVICE_NAME="sm-agent"

show_help() {
    cat << EOF
Security Manager Agent Installer

Usage: $0 [OPTIONS]

Options:
  --token TOKEN       Authentication token (required)
  --org ORG_ID        Organization ID (required)
  --ingest URL        Ingest service URL (default: ${DEFAULT_INGEST_URL})
  --install-dir DIR   Installation directory (default: ${INSTALL_DIR})
  --help              Show this help message

Examples:
  # Install with custom token and org
  $0 --token sm_tok_abc123 --org mycompany

  # Install with custom ingest URL
  $0 --token sm_tok_abc123 --org mycompany --ingest 192.168.1.100:9002

  # One-liner from GitHub
  curl -fsSL https://raw.githubusercontent.com/mulutu/security-manager/main/installer/install.sh | bash -s -- --token YOUR_TOKEN --org YOUR_ORG

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --token)
            TOKEN="$2"
            shift 2
            ;;
        --org)
            ORG_ID="$2"
            shift 2
            ;;
        --ingest)
            INGEST_URL="$2"
            shift 2
            ;;
        --install-dir)
            INSTALL_DIR="$2"
            shift 2
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$TOKEN" || -z "$ORG_ID" ]]; then
    echo -e "${RED}❌ Error: --token and --org are required${NC}"
    show_help
    exit 1
fi

echo -e "${GREEN}🛡️  Security Manager Agent Installer${NC}"
echo -e "${BLUE}   Organization: ${ORG_ID}${NC}"
echo -e "${BLUE}   Ingest URL: ${INGEST_URL}${NC}"
echo -e "${BLUE}   Install Dir: ${INSTALL_DIR}${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ This script must be run as root${NC}"
    echo "Please run: sudo $0 $@"
    exit 1
fi

# Detect OS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
else
    echo -e "${RED}❌ Unsupported OS: $OSTYPE${NC}"
    exit 1
fi

# Detect architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        ARCH="amd64"
        ;;
    arm64|aarch64)
        ARCH="arm64"
        ;;
    *)
        echo -e "${RED}❌ Unsupported architecture: $ARCH${NC}"
        exit 1
        ;;
esac

echo -e "${BLUE}📋 Detected: ${OS}-${ARCH}${NC}"

# Install dependencies
echo -e "${BLUE}📦 Installing dependencies...${NC}"
if command -v apt-get &> /dev/null; then
    apt-get update -qq
    apt-get install -y curl git golang-go
elif command -v yum &> /dev/null; then
    yum install -y curl git golang
elif command -v brew &> /dev/null; then
    brew install curl git go
else
    echo -e "${YELLOW}⚠️  Could not install dependencies automatically${NC}"
    echo -e "${YELLOW}   Please install: curl, git, golang${NC}"
fi

# Create install directory
echo -e "${BLUE}📁 Creating installation directory...${NC}"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Clone or update repository
if [[ -d "security-manager" ]]; then
    echo -e "${BLUE}📥 Updating existing repository...${NC}"
    cd security-manager
    git pull origin main
else
    echo -e "${BLUE}📥 Cloning repository...${NC}"
    git clone https://github.com/mulutu/security-manager.git
    cd security-manager
fi

# Build the agent
echo -e "${BLUE}🏗️  Building agent...${NC}"
cd cmd/agent
go build -o "${INSTALL_DIR}/sm-agent" .
cd ../..

# Make executable
chmod +x "${INSTALL_DIR}/sm-agent"

# Create configuration file
echo -e "${BLUE}⚙️  Creating configuration...${NC}"
cat > "${INSTALL_DIR}/sm-agent.conf" << EOF
# Security Manager Agent Configuration
SM_ORG_ID=${ORG_ID}
SM_TOKEN=${TOKEN}
SM_INGEST_URL=${INGEST_URL}
SM_HOST_ID=$(hostname)
SM_USE_TLS=false
SM_LOG_LEVEL=info
EOF

# Create systemd service
echo -e "${BLUE}🔧 Creating systemd service...${NC}"
cat > "/etc/systemd/system/${SERVICE_NAME}.service" << EOF
[Unit]
Description=Security Manager Agent
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=${INSTALL_DIR}/sm-agent
EnvironmentFile=${INSTALL_DIR}/sm-agent.conf
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
echo -e "${BLUE}🚀 Starting service...${NC}"
systemctl daemon-reload
systemctl enable "${SERVICE_NAME}"
systemctl start "${SERVICE_NAME}"

# Test the installation
echo -e "${BLUE}🧪 Testing installation...${NC}"
sleep 3

if systemctl is-active --quiet "${SERVICE_NAME}"; then
    echo -e "${GREEN}✅ Service is running${NC}"
    
    # Test connectivity
    cd "${INSTALL_DIR}/security-manager"
    if go run tools/test_remote/main.go -ingest "${INGEST_URL}" -org "${ORG_ID}" -token "${TOKEN}" 2>/dev/null; then
        echo -e "${GREEN}✅ Connectivity test passed${NC}"
    else
        echo -e "${YELLOW}⚠️  Connectivity test failed - check network and ingest service${NC}"
    fi
else
    echo -e "${RED}❌ Service failed to start${NC}"
    echo "Check logs: journalctl -u ${SERVICE_NAME} -f"
    exit 1
fi

echo ""
echo -e "${GREEN}🎉 Installation completed successfully!${NC}"
echo ""
echo -e "${BLUE}📊 Service Status:${NC}"
systemctl status "${SERVICE_NAME}" --no-pager -l
echo ""
echo -e "${BLUE}🔧 Management Commands:${NC}"
echo "  Start:   systemctl start ${SERVICE_NAME}"
echo "  Stop:    systemctl stop ${SERVICE_NAME}"
echo "  Status:  systemctl status ${SERVICE_NAME}"
echo "  Logs:    journalctl -u ${SERVICE_NAME} -f"
echo ""
echo -e "${BLUE}📁 Installation Directory: ${INSTALL_DIR}${NC}"
echo -e "${BLUE}⚙️  Configuration File: ${INSTALL_DIR}/sm-agent.conf${NC}"
echo ""
echo -e "${GREEN}🛡️  Your server is now protected by Security Manager!${NC}" 