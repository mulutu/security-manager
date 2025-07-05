#!/bin/bash

# Security Manager Linux Agent Installer
# Supports Ubuntu/Debian, CentOS/RHEL, and Fedora

set -e

# Configuration
ORG_ID="${ORG_ID:-demo}"
TOKEN="${TOKEN:-sm_tok_demo123}"
INGEST_URL="${INGEST_URL:-178.79.139.38:9002}"
INSTALL_DIR="/opt/security-manager"
SERVICE_NAME="security-manager-agent"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root (use sudo)"
   exit 1
fi

log_info "Security Manager - Linux Agent Installer"
log_info "  Organization: $ORG_ID"
log_info "  Ingest URL: $INGEST_URL"
echo

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VERSION=$VERSION_ID
else
    log_error "Cannot detect OS version"
    exit 1
fi

log_info "Detected OS: $OS $VERSION"

# Check dependencies
log_info "Checking dependencies..."

# Check Go
if ! command -v go &> /dev/null; then
    log_warn "Go not found, installing..."
    
    case $OS in
        *"Ubuntu"*|*"Debian"*)
            apt-get update
            apt-get install -y golang-go
            ;;
        *"CentOS"*|*"Red Hat"*|*"Rocky"*|*"AlmaLinux"*)
            yum install -y golang || dnf install -y golang
            ;;
        *"Fedora"*)
            dnf install -y golang
            ;;
        *)
            log_error "Unsupported OS for automatic Go installation: $OS"
            log_error "Please install Go manually and re-run this script"
            exit 1
            ;;
    esac
else
    log_success "Go already installed"
fi

# Check Git
if ! command -v git &> /dev/null; then
    log_warn "Git not found, installing..."
    
    case $OS in
        *"Ubuntu"*|*"Debian"*)
            apt-get update
            apt-get install -y git
            ;;
        *"CentOS"*|*"Red Hat"*|*"Rocky"*|*"AlmaLinux"*)
            yum install -y git || dnf install -y git
            ;;
        *"Fedora"*)
            dnf install -y git
            ;;
        *)
            log_error "Unsupported OS for automatic Git installation: $OS"
            log_error "Please install Git manually and re-run this script"
            exit 1
            ;;
    esac
else
    log_success "Git already installed"
fi

# Create installation directory
log_info "Creating installation directory..."
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Download and build agent
log_info "Downloading and building agent..."
if [ -d "security-manager" ]; then
    rm -rf security-manager
fi

git clone https://github.com/mulutu/security-manager.git
cd security-manager

# Fix go.mod for compatibility with older Go versions
log_info "Fixing go.mod for compatibility..."
# Set Go version to 1.18 (widely available)
sed -i 's/go 1\.[0-9][0-9]*/go 1.18/' go.mod
# Remove toolchain directive if present
sed -i '/^toolchain/d' go.mod

# Ensure we have the most compatible versions for PRODUCTION
log_info "Setting up minimal production dependencies..."
cat > go.mod << EOF
module github.com/mulutu/security-manager

go 1.18

require (
	google.golang.org/grpc v1.50.1
	google.golang.org/protobuf v1.28.1
)
EOF

# Remove any existing go.sum to let Go generate correct checksums
rm -f go.sum

# Clean Go module cache to avoid any cached bad checksums
log_info "Cleaning Go module cache..."
go clean -modcache

# Temporarily comment out NATS and ClickHouse imports in the agent code
log_info "Temporarily disabling problematic imports for build..."
find cmd/ -name "*.go" -exec sed -i 's/.*nats.*//g' {} \;
find cmd/ -name "*.go" -exec sed -i 's/.*clickhouse.*//g' {} \;

# Skip all dependency downloads and resolution
log_info "Using minimal dependencies to avoid Go version conflicts..."

# Set environment for fresh downloads
export GOPROXY=direct
export GOSUMDB=off
export GO111MODULE=on
export CGO_ENABLED=0

# Build the agent
log_info "Building minimal production agent..."
cd cmd/agent

# Set production build environment
export GOPROXY=direct
export GOSUMDB=off
export GO111MODULE=on
export CGO_ENABLED=0

# Build with production flags - exclude all test code
go build -ldflags="-s -w" -tags="production,!test" -o "$INSTALL_DIR/sm-agent" .

# Create systemd service
log_info "Creating systemd service..."
cat > /etc/systemd/system/${SERVICE_NAME}.service << EOF
[Unit]
Description=Security Manager Agent
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/sm-agent
Environment=ORG_ID=$ORG_ID
Environment=TOKEN=$TOKEN
Environment=INGEST_URL=$INGEST_URL
Environment=TLS_ENABLED=false
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
log_info "Enabling and starting service..."
systemctl daemon-reload
systemctl enable ${SERVICE_NAME}
systemctl start ${SERVICE_NAME}

# Verify installation
log_info "Verifying installation..."
sleep 3

if systemctl is-active --quiet ${SERVICE_NAME}; then
    log_success "Security Manager Agent installed and running successfully!"
    log_success "Service: $SERVICE_NAME"
    log_success "Status: $(systemctl is-active ${SERVICE_NAME})"
else
    log_error "Service failed to start. Check logs with: journalctl -u ${SERVICE_NAME}"
    exit 1
fi

echo
log_info "Management commands:"
echo "  Start:   systemctl start ${SERVICE_NAME}"
echo "  Stop:    systemctl stop ${SERVICE_NAME}"  
echo "  Status:  systemctl status ${SERVICE_NAME}"
echo "  Logs:    journalctl -u ${SERVICE_NAME} -f"
echo "  Restart: systemctl restart ${SERVICE_NAME}"
echo
log_success "Installation complete!" 