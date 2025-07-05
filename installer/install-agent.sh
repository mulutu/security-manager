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
log_info "Setting up production-only dependencies..."
cat > go.mod << EOF
module github.com/mulutu/security-manager

go 1.18

require (
	github.com/ClickHouse/clickhouse-go/v2 v2.5.1
	github.com/nats-io/nats.go v1.13.0
	google.golang.org/grpc v1.50.1
	google.golang.org/protobuf v1.28.1
)

// Exclude all test-related packages
exclude (
	github.com/nats-io/nats-server/v2 v2.11.6
	github.com/nats-io/nats-server/v2 v2.10.0
	github.com/nats-io/nats-server/v2 v2.9.0
)

// Replace any test imports with dummy modules
replace (
	github.com/nats-io/nats-server/v2/test => ./internal/noop
	github.com/nats-io/nats-server/v2/server => ./internal/noop
)
EOF

# Create a dummy noop module to replace test imports
mkdir -p internal/noop
cat > internal/noop/go.mod << EOF
module noop
go 1.18
EOF

cat > internal/noop/noop.go << EOF
// Package noop provides empty implementations for test dependencies
package noop

// Empty package to replace test dependencies
EOF

# Remove any existing go.sum and test directories
rm -f go.sum
rm -rf tools/test_*

# Download specific versions to avoid conflicts
log_info "Downloading production dependencies only..."
export GOPROXY=direct
export GOSUMDB=off
export GO111MODULE=on
export CGO_ENABLED=0

# Download only the specific versions we need for production
go mod download github.com/ClickHouse/clickhouse-go/v2@v2.5.1
go mod download github.com/nats-io/nats.go@v1.13.0
go mod download google.golang.org/grpc@v1.50.1
go mod download google.golang.org/protobuf@v1.28.1

# Skip go mod tidy to avoid pulling in test dependencies
log_info "Skipping dependency resolution to avoid test packages..."

# Verify no test imports exist in our code
log_info "Verifying production-only imports..."
if grep -r "nats-server" cmd/ internal/ 2>/dev/null; then
    log_error "Found test imports in production code - cleaning up..."
    # Remove any test imports from our code
    find cmd/ internal/ -name "*.go" -exec sed -i '/nats-server/d' {} \;
fi

# Build the agent
log_info "Building production agent..."
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