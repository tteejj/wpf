# TextExportDialog.ps1 - Dialog for selecting fields and export format for text export

class TextExportDialog : UnifiedDialog {
    [ConfigurationService]$ConfigService
    [TextExportService]$TextExportService
    [hashtable]$ExtractedData = @{}
    
    # UI Components
    [SearchableListBox]$FieldsList
    [MinimalTextBox]$OutputPathBox
    [SimpleListBox]$FormatList
    
    # Results
    [hashtable]$ExportResult = @{}
    [scriptblock]$OnExportComplete = {}
    
    TextExportDialog([hashtable]$extractedData) : base("Text Export - Select Fields and Format", 90, 30) {
        $this.ExtractedData = $extractedData
    }
    
    [void] OnInitialize() {
        # Get services
        $this.ConfigService = $this.ServiceContainer.GetService('ConfigurationService')
        $this.TextExportService = [TextExportService]::new($this.ConfigService)
        
        # Create UI components
        $this.CreateFieldSelection()
        $this.CreateFormatSelection()
        $this.CreateOutputPath()
        $this.SetupNavigation()
        
        # Load saved preferences
        $this.LoadPreferences()
        
        # Call parent initialization
        ([UnifiedDialog]$this).OnInitialize()
    }
    
    [void] CreateFieldSelection() {
        # Add instruction text
        $this.AddField("Instructions", "Instructions", "Select fields to export (Space to toggle, Enter to export)")
        
        # Create multi-select field list
        $this.FieldsList = [SearchableListBox]::new()
        $this.FieldsList.Height = 12
        $this.FieldsList.ShowBorder = $true
        $this.FieldsList.Title = "Available Fields ($($this.ExtractedData.Count) total)"
        $this.FieldsList.ShowSearchBox = $true
        $this.FieldsList.SearchPrompt = "Filter fields: "
        
        # Populate with available fields and their values
        $fieldItems = @()
        foreach ($field in ($this.ExtractedData.Keys | Sort-Object)) {
            $value = if ($this.ExtractedData[$field]) { 
                $this.ExtractedData[$field].ToString() 
            } else { 
                "(empty)" 
            }
            # Truncate long values for display
            if ($value.Length -gt 40) {
                $value = $value.Substring(0, 37) + "..."
            }
            $fieldItems += "$field : $value"
        }
        
        $this.FieldsList.SetItems($fieldItems)
        $this.AddControl($this.FieldsList)
        
        # Add field selection status
        $this.AddField("SelectedCount", "Selected Fields", "0 fields selected")
    }
    
    [void] CreateFormatSelection() {
        # Export format selection
        $this.FormatList = [SimpleListBox]::new()
        $this.FormatList.Height = 6
        $this.FormatList.ShowBorder = $true
        
        # Add supported formats with descriptions
        $formats = @(
            "CSV - Comma-separated values (Excel compatible)"
            "TSV - Tab-separated values" 
            "JSON - JavaScript Object Notation"
            "TXT - Formatted text (human readable)"
            "XML - Extensible Markup Language"
        )
        
        foreach ($format in $formats) {
            $this.FormatList.AddItem($format)
        }
        
        $this.AddControl($this.FormatList)
    }
    
    [void] CreateOutputPath() {
        # Output file path
        $defaultPath = $this.TextExportService.GenerateOutputPath("CSV", ".\")
        $this.AddField("OutputPath", "Output File Path", $defaultPath)
    }
    
    [void] SetupNavigation() {
        $this.SetButtons("Export", "Cancel")
        
        $dialog = $this
        $this.OnSubmit = {
            $dialog.PerformExport()
        }.GetNewClosure()
        
        $this.OnCancel = {
            $dialog.Close()
        }.GetNewClosure()
    }
    
    # Track field selection (simplified for now - would need MultiSelectListBox for full implementation)
    hidden [System.Collections.Generic.HashSet[string]]$SelectedFields = [System.Collections.Generic.HashSet[string]]::new()
    
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$key) {
        # Handle space bar for field selection when field list is focused
        if ($key.Key -eq [System.ConsoleKey]::Spacebar -and $this.FieldsList.IsFocused) {
            $this.ToggleFieldSelection()
            return $true
        }
        
        # Handle format selection updating output path
        if ($this.FormatList.IsFocused) {
            $this.UpdateOutputPath()
        }
        
        return ([UnifiedDialog]$this).HandleScreenInput($key)
    }
    
    [void] ToggleFieldSelection() {
        $selectedItem = $this.FieldsList.GetSelectedItem()
        if ($selectedItem) {
            # Extract field name (before the colon)
            $fieldName = $selectedItem.Split(':')[0].Trim()
            
            if ($this.SelectedFields.Contains($fieldName)) {
                $this.SelectedFields.Remove($fieldName)
            } else {
                $this.SelectedFields.Add($fieldName)
            }
            
            # Update selection count display
            $this.UpdateFieldValue("SelectedCount", "$($this.SelectedFields.Count) fields selected")
            $this.Invalidate()
        }
    }
    
    [void] UpdateOutputPath() {
        $selectedFormat = $this.FormatList.GetSelectedItem()
        if ($selectedFormat) {
            $formatCode = $selectedFormat.Split(' - ')[0]  # Extract format code (CSV, TSV, etc.)
            $newPath = $this.TextExportService.GenerateOutputPath($formatCode, ".\")
            $this.UpdateFieldValue("OutputPath", $newPath)
        }
    }
    
    [void] UpdateFieldValue([string]$fieldName, [string]$newValue) {
        # Find and update the field - simplified implementation
        foreach ($field in $this._fields) {
            if ($field.FieldName -eq $fieldName -and $field -is [MinimalTextBox]) {
                $field.SetText($newValue)
                break
            }
        }
    }
    
    [void] PerformExport() {
        try {
            # Get selected format
            $selectedFormat = $this.FormatList.GetSelectedItem()
            if (-not $selectedFormat) {
                Write-Host "Please select an export format" -ForegroundColor Red
                return
            }
            $formatCode = $selectedFormat.Split(' - ')[0]
            
            # Get output path
            $outputPath = $this.GetFieldValue("OutputPath")
            if (-not $outputPath) {
                Write-Host "Please specify an output file path" -ForegroundColor Red
                return
            }
            
            # Get selected fields (if none selected, export all)
            $fieldsToExport = if ($this.SelectedFields.Count -gt 0) {
                [string[]]$this.SelectedFields
            } else {
                [string[]]$this.ExtractedData.Keys
            }
            
            Write-Host "`nExporting $($fieldsToExport.Count) fields to $formatCode format..." -ForegroundColor Cyan
            
            # Perform the export
            $exportResult = $this.TextExportService.ExportToText(
                $this.ExtractedData,
                $outputPath, 
                $formatCode,
                $fieldsToExport
            )
            
            if ($exportResult.Success) {
                Write-Host "✅ $($exportResult.Message)" -ForegroundColor Green
                Write-Host "   Output file: $($exportResult.OutputPath)" -ForegroundColor Gray
                Write-Host "   Exported fields: $($exportResult.ExportedFields -join ', ')" -ForegroundColor Gray
                
                # Save preferences
                $this.TextExportService.SaveFieldSelection($fieldsToExport, $formatCode)
                
                # Set result for caller
                $this.ExportResult = $exportResult
                
                if ($this.OnExportComplete) {
                    & $this.OnExportComplete $exportResult
                }
                
                Write-Host "`nPress Enter to close..." -ForegroundColor Gray
                Read-Host
                $this.Close()
            } else {
                Write-Host "❌ Export failed: $($exportResult.Message)" -ForegroundColor Red
            }
            
        } catch {
            Write-Host "❌ Export error: $_" -ForegroundColor Red
        }
    }
    
    [void] LoadPreferences() {
        $settings = $this.TextExportService.LoadFieldSelection()
        
        # Set default format selection
        if ($settings.ExportFormat) {
            # Find and select the format in the list
            for ($i = 0; $i -lt $this.FormatList.Items.Count; $i++) {
                if ($this.FormatList.Items[$i].StartsWith($settings.ExportFormat)) {
                    $this.FormatList.SelectedIndex = $i
                    break
                }
            }
        }
        
        # Pre-select previously selected fields
        if ($settings.SelectedFields -and $settings.SelectedFields.Count -gt 0) {
            foreach ($field in $settings.SelectedFields) {
                if ($this.ExtractedData.ContainsKey($field)) {
                    $this.SelectedFields.Add($field)
                }
            }
            $this.UpdateFieldValue("SelectedCount", "$($this.SelectedFields.Count) fields selected")
        }
    }
}