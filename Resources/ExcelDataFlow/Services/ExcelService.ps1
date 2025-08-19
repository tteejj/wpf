# ExcelService.ps1 - Excel COM automation service for ExcelDataFlow

class ExcelService {
    hidden [object]$_excel = $null
    hidden [object]$_workbook = $null
    hidden [bool]$_isInitialized = $false
    
    ExcelService() {
        $this.InitializeExcel()
    }
    
    [void] InitializeExcel() {
        try {
            # Create Excel COM object (Windows only)
            $this._excel = New-Object -ComObject Excel.Application
            $this._excel.Visible = $false
            $this._excel.DisplayAlerts = $false
            $this._isInitialized = $true
        }
        catch {
            # Excel not available - application will work with manual field mapping
            $this._isInitialized = $false
        }
    }
    
    [bool] IsAvailable() {
        return $this._isInitialized -and ($this._excel -ne $null)
    }
    
    [hashtable] OpenWorkbook([string]$filePath) {
        if (-not $this.IsAvailable()) {
            return @{ Success = $false; Error = "Excel not available - simulating for testing" }
        }
        
        if (-not (Test-Path $filePath)) {
            return @{ Success = $false; Error = "File not found: $filePath" }
        }
        
        try {
            $this._workbook = $this._excel.Workbooks.Open($filePath)
            return @{ Success = $true; Workbook = $this._workbook }
        }
        catch {
            return @{ Success = $false; Error = "Failed to open workbook: $_" }
        }
    }
    
    [string[]] GetSheetNames([object]$workbook = $null) {
        $wb = if ($workbook) { $workbook } else { $this._workbook }
        if (-not $wb) { return @() }
        
        $sheetNames = @()
        foreach ($sheet in $wb.Worksheets) {
            $sheetNames += $sheet.Name
        }
        return $sheetNames
    }
    
    [object] GetCellValue([string]$sheetName, [string]$cellReference, [object]$workbook = $null) {
        $wb = if ($workbook) { $workbook } else { $this._workbook }
        if (-not $wb) { return $null }
        
        try {
            $worksheet = $wb.Worksheets.Item($sheetName)
            $range = $worksheet.Range($cellReference)
            return $range.Value2
        }
        catch {
            Write-Warning "Failed to get cell value from $sheetName!$cellReference`: $_"
            return $null
        }
    }
    
    [hashtable] SetCellValue([string]$sheetName, [string]$cellReference, [object]$value, [object]$workbook = $null) {
        $wb = if ($workbook) { $workbook } else { $this._workbook }
        if (-not $wb) { 
            return @{ Success = $false; Error = "No workbook available" }
        }
        
        try {
            $worksheet = $wb.Worksheets.Item($sheetName)
            $range = $worksheet.Range($cellReference)
            $range.Value2 = $value
            return @{ Success = $true }
        }
        catch {
            return @{ Success = $false; Error = "Failed to set cell value: $_" }
        }
    }
    
    [hashtable] CreateWorkbook([string]$savePath) {
        if (-not $this.IsAvailable()) {
            return @{ Success = $false; Error = "Excel not available" }
        }
        
        try {
            $newWorkbook = $this._excel.Workbooks.Add()
            if ($savePath) {
                $newWorkbook.SaveAs($savePath)
            }
            return @{ Success = $true; Workbook = $newWorkbook }
        }
        catch {
            return @{ Success = $false; Error = "Failed to create workbook: $_" }
        }
    }
    
    [hashtable] SaveWorkbook([object]$workbook = $null, [string]$savePath = $null) {
        $wb = if ($workbook) { $workbook } else { $this._workbook }
        if (-not $wb) { 
            return @{ Success = $false; Error = "No workbook to save" }
        }
        
        try {
            if ($savePath) {
                $wb.SaveAs($savePath)
            } else {
                $wb.Save()
            }
            return @{ Success = $true }
        }
        catch {
            return @{ Success = $false; Error = "Failed to save workbook: $_" }
        }
    }
    
    [void] CloseWorkbook([object]$workbook = $null) {
        $wb = if ($workbook) { $workbook } else { $this._workbook }
        if ($wb) {
            try {
                $wb.Close($false)  # Don't save changes
                if ($wb -eq $this._workbook) {
                    $this._workbook = $null
                }
            }
            catch {
                Write-Warning "Failed to close workbook: $_"
            }
        }
    }
    
    [hashtable] ExtractFieldMappings([hashtable]$mappings) {
        $result = @{
            Success = $true
            Data = @{}
            Errors = @()
        }
        
        if (-not $this._workbook) {
            $result.Success = $false
            $result.Errors += "No workbook is currently open"
            return $result
        }
        
        foreach ($fieldName in $mappings.Keys) {
            $mapping = $mappings[$fieldName]
            try {
                $value = $this.GetCellValue($mapping.Sheet, $mapping.Cell)
                $result.Data[$fieldName] = $value
            }
            catch {
                $result.Errors += "Failed to extract $fieldName from $($mapping.Sheet)!$($mapping.Cell): $_"
            }
        }
        
        if ($result.Errors.Count -gt 0) {
            $result.Success = $false
        }
        
        return $result
    }
    
    [hashtable] ExportFieldMappings([hashtable]$data, [hashtable]$mappings, [string]$targetFile, [string]$targetSheet) {
        $result = @{
            Success = $true
            Errors = @()
        }
        
        try {
            # Open or create target workbook
            $targetWorkbook = $null
            if (Test-Path $targetFile) {
                $openResult = $this.OpenWorkbook($targetFile)
                if ($openResult.Success) {
                    $targetWorkbook = $openResult.Workbook
                }
            } else {
                $createResult = $this.CreateWorkbook($targetFile)
                if ($createResult.Success) {
                    $targetWorkbook = $createResult.Workbook
                }
            }
            
            if (-not $targetWorkbook) {
                $result.Success = $false
                $result.Errors += "Failed to open or create target workbook"
                return $result
            }
            
            # Write data to target cells
            foreach ($fieldName in $data.Keys) {
                if ($mappings.ContainsKey($fieldName)) {
                    $mapping = $mappings[$fieldName]
                    $setResult = $this.SetCellValue($targetSheet, $mapping.Cell, $data[$fieldName], $targetWorkbook)
                    if (-not $setResult.Success) {
                        $result.Errors += "Failed to write $fieldName to $targetSheet!$($mapping.Cell): $($setResult.Error)"
                    }
                }
            }
            
            # Save the workbook
            $saveResult = $this.SaveWorkbook($targetWorkbook)
            if (-not $saveResult.Success) {
                $result.Errors += "Failed to save target workbook: $($saveResult.Error)"
            }
            
            # Close target workbook if it's different from current
            if ($targetWorkbook -ne $this._workbook) {
                $this.CloseWorkbook($targetWorkbook)
            }
        }
        catch {
            $result.Success = $false
            $result.Errors += "Export failed: $_"
        }
        
        if ($result.Errors.Count -gt 0) {
            $result.Success = $false
        }
        
        return $result
    }
    
    [void] Cleanup() {
        if ($this._workbook) {
            $this.CloseWorkbook()
        }
        
        if ($this._excel) {
            try {
                $this._excel.Quit()
                [System.Runtime.Interopservices.Marshal]::ReleaseComObject($this._excel) | Out-Null
            }
            catch {
                Write-Warning "Failed to cleanup Excel COM object: $_"
            }
            finally {
                $this._excel = $null
                $this._isInitialized = $false
            }
        }
    }
    
    # Destructor
    [void] Finalize() {
        $this.Cleanup()
    }
}