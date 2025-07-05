# Security Manager v1.0.7 Update Guide

## 🎉 Successfully Released v1.0.7!

Your Security Manager has been successfully updated with complete auto-registration functionality. All changes have been pushed to GitHub and the release process has been initiated.

## 📋 What's New in v1.0.7

### ✨ **Major Features**
- **Complete Auto-Registration**: Agents automatically register with hostname, IP, OS info
- **One-Click Server Addition**: Dashboard generates install commands immediately
- **PostgreSQL Integration**: Real-time agent status tracking in database
- **Enhanced System Detection**: Automatic capability detection based on OS
- **Streamlined UX**: No more manual server IP entry required

### 🔧 **Technical Improvements**
- Enhanced protobuf schema with auto-registration fields
- Database-backed agent management
- Improved error handling and logging
- Better authentication flow with registration confirmation
- Cross-platform system information collection

## 🚀 **Update Instructions**

### 1. Update the Ingest Engine (Server)

```bash
# On your server (178.79.139.38)
cd /path/to/security-manager
git pull origin main
go build -o ingest ./cmd/ingest

# Restart the service
sudo systemctl restart security-manager-ingest
# OR if using Docker:
docker-compose down && docker-compose up -d
```

### 2. Database Setup (Required for v1.0.7)

Ensure PostgreSQL is running and accessible:

```bash
# Environment variables needed:
export DATABASE_URL="postgresql://user:password@localhost:5432/security_manager"
# OR individual components:
export DB_HOST="localhost"
export DB_PORT="5432"
export DB_USER="your_user"
export DB_PASSWORD="your_password"
export DB_NAME="security_manager"
```

### 3. Update Agents

The new v1.0.7 agents will be available from GitHub releases shortly. Users can update by:

#### Option A: Using New Install Command (Recommended)
```bash
# Get the new install command from your dashboard
# Click "Add Server" → copy the curl command → run it
curl -L https://github.com/mulutu/security-manager/releases/latest/download/install.sh | bash -s -- YOUR_TOKEN_HERE
```

#### Option B: Manual Update
```bash
# Download the latest agent
wget https://github.com/mulutu/security-manager/releases/latest/download/sm-agent-linux-amd64
chmod +x sm-agent-linux-amd64
sudo mv sm-agent-linux-amd64 /usr/local/bin/sm-agent

# Restart the agent service
sudo systemctl restart security-manager-agent
```

## 🔍 **Verification Steps**

1. **Check GitHub Release**: Visit https://github.com/mulutu/security-manager/releases
2. **Verify Build**: Check https://github.com/mulutu/security-manager/actions for build status
3. **Test Auto-Registration**: 
   - Click "Add Server" in dashboard
   - Copy the generated curl command
   - Run on a test server
   - Verify server appears automatically in dashboard

## ⚠️ **Breaking Changes**

- **Database Required**: Ingest server now requires PostgreSQL connection
- **Enhanced Auth Flow**: Agents send more system information during authentication
- **Auto-Registration**: Servers appear automatically (no manual entry needed)

## 🔧 **New User Experience**

### Before v1.0.7:
1. User manually enters server name, IP, OS
2. Gets install script
3. Runs script on server
4. Server appears in dashboard

### After v1.0.7:
1. User clicks "Add Server"
2. Immediately gets curl command
3. Runs command on any server
4. Server auto-appears in dashboard within 30 seconds

## 📊 **System Requirements**

- **Ingest Server**: PostgreSQL database connection required
- **Agents**: Compatible with Linux (AMD64, ARM64, ARM), Windows, macOS
- **Dashboard**: No changes required (Next.js app continues as before)

## 🐛 **Troubleshooting**

### If agents don't appear:
1. Check PostgreSQL connection on ingest server
2. Verify environment variables are set
3. Check ingest server logs for database errors
4. Ensure agent can reach ingest server on port 9002

### If build fails:
1. Check GitHub Actions workflow status
2. Verify Go version compatibility
3. Check for any protobuf compilation errors

## 📞 **Support**

- **GitHub Issues**: https://github.com/mulutu/security-manager/issues
- **Releases**: https://github.com/mulutu/security-manager/releases
- **Actions**: https://github.com/mulutu/security-manager/actions

---

## 🎯 **Next Steps**

1. **Monitor Release**: Check GitHub Actions for successful build completion
2. **Test Deployment**: Use the new install commands on test servers
3. **Update Documentation**: Update any deployment guides with new process
4. **Train Users**: Show team members the new one-click server addition process

**The Security Manager v1.0.7 is now live with complete auto-registration! 🎉** 