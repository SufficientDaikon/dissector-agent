# install.ps1 — Dissector Installer for Windows (Claude Code)
# Run: .\install.ps1

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "🔬 Installing Dissector (Claude Code multi-agent system)..." -ForegroundColor Cyan
Write-Host ""

# Determine paths
$claudeDir = Join-Path $env:USERPROFILE ".claude"
$agentsSrc = Join-Path $PSScriptRoot ".claude\agents"
$skillsSrc = Join-Path $PSScriptRoot ".claude\skills"
$commandsSrc = Join-Path $PSScriptRoot ".claude\commands"

# Verify sources exist
if (-not ((Test-Path $agentsSrc) -and (Test-Path $skillsSrc) -and (Test-Path $commandsSrc))) {
    Write-Host "❌ Error: .claude\ sources not found under $PSScriptRoot" -ForegroundColor Red
    Write-Host "   Make sure you're running this from the dissector-agent repository root." -ForegroundColor Yellow
    exit 1
}

# Warn (don't fail) if the Claude Code CLI isn't on PATH
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Host "⚠️  Claude Code CLI ('claude') not found on PATH." -ForegroundColor Yellow
    Write-Host "   Install it first: https://code.claude.com/docs — the files will still be copied." -ForegroundColor Yellow
    Write-Host ""
}

New-Item -Path (Join-Path $claudeDir "agents") -ItemType Directory -Force | Out-Null
New-Item -Path (Join-Path $claudeDir "skills") -ItemType Directory -Force | Out-Null
New-Item -Path (Join-Path $claudeDir "commands") -ItemType Directory -Force | Out-Null

# Copy agents
Get-ChildItem -Path $agentsSrc -Filter *.md | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination (Join-Path $claudeDir "agents\$($_.Name)") -Force
    Write-Host "✅ Installed agent   $($_.Name)" -ForegroundColor Green
}

# Copy skills (each skill is a directory; copy it whole so bundled reference files survive)
Get-ChildItem -Path $skillsSrc -Directory | ForEach-Object {
    $dest = Join-Path $claudeDir "skills\$($_.Name)"
    if (Test-Path $dest) { Remove-Item -Path $dest -Recurse -Force }
    Copy-Item -Path $_.FullName -Destination $dest -Recurse -Force
    Write-Host "✅ Installed skill   $($_.Name)" -ForegroundColor Green
}

# Copy commands
Get-ChildItem -Path $commandsSrc -Filter *.md | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination (Join-Path $claudeDir "commands\$($_.Name)") -Force
    Write-Host "✅ Installed command /$($_.BaseName)" -ForegroundColor Green
}

Write-Host ""
Write-Host "🎉 Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "To use, open any Claude Code session and run:" -ForegroundColor White
Write-Host "  /dissect C:\path\to\codebase" -ForegroundColor Yellow
Write-Host ""
Write-Host "Or launch a dedicated session:" -ForegroundColor White
Write-Host "  claude --agent dissector" -ForegroundColor Yellow
Write-Host ""
Write-Host "To uninstall, remove:" -ForegroundColor White
Write-Host "  $claudeDir\agents\dissector.md and dissection-*.md" -ForegroundColor Gray
Write-Host "  $claudeDir\skills\dissect and dissection-standards" -ForegroundColor Gray
Write-Host "  $claudeDir\commands\dissect.md" -ForegroundColor Gray
Write-Host ""
