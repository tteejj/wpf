# Excel Data Mapping Tool - Simple Menu Version
param(
    [string]$ConfigFile = "_Config\excel_mapping.json"
)

function Show-MainMenu {
    Clear-Host
    Write-Host "=== Excel Data Flow Mapping Tool ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Configure Input Settings" -ForegroundColor Yellow
    Write-Host "2. Set Source Cell Mappings" -ForegroundColor Yellow  
    Write-Host "3. Set Destination Cell Mappings" -ForegroundColor Yellow
    Write-Host "4. View Current Configuration" -ForegroundColor Yellow
    Write-Host "5. Save Configuration" -ForegroundColor Yellow
    Write-Host "6. Load Configuration" -ForegroundColor Yellow
    Write-Host "9. Exit" -ForegroundColor Red
    Write-Host ""
}

function Get-UserChoice {
    param([string]$Prompt = "Choice")
    Write-Host "$Prompt (1-9): " -NoNewline -ForegroundColor Green
    $choice = Read-Host
    return $choice
}

function Set-InputConfiguration {
    param($config)
    
    Clear-Host
    Write-Host "=== Input Configuration ===" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Current Settings:" -ForegroundColor Yellow
    Write-Host "  Source File: $($config.Source.File)"
    Write-Host "  Source Sheet: $($config.Source.Sheet)"
    Write-Host "  Dest File: $($config.Destination.File)"
    Write-Host "  Dest Sheet: $($config.Destination.Sheet)"
    Write-Host ""
    
    Write-Host "Enter new values (press Enter to keep current):" -ForegroundColor Green
    
    Write-Host "Source Excel File [$($config.Source.File)]: " -NoNewline
    $newSourceFile = Read-Host
    if (![string]::IsNullOrEmpty($newSourceFile)) {
        $config.Source.File = $newSourceFile
    }
    
    Write-Host "Source Sheet [$($config.Source.Sheet)]: " -NoNewline
    $newSourceSheet = Read-Host
    if (![string]::IsNullOrEmpty($newSourceSheet)) {
        $config.Source.Sheet = $newSourceSheet
    }
    
    Write-Host "Destination Excel File [$($config.Destination.File)]: " -NoNewline
    $newDestFile = Read-Host
    if (![string]::IsNullOrEmpty($newDestFile)) {
        $config.Destination.File = $newDestFile
    }
    
    Write-Host "Destination Sheet [$($config.Destination.Sheet)]: " -NoNewline
    $newDestSheet = Read-Host
    if (![string]::IsNullOrEmpty($newDestSheet)) {
        $config.Destination.Sheet = $newDestSheet
    }
    
    Write-Host ""
    Write-Host "Configuration updated!" -ForegroundColor Green
    Write-Host "Press any key to continue..."
    $null = $Host.UI.RawUI.ReadKey()
    
    return $config
}

function Edit-FieldMappings {
    param($config, [string]$MappingType)
    
    $fieldNames = $config.FieldMappings.Keys | Sort-Object
    $currentIndex = 0
    
    while ($true) {
        Clear-Host
        Write-Host "=== $MappingType Mapping ===" -ForegroundColor Cyan
        Write-Host "Field $($currentIndex + 1) of $($fieldNames.Count)" -ForegroundColor Yellow
        Write-Host ""
        
        $fieldName = $fieldNames[$currentIndex]
        $mapping = $config.FieldMappings[$fieldName]
        
        Write-Host "Field: $fieldName" -ForegroundColor Green
        Write-Host "Source Cell: $($mapping.Source)" -ForegroundColor White
        Write-Host "Dest Cell: $($mapping.Dest)" -ForegroundColor White
        Write-Host ""
        
        if ($MappingType -eq "Source") {
            Write-Host "Enter new source cell [$($mapping.Source)]: " -NoNewline
            $newValue = Read-Host
            if (![string]::IsNullOrEmpty($newValue)) {
                $config.FieldMappings[$fieldName].Source = $newValue
            }
        } else {
            Write-Host "Enter new destination cell [$($mapping.Dest)]: " -NoNewline
            $newValue = Read-Host
            if (![string]::IsNullOrEmpty($newValue)) {
                $config.FieldMappings[$fieldName].Dest = $newValue
            }
        }
        
        Write-Host ""
        Write-Host "Navigation:" -ForegroundColor Gray
        Write-Host "  [N]ext  [P]revious  [J]ump to field  [D]one"
        Write-Host ""
        
        $action = Get-UserChoice "Action"
        
        switch ($action.ToUpper()) {
            "N" { 
                if ($currentIndex -lt ($fieldNames.Count - 1)) { 
                    $currentIndex++ 
                }
            }
            "P" { 
                if ($currentIndex -gt 0) { 
                    $currentIndex-- 
                }
            }
            "J" {
                Write-Host ""
                for ($i = 0; $i -lt $fieldNames.Count; $i++) {
                    Write-Host "$($i + 1). $($fieldNames[$i])"
                }
                Write-Host ""
                $jumpChoice = Get-UserChoice "Jump to field number"
                $jumpIndex = [int]$jumpChoice - 1
                if ($jumpIndex -ge 0 -and $jumpIndex -lt $fieldNames.Count) {
                    $currentIndex = $jumpIndex
                }
            }
            "D" { 
                return $config
            }
        }
    }
}

function Show-Configuration {
    param($config)
    
    Clear-Host
    Write-Host "=== Current Configuration ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Input Settings:" -ForegroundColor Yellow
    Write-Host "  Source: $($config.Source.File) [$($config.Source.Sheet)]"
    Write-Host "  Destination: $($config.Destination.File) [$($config.Destination.Sheet)]"
    Write-Host ""
    Write-Host "Field Mappings:" -ForegroundColor Yellow
    
    $fieldNames = $config.FieldMappings.Keys | Sort-Object
    foreach ($fieldName in $fieldNames) {
        $mapping = $config.FieldMappings[$fieldName]
        Write-Host "  $fieldName : $($mapping.Source) -> $($mapping.Dest)"
    }
    
    Write-Host ""
    Write-Host "Press any key to continue..."
    $null = $Host.UI.RawUI.ReadKey()
}

function Save-Configuration {
    param($config, $configPath)
    
    $configDir = Split-Path $configPath -Parent
    if (!(Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }
    
    $config.Timestamp = (Get-Date).ToString()
    $config | ConvertTo-Json -Depth 10 | Set-Content $configPath
    
    Clear-Host
    Write-Host "=== Configuration Saved ===" -ForegroundColor Green
    Write-Host "File: $configPath" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Press any key to continue..."
    $null = $Host.UI.RawUI.ReadKey()
}

function Load-Configuration {
    param($configPath)
    
    if (Test-Path $configPath) {
        try {
            $config = Get-Content $configPath | ConvertFrom-Json
            Write-Host "Configuration loaded from $configPath" -ForegroundColor Green
            return $config
        } catch {
            Write-Host "Error loading configuration: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "Configuration file not found: $configPath" -ForegroundColor Yellow
    }
    
    Write-Host "Press any key to continue..."
    $null = $Host.UI.RawUI.ReadKey()
    return $null
}

function New-DefaultConfiguration {
    return @{
        Source = @{
            File = "C:\data\source.xlsx"
            Sheet = "SVI-CAS"
        }
        Destination = @{
            File = "C:\data\output.xlsx"
            Sheet = "Output"
        }
        FieldMappings = @{
            "RequestDate" = @{ Source = "W23"; Dest = "A1" }
            "AuditType" = @{ Source = "W78"; Dest = "A2" }
            "AuditorName" = @{ Source = "W10"; Dest = "A3" }
            "TPName" = @{ Source = "W3"; Dest = "A4" }
            "TPEmailAddress" = @{ Source = "X3"; Dest = "A5" }
            "TPPhoneNumber" = @{ Source = "Y3"; Dest = "A6" }
            "CorporateContact" = @{ Source = "W5"; Dest = "A7" }
            "CorporateContactEmail" = @{ Source = "X5"; Dest = "A8" }
            "CorporateContactPhone" = @{ Source = "Y5"; Dest = "A9" }
            "SiteName" = @{ Source = "W7"; Dest = "A10" }
            "SiteAddress" = @{ Source = "W8"; Dest = "A11" }
            "SiteCity" = @{ Source = "W9"; Dest = "A12" }
            "SiteState" = @{ Source = "X9"; Dest = "A13" }
            "SiteZip" = @{ Source = "Y9"; Dest = "A14" }
            "SiteCountry" = @{ Source = "Z9"; Dest = "A15" }
            "AttentionContact" = @{ Source = "W11"; Dest = "A16" }
            "AttentionContactEmail" = @{ Source = "X11"; Dest = "A17" }
            "AttentionContactPhone" = @{ Source = "Y11"; Dest = "A18" }
            "TaxID" = @{ Source = "W13"; Dest = "A19" }
            "DUNS" = @{ Source = "X13"; Dest = "A20" }
            "CASNumber" = @{ Source = "G17"; Dest = "A21" }
            "AssetName" = @{ Source = "H17"; Dest = "A22" }
            "SerialNumber" = @{ Source = "I17"; Dest = "A23" }
            "ModelNumber" = @{ Source = "J17"; Dest = "A24" }
            "ManufacturerName" = @{ Source = "K17"; Dest = "A25" }
            "InstallDate" = @{ Source = "L17"; Dest = "A26" }
            "Capacity" = @{ Source = "M17"; Dest = "A27" }
            "CapacityUnit" = @{ Source = "N17"; Dest = "A28" }
            "TankType" = @{ Source = "O17"; Dest = "A29" }
            "Product" = @{ Source = "P17"; Dest = "A30" }
            "LeakDetection" = @{ Source = "Q17"; Dest = "A31" }
            "Piping" = @{ Source = "R17"; Dest = "A32" }
            "Monitoring" = @{ Source = "S17"; Dest = "A33" }
            "Status" = @{ Source = "T17"; Dest = "A34" }
            "Comments" = @{ Source = "U17"; Dest = "A35" }
            "ComplianceDate" = @{ Source = "W25"; Dest = "A36" }
            "NextInspectionDate" = @{ Source = "W27"; Dest = "A37" }
            "CertificationNumber" = @{ Source = "W29"; Dest = "A38" }
            "InspectorName" = @{ Source = "W31"; Dest = "A39" }
            "InspectorLicense" = @{ Source = "W33"; Dest = "A40" }
        }
        Timestamp = (Get-Date).ToString()
    }
}

# Main execution
$configPath = Join-Path $PSScriptRoot $ConfigFile

# Try to load existing configuration or create default
$config = Load-Configuration $configPath
if ($null -eq $config) {
    $config = New-DefaultConfiguration
}

# Main menu loop
while ($true) {
    Show-MainMenu
    $choice = Get-UserChoice
    
    switch ($choice) {
        "1" { 
            $config = Set-InputConfiguration $config
        }
        "2" { 
            $config = Edit-FieldMappings $config "Source"
        }
        "3" { 
            $config = Edit-FieldMappings $config "Destination"
        }
        "4" { 
            Show-Configuration $config
        }
        "5" { 
            Save-Configuration $config $configPath
        }
        "6" { 
            $loadedConfig = Load-Configuration $configPath
            if ($null -ne $loadedConfig) {
                $config = $loadedConfig
            }
        }
        "9" { 
            Write-Host "Exiting..." -ForegroundColor Red
            exit
        }
        default {
            Write-Host "Invalid choice. Please select 1-6 or 9." -ForegroundColor Red
            Start-Sleep 2
        }
    }
}