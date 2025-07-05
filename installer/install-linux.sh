#!/bin/bash

# Security Manager - Linux Agent Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/mulutu/security-manager/main/installer/install-linux.sh | bash

set -e

# Default configuration
ORG_ID="${SM_ORG_ID:-demo}"
TOKEN="${SM_TOKEN:-sm_tok_demo123}"
INGEST_URL="${SM_INGEST_URL:-178.79.139.38:9002}"
INSTALL_DIR="/opt/security-manager"
SERVICE_NAME="security-manager-agent"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root (use sudo)"
   exit 1
fi

log_info "Security Manager - Linux Agent Installer"
echo "  Organization: $ORG_ID"
echo "  Ingest URL: $INGEST_URL"
echo ""

# Check dependencies
log_info "Checking dependencies..."

# Check if Go is installed
if ! command -v go &> /dev/null; then
    log_info "Installing Go..."
    if command -v apt-get &> /dev/null; then
        # Ubuntu/Debian
        apt-get update -qq
        apt-get install -y golang-go git
    elif command -v yum &> /dev/null; then
        # CentOS/RHEL
        yum install -y golang git
    elif command -v dnf &> /dev/null; then
        # Fedora
        dnf install -y golang git
    else
        log_error "Unsupported package manager. Please install Go and Git manually."
        exit 1
    fi
    log_success "Go installed"
else
    log_success "Go already installed"
fi

# Check if Git is installed
if ! command -v git &> /dev/null; then
    log_info "Installing Git..."
    if command -v apt-get &> /dev/null; then
        apt-get install -y git
    elif command -v yum &> /dev/null; then
        yum install -y git
    elif command -v dnf &> /dev/null; then
        dnf install -y git
    fi
    log_success "Git installed"
else
    log_success "Git already installed"
fi

# Create installation directory
log_info "Creating installation directory..."
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Clone and build the agent
log_info "Downloading and building agent..."
if [ -d "security-manager" ]; then
    rm -rf security-manager
fi

git clone https://github.com/mulutu/security-manager.git
cd security-manager

# Fix go.mod for older Go versions compatibility
log_info "Fixing go.mod for compatibility..."
sed -i 's/go 1\.23\.0/go 1.21/' go.mod
sed -i '/^toolchain/d' go.mod

# Build the agent
export GOOS=linux
export GOARCH=amd64
export CGO_ENABLED=0

go mod download
go build -o sm-agent ./cmd/agent

# Install the agent
cp sm-agent "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/sm-agent"

log_success "Agent built and installed"

# Create systemd service
log_info "Creating systemd service..."
cat > /etc/systemd/system/$SERVICE_NAME.service << EOF
[Unit]
Description=Security Manager Agent
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/sm-agent -org $ORG_ID -token $TOKEN -ingest $INGEST_URL
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
systemctl daemon-reload
systemctl enable $SERVICE_NAME
systemctl start $SERVICE_NAME

# Check service status
sleep 3
if systemctl is-active --quiet $SERVICE_NAME; then
    log_success "Service is running"
else
    log_warning "Service may not be running properly"
    log_info "Check logs with: journalctl -u $SERVICE_NAME -f"
fi

# Cleanup
cd /
rm -rf "$INSTALL_DIR/security-manager"

log_success "Installation completed successfully!"
echo ""
log_info "Service Status:"
systemctl status $SERVICE_NAME --no-pager -l
echo ""
log_info "Management Commands:"
echo "  Start:   sudo systemctl start $SERVICE_NAME"
echo "  Stop:    sudo systemctl stop $SERVICE_NAME"
echo "  Status:  sudo systemctl status $SERVICE_NAME"
echo "  Logs:    sudo journalctl -u $SERVICE_NAME -f"
echo "  Disable: sudo systemctl disable $SERVICE_NAME"
echo ""
log_info "Web Interfaces:"
echo "  NATS Monitor: http://$(echo $INGEST_URL | cut -d: -f1):8222"
echo "  ClickHouse UI: http://$(echo $INGEST_URL | cut -d: -f1):8123"
echo ""
log_info "Documentation: https://github.com/mulutu/security-manager/blob/main/DEPLOYMENT_MANUAL.md" 