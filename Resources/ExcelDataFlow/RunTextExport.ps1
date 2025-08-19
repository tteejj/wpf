# RunTextExport.ps1 - Dedicated text export with field selection

param(
    [string]$Format = "CSV",           # Export format (CSV, TSV, JSON, TXT, XML)
    [string[]]$Fields = @(),           # Specific fields to export (empty = all fields)
    [string]$OutputPath = "",          # Custom output path (file or directory)
    [switch]$BrowseFile,               # Browse for output file location
    [switch]$Interactive,              # Show field selection dialog  
    [switch]$ListFields               # Just list available fields
)

$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectPath = $PSScriptRoot

# Import required classes
. "$projectPath\Core\ServiceContainer.ps1"
. "$projectPath\Services\ConfigurationService.ps1"
. "$projectPath\Services\ExcelService.ps1"
. "$projectPath\Services\TextExportService.ps1"
. "$projectPath\Services\DataProcessingService.ps1"
. "$projectPath\Screens\FolderBrowserDialog.ps1"

function Show-AvailableFields {
    param([hashtable]$data)
    
    Write-Host "`n=== Available Fields for Export ===" -ForegroundColor Cyan
    Write-Host "Total: $($data.Count) fields`n" -ForegroundColor Yellow
    
    $data.GetEnumerator() | Sort-Object Name | ForEach-Object {
        $value = if ($_.Value) { 
            $val = $_.Value.ToString()
            if ($val.Length -gt 50) { $val.Substring(0, 47) + "..." } else { $val }
        } else { 
            "(empty)" 
        }
        Write-Host ("{0,-25} : {1}" -f $_.Key, $value) -ForegroundColor White
    }
    
    Write-Host "`nUsage examples:" -ForegroundColor Yellow
    Write-Host "  Export all fields to CSV:" -ForegroundColor Gray
    Write-Host "    pwsh -File RunTextExport.ps1 -Format CSV" -ForegroundColor White
    Write-Host "  Export specific fields to JSON:" -ForegroundColor Gray
    Write-Host "    pwsh -File RunTextExport.ps1 -Format JSON -Fields RequestDate,SiteName,Product" -ForegroundColor White
    Write-Host "  Specify output file:" -ForegroundColor Gray
    Write-Host "    pwsh -File RunTextExport.ps1 -Format TXT -OutputPath '/path/to/mydata.txt'" -ForegroundColor White
    Write-Host "  Specify output directory:" -ForegroundColor Gray
    Write-Host "    pwsh -File RunTextExport.ps1 -Format CSV -OutputPath '/path/to/directory/'" -ForegroundColor White
    Write-Host "  Browse for output location:" -ForegroundColor Gray
    Write-Host "    pwsh -File RunTextExport.ps1 -Format CSV -BrowseFile" -ForegroundColor White
}

try {
    Write-Host "=== ExcelDataFlow Text Export ===" -ForegroundColor Cyan
    
    # Initialize services
    $serviceContainer = [ServiceContainer]::new()
    $serviceContainer.RegisterService("ConfigurationService", [ConfigurationService]::new())
    $serviceContainer.RegisterService("ExcelService", [ExcelService]::new())
    
    $configService = $serviceContainer.GetService("ConfigurationService")
    $excelService = $serviceContainer.GetService("ExcelService")
    $textExportService = [TextExportService]::new($configService)
    $dataProcessor = [DataProcessingService]::new($excelService, $configService)
    
    # Check for configuration
    $config = $configService.GetSetting('ExcelMappings', $null)
    if (-not $config) {
        Write-Host "❌ No configuration found!" -ForegroundColor Red
        Write-Host "Please run the mapping wizard first:" -ForegroundColor Yellow
        Write-Host "  pwsh -File Start.ps1" -ForegroundColor White
        exit 1
    }
    
    # Extract data first
    Write-Host "Extracting data from Excel source..." -ForegroundColor Yellow
    $sourceResult = $dataProcessor.OpenSourceWorkbook($config)
    if (-not $sourceResult.Success) {
        Write-Host "❌ Failed to open source: $($sourceResult.Error)" -ForegroundColor Red
        exit 1
    }
    
    $extractResult = $dataProcessor.ExtractData($config)
    if (-not $extractResult.Success) {
        Write-Host "❌ Data extraction failed:" -ForegroundColor Red
        foreach ($error in $extractResult.Errors) {
            Write-Host "  • $error" -ForegroundColor Red
        }
        exit 1
    }
    
    $extractedData = $extractResult.Data
    Write-Host "✅ Extracted $($extractedData.Count) fields successfully" -ForegroundColor Green
    
    # List fields mode
    if ($ListFields) {
        Show-AvailableFields $extractedData
        exit 0
    }
    
    # Validate format
    $supportedFormats = $textExportService.GetSupportedFormats()
    if ($Format.ToUpper() -notin $supportedFormats) {
        Write-Host "❌ Unsupported format: $Format" -ForegroundColor Red
        Write-Host "Supported formats: $($supportedFormats -join ', ')" -ForegroundColor Yellow
        exit 1
    }
    
    # Determine fields to export
    $fieldsToExport = if ($Fields.Count -gt 0) {
        # Validate specified fields exist
        $invalidFields = $Fields | Where-Object { $_ -notin $extractedData.Keys }
        if ($invalidFields.Count -gt 0) {
            Write-Host "❌ Invalid fields specified: $($invalidFields -join ', ')" -ForegroundColor Red
            Write-Host "Use -ListFields to see available fields" -ForegroundColor Yellow
            exit 1
        }
        $Fields
    } else {
        # Use all available fields
        [string[]]$extractedData.Keys
    }
    
    # Determine output path: browse, specify, or auto-generate
    if ($BrowseFile) {
        Write-Host "`nBrowsing for output location..." -ForegroundColor Cyan
        $selectedPath = Show-FolderBrowser $projectPath
        if ($selectedPath) {
            # Generate filename with timestamp  
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $extension = switch ($Format.ToUpper()) {
                "CSV" { ".csv" }
                "TSV" { ".tsv" }
                "JSON" { ".json" }
                "TXT" { ".txt" }
                "XML" { ".xml" }
                default { ".txt" }
            }
            $OutputPath = Join-Path $selectedPath "ExcelDataExport_$timestamp$extension"
            Write-Host "Selected output location: $OutputPath" -ForegroundColor Green
        } else {
            Write-Host "No location selected, using current directory" -ForegroundColor Yellow
            $OutputPath = $textExportService.GenerateOutputPath($Format, ".\")
        }
    } elseif ($OutputPath) {
        # User specified path - check if it's a directory or file
        if (Test-Path $OutputPath -PathType Container) {
            # It's a directory, generate filename
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $extension = switch ($Format.ToUpper()) {
                "CSV" { ".csv" }
                "TSV" { ".tsv" }
                "JSON" { ".json" }
                "TXT" { ".txt" }
                "XML" { ".xml" }
                default { ".txt" }
            }
            $OutputPath = Join-Path $OutputPath "ExcelDataExport_$timestamp$extension"
        }
        Write-Host "Using specified output: $OutputPath" -ForegroundColor Green
    } else {
        # Auto-generate in current directory
        $OutputPath = $textExportService.GenerateOutputPath($Format, ".\")
        Write-Host "Auto-generated output: $OutputPath" -ForegroundColor Cyan
    }
    
    # Interactive mode - show field selection dialog
    if ($Interactive) {
        Write-Host "`nLaunching interactive field selection..." -ForegroundColor Cyan
        Write-Host "This would open the field selection dialog in a full TUI environment." -ForegroundColor Gray
        Write-Host "For now, using all fields. Use -Fields parameter for specific selection." -ForegroundColor Gray
    }
    
    # Perform export
    Write-Host "`nExporting data..." -ForegroundColor Cyan
    Write-Host "  Fields: $($fieldsToExport.Count) of $($extractedData.Count) available" -ForegroundColor Gray
    Write-Host "  Format: $Format" -ForegroundColor Gray
    Write-Host "  Output: $OutputPath" -ForegroundColor Gray
    
    $exportResult = $textExportService.ExportToText($extractedData, $OutputPath, $Format, $fieldsToExport)
    
    if ($exportResult.Success) {
        Write-Host "`n✅ Export successful!" -ForegroundColor Green
        Write-Host "  File: $($exportResult.OutputPath)" -ForegroundColor White
        Write-Host "  Fields exported: $($exportResult.ExportedFields.Count)" -ForegroundColor White
        Write-Host "  Format: $Format" -ForegroundColor White
        
        # Save preferences for future use
        $textExportService.SaveFieldSelection($fieldsToExport, $Format)
        
        # Show file info
        if (Test-Path $exportResult.OutputPath) {
            $fileInfo = Get-Item $exportResult.OutputPath
            Write-Host "  File size: $([Math]::Round($fileInfo.Length / 1KB, 2)) KB" -ForegroundColor Gray
        }
        
        Write-Host "`nExported fields:" -ForegroundColor Yellow
        $fieldsToExport | ForEach-Object {
            $value = if ($extractedData[$_]) { $extractedData[$_].ToString() } else { "(empty)" }
            if ($value.Length -gt 40) { $value = $value.Substring(0, 37) + "..." }
            Write-Host "  $_`: $value" -ForegroundColor White
        }
        
    } else {
        Write-Host "`n❌ Export failed: $($exportResult.Message)" -ForegroundColor Red
        exit 1
    }
    
} catch {
    Write-Host "`n❌ FATAL ERROR: $_" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
    exit 1
} finally {
    # Cleanup
    if ($excelService) {
        $excelService.Cleanup()
    }
}

Write-Host "`n=== Text Export Complete ===" -ForegroundColor Cyan