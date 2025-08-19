# SimpleProfileSelectionDialog.ps1 - Simplified profile selection dialog

class SimpleProfileSelectionDialog : SimpleDialog {
    [ExportProfileService]$ProfileService
    [ConfigurationService]$ConfigService
    [string]$SelectedProfile = ""
    [string]$SelectedOutputPath = ""
    [string]$SelectedFileName = ""
    [bool]$DialogResult = $false
    [string[]]$ProfileNames = @()
    [int]$SelectedIndex = 0
    
    SimpleProfileSelectionDialog() : base("Select Export Profile") {
        $this.DialogWidth = 80
        $this.DialogHeight = 18
        $this.SetButtons("Export", "Cancel")
    }
    
    [void] InitializeContent() {
        # Initialize services
        $this.ConfigService = $this.ServiceContainer.GetService('ConfigurationService')
        $this.ProfileService = [ExportProfileService]::new($this.ConfigService)
        
        # Load profiles
        $this.ProfileNames = $this.ProfileService.GetProfileNames($true)
        
        # Create default profiles if none exist
        if ($this.ProfileNames.Count -eq 0) {
            $excelConfig = $this.ConfigService.GetExcelMappings()
            if ($excelConfig -and $excelConfig.FieldMappings) {
                $availableFields = @()
                foreach ($fieldName in $excelConfig.FieldMappings.Keys) {
                    $availableFields += $fieldName
                }
                $this.ProfileService.CreateDefaultProfiles($availableFields)
                $this.ProfileNames = $this.ProfileService.GetProfileNames($true)
            }
        }
        
        # Add fields
        $this.AddField("OutputFolder", "Output Folder (F3 to browse)", $PWD.Path)
        $this.AddField("FileName", "File Name", "export_$(Get-Date -Format 'yyyyMMdd_HHmmss')")
        
        # Set up events
        $dialog = $this
        $this.OnSubmit = {
            $dialog.ExecuteExport()
        }.GetNewClosure()
        
        # Set default values
        if ($this.ProfileNames.Count -gt 0) {
            $this.SelectedProfile = $this.ProfileNames[0]
            $this.UpdateFileNameForProfile()
        }
    }
    
    [void] UpdateFileNameForProfile() {
        if ($this.SelectedProfile) {
            $profiles = $this.ProfileService.GetAllProfiles()
            if ($profiles.ContainsKey($this.SelectedProfile)) {
                $profile = $profiles[$this.SelectedProfile]
                $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
                $extension = switch ($profile.ExportFormat.ToLower()) {
                    'csv' { '.csv' }
                    'tsv' { '.tsv' }
                    'json' { '.json' }
                    'xml' { '.xml' }
                    'txt' { '.txt' }
                    default { '.txt' }
                }
                $fileName = "$($this.SelectedProfile.ToLower() -replace '[^a-z0-9]', '_')_$timestamp$extension"
                $this.SetFieldValue("FileName", $fileName)
            }
        }
    }
    
    [void] ShowFileBrowser() {
        try {
            $currentPath = $this.GetFieldValue("OutputFolder")
            if (-not (Test-Path $currentPath -PathType Container)) {
                $currentPath = $PWD.Path
            }
            
            $fileBrowser = [SimpleFileTree]::new($currentPath)
            $fileBrowser.DialogTitle = "Select Output Folder"
            $fileBrowser.AllowDirectories = $true
            $fileBrowser.AllowFiles = $false
            
            $dialog = $this
            $fileBrowser.OnPathSelected = {
                param($path)
                $dialog.SetFieldValue("OutputFolder", $path)
            }.GetNewClosure()
            
            $fileBrowser.ShowDialog()
            if ($fileBrowser.DialogResult) {
                $this.SetFieldValue("OutputFolder", $fileBrowser.SelectedPath)
                $this.Invalidate()
            }
        } catch {
            Write-Host "File browser not available. Please enter path manually." -ForegroundColor Yellow
        }
    }
    
    [void] ExecuteExport() {
        if (-not $this.SelectedProfile) {
            Write-Host "Please select a profile first" -ForegroundColor Yellow
            return
        }
        
        $outputFolder = $this.GetFieldValue("OutputFolder")
        $fileName = $this.GetFieldValue("FileName")
        
        if ([string]::IsNullOrWhiteSpace($outputFolder)) {
            Write-Host "Please specify an output folder" -ForegroundColor Yellow
            return
        }
        
        if ([string]::IsNullOrWhiteSpace($fileName)) {
            Write-Host "Please specify a file name" -ForegroundColor Yellow
            return
        }
        
        if (-not (Test-Path $outputFolder -PathType Container)) {
            Write-Host "Output folder does not exist: $outputFolder" -ForegroundColor Yellow
            return
        }
        
        $this.SelectedOutputPath = Join-Path $outputFolder $fileName
        $this.SelectedFileName = $fileName
        $this.DialogResult = $true
        $this.CloseDialog()
    }
    
    [hashtable] GetExportSettings() {
        if (-not $this.DialogResult -or -not $this.SelectedProfile) {
            return @{
                Success = $false
                Message = "No profile selected"
            }
        }
        
        $profileResult = $this.ProfileService.LoadProfile($this.SelectedProfile)
        if (-not $profileResult.Success) {
            return $profileResult
        }
        
        $profile = $profileResult.Profile
        
        return @{
            Success = $true
            ProfileName = $this.SelectedProfile
            OutputPath = $this.SelectedOutputPath
            FileName = $this.SelectedFileName
            Format = $profile.ExportFormat
            SelectedFields = $profile.SelectedFields
            Profile = $profile
        }
    }
    
    [string] OnRender() {
        $sb = [System.Text.StringBuilder]::new(2048)
        
        # Base dialog
        $baseRender = ([SimpleDialog]$this).Render()
        $sb.Append($baseRender)
        
        # Profile selection area
        $contentX = $this.DialogX + 3
        $contentY = $this.DialogY + 3
        
        # Title
        $sb.Append([VT]::MoveTo($contentX, $contentY))
        $sb.Append([VT]::Blue())
        $sb.Append("Available Export Profiles:")
        
        # Profile list
        if ($this.ProfileNames.Count -eq 0) {
            $sb.Append([VT]::MoveTo($contentX, $contentY + 2))
            $sb.Append([VT]::Red())
            $sb.Append("No profiles found. Create profiles using RunTextExport.ps1 -Interactive")
        } else {
            for ($i = 0; $i -lt $this.ProfileNames.Count; $i++) {
                $profileName = $this.ProfileNames[$i]
                $y = $contentY + 2 + $i
                
                $sb.Append([VT]::MoveTo($contentX, $y))
                
                if ($i -eq $this.SelectedIndex) {
                    $sb.Append([VT]::RGBBG(0, 100, 200))
                    $sb.Append([VT]::White())
                    $sb.Append("→ ")
                } else {
                    $sb.Append([VT]::Reset())
                    $sb.Append("  ")
                }
                
                $sb.Append("$($i + 1). $profileName")
                
                # Show profile details for selected
                if ($i -eq $this.SelectedIndex) {
                    $profiles = $this.ProfileService.GetAllProfiles()
                    if ($profiles.ContainsKey($profileName)) {
                        $profile = $profiles[$profileName]
                        $sb.Append(" ($($profile.SelectedFields.Count) fields, $($profile.ExportFormat))")
                    }
                }
            }
        }
        
        # Instructions
        $instructionsY = $this.DialogY + $this.DialogHeight - 6
        $sb.Append([VT]::MoveTo($contentX, $instructionsY))
        $sb.Append([VT]::Yellow())
        $sb.Append("Use Up/Down to select profile, F3 to browse folders, Tab to edit fields")
        
        return $sb.ToString()
    }
    
    [bool] HandleDialogInput([System.ConsoleKeyInfo]$key) {
        # Handle profile selection
        switch ($key.Key) {
            ([System.ConsoleKey]::UpArrow) {
                if ($this.ProfileNames.Count -gt 0) {
                    $this.SelectedIndex = ($this.SelectedIndex - 1 + $this.ProfileNames.Count) % $this.ProfileNames.Count
                    $this.SelectedProfile = $this.ProfileNames[$this.SelectedIndex]
                    $this.UpdateFileNameForProfile()
                    $this.Invalidate()
                    return $true
                }
            }
            ([System.ConsoleKey]::DownArrow) {
                if ($this.ProfileNames.Count -gt 0) {
                    $this.SelectedIndex = ($this.SelectedIndex + 1) % $this.ProfileNames.Count
                    $this.SelectedProfile = $this.ProfileNames[$this.SelectedIndex]
                    $this.UpdateFileNameForProfile()
                    $this.Invalidate()
                    return $true
                }
            }
            ([System.ConsoleKey]::F3) {
                $this.ShowFileBrowser()
                return $true
            }
        }
        
        # Handle number keys for direct selection
        if ($key.KeyChar -ge '1' -and $key.KeyChar -le '9') {
            $index = [int]$key.KeyChar - 49  # Convert to 0-based index
            if ($index -lt $this.ProfileNames.Count) {
                $this.SelectedIndex = $index
                $this.SelectedProfile = $this.ProfileNames[$this.SelectedIndex]
                $this.UpdateFileNameForProfile()
                $this.Invalidate()
                return $true
            }
        }
        
        # Let parent handle other input
        return ([SimpleDialog]$this).HandleInput($key)
    }
}