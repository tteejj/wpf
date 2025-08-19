# IntegratedWorkflowManager.ps1 - Complete workflow management with profile integration

class IntegratedWorkflowManager {
    [object]$ServiceContainer = $null
    [ConfigurationService]$ConfigService = $null
    [ExportProfileService]$ProfileService = $null
    [TextExportService]$TextExportService = $null
    [DataProcessingService]$DataService = $null
    
    # Current state
    [string]$CurrentFlow = ""  # "startup", "wizard", "post_config", "profile_export"
    [object]$CurrentScreen = $null
    
    # Data
    [hashtable]$ConfigData = @{}
    [hashtable]$SourceMappings = @{}
    [hashtable]$DestMappings = @{}
    
    IntegratedWorkflowManager([object]$serviceContainer) {
        $this.ServiceContainer = $serviceContainer
        $this.ConfigService = $serviceContainer.GetService('ConfigurationService')
        
        # Initialize additional services
        $this.ProfileService = [ExportProfileService]::new($this.ConfigService)
        $this.TextExportService = [TextExportService]::new($this.ConfigService)
        
        # DataProcessingService needs both ExcelService and ConfigService
        $excelService = $serviceContainer.GetService('ExcelService')
        $this.DataService = [DataProcessingService]::new($excelService, $this.ConfigService)
    }
    
    [void] Start() {
        Write-Host "Starting ExcelDataFlow Integrated Workflow..." -ForegroundColor Cyan
        
        # Check if we have existing configuration
        $existingConfig = $this.ConfigService.GetExcelMappings()
        $hasConfig = $existingConfig -and $existingConfig.SourceFile
        
        if ($hasConfig) {
            # Show startup selection (profile export vs reconfigure)
            $this.ShowStartupSelection()
        } else {
            # No config, go straight to wizard
            $this.StartWizard()
        }
    }
    
    [void] ShowStartupSelection() {
        $this.CurrentFlow = "startup"
        Write-Host "Loading startup options..." -ForegroundColor Yellow
        
        # Load required classes
        . "$PSScriptRoot\StartupSelectionDialog.ps1"
        
        $dialog = [StartupSelectionDialog]::new()
        
        # Set up navigation
        $manager = $this
        $dialog.OnSelect = {
            # First set the SelectedOption based on SelectedIndex
            switch ($dialog.SelectedIndex) {
                0 { $dialog.SelectedOption = "profile" }
                1 { $dialog.SelectedOption = "configure" }
            }
            
            # Then handle the selection
            $selection = $dialog.SelectedOption
            if ($selection -eq "profile") {
                $manager.StartProfileExport()
            } elseif ($selection -eq "configure") {
                $manager.StartWizard()
            }
        }.GetNewClosure()
        
        $dialog.OnCancel = {
            Write-Host "Exiting ExcelDataFlow..." -ForegroundColor Cyan
            [Environment]::Exit(0)
        }.GetNewClosure()
        
        # Show dialog using SimpleDialog system
        $dialog.Show()
    }
    
    [void] StartProfileExport() {
        $this.CurrentFlow = "profile_export"
        Write-Host "Starting profile-based export..." -ForegroundColor Yellow
        
        # Load required classes
        . "$PSScriptRoot\ProfileSelectionDialog.ps1"
        
        try {
            # Create default profiles if none exist
            $existingProfiles = $this.ProfileService.GetProfileNames($false)
            if ($existingProfiles.Count -eq 0) {
                Write-Host "Creating default profiles..." -ForegroundColor Cyan
                $excelConfig = $this.ConfigService.GetExcelMappings()
                $availableFields = @()
                foreach ($fieldName in $excelConfig.FieldMappings.Keys) {
                    $availableFields += $fieldName
                }
                $this.ProfileService.CreateDefaultProfiles($availableFields)
            }
            
            $dialog = [ProfileSelectionDialog]::new()
            
            $manager = $this
            $dialog.OnSelect = {
                [Logger]::Info("=== IntegratedWorkflowManager.OnSelect triggered ===")
                # Just prepare the export settings, don't do the actual export here
                $dialog.ExportWithSelectedProfile()
                [Logger]::Info("Profile selection completed, dialog will exit")
            }.GetNewClosure()
            
            $dialog.OnCancel = {
                $manager.ShowStartupSelection()
            }.GetNewClosure()
            
            # Show dialog and wait for it to complete
            [Logger]::Info("Showing ProfileSelectionDialog...")
            $dialog.Show()
            
            # After dialog completes, check if export was set up and execute it
            [Logger]::Info("Dialog completed, checking DialogResult: $($dialog.DialogResult)")
            if ($dialog.DialogResult) {
                [Logger]::Info("Dialog successful, executing export...")
                $this.ExecuteProfileExport($dialog)
            } else {
                [Logger]::Info("Dialog was cancelled or failed")
                $this.ShowStartupSelection()
            }
            
        } catch {
            Write-Host "Failed to start profile export: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Falling back to configuration wizard..." -ForegroundColor Yellow
            $this.StartWizard()
        }
    }
    
    [void] ExecuteProfileExport([object]$dialog) {
        [Logger]::Info("=== ExecuteProfileExport started ===")
        [Logger]::Debug("Dialog DialogResult: $($dialog.DialogResult)")
        
        # Get export settings from the dialog (ExportWithSelectedProfile already called in OnSelect)
        [Logger]::Info("Getting export settings from dialog...")
        $exportSettings = $dialog.GetExportSettings()
        [Logger]::Debug("GetExportSettings result: Success=$($exportSettings.Success)")
        if (-not $exportSettings.Success) {
            [Logger]::Error("Export failed: $($exportSettings.Message)")
            return
        }
        
        [Logger]::Info("Export settings obtained successfully")
        [Logger]::Debug("Output path: $($exportSettings.OutputPath)")
        [Logger]::Debug("Format: $($exportSettings.Format)")
        [Logger]::Debug("Selected fields count: $($exportSettings.SelectedFields.Count)")
        
        try {
            [Logger]::Info("Starting data extraction from Excel...")
            
            # Get Excel configuration for data extraction
            $config = $this.ConfigService.GetSetting('ExcelMappings', $null)
            if (-not $config) {
                [Logger]::Error("No Excel configuration found")
                Write-Host "❌ No Excel configuration found! Please run setup first." -ForegroundColor Red
                return
            }
            
            # Open source workbook first
            [Logger]::Info("Opening source workbook...")
            $sourceResult = $this.DataService.OpenSourceWorkbook($config)
            if (-not $sourceResult.Success) {
                [Logger]::Error("Failed to open source workbook: $($sourceResult.Error)")
                Write-Host "❌ Failed to open Excel file: $($sourceResult.Error)" -ForegroundColor Red
                return
            }
            
            # Extract data with configuration
            [Logger]::Info("Extracting data with field mappings...")
            $dataResult = $this.DataService.ExtractData($config)
            [Logger]::Debug("ExtractData result: Success=$($dataResult.Success)")
            if (-not $dataResult.Success) {
                [Logger]::Error("Failed to extract data")
                if ($dataResult.Errors) {
                    foreach ($error in $dataResult.Errors) {
                        [Logger]::Error("  - $error")
                    }
                }
                return
            }
            
            [Logger]::Info("Data extraction successful, starting text export...")
            [Logger]::Info("Exporting to $($exportSettings.Format)...")
            $exportResult = $this.TextExportService.ExportToText(
                $dataResult.Data,
                $exportSettings.OutputPath,
                $exportSettings.Format,
                $exportSettings.SelectedFields
            )
            
            [Logger]::Debug("ExportToText result: Success=$($exportResult.Success)")
            
            if ($exportResult.Success) {
                [Logger]::Success("Export completed successfully!")
                Write-Host ""
                Write-Host "✅ Export completed successfully!" -ForegroundColor Green
                Write-Host "File: $($exportSettings.OutputPath)" -ForegroundColor Cyan
                Write-Host "Records: $($exportResult.RecordCount)" -ForegroundColor Cyan
                Write-Host "Fields: $($exportResult.FieldCount)" -ForegroundColor Cyan
                Write-Host ""
                
                # Offer to continue or exit
                $continue = Read-Host "Continue with another export? (y/N)"
                if ($continue -match '^[Yy]') {
                    $this.ShowStartupSelection()
                } else {
                    Write-Host "Exiting ExcelDataFlow..." -ForegroundColor Cyan
                    [Environment]::Exit(0)
                }
            } else {
                [Logger]::Error("Export to text failed: $($exportResult.Message)")
                Write-Host "Export failed: $($exportResult.Message)" -ForegroundColor Red
            }
            
        } catch {
            [Logger]::Error("Export failed with exception: $($_.Exception.Message)")
            Write-Host "Export failed with error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    [void] StartWizard() {
        $this.CurrentFlow = "wizard"
        Write-Host "Starting Excel Mapping Configuration..." -ForegroundColor Cyan
        Write-Host ""
        
        try {
            # Check if the mapping tool exists
            $mappingToolPath = "$PSScriptRoot\..\ExcelMappingTool.ps1"
            if (Test-Path $mappingToolPath) {
                Write-Host "Launching Excel Mapping Tool..." -ForegroundColor Yellow
                Write-Host "Use the tool to configure your Excel mappings, then return here." -ForegroundColor Gray
                Write-Host ""
                
                # Run the mapping tool
                & $mappingToolPath
                
                Write-Host ""
                Write-Host "Mapping tool completed. Returning to main menu..." -ForegroundColor Green
                Start-Sleep -Seconds 1
                $this.ShowStartupSelection()
            } else {
                Write-Host "❌ Excel Mapping Tool not found at: $mappingToolPath" -ForegroundColor Red
                Write-Host "Please configure mappings manually or check installation." -ForegroundColor Yellow
                Write-Host ""
                Read-Host "Press Enter to return to main menu"
                $this.ShowStartupSelection()
            }
        } catch {
            Write-Host "❌ Failed to launch mapping tool: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host ""
            Read-Host "Press Enter to return to main menu"
            $this.ShowStartupSelection()
        }
    }
    
    # Wizard methods temporarily disabled
    # [void] ShowStep1() { ... }
    # [void] ShowStep2() { ... }
    # [void] ShowStep3() { ... }
    
    [void] ShowPostConfiguration() {
        $this.CurrentFlow = "post_config"
        Write-Host "Configuration complete! Showing options..." -ForegroundColor Green
        
        # Load post-configuration dialog
        . "$PSScriptRoot\PostConfigurationDialog.ps1"
        
        $fieldCount = $this.SourceMappings.Count
        $dialog = [PostConfigurationDialog]::new($fieldCount)
        
        $manager = $this
        $dialog.OnSelect = {
            $selection = $dialog.SelectedOption
            switch ($selection) {
                "profile_export" { $manager.StartTextExportWithProfile() }
                "test_processing" { $manager.RunTestProcessing() }
                "full_processing" { $manager.RunFullProcessing() }
                "exit" { 
                    Write-Host "Exiting ExcelDataFlow..." -ForegroundColor Cyan
                    [Environment]::Exit(0)
                }
            }
        }.GetNewClosure()
        
        $dialog.Show()
    }
    
    [void] StartTextExportWithProfile() {
        Write-Host "Starting interactive text export..." -ForegroundColor Cyan
        
        # Load text export dialog
        . "$PSScriptRoot\..\RunTextExport.ps1"
        
        try {
            # Run interactive text export
            & "$PSScriptRoot\..\RunTextExport.ps1" -Interactive
            
            # After export, show options again
            $this.ShowPostConfiguration()
            
        } catch {
            Write-Host "Text export failed: $($_.Exception.Message)" -ForegroundColor Red
            $this.ShowPostConfiguration()
        }
    }
    
    [void] RunTestProcessing() {
        Write-Host "Running test data processing..." -ForegroundColor Cyan
        
        try {
            # Get Excel configuration for data extraction
            $config = $this.ConfigService.GetSetting('ExcelMappings', $null)
            if (-not $config) {
                Write-Host "❌ No Excel configuration found! Please run setup first." -ForegroundColor Red
                Write-Host ""
                Read-Host "Press Enter to continue"
                $this.ShowPostConfiguration()
                return
            }
            
            # Open source workbook first
            $sourceResult = $this.DataService.OpenSourceWorkbook($config)
            if (-not $sourceResult.Success) {
                Write-Host "❌ Failed to open Excel file: $($sourceResult.Error)" -ForegroundColor Red
                Write-Host ""
                Read-Host "Press Enter to continue"
                $this.ShowPostConfiguration()
                return
            }
            
            $dataResult = $this.DataService.ExtractData($config)
            if ($dataResult.Success) {
                Write-Host "✅ Test processing successful!" -ForegroundColor Green
                Write-Host "Extracted $($dataResult.Data.Count) fields" -ForegroundColor Cyan
                
                # Show sample data
                $count = 0
                foreach ($field in $dataResult.Data.GetEnumerator()) {
                    Write-Host "  $($field.Key): $($field.Value)" -ForegroundColor Gray
                    $count++
                    if ($count -ge 5) { 
                        Write-Host "  ... and $($dataResult.Data.Count - 5) more fields" -ForegroundColor Gray
                        break 
                    }
                }
            } else {
                Write-Host "Test processing failed" -ForegroundColor Red
                if ($dataResult.Errors) {
                    foreach ($error in $dataResult.Errors) {
                        Write-Host "  - $error" -ForegroundColor Red
                    }
                }
            }
        } catch {
            Write-Host "Test processing failed: $($_.Exception.Message)" -ForegroundColor Red
        }
        
        Write-Host ""
        Read-Host "Press Enter to continue"
        $this.ShowPostConfiguration()
    }
    
    [void] RunFullProcessing() {
        Write-Host "Running full Excel processing..." -ForegroundColor Cyan
        
        try {
            $result = $this.DataService.ProcessDataWorkflow($false)
            if ($result.Success) {
                Write-Host "✅ Full processing completed successfully!" -ForegroundColor Green
                Write-Host "Processed $($result.ProcessedFields) fields" -ForegroundColor Cyan
            } else {
                Write-Host "Full processing failed: $($result.Message)" -ForegroundColor Red
            }
        } catch {
            Write-Host "Full processing failed: $($_.Exception.Message)" -ForegroundColor Red
        }
        
        Write-Host ""
        Read-Host "Press Enter to continue"
        $this.ShowPostConfiguration()
    }
    
}