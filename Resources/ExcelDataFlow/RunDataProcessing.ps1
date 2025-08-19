# RunDataProcessing.ps1 - Execute the actual Excel data extraction and export

param(
    [switch]$Preview,     # Show preview instead of full processing
    [switch]$Force,       # Skip confirmation prompts
    [switch]$TextExport,  # Include text export with field selection
    [string]$TextFormat = "CSV"  # Text export format (CSV, TSV, JSON, TXT, XML)
)

$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectPath = $PSScriptRoot

# Import all required classes
. "$projectPath\Core\ServiceContainer.ps1"
. "$projectPath\Services\ConfigurationService.ps1"
. "$projectPath\Services\ExcelService.ps1"
. "$projectPath\Services\TextExportService.ps1"
. "$projectPath\Services\DataProcessingService.ps1"

function Show-Configuration {
    param([hashtable]$config)
    
    Write-Host "`n=== Current Configuration ===" -ForegroundColor Cyan
    Write-Host "Source File: " -NoNewline -ForegroundColor Yellow
    Write-Host $config.SourceFile -ForegroundColor White
    Write-Host "Source Sheet: " -NoNewline -ForegroundColor Yellow  
    Write-Host $config.SourceSheet -ForegroundColor White
    Write-Host "Destination File: " -NoNewline -ForegroundColor Yellow
    Write-Host $config.DestFile -ForegroundColor White
    Write-Host "Destination Sheet: " -NoNewline -ForegroundColor Yellow
    Write-Host $config.DestSheet -ForegroundColor White
    Write-Host "Field Mappings: " -NoNewline -ForegroundColor Yellow
    Write-Host "$($config.FieldMappings.Count) fields configured" -ForegroundColor White
    Write-Host ""
}

function Show-Preview {
    param([hashtable]$previewData)
    
    Write-Host "`n=== Data Preview (First 10 Fields) ===" -ForegroundColor Cyan
    Write-Host ("{0,-25} {1,-20} {2,-30} {3}" -f "Field", "Value", "Source", "Destination") -ForegroundColor Yellow
    Write-Host ("-" * 100) -ForegroundColor Gray
    
    foreach ($field in $previewData.Keys) {
        $data = $previewData[$field]
        $value = if ($data.Value) { 
            if ($data.Value.ToString().Length -gt 18) { 
                $data.Value.ToString().Substring(0, 15) + "..." 
            } else { 
                $data.Value.ToString() 
            }
        } else { 
            "(empty)" 
        }
        
        Write-Host ("{0,-25} {1,-20} {2,-30} {3}" -f $field, $value, $data.Source, $data.Destination) -ForegroundColor White
    }
    Write-Host ""
}

try {
    Write-Host "=== ExcelDataFlow Data Processing ===" -ForegroundColor Cyan
    Write-Host ""
    
    # Initialize services
    $serviceContainer = [ServiceContainer]::new()
    $serviceContainer.RegisterService("ConfigurationService", [ConfigurationService]::new())
    $serviceContainer.RegisterService("ExcelService", [ExcelService]::new())
    
    $configService = $serviceContainer.GetService("ConfigurationService")
    $excelService = $serviceContainer.GetService("ExcelService")
    $dataProcessor = [DataProcessingService]::new($excelService, $configService)
    
    # Check for configuration
    $config = $configService.GetSetting('ExcelMappings', $null)
    if (-not $config) {
        Write-Host "❌ No configuration found!" -ForegroundColor Red
        Write-Host "Please run the mapping wizard first:" -ForegroundColor Yellow
        Write-Host "  pwsh -File Start.ps1" -ForegroundColor White
        exit 1
    }
    
    Show-Configuration $config
    
    if ($Preview) {
        # Preview mode
        Write-Host "Generating data preview..." -ForegroundColor Yellow
        $previewResult = $dataProcessor.PreviewData(10)
        
        if ($previewResult.Success) {
            Show-Preview $previewResult.Preview
            Write-Host "✅ $($previewResult.Message)" -ForegroundColor Green
        } else {
            Write-Host "❌ Preview failed: $($previewResult.Message)" -ForegroundColor Red
            exit 1
        }
    } else {
        # Full processing mode
        if (-not $Force) {
            Write-Host "This will extract data from the source Excel file and export to the destination." -ForegroundColor Yellow
            Write-Host "Continue? (y/N): " -NoNewline -ForegroundColor Cyan
            $response = Read-Host
            if ($response -ne 'y' -and $response -ne 'Y') {
                Write-Host "Operation cancelled." -ForegroundColor Yellow
                exit 0
            }
        }
        
        Write-Host "`nStarting data processing workflow..." -ForegroundColor Cyan
        if ($TextExport) {
            Write-Host "Text export enabled - format: $TextFormat" -ForegroundColor Yellow
        }
        
        $result = $dataProcessor.ProcessDataWorkflow($TextExport)
        
        if ($result.Success) {
            Write-Host "`n✅ SUCCESS: $($result.Message)" -ForegroundColor Green
            Write-Host "Extracted $($result.ExtractedData.Count) fields" -ForegroundColor Green
            
            # Show text export results if performed
            if ($result.TextExportResult) {
                if ($result.TextExportResult.Success) {
                    Write-Host "✅ Text export: $($result.TextExportResult.OutputPath)" -ForegroundColor Green
                    Write-Host "   Format: $($result.TextExportResult.ExportedFields.Count) fields in $TextFormat" -ForegroundColor Gray
                } else {
                    Write-Host "⚠️  Text export failed: $($result.TextExportResult.Message)" -ForegroundColor Yellow
                }
            }
            
            # Show summary of extracted data
            if ($result.ExtractedData.Count -gt 0) {
                Write-Host "`n=== Extracted Data Summary ===" -ForegroundColor Cyan
                $result.ExtractedData.GetEnumerator() | Sort-Object Name | ForEach-Object {
                    $value = if ($_.Value) { $_.Value.ToString() } else { "(empty)" }
                    if ($value.Length -gt 50) { $value = $value.Substring(0, 47) + "..." }
                    Write-Host "  $($_.Key): $value" -ForegroundColor White
                }
            }
        } else {
            Write-Host "`n❌ FAILED: Data processing encountered errors:" -ForegroundColor Red
            foreach ($error in $result.Errors) {
                Write-Host "  • $error" -ForegroundColor Red
            }
            exit 1
        }
    }
}
catch {
    Write-Host "`n❌ FATAL ERROR: $_" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
    exit 1
}
finally {
    # Always cleanup
    if ($excelService) {
        $excelService.Cleanup()
    }
}

Write-Host "`n=== Processing Complete ===" -ForegroundColor Cyan