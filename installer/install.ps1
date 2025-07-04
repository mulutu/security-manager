# Security Manager - Windows PowerShell Installer
# Usage: irm https://raw.githubusercontent.com/mulutu/security-manager/main/installer/install.ps1 | iex
# With parameters: irm https://raw.githubusercontent.com/mulutu/security-manager/main/installer/install.ps1 | iex; Install-SM -Token "your_token" -OrgId "your_org"

param(
    [Parameter(Mandatory=$false)]
    [string]$Token = "sm_tok_demo123",
    
    [Parameter(Mandatory=$false)]
    [string]$OrgId = "demo",
    
    [Parameter(Mandatory=$false)]
    [string]$IngestUrl = "178.79.139.38:9002",
    
    [Parameter(Mandatory=$false)]
    [string]$InstallDir = "C:\Program Files\Security Manager",
    
    [Parameter(Mandatory=$false)]
    [string]$ServiceName = "SecurityManagerAgent",
    
    [Parameter(Mandatory=$false)]
    [switch]$Help
)

function Install-SM {
    param(
        [string]$Token = "sm_tok_demo123",
        [string]$OrgId = "demo", 
        [string]$IngestUrl = "178.79.139.38:9002",
        [string]$InstallDir = "C:\Program Files\Security Manager",
        [string]$ServiceName = "SecurityManagerAgent"
    )
    
    Write-Host "🛡️  Security Manager Agent Installer" -ForegroundColor Green
    Write-Host "   Organization: $OrgId" -ForegroundColor Blue
    Write-Host "   Ingest URL: $IngestUrl" -ForegroundColor Blue
    Write-Host "   Install Dir: $InstallDir" -ForegroundColor Blue
    Write-Host ""

    # Check if running as Administrator
    if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Host "❌ This script must be run as Administrator" -ForegroundColor Red
        Write-Host "Please right-click PowerShell and 'Run as Administrator'" -ForegroundColor Yellow
        exit 1
    }

    # Check if Go is installed
    if (-not (Get-Command go -ErrorAction SilentlyContinue)) {
        Write-Host "📦 Installing Go..." -ForegroundColor Blue
        
        # Download and install Go
        $goVersion = "1.21.5"
        $goUrl = "https://golang.org/dl/go$goVersion.windows-amd64.msi"
        $goInstaller = "$env:TEMP\go-installer.msi"
        
        Write-Host "   Downloading Go $goVersion..." -ForegroundColor Gray
        Invoke-WebRequest -Uri $goUrl -OutFile $goInstaller
        
        Write-Host "   Installing Go..." -ForegroundColor Gray
        Start-Process msiexec.exe -ArgumentList "/i", $goInstaller, "/quiet" -Wait
        
        # Add Go to PATH
        $env:PATH += ";C:\Program Files\Go\bin"
        [Environment]::SetEnvironmentVariable("PATH", $env:PATH, [EnvironmentVariableTarget]::Machine)
        
        Remove-Item $goInstaller
        Write-Host "✅ Go installed successfully" -ForegroundColor Green
    }

    # Check if Git is installed
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "📦 Installing Git..." -ForegroundColor Blue
        
        # Download and install Git
        $gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.42.0.windows.2/Git-2.42.0.2-64-bit.exe"
        $gitInstaller = "$env:TEMP\git-installer.exe"
        
        Write-Host "   Downloading Git..." -ForegroundColor Gray
        Invoke-WebRequest -Uri $gitUrl -OutFile $gitInstaller
        
        Write-Host "   Installing Git..." -ForegroundColor Gray
        Start-Process $gitInstaller -ArgumentList "/SILENT" -Wait
        
        # Add Git to PATH
        $env:PATH += ";C:\Program Files\Git\bin"
        [Environment]::SetEnvironmentVariable("PATH", $env:PATH, [EnvironmentVariableTarget]::Machine)
        
        Remove-Item $gitInstaller
        Write-Host "✅ Git installed successfully" -ForegroundColor Green
    }

    # Create installation directory
    Write-Host "📁 Creating installation directory..." -ForegroundColor Blue
    if (Test-Path $InstallDir) {
        Remove-Item $InstallDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    Set-Location $InstallDir

    # Clone repository
    Write-Host "📥 Cloning repository..." -ForegroundColor Blue
    git clone https://github.com/mulutu/security-manager.git
    Set-Location "security-manager"

    # Build the agent
    Write-Host "🏗️  Building agent..." -ForegroundColor Blue
    Set-Location "cmd/agent"
    $env:GOOS = "windows"
    $env:GOARCH = "amd64"
    go build -o "$InstallDir\sm-agent.exe" .
    Set-Location "..\..\.."

    # Create configuration file
    Write-Host "⚙️  Creating configuration..." -ForegroundColor Blue
    $configContent = @"
# Security Manager Agent Configuration
SM_ORG_ID=$OrgId
SM_TOKEN=$Token
SM_INGEST_URL=$IngestUrl
SM_HOST_ID=$env:COMPUTERNAME
SM_USE_TLS=false
SM_LOG_LEVEL=info
"@
    $configContent | Out-File -FilePath "$InstallDir\sm-agent.conf" -Encoding UTF8

    # Create Windows service
    Write-Host "🔧 Creating Windows service..." -ForegroundColor Blue
    
    # Stop existing service if it exists
    if (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue) {
        Write-Host "   Stopping existing service..." -ForegroundColor Gray
        Stop-Service -Name $ServiceName -Force
        & sc.exe delete $ServiceName
        Start-Sleep 2
    }

    # Create new service
    $servicePath = "`"$InstallDir\sm-agent.exe`""
    $serviceArgs = @(
        "create", $ServiceName,
        "binPath=", $servicePath,
        "start=", "auto",
        "DisplayName=", "Security Manager Agent",
        "Description=", "Security Manager monitoring and protection agent"
    )
    
    & sc.exe @serviceArgs
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Service created successfully" -ForegroundColor Green
    } else {
        Write-Host "❌ Failed to create service" -ForegroundColor Red
        exit 1
    }

    # Start the service
    Write-Host "🚀 Starting service..." -ForegroundColor Blue
    Start-Service -Name $ServiceName
    Start-Sleep 3

    # Test the installation
    Write-Host "🧪 Testing installation..." -ForegroundColor Blue
    
    $service = Get-Service -Name $ServiceName
    if ($service.Status -eq "Running") {
        Write-Host "✅ Service is running" -ForegroundColor Green
        
        # Test connectivity
        Set-Location "$InstallDir\security-manager"
        try {
            $env:SM_INGEST_URL = $IngestUrl
            $env:SM_ORG_ID = $OrgId
            $env:SM_TOKEN = $Token
            & go run tools/test_remote/main.go -ingest $IngestUrl -org $OrgId -token $Token 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ Connectivity test passed" -ForegroundColor Green
            } else {
                Write-Host "⚠️  Connectivity test failed - check network and ingest service" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "⚠️  Could not run connectivity test" -ForegroundColor Yellow
        }
    } else {
        Write-Host "❌ Service failed to start" -ForegroundColor Red
        Write-Host "Check Windows Event Log for details" -ForegroundColor Yellow
        exit 1
    }

    Write-Host ""
    Write-Host "🎉 Installation completed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📊 Service Status:" -ForegroundColor Blue
    Get-Service -Name $ServiceName | Format-Table -AutoSize
    Write-Host ""
    Write-Host "🔧 Management Commands:" -ForegroundColor Blue
    Write-Host "  Start:   Start-Service -Name $ServiceName"
    Write-Host "  Stop:    Stop-Service -Name $ServiceName"
    Write-Host "  Status:  Get-Service -Name $ServiceName"
    Write-Host "  Logs:    Get-EventLog -LogName Application -Source '$ServiceName' -Newest 10"
    Write-Host ""
    Write-Host "📁 Installation Directory: $InstallDir" -ForegroundColor Blue
    Write-Host "⚙️  Configuration File: $InstallDir\sm-agent.conf" -ForegroundColor Blue
    Write-Host ""
    Write-Host "🛡️  Your server is now protected by Security Manager!" -ForegroundColor Green
}

function Show-Help {
    Write-Host @"
Security Manager Agent Installer for Windows

Usage:
  # One-liner installation with defaults
  irm https://raw.githubusercontent.com/mulutu/security-manager/main/installer/install.ps1 | iex

  # Installation with custom parameters
  irm https://raw.githubusercontent.com/mulutu/security-manager/main/installer/install.ps1 | iex; Install-SM -Token "your_token" -OrgId "your_org"

Parameters:
  -Token       Authentication token (default: sm_tok_demo123)
  -OrgId       Organization ID (default: demo)
  -IngestUrl   Ingest service URL (default: 178.79.139.38:9002)
  -InstallDir  Installation directory (default: C:\Program Files\Security Manager)
  -ServiceName Windows service name (default: SecurityManagerAgent)

Examples:
  Install-SM -Token "sm_tok_abc123" -OrgId "mycompany"
  Install-SM -Token "sm_tok_abc123" -OrgId "mycompany" -IngestUrl "192.168.1.100:9002"

"@
}

# Main execution
if ($Help) {
    Show-Help
    exit 0
}

# If parameters were provided, install directly
if ($PSBoundParameters.Count -gt 0) {
    Install-SM -Token $Token -OrgId $OrgId -IngestUrl $IngestUrl -InstallDir $InstallDir -ServiceName $ServiceName
} 