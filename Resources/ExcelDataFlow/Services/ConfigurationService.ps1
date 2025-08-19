# ConfigurationService.ps1 - Simple configuration management for ExcelDataFlow

class ConfigurationService {
    hidden [string]$_configPath
    hidden [hashtable]$_settings = @{}
    
    ConfigurationService([string]$configPath) {
        $this._configPath = $configPath
        
        # Ensure config directory exists
        $configDir = Split-Path $configPath -Parent
        if (-not (Test-Path $configDir)) {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        }
        
        $this.LoadSettings()
    }
    
    [void] LoadSettings() {
        if (Test-Path $this._configPath) {
            try {
                $json = Get-Content $this._configPath -Raw
                $this._settings = $json | ConvertFrom-Json -AsHashtable
            }
            catch {
                Write-Warning "Failed to load configuration: $_"
                $this._settings = @{}
            }
        }
        else {
            $this._settings = @{}
        }
    }
    
    [void] SaveSettings() {
        try {
            $this._settings | ConvertTo-Json -Depth 10 | Set-Content $this._configPath
        }
        catch {
            Write-Warning "Failed to save configuration: $_"
        }
    }
    
    [object] GetSetting([string]$key, [object]$defaultValue = $null) {
        if ($this._settings.ContainsKey($key)) {
            return $this._settings[$key]
        }
        return $defaultValue
    }
    
    [void] SetSetting([string]$key, [object]$value) {
        $this._settings[$key] = $value
        $this.SaveSettings()
    }
    
    [hashtable] GetAllSettings() {
        return $this._settings.Clone()
    }
    
    # Get Excel configuration mappings
    [object] GetExcelMappings() {
        return $this.GetSetting('ExcelMappings', $null)
    }
    
    # Set Excel configuration mappings
    [void] SetExcelMappings([hashtable]$mappings) {
        $this.SetSetting('ExcelMappings', $mappings)
    }
}