# Configuration Management Implementation
# Implements configuration loading, validation, and file watching

# Configuration schema definition (from the spec)
class ConfigurationSchema {
    hidden [hashtable] $_schema = @{}
    hidden [hashtable] $_validators = @{}
    hidden [hashtable] $_defaults = @{}
    
    [void] DefineSection([string]$sectionName, [hashtable]$sectionSchema) {
        $this._schema[$sectionName] = $sectionSchema
        
        # Extract defaults and validators
        foreach ($key in $sectionSchema.GetEnumerator()) {
            $fullKey = "$sectionName.$($key.Key)"
            
            if ($key.Value.ContainsKey('default')) {
                $this._defaults[$fullKey] = $key.Value.default
            }
            
            if ($key.Value.ContainsKey('validator')) {
                $this._validators[$fullKey] = $key.Value.validator
            }
        }
    }
    
    [hashtable] ValidateConfiguration([hashtable]$config) {
        $errors = @()
        $warnings = @()
        
        foreach ($section in $this._schema.GetEnumerator()) {
            $sectionName = $section.Key
            $sectionSchema = $section.Value
            $sectionConfig = $config[$sectionName]
            
            if (-not $sectionConfig -and $this.IsSectionRequired($sectionSchema)) {
                $errors += "Required section '$sectionName' is missing"
                continue
            }
            
            if ($sectionConfig) {
                $result = $this.ValidateSection($sectionName, $sectionConfig, $sectionSchema)
                $errors += $result.Errors
                $warnings += $result.Warnings
            }
        }
        
        return @{
            IsValid = $errors.Count -eq 0
            Errors = $errors
            Warnings = $warnings
        }
    }
    
    [hashtable] ValidateSection([string]$sectionName, [hashtable]$sectionConfig, [hashtable]$sectionSchema) {
        $errors = @()
        $warnings = @()
        
        foreach ($field in $sectionSchema.GetEnumerator()) {
            $fieldName = $field.Key
            $fieldSchema = $field.Value
            $fieldValue = $sectionConfig[$fieldName]
            $fullFieldName = "$sectionName.$fieldName"
            
            # Check required fields
            if ($fieldSchema.ContainsKey('required') -and $fieldSchema.required -and $null -eq $fieldValue) {
                $errors += "Required field '$fullFieldName' is missing"
                continue
            }
        }
        
        return @{
            Errors = $errors
            Warnings = $warnings
        }
    }
    
    [bool] IsSectionRequired([hashtable]$sectionSchema) {
        foreach ($field in $sectionSchema.Values) {
            if ($field.ContainsKey('required') -and $field.required) {
                return $true
            }
        }
        return $false
    }
    
    [hashtable] GetDefaults() {
        return $this._defaults
    }
}

class TaskWarriorConfigProvider {
    hidden [string] $_configPath
    hidden [hashtable] $_config = @{}
    hidden [ConfigurationSchema] $_schema
    hidden [System.IO.FileSystemWatcher] $_fileWatcher
    hidden [object] $_eventPublisher  # IEventPublisher
    hidden [datetime] $_lastLoad
    
    TaskWarriorConfigProvider([string]$configPath, [object]$eventPublisher) {
        $this._configPath = $configPath
        $this._eventPublisher = $eventPublisher
        $this._schema = $this.CreateSchema()
        $this.LoadConfiguration()
        
        if ($eventPublisher) {
            $this.SetupFileWatcher()
        }
    }
    
    [ConfigurationSchema] CreateSchema() {
        $schema = [ConfigurationSchema]::new()
        
        # Core application settings
        $schema.DefineSection('app', @{
            'refresh_rate' = @{ type = 'int'; min = 1; max = 60; default = 2; required = $true }
            'max_tasks_display' = @{ type = 'int'; min = 10; max = 10000; default = 1000 }
            'auto_save' = @{ type = 'bool'; default = $true }
            'confirm_quit' = @{ type = 'bool'; default = $false }
            'startup_report' = @{ type = 'string'; values = @('next', 'ready', 'waiting', 'all'); default = 'next' }
        })
        
        # Theme configuration
        $schema.DefineSection('theme', @{
            'name' = @{ type = 'string'; default = 'default'; required = $true }
            'background' = @{ type = 'color'; default = 'black' }
            'foreground' = @{ type = 'color'; default = 'white' }
            'accent' = @{ type = 'color'; default = 'blue' }
            'warning' = @{ type = 'color'; default = 'yellow' }
            'error' = @{ type = 'color'; default = 'red' }
            'success' = @{ type = 'color'; default = 'green' }
            'border' = @{ type = 'color'; default = 'gray' }
            'selection' = @{ type = 'color'; default = 'bright_blue' }
        })
        
        return $schema
    }
    
    [void] LoadConfiguration() {
        try {
            if (Test-Path $this._configPath) {
                $configContent = Get-Content $this._configPath -Raw
                $this._config = $configContent | ConvertFrom-Json -AsHashtable
            } else {
                $this._config = @{}
            }
            
            # Apply defaults
            $defaults = $this._schema.GetDefaults()
            foreach ($default in $defaults.GetEnumerator()) {
                $keyParts = $default.Key -split '\.'
                $section = $keyParts[0]
                $key = $keyParts[1]
                
                if (-not $this._config.ContainsKey($section)) {
                    $this._config[$section] = @{}
                }
                
                if (-not $this._config[$section].ContainsKey($key)) {
                    $this._config[$section][$key] = $default.Value
                }
            }
            
            $this._lastLoad = Get-Date
            
            # Publish configuration loaded event
            if ($this._eventPublisher) {
                $this._eventPublisher.Publish('ConfigurationLoaded', @{
                    Path = $this._configPath
                    Timestamp = $this._lastLoad
                })
            }
            
        } catch {
            Write-Warning "Failed to load configuration from $($this._configPath): $($_.Exception.Message)"
            # Fall back to defaults only
            $this._config = @{}
            $defaults = $this._schema.GetDefaults()
            foreach ($default in $defaults.GetEnumerator()) {
                $keyParts = $default.Key -split '\.'
                $section = $keyParts[0]
                $key = $keyParts[1]
                
                if (-not $this._config.ContainsKey($section)) {
                    $this._config[$section] = @{}
                }
                $this._config[$section][$key] = $default.Value
            }
        }
    }
    
    [void] SetupFileWatcher() {
        if ($this._fileWatcher) {
            $this._fileWatcher.Dispose()
        }
        
        $configDir = Split-Path $this._configPath -Parent
        $configFile = Split-Path $this._configPath -Leaf
        
        if (Test-Path $configDir) {
            $this._fileWatcher = [System.IO.FileSystemWatcher]::new($configDir, $configFile)
            $this._fileWatcher.NotifyFilter = [System.IO.NotifyFilters]::LastWrite
            $this._fileWatcher.EnableRaisingEvents = $true
            
            # Store reference to parent for event handler
            $parentRef = $this
            
            Register-ObjectEvent -InputObject $this._fileWatcher -EventName Changed -Action {
                param($sender, $e)
                
                # Debounce file changes
                Start-Sleep -Milliseconds 100
                
                try {
                    # Access parent through closure
                    $parentRef.LoadConfiguration()
                    
                    if ($parentRef._eventPublisher) {
                        $parentRef._eventPublisher.Publish('ConfigurationChanged', @{
                            Path = $e.FullPath
                            ChangeType = $e.ChangeType
                            Timestamp = Get-Date
                        })
                    }
                } catch {
                    Write-Warning "Failed to reload configuration after file change: $_"
                }
            }.GetNewClosure()
        }
    }
    
    [object] GetValue([string]$key) {
        return $this.GetValue($key, $null)
    }
    
    [object] GetValue([string]$key, [object]$defaultValue) {
        $keyParts = $key -split '\.'
        if ($keyParts.Count -ne 2) {
            throw "Configuration key must be in format 'section.key'"
        }
        
        $section = $keyParts[0]
        $property = $keyParts[1]
        
        if ($this._config.ContainsKey($section) -and $this._config[$section].ContainsKey($property)) {
            return $this._config[$section][$property]
        }
        
        return $defaultValue
    }
    
    [void] SetValue([string]$key, [object]$value) {
        $keyParts = $key -split '\.'
        if ($keyParts.Count -ne 2) {
            throw "Configuration key must be in format 'section.key'"
        }
        
        $section = $keyParts[0]
        $property = $keyParts[1]
        
        if (-not $this._config.ContainsKey($section)) {
            $this._config[$section] = @{}
        }
        
        $this._config[$section][$property] = $value
    }
    
    [hashtable] GetSection([string]$sectionName) {
        if ($this._config.ContainsKey($sectionName)) {
            return $this._config[$sectionName]
        }
        return @{}
    }
    
    [hashtable] ValidateConfiguration() {
        return $this._schema.ValidateConfiguration($this._config)
    }
    
    [void] Dispose() {
        if ($this._fileWatcher) {
            $this._fileWatcher.Dispose()
            $this._fileWatcher = $null
        }
    }
}