# Security Manager - Distributed Deployment Guide

This guide covers deploying the Security Manager services on a remote VM and connecting agents from different machines.

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    Remote VM (178.79.139.38)                    │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────┐ │
│  │    NATS     │  │ ClickHouse  │  │   Ingest    │  │  Nginx  │ │
│  │   :4222     │  │   :9000     │  │   :9002     │  │   :80   │ │
│  │   :8222     │  │   :8123     │  │             │  │   :443  │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────┘ │
└─────────────────────────────────────────────────────────────────┘
                                │
                                │ gRPC :9002
                                │
                ┌───────────────┼───────────────┐
                │               │               │
                ▼               ▼               ▼
    ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
    │  Windows Agent  │ │  Linux Agent    │ │  Other Agents   │
    │   (Laptop)      │ │ (178.79.136.143)│ │                 │
    └─────────────────┘ └─────────────────┘ └─────────────────┘
```

## 🚀 Step 1: Deploy Services on Remote VM (178.79.139.38)

### Prerequisites
- Ubuntu/Debian/CentOS Linux VM
- Docker and Docker Compose installed
- Firewall configured to allow ports: 9002, 8222, 8123, 80, 443

### Deployment Steps

1. **SSH into the remote VM:**
   ```bash
   ssh user@178.79.139.38
   ```

2. **Download and run the deployment script:**
   ```bash
   curl -fsSL https://raw.githubusercontent.com/mulutu/security-manager/main/deploy/deploy-remote.sh | bash
   ```

   **OR manually:**
   ```bash
   wget https://raw.githubusercontent.com/mulutu/security-manager/main/deploy/deploy-remote.sh
   chmod +x deploy-remote.sh
   ./deploy-remote.sh
   ```

5. **Verify services are running:**
   ```bash
   docker-compose -f docker-compose.prod.yml ps
   ```

### Expected Output
```
     Name                   Command               State                    Ports
─────────────────────────────────────────────────────────────────────────────────
deploy_clickhouse_1   /entrypoint.sh                   Up      0.0.0.0:8123->8123/tcp,
                                                               0.0.0.0:9000->9000/tcp
deploy_ingest_1       /app/ingest                      Up      0.0.0.0:9002->9002/tcp
deploy_nats_1         /nats-server -js -m 8222         Up      0.0.0.0:4222->4222/tcp,
                                                               0.0.0.0:8222->8222/tcp
deploy_nginx_1        /docker-entrypoint.sh nginx      Up      0.0.0.0:443->443/tcp,
                                                               0.0.0.0:80->80/tcp
```

## 🪟 Step 2: Setup Windows Agent (Your Laptop)

### Prerequisites
- Windows 10/11
- PowerShell (Run as Administrator)

### One-Line Installation
```powershell
# Default installation (demo org)
irm https://raw.githubusercontent.com/mulutu/security-manager/main/installer/install.ps1 | iex

# Custom installation
irm https://raw.githubusercontent.com/mulutu/security-manager/main/installer/install.ps1 | iex; Install-SM -Token "your_token" -OrgId "your_org"
```

### Manual Setup (Alternative)

1. **Open PowerShell as Administrator**

2. **Navigate to your project directory:**
   ```powershell
   cd C:\path\to\security-manager\deploy
   ```

3. **Run the Windows setup script:**
   ```powershell
   .\windows-agent.ps1 -Build -Test
   ```

4. **Start the agent:**
   ```powershell
   .\windows-agent.ps1
   ```

### Custom Configuration
```powershell
# One-liner with custom parameters
Install-SM -Token "your_token" -OrgId "your_org" -IngestUrl "178.79.139.38:9002"

# Manual script with custom parameters
.\windows-agent.ps1 -IngestURL "178.79.139.38:9002" -OrgID "your-org" -Token "your-token" -HostID "laptop-01"
```

## 🐧 Step 3: Setup Linux Agent (178.79.136.143)

### Prerequisites
- Linux VM with internet access
- SSH access to the VM

### One-Line Installation
```bash
# Default installation (demo org)
curl -fsSL https://raw.githubusercontent.com/mulutu/security-manager/main/installer/install.sh | sudo bash

# Custom installation
curl -fsSL https://raw.githubusercontent.com/mulutu/security-manager/main/installer/install.sh | sudo bash -s -- --token "your_token" --org "your_org"
```

### Manual Setup (Alternative)

1. **SSH into the Linux VM:**
   ```bash
   ssh user@178.79.136.143
   ```

2. **Download and run the agent setup script:**
   ```bash
   curl -fsSL https://raw.githubusercontent.com/mulutu/security-manager/main/deploy/linux-agent.sh | bash
   ```

   **OR manually:**
   ```bash
   wget https://raw.githubusercontent.com/mulutu/security-manager/main/deploy/linux-agent.sh
   chmod +x linux-agent.sh
   ./linux-agent.sh
   ```

### Custom Configuration
```bash
# Set environment variables for custom config
export SM_INGEST_URL="178.79.139.38:9002"
export SM_ORG_ID="your-org"
export SM_TOKEN="your-token"
export SM_HOST_ID="linux-vm-01"
./linux-agent.sh
```

## 🔍 Step 4: Monitoring and Verification

### Service Health Checks
```bash
# Check all services
curl http://178.79.139.38/health

# NATS monitoring
open http://178.79.139.38:8222

# ClickHouse UI
open http://178.79.139.38:8123
```

### View Logs
```bash
# On remote VM (178.79.139.38)
docker-compose -f docker-compose.prod.yml logs -f ingest

# View specific service logs
docker-compose -f docker-compose.prod.yml logs -f clickhouse
docker-compose -f docker-compose.prod.yml logs -f nats
```

### Verify Data Flow
```bash
# Check ClickHouse for incoming events
curl "http://178.79.139.38:8123/" -d "SELECT count(*) FROM events"

# Check NATS subjects
curl http://178.79.139.38:8222/jsz
```

## 🔧 Troubleshooting

### Common Issues

1. **Connection Refused (Port 9002)**
   - Check firewall rules on remote VM
   - Verify ingest service is running
   - Test with telnet: `telnet 178.79.139.38 9002`

2. **Authentication Failed**
   - Verify token matches in both agent and ingest service
   - Check ingest service logs for auth errors

3. **Docker Services Not Starting**
   - Check disk space: `df -h`
   - Check Docker logs: `docker-compose logs`
   - Restart services: `docker-compose down && docker-compose up -d`

### Debug Commands

```bash
# Test gRPC connection
go run tools/test_auth/main.go

# Check network connectivity
nc -zv 178.79.139.38 9002

# Monitor network traffic
sudo tcpdump -i any port 9002
```

## 🔒 Security Configuration

### Firewall Rules (Remote VM)
```bash
# Ubuntu/Debian
sudo ufw allow 9002/tcp  # gRPC ingest
sudo ufw allow 8222/tcp  # NATS monitoring
sudo ufw allow 8123/tcp  # ClickHouse UI
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS

# CentOS/RHEL
sudo firewall-cmd --add-port=9002/tcp --permanent
sudo firewall-cmd --add-port=8222/tcp --permanent
sudo firewall-cmd --add-port=8123/tcp --permanent
sudo firewall-cmd --reload
```

### Enable TLS (Production)
1. Obtain SSL certificates
2. Update `docker-compose.prod.yml` with TLS settings
3. Configure nginx for SSL termination

## 📊 Performance Monitoring

### Key Metrics to Monitor
- **Agent Connection Count**: Check NATS monitoring
- **Event Ingestion Rate**: Monitor ClickHouse insert rate
- **System Resources**: CPU, Memory, Disk usage
- **Network Latency**: Agent to ingest service

### Scaling Considerations
- **Horizontal Scaling**: Add more ingest service replicas
- **Database Sharding**: Partition ClickHouse by org_id
- **Load Balancing**: Use nginx upstream for multiple ingest services

## 🎯 Next Steps

1. **Enable TLS encryption** for production security
2. **Add more authentication methods** (JWT, certificates)
3. **Implement proper logging** and monitoring
4. **Add automated backups** for ClickHouse data
5. **Configure alerting** for service failures

---

## 📞 Support

For issues or questions:
1. Check the logs first
2. Verify network connectivity
3. Review firewall settings
4. Test with minimal configuration 