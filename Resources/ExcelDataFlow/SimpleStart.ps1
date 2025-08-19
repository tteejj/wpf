# Simple Excel Data Mapping - Actually Usable Version
Clear-Host

Write-Host "=== Excel Data Flow Mapping ===" -ForegroundColor Cyan
Write-Host ""

# Input Configuration
Write-Host "STEP 1: Input Configuration" -ForegroundColor Yellow
$sourceFile = Read-Host "Source Excel File [C:\data\source.xlsx]"
if ([string]::IsNullOrEmpty($sourceFile)) { $sourceFile = "C:\data\source.xlsx" }

$sourceSheet = Read-Host "Source Sheet [SVI-CAS]"
if ([string]::IsNullOrEmpty($sourceSheet)) { $sourceSheet = "SVI-CAS" }

$destFile = Read-Host "Destination Excel File [C:\data\output.xlsx]"
if ([string]::IsNullOrEmpty($destFile)) { $destFile = "C:\data\output.xlsx" }

$destSheet = Read-Host "Destination Sheet [Output]"
if ([string]::IsNullOrEmpty($destSheet)) { $destSheet = "Output" }

Write-Host ""
Write-Host "Configuration:" -ForegroundColor Green
Write-Host "  Source: $sourceFile [$sourceSheet]"
Write-Host "  Destination: $destFile [$destSheet]"
Write-Host ""

# Field Mappings
$fields = @{
    "RequestDate" = @{ Source = "W23"; Dest = "" }
    "AuditType" = @{ Source = "W78"; Dest = "" }
    "AuditorName" = @{ Source = "W10"; Dest = "" }
    "TPName" = @{ Source = "W3"; Dest = "" }
    "TPEmailAddress" = @{ Source = "X3"; Dest = "" }
    "TPPhoneNumber" = @{ Source = "Y3"; Dest = "" }
    "CorporateContact" = @{ Source = "W5"; Dest = "" }
    "CorporateContactEmail" = @{ Source = "X5"; Dest = "" }
    "CorporateContactPhone" = @{ Source = "Y5"; Dest = "" }
    "SiteName" = @{ Source = "W7"; Dest = "" }
    "SiteAddress" = @{ Source = "W8"; Dest = "" }
    "SiteCity" = @{ Source = "W9"; Dest = "" }
    "SiteState" = @{ Source = "X9"; Dest = "" }
    "SiteZip" = @{ Source = "Y9"; Dest = "" }
    "SiteCountry" = @{ Source = "Z9"; Dest = "" }
    "AttentionContact" = @{ Source = "W11"; Dest = "" }
    "AttentionContactEmail" = @{ Source = "X11"; Dest = "" }
    "AttentionContactPhone" = @{ Source = "Y11"; Dest = "" }
    "TaxID" = @{ Source = "W13"; Dest = "" }
    "DUNS" = @{ Source = "X13"; Dest = "" }
    "CASNumber" = @{ Source = "G17"; Dest = "" }
    "AssetName" = @{ Source = "H17"; Dest = "" }
    "SerialNumber" = @{ Source = "I17"; Dest = "" }
    "ModelNumber" = @{ Source = "J17"; Dest = "" }
    "ManufacturerName" = @{ Source = "K17"; Dest = "" }
    "InstallDate" = @{ Source = "L17"; Dest = "" }
    "Capacity" = @{ Source = "M17"; Dest = "" }
    "CapacityUnit" = @{ Source = "N17"; Dest = "" }
    "TankType" = @{ Source = "O17"; Dest = "" }
    "Product" = @{ Source = "P17"; Dest = "" }
    "LeakDetection" = @{ Source = "Q17"; Dest = "" }
    "Piping" = @{ Source = "R17"; Dest = "" }
    "Monitoring" = @{ Source = "S17"; Dest = "" }
    "Status" = @{ Source = "T17"; Dest = "" }
    "Comments" = @{ Source = "U17"; Dest = "" }
    "ComplianceDate" = @{ Source = "W25"; Dest = "" }
    "NextInspectionDate" = @{ Source = "W27"; Dest = "" }
    "CertificationNumber" = @{ Source = "W29"; Dest = "" }
    "InspectorName" = @{ Source = "W31"; Dest = "" }
    "InspectorLicense" = @{ Source = "W33"; Dest = "" }
}

Write-Host "STEP 2: Configure Field Mappings" -ForegroundColor Yellow
Write-Host "Press Enter to use default, or type new value" -ForegroundColor Gray
Write-Host ""

$fieldNames = $fields.Keys | Sort-Object
$currentField = 0

while ($currentField -lt $fieldNames.Count) {
    $fieldName = $fieldNames[$currentField]
    $currentSource = $fields[$fieldName].Source
    $currentDest = $fields[$fieldName].Dest
    
    Clear-Host
    Write-Host "=== Excel Data Flow Mapping ===" -ForegroundColor Cyan
    Write-Host "Field $($currentField + 1) of $($fieldNames.Count)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Current Field: $fieldName" -ForegroundColor Green
    Write-Host ""
    
    # Show source cell
    Write-Host "Source Cell [$currentSource]: " -NoNewline
    $newSource = Read-Host
    if (![string]::IsNullOrEmpty($newSource)) {
        $fields[$fieldName].Source = $newSource
    }
    
    # Show dest cell
    Write-Host "Destination Cell [$currentDest]: " -NoNewline
    $newDest = Read-Host
    if (![string]::IsNullOrEmpty($newDest)) {
        $fields[$fieldName].Dest = $newDest
    }
    
    Write-Host ""
    Write-Host "Controls: [N]ext, [P]revious, [S]ave & Exit, [Q]uit" -ForegroundColor Gray
    $action = Read-Host "Action"
    
    switch ($action.ToUpper()) {
        "P" { 
            if ($currentField -gt 0) { $currentField-- }
        }
        "S" {
            # Save configuration
            $config = @{
                Source = @{
                    File = $sourceFile
                    Sheet = $sourceSheet
                }
                Destination = @{
                    File = $destFile
                    Sheet = $destSheet
                }
                FieldMappings = $fields
                Timestamp = (Get-Date).ToString()
            }
            
            $configPath = "$PSScriptRoot\_Config\excel_mapping.json"
            $configDir = Split-Path $configPath -Parent
            if (!(Test-Path $configDir)) {
                New-Item -ItemType Directory -Path $configDir -Force | Out-Null
            }
            
            $config | ConvertTo-Json -Depth 10 | Set-Content $configPath
            
            Clear-Host
            Write-Host "=== Configuration Saved ===" -ForegroundColor Green
            Write-Host "File: $configPath" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Field Mappings Configured:" -ForegroundColor Yellow
            
            foreach ($field in $fieldNames) {
                $src = $fields[$field].Source
                $dst = $fields[$field].Dest
                Write-Host "  $field : $src -> $dst"
            }
            
            Write-Host ""
            Write-Host "Ready for Excel operations!" -ForegroundColor Green
            return
        }
        "Q" {
            Write-Host "Exiting without saving..." -ForegroundColor Red
            return
        }
        default {
            $currentField++
        }
    }
}

Write-Host ""
Write-Host "All fields configured! Use 'S' to save." -ForegroundColor Green