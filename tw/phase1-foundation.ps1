
# Phase 1: Data Foundation
# Defines the data structures and functions for interacting with Taskwarrior.

# 1. The Task Class
# This class represents a single task, with properties matching the JSON
# output from `task export`.

class Task {
    # Core Properties
    [int]$id
    [string]$uuid
    [string]$description
    [string]$status
    [string]$project
    [datetime]$entry
    [datetime]$modified

    # Optional / Can be Null
    [datetime]$due
    [datetime]$wait
    [datetime]$scheduled
    [datetime]$end # Completion date
    [datetime]$until # Recurring task property

    # Collections
    [string[]]$tags
    [object[]]$annotations

    # Calculated & Other
    [string]$priority
    [decimal]$urgency # Urgency can be a decimal value
    [hashtable]$udas

    # Constructor to handle potential nulls and UDAs
    Task([psobject]$JsonTask) {
        # Directly map properties that exist
        $this.id = $JsonTask.id
        $this.uuid = $JsonTask.uuid
        $this.description = $JsonTask.description
        $this.status = $JsonTask.status
        $this.project = $JsonTask.project
        $this.entry = $JsonTask.entry
        $this.modified = $JsonTask.modified
        $this.due = $JsonTask.due
        $this.wait = $JsonTask.wait
        $this.scheduled = $JsonTask.scheduled
        $this.end = $JsonTask.end
        $this.until = $JsonTask.until
        $this.tags = $JsonTask.tags
        $this.annotations = $JsonTask.annotations
        $this.priority = $JsonTask.priority
        $this.urgency = $JsonTask.urgency

        # Initialize the UDAs hashtable
        $this.udas = @{}

        # Find and add UDAs
        $standardProperties = @('id', 'uuid', 'description', 'status', 'project', 'entry', 'modified', 'due', 'wait', 'scheduled', 'end', 'until', 'tags', 'annotations', 'priority', 'urgency')
        foreach ($property in $JsonTask.PSObject.Properties) {
            if ($standardProperties -notcontains $property.Name) {
                $this.udas[$property.Name] = $property.Value
            }
        }
    }
}

# 2. Get-Tasks Function
# This function queries the taskwarrior CLI, gets the JSON output,
# and converts it into an array of [Task] objects.

function Get-Tasks {
    param (
        [string]$Filter
    )

    try {
        Write-Verbose "Fetching tasks with filter: '$Filter'"
        $command = "task rc.json.array=on export $Filter"
        $jsonOutput = Invoke-Expression $command
        
        # If there's no output, return an empty array
        if ([string]::IsNullOrWhiteSpace($jsonOutput)) {
            return @()
        }

        $jsonObjects = $jsonOutput | ConvertFrom-Json
        
        $tasks = @()
        foreach ($obj in $jsonObjects) {
            $tasks += [Task]::new($obj)
        }
        
        return $tasks
    }
    catch {
        Write-Error "Failed to get or parse tasks. Make sure 'task' is in your PATH and that your filter is valid."
        Write-Error $_.Exception.Message
        return @() # Return an empty array on failure
    }
}

# 3. Example Usage
# This demonstrates how to use the function and access the task properties.

Write-Host "Fetching all pending tasks..."
$pendingTasks = Get-Tasks -Filter "status:pending"

if ($pendingTasks.Count -gt 0) {
    Write-Host "Found $($pendingTasks.Count) pending tasks:"
    foreach ($task in $pendingTasks) {
        Write-Host ("- [{0}] {1} (Project: {2})" -f $task.id, $task.description, $task.project)
    }
}
else {
    Write-Host "No pending tasks found."
}

