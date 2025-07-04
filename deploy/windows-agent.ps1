# Windows Agent Setup Script for Security Manager
# Run this on your Windows laptop to connect to the remote VM

param(
    [string]$IngestURL = "178.79.139.38:9002",
    [string]$OrgID = "demo", 
    [string]$Token = "sm_tok_demo123",
    [string]$HostID = $env:COMPUTERNAME,
    [string]$LogFile = "C:\Windows\Temp\sm-test.log",
    [switch]$Build,
    [switch]$Test
)

Write-Host "🔧 Security Manager Windows Agent Setup" -ForegroundColor Green
Write-Host "Connecting to: $IngestURL" -ForegroundColor Yellow

# Check if Go is installed
if (-not (Get-Command go -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Go not found. Please install Go from https://golang.org/dl/" -ForegroundColor Red
    exit 1
}

# Navigate to project root
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

if ($Build) {
    Write-Host "🏗️  Building Windows agent..." -ForegroundColor Blue
    
    # Build the agent
    Set-Location "cmd/agent"
    $env:GOOS = "windows"
    $env:GOARCH = "amd64"
    go build -o "../../sm-agent.exe" .
    Set-Location $ProjectRoot
    
    if (Test-Path "sm-agent.exe") {
        Write-Host "✅ Agent built successfully: sm-agent.exe" -ForegroundColor Green
    } else {
        Write-Host "❌ Build failed" -ForegroundColor Red
        exit 1
    }
}

if ($Test) {
    Write-Host "🧪 Testing connection to remote ingest service..." -ForegroundColor Blue
    
    # Test connection using Go test tool
    Set-Location "tools/test_auth"
    $env:SM_INGEST_URL = $IngestURL
    go run main.go
    Set-Location $ProjectRoot
}

# Create a test log file
if (-not (Test-Path $LogFile)) {
    Write-Host "📝 Creating test log file: $LogFile" -ForegroundColor Blue
    "Test log entry from Windows agent at $(Get-Date)" | Out-File -FilePath $LogFile -Encoding UTF8
}

# Start the agent
Write-Host "🚀 Starting Windows agent..." -ForegroundColor Green
Write-Host "   Org ID: $OrgID" -ForegroundColor Gray
Write-Host "   Host ID: $HostID" -ForegroundColor Gray
Write-Host "   Ingest URL: $IngestURL" -ForegroundColor Gray
Write-Host "   Log File: $LogFile" -ForegroundColor Gray
Write-Host ""
Write-Host "Press Ctrl+C to stop the agent" -ForegroundColor Yellow
Write-Host ""

# Add some test log entries in background
Start-Job -ScriptBlock {
    param($LogFile)
    while ($true) {
        "Windows test log entry at $(Get-Date)" | Add-Content -Path $LogFile
        Start-Sleep 30
    }
} -ArgumentList $LogFile | Out-Null

# Run the agent
& ".\sm-agent.exe" -org $OrgID -token $Token -host $HostID -ingest $IngestURL -file $LogFile

Write-Host "🛑 Agent stopped" -ForegroundColor Red 