# QuickExport.ps1 - Simple export with file browser

param(
    [string]$Format = "TXT"            # Default to TXT for readability
)

$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "=== Quick Export ===" -ForegroundColor Cyan
Write-Host "Choose where to save the export file." -ForegroundColor Gray
Write-Host ""

# Simply call RunTextExport with BrowseFile flag
& "$PSScriptRoot\RunTextExport.ps1" -Format $Format -BrowseFile