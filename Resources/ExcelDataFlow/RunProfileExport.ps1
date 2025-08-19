# RunProfileExport.ps1 - Simplified export workflow using saved profiles
# Interactive profile selection with file browser integration

param(
    [string]$ProfileName = "",
    [string]$OutputPath = "",
    [string]$FileName = "",
    [switch]$ListProfiles,
    [switch]$Force
)

# Load required classes and services
. "$PSScriptRoot\Services\ConfigurationService.ps1"
. "$PSScriptRoot\Services\ExportProfileService.ps1"
. "$PSScriptRoot\Services\TextExportService.ps1"
. "$PSScriptRoot\Services\DataProcessingService.ps1"
. "$PSScriptRoot\Screens\ProfileSelectionDialog.ps1"
. "$PSScriptRoot\Core\VT100.ps1"

function Write-Header {
    param([string]$Title)
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Blue
    Write-Host "  $Title" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Blue
    Write-Host ""
}

function Write-Step {
    param([string]$Message)
    Write-Host "→ $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ $Message" -ForegroundColor Cyan
}

# Initialize services
$configService = [ConfigurationService]::new()
$profileService = [ExportProfileService]::new($configService)
$textExportService = [TextExportService]::new($configService)
$dataService = [DataProcessingService]::new($configService)

Write-Header "ExcelDataFlow - Profile-Based Export"

# Handle list profiles command
if ($ListProfiles) {
    Write-Step "Available Export Profiles:"
    $profiles = $profileService.GetAllProfiles()
    $profileNames = $profileService.GetProfileNames($true)
    
    if ($profileNames.Count -eq 0) {
        Write-Info "No profiles found. Create profiles using: RunTextExport.ps1 -Interactive"
        exit 0
    }
    
    foreach ($profileName in $profileNames) {
        $profile = $profiles[$profileName]
        $fieldCount = $profile.SelectedFields.Count
        $format = $profile.ExportFormat
        $useCount = $profile.UseCount
        $lastUsed = if ($useCount -gt 0) { " (Last used: $($profile.LastUsed))" } else { "" }
        
        Write-Host "  • $profileName" -ForegroundColor Yellow
        Write-Host "    Format: $format, Fields: $fieldCount$lastUsed" -ForegroundColor Gray
        if ($profile.Description) {
            Write-Host "    Description: $($profile.Description)" -ForegroundColor Gray
        }
        Write-Host ""
    }
    exit 0
}

# Check if we have Excel configuration
Write-Step "Checking Excel configuration..."
$excelConfig = $configService.GetExcelMappings()
if (-not $excelConfig -or -not $excelConfig.SourceFile) {
    Write-Error "No Excel configuration found. Please run Start.ps1 first to configure Excel mappings."
    exit 1
}
Write-Success "Excel configuration found: $($excelConfig.SourceFile)"

# Handle direct profile specification
if ($ProfileName) {
    Write-Step "Loading specified profile: $ProfileName"
    $profileResult = $profileService.LoadProfile($ProfileName)
    if (-not $profileResult.Success) {
        Write-Error $profileResult.Message
        exit 1
    }
    
    $profile = $profileResult.Profile
    Write-Success "Profile loaded: $($profile.SelectedFields.Count) fields, $($profile.ExportFormat) format"
    
    # Determine output path
    if (-not $OutputPath) {
        $OutputPath = $PWD.Path
    }
    
    if (-not $FileName) {
        $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $extension = switch ($profile.ExportFormat.ToLower()) {
            'csv' { '.csv' }
            'tsv' { '.tsv' }
            'json' { '.json' }
            'xml' { '.xml' }
            'txt' { '.txt' }
            default { '.txt' }
        }
        $FileName = "$($ProfileName.ToLower() -replace '[^a-z0-9]', '_')_$timestamp$extension"
    }
    
    $fullOutputPath = Join-Path $OutputPath $FileName
    
} else {
    # Interactive profile selection
    Write-Step "Launching interactive profile selection..."
    
    # Create default profiles if none exist
    $existingProfiles = $profileService.GetProfileNames($false)
    if ($existingProfiles.Count -eq 0) {
        Write-Info "No profiles found. Creating default profiles..."
        # Get available fields from Excel configuration
        $availableFields = @()
        foreach ($fieldName in $excelConfig.FieldMappings.Keys) {
            $availableFields += $fieldName
        }
        $profileService.CreateDefaultProfiles($availableFields)
        Write-Success "Created default profiles"
    }
    
    try {
        $profileDialog = [ProfileSelectionDialog]::new()
        $profileDialog.ShowDialog()
        
        if (-not $profileDialog.DialogResult) {
            Write-Info "Profile selection cancelled"
            exit 0
        }
        
        $exportSettings = $profileDialog.GetExportSettings()
        if (-not $exportSettings.Success) {
            Write-Error $exportSettings.Message
            exit 1
        }
        
        $ProfileName = $exportSettings.ProfileName
        $fullOutputPath = $exportSettings.OutputPath
        $profile = $exportSettings.Profile
        
        Write-Success "Selected profile: $ProfileName"
        Write-Success "Output path: $fullOutputPath"
        
    } catch {
        Write-Error "Failed to show profile selection dialog: $($_.Exception.Message)"
        Write-Info "Falling back to command-line mode. Use -ProfileName parameter or RunTextExport.ps1 -Interactive to create profiles."
        exit 1
    }
}

# Confirm export (unless forced)
if (-not $Force) {
    Write-Host ""
    Write-Info "Export Summary:"
    Write-Host "  Profile: $ProfileName" -ForegroundColor White
    Write-Host "  Format: $($profile.ExportFormat)" -ForegroundColor White
    Write-Host "  Fields: $($profile.SelectedFields.Count)" -ForegroundColor White
    Write-Host "  Output: $fullOutputPath" -ForegroundColor White
    Write-Host ""
    
    $confirmation = Read-Host "Proceed with export? (y/N)"
    if ($confirmation -notmatch '^[Yy]') {
        Write-Info "Export cancelled"
        exit 0
    }
}

# Step 1: Extract data from Excel
Write-Step "Extracting data from Excel..."
$dataResult = $dataService.ExtractData()
if (-not $dataResult.Success) {
    Write-Error "Failed to extract data: $($dataResult.Message)"
    exit 1
}
Write-Success "Extracted $($dataResult.ExtractedData.Count) fields from Excel"

# Step 2: Export to text format
Write-Step "Exporting to $($profile.ExportFormat) format..."
$exportResult = $textExportService.ExportToText(
    $dataResult.ExtractedData,
    $fullOutputPath,
    $profile.ExportFormat,
    $profile.SelectedFields
)

if (-not $exportResult.Success) {
    Write-Error "Failed to export: $($exportResult.Message)"
    exit 1
}

Write-Success "Export completed successfully!"
Write-Info "Output file: $fullOutputPath"
Write-Info "Records exported: $($exportResult.RecordCount)"
Write-Info "Fields exported: $($exportResult.FieldCount)"

# Update profile usage statistics (already done by LoadProfile, but good to mention)
Write-Step "Profile '$ProfileName' usage statistics updated"

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  Export Complete!" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""

# Optionally open the output file or folder
if (Get-Command explorer.exe -ErrorAction SilentlyContinue) {
    $openChoice = Read-Host "Open output folder? (y/N)"
    if ($openChoice -match '^[Yy]') {
        explorer.exe (Split-Path $fullOutputPath -Parent)
    }
}