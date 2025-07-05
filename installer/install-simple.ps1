# Security Manager - Simple Windows Installer
# Usage: irm https://raw.githubusercontent.com/mulutu/security-manager/main/installer/install-simple.ps1 | iex

param(
    [Parameter(Mandatory=$false)]
    [string]$Token = "sm_tok_demo123",
    
    [Parameter(Mandatory=$false)]
    [string]$OrgId = "demo",
    
    [Parameter(Mandatory=$false)]
    [string]$IngestUrl = "178.79.139.38:9002"
)

Write-Host "🛡️  Security Manager - Simple Windows Installer" -ForegroundColor Green
Write-Host "   Organization: $OrgId" -ForegroundColor Blue
Write-Host "   Ingest URL: $IngestUrl" -ForegroundColor Blue
Write-Host ""

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "❌ Administrator privileges required" -ForegroundColor Red
    Write-Host "   Right-click PowerShell → 'Run as Administrator'" -ForegroundColor White
    exit 1
}

Write-Host "✅ Running as Administrator" -ForegroundColor Green
Write-Host ""

try {
    # Build the agent
    Write-Host "🏗️  Building agent..." -ForegroundColor Blue
    
    $tempDir = "$env:TEMP\security-manager-install"
    if (Test-Path $tempDir) {
        Remove-Item $tempDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    Set-Location $tempDir
    
    git clone https://github.com/mulutu/security-manager.git
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to clone repository"
    }
    Set-Location "security-manager"
    
    $env:GOOS = "windows"
    $env:GOARCH = "amd64"
    $env:CGO_ENABLED = "0"
    $env:GO111MODULE = "on"
    
    Write-Host "   Downloading dependencies..." -ForegroundColor Gray
    go mod download
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to download Go dependencies"
    }
    
    Write-Host "   Building agent..." -ForegroundColor Gray
    go build -v -o "sm-agent.exe" ./cmd/agent
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to build agent"
    }
    
    # Install
    $installDir = "C:\Program Files\Security Manager"
    if (Test-Path $installDir) {
        Remove-Item $installDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
    Copy-Item "sm-agent.exe" "$installDir\sm-agent.exe"
    
    Write-Host "✅ Agent built and installed" -ForegroundColor Green
    
    # Create service (but don't start it)
    Write-Host "🔧 Creating Windows service..." -ForegroundColor Blue
    $serviceName = "SecurityManagerAgent"
    
    # Remove existing service
    if (Get-Service -Name $serviceName -ErrorAction SilentlyContinue) {
        Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
        & sc.exe delete $serviceName 2>$null
    }
    
    # Install and start the native Windows service
    Write-Host "🔧 Installing Windows service..." -ForegroundColor Blue
    
    # Use the agent's built-in service installation
    try {
        $installResult = & "$installDir\sm-agent.exe" -service install -org $OrgId -token $Token -ingest $IngestUrl 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Service installed successfully" -ForegroundColor Green
        } else {
            Write-Host "   Service install output: $installResult" -ForegroundColor Gray
            throw "Service installation failed with exit code $LASTEXITCODE"
        }
    } catch {
        Write-Host "❌ Failed to install service: $($_.Exception.Message)" -ForegroundColor Red
        throw "Service installation failed"
    }
    
    # Start the service
    Write-Host "🚀 Starting service..." -ForegroundColor Blue
    try {
        $startResult = & "$installDir\sm-agent.exe" -service start 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Service started successfully" -ForegroundColor Green
        } else {
            Write-Host "   Service start output: $startResult" -ForegroundColor Gray
            # Try manual start as fallback
            Write-Host "   Trying manual start..." -ForegroundColor Gray
            Start-Service -Name "SecurityManagerAgent" -ErrorAction Stop
            Write-Host "✅ Service started manually" -ForegroundColor Green
        }
    } catch {
        Write-Host "❌ Failed to start service: $($_.Exception.Message)" -ForegroundColor Red
        throw "Service start failed"
    }
    
    # Verify service is running
    Start-Sleep 3
    $service = Get-Service -Name "SecurityManagerAgent" -ErrorAction SilentlyContinue
    if ($service -and $service.Status -eq "Running") {
        Write-Host "✅ Service is running correctly" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Service status: $($service.Status)" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "🎉 Installation completed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📊 Service Status:" -ForegroundColor Blue
    Get-Service -Name "SecurityManagerAgent" -ErrorAction SilentlyContinue | Format-Table -AutoSize
    Write-Host ""
    Write-Host "🔧 Management Commands:" -ForegroundColor Blue
    Write-Host "  Start:   `"$installDir\sm-agent.exe`" -service start"
    Write-Host "  Stop:    `"$installDir\sm-agent.exe`" -service stop"
    Write-Host "  Status:  Get-Service -Name SecurityManagerAgent"
    Write-Host "  Uninstall: `"$installDir\sm-agent.exe`" -service uninstall"
    Write-Host ""
    Write-Host "🌐 Web Interfaces:" -ForegroundColor Blue
    Write-Host "  NATS Monitor: http://$($IngestUrl.Replace(':9002', ':8222'))"
    Write-Host "  ClickHouse UI: http://$($IngestUrl.Replace(':9002', ':8123'))"
    Write-Host ""
    Write-Host "📞 Need help? Check: https://github.com/mulutu/security-manager/blob/main/DEPLOYMENT_MANUAL.md" -ForegroundColor Cyan
    
} catch {
    Write-Host "❌ Installation failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} 