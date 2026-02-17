$ErrorActionPreference = 'SilentlyContinue'

$port = 3000
$logFile = "$env:USERPROFILE\opentunnel_url.txt"

Write-Host "Starting webhook server on port $port..."

# Start the webhook server in background
$serverJob = Start-Job -ScriptBlock {
    param($p)
    Set-Location "C:\Users\Julian\Documents\opentunnel\skills\opentunnel-connect\scripts"
    node server.js $p 2>&1
} -ArgumentList $port

# Wait for tunnel
Start-Sleep -Seconds 20

# Check for URL in the job output
$output = Receive-Job -Job $serverJob
Write-Host $output

# Try to get the URL
if ($output -match '([a-zA-Z0-9.-]+\.lhr\.life)') {
    $url = $Matches[1]
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Server running! Share this URL:" -ForegroundColor Green
    Write-Host $url -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Command for remote server:"
    Write-Host "curl -fsSL `"https://raw.githubusercontent.com/julianponguta/opentunnel/main/skills/opentunnel-connect/scripts/remote.sh`" | sudo bash -s -- $url 60 root"
} else {
    Write-Host "Waiting for tunnel..." -ForegroundColor Yellow
}

# Keep running
while ($true) { Start-Sleep -Seconds 60 }
