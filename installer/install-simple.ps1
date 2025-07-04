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
    Set-Location "security-manager"
    
    $env:GOOS = "windows"
    $env:GOARCH = "amd64"
    $env:CGO_ENABLED = "0"
    $env:GO111MODULE = "on"
    
    go mod download
    go mod tidy
    go build -v -o "sm-agent.exe" ./cmd/agent
    
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
    
    # Create new service
    $servicePath = "`"$installDir\sm-agent.exe`" -org $OrgId -token $Token -ingest $IngestUrl"
    & sc.exe create $serviceName binPath= $servicePath start= demand DisplayName= "Security Manager Agent" Description= "Security Manager monitoring and protection agent"
    
    Write-Host "✅ Service created successfully" -ForegroundColor Green
    Write-Host ""
    Write-Host "🎉 Installation completed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "🔧 Next Steps:" -ForegroundColor Blue
    Write-Host "  1. Test connection: Test-NetConnection -ComputerName 178.79.139.38 -Port 9002" -ForegroundColor White
    Write-Host "  2. Test agent manually: cd '$installDir' && .\sm-agent.exe -org $OrgId -token $Token -ingest $IngestUrl" -ForegroundColor White
    Write-Host "  3. Start service: Start-Service -Name $serviceName" -ForegroundColor White
    Write-Host "  4. Check status: Get-Service -Name $serviceName" -ForegroundColor White
    Write-Host ""
    Write-Host "📞 Need help? Check: https://github.com/mulutu/security-manager/blob/main/DEPLOYMENT_MANUAL.md" -ForegroundColor Cyan
    
} catch {
    Write-Host "❌ Installation failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} 