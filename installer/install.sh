#!/bin/bash
set -e

# Security Manager - Production Agent Installer
# Pre-compiled binaries only - no source compilation

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
            log_error "Unsupported architecture: $arch"
            log_error "Supported architectures: x86_64 (amd64), aarch64/arm64, armv7l (arm)"
            exit 1
            ;;
    esac
    
    if [ "$os" != "linux" ]; then
        log_error "Unsupported operating system: $os"
        log_error "This installer only supports Linux"
        exit 1
    fi
    
    echo "${os}-${arch}"
}

# Download pre-compiled binary
download_binary() {
    local platform=$(detect_platform)
    local binary_name="sm-agent-${platform}"
    local download_url="${BINARY_BASE_URL}/${binary_name}"
    local checksum_url="${BINARY_BASE_URL}/${binary_name}.sha256"
    
    log_info "Downloading pre-compiled binary for ${platform}..."
    
    # Create installation directory
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    # Download binary
    if command -v curl &> /dev/null; then
        if ! curl -fsSL -o "sm-agent" "$download_url"; then
            log_error "Failed to download binary from: $download_url"
            log_error "Please check your internet connection and try again"
            exit 1
        fi
        
        # Download and verify checksum
        if curl -fsSL -o "${binary_name}.sha256" "$checksum_url" 2>/dev/null; then
            log_info "Verifying binary integrity..."
            if command -v sha256sum &> /dev/null; then
                if echo "$(cat ${binary_name}.sha256)" | sha256sum -c --quiet; then
                    log_success "Binary integrity verified"
                else
                    log_warn "Binary checksum verification failed, but continuing..."
                fi
            else
                log_warn "sha256sum not available, skipping checksum verification"
            fi
            rm -f "${binary_name}.sha256"
        else
            log_warn "Could not download checksum file, skipping verification"
        fi
        
    elif command -v wget &> /dev/null; then
        if ! wget -q -O "sm-agent" "$download_url"; then
            log_error "Failed to download binary from: $download_url"
            log_error "Please check your internet connection and try again"
            exit 1
        fi
        
        # Download and verify checksum
        if wget -q -O "${binary_name}.sha256" "$checksum_url" 2>/dev/null; then
            log_info "Verifying binary integrity..."
            if command -v sha256sum &> /dev/null; then
                if echo "$(cat ${binary_name}.sha256)" | sha256sum -c --quiet; then
                    log_success "Binary integrity verified"
                else
                    log_warn "Binary checksum verification failed, but continuing..."
                fi
            else
                log_warn "sha256sum not available, skipping checksum verification"
            fi
            rm -f "${binary_name}.sha256"
        else
            log_warn "Could not download checksum file, skipping verification"
        fi
        
    else
        log_error "Neither curl nor wget available for downloading"
        log_error "Please install curl or wget and try again"
        exit 1
    fi
    
    # Make binary executable
    chmod +x "sm-agent"
    
    # Verify binary works
    if ! ./sm-agent --help &> /dev/null; then
        log_error "Downloaded binary is not executable or corrupted"
        log_error "This may be due to architecture mismatch or corrupted download"
        exit 1
    fi
    
    log_success "Downloaded and verified pre-compiled binary"
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
    # Download pre-compiled binary
    download_binary
    
    # Create and start service
    create_service
    
    # Verify installation
    verify_installation
    
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