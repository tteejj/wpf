# ExcelMappingSetupDialog.ps1 - Setup dialog for Excel field mappings
# Using REAL Praxis BaseDialog architecture

class ExcelMappingSetupDialog : UnifiedDialog {
    # Configuration service
    [ConfigurationService]$ConfigService
    [ExcelService]$ExcelService
    
    # File selection controls
    [MinimalTextBox]$SourceFileBox
    [MinimalTextBox]$SourceSheetBox
    [MinimalTextBox]$DestFileBox
    [MinimalTextBox]$DestSheetBox
    
    # Field mapping grid
    [MinimalDataGrid]$MappingGrid
    
    ExcelMappingSetupDialog([string]$title, [int]$width, [int]$height) : base($title, $width, $height) {
        # UnifiedDialog handles buttons automatically
    }
    
    [void] OnInitialize() {
        # Get services first
        $this.ConfigService = $this.ServiceContainer.GetService('ConfigurationService')
        $this.ExcelService = $this.ServiceContainer.GetService('ExcelService')
        
        # Create fields BEFORE calling parent initialization
        $this.CreateFileControls()
        $this.CreateMappingGrid()
        $this.LoadSettings()
        $this.SetupEventHandlers()
        
        # Now call parent initialization which will layout the fields
        ([UnifiedDialog]$this).OnInitialize()
    }
    
    [void] CreateFileControls() {
        # Use UnifiedDialog's simple field API
        $this.AddField("SourceFile", "Source Excel File", "C:\path\to\source.xlsx")
        $this.AddField("SourceSheet", "Source Sheet", "SVI-CAS")
        $this.AddField("DestFile", "Destination Excel File", "C:\path\to\destination.xlsx")
        $this.AddField("DestSheet", "Destination Sheet", "Output")
    }
    
    [void] CreateMappingGrid() {
        $this.MappingGrid = [MinimalDataGrid]::new()
        $this.MappingGrid.ShowHeaders = $true
        $this.MappingGrid.Headers = @("Field Name", "Source Cell", "Dest Cell")
        $this.MappingGrid.ColumnWidths = @(25, 15, 15)
        $this.MappingGrid.Height = 12  # Show more rows with scrolling for 40+ fields
        $this.AddControl($this.MappingGrid)  # Use UnifiedDialog API
        
        # Populate with default field mappings
        $this.PopulateDefaultMappings()
    }
    
    [void] PopulateDefaultMappings() {
        # Default field mappings from the original ExcelImportService
        $defaultFields = @(
            @{ FieldName = "RequestDate"; SourceCell = "W23"; DestCell = "" }
            @{ FieldName = "AuditType"; SourceCell = "W78"; DestCell = "" }
            @{ FieldName = "AuditorName"; SourceCell = "W10"; DestCell = "" }
            @{ FieldName = "TPName"; SourceCell = "W3"; DestCell = "" }
            @{ FieldName = "TPEmailAddress"; SourceCell = "X3"; DestCell = "" }
            @{ FieldName = "TPPhoneNumber"; SourceCell = "Y3"; DestCell = "" }
            @{ FieldName = "CorporateContact"; SourceCell = "W5"; DestCell = "" }
            @{ FieldName = "CorporateContactEmail"; SourceCell = "X5"; DestCell = "" }
            @{ FieldName = "CorporateContactPhone"; SourceCell = "Y5"; DestCell = "" }
            @{ FieldName = "SiteName"; SourceCell = "W7"; DestCell = "" }
            @{ FieldName = "SiteAddress"; SourceCell = "W8"; DestCell = "" }
            @{ FieldName = "SiteCity"; SourceCell = "W9"; DestCell = "" }
            @{ FieldName = "SiteState"; SourceCell = "X9"; DestCell = "" }
            @{ FieldName = "SiteZip"; SourceCell = "Y9"; DestCell = "" }
            @{ FieldName = "SiteCountry"; SourceCell = "Z9"; DestCell = "" }
            @{ FieldName = "AttentionContact"; SourceCell = "W11"; DestCell = "" }
            @{ FieldName = "AttentionContactEmail"; SourceCell = "X11"; DestCell = "" }
            @{ FieldName = "AttentionContactPhone"; SourceCell = "Y11"; DestCell = "" }
            @{ FieldName = "TaxID"; SourceCell = "W13"; DestCell = "" }
            @{ FieldName = "DUNS"; SourceCell = "X13"; DestCell = "" }
            @{ FieldName = "CASNumber"; SourceCell = "G17"; DestCell = "" }
            @{ FieldName = "AssetName"; SourceCell = "H17"; DestCell = "" }
            @{ FieldName = "SerialNumber"; SourceCell = "I17"; DestCell = "" }
            @{ FieldName = "ModelNumber"; SourceCell = "J17"; DestCell = "" }
            @{ FieldName = "ManufacturerName"; SourceCell = "K17"; DestCell = "" }
            @{ FieldName = "InstallDate"; SourceCell = "L17"; DestCell = "" }
            @{ FieldName = "Capacity"; SourceCell = "M17"; DestCell = "" }
            @{ FieldName = "CapacityUnit"; SourceCell = "N17"; DestCell = "" }
            @{ FieldName = "TankType"; SourceCell = "O17"; DestCell = "" }
            @{ FieldName = "Product"; SourceCell = "P17"; DestCell = "" }
            @{ FieldName = "LeakDetection"; SourceCell = "Q17"; DestCell = "" }
            @{ FieldName = "Piping"; SourceCell = "R17"; DestCell = "" }
            @{ FieldName = "Monitoring"; SourceCell = "S17"; DestCell = "" }
            @{ FieldName = "Status"; SourceCell = "T17"; DestCell = "" }
            @{ FieldName = "Comments"; SourceCell = "U17"; DestCell = "" }
            @{ FieldName = "ComplianceDate"; SourceCell = "W25"; DestCell = "" }
            @{ FieldName = "NextInspectionDate"; SourceCell = "W27"; DestCell = "" }
            @{ FieldName = "CertificationNumber"; SourceCell = "W29"; DestCell = "" }
            @{ FieldName = "InspectorName"; SourceCell = "W31"; DestCell = "" }
            @{ FieldName = "InspectorLicense"; SourceCell = "W33"; DestCell = "" }
        )
        
        foreach ($field in $defaultFields) {
            $this.MappingGrid.AddItem($field)
        }
    }
    
    [void] SetupEventHandlers() {
        # Use UnifiedDialog's event handler API with proper closure
        $dialog = $this
        $this.OnSubmit = {
            $dialog.SaveSettings()
            Write-Host "`n✅ Configuration saved successfully!" -ForegroundColor Green
            Write-Host "`nYour Excel field mappings are now ready for data processing." -ForegroundColor Cyan
            Write-Host "`nTo process your Excel data, run:" -ForegroundColor Yellow
            Write-Host "  pwsh -File RunDataProcessing.ps1 -Preview   # Preview data first" -ForegroundColor White
            Write-Host "  pwsh -File RunDataProcessing.ps1            # Full processing" -ForegroundColor White
            Write-Host "`nPress Enter to exit..." -ForegroundColor Gray
            Read-Host
            $dialog.Close()
        }.GetNewClosure()
        
        $this.OnCancel = {
            # Exit application
            if ($global:ServiceContainer) {
                $excelService = $global:ServiceContainer.GetService('ExcelService')
                if ($excelService) {
                    $excelService.Cleanup()
                }
            }
            [Environment]::Exit(0)
        }.GetNewClosure()
    }
    
    [void] SaveSettings() {
        if (-not $this.ConfigService) { return }
        
        # Get field values using UnifiedDialog API
        $sourceFile = $this.GetFieldValue("SourceFile")
        $sourceSheet = $this.GetFieldValue("SourceSheet")
        $destFile = $this.GetFieldValue("DestFile")
        $destSheet = $this.GetFieldValue("DestSheet")
        
        # Collect all mappings
        $mappings = @{}
        foreach ($item in $this.MappingGrid.Items) {
            if ($item.FieldName) {
                $mappings[$item.FieldName] = @{
                    Sheet = $sourceSheet
                    Cell = $item.SourceCell
                    DestSheet = $destSheet
                    DestCell = $item.DestCell
                }
            }
        }
        
        # Save configuration
        $config = @{
            SourceFile = $sourceFile
            SourceSheet = $sourceSheet
            DestFile = $destFile
            DestSheet = $destSheet
            FieldMappings = $mappings
        }
        
        $this.ConfigService.SetSetting('ExcelMappings', $config)
    }
    
    [void] LoadSettings() {
        if (-not $this.ConfigService) { return }
        
        $config = $this.ConfigService.GetSetting('ExcelMappings', $null)
        if ($config) {
            # Note: Field values will be set by UnifiedDialog during initialization
            # This method will be called after field creation to update saved values
            
            # Load field mappings if they exist
            if ($config.FieldMappings) {
                $this.MappingGrid.Items.Clear()
                foreach ($fieldName in $config.FieldMappings.Keys) {
                    $mapping = $config.FieldMappings[$fieldName]
                    $item = @{
                        FieldName = $fieldName
                        SourceCell = $mapping.Cell
                        DestCell = $mapping.DestCell
                    }
                    $this.MappingGrid.AddItem($item)
                }
            }
        }
    }
}