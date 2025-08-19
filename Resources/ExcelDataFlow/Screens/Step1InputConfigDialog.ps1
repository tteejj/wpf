# Step1InputConfigDialog.ps1 - Step 1: Input Configuration (4 file/sheet fields)

class Step1InputConfigDialog : UnifiedDialog {
    [ConfigurationService]$ConfigService
    [hashtable]$ConfigData = @{}
    
    # Event for proceeding to next step
    [scriptblock]$OnNext = {}
    
    Step1InputConfigDialog() : base("Step 1 of 3: Input Configuration", 60, 15) {
        
    }
    
    [void] OnInitialize() {
        # Get services
        $this.ConfigService = $this.ServiceContainer.GetService('ConfigurationService')
        
        # Create the 4 input fields
        $this.CreateInputFields()
        
        # Load any saved settings
        $this.LoadSettings()
        
        # Set up navigation buttons
        $this.SetupNavigation()
        
        # Call parent initialization
        ([UnifiedDialog]$this).OnInitialize()
    }
    
    [void] CreateInputFields() {
        $this.AddField("SourceFile", "Source Excel File (F3 to browse)", "C:\path\to\source.xlsx")
        $this.AddField("SourceSheet", "Source Sheet", "SVI-CAS")
        $this.AddField("DestFile", "Destination Excel File (F4 to browse)", "C:\path\to\destination.xlsx")
        $this.AddField("DestSheet", "Destination Sheet", "Output")
    }
    
    [void] SetupNavigation() {
        # Override default buttons with Next/Cancel
        $this.SetButtons("Next", "Cancel")
        
        # Capture the dialog reference for the closure
        $dialog = $this
        $this.OnSubmit = {
            # Collect field values using the captured dialog reference
            $dialog.ConfigData = @{
                SourceFile = $dialog.GetFieldValue("SourceFile")
                SourceSheet = $dialog.GetFieldValue("SourceSheet") 
                DestFile = $dialog.GetFieldValue("DestFile")
                DestSheet = $dialog.GetFieldValue("DestSheet")
            }
            
            # Save settings
            $dialog.SaveSettings()
            
            # Proceed to next step
            if ($dialog.OnNext) {
                & $dialog.OnNext $dialog.ConfigData
            }
        }.GetNewClosure()
        
        $this.OnCancel = {
            # Exit application
            [Environment]::Exit(0)
        }.GetNewClosure()
    }
    
    [void] SaveSettings() {
        if ($this.ConfigService) {
            $this.ConfigService.SetSetting('InputConfig', $this.ConfigData)
        }
    }
    
    [void] LoadSettings() {
        if ($this.ConfigService) {
            $saved = $this.ConfigService.GetSetting('InputConfig', $null)
            if ($saved) {
                # Settings will be applied by UnifiedDialog during field creation
                $this.ConfigData = $saved
            }
        }
    }
    
    [void] ShowFileBrowser([string]$fieldName, [string]$title) {
        # Load the simple file tree component
        . "$PSScriptRoot\..\Components\SimpleFileTree.ps1"
        
        $currentPath = $this.GetFieldValue($fieldName)
        if ([string]::IsNullOrWhiteSpace($currentPath)) {
            $currentPath = $PWD.Path
        } else {
            # If it's a file path, get the directory
            if (Test-Path $currentPath -PathType Leaf) {
                $currentPath = Split-Path $currentPath -Parent
            } elseif (-not (Test-Path $currentPath -PathType Container)) {
                $currentPath = $PWD.Path
            }
        }
        
        try {
            $fileBrowser = [SimpleFileTree]::new($currentPath)
            $fileBrowser.DialogTitle = $title
            $fileBrowser.AllowDirectories = $true
            $fileBrowser.AllowFiles = $true
            
            $dialog = $this
            $fileBrowser.OnPathSelected = {
                param($path)
                $dialog.SetFieldValue($fieldName, $path)
            }.GetNewClosure()
            
            $fileBrowser.ShowDialog()
            if ($fileBrowser.DialogResult) {
                $this.SetFieldValue($fieldName, $fileBrowser.SelectedPath)
                $this.Invalidate()
            }
        } catch {
            # Fallback to manual input if file browser fails
            Write-Host "File browser not available. Please enter path manually." -ForegroundColor Yellow
        }
    }
    
    [bool] HandleDialogInput([System.ConsoleKeyInfo]$key) {
        # Handle file browser shortcuts
        if ($key.Key -eq [System.ConsoleKey]::F3) {
            $this.ShowFileBrowser("SourceFile", "Select Source Excel File")
            return $true
        }
        
        if ($key.Key -eq [System.ConsoleKey]::F4) {
            $this.ShowFileBrowser("DestFile", "Select Destination Excel File")
            return $true
        }
        
        # Let parent handle other input
        return ([UnifiedDialog]$this).HandleDialogInput($key)
    }
}