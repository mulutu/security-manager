#!/bin/bash
set -e

# Security Manager - Production Agent Installer
# Tries pre-compiled binaries first, falls back to source compilation

# Configuration
ORG_ID=${SM_ORG_ID:-"demo"}
TOKEN=${SM_TOKEN:-"sm_tok_demo123"}
INGEST_URL=${SM_INGEST_URL:-"178.79.139.38:9002"}
INSTALL_DIR="/opt/security-manager"
SERVICE_NAME="security-manager-agent"
GITHUB_REPO="mulutu/security-manager"
BINARY_BASE_URL="https://github.com/${GITHUB_REPO}/releases/latest/download"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root (use sudo)"
   exit 1
fi

log_info "Security Manager - Production Agent Installer"
log_info "  Organization: $ORG_ID"
log_info "  Ingest URL: $INGEST_URL"
echo

# Detect platform
detect_platform() {
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    local arch=$(uname -m)
    
    case $arch in
        x86_64) arch="amd64" ;;
        aarch64|arm64) arch="arm64" ;;
        armv7l) arch="arm" ;;
        *) 
            log_warn "Unsupported architecture: $arch"
            return 1
            ;;
    esac
    
    echo "${os}-${arch}"
}

# Try downloading pre-compiled binary
try_precompiled() {
    local platform=$(detect_platform)
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    local binary_name="sm-agent-${platform}"
    local download_url="${BINARY_BASE_URL}/${binary_name}"
    
    log_info "Trying pre-compiled binary for ${platform}..."
    
    # Create installation directory
    mkdir -p "$INSTALL_DIR"
    
    # Download binary
    if command -v curl &> /dev/null; then
        if curl -fsSL -o "$INSTALL_DIR/sm-agent" "$download_url"; then
            chmod +x "$INSTALL_DIR/sm-agent"
            log_success "Downloaded pre-compiled binary"
            return 0
        fi
    elif command -v wget &> /dev/null; then
        if wget -q -O "$INSTALL_DIR/sm-agent" "$download_url"; then
            chmod +x "$INSTALL_DIR/sm-agent"
            log_success "Downloaded pre-compiled binary"
            return 0
        fi
    fi
    
    log_warn "Pre-compiled binary not available or download failed"
    return 1
}

# Fallback to source compilation
compile_from_source() {
    log_info "Falling back to source compilation..."
    
    # Use the existing install-agent.sh script
    if command -v curl &> /dev/null; then
        curl -fsSL "https://raw.githubusercontent.com/${GITHUB_REPO}/main/installer/install-agent.sh" | bash
    elif command -v wget &> /dev/null; then
        wget -qO- "https://raw.githubusercontent.com/${GITHUB_REPO}/main/installer/install-agent.sh" | bash
    else
        log_error "Neither curl nor wget available for downloading installer"
        exit 1
    fi
}

# Create systemd service
create_service() {
    log_info "Creating systemd service..."
    cat > /etc/systemd/system/${SERVICE_NAME}.service << EOF
[Unit]
Description=Security Manager Agent
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/sm-agent -org=$ORG_ID -token=$TOKEN -ingest=$INGEST_URL
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # Enable and start service
    systemctl daemon-reload
    systemctl enable ${SERVICE_NAME}
    systemctl start ${SERVICE_NAME}
}

# Verify installation
verify_installation() {
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
}

# Main installation flow
main() {
    # Try pre-compiled binary first
    if try_precompiled; then
        create_service
        verify_installation
    else
        # Fallback to source compilation
        log_warn "Switching to source compilation method..."
        compile_from_source
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
}

# Run main function
main "$@" 