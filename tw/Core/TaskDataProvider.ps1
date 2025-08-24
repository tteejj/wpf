# TaskWarrior Data Provider Implementation
# Handles integration with TaskWarrior command line tool

class TaskWarriorDataProvider {
    hidden [hashtable] $_config
    hidden [string] $_taskCommand
    hidden [int] $_timeoutSeconds
    hidden [string] $_dataLocation
    
    TaskWarriorDataProvider([hashtable]$config) {
        $this._config = $config
        $this._taskCommand = if ($config.taskwarrior.task_command) { $config.taskwarrior.task_command } else { "task" }
        $this._timeoutSeconds = if ($config.taskwarrior.timeout_seconds) { $config.taskwarrior.timeout_seconds } else { 30 }
        $this._dataLocation = if ($config.taskwarrior.data_location) { $config.taskwarrior.data_location } else { "$env:HOME/.task" }
    }
    
    [array] GetTasks() {
        return $this.GetTasks("")
    }
    
    [array] GetTasks([string]$filter) {
        $command = if ($filter) {
            "$($this._taskCommand) $filter export"
        } else {
            "$($this._taskCommand) export"
        }
        
        $result = $this.ExecuteTaskWarriorCommand($command)
        
        if ($result.Success) {
            return $this.ParseTaskWarriorJson($result.Output)
        } else {
            throw "Failed to load tasks: $($result.Error)"
        }
    }
    
    [hashtable] SaveTask([hashtable]$task) {
        try {
            if ($task.ContainsKey('id') -and $task.id) {
                # Update existing task
                return $this.UpdateTask($task)
            } else {
                # Create new task
                return $this.CreateTask($task)
            }
        } catch {
            return @{
                Success = $false
                Error = $_.Exception.Message
            }
        }
    }
    
    hidden [hashtable] CreateTask([hashtable]$task) {
        $description = $task.description
        if ([string]::IsNullOrWhiteSpace($description)) {
            throw "Task description is required"
        }
        
        # Build command arguments
        $args = @("add", "`"$description`"")
        
        if ($task.ContainsKey('project') -and $task.project) {
            $args += "project:$($task.project)"
        }
        
        if ($task.ContainsKey('priority') -and $task.priority) {
            $args += "priority:$($task.priority)"
        }
        
        if ($task.ContainsKey('due') -and $task.due) {
            $args += "due:`"$($task.due)`""
        }
        
        if ($task.ContainsKey('tags') -and $task.tags) {
            foreach ($tag in $task.tags) {
                $args += "+$tag"
            }
        }
        
        $command = "$($this._taskCommand) $($args -join ' ')"
        $result = $this.ExecuteTaskWarriorCommand($command)
        
        return @{
            Success = $result.Success
            Output = $result.Output
            Error = $result.Error
        }
    }
    
    hidden [hashtable] UpdateTask([hashtable]$task) {
        $taskId = $task.id
        $args = @($taskId, "modify")
        
        if ($task.ContainsKey('description')) {
            $args += "`"$($task.description)`""
        }
        
        if ($task.ContainsKey('project')) {
            $args += "project:$($task.project)"
        }
        
        if ($task.ContainsKey('priority')) {
            $args += "priority:$($task.priority)"
        }
        
        if ($task.ContainsKey('status') -and $task.status -eq 'completed') {
            $args = @($taskId, "done")
        }
        
        $command = "$($this._taskCommand) $($args -join ' ')"
        $result = $this.ExecuteTaskWarriorCommand($command)
        
        return @{
            Success = $result.Success
            Output = $result.Output
            Error = $result.Error
        }
    }
    
    [hashtable] ExecuteTaskWarriorCommand([string]$command) {
        $startTime = Get-Date
        try {            
            # Simple execution for testing - in production would use proper process management
            $result = Invoke-Expression $command 2>&1
            $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
            
            return @{
                Success = $exitCode -eq 0
                Output = if ($result) { ($result | Out-String).Trim() } else { "" }
                Error = if ($exitCode -ne 0) { "Command failed with exit code $exitCode" } else { "" }
                ExitCode = $exitCode
                Duration = (Get-Date) - $startTime
            }
            
        } catch {
            return @{
                Success = $false
                Output = ""
                Error = $_.Exception.Message
                ExitCode = -1
                Duration = (Get-Date) - $startTime
            }
        }
    }
    
    [array] ParseTaskWarriorJson([string]$jsonOutput) {
        if ([string]::IsNullOrWhiteSpace($jsonOutput)) {
            return @()
        }
        
        try {
            $tasks = $jsonOutput | ConvertFrom-Json
            if ($null -eq $tasks) {
                return @()
            }
            
            # Convert to hashtables for easier manipulation
            $result = @()
            foreach ($task in $tasks) {
                $taskHash = @{}
                
                # Copy all properties from the task object
                $task.PSObject.Properties | ForEach-Object {
                    $taskHash[$_.Name] = $_.Value
                }
                
                # Ensure required fields have default values
                if (-not $taskHash.ContainsKey('urgency')) {
                    $taskHash.urgency = 0.0
                }
                
                if (-not $taskHash.ContainsKey('tags')) {
                    $taskHash.tags = @()
                }
                
                $result += $taskHash
            }
            
            return $result
        } catch {
            throw "Failed to parse TaskWarrior JSON output: $($_.Exception.Message)"
        }
    }
    
    [hashtable] ValidateTask([hashtable]$task) {
        $errors = @()
        
        # Check required fields
        if (-not $task.ContainsKey('description') -or [string]::IsNullOrWhiteSpace($task.description)) {
            $errors += "Task description is required"
        }
        
        if ($task.ContainsKey('uuid') -and -not [string]::IsNullOrWhiteSpace($task.uuid)) {
            if ($task.uuid -notmatch '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') {
                $errors += "Invalid UUID format"
            }
        }
        
        # Validate status
        if ($task.ContainsKey('status')) {
            $validStatuses = @('pending', 'completed', 'deleted', 'waiting')
            if ($task.status -notin $validStatuses) {
                $errors += "Invalid status: $($task.status). Must be one of: $($validStatuses -join ', ')"
            }
        }
        
        # Validate priority
        if ($task.ContainsKey('priority')) {
            $validPriorities = @('H', 'M', 'L')
            if ($task.priority -notin $validPriorities) {
                $errors += "Invalid priority: $($task.priority). Must be one of: $($validPriorities -join ', ')"
            }
        }
        
        return @{
            IsValid = $errors.Count -eq 0
            Errors = $errors
        }
    }
}

# Mock provider for testing
class MockTaskWarriorDataProvider : TaskWarriorDataProvider {
    hidden [array] $_mockTasks
    
    MockTaskWarriorDataProvider([array]$mockTasks) : base(@{}) {
        $this._mockTasks = $mockTasks
    }
    
    [array] GetTasks() {
        return $this.GetTasks("")
    }
    
    [array] GetTasks([string]$filter) {
        $tasks = $this._mockTasks.Clone()
        
        if ($filter) {
            # Simple filter implementation for testing
            if ($filter -eq "status:pending") {
                $tasks = $tasks | Where-Object { $_.status -eq 'pending' }
            } elseif ($filter -eq "status:completed") {
                $tasks = $tasks | Where-Object { $_.status -eq 'completed' }
            }
        }
        
        return $tasks
    }
    
    [hashtable] ExecuteTaskWarriorCommand([string]$command) {
        # Mock successful execution
        return @{
            Success = $true
            Output = "Mocked command execution"
            Error = ""
            ExitCode = 0
            Duration = [timespan]::FromMilliseconds(10)
        }
    }
}