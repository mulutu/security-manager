#!/bin/bash

# Deployment script for Security Manager on remote VM (178.79.139.38)
# Run this script on the remote VM to set up the services

set -e

echo "🚀 Deploying Security Manager to remote VM..."

# Clone or update the repository
if [ -d "security-manager" ]; then
    echo "📥 Updating existing repository..."
    cd security-manager
    git pull origin main
    cd ..
else
    echo "📥 Cloning repository from GitHub..."
    git clone https://github.com/mulutu/security-manager.git
fi

# Navigate to the project directory
cd security-manager/deploy

# Create necessary directories
mkdir -p logs ssl

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found. Please install Docker first:"
    echo "   curl -fsSL https://get.docker.com | sh"
    echo "   sudo usermod -aG docker $USER"
    echo "   sudo systemctl enable docker"
    echo "   sudo systemctl start docker"
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose not found. Installing..."
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

# Stop any existing containers
echo "🛑 Stopping existing containers..."
docker-compose -f docker-compose.prod.yml down || true

# Build and start services
echo "🏗️  Building and starting services..."
docker-compose -f docker-compose.prod.yml up --build -d

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 10

# Check service status
echo "📊 Service status:"
docker-compose -f docker-compose.prod.yml ps

# Test connectivity
echo "🧪 Testing connectivity..."
if curl -s http://localhost/health > /dev/null; then
    echo "✅ HTTP health check passed"
else
    echo "❌ HTTP health check failed"
fi

# Display connection info
echo ""
echo "🎉 Deployment complete!"
echo ""
echo "📡 Service URLs:"
echo "   - gRPC Ingest: 178.79.139.38:9002"
echo "   - NATS Monitor: http://178.79.139.38:8222"
echo "   - ClickHouse UI: http://178.79.139.38:8123"
echo "   - Health Check: http://178.79.139.38/health"
echo ""
echo "🔧 Agent connection examples:"
echo "   Windows: ./sm-agent.exe -org demo -token sm_tok_demo123 -ingest 178.79.139.38:9002"
echo "   Linux:   ./sm-agent -org demo -token sm_tok_demo123 -ingest 178.79.139.38:9002"
echo ""
echo "📋 To view logs:"
echo "   docker-compose -f docker-compose.prod.yml logs -f ingest"
echo ""
echo "🔒 Security Notes:"
echo "   - TLS is currently disabled for testing"
echo "   - Remember to configure firewall rules for ports 9002, 8222, 8123"
echo "   - Consider enabling TLS for production use" 