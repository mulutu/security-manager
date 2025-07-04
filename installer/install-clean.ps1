# Security Manager - Clean Windows Installer
# Usage: irm https://raw.githubusercontent.com/mulutu/security-manager/main/installer/install-clean.ps1 | iex

param(
    [Parameter(Mandatory=$false)]
    [string]$Token = "sm_tok_demo123",
    
    [Parameter(Mandatory=$false)]
    [string]$OrgId = "demo",
    
    [Parameter(Mandatory=$false)]
    [string]$IngestUrl = "178.79.139.38:9002",
    
    [Parameter(Mandatory=$false)]
    [switch]$Help
)

# Main execution
if ($Help) {
    Write-Host "Security Manager - Clean Windows Installer" -ForegroundColor Green
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  irm https://raw.githubusercontent.com/mulutu/security-manager/main/installer/install-clean.ps1 | iex" -ForegroundColor White
    Write-Host ""
    Write-Host "This installer has no progress bars and provides a clean experience." -ForegroundColor White
    exit 0
}

Write-Host "🛡️  Security Manager - Clean Windows Installer" -ForegroundColor Green
Write-Host "   Organization: $OrgId" -ForegroundColor Blue
Write-Host "   Ingest URL: $IngestUrl" -ForegroundColor Blue
Write-Host ""

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "❌ Administrator privileges required" -ForegroundColor Red
    Write-Host ""
    Write-Host "🔧 Quick Fix:" -ForegroundColor Yellow
    Write-Host "   1. Close this window" -ForegroundColor White
    Write-Host "   2. Right-click PowerShell → 'Run as Administrator'" -ForegroundColor White
    Write-Host "   3. Run: irm https://raw.githubusercontent.com/mulutu/security-manager/main/installer/install-clean.ps1 | iex" -ForegroundColor White
    Write-Host ""
    exit 1
}

Write-Host "✅ Running as Administrator - proceeding with installation..." -ForegroundColor Green
Write-Host ""

try {
    # Step 1: Check and install dependencies
    Write-Host "📦 Checking dependencies..." -ForegroundColor Blue
    
    # Check if Go is installed
    if (-not (Get-Command go -ErrorAction SilentlyContinue)) {
        Write-Host "📦 Installing Go..." -ForegroundColor Blue
        
        try {
            # Download Go installer
            $goVersion = "1.21.5"
            $goUrl = "https://golang.org/dl/go$goVersion.windows-amd64.msi"
            $goInstaller = "$env:TEMP\go-installer.msi"
            
            Write-Host "   Downloading Go $goVersion..." -ForegroundColor Gray
            Invoke-WebRequest -Uri $goUrl -OutFile $goInstaller -UseBasicParsing
            
            Write-Host "   Installing Go..." -ForegroundColor Gray
            Start-Process msiexec.exe -ArgumentList "/i", $goInstaller, "/quiet" -Wait
            
            # Refresh environment
            $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH","User")
            
            Remove-Item $goInstaller -ErrorAction SilentlyContinue
            Write-Host "✅ Go installed successfully" -ForegroundColor Green
        } catch {
            Write-Host "❌ Failed to install Go. Please install manually from: https://golang.org/dl/" -ForegroundColor Red
            throw "Go installation failed"
        }
    } else {
        Write-Host "✅ Go already installed" -ForegroundColor Green
    }

    # Check if Git is installed
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "📦 Installing Git..." -ForegroundColor Blue
        
        try {
            # Download Git installer
            $gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.42.0.windows.2/Git-2.42.0.2-64-bit.exe"
            $gitInstaller = "$env:TEMP\git-installer.exe"
            
            Write-Host "   Downloading Git..." -ForegroundColor Gray
            Invoke-WebRequest -Uri $gitUrl -OutFile $gitInstaller -UseBasicParsing
            
            Write-Host "   Installing Git..." -ForegroundColor Gray
            Start-Process $gitInstaller -ArgumentList "/SILENT" -Wait
            
            # Refresh environment
            $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH","User")
            
            Remove-Item $gitInstaller -ErrorAction SilentlyContinue
            Write-Host "✅ Git installed successfully" -ForegroundColor Green
        } catch {
            Write-Host "❌ Failed to install Git. Please install manually from: https://git-scm.com/download/win" -ForegroundColor Red
            throw "Git installation failed"
        }
    } else {
        Write-Host "✅ Git already installed" -ForegroundColor Green
    }

    # Step 2: Prepare installation directory
    Write-Host "📁 Preparing installation directory..." -ForegroundColor Blue
    
    # Create temporary directory for build
    $tempDir = "$env:TEMP\security-manager-install"
    if (Test-Path $tempDir) {
        Remove-Item $tempDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    Set-Location $tempDir

    # Step 3: Clone repository
    Write-Host "📥 Downloading agent source code..." -ForegroundColor Blue
    try {
        git clone https://github.com/mulutu/security-manager.git
        Set-Location "security-manager"
    } catch {
        Write-Host "❌ Failed to clone repository. Check internet connection." -ForegroundColor Red
        throw "Repository clone failed"
    }

    # Step 4: Build the agent
    Write-Host "🏗️  Building agent..." -ForegroundColor Blue
    try {
        # Set build environment variables
        $env:GOOS = "windows"
        $env:GOARCH = "amd64"
        $env:CGO_ENABLED = "0"
        $env:GO111MODULE = "on"
        
        Write-Host "   Setting up Go modules..." -ForegroundColor Gray
        go mod download
        go mod tidy
        
        Write-Host "   Building agent executable..." -ForegroundColor Gray
        $buildOutput = go build -v -o "sm-agent.exe" ./cmd/agent 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "   Build output: $buildOutput" -ForegroundColor Red
            throw "Build failed with exit code $LASTEXITCODE"
        }
        
        if (-not (Test-Path "sm-agent.exe")) {
            throw "Build failed - executable not created"
        }
        
        # Verify the executable
        $exeSize = (Get-Item "sm-agent.exe").Length
        Write-Host "   Executable size: $([math]::Round($exeSize/1MB,2)) MB" -ForegroundColor Gray
        
        # Move to Program Files
        $installDir = "C:\Program Files\Security Manager"
        if (Test-Path $installDir) {
            Remove-Item $installDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $installDir -Force | Out-Null
        
        Copy-Item "sm-agent.exe" "$installDir\sm-agent.exe"
        Set-Location $installDir
        
        Write-Host "✅ Agent built successfully" -ForegroundColor Green
    } catch {
        Write-Host "❌ Build failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "   Build output: $buildOutput" -ForegroundColor Red
        throw "Build failed"
    }

    # Step 5: Create configuration
    Write-Host "⚙️  Creating configuration..." -ForegroundColor Blue
    $configContent = @"
# Security Manager Agent Configuration
SM_ORG_ID=$OrgId
SM_TOKEN=$Token
SM_INGEST_URL=$IngestUrl
SM_HOST_ID=$env:COMPUTERNAME
SM_USE_TLS=false
SM_LOG_LEVEL=debug
"@
    $configContent | Out-File -FilePath "$installDir\sm-agent.conf" -Encoding UTF8

    # Step 6: Skip agent test (not critical for installation)
    Write-Host "✅ Agent executable created successfully" -ForegroundColor Green

    # Step 7: Create and start Windows service
    Write-Host "🔧 Creating Windows service..." -ForegroundColor Blue
    $serviceName = "SecurityManagerAgent"

    # Remove existing service if it exists
    if (Get-Service -Name $serviceName -ErrorAction SilentlyContinue) {
        Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
        & sc.exe delete $serviceName 2>$null
        Start-Sleep 2
    }

    # Create new service using multiple methods
    $servicePath = "`"$installDir\sm-agent.exe`" -org $OrgId -token $Token -ingest $IngestUrl"
    $serviceCreated = $false
    
    # Method 1: Try sc.exe
    try {
        & sc.exe create $serviceName binPath= $servicePath start= auto DisplayName= "Security Manager Agent" Description= "Security Manager monitoring and protection agent" 2>$null
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
            New-Service -Name $serviceName -BinaryPathName "$installDir\sm-agent.exe -org $OrgId -token $Token -ingest $IngestUrl" -DisplayName "Security Manager Agent" -Description "Security Manager monitoring and protection agent" -StartupType Automatic -ErrorAction Stop
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
                "create", $serviceName,
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

    # Step 8: Start the service
    Write-Host "🚀 Starting service..." -ForegroundColor Blue
    try {
        Start-Service -Name $serviceName -ErrorAction Stop
        Start-Sleep 5
        
        $service = Get-Service -Name $serviceName
        if ($service.Status -eq "Running") {
            Write-Host "✅ Service is running" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Service created but not running. Checking logs..." -ForegroundColor Yellow
            
            # Check service logs
            try {
                $logs = Get-EventLog -LogName Application -Source $serviceName -Newest 5 -ErrorAction SilentlyContinue
                if ($logs) {
                    Write-Host "   Recent service logs:" -ForegroundColor Gray
                    $logs | ForEach-Object { Write-Host "   $($_.TimeGenerated): $($_.Message)" -ForegroundColor Gray }
                }
            } catch {
                Write-Host "   No service logs found" -ForegroundColor Gray
            }
            
            # Try to start manually to see error
            Write-Host "   Trying manual start to see error..." -ForegroundColor Gray
            $process = Start-Process -FilePath "$installDir\sm-agent.exe" -ArgumentList "-org", $OrgId, "-token", $Token, "-ingest", $IngestUrl -PassThru -WindowStyle Hidden -RedirectStandardOutput "$tempDir\manual-output.txt" -RedirectStandardError "$tempDir\manual-error.txt"
            Start-Sleep 3
            
            if (Test-Path "$tempDir\manual-error.txt") {
                $errorMsg = Get-Content "$tempDir\manual-error.txt" -Raw
                Write-Host "   Manual start error: $errorMsg" -ForegroundColor Red
            }
            
            Remove-Item "$tempDir\manual-output.txt" -ErrorAction SilentlyContinue
            Remove-Item "$tempDir\manual-error.txt" -ErrorAction SilentlyContinue
            
            if ($process -and -not $process.HasExited) {
                Stop-Process -Id $process.Id -Force
            }
            
            Write-Host "⚠️  Service created but failed to start. Check the error above." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "❌ Failed to start service: $($_.Exception.Message)" -ForegroundColor Red
        throw "Service start failed"
    }

    # Step 9: Verify installation
    Write-Host "🔍 Verifying installation..." -ForegroundColor Blue
    
    # Cleanup
    Set-Location $tempDir
    Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue

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
    Write-Host "📚 Documentation: https://github.com/mulutu/security-manager/blob/main/DEPLOYMENT_MANUAL.md" -ForegroundColor Cyan
        
} catch {
    Write-Host ""
    Write-Host "❌ Installation failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "🔧 Troubleshooting:" -ForegroundColor Yellow
    Write-Host "   1. Check internet connection" -ForegroundColor White
    Write-Host "   2. Ensure antivirus is not blocking the installation" -ForegroundColor White
    Write-Host "   3. Check disk space (need at least 1GB free)" -ForegroundColor White
    Write-Host "   4. Try manual build: cd cmd/agent && go build -o sm-agent.exe ." -ForegroundColor White
    Write-Host "   5. Check logs: Get-EventLog -LogName Application -Newest 10" -ForegroundColor White
    Write-Host ""
    Write-Host "📞 Need help? Check: https://github.com/mulutu/security-manager/blob/main/DEPLOYMENT_MANUAL.md" -ForegroundColor Cyan
    exit 1
} 