# Step2SourceMappingDialog.ps1 - Step 2: Source Field Mapping (scrollable list)

class Step2SourceMappingDialog : UnifiedDialog {
    [ConfigurationService]$ConfigService
    [SimpleListBox]$FieldsList
    [MinimalTextBox]$SourceCellBox
    [hashtable]$InputConfig = @{}
    [hashtable]$SourceMappings = @{}
    [array]$FieldNames = @()
    [int]$CurrentFieldIndex = -1
    
    # Navigation events
    [scriptblock]$OnNext = {}
    [scriptblock]$OnPrevious = {}
    
    Step2SourceMappingDialog([hashtable]$inputConfig) : base("Step 2 of 3: Source Field Mapping", 70, 25) {
        $this.InputConfig = $inputConfig
        $this.InitializeFieldNames()
    }
    
    [void] InitializeFieldNames() {
        # All 40+ field names from the original mapping
        $this.FieldNames = @(
            "RequestDate", "AuditType", "AuditorName", "TPName", "TPEmailAddress", "TPPhoneNumber",
            "CorporateContact", "CorporateContactEmail", "CorporateContactPhone", "SiteName", 
            "SiteAddress", "SiteCity", "SiteState", "SiteZip", "SiteCountry", "AttentionContact",
            "AttentionContactEmail", "AttentionContactPhone", "TaxID", "DUNS", "CASNumber",
            "AssetName", "SerialNumber", "ModelNumber", "ManufacturerName", "InstallDate",
            "Capacity", "CapacityUnit", "TankType", "Product", "LeakDetection", "Piping",
            "Monitoring", "Status", "Comments", "ComplianceDate", "NextInspectionDate",
            "CertificationNumber", "InspectorName", "InspectorLicense"
        )
        
        # Initialize with default source cells
        $defaultMappings = @{
            "RequestDate" = "W23"; "AuditType" = "W78"; "AuditorName" = "W10"; "TPName" = "W3"
            "TPEmailAddress" = "X3"; "TPPhoneNumber" = "Y3"; "CorporateContact" = "W5"
            "CorporateContactEmail" = "X5"; "CorporateContactPhone" = "Y5"; "SiteName" = "W7"
            "SiteAddress" = "W8"; "SiteCity" = "W9"; "SiteState" = "X9"; "SiteZip" = "Y9"
            "SiteCountry" = "Z9"; "AttentionContact" = "W11"; "AttentionContactEmail" = "X11"
            "AttentionContactPhone" = "Y11"; "TaxID" = "W13"; "DUNS" = "X13"; "CASNumber" = "G17"
            "AssetName" = "H17"; "SerialNumber" = "I17"; "ModelNumber" = "J17"
            "ManufacturerName" = "K17"; "InstallDate" = "L17"; "Capacity" = "M17"
            "CapacityUnit" = "N17"; "TankType" = "O17"; "Product" = "P17"
            "LeakDetection" = "Q17"; "Piping" = "R17"; "Monitoring" = "S17"; "Status" = "T17"
            "Comments" = "U17"; "ComplianceDate" = "W25"; "NextInspectionDate" = "W27"
            "CertificationNumber" = "W29"; "InspectorName" = "W31"; "InspectorLicense" = "W33"
        }
        
        foreach ($field in $this.FieldNames) {
            $this.SourceMappings[$field] = $defaultMappings[$field]
        }
    }
    
    [void] OnInitialize() {
        # Get services
        $this.ConfigService = $this.ServiceContainer.GetService('ConfigurationService')
        
        # Show input config summary at top
        $this.ShowInputSummary()
        
        # Create scrollable field list
        $this.CreateFieldsList()
        
        # Create source cell edit box
        $this.CreateSourceCellEditor()
        
        # Set up navigation
        $this.SetupNavigation()
        
        # Load saved mappings
        $this.LoadSettings()
        
        # Call parent initialization
        ([UnifiedDialog]$this).OnInitialize()
    }
    
    [void] ShowInputSummary() {
        $summary = "Source: $($this.InputConfig.SourceFile) [$($this.InputConfig.SourceSheet)] → Dest: $($this.InputConfig.DestFile) [$($this.InputConfig.DestSheet)]"
        $this.AddField("Summary", "Configuration", $summary)
    }
    
    [void] CreateFieldsList() {
        $this.FieldsList = [SimpleListBox]::new()
        $this.FieldsList.Height = 12
        $this.FieldsList.ShowBorder = $true
        
        # Populate with field names
        foreach ($field in $this.FieldNames) {
            $sourceCell = $this.SourceMappings[$field]
            $displayText = "$field → $sourceCell"
            $this.FieldsList.AddItem($displayText)
        }
        
        # Handle selection change
        $dialog = $this
        $this.FieldsList.OnSelectionChanged = {
            $dialog.OnFieldSelected()
        }.GetNewClosure()
        
        $this.AddControl($this.FieldsList)
    }
    
    [void] CreateSourceCellEditor() {
        $this.SourceCellBox = [MinimalTextBox]::new()
        $this.SourceCellBox.Height = 1
        $this.SourceCellBox.Placeholder = "Enter source cell (e.g., W23, L17)"
        
        $this.SourceCellBox | Add-Member -NotePropertyName "FieldName" -NotePropertyValue "SourceCell"
        $this.SourceCellBox | Add-Member -NotePropertyName "Label" -NotePropertyValue "Source Cell"
        
        $this.AddControl($this.SourceCellBox)
    }
    
    [void] OnFieldSelected() {
        $selectedIndex = $this.FieldsList.SelectedIndex
        if ($selectedIndex -ge 0 -and $selectedIndex -lt $this.FieldNames.Count) {
            $this.CurrentFieldIndex = $selectedIndex
            $fieldName = $this.FieldNames[$selectedIndex]
            $sourceCell = $this.SourceMappings[$fieldName]
            $this.SourceCellBox.SetText($sourceCell)
        }
    }
    
    [void] UpdateCurrentField() {
        if ($this.CurrentFieldIndex -ge 0) {
            $fieldName = $this.FieldNames[$this.CurrentFieldIndex]
            $newSourceCell = $this.SourceCellBox.Text
            $this.SourceMappings[$fieldName] = $newSourceCell
            
            # Update display in list
            $displayText = "$fieldName → $newSourceCell"
            $this.FieldsList.Items[$this.CurrentFieldIndex] = $displayText
            $this.FieldsList.Invalidate()
        }
    }
    
    [void] SetupNavigation() {
        $this.SetButtons("Next", "Previous")
        
        # Capture dialog reference for closures
        $dialog = $this
        $this.OnSubmit = {
            # Update current field before proceeding
            $dialog.UpdateCurrentField()
            
            # Save mappings
            $dialog.SaveSettings()
            
            # Proceed to next step
            if ($dialog.OnNext) {
                & $dialog.OnNext $dialog.InputConfig $dialog.SourceMappings
            }
        }.GetNewClosure()
        
        $this.OnCancel = {
            # Go back to previous step
            if ($dialog.OnPrevious) {
                & $dialog.OnPrevious
            }
        }.GetNewClosure()
    }
    
    [void] SaveSettings() {
        if ($this.ConfigService) {
            $this.ConfigService.SetSetting('SourceMappings', $this.SourceMappings)
        }
    }
    
    [void] LoadSettings() {
        if ($this.ConfigService) {
            $saved = $this.ConfigService.GetSetting('SourceMappings', $null)
            if ($saved) {
                $this.SourceMappings = $saved
                # Refresh the list display
                for ($i = 0; $i -lt $this.FieldNames.Count; $i++) {
                    $fieldName = $this.FieldNames[$i]
                    $sourceCell = $this.SourceMappings[$fieldName]
                    $this.FieldsList.Items[$i] = "$fieldName → $sourceCell"
                }
            }
        }
    }
    
    # Handle key input for updating fields
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$key) {
        if ($key.Key -eq [System.ConsoleKey]::Enter -and $this.SourceCellBox.IsFocused) {
            $this.UpdateCurrentField()
            return $true
        }
        
        return ([UnifiedDialog]$this).HandleScreenInput($key)
    }
}