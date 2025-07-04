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
    
    # Create new service with better error handling
    Write-Host "🔧 Creating Windows service..." -ForegroundColor Blue
    $servicePath = "`"$installDir\sm-agent.exe`" -org $OrgId -token $Token -ingest $IngestUrl"
    
    # Try multiple service creation methods
    $serviceCreated = $false
    
    # Method 1: sc.exe
    try {
        $result = & sc.exe create $serviceName binPath= $servicePath start= auto DisplayName= "Security Manager Agent" Description= "Security Manager monitoring and protection agent" 2>&1
        if ($LASTEXITCODE -eq 0) {
            $serviceCreated = $true
            Write-Host "✅ Service created using sc.exe" -ForegroundColor Green
        } else {
            Write-Host "   sc.exe failed: $result" -ForegroundColor Gray
        }
    } catch {
        Write-Host "   sc.exe exception: $($_.Exception.Message)" -ForegroundColor Gray
    }
    
    # Method 2: PowerShell New-Service
    if (-not $serviceCreated) {
        try {
            New-Service -Name $serviceName -BinaryPathName "$installDir\sm-agent.exe -org $OrgId -token $Token -ingest $IngestUrl" -DisplayName "Security Manager Agent" -Description "Security Manager monitoring and protection agent" -StartupType Automatic -ErrorAction Stop
            $serviceCreated = $true
            Write-Host "✅ Service created using PowerShell" -ForegroundColor Green
        } catch {
            Write-Host "   PowerShell method failed: $($_.Exception.Message)" -ForegroundColor Gray
        }
    }
    
    if (-not $serviceCreated) {
        throw "Failed to create Windows service using all methods"
    }
    
    # Verify service exists
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if (-not $service) {
        throw "Service was not created properly"
    }
    
    Write-Host "✅ Service verified and exists" -ForegroundColor Green
    
    # Start the service with timeout
    Write-Host "🚀 Starting service..." -ForegroundColor Blue
    try {
        Start-Service -Name $serviceName -ErrorAction Stop
        Start-Sleep 5
        
        $service = Get-Service -Name $serviceName
        if ($service.Status -eq "Running") {
            Write-Host "✅ Service is running" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Service created but not running. Status: $($service.Status)" -ForegroundColor Yellow
            
            # Check service logs
            try {
                $logs = Get-EventLog -LogName Application -Source $serviceName -Newest 3 -ErrorAction SilentlyContinue
                if ($logs) {
                    Write-Host "   Recent service logs:" -ForegroundColor Gray
                    $logs | ForEach-Object { Write-Host "   $($_.TimeGenerated): $($_.Message)" -ForegroundColor Gray }
                }
            } catch {
                Write-Host "   No service logs found" -ForegroundColor Gray
            }
        }
    } catch {
        Write-Host "❌ Failed to start service: $($_.Exception.Message)" -ForegroundColor Red
        throw "Service start failed"
    }
    
    Write-Host ""
    Write-Host "🎉 Installation completed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📊 Service Status:" -ForegroundColor Blue
    Get-Service -Name $serviceName -ErrorAction SilentlyContinue | Format-Table -AutoSize
    Write-Host ""
    Write-Host "🔧 Management Commands:" -ForegroundColor Blue
    Write-Host "  Start:   Start-Service -Name $serviceName"
    Write-Host "  Stop:    Stop-Service -Name $serviceName"
    Write-Host "  Status:  Get-Service -Name $serviceName"
    Write-Host "  Logs:    Get-EventLog -LogName Application -Source '$serviceName' -Newest 10"
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