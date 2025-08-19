# DataPoolAdapter.ps1 - Adapter to make ExcelDataFlow use the common data pool

class DataPoolAdapter {
    [string]$AppName = "ExcelDataFlow"
    [bool]$UseDataPool = $false
    
    DataPoolAdapter() {
        # Check if DataPool is available
        $dataPoolPath = Join-Path $PSScriptRoot "../../PraxisCore/Services/DataPool.ps1"
        if (Test-Path $dataPoolPath) {
            . $dataPoolPath
            [DataPool]::Initialize()
            $this.UseDataPool = $true
        }
    }
    
    # Load Excel mappings from either local file or data pool
    [object] LoadMappings() {
        if ($this.UseDataPool) {
            # Try data pool first
            $mappings = [DataPool]::Read($this.AppName, "excel")
            if ($mappings) {
                return $mappings
            }
        }
        
        # Fall back to local config
        return $null
    }
    
    # Save Excel mappings to both local and data pool
    [void] SaveMappings([object]$mappings) {
        # Save to data pool if available
        if ($this.UseDataPool) {
            [DataPool]::Write($this.AppName, "excel", $mappings)
        }
    }
    
    # Check for incoming export requests from other apps
    [object[]] CheckExchanges() {
        if ($this.UseDataPool) {
            return [DataPool]::GetPendingExchanges($this.AppName)
        }
        return @()
    }
    
    # Process export request from other apps
    [hashtable] ProcessExportRequest([object]$exchange) {
        if ($exchange.Type -eq "export-request") {
            return @{
                Data = $exchange.Data.Data
                Template = $exchange.Data.Template
                Format = $exchange.Data.Format
                FromApp = $exchange.From
                Metadata = $exchange.Data
            }
        }
        return $null
    }
    
    # Send processed Excel file back to requesting app
    [void] SendExportResult([string]$toApp, [string]$filePath, [hashtable]$metadata = @{}) {
        if ($this.UseDataPool) {
            [DataPool]::Exchange($this.AppName, $toApp, "export-result", @{
                FilePath = $filePath
                Format = $metadata.Format
                RowCount = $metadata.RowCount
                Timestamp = Get-Date -Format "o"
            })
        }
    }
    
    # Import data and send to other apps
    [void] SendImportedData([string]$toApp, [object[]]$data, [string]$dataType) {
        if ($this.UseDataPool) {
            [DataPool]::Exchange($this.AppName, $toApp, "import-data", @{
                $dataType = $data
                ImportDate = Get-Date -Format "o"
                RowCount = $data.Count
            })
        }
    }
    
    # Add export/import operation to recent items
    [void] AddToRecent([string]$operation, [string]$description, [string]$id = "") {
        if ($this.UseDataPool) {
            if (-not $id) { $id = [Guid]::NewGuid().ToString() }
            [DataPool]::AddRecentItem($this.AppName, $operation, $description, $id)
        }
    }
    
    # Get templates based on requesting app
    [hashtable] GetTemplateForApp([string]$appName, [string]$templateName) {
        $templates = @{
            "TaskPro" = @{
                "TaskList" = @{
                    Columns = @("Title", "Project", "Priority", "DueDate", "Completed", "Notes")
                    Headers = @("Task Title", "Project", "Priority", "Due Date", "Completed", "Notes")
                    Formatting = @{
                        DueDate = "yyyy-MM-dd"
                        Completed = "Yes/No"
                    }
                }
            }
            "TimeTracker" = @{
                "WeeklyTimesheet" = @{
                    Columns = @("ProjectCode", "Description", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Total")
                    Headers = @("Project Code", "Description", "Mon", "Tue", "Wed", "Thu", "Fri", "Total Hours")
                    Formatting = @{
                        Total = "0.00"
                    }
                }
            }
            "CommandLibrary" = @{
                "CommandLibrary" = @{
                    Columns = @("Title", "CommandText", "Description", "Tags", "Group", "UseCount")
                    Headers = @("Command Name", "Command", "Description", "Tags", "Category", "Times Used")
                    Formatting = @{
                        Tags = "Comma-separated"
                    }
                }
            }
            "MacroFactory" = @{
                "MacroLibrary" = @{
                    Columns = @("Name", "Description", "ActionCount", "Created", "Modified")
                    Headers = @("Macro Name", "Description", "Actions", "Created Date", "Last Modified")
                    Formatting = @{
                        Created = "yyyy-MM-dd HH:mm"
                        Modified = "yyyy-MM-dd HH:mm"
                    }
                }
            }
        }
        
        if ($templates.ContainsKey($appName) -and $templates[$appName].ContainsKey($templateName)) {
            return $templates[$appName][$templateName]
        }
        
        # Default template
        return @{
            Columns = @()
            Headers = @()
            Formatting = @{}
        }
    }
}