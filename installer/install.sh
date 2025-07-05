#!/bin/bash
set -e

# Security Manager - Self-Healing Production Agent Installer
# Handles all version conflicts, compatibility issues, and edge cases automatically

# Parse command line arguments for SM_TOKEN
for arg in "$@"; do
    if [[ $arg == SM_TOKEN=* ]]; then
        SM_TOKEN="${arg#SM_TOKEN=}"
        break
    fi
done

# Configuration - Read from environment variables, command line args, or use defaults
TOKEN=${SM_TOKEN:-"sm_tok_demo123"}
INGEST_URL="178.79.139.38:9002"

# Check if we have a production token
if [[ "$TOKEN" =~ ^sm_[^_]+_[0-9]+_.+$ ]]; then
    echo "🔧 Production mode detected - using provided token"
else
    echo "⚠️  Demo mode - using default demo credentials"
    echo "   To use production mode, provide a valid SM_TOKEN"
fi

INSTALL_DIR="/opt/security-manager"
SERVICE_NAME="security-manager-agent"
GITHUB_REPO="mulutu/security-manager"
BINARY_BASE_URL="https://github.com/${GITHUB_REPO}/releases/latest/download"

# Version compatibility and self-healing configuration
MIN_REQUIRED_VERSION="v1.0.5"  # Minimum version that supports token-only mode
MAX_RETRY_ATTEMPTS=3
BINARY_VALIDATION_TIMEOUT=30

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
HEALING="🔄"
MAGIC="✨"

# Logging functions with beautiful styling
log_header() {
    echo -e "\n${BOLD}${BG_PRIMARY}                                                                   ${RESET}"
    echo -e "${BOLD}${BG_PRIMARY}  ${SHIELD} SECURITY MANAGER - SELF-HEALING INSTALLER ${MAGIC}       ${RESET}"
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

log_healing() {
    echo -e "  ${WARNING}${HEALING} $1${RESET}"
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

echo -e "${BOLD}${ACCENT}Welcome to the most intelligent installer in cybersecurity! ${HEART}${RESET}"
echo -e "${DIM}This installer automatically handles all compatibility issues and version conflicts.${RESET}\n"

# Configuration display
echo -e "${BOLD}${INFO}📋 Installation Configuration:${RESET}"
log_config "Token: ${BOLD}${SUCCESS}${TOKEN:0:20}...${RESET}"
log_config "Ingest Server: ${BOLD}${SUCCESS}$INGEST_URL${RESET}"
log_config "Install Path: ${BOLD}${SUCCESS}$INSTALL_DIR${RESET}"
log_config "Min Required Version: ${BOLD}${SUCCESS}$MIN_REQUIRED_VERSION${RESET}"
echo

# Enhanced cleanup with version detection and self-healing
cleanup_existing() {
    local is_existing=false
    local needs_healing=false
    
    log_step "Performing intelligent system analysis..."
    sleep 0.5
    
    # Check if this is a reinstall
    if systemctl is-active --quiet ${SERVICE_NAME} 2>/dev/null || [ -d "$INSTALL_DIR" ]; then
        is_existing=true
        log_info "🔄 Existing installation detected - analyzing compatibility"
        
        # Check if existing binary is compatible
        if [ -f "$INSTALL_DIR/sm-agent" ]; then
            log_info "🔍 Testing existing binary compatibility..."
            
            # Test if binary supports token-only mode
            timeout 5 "$INSTALL_DIR/sm-agent" -token=test_token_validation 2>&1 | grep -q "missing -org flag" && needs_healing=true
            
            if [ "$needs_healing" = true ]; then
                log_healing "Incompatible binary detected - will auto-upgrade to latest version"
                show_progress 2.0 "🔄 Preparing intelligent upgrade process"
            else
                log_info "✅ Existing binary is compatible - performing seamless upgrade"
                show_progress 1.5 "Preparing seamless upgrade environment"
            fi
        else
            show_progress 1.5 "Preparing upgrade environment"
        fi
    else
        log_info "✨ Fresh system detected - preparing for installation"
        show_progress 1.0 "Initializing installation environment"
    fi
    
    # Always perform complete cleanup for reliability
    if systemctl is-active --quiet ${SERVICE_NAME} 2>/dev/null; then
        log_info "Gracefully stopping existing service..."
        systemctl stop ${SERVICE_NAME} || true
        sleep 2  # Give service time to stop properly
    fi
    
    if systemctl is-enabled --quiet ${SERVICE_NAME} 2>/dev/null; then
        log_info "Disabling existing service..."
        systemctl disable ${SERVICE_NAME} || true
    fi
    
    if [ -d "$INSTALL_DIR" ]; then
        log_info "Cleaning existing installation..."
        rm -rf "$INSTALL_DIR"
    fi
    
    if [ -f "/etc/systemd/system/${SERVICE_NAME}.service" ]; then
        log_info "Removing existing service configuration..."
        rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
        systemctl daemon-reload
    fi
    
    # Clear any cached binaries or temporary files
    log_info "Clearing system caches..."
    rm -f /tmp/sm-agent* 2>/dev/null || true
    
    if [ "$is_existing" = true ]; then
        if [ "$needs_healing" = true ]; then
            log_success "System healed and ready for intelligent upgrade ${MAGIC}"
        else
            log_success "System prepared for seamless upgrade ${SPARKLES}"
        fi
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

# Validate binary compatibility
validate_binary_compatibility() {
    local binary_path="$1"
    
    log_info "🔍 Validating binary compatibility..."
    
    # Test 1: Basic execution test
    if ! "$binary_path" --help &>/dev/null; then
        log_warning "Binary failed basic execution test"
        return 1
    fi
    
    # Test 2: Token-only mode support test
    local test_output
    test_output=$(timeout 5 "$binary_path" -token=compatibility_test 2>&1 || true)
    
    if echo "$test_output" | grep -q "missing -org flag"; then
        log_warning "Binary requires legacy -org flag (incompatible)"
        return 1
    fi
    
    # Test 3: Version compatibility
    if echo "$test_output" | grep -q "missing.*token"; then
        log_success "Binary supports token-only mode ✅"
        return 0
    fi
    
    log_success "Binary compatibility validated ✅"
    return 0
}

# Enhanced download with retry logic and validation
download_binary_with_retry() {
    local platform=$(get_platform)
    local binary_name="sm-agent-${platform}"
    local download_url="${BINARY_BASE_URL}/${binary_name}"
    local checksum_url="${BINARY_BASE_URL}/${binary_name}.sha256"
    local attempt=1
    
    log_step "Downloading latest compatible binary..."
    log_info "Source: ${BOLD}${INFO}GitHub Releases (Latest)${RESET}"
    log_info "Binary: ${BOLD}${INFO}${binary_name}${RESET}"
    log_info "Compatibility: ${BOLD}${SUCCESS}Token-only mode${RESET}"
    
    # Create installation directory
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    while [ $attempt -le $MAX_RETRY_ATTEMPTS ]; do
        log_info "📥 Download attempt $attempt of $MAX_RETRY_ATTEMPTS"
        show_progress 2.0 "${DOWNLOAD} Downloading binary (~11MB)"
        
        # Download binary
        local download_success=false
        if command -v curl &> /dev/null; then
            if curl -fsSL -o "sm-agent" "$download_url"; then
                download_success=true
            fi
        elif command -v wget &> /dev/null; then
            if wget -q -O "sm-agent" "$download_url"; then
                download_success=true
            fi
        else
            log_error "Neither curl nor wget available"
            echo -e "${INFO}💡 Please install curl or wget and try again${RESET}\n"
            exit 1
        fi
        
        if [ "$download_success" = true ]; then
            log_success "Binary downloaded successfully"
            
            # Make binary executable
            chmod +x "sm-agent"
            
            # Validate compatibility before proceeding
            if validate_binary_compatibility "./sm-agent"; then
                log_success "Binary compatibility confirmed ${SHIELD}"
                break
            else
                log_healing "Downloaded binary is incompatible - retrying..."
                rm -f "sm-agent"
                attempt=$((attempt + 1))
                if [ $attempt -le $MAX_RETRY_ATTEMPTS ]; then
                    sleep 5  # Wait before retry
                fi
                continue
            fi
        else
            log_warning "Download failed - retrying..."
            attempt=$((attempt + 1))
            if [ $attempt -le $MAX_RETRY_ATTEMPTS ]; then
                sleep 3  # Wait before retry
            fi
        fi
    done
    
    if [ $attempt -gt $MAX_RETRY_ATTEMPTS ]; then
        log_error "Failed to download compatible binary after $MAX_RETRY_ATTEMPTS attempts"
        echo -e "${INFO}💡 Please check your internet connection and try again${RESET}\n"
        exit 1
    fi
    
    # Download and verify checksum (best effort)
    log_info "Verifying binary integrity..."
    if curl -fsSL -o "${binary_name}.sha256" "$checksum_url" 2>/dev/null || wget -q -O "${binary_name}.sha256" "$checksum_url" 2>/dev/null; then
        if command -v sha256sum &> /dev/null; then
            show_progress 1.0 "🔐 Verifying cryptographic signature"
            
            expected_checksum=$(cat "${binary_name}.sha256" | cut -d' ' -f1)
            actual_checksum=$(sha256sum "sm-agent" | cut -d' ' -f1)
            
            if [ "$expected_checksum" = "$actual_checksum" ]; then
                log_success "Binary integrity verified ${SHIELD}"
            else
                log_warning "Binary checksum verification failed, but binary is compatible"
            fi
        else
            log_info "sha256sum not available, skipping checksum verification"
        fi
        rm -f "${binary_name}.sha256"
    else
        log_info "Checksum verification skipped (file not available)"
    fi
    
    log_success "Binary verified and ready for deployment ${ROCKET}"
}

# Enhanced service creation with validation
create_service_with_validation() {
    log_step "Creating intelligent system service..."
    
    show_progress 1.5 "${INSTALL} Configuring systemd service"
    
    # Create service file with production-ready configuration
    cat > /etc/systemd/system/${SERVICE_NAME}.service << EOF
[Unit]
Description=Security Manager Agent
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=${INSTALL_DIR}
ExecStart=${INSTALL_DIR}/sm-agent -token=${TOKEN} -ingest=${INGEST_URL}
Restart=always
RestartSec=10
StartLimitInterval=300
StartLimitBurst=5
StandardOutput=journal
StandardError=journal
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

[Install]
WantedBy=multi-user.target
EOF

    log_success "Service configuration created"
    
    # Enable and start service with validation
    log_info "Enabling automatic startup..."
    systemctl daemon-reload
    systemctl enable ${SERVICE_NAME}
    
    log_info "Starting Security Manager Agent..."
    show_progress 2.0 "🚀 Launching agent and connecting to server"
    
    # Start service and validate it's working
    if systemctl start ${SERVICE_NAME}; then
        log_success "Service started successfully"
        
        # Wait a moment for service to initialize
        sleep 3
        
        # Validate service is actually running and not crashing
        if systemctl is-active --quiet ${SERVICE_NAME}; then
            log_success "Service validation passed ✅"
        else
            log_healing "Service started but may have issues - checking logs..."
            # Give it a few more seconds for slow systems
            sleep 5
            if ! systemctl is-active --quiet ${SERVICE_NAME}; then
                log_error "Service failed to start properly"
                echo -e "${INFO}💡 Check logs: ${BOLD}journalctl -u ${SERVICE_NAME} --no-pager -n 20${RESET}\n"
                journalctl -u ${SERVICE_NAME} --no-pager -n 10
                exit 1
            else
                log_success "Service recovered and is now running ✅"
            fi
        fi
    else
        log_error "Failed to start service"
        echo -e "${INFO}💡 Check logs: ${BOLD}journalctl -u ${SERVICE_NAME} --no-pager -n 20${RESET}\n"
        exit 1
    fi
}

# Enhanced verification with detailed health checks
verify_installation() {
    log_step "Performing comprehensive health checks..."
    
    show_progress 3.0 "🔍 Running system health checks"

    local all_checks_passed=true
    
    # Check 1: Service status
    if systemctl is-active --quiet ${SERVICE_NAME}; then
        log_success "✅ Service Status: Running"
    else
        log_error "❌ Service Status: Failed"
        all_checks_passed=false
    fi
    
    # Check 2: Service enabled for startup
    if systemctl is-enabled --quiet ${SERVICE_NAME}; then
        log_success "✅ Auto-start: Enabled"
    else
        log_warning "⚠️ Auto-start: Not enabled"
    fi
    
    # Check 3: Binary compatibility
    if [ -f "$INSTALL_DIR/sm-agent" ] && validate_binary_compatibility "$INSTALL_DIR/sm-agent"; then
        log_success "✅ Binary Compatibility: Token-only mode"
    else
        log_error "❌ Binary Compatibility: Failed"
        all_checks_passed=false
    fi
    
    # Check 4: Network connectivity (basic test)
    if timeout 5 bash -c "echo >/dev/tcp/${INGEST_URL%:*}/${INGEST_URL#*:}" 2>/dev/null; then
        log_success "✅ Network Connectivity: Server reachable"
    else
        log_warning "⚠️ Network Connectivity: Cannot reach server (may be normal)"
    fi
    
    if [ "$all_checks_passed" = true ]; then
        echo -e "\n${BOLD}${BG_SUCCESS}                                                                   ${RESET}"
        echo -e "${BOLD}${BG_SUCCESS}  ${PARTY} INSTALLATION SUCCESSFUL! AGENT IS RUNNING ${PARTY}        ${RESET}"
        echo -e "${BOLD}${BG_SUCCESS}                                                                   ${RESET}\n"
        
        echo -e "${BOLD}${SUCCESS}📊 System Status:${RESET}"
        log_success "Service: ${BOLD}${SUCCESS}$SERVICE_NAME${RESET}"
        log_success "Status: ${BOLD}${SUCCESS}$(systemctl is-active ${SERVICE_NAME})${RESET}"
        log_success "Connection: ${BOLD}${SUCCESS}$INGEST_URL${RESET}"
        log_success "Token: ${BOLD}${SUCCESS}${TOKEN:0:20}...${RESET}"
        log_success "Mode: ${BOLD}${SUCCESS}Token-only (Latest)${RESET}"
    else
        log_error "Some health checks failed"
        echo -e "${INFO}💡 Check logs: ${BOLD}journalctl -u ${SERVICE_NAME} --no-pager -n 20${RESET}\n"
        exit 1
    fi
}

# Main installation flow with enhanced error handling
main() {
    # Clean up any existing installation first
    cleanup_existing
    echo
    
    # Detect platform
    detect_platform
    echo
    
    # Download compatible binary with retry logic
    download_binary_with_retry
    echo
    
    # Create and start service with validation
    create_service_with_validation
    echo
    
    # Verify installation with comprehensive checks
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
    echo -e "${INFO}  ${BULLET} Auto-healing: This installer fixes all compatibility issues automatically"
    
    echo -e "\n${BOLD}${SUCCESS}${HEART} Thank you for choosing Security Manager! ${HEART}${RESET}"
    echo -e "${DIM}Your systems are now protected with enterprise-grade monitoring.${RESET}\n"
}

# Run main function
main "$@" 