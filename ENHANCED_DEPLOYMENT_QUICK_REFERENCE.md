# Enhanced Security Manager - Quick Reference Card

**🚀 One-Command Deployment**

## 🔥 **Super Quick Start**

### **Complete Deployment (Services + Agent)**
```bash
# Deploy everything on service host (178.79.139.38)
curl -fsSL https://raw.githubusercontent.com/mulutu/security-manager/main/deploy/deploy-enhanced.sh | bash

# Deploy agent only on target servers
curl -fsSL https://raw.githubusercontent.com/mulutu/security-manager/main/installer/install.sh | sudo bash
```

### **Custom Deployment**
```bash
# Download deployment script
curl -fsSL https://raw.githubusercontent.com/mulutu/security-manager/main/deploy/deploy-enhanced.sh -o deploy-enhanced.sh
chmod +x deploy-enhanced.sh

# Deploy services only
./deploy-enhanced.sh --type services

# Deploy agent only
sudo ./deploy-enhanced.sh --type agent --org "myorg" --token "mytoken"

# Full deployment with custom settings
./deploy-enhanced.sh --type full --service-host "1.2.3.4" --org "myorg" --token "mytoken"
```

---

## 📊 **Monitoring URLs**

| Service | URL | Purpose |
|---------|-----|---------|
| **Health Check** | `http://178.79.139.38/health` | Service status |
| **NATS Monitor** | `http://178.79.139.38:8222` | Message queuing |
| **ClickHouse UI** | `http://178.79.139.38:8123` | Data analytics |
| **gRPC Ingest** | `178.79.139.38:9002` | Agent connection |

---

## 🛡️ **Security Features**

### **Enhanced Collectors**
- **📋 Systemd Journal**: Real-time system events
- **🔐 Authentication**: SSH/sudo/login monitoring
- **⚙️ Process Monitor**: Creation/termination tracking
- **🌐 Network Monitor**: Connection analysis
- **📊 System Metrics**: CPU/memory/disk usage
- **📁 File Monitor**: Critical file changes

### **Active Mitigations**
- **🚫 IP Blocking**: Automatic iptables rules
- **💀 Process Kill**: Graceful → force termination
- **🔒 Host Isolation**: Network quarantine
- **📦 File Quarantine**: Suspicious file containment
- **🛑 Service Control**: Systemd management

### **Detection Rules (8 Active)**
1. **SSH Brute Force** - 5+ failed attempts
2. **High CPU Usage** - >90% sustained
3. **High Memory Usage** - >90% sustained
4. **Critical Disk Usage** - >85% full
5. **Suspicious Processes** - nc, python -c, etc.
6. **Critical File Changes** - /etc/passwd, /etc/shadow
7. **Network Scanning** - Port scan detection
8. **Authentication Anomalies** - Unusual login patterns

---

## 🔧 **Essential Commands**

### **Agent Management**
```bash
# Service control
sudo systemctl start security-manager-agent
sudo systemctl stop security-manager-agent
sudo systemctl restart security-manager-agent
sudo systemctl status security-manager-agent

# Logs and monitoring
sudo journalctl -u security-manager-agent -f
sudo journalctl -u security-manager-agent -n 100
sudo journalctl -u security-manager-agent --since "1 hour ago"

# Configuration
sudo nano /etc/security-manager/config.yaml
sudo /opt/security-manager/sm-agent --version
```

### **Service Management**
```bash
# Docker services
cd ~/security-manager/deploy
docker-compose -f docker-compose.prod.yml ps
docker-compose -f docker-compose.prod.yml logs -f
docker-compose -f docker-compose.prod.yml restart
docker-compose -f docker-compose.prod.yml down
docker-compose -f docker-compose.prod.yml up -d

# Individual service logs
docker-compose -f docker-compose.prod.yml logs ingest
docker-compose -f docker-compose.prod.yml logs nats
docker-compose -f docker-compose.prod.yml logs clickhouse
```

---

## 📊 **Data Queries**

### **ClickHouse Quick Queries**
```sql
-- Recent security events
SELECT stream, COUNT(*) as count, MAX(ts) as latest
FROM events 
WHERE ts > now() - INTERVAL 1 HOUR
GROUP BY stream ORDER BY count DESC;

-- Active alerts
SELECT rule_name, severity, COUNT(*) as count
FROM alerts 
WHERE ts > now() - INTERVAL 1 HOUR
GROUP BY rule_name, severity ORDER BY count DESC;

-- Mitigation success rate
SELECT action, success, COUNT(*) as total
FROM mitigations 
WHERE ts > now() - INTERVAL 24 HOUR
GROUP BY action, success ORDER BY total DESC;

-- Agent health
SELECT host_id, MAX(ts) as last_heartbeat
FROM agent_heartbeats 
WHERE ts > now() - INTERVAL 1 HOUR
GROUP BY host_id ORDER BY last_heartbeat DESC;

-- System performance
SELECT host_id, AVG(cpu_usage) as avg_cpu, AVG(memory_usage) as avg_mem
FROM system_metrics 
WHERE ts > now() - INTERVAL 1 HOUR
GROUP BY host_id ORDER BY avg_cpu DESC;
```

### **NATS Monitoring**
```bash
# Connection stats
curl -s "http://178.79.139.38:8222/connz" | jq '.connections[] | {name, ip, port}'

# Stream info
curl -s "http://178.79.139.38:8222/jsz" | jq '.streams[] | {name, messages, bytes}'

# Subject stats
curl -s "http://178.79.139.38:8222/subsz" | jq '.subscriptions[] | {subject, msgs}'
```

---

## 🚨 **Troubleshooting**

### **Agent Issues**
```bash
# Check agent status
sudo systemctl status security-manager-agent

# Common fixes
sudo systemctl restart security-manager-agent
sudo usermod -a -G systemd-journal security-manager
sudo chmod +r /var/log/auth.log

# Connectivity test
telnet 178.79.139.38 9002
curl -v http://178.79.139.38/health
```

### **Service Issues**
```bash
# Check all services
curl -v http://178.79.139.38/health

# Restart services
cd ~/security-manager/deploy
docker-compose -f docker-compose.prod.yml restart

# Check ports
netstat -tlnp | grep -E "(9002|8222|8123)"
sudo ufw status
```

### **Data Flow Issues**
```bash
# Check recent events
curl -s "http://178.79.139.38:8123/" -d "SELECT COUNT(*) FROM events WHERE ts > now() - INTERVAL 5 MINUTE"

# Check NATS messages
curl -s "http://178.79.139.38:8222/varz" | jq '.in_msgs'

# Test agent connectivity
go run tools/test_enhanced/main.go -ingest 178.79.139.38:9002
```

---

## 🧪 **Testing Security Features**

### **Trigger SSH Brute Force**
```bash
# Safe test (add fake log entries)
for i in {1..6}; do
  echo "$(date) Failed password for testuser$i from 192.168.1.100 port 22 ssh2" | sudo tee -a /var/log/auth.log
  sleep 1
done

# Check for IP blocking
sudo iptables -L INPUT -n | grep 192.168.1.100
```

### **Trigger Resource Alerts**
```bash
# High CPU alert
echo "$(date) High CPU usage: 95.2%" | sudo tee -a /var/log/syslog

# High disk usage alert
echo "$(date) High disk usage: 92.1%" | sudo tee -a /var/log/syslog

# Check for alerts
curl -s "http://178.79.139.38:8123/" -d "SELECT * FROM alerts WHERE ts > now() - INTERVAL 5 MINUTE"
```

### **Test Process Monitoring**
```bash
# Suspicious process
echo "$(date) Process started: nc (PID: 12345)" | sudo tee -a /var/log/syslog

# File modification
echo "$(date) File modified: /etc/passwd" | sudo tee -a /var/log/syslog

# Check detection
sudo journalctl -u security-manager-agent -n 20 | grep -i "alert\|mitigation"
```

---

## 🔄 **Maintenance**

### **Regular Checks**
```bash
# Daily health check
curl -s http://178.79.139.38/health && echo "✅ Services healthy"

# Weekly data cleanup (optional)
curl -s "http://178.79.139.38:8123/" -d "ALTER TABLE events DELETE WHERE ts < now() - INTERVAL 90 DAY"

# Monthly agent updates
curl -fsSL https://raw.githubusercontent.com/mulutu/security-manager/main/installer/install.sh | sudo bash
```

### **Backup Important Data**
```bash
# Export recent alerts
curl -s "http://178.79.139.38:8123/" -d "SELECT * FROM alerts WHERE ts > now() - INTERVAL 7 DAY FORMAT CSV" > alerts_backup.csv

# Export configuration
sudo cp /etc/security-manager/config.yaml ~/config_backup.yaml
```

---

## 📞 **Support**

### **Log Collection**
```bash
# Collect agent logs
sudo journalctl -u security-manager-agent --since "24 hours ago" > agent_logs.txt

# Collect service logs
cd ~/security-manager/deploy
docker-compose -f docker-compose.prod.yml logs > service_logs.txt

# System information
uname -a > system_info.txt
df -h >> system_info.txt
free -h >> system_info.txt
```

### **Performance Metrics**
```bash
# Agent resource usage
ps aux | grep sm-agent

# Service resource usage
docker stats --no-stream

# Network connectivity
ping -c 3 178.79.139.38
telnet 178.79.139.38 9002
```

---

## 🎯 **Performance Targets**

| Metric | Target | Command to Check |
|--------|--------|------------------|
| **Detection Latency** | < 1 second | Check agent logs for processing times |
| **Mitigation Response** | < 3 seconds | Check mitigation table timestamps |
| **Agent RAM Usage** | < 50MB | `ps aux \| grep sm-agent` |
| **Agent CPU Usage** | < 2% | `top -p $(pgrep sm-agent)` |
| **Event Processing** | 10,000+/sec | Check NATS message rates |

---

## 🚀 **Quick Deployment Summary**

### **For New Deployments**
1. **Service Host**: `curl -fsSL https://raw.githubusercontent.com/mulutu/security-manager/main/deploy/deploy-enhanced.sh | bash`
2. **Agent Hosts**: `curl -fsSL https://raw.githubusercontent.com/mulutu/security-manager/main/installer/install.sh | sudo bash`
3. **Verify**: Open `http://178.79.139.38:8123` and run test queries

### **For Existing Deployments**
1. **Update Services**: `cd ~/security-manager && git pull && docker-compose -f deploy/docker-compose.prod.yml up --build -d`
2. **Update Agents**: `curl -fsSL https://raw.githubusercontent.com/mulutu/security-manager/main/installer/install.sh | sudo bash`
3. **Test**: `go run tools/test_enhanced/main.go -ingest 178.79.139.38:9002`

---

**🎉 You now have enterprise-grade security monitoring with automated threat response! 🎉** 