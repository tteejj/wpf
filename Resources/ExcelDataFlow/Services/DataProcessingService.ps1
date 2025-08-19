# DataProcessingService.ps1 - Main data processing workflow for ExcelDataFlow

class DataProcessingService {
    [ExcelService]$ExcelService
    [ConfigurationService]$ConfigService
    
    DataProcessingService([ExcelService]$excelService, [ConfigurationService]$configService) {
        $this.ExcelService = $excelService
        $this.ConfigService = $configService
    }
    
    # Main workflow: Extract data from source, transform, and export to destination
    [hashtable] ProcessDataWorkflow([bool]$includeTextExport = $false) {
        $result = @{
            Success = $false
            Message = ""
            ExtractedData = @{}
            Errors = @()
            TextExportResult = $null
        }
        
        try {
            # Get saved configuration
            $config = $this.ConfigService.GetSetting('ExcelMappings', $null)
            if (-not $config) {
                $result.Errors += "No configuration found. Please run the mapping wizard first."
                return $result
            }
            
            Write-Host "Starting Excel data processing workflow..." -ForegroundColor Cyan
            Write-Host "Source: $($config.SourceFile) [$($config.SourceSheet)]" -ForegroundColor Yellow
            Write-Host "Destination: $($config.DestFile) [$($config.DestSheet)]" -ForegroundColor Yellow
            
            # Step 1: Open source workbook
            $sourceResult = $this.OpenSourceWorkbook($config)
            if (-not $sourceResult.Success) {
                $result.Errors += $sourceResult.Error
                return $result
            }
            
            # Step 2: Extract data using field mappings
            $extractResult = $this.ExtractData($config)
            if (-not $extractResult.Success) {
                $result.Errors += $extractResult.Errors
                return $result
            }
            
            $result.ExtractedData = $extractResult.Data
            Write-Host "Extracted $($extractResult.Data.Count) fields from source" -ForegroundColor Green
            
            # Step 3: Export data to destination Excel
            $exportResult = $this.ExportData($extractResult.Data, $config)
            if (-not $exportResult.Success) {
                $result.Errors += $exportResult.Errors
                return $result
            }
            
            Write-Host "Excel export completed successfully!" -ForegroundColor Green
            
            # Step 4: Optional text export
            if ($includeTextExport) {
                $textExportResult = $this.PerformTextExport($result.ExtractedData)
                $result.TextExportResult = $textExportResult
                if ($textExportResult.Success) {
                    Write-Host "Text export completed successfully!" -ForegroundColor Green
                } else {
                    Write-Host "Text export failed: $($textExportResult.Message)" -ForegroundColor Yellow
                }
            }
            
            $result.Success = $true
            $result.Message = "Data processing completed successfully!"
            Write-Host $result.Message -ForegroundColor Green
            
        }
        catch {
            $result.Errors += "Workflow failed: $_"
        }
        finally {
            # Always cleanup COM objects
            $this.ExcelService.Cleanup()
        }
        
        return $result
    }
    
    # Perform interactive text export with field selection
    [hashtable] PerformTextExport([hashtable]$extractedData) {
        try {
            Write-Host "`nPerforming text export..." -ForegroundColor Cyan
            
            # Note: Interactive text export dialog is available but requires full UI loading
            # For now, using direct export via TextExportService
            Write-Host "Using direct text export (interactive dialog available in full UI mode)..." -ForegroundColor Cyan
            
            # This would show the dialog in a full TUI app
            # For CLI usage, we'll do automatic export with saved preferences
            $textExportService = [TextExportService]::new($this.ConfigService)
            $settings = $textExportService.LoadFieldSelection()
            
            # Use saved preferences or defaults
            $selectedFields = if ($settings.SelectedFields.Count -gt 0) { $settings.SelectedFields } else { $extractedData.Keys }
            $format = if ($settings.ExportFormat) { $settings.ExportFormat } else { "CSV" }
            $outputPath = $textExportService.GenerateOutputPath($format, ".\")
            
            Write-Host "Exporting $($selectedFields.Count) fields to $format format..." -ForegroundColor Yellow
            
            $result = $textExportService.ExportToText($extractedData, $outputPath, $format, $selectedFields)
            
            if ($result.Success) {
                Write-Host "✅ Text export successful: $($result.OutputPath)" -ForegroundColor Green
            }
            
            return $result
            
        } catch {
            return @{
                Success = $false
                Message = "Text export failed: $_"
            }
        }
    }
    
    [hashtable] OpenSourceWorkbook([hashtable]$config) {
        Write-Host "Opening source workbook..." -ForegroundColor Yellow
        
        if (-not (Test-Path $config.SourceFile)) {
            return @{ Success = $false; Error = "Source file not found: $($config.SourceFile)" }
        }
        
        $openResult = $this.ExcelService.OpenWorkbook($config.SourceFile)
        if (-not $openResult.Success) {
            return @{ Success = $false; Error = "Failed to open source: $($openResult.Error)" }
        }
        
        # Verify sheet exists
        $sheetNames = $this.ExcelService.GetSheetNames()
        if ($config.SourceSheet -notin $sheetNames) {
            return @{ Success = $false; Error = "Sheet '$($config.SourceSheet)' not found in source workbook. Available: $($sheetNames -join ', ')" }
        }
        
        Write-Host "Source workbook opened successfully" -ForegroundColor Green
        return @{ Success = $true }
    }
    
    [hashtable] ExtractData([hashtable]$config) {
        Write-Host "Extracting data using field mappings..." -ForegroundColor Yellow
        
        $result = @{
            Success = $true
            Data = @{}
            Errors = @()
        }
        
        $fieldCount = $config.FieldMappings.Count
        $extractedCount = 0
        
        foreach ($fieldName in $config.FieldMappings.Keys) {
            $mapping = $config.FieldMappings[$fieldName]
            
            try {
                $value = $this.ExcelService.GetCellValue($mapping.Sheet, $mapping.Cell)
                
                if ($null -ne $value -and $value -ne "") {
                    $result.Data[$fieldName] = $value
                    $extractedCount++
                    Write-Host "  ✓ $fieldName = '$value' (from $($mapping.Cell))" -ForegroundColor Gray
                } else {
                    Write-Host "  ⚠ $fieldName = (empty) (from $($mapping.Cell))" -ForegroundColor DarkYellow
                }
            }
            catch {
                $error = "Failed to extract $fieldName from $($mapping.Sheet)!$($mapping.Cell): $_"
                $result.Errors += $error
                Write-Host "  ✗ $error" -ForegroundColor Red
            }
        }
        
        Write-Host "Extraction complete: $extractedCount/$fieldCount fields extracted" -ForegroundColor Green
        
        if ($result.Errors.Count -gt 0) {
            $result.Success = $false
        }
        
        return $result
    }
    
    [hashtable] ExportData([hashtable]$data, [hashtable]$config) {
        Write-Host "Exporting data to destination..." -ForegroundColor Yellow
        
        # Build destination mappings from config
        $destMappings = @{}
        foreach ($fieldName in $config.FieldMappings.Keys) {
            $mapping = $config.FieldMappings[$fieldName]
            if ($mapping.DestCell -and $mapping.DestCell -ne "") {
                $destMappings[$fieldName] = @{ Cell = $mapping.DestCell }
            }
        }
        
        if ($destMappings.Count -eq 0) {
            return @{ Success = $false; Errors = @("No destination cell mappings configured") }
        }
        
        Write-Host "Exporting $($destMappings.Count) fields to destination..." -ForegroundColor Yellow
        
        $exportResult = $this.ExcelService.ExportFieldMappings(
            $data, 
            $destMappings, 
            $config.DestFile, 
            $config.DestSheet
        )
        
        if ($exportResult.Success) {
            Write-Host "Export completed successfully!" -ForegroundColor Green
        } else {
            Write-Host "Export failed:" -ForegroundColor Red
            foreach ($error in $exportResult.Errors) {
                Write-Host "  ✗ $error" -ForegroundColor Red
            }
        }
        
        return $exportResult
    }
    
    # Quick data preview without full processing
    [hashtable] PreviewData([int]$maxFields = 10) {
        $result = @{
            Success = $false
            Preview = @{}
            Message = ""
        }
        
        try {
            $config = $this.ConfigService.GetSetting('ExcelMappings', $null)
            if (-not $config) {
                $result.Message = "No configuration found"
                return $result
            }
            
            $openResult = $this.OpenSourceWorkbook($config)
            if (-not $openResult.Success) {
                $result.Message = $openResult.Error
                return $result
            }
            
            $fieldNames = $config.FieldMappings.Keys | Select-Object -First $maxFields
            foreach ($fieldName in $fieldNames) {
                $mapping = $config.FieldMappings[$fieldName]
                try {
                    $value = $this.ExcelService.GetCellValue($mapping.Sheet, $mapping.Cell)
                    $result.Preview[$fieldName] = @{
                        Value = $value
                        Source = "$($mapping.Sheet)!$($mapping.Cell)"
                        Destination = if ($mapping.DestCell) { "$($config.DestSheet)!$($mapping.DestCell)" } else { "(not mapped)" }
                    }
                }
                catch {
                    $result.Preview[$fieldName] = @{
                        Value = "(error: $_)"
                        Source = "$($mapping.Sheet)!$($mapping.Cell)"
                        Destination = if ($mapping.DestCell) { "$($config.DestSheet)!$($mapping.DestCell)" } else { "(not mapped)" }
                    }
                }
            }
            
            $result.Success = $true
            $result.Message = "Preview generated successfully"
        }
        catch {
            $result.Message = "Preview failed: $_"
        }
        finally {
            $this.ExcelService.Cleanup()
        }
        
        return $result
    }
}