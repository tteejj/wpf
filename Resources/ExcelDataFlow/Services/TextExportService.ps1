# TextExportService.ps1 - Text export functionality with field selection

class TextExportService {
    [ConfigurationService]$ConfigService
    
    TextExportService([ConfigurationService]$configService) {
        $this.ConfigService = $configService
    }
    
    # Export data to various text formats
    [hashtable] ExportToText([hashtable]$data, [string]$outputPath, [string]$format = "CSV", [string[]]$selectedFields = @()) {
        $result = @{
            Success = $false
            Message = ""
            ExportedFields = @()
            OutputPath = $outputPath
        }
        
        try {
            # Determine which fields to export
            $fieldsToExport = if ($selectedFields.Count -gt 0) { $selectedFields } else { $data.Keys }
            
            # Filter data to only selected fields
            $filteredData = @{}
            foreach ($field in $fieldsToExport) {
                if ($data.ContainsKey($field)) {
                    $filteredData[$field] = $data[$field]
                }
            }
            
            if ($filteredData.Count -eq 0) {
                $result.Message = "No data to export with selected fields"
                return $result
            }
            
            # Create output directory if needed
            $outputDir = Split-Path $outputPath -Parent
            if ($outputDir -and !(Test-Path $outputDir)) {
                New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
            }
            
            # Export based on format
            switch ($format.ToUpper()) {
                "CSV" { $this.ExportToCSV($filteredData, $outputPath) }
                "TSV" { $this.ExportToTSV($filteredData, $outputPath) }
                "JSON" { $this.ExportToJSON($filteredData, $outputPath) }
                "TXT" { $this.ExportToFormattedText($filteredData, $outputPath) }
                "XML" { $this.ExportToXML($filteredData, $outputPath) }
                default { 
                    $result.Message = "Unsupported format: $format. Supported: CSV, TSV, JSON, TXT, XML"
                    return $result
                }
            }
            
            $result.Success = $true
            $result.Message = "Successfully exported $($filteredData.Count) fields to $format format"
            $result.ExportedFields = $fieldsToExport
            
        } catch {
            $result.Message = "Export failed: $_"
        }
        
        return $result
    }
    
    # CSV export with proper escaping
    [void] ExportToCSV([hashtable]$data, [string]$outputPath) {
        $csv = @()
        
        # Header row
        $headers = $data.Keys | Sort-Object
        $csv += ($headers -join ",")
        
        # Data row
        $values = @()
        foreach ($header in $headers) {
            $value = $data[$header]
            # Escape CSV values that contain commas, quotes, or newlines
            if ($value -and ($value.ToString().Contains(",") -or $value.ToString().Contains('"') -or $value.ToString().Contains("`n"))) {
                $value = '"' + $value.ToString().Replace('"', '""') + '"'
            }
            $values += $value
        }
        $csv += ($values -join ",")
        
        $csv | Out-File -FilePath $outputPath -Encoding UTF8
    }
    
    # Tab-separated values export
    [void] ExportToTSV([hashtable]$data, [string]$outputPath) {
        $tsv = @()
        
        # Header row
        $headers = $data.Keys | Sort-Object
        $tsv += ($headers -join "`t")
        
        # Data row
        $values = @()
        foreach ($header in $headers) {
            $value = if ($data[$header]) { $data[$header].ToString() } else { "" }
            # Replace tabs with spaces in values
            $value = $value.Replace("`t", " ")
            $values += $value
        }
        $tsv += ($values -join "`t")
        
        $tsv | Out-File -FilePath $outputPath -Encoding UTF8
    }
    
    # JSON export with pretty formatting
    [void] ExportToJSON([hashtable]$data, [string]$outputPath) {
        # Create structured output with metadata
        $jsonOutput = @{
            ExportTimestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            FieldCount = $data.Count
            Data = $data
        }
        
        $jsonOutput | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputPath -Encoding UTF8
    }
    
    # Formatted text export for readability
    [void] ExportToFormattedText([hashtable]$data, [string]$outputPath) {
        $text = @()
        
        $text += "=== Excel Data Export ==="
        $text += "Export Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        $text += "Fields Exported: $($data.Count)"
        $text += ""
        
        # Find the longest field name for alignment
        $maxFieldLength = ($data.Keys | Measure-Object -Property Length -Maximum).Maximum
        
        foreach ($field in ($data.Keys | Sort-Object)) {
            $value = if ($data[$field]) { $data[$field].ToString() } else { "(empty)" }
            $text += "$($field.PadRight($maxFieldLength)) : $value"
        }
        
        $text += ""
        $text += "=== End of Export ==="
        
        $text | Out-File -FilePath $outputPath -Encoding UTF8
    }
    
    # XML export with proper structure
    [void] ExportToXML([hashtable]$data, [string]$outputPath) {
        $xml = @()
        
        $xml += '<?xml version="1.0" encoding="UTF-8"?>'
        $xml += '<ExcelDataExport>'
        $xml += "  <ExportInfo>"
        $xml += "    <Timestamp>$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')</Timestamp>"
        $xml += "    <FieldCount>$($data.Count)</FieldCount>"
        $xml += "  </ExportInfo>"
        $xml += "  <Fields>"
        
        foreach ($field in ($data.Keys | Sort-Object)) {
            $value = if ($data[$field]) { 
                # Escape XML special characters
                $data[$field].ToString().Replace("&", "&amp;").Replace("<", "&lt;").Replace(">", "&gt;").Replace('"', "&quot;").Replace("'", "&apos;")
            } else { 
                ""
            }
            $xml += "    <Field Name=`"$field`">$value</Field>"
        }
        
        $xml += "  </Fields>"
        $xml += '</ExcelDataExport>'
        
        $xml | Out-File -FilePath $outputPath -Encoding UTF8
    }
    
    # Get available export formats
    [string[]] GetSupportedFormats() {
        return @("CSV", "TSV", "JSON", "TXT", "XML")
    }
    
    # Save field selection preferences
    [void] SaveFieldSelection([string[]]$selectedFields, [string]$exportFormat) {
        $settings = @{
            SelectedFields = $selectedFields
            ExportFormat = $exportFormat
            LastUpdated = (Get-Date).ToString()
        }
        
        $this.ConfigService.SetSetting('TextExportSettings', $settings)
    }
    
    # Load field selection preferences
    [hashtable] LoadFieldSelection() {
        $settings = $this.ConfigService.GetSetting('TextExportSettings', @{
            SelectedFields = @()
            ExportFormat = "CSV"
        })
        return $settings
    }
    
    # Generate suggested filename based on format and timestamp
    [string] GenerateOutputPath([string]$format, [string]$baseDir = "") {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $extension = switch ($format.ToUpper()) {
            "CSV" { ".csv" }
            "TSV" { ".tsv" }
            "JSON" { ".json" }
            "TXT" { ".txt" }
            "XML" { ".xml" }
            default { ".txt" }
        }
        
        $filename = "ExcelDataExport_$timestamp$extension"
        
        if ($baseDir) {
            return Join-Path $baseDir $filename
        } else {
            return $filename
        }
    }
    
    # Generate project-specific path
    [string] GetProjectSpecificPath([string]$originalPath, [string]$projectName, [string]$format) {
        $baseDir = Split-Path $originalPath -Parent
        $projectsDir = Join-Path $baseDir "Projects"
        $projectDir = Join-Path $projectsDir $projectName
        
        # Generate filename with timestamp
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $extension = switch ($format.ToUpper()) {
            "CSV" { ".csv" }
            "TSV" { ".tsv" }
            "JSON" { ".json" }
            "TXT" { ".txt" }
            "XML" { ".xml" }
            default { ".txt" }
        }
        
        $filename = "ExcelDataExport_$timestamp$extension"
        return Join-Path $projectDir $filename
    }
    
    # Auto-detect project name from export data
    [string] DetectProjectFromData([hashtable]$data) {
        $projectName = ""
        
        # Strategy 1: Use SiteName + AuditType
        if ($data.ContainsKey("SiteName") -and $data["SiteName"]) {
            $siteName = $data["SiteName"] -replace '[^\w\-\s]', '' -replace '\s+', '-'
            $projectName = $siteName
            
            if ($data.ContainsKey("AuditType") -and $data["AuditType"]) {
                $auditType = $data["AuditType"] -replace '[^\w\-\s]', '' -replace '\s+', '-'
                $projectName = "$siteName-$auditType"
            }
        }
        # Strategy 2: Use just AuditType if no SiteName
        elseif ($data.ContainsKey("AuditType") -and $data["AuditType"]) {
            $projectName = $data["AuditType"] -replace '[^\w\-\s]', '' -replace '\s+', '-'
        }
        # Strategy 3: Use TPName (Technical Partner) as fallback
        elseif ($data.ContainsKey("TPName") -and $data["TPName"]) {
            $projectName = $data["TPName"] -replace '[^\w\-\s]', '' -replace '\s+', '-'
        }
        
        # Add year for uniqueness
        if ($projectName) {
            $year = (Get-Date).Year
            $projectName = "$projectName-$year"
        } else {
            # Ultimate fallback
            $projectName = "Project-$(Get-Date -Format 'yyyyMMdd')"
        }
        
        return $projectName
    }
    
    # Get most recent export for a project
    [string] GetMostRecentProjectExport([string]$projectName, [string]$baseDir = "") {
        if (-not $baseDir) {
            $baseDir = $PSScriptRoot
        }
        
        $projectsDir = Join-Path $baseDir "Projects"
        $projectDir = Join-Path $projectsDir $projectName
        
        if (-not (Test-Path $projectDir)) {
            return ""
        }
        
        $exportFiles = Get-ChildItem -Path $projectDir -Filter "ExcelDataExport_*" -File | 
                      Sort-Object LastWriteTime -Descending | 
                      Select-Object -First 1
        
        if ($exportFiles) {
            return $exportFiles.FullName
        }
        
        return ""
    }
    
    # List all projects with exports
    [string[]] GetProjectsWithExports([string]$baseDir = "") {
        if (-not $baseDir) {
            $baseDir = $PSScriptRoot
        }
        
        $projectsDir = Join-Path $baseDir "Projects"
        
        if (-not (Test-Path $projectsDir)) {
            return @()
        }
        
        $projectDirs = Get-ChildItem -Path $projectsDir -Directory
        return $projectDirs.Name
    }
    
    # Interactive project selection
    [string] SelectProjectInteractively([string]$baseDir = "") {
        if (-not $baseDir) {
            $baseDir = $PSScriptRoot
        }
        
        $projectsDir = Join-Path $baseDir "Projects"
        $existingProjects = @()
        
        if (Test-Path $projectsDir) {
            $existingProjects = Get-ChildItem -Path $projectsDir -Directory | Select-Object -ExpandProperty Name
        }
        
        Write-Host "`n=== Project Selection ===" -ForegroundColor Cyan
        
        if ($existingProjects.Count -gt 0) {
            Write-Host "Existing projects:" -ForegroundColor Yellow
            for ($i = 0; $i -lt $existingProjects.Count; $i++) {
                Write-Host "  $($i + 1). $($existingProjects[$i])" -ForegroundColor White
            }
            Write-Host "  $($existingProjects.Count + 1). Create new project" -ForegroundColor Green
            Write-Host "  0. Auto-detect from data" -ForegroundColor Gray
            
            do {
                Write-Host "`nSelect option (0-$($existingProjects.Count + 1)): " -NoNewline -ForegroundColor Yellow
                $choice = Read-Host
                
                if ($choice -eq "0") {
                    return ""  # Auto-detect
                } elseif ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $existingProjects.Count) {
                    return $existingProjects[[int]$choice - 1]
                } elseif ($choice -eq ($existingProjects.Count + 1).ToString()) {
                    break  # Create new
                } else {
                    Write-Host "Invalid choice. Please try again." -ForegroundColor Red
                }
            } while ($true)
        } else {
            Write-Host "No existing projects found." -ForegroundColor Gray
            Write-Host "Options:" -ForegroundColor Yellow
            Write-Host "  1. Create new project" -ForegroundColor Green
            Write-Host "  0. Auto-detect from data" -ForegroundColor Gray
            
            do {
                Write-Host "`nSelect option (0-1): " -NoNewline -ForegroundColor Yellow
                $choice = Read-Host
                
                if ($choice -eq "0") {
                    return ""  # Auto-detect
                } elseif ($choice -eq "1") {
                    break  # Create new
                } else {
                    Write-Host "Invalid choice. Please try again." -ForegroundColor Red
                }
            } while ($true)
        }
        
        # Create new project
        do {
            Write-Host "`nEnter new project name: " -NoNewline -ForegroundColor Yellow
            $newProject = Read-Host
            
            if ($newProject.Trim() -ne "") {
                # Clean the project name
                $cleanProject = $newProject -replace '[^\w\-\s]', '' -replace '\s+', '-'
                if ($cleanProject -ne $newProject) {
                    Write-Host "Project name cleaned to: $cleanProject" -ForegroundColor Gray
                }
                return $cleanProject
            } else {
                Write-Host "Project name cannot be empty. Please try again." -ForegroundColor Red
            }
        } while ($true)
    }
}