#!/bin/bash

# Linux Agent Setup Script for Security Manager  
# Run this on your Linux VM (178.79.136.143) to connect to the remote ingest service

set -e

# Configuration
INGEST_URL="${SM_INGEST_URL:-178.79.139.38:9002}"
ORG_ID="${SM_ORG_ID:-demo}"
TOKEN="${SM_TOKEN:-sm_tok_demo123}"
HOST_ID="${SM_HOST_ID:-$(hostname)}"
LOG_FILE="${SM_LOG_FILE:-/tmp/sm-test.log}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔧 Security Manager Linux Agent Setup${NC}"
echo -e "${YELLOW}Connecting to: $INGEST_URL${NC}"

# Check if Go is installed
if ! command -v go &> /dev/null; then
    echo -e "${RED}❌ Go not found. Installing Go...${NC}"
    
    # Install Go
    GO_VERSION="1.21.5"
    wget -q "https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz"
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf "go${GO_VERSION}.linux-amd64.tar.gz"
    rm "go${GO_VERSION}.linux-amd64.tar.gz"
    
    # Add Go to PATH
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
    export PATH=$PATH:/usr/local/go/bin
    
    echo -e "${GREEN}✅ Go installed successfully${NC}"
fi

# Get the project (if not already present)
if [ ! -d "security-manager" ]; then
    echo -e "${BLUE}📥 Cloning project from GitHub...${NC}"
    git clone https://github.com/mulutu/security-manager.git
    cd security-manager
else
    echo -e "${BLUE}📥 Updating existing repository...${NC}"
    cd security-manager
    git pull origin main
fi

# Build the agent
echo -e "${BLUE}🏗️  Building Linux agent...${NC}"
cd cmd/agent
go build -o ../../sm-agent .
cd ../..

if [ -f "sm-agent" ]; then
    echo -e "${GREEN}✅ Agent built successfully: sm-agent${NC}"
    chmod +x sm-agent
else
    echo -e "${RED}❌ Build failed${NC}"
    exit 1
fi

# Test connection
echo -e "${BLUE}🧪 Testing connection to remote ingest service...${NC}"
cd tools/test_auth
SM_INGEST_URL="$INGEST_URL" go run main.go
cd ../..

# Create test log file and add entries
echo -e "${BLUE}📝 Creating test log file: $LOG_FILE${NC}"
echo "Test log entry from Linux agent at $(date)" > "$LOG_FILE"

# Start background log generator
echo -e "${BLUE}🔄 Starting background log generator...${NC}"
(
    while true; do
        echo "Linux test log entry at $(date)" >> "$LOG_FILE"
        echo "System info: $(uname -a)" >> "$LOG_FILE"
        echo "Memory usage: $(free -h | grep Mem:)" >> "$LOG_FILE"
        echo "---" >> "$LOG_FILE"
        sleep 30
    done
) &
LOG_GENERATOR_PID=$!

# Function to cleanup on exit
cleanup() {
    echo -e "\n${RED}🛑 Stopping agent and log generator...${NC}"
    kill $LOG_GENERATOR_PID 2>/dev/null || true
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Start the agent
echo -e "${GREEN}🚀 Starting Linux agent...${NC}"
echo -e "${GRAY}   Org ID: $ORG_ID${NC}"
echo -e "${GRAY}   Host ID: $HOST_ID${NC}"
echo -e "${GRAY}   Ingest URL: $INGEST_URL${NC}"
echo -e "${GRAY}   Log File: $LOG_FILE${NC}"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop the agent${NC}"
echo ""

# Run the agent
./sm-agent -org "$ORG_ID" -token "$TOKEN" -host "$HOST_ID" -ingest "$INGEST_URL" -file "$LOG_FILE"

cleanup 