#!/bin/bash

# Security Manager - Linux Agent Deployment
# This script deploys the Security Manager agent on a Linux system
# Usage: curl -fsSL https://raw.githubusercontent.com/mulutu/security-manager/main/deploy/linux-agent.sh | sudo bash

set -e

# Configuration
INGEST_URL="${SM_INGEST_URL:-178.79.139.38:9002}"
ORG_ID="${SM_ORG_ID:-demo}"
TOKEN="${SM_TOKEN:-sm_tok_demo123}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}🛡️  Security Manager - Linux Agent Deployment${NC}"
echo -e "${YELLOW}   Target: $(hostname)${NC}"
echo -e "${YELLOW}   Ingest URL: $INGEST_URL${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ This script must be run as root (use sudo)${NC}"
   exit 1
fi

# Use the official installer
echo -e "${BLUE}📥 Running official installer...${NC}"
export SM_ORG_ID="$ORG_ID"
export SM_TOKEN="$TOKEN"
export SM_INGEST_URL="$INGEST_URL"

curl -fsSL https://raw.githubusercontent.com/mulutu/security-manager/main/installer/install-linux.sh | bash

echo -e "${GREEN}✅ Agent deployed successfully!${NC}"
echo ""
echo -e "${BLUE}🔧 Management Commands:${NC}"
echo "  Status: sudo systemctl status security-manager-agent"
echo "  Logs:   sudo journalctl -u security-manager-agent -f"
echo "  Stop:   sudo systemctl stop security-manager-agent"
echo "  Start:  sudo systemctl start security-manager-agent" 