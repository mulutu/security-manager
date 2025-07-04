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

function Write-ProgressBar {
    param([string]$Activity, [string]$Status, [int]$PercentComplete)
    Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete
}

function Install-SM {
    param(
        [string]$Token = "sm_tok_demo123",
        [string]$OrgId = "demo", 
        [string]$IngestUrl = "178.79.139.38:9002",
        [string]$InstallDir = "C:\Program Files\Security Manager",
        [string]$ServiceName = "SecurityManagerAgent"
    )
    
    # Clear any existing progress
    Write-Progress -Completed
    
    Write-Host "🛡️  Security Manager Agent Installer" -ForegroundColor Green
    Write-Host "   Organization: $OrgId" -ForegroundColor Blue
    Write-Host "   Ingest URL: $IngestUrl" -ForegroundColor Blue
    Write-Host "   Install Dir: $InstallDir" -ForegroundColor Blue
    Write-Host ""

    # Check if running as Administrator
    if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Host "❌ Administrator privileges required" -ForegroundColor Red
        Write-Host ""
        Write-Host "🔧 Quick Fix:" -ForegroundColor Yellow
        Write-Host "   1. Close this window" -ForegroundColor White
        Write-Host "   2. Right-click PowerShell → 'Run as Administrator'" -ForegroundColor White
        Write-Host "   3. Run the installation command again:" -ForegroundColor White
        Write-Host ""
        Write-Host "   irm https://raw.githubusercontent.com/mulutu/security-manager/main/installer/install.ps1 | iex; Install-SM -Token `"$Token`" -OrgId `"$OrgId`"" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "💡 Alternative: Use the simple installer:" -ForegroundColor Yellow
        Write-Host "   irm https://raw.githubusercontent.com/mulutu/security-manager/main/installer/install-simple.ps1 | iex" -ForegroundColor Cyan
        Write-Host ""
        exit 1
    }

    Write-Host "✅ Running as Administrator - proceeding with installation..." -ForegroundColor Green
    Write-Host ""

    try {
        # Step 1: Check and install dependencies (10%)
        Write-ProgressBar -Activity "Installing Security Manager" -Status "Checking dependencies..." -PercentComplete 10
        
        # Check if Go is installed
        if (-not (Get-Command go -ErrorAction SilentlyContinue)) {
            Write-Host "📦 Installing Go..." -ForegroundColor Blue
            
            # Download and install Go
            $goVersion = "1.21.5"
            $goUrl = "https://golang.org/dl/go$goVersion.windows-amd64.msi"
            $goInstaller = "$env:TEMP\go-installer.msi"
            
            Write-Host "   Downloading Go $goVersion..." -ForegroundColor Gray
            Invoke-WebRequest -Uri $goUrl -OutFile $goInstaller -UseBasicParsing
            
            Write-Host "   Installing Go..." -ForegroundColor Gray
            Start-Process msiexec.exe -ArgumentList "/i", $goInstaller, "/quiet" -Wait
            
            # Add Go to PATH
            $env:PATH += ";C:\Program Files\Go\bin"
            [Environment]::SetEnvironmentVariable("PATH", $env:PATH, [EnvironmentVariableTarget]::Machine)
            
            Remove-Item $goInstaller -ErrorAction SilentlyContinue
            Write-Host "✅ Go installed successfully" -ForegroundColor Green
        } else {
            Write-Host "✅ Go already installed" -ForegroundColor Green
        }

        # Check if Git is installed
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
            Write-Host "📦 Installing Git..." -ForegroundColor Blue
            
            # Download and install Git
            $gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.42.0.windows.2/Git-2.42.0.2-64-bit.exe"
            $gitInstaller = "$env:TEMP\git-installer.exe"
            
            Write-Host "   Downloading Git..." -ForegroundColor Gray
            Invoke-WebRequest -Uri $gitUrl -OutFile $gitInstaller -UseBasicParsing
            
            Write-Host "   Installing Git..." -ForegroundColor Gray
            Start-Process $gitInstaller -ArgumentList "/SILENT" -Wait
            
            # Add Git to PATH
            $env:PATH += ";C:\Program Files\Git\bin"
            [Environment]::SetEnvironmentVariable("PATH", $env:PATH, [EnvironmentVariableTarget]::Machine)
            
            Remove-Item $gitInstaller -ErrorAction SilentlyContinue
            Write-Host "✅ Git installed successfully" -ForegroundColor Green
        } else {
            Write-Host "✅ Git already installed" -ForegroundColor Green
        }

        # Step 2: Prepare installation directory (20%)
        Write-ProgressBar -Activity "Installing Security Manager" -Status "Preparing installation directory..." -PercentComplete 20
        
        # Create installation directory
        Write-Host "📁 Creating installation directory..." -ForegroundColor Blue
        if (Test-Path $InstallDir) {
            Remove-Item $InstallDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
        Set-Location $InstallDir

        # Step 3: Clone repository (30%)
        Write-ProgressBar -Activity "Installing Security Manager" -Status "Downloading agent source code..." -PercentComplete 30
        
        # Clone repository
        Write-Host "📥 Downloading agent source code..." -ForegroundColor Blue
        git clone https://github.com/mulutu/security-manager.git
        Set-Location "security-manager"

        # Step 4: Build the agent (50%)
        Write-ProgressBar -Activity "Installing Security Manager" -Status "Building agent..." -PercentComplete 50
        
        # Build the agent
        Write-Host "🏗️  Building agent..." -ForegroundColor Blue
        Set-Location "cmd/agent"
        $env:GOOS = "windows"
        $env:GOARCH = "amd64"
        go build -o "$InstallDir\sm-agent.exe" .
        
        if (-not (Test-Path "$InstallDir\sm-agent.exe")) {
            throw "Build failed - executable not created"
        }
        
        Set-Location "..\..\.."
        Write-Host "✅ Agent built successfully" -ForegroundColor Green

        # Step 5: Create configuration (60%)
        Write-ProgressBar -Activity "Installing Security Manager" -Status "Creating configuration..." -PercentComplete 60
        
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

        # Step 6: Create and start Windows service (80%)
        Write-ProgressBar -Activity "Installing Security Manager" -Status "Creating Windows service..." -PercentComplete 80
        
        # Create Windows service
        Write-Host "🔧 Creating Windows service..." -ForegroundColor Blue
        
        # Stop existing service if it exists
        if (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue) {
            Write-Host "   Stopping existing service..." -ForegroundColor Gray
            Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
            & sc.exe delete $ServiceName 2>$null
            Start-Sleep 2
        }

        # Create new service using multiple methods
        $servicePath = "`"$InstallDir\sm-agent.exe`""
        $serviceCreated = $false
        
        # Method 1: Try sc.exe
        try {
            & sc.exe create $ServiceName binPath= $servicePath start= auto DisplayName= "Security Manager Agent" Description= "Security Manager monitoring and protection agent" 2>$null
            if ($LASTEXITCODE -eq 0) {
                $serviceCreated = $true
                Write-Host "✅ Service created using sc.exe" -ForegroundColor Green
            }
        } catch {
            Write-Host "   sc.exe method failed, trying PowerShell..." -ForegroundColor Gray
        }
        
        # Method 2: Try PowerShell New-Service
        if (-not $serviceCreated) {
            try {
                New-Service -Name $ServiceName -BinaryPathName "$InstallDir\sm-agent.exe" -DisplayName "Security Manager Agent" -Description "Security Manager monitoring and protection agent" -StartupType Automatic -ErrorAction Stop
                $serviceCreated = $true
                Write-Host "✅ Service created using PowerShell" -ForegroundColor Green
            } catch {
                Write-Host "   PowerShell method failed, trying manual creation..." -ForegroundColor Gray
            }
        }
        
        # Method 3: Manual service creation
        if (-not $serviceCreated) {
            try {
                $serviceArgs = @(
                    "create", $ServiceName,
                    "binPath=", $servicePath,
                    "start=", "auto",
                    "DisplayName=", "Security Manager Agent",
                    "Description=", "Security Manager monitoring and protection agent"
                )
                & sc.exe @serviceArgs
                if ($LASTEXITCODE -eq 0) {
                    $serviceCreated = $true
                    Write-Host "✅ Service created manually" -ForegroundColor Green
                }
            } catch {
                throw "Failed to create Windows service using all methods"
            }
        }
        
        if (-not $serviceCreated) {
            throw "Failed to create Windows service"
        }

        # Step 7: Start the service (90%)
        Write-ProgressBar -Activity "Installing Security Manager" -Status "Starting service..." -PercentComplete 90
        
        # Start the service
        Write-Host "🚀 Starting service..." -ForegroundColor Blue
        Start-Service -Name $ServiceName -ErrorAction Stop
        Start-Sleep 3

        # Step 8: Verify installation (100%)
        Write-ProgressBar -Activity "Installing Security Manager" -Status "Verifying installation..." -PercentComplete 100
        
        # Test the installation
        Write-Host "🧪 Verifying installation..." -ForegroundColor Blue
        
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
            throw "Service failed to start"
        }

        # Clear progress
        Write-Progress -Completed

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
        Write-Host "🌐 Web Interfaces:" -ForegroundColor Blue
        Write-Host "  NATS Monitor: http://$($IngestUrl.Replace(':9002', ':8222'))"
        Write-Host "  ClickHouse UI: http://$($IngestUrl.Replace(':9002', ':8123'))"
        Write-Host ""
        Write-Host "📚 Documentation: https://github.com/mulutu/security-manager/blob/main/DEPLOYMENT_MANUAL.md" -ForegroundColor Cyan
        
    } catch {
        Write-Progress -Completed
        Write-Host ""
        Write-Host "❌ Installation failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        Write-Host "🔧 Troubleshooting:" -ForegroundColor Yellow
        Write-Host "   1. Check internet connection" -ForegroundColor White
        Write-Host "   2. Ensure antivirus is not blocking the installation" -ForegroundColor White
        Write-Host "   3. Try manual installation: git clone https://github.com/mulutu/security-manager.git" -ForegroundColor White
        Write-Host "   4. Check logs: Get-EventLog -LogName Application -Newest 10" -ForegroundColor White
        Write-Host ""
        Write-Host "📞 Need help? Check: https://github.com/mulutu/security-manager/blob/main/DEPLOYMENT_MANUAL.md" -ForegroundColor Cyan
        exit 1
    }
}

# Main execution
if ($Help) {
    Write-Host "Security Manager Agent Installer" -ForegroundColor Green
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  irm https://raw.githubusercontent.com/mulutu/security-manager/main/installer/install.ps1 | iex" -ForegroundColor White
    Write-Host "  irm https://raw.githubusercontent.com/mulutu/security-manager/main/installer/install.ps1 | iex; Install-SM -Token 'your_token' -OrgId 'your_org'" -ForegroundColor White
    Write-Host ""
    Write-Host "Parameters:" -ForegroundColor Yellow
    Write-Host "  -Token     : Authentication token (default: sm_tok_demo123)" -ForegroundColor White
    Write-Host "  -OrgId     : Organization ID (default: demo)" -ForegroundColor White
    Write-Host "  -IngestUrl : Ingest service URL (default: 178.79.139.38:9002)" -ForegroundColor White
    Write-Host "  -Help      : Show this help message" -ForegroundColor White
    exit 0
}

# Auto-install if no parameters provided
if ($PSBoundParameters.Count -eq 0) {
    Install-SM
} else {
    Install-SM -Token $Token -OrgId $OrgId -IngestUrl $IngestUrl -InstallDir $InstallDir -ServiceName $ServiceName
} 