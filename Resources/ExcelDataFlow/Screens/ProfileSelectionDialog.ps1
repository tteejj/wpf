# ProfileSelectionDialog.ps1 - Select and manage export profiles with file browser integration

. "$PSScriptRoot\..\Base\SimpleDialog.ps1"
. "$PSScriptRoot\..\Services\ExportProfileService.ps1"
. "$PSScriptRoot\..\Services\ConfigurationService.ps1"
. "$PSScriptRoot\..\Services\TextExportService.ps1"

class ProfileSelectionDialog : SimpleDialog {
    [string]$SelectedProfile = ""
    [string]$SelectedOutputPath = ""
    [string]$SelectedFileName = ""
    [string]$OutputPath = ""
    [string]$FileName = ""
    
    # Services
    [ExportProfileService]$ProfileService
    [ConfigurationService]$ConfigService
    [TextExportService]$TextExportService
    
    # Internal state
    [hashtable]$_profiles = @{}
    [string[]]$_profileNames = @()
    
    ProfileSelectionDialog() : base("Select Export Profile") {
        $this.Width = 100
        $this.Height = 25
        $this.Description = "Select a profile and specify output location for text export"
        $this.Instructions = "Use Up/Down to select profile, F3 to browse folders, Tab to edit fields, Enter to export"
        
        # Initialize services
        $configPath = "$PSScriptRoot\..\_Config\settings.json"
        $this.ConfigService = [ConfigurationService]::new($configPath)
        $this.ProfileService = [ExportProfileService]::new($this.ConfigService)
        $this.TextExportService = [TextExportService]::new($this.ConfigService)
        
        # Set default output path and filename
        $this.OutputPath = $PWD.Path
        $this.FileName = "export_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        
        # Load profiles
        $this.RefreshProfiles()
        
        # Ensure initial selection is set
        $this.UpdateProfileSelection()
        
        # Set up event handlers
        $dialog = $this
        $this.OnSelect = {
            [Logger]::Info("=== ProfileSelectionDialog.OnSelect triggered ===")
            [Logger]::Info("Selected Profile: '$($dialog.SelectedProfile)'")
            [Logger]::Info("Selected Index: $($dialog.SelectedIndex)")
            
            # Just set DialogResult to indicate selection was made
            # The workflow manager will call ExportWithSelectedProfile
            $dialog.DialogResult = $true
            [Logger]::Success("ProfileSelectionDialog DialogResult set to true")
        }.GetNewClosure()
    }
    
    [void] RefreshProfiles() {
        $this._profileNames = $this.ProfileService.GetProfileNames($true)  # Sort by usage
        $this._profiles = $this.ProfileService.GetAllProfiles()
        
        # Build profile display items
        $items = @()
        foreach ($profileName in $this._profileNames) {
            $profile = $this._profiles[$profileName]
            $fieldCount = $profile.SelectedFields.Count
            $format = $profile.ExportFormat
            $useCount = $profile.UseCount
            
            $displayText = "$profileName ($fieldCount fields, $format)"
            if ($useCount -gt 0) {
                $displayText += " - Used $useCount times"
            }
            
            $items += $displayText
        }
        
        if ($items.Count -eq 0) {
            $items += "No profiles found - create some first"
        }
        
        $this.Options = $items
        
        # Select first profile by default
        if ($this._profileNames.Count -gt 0) {
            $this.SelectedIndex = 0
            $this.UpdateProfileSelection()
        }
    }
    
    [void] UpdateProfileSelection() {
        if ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this._profileNames.Count) {
            $this.SelectedProfile = $this._profileNames[$this.SelectedIndex]
            $profile = $this._profiles[$this.SelectedProfile]
            
            # Update file name to include format
            if ($profile) {
                $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
                $extension = switch ($profile.ExportFormat.ToLower()) {
                    'csv' { '.csv' }
                    'tsv' { '.tsv' }
                    'json' { '.json' }
                    'xml' { '.xml' }
                    'txt' { '.txt' }
                    default { '.txt' }
                }
                $this.FileName = "$($this.SelectedProfile.ToLower() -replace '[^a-z0-9]', '_')_$timestamp$extension"
            }
        }
    }
    
    [string] RenderOptions() {
        $sb = [System.Text.StringBuilder]::new(2048)
        
        # Profiles list
        $profilesY = $this.Y + 5
        $profilesX = $this.X + 3
        $profilesWidth = 45
        $profilesHeight = 10
        
        # Profiles box
        $sb.Append([VT]::MoveTo($profilesX, $profilesY))
        $sb.Append([VT]::White())
        $sb.Append("Available Export Profiles:")
        
        $sb.Append([VT]::MoveTo($profilesX, $profilesY + 2))
        $sb.Append("┌")
        $sb.Append("─" * ($profilesWidth - 2))
        $sb.Append("┐")
        
        # Show profiles
        for ($i = 0; $i -lt [Math]::Min($this.Options.Count, 8); $i++) {
            $itemY = $profilesY + 3 + $i
            $sb.Append([VT]::MoveTo($profilesX, $itemY))
            $sb.Append("│")
            
            if ($i -eq $this.SelectedIndex) {
                $sb.Append([VT]::RGBBG(0, 100, 200))
                $sb.Append([VT]::White())
                $sb.Append("▸ ")
            } else {
                $sb.Append([VT]::Reset())
                $sb.Append("  ")
            }
            
            $optionText = $this.Options[$i]
            if ($optionText.Length -gt ($profilesWidth - 5)) {
                $optionText = $optionText.Substring(0, $profilesWidth - 8) + "..."
            }
            $sb.Append($optionText)
            
            # Pad to box width
            $padding = $profilesWidth - 3 - $optionText.Length
            if ($padding -gt 0) {
                $sb.Append(" " * $padding)
            }
            
            $sb.Append([VT]::Reset())
            $sb.Append("│")
        }
        
        # Fill remaining lines
        for ($i = $this.Options.Count; $i -lt 8; $i++) {
            $itemY = $profilesY + 3 + $i
            $sb.Append([VT]::MoveTo($profilesX, $itemY))
            $sb.Append("│")
            $sb.Append(" " * ($profilesWidth - 2))
            $sb.Append("│")
        }
        
        $sb.Append([VT]::MoveTo($profilesX, $profilesY + 11))
        $sb.Append("└")
        $sb.Append("─" * ($profilesWidth - 2))
        $sb.Append("┘")
        
        # Output settings on the right
        $settingsX = $profilesX + $profilesWidth + 5
        $settingsY = $profilesY
        
        $sb.Append([VT]::MoveTo($settingsX, $settingsY))
        $sb.Append([VT]::White())
        $sb.Append("Export Settings:")
        
        $sb.Append([VT]::MoveTo($settingsX, $settingsY + 2))
        $sb.Append([VT]::Gray())
        $sb.Append("Output Folder:")
        $sb.Append([VT]::MoveTo($settingsX, $settingsY + 3))
        $sb.Append([VT]::Cyan())
        $sb.Append($this.OutputPath)
        
        $sb.Append([VT]::MoveTo($settingsX, $settingsY + 5))
        $sb.Append([VT]::Gray())
        $sb.Append("File Name:")
        $sb.Append([VT]::MoveTo($settingsX, $settingsY + 6))
        $sb.Append([VT]::Cyan())
        $sb.Append($this.FileName)
        
        # Profile details (if selected)
        if ($this.SelectedProfile -and $this._profiles.ContainsKey($this.SelectedProfile)) {
            $profile = $this._profiles[$this.SelectedProfile]
            $detailsY = $settingsY + 8
            
            $sb.Append([VT]::MoveTo($settingsX, $detailsY))
            $sb.Append([VT]::Green())
            $sb.Append("Selected Profile Details:")
            
            $sb.Append([VT]::MoveTo($settingsX, $detailsY + 1))
            $sb.Append([VT]::Reset())
            $sb.Append("Format: $($profile.ExportFormat)")
            
            $sb.Append([VT]::MoveTo($settingsX, $detailsY + 2))
            $sb.Append("Fields: $($profile.SelectedFields.Count)")
            
            if ($profile.Description) {
                $sb.Append([VT]::MoveTo($settingsX, $detailsY + 3))
                $sb.Append("Description: $($profile.Description)")
            }
            
            if ($profile.UseCount -gt 0) {
                $sb.Append([VT]::MoveTo($settingsX, $detailsY + 4))
                $sb.Append("Last used: $($profile.LastUsed)")
            }
        }
        
        return $sb.ToString()
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        # Handle F3 for file browser
        if ($key.Key -eq [System.ConsoleKey]::F3) {
            # Simple folder browser - just ask for path
            Write-Host -NoNewline ([VT]::MoveTo($this.X + 3, $this.Y + $this.Height - 2))
            Write-Host -NoNewline ([VT]::Yellow())
            Write-Host -NoNewline "Enter output folder path: "
            Write-Host -NoNewline ([VT]::Reset())
            $newPath = Read-Host
            if ($newPath -and (Test-Path $newPath -PathType Container)) {
                $this.OutputPath = $newPath
            }
            return $true
        }
        
        # Handle arrow keys and selection
        if ($key.Key -eq [System.ConsoleKey]::UpArrow -or $key.Key -eq [System.ConsoleKey]::DownArrow) {
            $result = ([SimpleDialog]$this).HandleInput($key)
            $this.UpdateProfileSelection()
            return $result
        }
        
        # Handle other keys
        return ([SimpleDialog]$this).HandleInput($key)
    }
    
    [void] ExportWithSelectedProfile() {
        try {
            # Debug info
            [Logger]::Debug("ExportWithSelectedProfile called")
            [Logger]::Debug("Selected Profile: '$($this.SelectedProfile)'")
            [Logger]::Debug("Selected Index: $($this.SelectedIndex)")
            [Logger]::Debug("Profile Names Count: $($this._profileNames.Count)")
            
            if (-not $this.SelectedProfile) {
                $this.ShowMessage("Please select a profile first")
                return
            }
        
        if ([string]::IsNullOrWhiteSpace($this.OutputPath)) {
            $this.ShowMessage("Please specify an output folder")
            return
        }
        
        if ([string]::IsNullOrWhiteSpace($this.FileName)) {
            $this.ShowMessage("Please specify a file name")
            return
        }
        
        # Validate output directory
        if (-not (Test-Path $this.OutputPath -PathType Container)) {
            $this.ShowMessage("Output folder does not exist: $($this.OutputPath)")
            return
        }
        
        # Build full output path
        $finalFileName = $this.FileName
        if (-not $finalFileName.Contains('.')) {
            $profile = $this._profiles[$this.SelectedProfile]
            $extension = switch ($profile.ExportFormat.ToLower()) {
                'csv' { '.csv' }
                'tsv' { '.tsv' }
                'json' { '.json' }
                'xml' { '.xml' }
                'txt' { '.txt' }
                default { '.txt' }
            }
            $finalFileName += $extension
        }
        
            $this.SelectedOutputPath = Join-Path $this.OutputPath $finalFileName
            $this.SelectedFileName = $finalFileName
            $this.DialogResult = $true
            
        } catch {
            Write-Host "Export error: $($_.Exception.Message)" -ForegroundColor Red
            $this.ShowMessage("Export failed: $($_.Exception.Message)")
        }
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
    
    [void] ShowMessage([string]$message) {
        Write-Host -NoNewline ([VT]::MoveTo($this.X + 3, $this.Y + $this.Height - 2))
        Write-Host -NoNewline ([VT]::Yellow())
        Write-Host -NoNewline $message
        Write-Host -NoNewline ([VT]::Reset())
        Start-Sleep -Milliseconds 1500
    }
}