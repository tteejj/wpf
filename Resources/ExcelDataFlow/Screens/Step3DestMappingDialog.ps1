# Step3DestMappingDialog.ps1 - Step 3: Destination Field Mapping (scrollable list)

class Step3DestMappingDialog : UnifiedDialog {
    [ConfigurationService]$ConfigService
    [SimpleListBox]$FieldsList
    [MinimalTextBox]$DestCellBox
    [hashtable]$InputConfig = @{}
    [hashtable]$SourceMappings = @{}
    [hashtable]$DestMappings = @{}
    [array]$FieldNames = @()
    [int]$CurrentFieldIndex = -1
    
    # Navigation events
    [scriptblock]$OnSave = {}
    [scriptblock]$OnPrevious = {}
    
    Step3DestMappingDialog([hashtable]$inputConfig, [hashtable]$sourceMappings) : base("Step 3 of 3: Destination Field Mapping", 80, 25) {
        $this.InputConfig = $inputConfig
        $this.SourceMappings = $sourceMappings
        $this.FieldNames = $sourceMappings.Keys
        
        # Initialize destination mappings (empty by default)
        foreach ($field in $this.FieldNames) {
            $this.DestMappings[$field] = ""
        }
    }
    
    [void] OnInitialize() {
        # Get services
        $this.ConfigService = $this.ServiceContainer.GetService('ConfigurationService')
        
        # Show config summary
        $this.ShowConfigSummary()
        
        # Create scrollable field list showing source mappings
        $this.CreateFieldsList()
        
        # Create destination cell edit box
        $this.CreateDestCellEditor()
        
        # Set up navigation
        $this.SetupNavigation()
        
        # Load saved destination mappings
        $this.LoadSettings()
        
        # Call parent initialization
        ([UnifiedDialog]$this).OnInitialize()
    }
    
    [void] ShowConfigSummary() {
        $summary = "Source: $($this.InputConfig.SourceFile) [$($this.InputConfig.SourceSheet)] → Dest: $($this.InputConfig.DestFile) [$($this.InputConfig.DestSheet)]"
        $this.AddField("Summary", "Configuration", $summary)
    }
    
    [void] CreateFieldsList() {
        $this.FieldsList = [SimpleListBox]::new()
        $this.FieldsList.Height = 12
        $this.FieldsList.ShowBorder = $true
        
        # Populate with field names showing source mapping and destination field
        foreach ($field in $this.FieldNames) {
            $sourceCell = $this.SourceMappings[$field]
            $destCell = $this.DestMappings[$field]
            $displayText = "$field | $sourceCell | $destCell"
            $this.FieldsList.AddItem($displayText)
        }
        
        # Handle selection change
        $dialog = $this
        $this.FieldsList.OnSelectionChanged = {
            $dialog.OnFieldSelected()
        }.GetNewClosure()
        
        $this.AddControl($this.FieldsList)
    }
    
    [void] CreateDestCellEditor() {
        $this.DestCellBox = [MinimalTextBox]::new()
        $this.DestCellBox.Height = 1
        $this.DestCellBox.Placeholder = "Enter destination cell (e.g., A1, B2)"
        
        $this.DestCellBox | Add-Member -NotePropertyName "FieldName" -NotePropertyValue "DestCell"
        $this.DestCellBox | Add-Member -NotePropertyName "Label" -NotePropertyValue "Destination Cell"
        
        $this.AddControl($this.DestCellBox)
    }
    
    [void] OnFieldSelected() {
        $selectedIndex = $this.FieldsList.SelectedIndex
        if ($selectedIndex -ge 0 -and $selectedIndex -lt $this.FieldNames.Count) {
            $this.CurrentFieldIndex = $selectedIndex
            $fieldName = $this.FieldNames[$selectedIndex]
            $destCell = $this.DestMappings[$fieldName]
            $this.DestCellBox.SetText($destCell)
        }
    }
    
    [void] UpdateCurrentField() {
        if ($this.CurrentFieldIndex -ge 0) {
            $fieldName = $this.FieldNames[$this.CurrentFieldIndex]
            $newDestCell = $this.DestCellBox.Text
            $this.DestMappings[$fieldName] = $newDestCell
            
            # Update display in list
            $sourceCell = $this.SourceMappings[$fieldName]
            $displayText = "$fieldName | $sourceCell | $newDestCell"
            $this.FieldsList.Items[$this.CurrentFieldIndex] = $displayText
            $this.FieldsList.Invalidate()
        }
    }
    
    [void] SetupNavigation() {
        $this.SetButtons("Save", "Previous")
        
        # Capture dialog reference for closures
        $dialog = $this
        $this.OnSubmit = {
            # Update current field before saving
            $dialog.UpdateCurrentField()
            
            # Save all mappings
            $dialog.SaveAllSettings()
            
            # Complete the workflow
            Write-Host "Excel field mappings saved successfully!" -ForegroundColor Green
            Write-Host "Configuration complete. Ready for Excel operations." -ForegroundColor Green
            
            if ($dialog.OnSave) {
                & $dialog.OnSave $dialog.InputConfig $dialog.SourceMappings $dialog.DestMappings
            }
            
            # Exit application
            [Environment]::Exit(0)
        }.GetNewClosure()
        
        $this.OnCancel = {
            # Go back to previous step
            if ($dialog.OnPrevious) {
                & $dialog.OnPrevious
            }
        }.GetNewClosure()
    }
    
    [void] SaveAllSettings() {
        if ($this.ConfigService) {
            # Save complete configuration
            $completeConfig = @{
                InputConfig = $this.InputConfig
                SourceMappings = $this.SourceMappings
                DestMappings = $this.DestMappings
                Timestamp = (Get-Date).ToString()
            }
            
            $this.ConfigService.SetSetting('CompleteExcelMapping', $completeConfig)
            $this.ConfigService.SetSetting('DestMappings', $this.DestMappings)
        }
    }
    
    [void] LoadSettings() {
        if ($this.ConfigService) {
            $saved = $this.ConfigService.GetSetting('DestMappings', $null)
            if ($saved) {
                $this.DestMappings = $saved
                # Refresh the list display
                for ($i = 0; $i -lt $this.FieldNames.Count; $i++) {
                    $fieldName = $this.FieldNames[$i]
                    $sourceCell = $this.SourceMappings[$fieldName]
                    $destCell = $this.DestMappings[$fieldName]
                    $this.FieldsList.Items[$i] = "$fieldName | $sourceCell | $destCell"
                }
            }
        }
    }
    
    # Handle key input for updating fields
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$key) {
        if ($key.Key -eq [System.ConsoleKey]::Enter -and $this.DestCellBox.IsFocused) {
            $this.UpdateCurrentField()
            return $true
        }
        
        return ([UnifiedDialog]$this).HandleScreenInput($key)
    }
}