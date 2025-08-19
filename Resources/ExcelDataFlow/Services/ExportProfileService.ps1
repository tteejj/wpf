# ExportProfileService.ps1 - Manage text export profiles for quick reuse

class ExportProfileService {
    [ConfigurationService]$ConfigService
    hidden [string]$_profilesKey = "ExportProfiles"
    
    ExportProfileService([ConfigurationService]$configService) {
        $this.ConfigService = $configService
    }
    
    # Save a new export profile
    [hashtable] SaveProfile([string]$profileName, [string[]]$selectedFields, [string]$format, [string]$description = "") {
        $result = @{
            Success = $false
            Message = ""
            ProfileName = $profileName
        }
        
        try {
            if ([string]::IsNullOrWhiteSpace($profileName)) {
                $result.Message = "Profile name cannot be empty"
                return $result
            }
            
            # Get existing profiles
            $profiles = $this.GetAllProfiles()
            
            # Create new profile
            $profile = @{
                Name = $profileName
                Description = $description
                SelectedFields = $selectedFields
                ExportFormat = $format
                CreatedDate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                LastUsed = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                UseCount = 0
            }
            
            # Add or update profile
            $profiles[$profileName] = $profile
            
            # Save back to configuration
            $this.ConfigService.SetSetting($this._profilesKey, $profiles)
            
            $result.Success = $true
            $result.Message = "Profile '$profileName' saved successfully"
            
        } catch {
            $result.Message = "Failed to save profile: $_"
        }
        
        return $result
    }
    
    # Load an export profile
    [hashtable] LoadProfile([string]$profileName) {
        $result = @{
            Success = $false
            Message = ""
            Profile = $null
        }
        
        try {
            $profiles = $this.GetAllProfiles()
            
            if ($profiles.ContainsKey($profileName)) {
                $profile = $profiles[$profileName]
                
                # Update usage statistics
                $profile.LastUsed = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                $profile.UseCount = $profile.UseCount + 1
                
                # Save updated stats
                $profiles[$profileName] = $profile
                $this.ConfigService.SetSetting($this._profilesKey, $profiles)
                
                $result.Success = $true
                $result.Profile = $profile
                $result.Message = "Profile '$profileName' loaded successfully"
            } else {
                $result.Message = "Profile '$profileName' not found"
            }
            
        } catch {
            $result.Message = "Failed to load profile: $_"
        }
        
        return $result
    }
    
    # Get all saved profiles
    [hashtable] GetAllProfiles() {
        try {
            $profiles = $this.ConfigService.GetSetting($this._profilesKey, @{})
            return $profiles
        } catch {
            return @{}
        }
    }
    
    # Get profile names sorted by usage
    [string[]] GetProfileNames([bool]$sortByUsage = $true) {
        $profiles = $this.GetAllProfiles()
        
        if ($sortByUsage) {
            # Sort by usage count (descending), then by last used (descending)
            $sortedProfiles = $profiles.GetEnumerator() | Sort-Object {
                -$_.Value.UseCount
            }, {
                -[datetime]$_.Value.LastUsed
            }
            return [string[]]($sortedProfiles | ForEach-Object { $_.Key })
        } else {
            # Alphabetical sort
            return [string[]]($profiles.Keys | Sort-Object)
        }
    }
    
    # Delete a profile
    [hashtable] DeleteProfile([string]$profileName) {
        $result = @{
            Success = $false
            Message = ""
        }
        
        try {
            $profiles = $this.GetAllProfiles()
            
            if ($profiles.ContainsKey($profileName)) {
                $profiles.Remove($profileName)
                $this.ConfigService.SetSetting($this._profilesKey, $profiles)
                
                $result.Success = $true
                $result.Message = "Profile '$profileName' deleted successfully"
            } else {
                $result.Message = "Profile '$profileName' not found"
            }
            
        } catch {
            $result.Message = "Failed to delete profile: $_"
        }
        
        return $result
    }
    
    # Get profile statistics and info
    [hashtable] GetProfileInfo([string]$profileName) {
        $profiles = $this.GetAllProfiles()
        
        if ($profiles.ContainsKey($profileName)) {
            $profile = $profiles[$profileName]
            return @{
                Success = $true
                Name = $profile.Name
                Description = $profile.Description
                FieldCount = $profile.SelectedFields.Count
                Format = $profile.ExportFormat
                CreatedDate = $profile.CreatedDate
                LastUsed = $profile.LastUsed
                UseCount = $profile.UseCount
                Fields = $profile.SelectedFields
            }
        } else {
            return @{
                Success = $false
                Message = "Profile not found"
            }
        }
    }
    
    # Create some default profiles based on common use cases
    [void] CreateDefaultProfiles([string[]]$availableFields) {
        $profiles = $this.GetAllProfiles()
        
        # Only create defaults if no profiles exist
        if ($profiles.Count -eq 0) {
            Write-Host "Creating default export profiles..." -ForegroundColor Yellow
            
            # Basic Info Profile
            $basicFields = $availableFields | Where-Object { 
                $_ -in @("RequestDate", "SiteName", "TPName", "AuditorName", "AuditType") 
            }
            if ($basicFields.Count -gt 0) {
                $this.SaveProfile("Basic Info", $basicFields, "CSV", "Essential project information")
            }
            
            # Contact Details Profile
            $contactFields = $availableFields | Where-Object { 
                $_ -in @("TPName", "TPEmailAddress", "TPPhoneNumber", "CorporateContact", "CorporateContactEmail", "AttentionContact") 
            }
            if ($contactFields.Count -gt 0) {
                $this.SaveProfile("Contact Details", $contactFields, "CSV", "All contact information")
            }
            
            # Site Information Profile
            $siteFields = $availableFields | Where-Object { 
                $_ -in @("SiteName", "SiteAddress", "SiteCity", "SiteState", "SiteZip", "SiteCountry") 
            }
            if ($siteFields.Count -gt 0) {
                $this.SaveProfile("Site Information", $siteFields, "TXT", "Location and address details")
            }
            
            # Asset Details Profile
            $assetFields = $availableFields | Where-Object { 
                $_ -in @("CASNumber", "AssetName", "SerialNumber", "ModelNumber", "ManufacturerName", "InstallDate", "Capacity", "TankType", "Product") 
            }
            if ($assetFields.Count -gt 0) {
                $this.SaveProfile("Asset Details", $assetFields, "JSON", "Equipment and asset information")
            }
            
            # Compliance Profile
            $complianceFields = $availableFields | Where-Object { 
                $_ -in @("ComplianceDate", "NextInspectionDate", "CertificationNumber", "InspectorName", "InspectorLicense", "Status") 
            }
            if ($complianceFields.Count -gt 0) {
                $this.SaveProfile("Compliance Data", $complianceFields, "XML", "Regulatory and compliance information")
            }
            
            # Complete Export Profile
            $this.SaveProfile("Complete Export", $availableFields, "CSV", "All available fields")
            
            Write-Host "✅ Created default export profiles" -ForegroundColor Green
        }
    }
    
    # Import/Export profiles for sharing
    [hashtable] ExportProfilesToFile([string]$filePath) {
        $result = @{
            Success = $false
            Message = ""
        }
        
        try {
            $profiles = $this.GetAllProfiles()
            $exportData = @{
                ExportDate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                ProfileCount = $profiles.Count
                Profiles = $profiles
            }
            
            $exportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $filePath -Encoding UTF8
            
            $result.Success = $true
            $result.Message = "Exported $($profiles.Count) profiles to $filePath"
            
        } catch {
            $result.Message = "Failed to export profiles: $_"
        }
        
        return $result
    }
    
    [hashtable] ImportProfilesFromFile([string]$filePath, [bool]$overwriteExisting = $false) {
        $result = @{
            Success = $false
            Message = ""
            ImportedCount = 0
            SkippedCount = 0
        }
        
        try {
            if (-not (Test-Path $filePath)) {
                $result.Message = "File not found: $filePath"
                return $result
            }
            
            $importData = Get-Content $filePath | ConvertFrom-Json
            $existingProfiles = $this.GetAllProfiles()
            
            foreach ($profileName in $importData.Profiles.PSObject.Properties.Name) {
                $profile = $importData.Profiles.$profileName
                
                if ($existingProfiles.ContainsKey($profileName) -and -not $overwriteExisting) {
                    $result.SkippedCount++
                    continue
                }
                
                # Reset usage statistics for imported profiles
                $profile.UseCount = 0
                $profile.LastUsed = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                
                $existingProfiles[$profileName] = $profile
                $result.ImportedCount++
            }
            
            $this.ConfigService.SetSetting($this._profilesKey, $existingProfiles)
            
            $result.Success = $true
            $result.Message = "Imported $($result.ImportedCount) profiles, skipped $($result.SkippedCount) existing"
            
        } catch {
            $result.Message = "Failed to import profiles: $_"
        }
        
        return $result
    }
}