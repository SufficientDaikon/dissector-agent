# install.ps1 — Dissector Agent Installer for Windows
# Run: .\install.ps1

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "🔬 Installing Dissector Agent..." -ForegroundColor Cyan
Write-Host ""

# Determine paths
$agentsDir = Join-Path $env:USERPROFILE ".copilot\agents"
$sourceFile = Join-Path $PSScriptRoot "agents\dissector.agent.md"
$destFile = Join-Path $agentsDir "dissector.agent.md"

# Verify source file exists
if (-not (Test-Path $sourceFile)) {
    Write-Host "❌ Error: Source file not found at $sourceFile" -ForegroundColor Red
    Write-Host "   Make sure you're running this from the dissector-agent repository root." -ForegroundColor Yellow
    exit 1
}

# Create the agents directory if it doesn't exist
if (-not (Test-Path $agentsDir)) {
    New-Item -Path $agentsDir -ItemType Directory -Force | Out-Null
    Write-Host "✅ Created $agentsDir" -ForegroundColor Green
} else {
    Write-Host "✅ Found existing $agentsDir" -ForegroundColor Green
}

# Copy the agent file
Copy-Item -Path $sourceFile -Destination $destFile -Force
Write-Host "✅ Copied dissector.agent.md to $agentsDir" -ForegroundColor Green

Write-Host ""
Write-Host "🎉 Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Installed files:" -ForegroundColor White
Write-Host "  $destFile" -ForegroundColor Gray
Write-Host ""
Write-Host "To use: Open VS Code Copilot Chat and type:" -ForegroundColor White
Write-Host '  @dissector Dissect /path/to/your/codebase' -ForegroundColor Yellow
Write-Host ""
