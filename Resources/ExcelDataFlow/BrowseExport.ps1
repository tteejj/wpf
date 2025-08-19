# BrowseExport.ps1 - Quick export with folder browser

param(
    [string]$Format = "TXT"            # Default to TXT for readability
)

$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "=== Quick Export with Folder Browser ===" -ForegroundColor Cyan
Write-Host "This will export data and let you choose the project folder." -ForegroundColor Gray
Write-Host ""

# Simply call RunTextExport with BrowseFolder flag
& "$PSScriptRoot\RunTextExport.ps1" -Format $Format -BrowseFolder