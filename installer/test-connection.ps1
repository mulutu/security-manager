# Security Manager - Connection Test Script
# Usage: irm https://raw.githubusercontent.com/mulutu/security-manager/main/installer/test-connection.ps1 | iex

Write-Host "🔍 Security Manager - Connection Test" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green
Write-Host ""

$ingestUrl = "178.79.139.38:9002"
$orgId = "demo"
$token = "sm_tok_demo123"

Write-Host "📡 Testing network connectivity..." -ForegroundColor Blue

# Test basic network connectivity
try {
    $parts = $ingestUrl.Split(':')
    $hostname = $parts[0]
    $port = $parts[1]
    
    Write-Host "  Testing connection to $hostname:$port..." -ForegroundColor Gray
    
    # Test TCP connection
    $tcpClient = New-Object System.Net.Sockets.TcpClient
    $connect = $tcpClient.BeginConnect($hostname, $port, $null, $null)
    $wait = $connect.AsyncWaitHandle.WaitOne(5000, $false)
    
    if ($wait) {
        $tcpClient.EndConnect($connect)
        Write-Host "  ✅ TCP connection successful" -ForegroundColor Green
        $tcpClient.Close()
    } else {
        Write-Host "  ❌ TCP connection failed (timeout)" -ForegroundColor Red
    }
} catch {
    Write-Host "  ❌ Network test failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test if the agent can start and connect
Write-Host "🧪 Testing agent connection..." -ForegroundColor Blue

$installDir = "C:\Program Files\Security Manager"
if (Test-Path "$installDir\sm-agent.exe") {
    Write-Host "  Found agent executable at $installDir" -ForegroundColor Gray
    
    # Test agent with timeout
    Write-Host "  Starting agent with 10-second timeout..." -ForegroundColor Gray
    
    $process = Start-Process -FilePath "$installDir\sm-agent.exe" -ArgumentList "-org", $orgId, "-token", $token, "-ingest", $ingestUrl -PassThru -WindowStyle Hidden -RedirectStandardOutput "$env:TEMP\agent-output.txt" -RedirectStandardError "$env:TEMP\agent-error.txt"
    
    # Wait for 10 seconds
    $startTime = Get-Date
    $timeout = 10
    
    while (-not $process.HasExited -and ((Get-Date) - $startTime).TotalSeconds -lt $timeout) {
        Start-Sleep 1
    }
    
    if ($process.HasExited) {
        Write-Host "  Agent exited with code: $($process.ExitCode)" -ForegroundColor Yellow
        
        if (Test-Path "$env:TEMP\agent-error.txt") {
            $errorMsg = Get-Content "$env:TEMP\agent-error.txt" -Raw
            Write-Host "  Error output:" -ForegroundColor Red
            Write-Host $errorMsg -ForegroundColor Red
        }
        
        if (Test-Path "$env:TEMP\agent-output.txt") {
            $output = Get-Content "$env:TEMP\agent-output.txt" -Raw
            Write-Host "  Standard output:" -ForegroundColor Gray
            Write-Host $output -ForegroundColor Gray
        }
    } else {
        Write-Host "  Agent is still running after $timeout seconds" -ForegroundColor Green
        Write-Host "  This suggests the connection is working!" -ForegroundColor Green
        Stop-Process -Id $process.Id -Force
    }
    
    # Cleanup
    Remove-Item "$env:TEMP\agent-output.txt" -ErrorAction SilentlyContinue
    Remove-Item "$env:TEMP\agent-error.txt" -ErrorAction SilentlyContinue
} else {
    Write-Host "  ❌ Agent executable not found at $installDir" -ForegroundColor Red
}

Write-Host ""
Write-Host "🔧 Recommendations:" -ForegroundColor Yellow

if (Test-Path "$env:TEMP\agent-error.txt") {
    $errorMsg = Get-Content "$env:TEMP\agent-error.txt" -Raw
    if ($errorMsg -like "*dial*" -or $errorMsg -like "*connection*") {
        Write-Host "  1. Check if the ingest server is running on 178.79.139.38:9002" -ForegroundColor White
        Write-Host "  2. Check firewall settings on both client and server" -ForegroundColor White
        Write-Host "  3. Verify the server IP address is correct" -ForegroundColor White
    } elseif ($error -like "*authentication*" -or $error -like "*token*") {
        Write-Host "  1. Check if the token 'sm_tok_demo123' is valid" -ForegroundColor White
        Write-Host "  2. Verify the organization ID 'demo' is correct" -ForegroundColor White
        Write-Host "  3. Check if the ingest server is configured to accept this token" -ForegroundColor White
    } else {
        Write-Host "  1. Check the error message above for specific issues" -ForegroundColor White
        Write-Host "  2. Verify the ingest server is running and accessible" -ForegroundColor White
        Write-Host "  3. Check network connectivity and firewall settings" -ForegroundColor White
    }
} else {
    Write-Host "  1. The agent seems to be connecting successfully" -ForegroundColor White
    Write-Host "  2. If the service still fails, check Windows Event Viewer logs" -ForegroundColor White
    Write-Host "  3. Try running the agent manually to see real-time output" -ForegroundColor White
}

Write-Host ""
Write-Host "📞 Need help? Check: https://github.com/mulutu/security-manager/blob/main/DEPLOYMENT_MANUAL.md" -ForegroundColor Cyan 