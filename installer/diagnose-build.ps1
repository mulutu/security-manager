# Security Manager - Build Diagnostic Script
# Usage: irm https://raw.githubusercontent.com/mulutu/security-manager/main/installer/diagnose-build.ps1 | iex

Write-Host "🔍 Security Manager - Build Diagnostic Tool" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
Write-Host ""

# Check system information
Write-Host "📊 System Information:" -ForegroundColor Blue
Write-Host "  OS Version: $([System.Environment]::OSVersion)" -ForegroundColor Gray
Write-Host "  Architecture: $([System.Environment]::GetEnvironmentVariable('PROCESSOR_ARCHITECTURE'))" -ForegroundColor Gray
Write-Host "  PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
Write-Host ""

# Check disk space
Write-Host "💾 Disk Space:" -ForegroundColor Blue
$disk = Get-WmiObject -Class Win32_LogicalDisk | Where-Object {$_.DeviceID -eq "C:"}
$freeGB = [math]::Round($disk.FreeSpace/1GB, 2)
$totalGB = [math]::Round($disk.Size/1GB, 2)
Write-Host "  C: Drive - Free: ${freeGB}GB / Total: ${totalGB}GB" -ForegroundColor Gray
if ($freeGB -lt 1) {
    Write-Host "  ⚠️  Low disk space - need at least 1GB free" -ForegroundColor Yellow
} else {
    Write-Host "  ✅ Sufficient disk space" -ForegroundColor Green
}
Write-Host ""

# Check Go installation
Write-Host "🐹 Go Installation:" -ForegroundColor Blue
try {
    $goVersion = go version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Go installed: $goVersion" -ForegroundColor Green
        
        # Check Go environment
        Write-Host "  Go Environment:" -ForegroundColor Gray
        Write-Host "    GOPATH: $(go env GOPATH)" -ForegroundColor Gray
        Write-Host "    GOROOT: $(go env GOROOT)" -ForegroundColor Gray
        Write-Host "    GOMODCACHE: $(go env GOMODCACHE)" -ForegroundColor Gray
        Write-Host "    GO111MODULE: $(go env GO111MODULE)" -ForegroundColor Gray
    } else {
        Write-Host "  ❌ Go not found or not working" -ForegroundColor Red
    }
} catch {
    Write-Host "  ❌ Go not installed" -ForegroundColor Red
}
Write-Host ""

# Check Git installation
Write-Host "📚 Git Installation:" -ForegroundColor Blue
try {
    $gitVersion = git --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Git installed: $gitVersion" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Git not found or not working" -ForegroundColor Red
    }
} catch {
    Write-Host "  ❌ Git not installed" -ForegroundColor Red
}
Write-Host ""

# Check network connectivity
Write-Host "🌐 Network Connectivity:" -ForegroundColor Blue
try {
    $response = Invoke-WebRequest -Uri "https://github.com" -UseBasicParsing -TimeoutSec 10
    if ($response.StatusCode -eq 200) {
        Write-Host "  ✅ GitHub accessible" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  GitHub returned status: $($response.StatusCode)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ❌ Cannot access GitHub: $($_.Exception.Message)" -ForegroundColor Red
}

try {
    $response = Invoke-WebRequest -Uri "https://golang.org" -UseBasicParsing -TimeoutSec 10
    if ($response.StatusCode -eq 200) {
        Write-Host "  ✅ Go website accessible" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  Go website returned status: $($response.StatusCode)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ❌ Cannot access Go website: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Check if we can clone and build
Write-Host "🏗️  Build Test:" -ForegroundColor Blue
$tempDir = "$env:TEMP\sm-diagnostic"
if (Test-Path $tempDir) {
    Remove-Item $tempDir -Recurse -Force
}
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
Set-Location $tempDir

try {
    Write-Host "  Cloning repository..." -ForegroundColor Gray
    git clone https://github.com/mulutu/security-manager.git 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Repository cloned successfully" -ForegroundColor Green
        
        Set-Location "security-manager"
        
        # Check if go.mod exists
        if (Test-Path "go.mod") {
            Write-Host "  ✅ go.mod found" -ForegroundColor Green
            
            # Try to download dependencies
            Write-Host "  Downloading dependencies..." -ForegroundColor Gray
            go mod download 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  ✅ Dependencies downloaded" -ForegroundColor Green
                
                # Try to build
                Write-Host "  Building agent..." -ForegroundColor Gray
                $env:GOOS = "windows"
                $env:GOARCH = "amd64"
                $env:CGO_ENABLED = "0"
                $env:GO111MODULE = "on"
                
                $buildOutput = go build -v -o "sm-agent.exe" ./cmd/agent 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "  ✅ Build successful!" -ForegroundColor Green
                    
                    # Check executable
                    if (Test-Path "sm-agent.exe") {
                        $exeSize = (Get-Item "sm-agent.exe").Length
                        Write-Host "  Executable size: $([math]::Round($exeSize/1MB,2)) MB" -ForegroundColor Gray
                        
                        # Test executable
                        Write-Host "  Testing executable..." -ForegroundColor Gray
                        $process = Start-Process -FilePath ".\sm-agent.exe" -ArgumentList "-help" -PassThru -WindowStyle Hidden -RedirectStandardOutput "$tempDir\test-output.txt" -RedirectStandardError "$tempDir\test-error.txt"
                        Start-Sleep 2
                        
                        if (Test-Path "$tempDir\test-output.txt") {
                            $output = Get-Content "$tempDir\test-output.txt" -Raw
                            Write-Host "  ✅ Executable runs successfully" -ForegroundColor Green
                        } else {
                            Write-Host "  ⚠️  Executable created but may have issues" -ForegroundColor Yellow
                        }
                    } else {
                        Write-Host "  ❌ Executable not created" -ForegroundColor Red
                    }
                } else {
                    Write-Host "  ❌ Build failed with exit code $LASTEXITCODE" -ForegroundColor Red
                    Write-Host "  Build output:" -ForegroundColor Red
                    Write-Host $buildOutput -ForegroundColor Red
                }
            } else {
                Write-Host "  ❌ Failed to download dependencies" -ForegroundColor Red
            }
        } else {
            Write-Host "  ❌ go.mod not found" -ForegroundColor Red
        }
    } else {
        Write-Host "  ❌ Failed to clone repository" -ForegroundColor Red
    }
} catch {
    Write-Host "  ❌ Build test failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Cleanup
Set-Location $env:TEMP
Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "🔧 Recommendations:" -ForegroundColor Yellow
Write-Host "  1. If Go is missing: Install from https://golang.org/dl/" -ForegroundColor White
Write-Host "  2. If Git is missing: Install from https://git-scm.com/download/win" -ForegroundColor White
Write-Host "  3. If network issues: Check firewall/proxy settings" -ForegroundColor White
Write-Host "  4. If build fails: Check error messages above" -ForegroundColor White
Write-Host "  5. Try the fixed installer: irm https://raw.githubusercontent.com/mulutu/security-manager/main/installer/install-fixed.ps1 | iex" -ForegroundColor White
Write-Host ""
Write-Host "📞 Need help? Check: https://github.com/mulutu/security-manager/blob/main/DEPLOYMENT_MANUAL.md" -ForegroundColor Cyan 