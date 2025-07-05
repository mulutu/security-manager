@echo off
echo Security Manager - Cross-Platform Binary Builder
echo ================================================

REM Create build directory
if not exist "build" mkdir build
cd build

REM Clean previous builds
del /Q sm-agent-* 2>nul
del /Q *.sha256 2>nul

echo.
echo Building Linux AMD64 binary...
set GOOS=linux
set GOARCH=amd64
set CGO_ENABLED=0
go build -ldflags="-s -w -X main.version=v1.0.4" -o sm-agent-linux-amd64 ..\cmd\agent
if %ERRORLEVEL% neq 0 (
    echo ERROR: Failed to build Linux AMD64 binary
    goto :error
)

echo Building Linux ARM64 binary...
set GOARCH=arm64
go build -ldflags="-s -w -X main.version=v1.0.4" -o sm-agent-linux-arm64 ..\cmd\agent
if %ERRORLEVEL% neq 0 (
    echo ERROR: Failed to build Linux ARM64 binary
    goto :error
)

echo Building Linux ARM binary...
set GOARCH=arm
set GOARM=7
go build -ldflags="-s -w -X main.version=v1.0.4" -o sm-agent-linux-arm ..\cmd\agent
if %ERRORLEVEL% neq 0 (
    echo ERROR: Failed to build Linux ARM binary
    goto :error
)

echo.
echo Generating SHA256 checksums...
powershell -Command "Get-FileHash sm-agent-linux-amd64 -Algorithm SHA256 | ForEach-Object { $_.Hash.ToLower() + '  ' + $_.Path.Split('\')[-1] }" > sm-agent-linux-amd64.sha256
powershell -Command "Get-FileHash sm-agent-linux-arm64 -Algorithm SHA256 | ForEach-Object { $_.Hash.ToLower() + '  ' + $_.Path.Split('\')[-1] }" > sm-agent-linux-arm64.sha256
powershell -Command "Get-FileHash sm-agent-linux-arm -Algorithm SHA256 | ForEach-Object { $_.Hash.ToLower() + '  ' + $_.Path.Split('\')[-1] }" > sm-agent-linux-arm.sha256

echo.
echo Build complete! Files created:
dir sm-agent-* /B
echo.
echo Checksums:
type sm-agent-linux-amd64.sha256
type sm-agent-linux-arm64.sha256
type sm-agent-linux-arm.sha256

echo.
echo SUCCESS: All binaries built successfully!
cd ..
goto :end

:error
echo.
echo FAILED: Build process failed!
cd ..
exit /b 1

:end 