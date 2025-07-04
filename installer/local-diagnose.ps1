# Security Manager - Local Build Diagnostic
# Run this script from the security-manager directory

Write-Host "🔍 Security Manager - Local Build Diagnostic" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
Write-Host ""

# Check if we're in the right directory
if (-not (Test-Path "go.mod")) {
    Write-Host "❌ go.mod not found. Please run this script from the security-manager root directory." -ForegroundColor Red
    Write-Host "   Current directory: $(Get-Location)" -ForegroundColor Gray
    exit 1
}

Write-Host "✅ Found go.mod in current directory" -ForegroundColor Green
Write-Host ""

# Check Go installation
Write-Host "🐹 Go Installation:" -ForegroundColor Blue
try {
    $goVersion = go version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Go installed: $goVersion" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Go not found or not working" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "  ❌ Go not installed" -ForegroundColor Red
    exit 1
}

# Check if cmd/agent exists
Write-Host "📁 Directory Structure:" -ForegroundColor Blue
if (Test-Path "cmd/agent") {
    Write-Host "  ✅ cmd/agent directory found" -ForegroundColor Green
    if (Test-Path "cmd/agent/main.go") {
        Write-Host "  ✅ main.go found in cmd/agent" -ForegroundColor Green
    } else {
        Write-Host "  ❌ main.go not found in cmd/agent" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "  ❌ cmd/agent directory not found" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Try to build
Write-Host "🏗️  Build Test:" -ForegroundColor Blue
try {
    # Set build environment variables
    $env:GOOS = "windows"
    $env:GOARCH = "amd64"
    $env:CGO_ENABLED = "0"
    $env:GO111MODULE = "on"
    
    Write-Host "  Downloading dependencies..." -ForegroundColor Gray
    go mod download 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ❌ Failed to download dependencies" -ForegroundColor Red
        exit 1
    }
    Write-Host "  ✅ Dependencies downloaded" -ForegroundColor Green
    
    Write-Host "  Building agent..." -ForegroundColor Gray
    $buildOutput = go build -v -o "sm-agent.exe" ./cmd/agent 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Build successful!" -ForegroundColor Green
        
        # Check executable
        if (Test-Path "sm-agent.exe") {
            $exeSize = (Get-Item "sm-agent.exe").Length
            Write-Host "  Executable size: $([math]::Round($exeSize/1MB,2)) MB" -ForegroundColor Gray
            
            # Test executable
            Write-Host "  Testing executable..." -ForegroundColor Gray
            $process = Start-Process -FilePath ".\sm-agent.exe" -ArgumentList "-help" -PassThru -WindowStyle Hidden -RedirectStandardOutput "test-output.txt" -RedirectStandardError "test-error.txt"
            Start-Sleep 2
            
            if (Test-Path "test-output.txt") {
                $output = Get-Content "test-output.txt" -Raw
                Write-Host "  ✅ Executable runs successfully" -ForegroundColor Green
                Remove-Item "test-output.txt" -ErrorAction SilentlyContinue
                Remove-Item "test-error.txt" -ErrorAction SilentlyContinue
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
        exit 1
    }
} catch {
    Write-Host "  ❌ Build test failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "🎉 Build diagnostic completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "🔧 Next Steps:" -ForegroundColor Blue
Write-Host "  1. The agent builds successfully" -ForegroundColor White
Write-Host "  2. Try running: .\sm-agent.exe -org demo -token sm_tok_demo123 -ingest 178.79.139.38:9002 -log-level debug" -ForegroundColor White
Write-Host "  3. If that works, create the Windows service manually" -ForegroundColor White
Write-Host ""
Write-Host "📞 Need help? Check: https://github.com/mulutu/security-manager/blob/main/DEPLOYMENT_MANUAL.md" -ForegroundColor Cyan 