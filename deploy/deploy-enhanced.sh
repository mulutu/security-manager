#!/bin/bash

# Security Manager v1.0.7 Enhanced Deployment Script
# Auto-registration with PostgreSQL integration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Default values
TYPE="services"
PROJECT_DIR="/opt/security-manager"
SERVICE_USER="security-manager"
POSTGRES_DB="security_manager"
POSTGRES_USER="security_manager"
POSTGRES_PASSWORD=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --type)
            TYPE="$2"
            shift 2
            ;;
        --project-dir)
            PROJECT_DIR="$2"
            shift 2
            ;;
        --postgres-password)
            POSTGRES_PASSWORD="$2"
            shift 2
            ;;
        -h|--help)
            echo "Security Manager v1.0.7 Enhanced Deployment"
            echo ""
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --type TYPE                 Deployment type (services, update, full) [default: services]"
            echo "  --project-dir DIR          Project directory [default: /opt/security-manager]"
            echo "  --postgres-password PASS   PostgreSQL password (will prompt if not provided)"
            echo "  -h, --help                 Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 --type services                    # Update services only"
            echo "  $0 --type update                      # Update code and restart"
            echo "  $0 --type full                        # Full deployment with dependencies"
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root (use sudo)"
fi

log "🚀 Starting Security Manager v1.0.7 Enhanced Deployment"
log "Type: $TYPE"
log "Project Directory: $PROJECT_DIR"

# Function to check if PostgreSQL is running
check_postgres() {
    log "🔍 Checking PostgreSQL status..."
    if systemctl is-active --quiet postgresql; then
        log "✅ PostgreSQL is running"
        return 0
    else
        warn "PostgreSQL is not running"
        return 1
    fi
}

# Function to setup PostgreSQL database
setup_postgres() {
    log "🗄️  Setting up PostgreSQL database..."
    
    if ! check_postgres; then
        log "📦 Installing PostgreSQL..."
        apt-get update
        apt-get install -y postgresql postgresql-contrib
        systemctl start postgresql
        systemctl enable postgresql
    fi
    
    # Get PostgreSQL password if not provided
    if [[ -z "$POSTGRES_PASSWORD" ]]; then
        echo -n "Enter PostgreSQL password for user '$POSTGRES_USER': "
        read -s POSTGRES_PASSWORD
        echo
    fi
    
    # Create database and user
    log "🔧 Creating database and user..."
    sudo -u postgres psql -c "CREATE DATABASE $POSTGRES_DB;" 2>/dev/null || true
    sudo -u postgres psql -c "CREATE USER $POSTGRES_USER WITH PASSWORD '$POSTGRES_PASSWORD';" 2>/dev/null || true
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $POSTGRES_DB TO $POSTGRES_USER;" 2>/dev/null || true
    sudo -u postgres psql -c "ALTER USER $POSTGRES_USER CREATEDB;" 2>/dev/null || true
    
    log "✅ PostgreSQL setup complete"
}

# Function to install Go if needed
install_go() {
    if command -v go &> /dev/null; then
        log "✅ Go is already installed ($(go version))"
        return 0
    fi
    
    log "📦 Installing Go..."
    GO_VERSION="1.21.5"
    cd /tmp
    wget -q "https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz"
    tar -C /usr/local -xzf "go${GO_VERSION}.linux-amd64.tar.gz"
    
    # Add Go to PATH
    echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
    export PATH=$PATH:/usr/local/go/bin
    
    log "✅ Go installed successfully"
}

# Function to create system user
create_user() {
    if id "$SERVICE_USER" &>/dev/null; then
        log "✅ User $SERVICE_USER already exists"
    else
        log "👤 Creating system user $SERVICE_USER..."
        useradd --system --shell /bin/false --home-dir /var/lib/security-manager --create-home $SERVICE_USER
    fi
}

# Function to setup project directory
setup_project() {
    log "📁 Setting up project directory..."
    
    if [[ -d "$PROJECT_DIR" ]]; then
        log "📂 Project directory exists, updating..."
        cd "$PROJECT_DIR"
        git pull origin main
    else
        log "📂 Cloning project..."
        mkdir -p "$(dirname "$PROJECT_DIR")"
        git clone https://github.com/mulutu/security-manager.git "$PROJECT_DIR"
        cd "$PROJECT_DIR"
    fi
    
    # Set ownership
    chown -R $SERVICE_USER:$SERVICE_USER "$PROJECT_DIR"
    
    log "✅ Project setup complete"
}

# Function to build services
build_services() {
    log "🔨 Building services..."
    cd "$PROJECT_DIR"
    
    # Build ingest server
    log "Building ingest server..."
    sudo -u $SERVICE_USER /usr/local/go/bin/go build -o ingest ./cmd/ingest
    
    # Build agent (for local testing)
    log "Building agent..."
    sudo -u $SERVICE_USER /usr/local/go/bin/go build -o agent ./cmd/agent
    
    # Set permissions
    chmod +x ingest agent
    
    log "✅ Build complete"
}

# Function to create systemd service
create_systemd_service() {
    log "🔧 Creating systemd service..."
    
    cat > /etc/systemd/system/security-manager-ingest.service << EOF
[Unit]
Description=Security Manager Ingest Server v1.0.7
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$PROJECT_DIR
ExecStart=$PROJECT_DIR/ingest
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

# Environment variables
Environment=DATABASE_URL=postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@localhost:5432/$POSTGRES_DB
Environment=DB_HOST=localhost
Environment=DB_PORT=5432
Environment=DB_USER=$POSTGRES_USER
Environment=DB_PASSWORD=$POSTGRES_PASSWORD
Environment=DB_NAME=$POSTGRES_DB

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$PROJECT_DIR

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    log "✅ Systemd service created"
}

# Function to start services
start_services() {
    log "🚀 Starting services..."
    
    systemctl enable security-manager-ingest
    systemctl restart security-manager-ingest
    
    # Wait a moment and check status
    sleep 3
    if systemctl is-active --quiet security-manager-ingest; then
        log "✅ Security Manager Ingest Server is running"
    else
        error "❌ Failed to start Security Manager Ingest Server"
    fi
}

# Function to show status
show_status() {
    log "📊 Service Status:"
    echo ""
    systemctl status security-manager-ingest --no-pager -l
    echo ""
    log "🔗 Service is listening on port 9002"
    log "🗄️  Database: postgresql://$POSTGRES_USER:***@localhost:5432/$POSTGRES_DB"
    echo ""
    log "✅ Security Manager v1.0.7 deployment complete!"
    echo ""
    log "🎯 New Features Available:"
    log "   • Auto-registration of agents"
    log "   • PostgreSQL integration"
    log "   • Enhanced system detection"
    log "   • One-click server addition in dashboard"
    echo ""
    log "📝 Next Steps:"
    log "   1. Access your dashboard and click 'Add Server'"
    log "   2. Copy the generated curl command"
    log "   3. Run on any server to auto-register agents"
    echo ""
}

# Main deployment logic
case $TYPE in
    "services"|"update")
        log "🔄 Updating Security Manager services..."
        setup_project
        build_services
        if [[ "$TYPE" == "services" ]]; then
            start_services
            show_status
        fi
        ;;
    "full")
        log "🚀 Full Security Manager deployment..."
        install_go
        create_user
        setup_postgres
        setup_project
        build_services
        create_systemd_service
        start_services
        show_status
        ;;
    *)
        error "Unknown deployment type: $TYPE"
        ;;
esac

log "🎉 Deployment completed successfully!" 