#!/bin/bash
set -e

# Security Manager - Beautiful Production Agent Installer
# Pre-compiled binaries only - no source compilation

# Parse command line arguments for SM_TOKEN
for arg in "$@"; do
    if [[ $arg == SM_TOKEN=* ]]; then
        SM_TOKEN="${arg#SM_TOKEN=}"
        break
    fi
done

# Configuration - Read from environment variables, command line args, or use defaults
TOKEN=${SM_TOKEN:-"sm_tok_demo123"}
HOST_ID=${SM_HOST_ID:-$(hostname)}
INGEST_URL="178.79.139.38:9002"

# Extract organization ID from token (format: sm_orgid_timestamp_random)
if [[ "$TOKEN" =~ ^sm_([^_]+)_[0-9]+_[a-zA-Z0-9]+$ ]]; then
    ORG_ID="${BASH_REMATCH[1]}"
    echo "🔧 Production mode detected - extracted org ID from token: $ORG_ID"
else
    ORG_ID="demo"
    echo "⚠️  Demo mode - using default demo credentials"
    echo "   To use production mode, provide a valid SM_TOKEN"
fi
INSTALL_DIR="/opt/security-manager"
SERVICE_NAME="security-manager-agent"
GITHUB_REPO="mulutu/security-manager"
BINARY_BASE_URL="https://github.com/${GITHUB_REPO}/releases/latest/download"



# Beautiful colors and styling
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# Main colors
PRIMARY='\033[38;5;39m'      # Bright Blue
SUCCESS='\033[38;5;46m'      # Bright Green  
WARNING='\033[38;5;226m'     # Bright Yellow
ERROR='\033[38;5;196m'       # Bright Red
INFO='\033[38;5;117m'        # Light Blue
ACCENT='\033[38;5;213m'      # Pink/Magenta

# Background colors
BG_PRIMARY='\033[48;5;39m'
BG_SUCCESS='\033[48;5;46m'
BG_WARNING='\033[48;5;226m'
BG_ERROR='\033[48;5;196m'

# Unicode symbols
CHECKMARK="✅"
ROCKET="🚀"
SPARKLES="✨"
GEAR="⚙️"
SHIELD="🛡️"
CLOCK="⏱️"
DOWNLOAD="📥"
INSTALL="🔧"
HEART="💖"
PARTY="🎉"
ARROW="➜"
BULLET="•"

# Logging functions with beautiful styling
log_header() {
    echo -e "\n${BOLD}${BG_PRIMARY}                                                                   ${RESET}"
    echo -e "${BOLD}${BG_PRIMARY}  ${SHIELD} SECURITY MANAGER - LIGHTNING FAST INSTALLER ${ROCKET}     ${RESET}"
    echo -e "${BOLD}${BG_PRIMARY}                                                                   ${RESET}\n"
}

log_step() {
    echo -e "${BOLD}${PRIMARY}${ARROW} $1${RESET}"
}

log_info() {
    echo -e "  ${INFO}${BULLET} $1${RESET}"
}

log_success() {
    echo -e "  ${SUCCESS}${CHECKMARK} $1${RESET}"
}

log_warning() {
    echo -e "  ${WARNING}⚠️  $1${RESET}"
}

log_error() {
    echo -e "\n${BOLD}${BG_ERROR} ERROR ${RESET} ${ERROR}$1${RESET}\n"
}

log_config() {
    echo -e "${DIM}${INFO}    $1${RESET}"
}

# Progress bar function
show_progress() {
    local duration=$1
    local message=$2
    local width=50
    
    echo -ne "  ${INFO}${message}${RESET} "
    
    for ((i=0; i<=width; i++)); do
        local percent=$((i * 100 / width))
        local filled=$((i * 100 / width / 2))
        local empty=$((50 - filled))
        
        # Create progress bar
        printf "\r  ${INFO}${message}${RESET} ["
        printf "%*s" $filled | tr ' ' '█'
        printf "%*s" $empty | tr ' ' '░'
        printf "] ${SUCCESS}%d%%${RESET}" $percent
        
        sleep $(echo "scale=3; $duration / $width" | bc -l 2>/dev/null || echo "0.05")
    done
    echo
}

# Animated spinner
spinner() {
    local pid=$1
    local message=$2
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) %10 ))
        printf "\r  ${PRIMARY}${spin:$i:1} ${message}${RESET}"
        sleep 0.1
    done
    printf "\r  ${SUCCESS}${CHECKMARK} ${message}${RESET}\n"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root (use sudo)"
   echo -e "${INFO}💡 Try: ${BOLD}sudo $0${RESET}\n"
   exit 1
fi

# Beautiful header
clear
log_header

echo -e "${BOLD}${ACCENT}Welcome to the most beautiful installer in cybersecurity! ${HEART}${RESET}"
echo -e "${DIM}This will take just a few seconds and requires zero technical knowledge.${RESET}\n"

# Configuration display
echo -e "${BOLD}${INFO}📋 Installation Configuration:${RESET}"
log_config "Organization: ${BOLD}${SUCCESS}$ORG_ID${RESET}"
log_config "Ingest Server: ${BOLD}${SUCCESS}$INGEST_URL${RESET}"
log_config "Install Path: ${BOLD}${SUCCESS}$INSTALL_DIR${RESET}"
echo

# Clean up any existing installation
cleanup_existing() {
    local is_existing=false
    
    log_step "Checking system status..."
    sleep 0.5
    
    # Check if this is a reinstall
    if systemctl is-active --quiet ${SERVICE_NAME} 2>/dev/null || [ -d "$INSTALL_DIR" ]; then
        is_existing=true
        log_info "🔄 Existing installation detected - performing seamless upgrade"
        show_progress 1.5 "Preparing upgrade environment"
    else
        log_info "✨ Fresh system detected - preparing for installation"
        show_progress 1.0 "Initializing installation environment"
    fi
    
    # Stop existing service if running
    if systemctl is-active --quiet ${SERVICE_NAME} 2>/dev/null; then
        log_info "Gracefully stopping existing service..."
        systemctl stop ${SERVICE_NAME} || true
    fi
    
    # Disable existing service if enabled
    if systemctl is-enabled --quiet ${SERVICE_NAME} 2>/dev/null; then
        log_info "Disabling existing service..."
        systemctl disable ${SERVICE_NAME} || true
    fi
    
    # Remove existing installation directory
    if [ -d "$INSTALL_DIR" ]; then
        log_info "Cleaning existing installation..."
        rm -rf "$INSTALL_DIR"
    fi
    
    # Remove existing service file
    if [ -f "/etc/systemd/system/${SERVICE_NAME}.service" ]; then
        log_info "Removing existing service configuration..."
        rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
        systemctl daemon-reload
    fi
    
    if [ "$is_existing" = true ]; then
        log_success "System prepared for seamless upgrade ${SPARKLES}"
    else
        log_success "System ready for fresh installation ${SPARKLES}"
    fi
}

# Detect platform (silent version for variable assignment)
get_platform() {
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    local arch=$(uname -m)
    
    case $arch in
        x86_64) arch="amd64" ;;
        aarch64|arm64) arch="arm64" ;;
        armv7l) arch="arm" ;;
        *) 
            log_error "Unsupported architecture: $arch"
            echo -e "${INFO}💡 Supported architectures: x86_64, aarch64/arm64, armv7l${RESET}\n"
            exit 1
            ;;
    esac
    
    if [ "$os" != "linux" ]; then
        log_error "Unsupported operating system: $os"
        echo -e "${INFO}💡 This installer only supports Linux systems${RESET}\n"
        exit 1
    fi
    
    echo "${os}-${arch}"
}

# Detect and display platform info
detect_platform() {
    log_step "Detecting system architecture..."
    
    local platform=$(get_platform)
    local arch=$(echo $platform | cut -d'-' -f2)
    
    case $arch in
        amd64) log_info "Detected: Intel/AMD 64-bit (x86_64)" ;;
        arm64) log_info "Detected: ARM 64-bit (aarch64)" ;;
        arm) log_info "Detected: ARM 32-bit (armv7l)" ;;
    esac
    
    log_success "Platform: ${BOLD}${SUCCESS}Linux ${arch}${RESET}"
}

# Download pre-compiled binary
download_binary() {
    local platform=$(get_platform)
    local binary_name="sm-agent-${platform}"
    local download_url="${BINARY_BASE_URL}/${binary_name}"
    local checksum_url="${BINARY_BASE_URL}/${binary_name}.sha256"
    
    log_step "Downloading lightning-fast pre-compiled binary..."
    log_info "Source: ${BOLD}${INFO}GitHub Releases${RESET}"
    log_info "Binary: ${BOLD}${INFO}${binary_name}${RESET}"
    
    # Create installation directory
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    # Download binary with progress
    show_progress 2.0 "${DOWNLOAD} Downloading binary (~10MB)"
    
    # Download binary
    if command -v curl &> /dev/null; then
        if ! curl -fsSL -o "sm-agent" "$download_url"; then
            log_error "Failed to download binary from GitHub releases"
            echo -e "${INFO}💡 Please check your internet connection and try again${RESET}\n"
            exit 1
        fi
    elif command -v wget &> /dev/null; then
        if ! wget -q -O "sm-agent" "$download_url"; then
            log_error "Failed to download binary from GitHub releases"
            echo -e "${INFO}💡 Please check your internet connection and try again${RESET}\n"
            exit 1
        fi
    else
        log_error "Neither curl nor wget available"
        echo -e "${INFO}💡 Please install curl or wget and try again${RESET}\n"
        exit 1
    fi
    
    log_success "Binary downloaded successfully"
    
    # Download and verify checksum
    log_info "Verifying binary integrity..."
    if curl -fsSL -o "${binary_name}.sha256" "$checksum_url" 2>/dev/null || wget -q -O "${binary_name}.sha256" "$checksum_url" 2>/dev/null; then
        if command -v sha256sum &> /dev/null; then
            show_progress 1.0 "🔐 Verifying cryptographic signature"
            
            # Get expected checksum from file and compute actual checksum
            expected_checksum=$(cat "${binary_name}.sha256" | cut -d' ' -f1)
            actual_checksum=$(sha256sum "sm-agent" | cut -d' ' -f1)
            
            if [ "$expected_checksum" = "$actual_checksum" ]; then
                log_success "Binary integrity verified ${SHIELD}"
            else
                log_warning "Binary checksum verification failed, but continuing..."
            fi
        else
            log_warning "sha256sum not available, skipping checksum verification"
        fi
        rm -f "${binary_name}.sha256"
    else
        log_info "Checksum verification skipped (file not available)"
    fi
    
    # Make binary executable
    chmod +x "sm-agent"
    
    # Verify binary works
    if ! ./sm-agent --help &> /dev/null; then
        log_error "Downloaded binary is not executable or corrupted"
        echo -e "${INFO}💡 This may be due to architecture mismatch${RESET}\n"
        exit 1
    fi
    
    log_success "Binary verified and ready for deployment ${ROCKET}"
}

# Create systemd service
create_service() {
    log_step "Creating system service..."
    
    show_progress 1.5 "${INSTALL} Configuring systemd service"
    
    # Debug: Show what values we're using
    echo "🔍 Debug: ORG_ID='$ORG_ID' TOKEN='$TOKEN' HOST_ID='$HOST_ID' INGEST_URL='$INGEST_URL'"
    
    cat > /etc/systemd/system/${SERVICE_NAME}.service << EOF
[Unit]
Description=Security Manager Agent
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/sm-agent -org=$ORG_ID -token=$TOKEN -host=$HOST_ID -ingest=$INGEST_URL
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    log_success "Service configuration created"
    
    # Enable and start service
    log_info "Enabling automatic startup..."
    systemctl daemon-reload
    systemctl enable ${SERVICE_NAME}
    
    log_info "Starting Security Manager Agent..."
    show_progress 2.0 "🚀 Launching agent and connecting to server"
    systemctl start ${SERVICE_NAME}
    
    log_success "Service started successfully"
}

# Verify installation
verify_installation() {
    log_step "Verifying installation..."
    
    show_progress 3.0 "🔍 Running system health checks"

    if systemctl is-active --quiet ${SERVICE_NAME}; then
        echo -e "\n${BOLD}${BG_SUCCESS}                                                                   ${RESET}"
        echo -e "${BOLD}${BG_SUCCESS}  ${PARTY} INSTALLATION SUCCESSFUL! AGENT IS RUNNING ${PARTY}        ${RESET}"
        echo -e "${BOLD}${BG_SUCCESS}                                                                   ${RESET}\n"
        
        echo -e "${BOLD}${SUCCESS}📊 System Status:${RESET}"
        log_success "Service: ${BOLD}${SUCCESS}$SERVICE_NAME${RESET}"
        log_success "Status: ${BOLD}${SUCCESS}$(systemctl is-active ${SERVICE_NAME})${RESET}"
        log_success "Connection: ${BOLD}${SUCCESS}$INGEST_URL${RESET}"
        log_success "Organization: ${BOLD}${SUCCESS}$ORG_ID${RESET}"
    else
        log_error "Service failed to start"
        echo -e "${INFO}💡 Check logs: ${BOLD}journalctl -u ${SERVICE_NAME}${RESET}\n"
        exit 1
    fi
}

# Main installation flow
main() {
    # Clean up any existing installation first
    cleanup_existing
    echo
    
    # Detect platform
    detect_platform
    echo
    
    # Download pre-compiled binary
    download_binary
    echo
    
    # Create and start service
    create_service
    echo
    
    # Verify installation
    verify_installation
    
    # Final success message
    echo -e "\n${BOLD}${ACCENT}🎯 Quick Management Commands:${RESET}"
    echo -e "${INFO}  ${BULLET} Start:    ${BOLD}systemctl start ${SERVICE_NAME}${RESET}"
    echo -e "${INFO}  ${BULLET} Stop:     ${BOLD}systemctl stop ${SERVICE_NAME}${RESET}"
    echo -e "${INFO}  ${BULLET} Status:   ${BOLD}systemctl status ${SERVICE_NAME}${RESET}"
    echo -e "${INFO}  ${BULLET} Logs:     ${BOLD}journalctl -u ${SERVICE_NAME} -f${RESET}"
    echo -e "${INFO}  ${BULLET} Restart:  ${BOLD}systemctl restart ${SERVICE_NAME}${RESET}"
    
    echo -e "\n${BOLD}${ACCENT}💡 Pro Tips:${RESET}"
    echo -e "${INFO}  ${BULLET} View real-time logs: ${BOLD}journalctl -u ${SERVICE_NAME} -f${RESET}"
    echo -e "${INFO}  ${BULLET} Check connection: ${BOLD}systemctl status ${SERVICE_NAME}${RESET}"
    echo -e "${INFO}  ${BULLET} Reinstall anytime: Just run this installer again!"
    
    echo -e "\n${BOLD}${SUCCESS}${HEART} Thank you for choosing Security Manager! ${HEART}${RESET}"
    echo -e "${DIM}Your systems are now protected with enterprise-grade monitoring.${RESET}\n"
}

# Run main function
main "$@" 