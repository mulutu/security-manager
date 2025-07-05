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

# Ensure we have the most compatible versions
log_info "Updating dependencies for maximum compatibility..."
cat > go.mod << EOF
module github.com/mulutu/security-manager

go 1.18

require (
	github.com/ClickHouse/clickhouse-go/v2 v2.5.1
	github.com/nats-io/nats.go v1.25.0
	google.golang.org/grpc v1.53.0
	google.golang.org/protobuf v1.28.1
)

require (
	github.com/ClickHouse/ch-go v0.51.0 // indirect
	github.com/andybalholm/brotli v1.0.4 // indirect
	github.com/go-faster/city v1.0.1 // indirect
	github.com/go-faster/errors v0.6.1 // indirect
	github.com/golang/protobuf v1.5.2 // indirect
	github.com/google/uuid v1.3.0 // indirect
	github.com/klauspost/compress v1.16.5 // indirect
	github.com/nats-io/nkeys v0.4.4 // indirect
	github.com/nats-io/nuid v1.0.1 // indirect
	github.com/paulmach/orb v0.8.0 // indirect
	github.com/pierrec/lz4/v4 v4.1.17 // indirect
	github.com/pkg/errors v0.9.1 // indirect
	github.com/segmentio/asm v1.2.0 // indirect
	github.com/shopspring/decimal v1.3.1 // indirect
	go.opentelemetry.io/otel v1.11.2 // indirect
	go.opentelemetry.io/otel/trace v1.11.2 // indirect
	golang.org/x/crypto v0.6.0 // indirect
	golang.org/x/net v0.6.0 // indirect
	golang.org/x/sys v0.5.0 // indirect
	golang.org/x/text v0.7.0 // indirect
	google.golang.org/genproto v0.0.0-20230110181048-76db0878b65f // indirect
	gopkg.in/yaml.v3 v3.0.1 // indirect
)
EOF

# Create a locked go.sum file to prevent any upgrades
cat > go.sum << 'EOF'
github.com/ClickHouse/ch-go v0.51.0 h1:GxkDUKMvlXwMqBhKs1eP3/5nlc7g6xfWUdOjKhxbqFE=
github.com/ClickHouse/ch-go v0.51.0/go.mod h1:CnBbdX1AJOmHLfYIGzwZoSzC/mEUz9VjP8jJMWKWBnE=
github.com/ClickHouse/clickhouse-go/v2 v2.5.1 h1:FjjjKCXDJQhgfKkUi5IlWgVjHDGXJEAkRKKNqQGMsVs=
github.com/ClickHouse/clickhouse-go/v2 v2.5.1/go.mod h1:5TBrOWgGJOZIHTvctT8CzQGCMJWGBQgAa0VjCU1xKpE=
github.com/andybalholm/brotli v1.0.4 h1:V7DdXeJtZscaqfNuAdSRuRFzuiKlHSC/Zh3zl9qY3JY=
github.com/andybalholm/brotli v1.0.4/go.mod h1:fO7iG3H7G2nSZ7m0zPUDn85XEX2GTukHGRSepvi9Eig=
github.com/davecgh/go-spew v1.1.0/go.mod h1:J7Y8YcW2NihsgmVo/mv3lAwl/skON4iLHjSsI+c5H38=
github.com/davecgh/go-spew v1.1.1 h1:vj9j/u1bqnvCEfJOwUhtlOARqs3+rkHYY13jYWTU97c=
github.com/davecgh/go-spew v1.1.1/go.mod h1:J7Y8YcW2NihsgmVo/mv3lAwl/skON4iLHjSsI+c5H38=
github.com/go-faster/city v1.0.1 h1:4WAxSZ3V2Ws4QRDrscLEDcibJY8uf41H6AhXDrNDcGw=
github.com/go-faster/city v1.0.1/go.mod h1:jKcUJId49qdW3L1qKHH/3wPeUstCVpVSXTM6vO3VcTw=
github.com/go-faster/errors v0.6.1 h1:nNIPOBkprlKzkThvS/0YaX8Zs9KewLCOSFQS5BU06FI=
github.com/go-faster/errors v0.6.1/go.mod h1:5MGV2/2T9yvlrbhe9pD9LO5Z/2zCSq2T8j+Jpi2LAyY=
github.com/golang/protobuf v1.5.0/go.mod h1:FsONVRAS9T7sI+LIUmWTfcYkHO4aIWwzhcaSAoJOfIk=
github.com/golang/protobuf v1.5.2 h1:ROPKBNFfQgOUMifHyP+KYbvpjbdoFNs+aK7DXlji0Tw=
github.com/golang/protobuf v1.5.2/go.mod h1:XVQd3VNwM+JqD3oG2Ue2ip4fOMUkwXdXDdiuN0vRsmY=
github.com/google/go-cmp v0.5.5/go.mod h1:v8dTdLbMG2kIc/vJvl+7+oU4LdXWs0MN6BYjqYQu6+s=
github.com/google/go-cmp v0.5.9 h1:O2Tfq5qg4qc4AmwVlvv0oLiVAGB7enBSJ2x2DqQFi38=
github.com/google/go-cmp v0.5.9/go.mod h1:17dUlkBOakJ0+DkrSSNjCkIjxS6bF9zb3elmeNGIjoY=
github.com/google/uuid v1.3.0 h1:t6JiXuUQJ+/3MHpbgTcfnZZJqBDGSJWsGvWJHJqg3YY=
github.com/google/uuid v1.3.0/go.mod h1:TIyPZe4MgqvfeYDBFedMoGGpEw/LqOeaOT+nhxU+yHo=
github.com/klauspost/compress v1.16.5 h1:IFV2oUNUzZaz+XyusxpLzpzS8Pt5rh0Z16For/djlyI=
github.com/klauspost/compress v1.16.5/go.mod h1:ntbaceVETuRiXiv4DpjP66DpAtAGkEQskQzEyD//IeE=
github.com/nats-io/nats.go v1.25.0 h1:t5ioC5QRVX4XHwjrKhNNp8T3dDTnrgJdCKKm1zuCE1s=
github.com/nats-io/nats.go v1.25.0/go.mod h1:XpbWUlOElGwTYbMR7imivs7jJj9GtK7ypv321Wp6pjc=
github.com/nats-io/nkeys v0.4.4 h1:xvBJ8d69TznjcQl9t6//Q5xXuVhyYiSos6RPtvQNTwk=
github.com/nats-io/nkeys v0.4.4/go.mod h1:XUkxdLPTufzlihbamfzQ7mw/VGx6ObUs+0bN5sNvt64=
github.com/nats-io/nuid v1.0.1 h1:5iA8DT8V7q8WK2EScv2padNa/rTESc1KdnPw4TC2paw=
github.com/nats-io/nuid v1.0.1/go.mod h1:19wcPz3Ph3q0Jbyiqsd0kePYG7A95tJPxeL+1OSON2c=
github.com/paulmach/orb v0.8.0 h1:Ral6IXZH8aOLQqKHvhKZLGKMWyJqDgxHWNV0mhpOJBE=
github.com/paulmach/orb v0.8.0/go.mod h1:9nuiUCPWbdZFrjCBT8xG8qONyLGOgQhOCKD9vZFIgCg=
github.com/pierrec/lz4/v4 v4.1.17 h1:kV4Ip+/hUBC+8T6+2EgburRtkE9ef4nbY3f4dFhGjMc=
github.com/pierrec/lz4/v4 v4.1.17/go.mod h1:gZWDp/Ze/IJXGXf23ltt2EXimqmTUXEy0GFuRQyBid4=
github.com/pkg/errors v0.9.1 h1:FEBLx1zS214owpjy7qsBeixbURkuhQAwrK5UwLGTwt4=
github.com/pkg/errors v0.9.1/go.mod h1:bwawxfHBFNV+L2hUp1rHADufV3IMtnDRdf1r5NINEl0=
github.com/pmezard/go-difflib v1.0.0 h1:4DBwDE0NGyQoBHbLQYPwSUPoCMWR5BEzIk/f1lZbAQM=
github.com/pmezard/go-difflib v1.0.0/go.mod h1:iKH77koFhYxTK1pcRnkKkqfTogsbg7gZNVY4sRDYZ/4=
github.com/segmentio/asm v1.2.0 h1:9BQrFxC+YOHJlTlHGkTrFWf59nbL3XnCoFLTwDCI7ys=
github.com/segmentio/asm v1.2.0/go.mod h1:BqMnlJP91P8d+4ibuonYZw9mfnzI9HfxselHZr5aAcs=
github.com/shopspring/decimal v1.3.1 h1:2Usl1nmF/WZucqkFZhnfFYxxxu8LG21F6nPQBE5gKV8=
github.com/shopspring/decimal v1.3.1/go.mod h1:DKyhrW/HYNuLGql+MJL6WCR6knT2jwCFRcu2hWP1vRM=
github.com/stretchr/objx v0.1.0/go.mod h1:HFkY916IF+rwdDfMAkV7OtwuqBVzrE8GR6GFx+wExME=
github.com/stretchr/objx v0.4.0/go.mod h1:YvHI0jy2hoMjB+UWwv71VJQ9isScKT/TqJzVSSt89Yw=
github.com/stretchr/objx v0.5.0/go.mod h1:Yh+to48EsGEfYuaHDzXPcE3xhTkx73EhmCGUpEOglKo=
github.com/stretchr/testify v1.7.1/go.mod h1:6Fq8oRcR53rry900zMqJjRRixrwX3KX962/h/Wwjteg=
github.com/stretchr/testify v1.8.0/go.mod h1:yNjHg4UonilssWZ8iaSj1OCr/vHnekPRkoO+kdMU+MU=
github.com/stretchr/testify v1.8.1 h1:w7B6lhMri9wdJUVmEZPGGhZzrYTPvgJArz7wNPgYKsk=
github.com/stretchr/testify v1.8.1/go.mod h1:w2LPCIKwWwSfY2zedu0+kehJoqGctiVI29o6fzry7u4=
go.opentelemetry.io/otel v1.11.2 h1:YBZcQlsVekzFsFbjygXMOXSs6pialIZxcjfO/mBDmR0=
go.opentelemetry.io/otel v1.11.2/go.mod h1:7p4EUV+AqgdlNV9gL97IgUZiVR3yrFXYo53f9BM3tRI=
go.opentelemetry.io/otel/trace v1.11.2 h1:Xf7hWSF2Glv0DE3MH7fBHvtpSBsjcBUe5MYAmZM/+y0=
go.opentelemetry.io/otel/trace v1.11.2/go.mod h1:4N+yC7QEz7TTsG9BSRLNAa63eg5E06ObSbKPmxQ/pKA=
golang.org/x/crypto v0.6.0 h1:qfktjS5LUO+fFKeJXZ+ikTRijMmljikvG68fpMMruSc=
golang.org/x/crypto v0.6.0/go.mod h1:OFC/31mSvZgRz0V1QTNCzfAI1aIRzbiufJtkMIlEp58=
golang.org/x/net v0.5.0/go.mod h1:DivGGAXEgPSlEBzxGzZI+ZLohi+xUj054jfeKui00ws=
golang.org/x/net v0.6.0 h1:L4ZwwTvKW9gr0ZMS1yrHD9GZhIuVjOBBnaKH+SPQK0Q=
golang.org/x/net v0.6.0/go.mod h1:2Tu9+aMcznHK/AK1HMvgo6xiTLG5rD5rZLDS+rp2Bjs=
golang.org/x/sys v0.5.0 h1:MUK/U/4lj1t1oPg0HfuXDN/Z1wv31ZJ/YcPiGccS4DU=
golang.org/x/sys v0.5.0/go.mod h1:oPkhp1MJrh7nUepCBck5+mAzfO9JrbApNNgaTdGDITg=
golang.org/x/text v0.7.0 h1:4BRB4x83lYWy72KwLD/qYDuTu7q9PjSagHvijDw7cLo=
golang.org/x/text v0.7.0/go.mod h1:mrYo+phRRbMaCq/xk9113O4dZlRixOauAjOtrjsXDZ8=
golang.org/x/xerrors v0.0.0-20191204190536-9bdfabe68543/go.mod h1:I/5z698sn9Ka8TeJc9MKroUUfqBBauWjQqLJ2OPfmY0=
google.golang.org/genproto v0.0.0-20230110181048-76db0878b65f h1:BWUVssLB0HVOSY78gIdvk1dTVYtT1y8SBWtPYuTJ/6w=
google.golang.org/genproto v0.0.0-20230110181048-76db0878b65f/go.mod h1:RGgjbofJ8xD9Sq1VVhDM1Vok1vRONV+rg+CjzG4SZKM=
google.golang.org/grpc v1.53.0 h1:LAv2ds7cmFV/XTS3XG1NneeENYrXGmorPxsBbptIjNc=
google.golang.org/grpc v1.53.0/go.mod h1:OnIrk0ipVdj4N5d9IUoFUx72/VlD7+jUsHwZgwSMQpw=
google.golang.org/protobuf v1.26.0-rc.1/go.mod h1:jlhhOSvTdKEhbULTjvd4ARK9grFBp09yW+WbY/TyQbw=
google.golang.org/protobuf v1.28.1 h1:d0NfwRgPtno5B1Wa6L2DAG+KdPLiMfJGNwLCUUPsksE=
google.golang.org/protobuf v1.28.1/go.mod h1:HV8QOd/L58Z+nl8r43ehVNZIU/HEI6OcFqwMG9pJV4I=
gopkg.in/check.v1 v0.0.0-20161208181325-20d25e280405 h1:yhCVgyC4o1eVCa2tZl7eS0r+SDo693bJlVdllGtEeKM=
gopkg.in/check.v1 v0.0.0-20161208181325-20d25e280405/go.mod h1:Co6ibVJAznAaIkqp8huTwlJQCZ016jof/cbN4VW5Yz0=
gopkg.in/yaml.v3 v3.0.0-20200313102051-9f266ea9e77c/go.mod h1:K4uyk7z7BCEPqu6E+C64Yfv1cQ7kz7rIZviUmN+EgEM=
gopkg.in/yaml.v3 v3.0.1 h1:fxVm/GzAzEWqLHuvctI91KS9hhNmmWOoWu0XTYJS7CA=
gopkg.in/yaml.v3 v3.0.1/go.mod h1:K4uyk7z7BCEPqu6E+C64Yfv1cQ7kz7rIZviUmN+EgEM=
EOF

# Build the agent
log_info "Building agent..."
cd cmd/agent

# Prevent Go from upgrading dependencies during build
export GOPROXY=direct
export GOSUMDB=off
export GO111MODULE=on
export GOFLAGS="-mod=readonly"

# Verify our locked dependencies are being used
log_info "Verifying dependency versions..."
go list -m all | grep golang.org/x/sys

go build -o "$INSTALL_DIR/sm-agent" .

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