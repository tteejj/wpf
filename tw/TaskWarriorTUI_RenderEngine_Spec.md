# TaskWarrior-TUI Render Engine Specification

## Executive Summary

This specification defines a PowerShell-based TUI render engine optimized for the TaskWarrior-TUI clone requirements. The engine combines the proven performance patterns from the Praxis framework with the specific architectural needs outlined in the TaskWarrior design specification.

## Architecture Overview

### Core Design Principles

1. **Double-Buffered Rendering**: All screen content built in memory before single atomic write
2. **Component-Based Composition**: Modular format functions return composable strings
3. **Performance-First**: <50ms render times, StringBuilder pooling, string caching
4. **Mode-Driven Display**: Support for TaskList, Command, Edit, and Confirm modes
5. **Implementation-Agnostic**: Same logical interface regardless of underlying technology

## Core Components

### 1. TaskWarriorRenderEngine Class

```powershell
class TaskWarriorRenderEngine {
    # Performance optimizations from Praxis
    hidden [System.Collections.Generic.Queue[System.Text.StringBuilder]]$_builderPool
    hidden [hashtable]$_stringCache = @{}
    hidden [hashtable]$_renderStats = @{}
    
    # TaskWarrior-specific state
    hidden [hashtable]$_appState = @{}
    hidden [hashtable]$_lastScreenState = @{}
    hidden [hashtable]$_dependencyCache = @{}  # Cache for dependency lookups
    
    # Render the complete application frame
    [void] RenderFrame([hashtable]$appState)
    
    # Component-specific rendering methods
    [string] RenderTaskList([array]$tasks, [hashtable]$displayState)
    [string] RenderStatusBar([hashtable]$statusData)
    [string] RenderCommandBar([hashtable]$commandState)
    [string] RenderConfirmationPrompt([hashtable]$confirmData)
    [string] RenderDependencyIndicators([Task]$task, [array]$allTasks)
    
    # Performance utilities
    [System.Text.StringBuilder] GetPooledStringBuilder()
    [void] ReturnPooledStringBuilder([System.Text.StringBuilder]$sb)
    [void] UpdateRenderStats([string]$component, [double]$renderTimeMs)
}
```

### 2. Application State Interface

The render engine expects a standardized state object matching the TaskWarrior specification:

```powershell
$appState = @{
    # Core Data
    tasks = [Task[]]@()                    # Current task list
    visibleTasks = [Task[]]@()             # Filtered/sorted tasks
    
    # View State  
    viewMode = "TaskList"                  # TaskList|Command|Edit|Confirm
    selectedIndex = 0                      # Currently selected task
    scrollOffset = 0                       # Top visible task index
    viewportHeight = 20                    # Visible task lines
    
    # Filtering & Interaction
    currentFilter = ""                     # Active filter expression
    commandBuffer = ""                     # Command being typed
    editBuffer = ""                        # Text being edited
    editingTaskID = $null                  # Task ID being edited
    
    # UI State
    statusMessage = ""                     # Current status message
    confirmMessage = ""                    # Confirmation prompt
    needsRedraw = $true                    # Render trigger flag
    
    # Terminal State
    consoleWidth = 80                      # Current terminal width
    consoleHeight = 24                     # Current terminal height
}
```

## Rendering Pipeline

### 1. Frame Composition Process

```powershell
function Update-View {
    param([hashtable]$appState)
    
    $frameStart = Get-Date
    $sb = $renderEngine.GetPooledStringBuilder()
    
    try {
        # Hide cursor for flicker-free rendering
        $sb.Append([VT]::HideCursor())
        
        # Check if full clear needed (console size changed)
        if ($appState.needsFullRedraw) {
            $sb.Append([VT]::Clear())
            $appState.needsFullRedraw = $false
        }
        
        # Compose main content area
        $taskListContent = $renderEngine.RenderTaskList($appState.visibleTasks, @{
            selectedIndex = $appState.selectedIndex
            scrollOffset = $appState.scrollOffset  
            viewportHeight = $appState.viewportHeight
            editingTaskID = $appState.editingTaskID
            editBuffer = $appState.editBuffer
        })
        $sb.Append($taskListContent)
        
        # Compose status bar
        $statusContent = $renderEngine.RenderStatusBar(@{
            viewMode = $appState.viewMode
            currentFilter = $appState.currentFilter
            taskCount = $appState.tasks.Count
            statusMessage = $appState.statusMessage
            consoleWidth = $appState.consoleWidth
        })
        $sb.Append($statusContent)
        
        # Compose command bar (context-sensitive)
        $commandContent = $renderEngine.RenderCommandBar(@{
            viewMode = $appState.viewMode
            commandBuffer = $appState.commandBuffer
            confirmMessage = $appState.confirmMessage
            consoleWidth = $appState.consoleWidth
            consoleHeight = $appState.consoleHeight
        })
        $sb.Append($commandContent)
        
        # Show cursor and complete frame
        $sb.Append([VT]::ShowCursor())
        
        # Single atomic write to console
        $output = $sb.ToString()
        [Console]::Write($output)
        
        # Performance tracking
        $frameTime = ((Get-Date) - $frameStart).TotalMilliseconds
        $renderEngine.UpdateRenderStats("CompleteFrame", $frameTime)
        
    } finally {
        $renderEngine.ReturnPooledStringBuilder($sb)
    }
}
```

### 2. Task List Rendering

The core visual component supporting the TaskWarrior specification requirements:

```powershell
[string] RenderTaskList([array]$tasks, [hashtable]$displayState) {
    $sb = $this.GetPooledStringBuilder()
    
    try {
        $startY = 3  # After header area
        $endY = $displayState.consoleHeight - 4  # Before status/command bars
        $visibleHeight = $endY - $startY
        
        # Calculate visible task range
        $startIdx = $displayState.scrollOffset
        $endIdx = [Math]::Min($startIdx + $visibleHeight, $tasks.Count)
        
        # Render header
        $sb.Append([VT]::MoveTo(1, 1))
        $sb.Append($this.FormatTaskListHeader())
        
        # Render visible tasks
        for ($i = $startIdx; $i -lt $endIdx; $i++) {
            $task = $tasks[$i]
            $isSelected = ($i -eq $displayState.selectedIndex)
            $isEditing = ($task.id -eq $displayState.editingTaskID)
            $currentY = $startY + ($i - $startIdx)
            
            $sb.Append([VT]::MoveTo(1, $currentY))
            $sb.Append($this.FormatTaskLine($task, $isSelected, $isEditing, $displayState))
        }
        
        # Clear remaining lines in viewport
        for ($y = ($startY + $endIdx - $startIdx); $y -lt $endY; $y++) {
            $sb.Append([VT]::MoveTo(1, $y))
            $sb.Append([VT]::ClearLine())
        }
        
        return $sb.ToString()
    } finally {
        $this.ReturnPooledStringBuilder($sb)
    }
}
```

### 3. Task Line Formatting

Supports the advanced features specified in the TaskWarrior design:

```powershell
[string] FormatTaskLine([Task]$task, [bool]$isSelected, [bool]$isEditing, [hashtable]$state) {
    $sb = $this.GetPooledStringBuilder()
    
    try {
        $width = $state.consoleWidth - 2  # Account for margins
        
        if ($isEditing) {
            # In-place editing mode
            $prefix = $this.FormatTaskLinePrefix($task, $isSelected)
            $editableDescription = $state.editBuffer + "█"  # Block cursor
            $suffix = $this.FormatTaskLineSuffix($task, $width - $prefix.Length - $editableDescription.Length)
            
            $sb.Append($prefix)
            $sb.Append($this.ApplyEditingHighlight($editableDescription))
            $sb.Append($suffix)
            
        } elseif ($isSelected) {
            # Selected task with pillbox highlighting
            $content = $this.FormatTaskLineContent($task, $width - 4)  # Account for selection indicators
            $sb.Append($this.ApplySelectionHighlight("▸ $content ◂"))
            
        } else {
            # Normal task line
            $content = $this.FormatTaskLineContent($task, $width)
            $sb.Append($content)
        }
        
        # Ensure consistent width
        $currentLength = [Measure]::TextWidth($sb.ToString())
        if ($currentLength -lt $width) {
            $sb.Append([StringCache]::GetSpaces($width - $currentLength))
        }
        
        return $sb.ToString()
    } finally {
        $this.ReturnPooledStringBuilder($sb)
    }
}
```

## Mode-Specific Rendering

### 1. Command Mode Display

```powershell
[string] RenderCommandBar([hashtable]$commandState) {
    $sb = $this.GetPooledStringBuilder()
    
    try {
        $y = $commandState.consoleHeight - 1
        $sb.Append([VT]::MoveTo(1, $y))
        
        switch ($commandState.viewMode) {
            "TaskList" {
                # Show keybinding hints
                $hints = "a:add x:complete e:edit /:filter q:quit ?:help"
                $sb.Append($this.ApplyHintHighlight($hints))
            }
            
            "Command" {
                # Show live command buffer
                $prompt = "> " + $commandState.commandBuffer
                $sb.Append($this.ApplyCommandHighlight($prompt))
                # Add cursor if needed
                $sb.Append("█")
            }
            
            "Edit" {
                # Show edit mode hints
                $hints = "Enter:save Esc:cancel"
                $sb.Append($this.ApplyEditHintHighlight($hints))
            }
            
            "Confirm" {
                # Show confirmation prompt
                $prompt = $commandState.confirmMessage + " (y/n): "
                $sb.Append($this.ApplyConfirmHighlight($prompt))
            }
        }
        
        # Pad to full width
        $currentLength = [Measure]::TextWidth($sb.ToString())
        $padding = $commandState.consoleWidth - $currentLength
        if ($padding -gt 0) {
            $sb.Append([StringCache]::GetSpaces($padding))
        }
        
        return $sb.ToString()
    } finally {
        $this.ReturnPooledStringBuilder($sb)
    }
}
```

### 2. Status Bar Display

```powershell
[string] RenderStatusBar([hashtable]$statusData) {
    $sb = $this.GetPooledStringBuilder()
    
    try {
        $y = $statusData.consoleHeight - 2
        $sb.Append([VT]::MoveTo(1, $y))
        
        # Left section: Mode and filter info
        $leftContent = @()
        $leftContent += "[$($statusData.viewMode)]"
        
        if ($statusData.currentFilter) {
            $leftContent += "Filter: $($statusData.currentFilter)"
        }
        
        $leftSection = $leftContent -join " | "
        
        # Right section: Task counts and status
        $rightContent = @()
        $rightContent += "Tasks: $($statusData.taskCount)"
        
        if ($statusData.statusMessage) {
            $rightContent += $statusData.statusMessage
        }
        
        $rightSection = $rightContent -join " | "
        
        # Layout with proper spacing
        $leftWidth = [Measure]::TextWidth($leftSection)
        $rightWidth = [Measure]::TextWidth($rightSection)
        $centerPadding = $statusData.consoleWidth - $leftWidth - $rightWidth
        
        $sb.Append($this.ApplyStatusHighlight($leftSection))
        $sb.Append([StringCache]::GetSpaces($centerPadding))
        $sb.Append($this.ApplyStatusHighlight($rightSection))
        
        return $sb.ToString()
    } finally {
        $this.ReturnPooledStringBuilder($sb)
    }
}
```

## Performance Requirements

### 1. Render Performance Targets

- **Frame Render Time**: <50ms for 10,000 tasks
- **Task List Render**: <20ms for visible portion  
- **Status/Command Bar**: <5ms each
- **Memory Usage**: <100MB for 10,000 tasks
- **String Builder Pool**: 5-10 pooled builders, 4KB default capacity

### 2. Optimization Strategies

```powershell
# String caching for common patterns
static [hashtable]$_commonStrings = @{
    'spaces_2' = '  '
    'spaces_4' = '    '
    'arrow_right' = '▸'
    'arrow_left' = '◂'
    'block_cursor' = '█'
    'vt_reset' = "`e[0m"
    'vt_hide_cursor' = "`e[?25l"
    'vt_show_cursor' = "`e[?25h"
}

# Differential rendering - only redraw changed regions
[bool] RequiresRedraw([hashtable]$currentState, [hashtable]$lastState) {
    # Compare critical state elements
    return (
        $currentState.selectedIndex -ne $lastState.selectedIndex -or
        $currentState.scrollOffset -ne $lastState.scrollOffset -or
        $currentState.viewMode -ne $lastState.viewMode -or
        $currentState.commandBuffer -ne $lastState.commandBuffer -or
        $currentState.needsRedraw
    )
}

# Task content caching
[string] GetCachedTaskLine([Task]$task, [string]$format) {
    $key = "$($task.id)_$($task.modified)_$format"
    if ($this._taskLineCache.ContainsKey($key)) {
        return $this._taskLineCache[$key]
    }
    
    $rendered = $this.FormatTaskLineContent($task, $format)
    $this._taskLineCache[$key] = $rendered
    return $rendered
}
```

## Integration with TaskWarrior Application

### 1. Initialization

```powershell
# Application startup
$renderEngine = [TaskWarriorRenderEngine]::new()
$renderEngine.OptimizeConsole()  # Configure terminal for best performance

# Initialize application state
$appState = Initialize-AppState
$appState.renderEngine = $renderEngine
```

### 2. Main Loop Integration

```powershell
while ($appState.running) {
    # Process input
    $inputChanged = Process-UserInput $appState
    
    # Update view if needed
    if ($inputChanged -or $appState.needsRedraw) {
        $renderEngine.RenderFrame($appState)
        $appState.needsRedraw = $false
    }
    
    # Handle resize events
    if (Test-ConsoleResize) {
        $appState.consoleWidth = [Console]::WindowWidth
        $appState.consoleHeight = [Console]::WindowHeight
        $appState.needsFullRedraw = $true
    }
    
    Start-Sleep -Milliseconds 16  # ~60 FPS
}
```

### 3. Cleanup

```powershell
# Application shutdown
$renderEngine.RestoreConsole()  # Reset terminal state
[Logger]::Info("Render engine stats: $($renderEngine.GetRenderStats())")
```

## Theme Integration

### 1. Color Management

The render engine integrates with the theme system specified in the TaskWarrior outline:

```powershell
# Theme color application methods
[string] ApplySelectionHighlight([string]$content) {
    $bgColor = $this.GetThemeColor('task.selected.background')
    $fgColor = $this.GetThemeColor('task.selected.foreground') 
    return "$bgColor$fgColor$content$([VT]::Reset())"
}

[string] ApplyEditingHighlight([string]$content) {
    $bgColor = $this.GetThemeColor('task.editing.background')
    $fgColor = $this.GetThemeColor('task.editing.foreground')
    return "$bgColor$fgColor$content$([VT]::Reset())"
}
```

### 2. Priority-Based Coloring

```powershell
[string] GetTaskPriorityColor([Task]$task) {
    switch ($task.priority) {
        "H" { return $this.GetThemeColor('priority.high') }
        "M" { return $this.GetThemeColor('priority.medium') }
        "L" { return $this.GetThemeColor('priority.low') }
        default { return $this.GetThemeColor('priority.none') }
    }
}
```

## Testing & Validation

### 1. Performance Testing

```powershell
# Benchmark render performance
function Test-RenderPerformance {
    param([int]$taskCount = 10000)
    
    $tasks = Generate-TestTasks $taskCount
    $appState = @{
        visibleTasks = $tasks[0..50]  # Simulate viewport
        selectedIndex = 25
        scrollOffset = 0
        viewportHeight = 50
    }
    
    $renderEngine = [TaskWarriorRenderEngine]::new()
    
    # Warm up
    1..10 | ForEach-Object { $renderEngine.RenderTaskList($appState.visibleTasks, $appState) }
    
    # Measure
    $times = @()
    1..100 | ForEach-Object {
        $start = Get-Date
        $renderEngine.RenderTaskList($appState.visibleTasks, $appState)
        $times += ((Get-Date) - $start).TotalMilliseconds
    }
    
    return @{
        AverageMs = ($times | Measure-Object -Average).Average
        MaxMs = ($times | Measure-Object -Maximum).Maximum
        MinMs = ($times | Measure-Object -Minimum).Minimum
    }
}
```

### 2. Visual Testing

```powershell
# Test different view modes
function Test-ViewModeRendering {
    $testStates = @(
        @{ viewMode = "TaskList"; commandBuffer = "" }
        @{ viewMode = "Command"; commandBuffer = "/proj:home" }
        @{ viewMode = "Edit"; editingTaskID = 42; editBuffer = "Updated task description" }
        @{ viewMode = "Confirm"; confirmMessage = "Delete task?" }
    )
    
    foreach ($state in $testStates) {
        $output = $renderEngine.RenderFrame($state)
        # Validate expected content appears
        Assert-Contains $output "[$($state.viewMode)]"
    }
}
```

## Dependency System Integration

### 1. Dependency Visualization

The render engine provides visual indicators for task dependencies:

```powershell
[string] RenderDependencyIndicators([Task]$task, [array]$allTasks) {
    $sb = $this.GetPooledStringBuilder()
    
    try {
        $indicators = @()
        
        # Show if task is blocked (has unresolved dependencies)
        if ($task.HasDependencies() -and -not $task.IsReady($allTasks)) {
            $blockedCount = ($task.depends | Where-Object { 
                $dep = $allTasks | Where-Object { $_.uuid -eq $_ }
                $dep -and $dep.status -notin @('completed', 'deleted')
            }).Count
            $indicators += $this.ApplyBlockedHighlight("⧖$blockedCount")  # Hourglass + count
        }
        
        # Show if task blocks others (is a dependency)
        $blockedTasks = $task.GetBlockedTasks($allTasks)
        if ($blockedTasks.Count -gt 0) {
            $indicators += $this.ApplyBlockingHighlight("⧗$($blockedTasks.Count)")  # Inverted hourglass
        }
        
        # Show recurring indicator
        if ($task.IsRecurring()) {
            $indicators += $this.ApplyRecurringHighlight("↻")  # Refresh symbol
        }
        
        # Show recurring child indicator
        if ($task.IsRecurringChild()) {
            $indicators += $this.ApplyRecurringChildHighlight("↺")  # Reverse refresh
        }
        
        return $indicators -join " "
        
    } finally {
        $this.ReturnPooledStringBuilder($sb)
    }
}
```

### 2. Dependency-Aware Task Line Formatting

Enhanced task line rendering with dependency status:

```powershell
[string] FormatTaskLineContent([Task]$task, [int]$maxWidth, [array]$allTasks) {
    $sb = $this.GetPooledStringBuilder()
    
    try {
        # Priority indicator (2 chars)
        $priorityIndicator = switch ($task.priority) {
            "H" { $this.ApplyPriorityHighlight("‼ ") }     # Double exclamation
            "M" { $this.ApplyPriorityHighlight("! ") }      # Single exclamation  
            "L" { $this.ApplyPriorityHighlight("· ") }      # Dot
            default { "  " }                                 # Two spaces
        }
        $sb.Append($priorityIndicator)
        
        # Dependency indicators (up to 6 chars)
        $depIndicators = $this.RenderDependencyIndicators($task, $allTasks)
        if ($depIndicators.Length -gt 6) { $depIndicators = $depIndicators.Substring(0, 6) }
        $sb.Append($depIndicators.PadRight(6))
        
        # Multi-column layout system
        $columns = $this.GetActiveColumns()
        $availableWidth = $maxWidth - 8  # Reserve space for priority and dep indicators
        $columnWidths = $this.CalculateColumnWidths($columns, $availableWidth)
        
        foreach ($column in $columns) {
            $columnWidth = $columnWidths[$column.Name]
            $content = $this.FormatColumnContent($task, $column, $columnWidth)
            $sb.Append($content)
        
        return $sb.ToString()
        
    } finally {
        $this.ReturnPooledStringBuilder($sb)
    }
}
```

### 3. Dependency Command Integration

Support for dependency operations in command mode:

```powershell
# Dependency-related commands
"dep:UUID"     # Add dependency on task UUID
"-dep:UUID"    # Remove dependency on UUID  
"deps"         # Show dependency tree for current task
"ready"        # Filter to tasks ready to work on (no unresolved deps)
"blocked"      # Filter to tasks that are blocked
"blocking"     # Filter to tasks that block others
```

### 4. Dependency Graph Visualization

Optional dependency tree view:

```powershell
[string] RenderDependencyTree([Task]$rootTask, [array]$allTasks, [int]$depth = 0) {
    $sb = $this.GetPooledStringBuilder()
    
    try {
        $indent = "  " * $depth
        $treeChar = if ($depth -eq 0) { "○" } else { "├─" }
        
        # Render current task
        $status = switch ($rootTask.status) {
            "completed" { "✓" }
            "pending" { if ($rootTask.IsReady($allTasks)) { "●" } else { "◐" } }
            "waiting" { "⏸" }
            default { "?" }
        }
        
        $sb.AppendLine("$indent$treeChar $status $($rootTask.description)")
        
        # Render dependencies
        foreach ($depUuid in $rootTask.depends) {
            $depTask = $allTasks | Where-Object { $_.uuid -eq $depUuid }
            if ($depTask -and $depth -lt 5) {  # Prevent infinite recursion
                $sb.Append($this.RenderDependencyTree($depTask, $allTasks, $depth + 1))
            }
        }
        
        return $sb.ToString()
        
    } finally {
        $this.ReturnPooledStringBuilder($sb)
    }
}
```

## Recurring Task System Integration

### 1. Recurring Task Display

The render engine differentiates between recurring templates and their instances:

```powershell
[string] ApplyRecurringHighlight([string]$content) {
    # Recurring template - bright blue with rotation symbol
    $bgColor = $this.GetThemeColor('recurring.template.background')
    $fgColor = $this.GetThemeColor('recurring.template.foreground') 
    return "$bgColor$fgColor$content$([VT]::Reset())"
}

[string] ApplyRecurringChildHighlight([string]$content) {
    # Recurring instance - dimmed blue with reverse rotation
    $bgColor = $this.GetThemeColor('recurring.instance.background')
    $fgColor = $this.GetThemeColor('recurring.instance.foreground')
    return "$bgColor$fgColor$content$([VT]::Reset())"
}
```

### 2. Recurring Pattern Display

Show recurrence information in task details:

```powershell
[string] FormatRecurrenceInfo([Task]$task) {
    $sb = $this.GetPooledStringBuilder()
    
    try {
        if ($task.IsRecurringTemplate()) {
            $pattern = $this.ParseRecurrencePattern($task.recur)
            $sb.Append("Recurs: $pattern")
            
            if ($null -ne $task.until) {
                $sb.Append(" until $($task.until.ToString('yyyy-MM-dd'))")
            }
            
            # Show next occurrence date
            $nextDue = $task.CalculateNextDue()
            if ($null -ne $nextDue) {
                $sb.Append(" (next: $($nextDue.ToString('yyyy-MM-dd')))")
            }
            
        } elseif ($task.IsRecurringChild()) {
            $sb.Append("Instance of recurring task")
            
            # Try to find parent template
            if (-not [string]::IsNullOrEmpty($task.parent)) {
                $sb.Append(" ($($task.parent.Substring(0,8))...)")
            }
        }
        
        return $sb.ToString()
        
    } finally {
        $this.ReturnPooledStringBuilder($sb)
    }
}

[string] ParseRecurrencePattern([string]$pattern) {
    switch -Regex ($pattern) {
        '^daily$|^1d$' { return "Daily" }
        '^weekly$|^1w$' { return "Weekly" }
        '^monthly$|^1m$' { return "Monthly" }
        '^quarterly$|^3m$' { return "Quarterly" }
        '^yearly$|^1y$' { return "Yearly" }
        '^(\d+)d$' { return "Every $($matches[1]) days" }
        '^(\d+)w$' { return "Every $($matches[1]) weeks" }
        '^(\d+)m$' { return "Every $($matches[1]) months" }
        '^(\d+)y$' { return "Every $($matches[1]) years" }
        default { return $pattern }
    }
}
```

### 3. Recurring Task Commands

Extended command support for recurring tasks:

```powershell
# Recurring task commands
"recur:daily"      # Set task to recur daily
"recur:weekly"     # Set task to recur weekly
"recur:3d"         # Set task to recur every 3 days
"recur:"           # Remove recurrence
"until:2024-12-31" # Set recurrence end date
"template"         # Filter to recurring templates only
"instances"        # Filter to recurring instances only
```

### 4. Recurring Task Status Display

Enhanced status bar to show recurring task information:

```powershell
[string] RenderRecurringStatus([hashtable]$statusData) {
    if ($statusData.selectedTask -and $statusData.selectedTask.IsRecurring()) {
        $sb = $this.GetPooledStringBuilder()
        
        try {
            $task = $statusData.selectedTask
            
            if ($task.IsRecurringTemplate()) {
                # Show template information
                $instanceCount = $statusData.allTasks | 
                    Where-Object { $_.parent -eq $task.uuid } | 
                    Measure-Object | 
                    Select-Object -ExpandProperty Count
                
                $sb.Append("Template: $($task.recur) ($instanceCount instances)")
                
                if ($task.ShouldGenerateNext()) {
                    $sb.Append(" [Ready to generate next]")
                }
                
            } elseif ($task.IsRecurringChild()) {
                # Show instance information
                $sb.Append("Instance of recurring task")
                
                # Show sibling count
                $siblingCount = $statusData.allTasks | 
                    Where-Object { $_.parent -eq $task.parent -and $_.uuid -ne $task.uuid } |
                    Measure-Object |
                    Select-Object -ExpandProperty Count
                
                if ($siblingCount -gt 0) {
                    $sb.Append(" ($siblingCount siblings)")
                }
            }
            
            return $sb.ToString()
            
        } finally {
            $this.ReturnPooledStringBuilder($sb)
        }
    }
    
    return ""
}
```

### 5. Recurring Task Workflow Integration

Support for recurring task lifecycle in main loop:

```powershell
# In Process-UserInput function
case "CompleteTask" {
    $selectedTask = $appState.visibleTasks[$appState.selectedIndex]
    
    # Complete the task
    $result = Invoke-TaskCommand "task $($selectedTask.uuid) done"
    
    # If it's a recurring template that should generate next occurrence
    if ($selectedTask.ShouldGenerateNext()) {
        $nextTask = $selectedTask.GenerateNextOccurrence()
        if ($nextTask) {
            # Add the next occurrence
            $addResult = Generate-RecurringTask $nextTask
            if ($addResult.Success) {
                $appState.statusMessage = "Task completed. Next occurrence created."
            } else {
                $appState.statusMessage = "Task completed. Failed to create next occurrence: $($addResult.Message)"
            }
        }
    } else {
        $appState.statusMessage = "Task completed."
    }
    
    # Refresh task list
    $appState.tasks = Get-Tasks
    return $true
}
```

## Advanced Filtering System Integration

### 1. Filter Expression Parser

The render engine includes a sophisticated filter parser supporting TaskWarrior syntax:

```powershell
class FilterExpressionParser {
    hidden [hashtable]$_tokens = @{}
    hidden [int]$_position = 0
    hidden [string[]]$_validAttributes = @(
        'description', 'project', 'priority', 'status', 'due', 'scheduled', 
        'wait', 'entry', 'modified', 'start', 'end', 'tags', 'urgency'
    )
    
    # Parse complex filter expression into executable AST
    [hashtable] ParseFilter([string]$expression) {
        $this._tokens = $this.Tokenize($expression)
        $this._position = 0
        
        try {
            return $this.ParseOrExpression()
        } catch {
            throw "Invalid filter syntax: $($_.Exception.Message)"
        }
    }
    
    # Tokenize filter expression
    [hashtable[]] Tokenize([string]$expression) {
        $tokens = @()
        $regex = @(
            '(?<OPERATOR>and|or|not|\(|\))',
            '(?<ATTRIBUTE>\w+)(?<MODIFIER>\.before|\.after|\.over|\.under)?:(?<VALUE>[^\s\)]+)',
            '(?<TAG>[+-]\w+)',
            '(?<VIRTUAL_TAG>\+[A-Z]+)',
            '(?<REGEX>\w+~/[^/]+/)',
            '(?<WHITESPACE>\s+)'
        ) -join '|'
        
        [regex]::Matches($expression, $regex) | ForEach-Object {
            $match = $_
            foreach ($group in $match.Groups | Where-Object { $_.Success -and $_.Name -ne '0' }) {
                if ($group.Name -ne 'WHITESPACE') {
                    $tokens += @{
                        Type = $group.Name
                        Value = $group.Value
                        Position = $group.Index
                    }
                }
            }
        }
        
        return $tokens
    }
    
    # Parse OR expressions (lowest precedence)
    [hashtable] ParseOrExpression() {
        $left = $this.ParseAndExpression()
        
        while ($this.CurrentToken() -and $this.CurrentToken().Value -eq 'or') {
            $this.Advance()
            $right = $this.ParseAndExpression()
            $left = @{
                Type = 'OR'
                Left = $left
                Right = $right
            }
        }
        
        return $left
    }
    
    # Parse AND expressions
    [hashtable] ParseAndExpression() {
        $left = $this.ParseNotExpression()
        
        while ($this.CurrentToken() -and ($this.CurrentToken().Value -eq 'and' -or $this.IsFilterTerm($this.CurrentToken()))) {
            if ($this.CurrentToken().Value -eq 'and') {
                $this.Advance()
            }
            $right = $this.ParseNotExpression()
            $left = @{
                Type = 'AND'
                Left = $left
                Right = $right
            }
        }
        
        return $left
    }
    
    # Parse NOT expressions
    [hashtable] ParseNotExpression() {
        if ($this.CurrentToken() -and $this.CurrentToken().Value -eq 'not') {
            $this.Advance()
            return @{
                Type = 'NOT'
                Expression = $this.ParsePrimaryExpression()
            }
        }
        
        return $this.ParsePrimaryExpression()
    }
    
    # Parse primary expressions (attributes, tags, parentheses)
    [hashtable] ParsePrimaryExpression() {
        $token = $this.CurrentToken()
        
        if (-not $token) {
            throw "Unexpected end of expression"
        }
        
        switch ($token.Type) {
            'OPERATOR' {
                if ($token.Value -eq '(') {
                    $this.Advance()
                    $expr = $this.ParseOrExpression()
                    if (-not $this.CurrentToken() -or $this.CurrentToken().Value -ne ')') {
                        throw "Missing closing parenthesis"
                    }
                    $this.Advance()
                    return $expr
                }
                throw "Unexpected operator: $($token.Value)"
            }
            
            'ATTRIBUTE' {
                return $this.ParseAttributeFilter($token)
            }
            
            'TAG' {
                return $this.ParseTagFilter($token)
            }
            
            'VIRTUAL_TAG' {
                return $this.ParseVirtualTagFilter($token)
            }
            
            'REGEX' {
                return $this.ParseRegexFilter($token)
            }
            
            default {
                throw "Unexpected token: $($token.Value)"
            }
        }
    }
    
    # Additional parser methods for specific filter types...
    [hashtable] ParseAttributeFilter([hashtable]$token) {
        $this.Advance()
        # Implementation for attribute:value parsing with modifiers
        # Returns hashtable representing the filter condition
    }
}
```

### 2. Real-time Filter Validation

Visual feedback for filter expression validation:

```powershell
[string] RenderFilterValidation([string]$expression) {
    $sb = $this.GetPooledStringBuilder()
    
    try {
        $parser = [FilterExpressionParser]::new()
        
        try {
            $ast = $parser.ParseFilter($expression)
            
            # Valid expression - show green checkmark
            $sb.Append($this.ApplyValidFilterHighlight("✓ Valid filter"))
            
            # Show quick preview of what would be matched
            $matchCount = $this.EstimateFilterMatches($ast)
            $sb.Append(" (~$matchCount matches)")
            
        } catch {
            # Invalid expression - show red error with details
            $sb.Append($this.ApplyInvalidFilterHighlight("✗ $($_.Exception.Message)"))
        }
        
        return $sb.ToString()
        
    } finally {
        $this.ReturnPooledStringBuilder($sb)
    }
}
```

### 3. Filter Auto-completion

Smart suggestions based on context and existing data:

```powershell
[string[]] GetFilterSuggestions([string]$partialExpression, [int]$cursorPosition) {
    $suggestions = @()
    
    # Parse context around cursor
    $beforeCursor = $partialExpression.Substring(0, $cursorPosition)
    $afterCursor = $partialExpression.Substring($cursorPosition)
    
    # Determine what type of suggestion is appropriate
    $context = $this.AnalyzeFilterContext($beforeCursor)
    
    switch ($context.Type) {
        'ATTRIBUTE' {
            # Suggest attribute names
            $suggestions += $this._validAttributes | Where-Object { $_ -like "$($context.Partial)*" }
        }
        
        'OPERATOR' {
            # Suggest logical operators
            $suggestions += @('and', 'or', 'not') | Where-Object { $_ -like "$($context.Partial)*" }
        }
        
        'VALUE' {
            # Suggest values based on attribute type
            $suggestions += $this.GetAttributeValueSuggestions($context.Attribute, $context.Partial)
        }
        
        'DATE' {
            # Suggest date expressions
            $suggestions += @('today', 'tomorrow', 'eom', 'sow', 'now') | Where-Object { $_ -like "$($context.Partial)*" }
        }
    }
    
    return $suggestions | Select-Object -First 10
}

[string[]] GetAttributeValueSuggestions([string]$attribute, [string]$partial) {
    # Get unique values from current task list for this attribute
    switch ($attribute) {
        'project' {
            return $this._appState.tasks.project | 
                Where-Object { -not [string]::IsNullOrEmpty($_) -and $_ -like "*$partial*" } |
                Select-Object -Unique |
                Sort-Object
        }
        
        'priority' {
            return @('H', 'M', 'L') | Where-Object { $_ -like "$partial*" }
        }
        
        'status' {
            return @('pending', 'completed', 'deleted', 'waiting') | Where-Object { $_ -like "$partial*" }
        }
        
        default {
            return @()
        }
    }
}
```

### 4. Advanced Filter Display

Enhanced command bar showing filter analysis:

```powershell
[string] RenderAdvancedCommandBar([hashtable]$commandState) {
    $sb = $this.GetPooledStringBuilder()
    
    try {
        $y = $commandState.consoleHeight - 1
        $sb.Append([VT]::MoveTo(1, $y))
        
        if ($commandState.viewMode -eq 'Command' -and $commandState.commandBuffer.StartsWith('/')) {
            $filterExpression = $commandState.commandBuffer.Substring(1)
            
            # Main filter input
            $prompt = "> /$filterExpression"
            $sb.Append($this.ApplyCommandHighlight($prompt))
            
            # Add cursor
            $sb.Append("█")
            
            # Show validation status in remaining space
            $remainingWidth = $commandState.consoleWidth - [Measure]::TextWidth($prompt) - 20
            if ($remainingWidth -gt 0) {
                $validation = $this.RenderFilterValidation($filterExpression)
                if ($validation.Length -gt $remainingWidth) {
                    $validation = $validation.Substring(0, $remainingWidth - 3) + "..."
                }
                $sb.Append("  $validation")
            }
            
        } else {
            # Standard command bar for other modes
            $sb.Append($this.RenderCommandBar($commandState))
        }
        
        return $sb.ToString()
        
    } finally {
        $this.ReturnPooledStringBuilder($sb)
    }
}
```

### 5. Filter History and Presets

Support for saved filters and recent filter history:

```powershell
# Filter history management
$filterHistory = [System.Collections.Generic.List[string]]::new()
$savedFilters = @{
    'urgent' = '+urgent and -COMPLETED'
    'overdue' = '+OVERDUE'
    'today' = 'due:today'
    'this_week' = 'due.before:eow'
    'work' = 'project:work and -COMPLETED'
}

# Quick filter activation commands
'!urgent'     # Apply saved 'urgent' filter
'!work'       # Apply saved 'work' filter
'!clear'      # Clear current filter
'!save:name'  # Save current filter with name
```

## Multi-Column Display System

### 1. Column Configuration System

Flexible column layout supporting TaskWarrior's rich data model:

```powershell
class ColumnDefinition {
    [string] $Name
    [string] $Header
    [string] $Attribute       # Task property to display
    [int] $MinWidth           # Minimum column width
    [int] $MaxWidth           # Maximum column width
    [double] $Weight          # Relative weight for width calculation
    [string] $Alignment       # Left, Right, Center
    [string] $Format          # Custom format function
    [bool] $Visible           # Whether column is currently displayed
    [bool] $Sortable          # Whether column supports sorting
    
    ColumnDefinition([string]$name, [string]$attribute, [int]$minWidth, [double]$weight) {
        $this.Name = $name
        $this.Header = $name
        $this.Attribute = $attribute
        $this.MinWidth = $minWidth
        $this.MaxWidth = 999
        $this.Weight = $weight
        $this.Alignment = "Left"
        $this.Format = ""
        $this.Visible = $true
        $this.Sortable = $true
    }
}

# Default column definitions matching TaskWarrior reports
$defaultColumns = @{
    'ID' = [ColumnDefinition]::new('ID', 'id', 3, 0.05)
    'Age' = [ColumnDefinition]::new('Age', 'entry', 4, 0.08)
    'Priority' = [ColumnDefinition]::new('Pri', 'priority', 3, 0.05)
    'Project' = [ColumnDefinition]::new('Project', 'project', 8, 0.15)
    'Description' = [ColumnDefinition]::new('Description', 'description', 20, 0.40)
    'Due' = [ColumnDefinition]::new('Due', 'due', 10, 0.12)
    'Urgency' = [ColumnDefinition]::new('Urg', 'urgency', 6, 0.08)
    'Tags' = [ColumnDefinition]::new('Tags', 'tags', 8, 0.15)
    'Depends' = [ColumnDefinition]::new('Deps', 'depends', 6, 0.08)
    'Recur' = [ColumnDefinition]::new('Recur', 'recur', 6, 0.08)
    'Scheduled' = [ColumnDefinition]::new('Scheduled', 'scheduled', 10, 0.12)
    'Start' = [ColumnDefinition]::new('Start', 'start', 10, 0.12)
    'Status' = [ColumnDefinition]::new('Status', 'status', 8, 0.10)
}
```

### 2. Dynamic Column Layout Engine

Intelligent width calculation and responsive layout:

```powershell
[hashtable] CalculateColumnWidths([ColumnDefinition[]]$columns, [int]$availableWidth) {
    $widths = @{}
    
    # Phase 1: Allocate minimum widths
    $reservedWidth = ($columns | Measure-Object -Property MinWidth -Sum).Sum
    $remainingWidth = $availableWidth - $reservedWidth
    
    if ($remainingWidth -le 0) {
        # Not enough space - use minimum widths only
        foreach ($column in $columns) {
            $widths[$column.Name] = $column.MinWidth
        }
        return $widths
    }
    
    # Phase 2: Distribute remaining width by weight
    $totalWeight = ($columns | Measure-Object -Property Weight -Sum).Sum
    
    foreach ($column in $columns) {
        $baseWidth = $column.MinWidth
        $extraWidth = [int](($column.Weight / $totalWeight) * $remainingWidth)
        $finalWidth = $baseWidth + $extraWidth
        
        # Respect maximum width constraints
        if ($column.MaxWidth -lt 999 -and $finalWidth -gt $column.MaxWidth) {
            $finalWidth = $column.MaxWidth
        }
        
        $widths[$column.Name] = $finalWidth
    }
    
    return $widths
}

[ColumnDefinition[]] GetActiveColumns() {
    # Get currently active column set based on config and screen width
    $screenWidth = [Console]::WindowWidth
    $activeColumns = @()
    
    # Base columns always shown
    $activeColumns += $this._columnDefinitions['ID']
    $activeColumns += $this._columnDefinitions['Description']
    
    # Add columns based on available width
    if ($screenWidth -gt 80) {
        $activeColumns += $this._columnDefinitions['Project']
        $activeColumns += $this._columnDefinitions['Due']
    }
    
    if ($screenWidth -gt 100) {
        $activeColumns += $this._columnDefinitions['Priority']
        $activeColumns += $this._columnDefinitions['Urgency']
    }
    
    if ($screenWidth -gt 120) {
        $activeColumns += $this._columnDefinitions['Age']
        $activeColumns += $this._columnDefinitions['Tags']
    }
    
    if ($screenWidth -gt 140) {
        $activeColumns += $this._columnDefinitions['Depends']
    }
    
    return $activeColumns | Where-Object { $_.Visible }
}
```

### 3. Column Content Formatters

Specialized formatting for each column type:

```powershell
[string] FormatColumnContent([Task]$task, [ColumnDefinition]$column, [int]$width) {
    $rawContent = $this.GetColumnRawContent($task, $column)
    $formattedContent = $this.ApplyColumnFormatting($rawContent, $column)
    return $this.ApplyColumnLayout($formattedContent, $column, $width)
}

[string] GetColumnRawContent([Task]$task, [ColumnDefinition]$column) {
    switch ($column.Attribute) {
        'id' { return $task.id.ToString() }
        'description' { return $task.description }
        'project' { return $task.project ?? '' }
        'priority' { return $task.priority ?? '' }
        'status' { return $task.status }
        'due' { return $task.GetFormattedDue() }
        'urgency' { return $task.urgency.ToString('F1') }
        'tags' { return ($task.tags -join ',') }
        'entry' { return $task.GetAgeString() }
        'depends' { return $task.depends.Count.ToString() }
        'recur' { return $task.recur ?? '' }
        'scheduled' { return $task.scheduled?.ToString('MM-dd') ?? '' }
        'start' { return $task.start?.ToString('MM-dd') ?? '' }
        default {
            # Check UDAs
            if ($task.uda.ContainsKey($column.Attribute)) {
                return $task.uda[$column.Attribute].ToString()
            }
            return ''
        }
    }
}

[string] ApplyColumnFormatting([string]$content, [ColumnDefinition]$column) {
    # Apply column-specific formatting and colors
    switch ($column.Name) {
        'ID' {
            return $this.ApplyIdHighlight($content)
        }
        'Priority' {
            return $this.ApplyPriorityColor($content)
        }
        'Project' {
            return $this.ApplyProjectHighlight($content)
        }
        'Due' {
            return $this.ApplyDueDateColor($content)
        }
        'Urgency' {
            return $this.ApplyUrgencyColor($content)
        }
        'Tags' {
            return $this.ApplyTagHighlight($content)
        }
        'Status' {
            return $this.ApplyStatusColor($content)
        }
        default {
            return $content
        }
    }
}

[string] ApplyColumnLayout([string]$content, [ColumnDefinition]$column, [int]$width) {
    # Apply alignment and padding
    $truncated = [Measure]::Truncate($content, $width)
    return [Measure]::Pad($truncated, $width, $column.Alignment)
}
```

### 4. Column Header Rendering

Smart header display with sorting indicators:

```powershell
[string] RenderColumnHeaders([ColumnDefinition[]]$columns, [hashtable]$columnWidths, [hashtable]$sortState) {
    $sb = $this.GetPooledStringBuilder()
    
    try {
        # Priority and dependency indicator headers
        $sb.Append("P ")      # Priority column
        $sb.Append("Deps  ")  # Dependency indicators
        
        # Render each column header
        foreach ($column in $columns) {
            $width = $columnWidths[$column.Name]
            $headerText = $column.Header
            
            # Add sort indicator if this column is sorted
            if ($sortState.Field -eq $column.Attribute) {
                $sortChar = if ($sortState.Descending) { "↓" } else { "↑" }
                $headerText += $sortChar
            }
            
            # Apply header formatting
            $formattedHeader = $this.ApplyHeaderHighlight($headerText)
            $paddedHeader = [Measure]::Pad($formattedHeader, $width, $column.Alignment)
            
            $sb.Append($paddedHeader)
        }
        
        return $sb.ToString()
        
    } finally {
        $this.ReturnPooledStringBuilder($sb)
    }
}
```

### 5. Responsive Column Management

Dynamic column visibility based on terminal size:

```powershell
# Column visibility rules for different screen widths
$columnVisibilityRules = @{
    60 = @('ID', 'Description')                                    # Minimal
    80 = @('ID', 'Description', 'Project', 'Due')                 # Basic  
    100 = @('ID', 'Priority', 'Description', 'Project', 'Due', 'Urgency') # Standard
    120 = @('ID', 'Age', 'Priority', 'Description', 'Project', 'Due', 'Urgency', 'Tags') # Extended
    140 = @('ID', 'Age', 'Priority', 'Description', 'Project', 'Due', 'Urgency', 'Tags', 'Depends') # Full
}

[void] UpdateColumnVisibility([int]$screenWidth) {
    # Find appropriate column set for current screen width
    $targetColumns = @('ID', 'Description')  # Minimum set
    
    foreach ($width in ($columnVisibilityRules.Keys | Sort-Object)) {
        if ($screenWidth -ge $width) {
            $targetColumns = $columnVisibilityRules[$width]
        }
    }
    
    # Update column visibility
    foreach ($column in $this._columnDefinitions.Values) {
        $column.Visible = $column.Name -in $targetColumns
    }
    
    # Trigger redraw if columns changed
    if ($this._lastColumnSet -ne ($targetColumns -join ',')) {
        $this._lastColumnSet = $targetColumns -join ','
        $this._needsFullRedraw = $true
    }
}
```

## Comprehensive Configuration System

### 1. TaskRC Configuration Parser

Complete .taskrc parsing with all TaskWarrior configuration categories:

```powershell
class TaskRCParser {
    [hashtable] ParseTaskRC([string]$taskrcPath) {
        $config = @{
            urgency = @{}
            color = @{}
            uda = @{}
            context = @{}
            report = @{}
            alias = @{}
            hook = @{}
        }
        
        $lines = Get-Content $taskrcPath -ErrorAction SilentlyContinue
        foreach ($line in $lines) {
            $line = $line.Trim()
            
            # Skip comments and empty lines
            if ([string]::IsNullOrEmpty($line) -or $line.StartsWith('#')) { continue }
            
            # Handle includes
            if ($line -match '^include\s+(.+)$') {
                $includePath = $matches[1]
                if (-not [System.IO.Path]::IsPathRooted($includePath)) {
                    $includePath = Join-Path (Split-Path $taskrcPath) $includePath
                }
                $includeConfig = $this.ParseTaskRC($includePath)
                $config = $this.MergeConfigurations($config, $includeConfig)
                continue
            }
            
            # Parse key=value pairs
            if ($line -match '^([^=]+)=(.*)$') {
                $key = $matches[1].Trim()
                $value = $matches[2].Trim()
                
                # Categorize configuration
                if ($key.StartsWith('urgency.')) {
                    $config.urgency[$key] = $this.ParseConfigValue($value)
                } elseif ($key.StartsWith('color.')) {
                    $config.color[$key] = $value
                } elseif ($key.StartsWith('uda.')) {
                    $config.uda[$key] = $this.ParseUDADefinition($value)
                } elseif ($key.StartsWith('context.')) {
                    $config.context[$key] = $value
                } elseif ($key.StartsWith('report.')) {
                    $config.report[$key] = $value
                } elseif ($key.StartsWith('alias.')) {
                    $config.alias[$key] = $value
                } elseif ($key.StartsWith('hook.')) {
                    $config.hook[$key] = $value
                } else {
                    # General settings
                    $config[$key] = $this.ParseConfigValue($value)
                }
            }
        }
        
        return $config
    }
    
    [object] ParseConfigValue([string]$value) {
        # Parse different value types
        if ($value -match '^\d+$') { return [int]$value }
        if ($value -match '^\d+\.\d+$') { return [double]$value }
        if ($value -eq 'true') { return $true }
        if ($value -eq 'false') { return $false }
        return $value
    }
    
    [hashtable] ParseUDADefinition([string]$definition) {
        # Parse UDA definition: "type:string,label:Customer"
        $uda = @{}
        $parts = $definition -split ','
        foreach ($part in $parts) {
            if ($part -match '^([^:]+):(.+)$') {
                $uda[$matches[1].Trim()] = $matches[2].Trim()
            }
        }
        return $uda
    }
}
```

### 2. Context Management System

Advanced context switching and workspace management:

```powershell
[string] RenderContextSwitcher([hashtable]$contextState) {
    $sb = $this.GetPooledStringBuilder()
    
    try {
        # Show current context in status bar
        if (-not [string]::IsNullOrEmpty($contextState.activeContext)) {
            $contextName = $contextState.activeContext
            $taskCount = $contextState.filteredCount
            $sb.Append($this.ApplyContextHighlight("[$contextName:$taskCount]"))
        } else {
            $sb.Append("No context")
        }
        
        return $sb.ToString()
        
    } finally {
        $this.ReturnPooledStringBuilder($sb)
    }
}

# Context switching commands
":work"         # Switch to work context
":personal"     # Switch to personal context  
":none"         # Clear context
":list"         # Show available contexts
":define work project:work.* or +urgent"  # Define new context
```

### 3. Enhanced Annotation Display

Rich annotation rendering with timestamps and editing:

```powershell
[string] RenderTaskAnnotations([Task]$task, [int]$maxWidth) {
    $sb = $this.GetPooledStringBuilder()
    
    try {
        if ($task.annotations.Count -eq 0) {
            return ""
        }
        
        $annotations = $task.GetAnnotationsSorted()
        foreach ($annotation in $annotations) {
            $timestamp = $annotation.entry.ToString("MM-dd HH:mm")
            $description = $annotation.description
            
            # Format: [timestamp] description
            $line = "[$timestamp] $description"
            if ($line.Length -gt $maxWidth) {
                $line = $line.Substring(0, $maxWidth - 3) + "..."
            }
            
            $sb.AppendLine($this.ApplyAnnotationHighlight($line))
        }
        
        return $sb.ToString()
        
    } finally {
        $this.ReturnPooledStringBuilder($sb)
    }
}
```

### 4. Project Hierarchy Visualization

Tree-like display of project structures:

```powershell
[string] RenderProjectHierarchy([hashtable]$projectTree, [int]$depth = 0) {
    $sb = $this.GetPooledStringBuilder()
    
    try {
        $indent = "  " * $depth
        
        foreach ($projectName in ($projectTree.Keys | Sort-Object)) {
            $projectData = $projectTree[$projectName]
            $taskCount = $projectData.TaskCount
            $childCount = $projectData.Children.Count
            
            # Render project node
            $nodeChar = if ($childCount -gt 0) { "📁" } else { "📄" }
            $line = "$indent$nodeChar $projectName ($taskCount)"
            $sb.AppendLine($this.ApplyProjectTreeHighlight($line, $depth))
            
            # Render children recursively
            if ($childCount -gt 0 -and $depth -lt 5) {
                $sb.Append($this.RenderProjectHierarchy($projectData.Children, $depth + 1))
            }
        }
        
        return $sb.ToString()
        
    } finally {
        $this.ReturnPooledStringBuilder($sb)
    }
}
```

### 5. Advanced Column Customization

User-configurable column system:

```powershell
# Column customization commands
":columns list"                    # Show available columns
":columns show id,desc,project"    # Set visible columns  
":columns hide tags"               # Hide specific columns
":columns width desc:30"           # Set column width
":columns order priority:1,desc:2" # Reorder columns
":columns save report_name"        # Save column configuration
":columns load report_name"        # Load saved configuration

[void] ApplyColumnConfiguration([hashtable]$columnConfig) {
    foreach ($column in $this._columnDefinitions.Values) {
        $configKey = "column.$($column.Attribute)"
        
        if ($columnConfig.ContainsKey("$configKey.visible")) {
            $column.Visible = $columnConfig["$configKey.visible"]
        }
        
        if ($columnConfig.ContainsKey("$configKey.width")) {
            $column.MinWidth = $columnConfig["$configKey.width"]
            $column.MaxWidth = $columnConfig["$configKey.width"]
        }
        
        if ($columnConfig.ContainsKey("$configKey.label")) {
            $column.Header = $columnConfig["$configKey.label"]
        }
    }
}
```

## Production-Ready Infrastructure Systems

### 1. Virtual Scrolling Engine

High-performance rendering for large datasets:

```powershell
class VirtualScrollingEngine {
    hidden [int] $_bufferSize = 10        # Extra rows to render for smooth scrolling
    hidden [hashtable] $_visibleRange = @{}
    hidden [hashtable] $_renderCache = @{}
    hidden [int] $_lastScrollOffset = -1
    hidden [int] $_lastViewportHeight = -1
    
    VirtualScrollingEngine([int]$bufferSize = 10) {
        $this._bufferSize = $bufferSize
        $this._visibleRange = @{
            StartIndex = 0
            EndIndex = 0
            BufferStart = 0
            BufferEnd = 0
        }
    }
    
    # Calculate which rows actually need rendering
    [hashtable] CalculateVisibleRange([int]$scrollOffset, [int]$viewportHeight, [int]$totalItems) {
        # Only recalculate if scroll position or viewport changed
        if ($scrollOffset -eq $this._lastScrollOffset -and $viewportHeight -eq $this._lastViewportHeight) {
            return $this._visibleRange
        }
        
        # Calculate visible range with buffer
        $startIndex = [Math]::Max(0, $scrollOffset - $this._bufferSize)
        $endIndex = [Math]::Min($totalItems - 1, $scrollOffset + $viewportHeight + $this._bufferSize)
        
        $this._visibleRange = @{
            StartIndex = $scrollOffset
            EndIndex = [Math]::Min($scrollOffset + $viewportHeight - 1, $totalItems - 1)
            BufferStart = $startIndex
            BufferEnd = $endIndex
            TotalVisible = $endIndex - $startIndex + 1
        }
        
        $this._lastScrollOffset = $scrollOffset
        $this._lastViewportHeight = $viewportHeight
        
        return $this._visibleRange
    }
    
    # Invalidate cached rows when data changes
    [void] InvalidateRange([int]$startIndex, [int]$endIndex) {
        for ($i = $startIndex; $i -le $endIndex; $i++) {
            $this._renderCache.Remove($i)
        }
    }
    
    # Get cached rendered line or render new one
    [string] GetRenderedLine([int]$index, [Task]$task, [scriptblock]$renderFunc) {
        $cacheKey = "$index-$($task.modified.Ticks)"
        
        if ($this._renderCache.ContainsKey($cacheKey)) {
            return $this._renderCache[$cacheKey]
        }
        
        # Render the line
        $renderedLine = & $renderFunc $task
        
        # Cache with size limit
        if ($this._renderCache.Count -gt 1000) {
            # Remove oldest 20% of cache entries
            $keysToRemove = $this._renderCache.Keys | Select-Object -First 200
            foreach ($key in $keysToRemove) {
                $this._renderCache.Remove($key)
            }
        }
        
        $this._renderCache[$cacheKey] = $renderedLine
        return $renderedLine
    }
    
    # Clear all cached renders
    [void] ClearCache() {
        $this._renderCache.Clear()
    }
}
```

### 2. Background Processing Pipeline

Async processing for expensive operations:

```powershell
class TaskProcessingPipeline {
    hidden [System.Collections.Concurrent.ConcurrentQueue[hashtable]] $_workQueue
    hidden [hashtable] $_activeJobs = @{}
    hidden [hashtable] $_completedResults = @{}
    hidden [int] $_jobIdCounter = 0
    hidden [bool] $_isProcessing = $false
    hidden [System.Threading.Timer] $_processingTimer
    
    TaskProcessingPipeline() {
        $this._workQueue = [System.Collections.Concurrent.ConcurrentQueue[hashtable]]::new()
        
        # Start background processing timer (every 50ms)
        $this._processingTimer = [System.Threading.Timer]::new(
            [System.Threading.TimerCallback]{ $this.ProcessWorkQueue() },
            $null, 50, 50
        )
    }
    
    # Queue urgency recalculation for tasks
    [int] QueueUrgencyCalculation([Task[]]$tasks, [hashtable]$config) {
        $jobId = ++$this._jobIdCounter
        
        $job = @{
            JobId = $jobId
            Type = 'UrgencyCalculation'
            Tasks = $tasks
            Config = $config
            QueuedAt = [datetime]::Now
            Status = 'Queued'
        }
        
        $this._workQueue.Enqueue($job)
        $this._activeJobs[$jobId] = $job
        
        return $jobId
    }
    
    # Queue filter evaluation
    [int] QueueFilterEvaluation([Task[]]$tasks, [string]$expression) {
        $jobId = ++$this._jobIdCounter
        
        $job = @{
            JobId = $jobId
            Type = 'FilterEvaluation'
            Tasks = $tasks
            Expression = $expression
            QueuedAt = [datetime]::Now
            Status = 'Queued'
        }
        
        $this._workQueue.Enqueue($job)
        $this._activeJobs[$jobId] = $job
        
        return $jobId
    }
    
    # Queue sorting operation
    [int] QueueSorting([Task[]]$tasks, [string]$sortField, [bool]$descending) {
        $jobId = ++$this._jobIdCounter
        
        $job = @{
            JobId = $jobId
            Type = 'Sorting'
            Tasks = $tasks
            SortField = $sortField
            Descending = $descending
            QueuedAt = [datetime]::Now
            Status = 'Queued'
        }
        
        $this._workQueue.Enqueue($job)
        $this._activeJobs[$jobId] = $job
        
        return $jobId
    }
    
    # Get completed results
    [hashtable] GetResult([int]$jobId, [int]$timeoutMs = 0) {
        $startTime = [datetime]::Now
        
        while ($true) {
            if ($this._completedResults.ContainsKey($jobId)) {
                $result = $this._completedResults[$jobId]
                $this._completedResults.Remove($jobId)
                return $result
            }
            
            if ($timeoutMs -gt 0 -and ([datetime]::Now - $startTime).TotalMilliseconds -gt $timeoutMs) {
                return @{ Status = 'Timeout'; JobId = $jobId }
            }
            
            Start-Sleep -Milliseconds 10
        }
    }
    
    # Check if job is complete (non-blocking)
    [bool] IsComplete([int]$jobId) {
        return $this._completedResults.ContainsKey($jobId)
    }
    
    # Process work queue (called by timer)
    [void] ProcessWorkQueue() {
        if ($this._isProcessing) { return }  # Prevent concurrent processing
        
        $this._isProcessing = $true
        
        try {
            $job = $null
            if ($this._workQueue.TryDequeue([ref]$job)) {
                $this.ProcessJob($job)
            }
        } finally {
            $this._isProcessing = $false
        }
    }
    
    # Process individual job
    [void] ProcessJob([hashtable]$job) {
        try {
            $job.Status = 'Processing'
            $job.StartedAt = [datetime]::Now
            
            $result = @{
                JobId = $job.JobId
                Status = 'Completed'
                CompletedAt = [datetime]::Now
            }
            
            switch ($job.Type) {
                'UrgencyCalculation' {
                    foreach ($task in $job.Tasks) {
                        $task.CalculateUrgency($job.Config)
                    }
                    $result.UpdatedTasks = $job.Tasks
                }
                
                'FilterEvaluation' {
                    $parser = [FilterExpressionParser]::new()
                    $ast = $parser.ParseFilter($job.Expression)
                    $filteredTasks = $job.Tasks | Where-Object { $_.MatchesFilter($ast) }
                    $result.FilteredTasks = $filteredTasks
                }
                
                'Sorting' {
                    $sortedTasks = $job.Tasks | Sort-Object -Property $job.SortField -Descending:$job.Descending
                    $result.SortedTasks = $sortedTasks
                }
            }
            
            $this._completedResults[$job.JobId] = $result
            
        } catch {
            # Job failed - return error result
            $this._completedResults[$job.JobId] = @{
                JobId = $job.JobId
                Status = 'Failed'
                Error = $_.Exception.Message
                CompletedAt = [datetime]::Now
            }
        } finally {
            $this._activeJobs.Remove($job.JobId)
        }
    }
    
    # Get queue statistics
    [hashtable] GetStatistics() {
        return @{
            QueuedJobs = $this._workQueue.Count
            ActiveJobs = $this._activeJobs.Count
            CompletedResults = $this._completedResults.Count
        }
    }
    
    # Dispose resources
    [void] Dispose() {
        if ($this._processingTimer) {
            $this._processingTimer.Dispose()
        }
    }
}
```

### 3. Unified State Coordinator

Transaction-based state management:

```powershell
class RenderStateManager {
    hidden [hashtable] $_currentState = @{}
    hidden [hashtable] $_transactionState = $null
    hidden [bool] $_inTransaction = $false
    hidden [System.Collections.Generic.List[hashtable]] $_subscribers = [System.Collections.Generic.List[hashtable]]::new()
    hidden [hashtable] $_changeQueue = @{}
    
    RenderStateManager([hashtable]$initialState) {
        $this._currentState = $initialState.Clone()
        $this._changeQueue = @{}
    }
    
    # Subscribe to state changes
    [void] Subscribe([string]$eventType, [scriptblock]$callback) {
        $this._subscribers.Add(@{
            EventType = $eventType
            Callback = $callback
        })
    }
    
    # Begin state transaction
    [void] BeginTransaction() {
        if ($this._inTransaction) {
            throw "Transaction already in progress"
        }
        
        $this._inTransaction = $true
        $this._transactionState = $this._currentState.Clone()
        $this._changeQueue.Clear()
    }
    
    # Update task list within transaction
    [void] UpdateTaskList([Task[]]$newTasks) {
        $this.EnsureTransaction()
        
        $oldTasks = $this._transactionState.tasks
        $this._transactionState.tasks = $newTasks
        
        $this._changeQueue.TasksChanged = @{
            OldTasks = $oldTasks
            NewTasks = $newTasks
            ChangedAt = [datetime]::Now
        }
        
        # Invalidate dependent state
        $this.InvalidateFilteredTasks()
        $this.InvalidateSortedTasks()
    }
    
    # Update filter within transaction  
    [void] UpdateFilter([string]$newFilter) {
        $this.EnsureTransaction()
        
        $oldFilter = $this._transactionState.currentFilter
        $this._transactionState.currentFilter = $newFilter
        
        $this._changeQueue.FilterChanged = @{
            OldFilter = $oldFilter
            NewFilter = $newFilter
            ChangedAt = [datetime]::Now
        }
        
        $this.InvalidateFilteredTasks()
    }
    
    # Update sort within transaction
    [void] UpdateSort([string]$field, [bool]$descending) {
        $this.EnsureTransaction()
        
        $this._transactionState.sortField = $field
        $this._transactionState.sortDescending = $descending
        
        $this._changeQueue.SortChanged = @{
            Field = $field
            Descending = $descending
            ChangedAt = [datetime]::Now
        }
        
        $this.InvalidateSortedTasks()
    }
    
    # Update configuration within transaction
    [void] UpdateConfiguration([hashtable]$configChanges) {
        $this.EnsureTransaction()
        
        foreach ($key in $configChanges.Keys) {
            $this._transactionState.taskrcConfig[$key] = $configChanges[$key]
        }
        
        $this._changeQueue.ConfigChanged = @{
            Changes = $configChanges
            ChangedAt = [datetime]::Now
        }
        
        # Config changes can affect everything
        $this.InvalidateUrgencyCalculations()
        $this.InvalidateFilteredTasks()
    }
    
    # Commit transaction and notify subscribers
    [void] CommitTransaction() {
        if (-not $this._inTransaction) {
            throw "No transaction in progress"
        }
        
        try {
            # Apply all changes atomically
            $this._currentState = $this._transactionState.Clone()
            
            # Notify subscribers of all changes
            foreach ($changeType in $this._changeQueue.Keys) {
                $this.NotifySubscribers($changeType, $this._changeQueue[$changeType])
            }
            
        } finally {
            $this._inTransaction = $false
            $this._transactionState = $null
            $this._changeQueue.Clear()
        }
    }
    
    # Rollback transaction
    [void] RollbackTransaction() {
        if (-not $this._inTransaction) {
            throw "No transaction in progress"
        }
        
        $this._inTransaction = $false
        $this._transactionState = $null
        $this._changeQueue.Clear()
    }
    
    # Get current state (read-only)
    [hashtable] GetCurrentState() {
        return $this._currentState.Clone()
    }
    
    # Get specific state value
    [object] GetStateValue([string]$key) {
        return $this._currentState[$key]
    }
    
    # Private helper methods
    hidden [void] EnsureTransaction() {
        if (-not $this._inTransaction) {
            throw "Operation requires active transaction"
        }
    }
    
    hidden [void] NotifySubscribers([string]$eventType, [hashtable]$eventData) {
        foreach ($subscriber in $this._subscribers) {
            if ($subscriber.EventType -eq $eventType -or $subscriber.EventType -eq '*') {
                try {
                    & $subscriber.Callback $eventData
                } catch {
                    # Log subscriber errors but continue
                    [Logger]::Error("State subscriber error for $eventType", $_)
                }
            }
        }
    }
    
    hidden [void] InvalidateFilteredTasks() {
        $this._changeQueue.FilteredTasksInvalidated = @{ ChangedAt = [datetime]::Now }
    }
    
    hidden [void] InvalidateSortedTasks() {
        $this._changeQueue.SortedTasksInvalidated = @{ ChangedAt = [datetime]::Now }
    }
    
    hidden [void] InvalidateUrgencyCalculations() {
        $this._changeQueue.UrgencyInvalidated = @{ ChangedAt = [datetime]::Now }
    }
}
```

### 4. Cache Management System

Multi-level caching for optimal performance:

```powershell
class RenderCacheManager {
    hidden [hashtable] $_urgencyCache = @{}
    hidden [hashtable] $_filterCache = @{}
    hidden [hashtable] $_formattedLineCache = @{}
    hidden [hashtable] $_sortCache = @{}
    hidden [hashtable] $_virtualTagCache = @{}
    hidden [int] $_maxCacheSize = 2000
    hidden [System.Collections.Generic.Dictionary[string, datetime]] $_accessTimes = [System.Collections.Generic.Dictionary[string, datetime]]::new()
    
    RenderCacheManager([int]$maxCacheSize = 2000) {
        $this._maxCacheSize = $maxCacheSize
    }
    
    # Cache urgency calculations
    [void] CacheTaskUrgency([string]$taskUuid, [string]$configHash, [double]$urgency) {
        $key = "$taskUuid-$configHash"
        $this._urgencyCache[$key] = $urgency
        $this._accessTimes[$key] = [datetime]::Now
        $this.EnforceCacheSize('urgency')
    }
    
    [nullable[double]] GetCachedUrgency([string]$taskUuid, [string]$configHash) {
        $key = "$taskUuid-$configHash"
        if ($this._urgencyCache.ContainsKey($key)) {
            $this._accessTimes[$key] = [datetime]::Now
            return $this._urgencyCache[$key]
        }
        return $null
    }
    
    # Cache filter results
    [void] CacheFilterResult([string]$filterExpression, [string]$taskListHash, [string[]]$matchingUuids) {
        $key = "$filterExpression-$taskListHash"
        $this._filterCache[$key] = $matchingUuids
        $this._accessTimes[$key] = [datetime]::Now
        $this.EnforceCacheSize('filter')
    }
    
    [string[]] GetCachedFilterResult([string]$filterExpression, [string]$taskListHash) {
        $key = "$filterExpression-$taskListHash"
        if ($this._filterCache.ContainsKey($key)) {
            $this._accessTimes[$key] = [datetime]::Now
            return $this._filterCache[$key]
        }
        return $null
    }
    
    # Cache formatted task lines
    [void] CacheFormattedLine([string]$taskUuid, [string]$formatHash, [string]$formattedLine) {
        $key = "$taskUuid-$formatHash"
        $this._formattedLineCache[$key] = $formattedLine
        $this._accessTimes[$key] = [datetime]::Now
        $this.EnforceCacheSize('formatted')
    }
    
    [string] GetCachedFormattedLine([string]$taskUuid, [string]$formatHash) {
        $key = "$taskUuid-$formatHash"
        if ($this._formattedLineCache.ContainsKey($key)) {
            $this._accessTimes[$key] = [datetime]::Now
            return $this._formattedLineCache[$key]
        }
        return $null
    }
    
    # Cache virtual tags (expensive to calculate)
    [void] CacheVirtualTags([string]$taskUuid, [datetime]$taskModified, [string[]]$virtualTags) {
        $key = "$taskUuid-$($taskModified.Ticks)"
        $this._virtualTagCache[$key] = $virtualTags
        $this._accessTimes[$key] = [datetime]::Now
        $this.EnforceCacheSize('virtualtag')
    }
    
    [string[]] GetCachedVirtualTags([string]$taskUuid, [datetime]$taskModified) {
        $key = "$taskUuid-$($taskModified.Ticks)"
        if ($this._virtualTagCache.ContainsKey($key)) {
            $this._accessTimes[$key] = [datetime]::Now
            return $this._virtualTagCache[$key]
        }
        return $null
    }
    
    # Invalidate specific task caches
    [void] InvalidateTaskCache([string]$taskUuid) {
        $keysToRemove = @()
        
        # Find all cache keys containing this task UUID
        foreach ($key in $this._urgencyCache.Keys) {
            if ($key.StartsWith($taskUuid)) { $keysToRemove += $key }
        }
        foreach ($key in $this._formattedLineCache.Keys) {
            if ($key.StartsWith($taskUuid)) { $keysToRemove += $key }
        }
        foreach ($key in $this._virtualTagCache.Keys) {
            if ($key.StartsWith($taskUuid)) { $keysToRemove += $key }
        }
        
        # Remove from all caches
        foreach ($key in $keysToRemove) {
            $this._urgencyCache.Remove($key)
            $this._formattedLineCache.Remove($key)
            $this._virtualTagCache.Remove($key)
            $this._accessTimes.Remove($key)
        }
    }
    
    # Invalidate filter caches (when task list changes)
    [void] InvalidateFilterCache() {
        $this._filterCache.Clear()
        $this._sortCache.Clear()
        
        # Remove access times for filter keys
        $keysToRemove = @()
        foreach ($key in $this._accessTimes.Keys) {
            if ($key.Contains('-')) {
                $parts = $key -split '-'
                if ($parts.Length -ge 2 -and ($parts[1].Length -eq 32 -or $parts[1].Length -eq 40)) {
                    # Looks like a hash, probably a filter or sort cache key
                    $keysToRemove += $key
                }
            }
        }
        foreach ($key in $keysToRemove) {
            $this._accessTimes.Remove($key)
        }
    }
    
    # Generate hash for configuration
    [string] GetConfigHash([hashtable]$config) {
        $configString = ($config.GetEnumerator() | Sort-Object Key | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ';'
        return [System.Security.Cryptography.MD5]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($configString)) | ForEach-Object { $_.ToString('x2') } | Join-String
    }
    
    # Generate hash for task list
    [string] GetTaskListHash([Task[]]$tasks) {
        $hashString = ($tasks | ForEach-Object { "$($_.uuid)-$($_.modified.Ticks)" }) -join ';'
        return [System.Security.Cryptography.MD5]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($hashString)) | ForEach-Object { $_.ToString('x2') } | Join-String
    }
    
    # Enforce cache size limits using LRU eviction
    hidden [void] EnforceCacheSize([string]$cacheType) {
        $cache = switch ($cacheType) {
            'urgency' { $this._urgencyCache }
            'filter' { $this._filterCache }
            'formatted' { $this._formattedLineCache }
            'virtualtag' { $this._virtualTagCache }
        }
        
        if ($cache.Count -gt $this._maxCacheSize) {
            # Remove oldest 20% of entries
            $entriesToRemove = [int]($this._maxCacheSize * 0.2)
            $oldestKeys = $cache.Keys | Sort-Object { $this._accessTimes[$_] } | Select-Object -First $entriesToRemove
            
            foreach ($key in $oldestKeys) {
                $cache.Remove($key)
                $this._accessTimes.Remove($key)
            }
        }
    }
    
    # Get cache statistics
    [hashtable] GetCacheStatistics() {
        return @{
            UrgencyCache = $this._urgencyCache.Count
            FilterCache = $this._filterCache.Count
            FormattedLineCache = $this._formattedLineCache.Count
            VirtualTagCache = $this._virtualTagCache.Count
            TotalEntries = $this._urgencyCache.Count + $this._filterCache.Count + $this._formattedLineCache.Count + $this._virtualTagCache.Count
            MaxCacheSize = $this._maxCacheSize
        }
    }
    
    # Clear all caches
    [void] ClearAll() {
        $this._urgencyCache.Clear()
        $this._filterCache.Clear()
        $this._formattedLineCache.Clear()
        $this._virtualTagCache.Clear()
        $this._sortCache.Clear()
        $this._accessTimes.Clear()
    }
}
```

### 5. Error Boundary System

Provides graceful degradation when rendering components fail, ensuring application stability:

```powershell
class RenderErrorHandler {
    hidden [hashtable] $_errorCounts = @{}
    hidden [hashtable] $_fallbackCache = @{}
    hidden [int] $_maxErrorsPerComponent = 5
    hidden [int] $_errorResetTimeMs = 30000
    hidden [Logger] $_logger = $null
    
    RenderErrorHandler([Logger]$logger = $null) {
        $this._logger = $logger
    }
    
    # Execute with error boundary protection
    [object] SafeExecute([string]$componentName, [scriptblock]$operation, [object]$fallbackValue = $null) {
        try {
            return $operation.Invoke()
        } catch {
            return $this.HandleRenderError($componentName, $_, $fallbackValue)
        }
    }
    
    # Handle rendering errors with fallback strategies
    [object] HandleRenderError([string]$componentName, [System.Management.Automation.ErrorRecord]$error, [object]$fallbackValue) {
        $errorKey = "${componentName}_$($error.Exception.GetType().Name)"
        
        # Track error frequency
        if (-not $this._errorCounts.ContainsKey($errorKey)) {
            $this._errorCounts[$errorKey] = @{
                Count = 0
                FirstSeen = Get-Date
                LastSeen = Get-Date
            }
        }
        
        $errorInfo = $this._errorCounts[$errorKey]
        $errorInfo.Count++
        $errorInfo.LastSeen = Get-Date
        
        if ($this._logger) {
            $this._logger.Error("RenderErrorHandler: $componentName failed (attempt $($errorInfo.Count))", $error)
        }
        
        # Check if component should be disabled
        if ($errorInfo.Count -gt $this._maxErrorsPerComponent) {
            if ($this._logger) {
                $this._logger.Warn("RenderErrorHandler: Disabling $componentName due to repeated failures")
            }
            return $this.GetDisabledComponentFallback($componentName)
        }
        
        # Return fallback value or cached content
        if ($fallbackValue -ne $null) {
            return $fallbackValue
        }
        
        return $this.GetFallbackContent($componentName)
    }
    
    # Get fallback content for failed component
    [string] GetFallbackContent([string]$componentName) {
        if ($this._fallbackCache.ContainsKey($componentName)) {
            return $this._fallbackCache[$componentName]
        }
        
        # Generate minimal fallback based on component type
        switch -Regex ($componentName) {
            'TaskList' { return "[Task list temporarily unavailable]" }
            'Header' { return "TaskWarrior-TUI" }
            'Footer' { return "Press q to quit" }
            'StatusBar' { return "Ready" }
            'FilterBar' { return "Filter: all" }
            default { return "[Component error: $componentName]" }
        }
    }
    
    # Get placeholder for permanently disabled component
    [string] GetDisabledComponentFallback([string]$componentName) {
        return "[DISABLED: $componentName - Too many errors]"
    }
    
    # Reset error counts (called periodically)
    [void] ResetErrorCounts() {
        $cutoff = (Get-Date).AddMilliseconds(-$this._errorResetTimeMs)
        $keysToReset = @()
        
        foreach ($key in $this._errorCounts.Keys) {
            if ($this._errorCounts[$key].LastSeen -lt $cutoff) {
                $keysToReset += $key
            }
        }
        
        foreach ($key in $keysToReset) {
            $this._errorCounts.Remove($key)
        }
        
        if ($keysToReset.Count -gt 0 -and $this._logger) {
            $this._logger.Debug("RenderErrorHandler: Reset $($keysToReset.Count) error counters")
        }
    }
    
    # Cache successful render output for fallback
    [void] CacheSuccessfulRender([string]$componentName, [string]$content) {
        # Only cache if content is reasonable size and not empty
        if ($content.Length -gt 0 -and $content.Length -lt 1000) {
            $this._fallbackCache[$componentName] = $content
        }
    }
    
    # Get error statistics
    [hashtable] GetErrorStats() {
        $stats = @{
            TotalComponents = $this._errorCounts.Count
            TotalErrors = 0
            DisabledComponents = @()
        }
        
        foreach ($key in $this._errorCounts.Keys) {
            $errorInfo = $this._errorCounts[$key]
            $stats.TotalErrors += $errorInfo.Count
            if ($errorInfo.Count -gt $this._maxErrorsPerComponent) {
                $stats.DisabledComponents += $key
            }
        }
        
        return $stats
        }
    }
    
    # Render error state
    [string] RenderErrorState([Exception]$error, [int]$consoleWidth) {
        $sb = [System.Text.StringBuilder]::new()
        
        $errorTitle = "⚠️  Rendering Error"
        $errorMessage = "Error: $($error.Message)"
        
        # Center the error message
        $titlePadding = [Math]::Max(0, ($consoleWidth - $errorTitle.Length) / 2)
        $messagePadding = [Math]::Max(0, ($consoleWidth - $errorMessage.Length) / 2)
        
        $sb.AppendLine([VT]::RGB(255, 100, 100) + (" " * $titlePadding) + $errorTitle + [VT]::Reset())
        $sb.AppendLine()
        $sb.AppendLine([VT]::RGB(200, 200, 200) + (" " * $messagePadding) + $errorMessage + [VT]::Reset())
        $sb.AppendLine()
        $sb.AppendLine([VT]::RGB(150, 150, 150) + "Press 'r' to retry or 'q' to quit" + [VT]::Reset())
        
        return $sb.ToString()
    }
    
    # Render loading state
    [string] RenderLoadingState([string]$operation, [int]$consoleWidth) {
        $sb = [System.Text.StringBuilder]::new()
        
        $loadingTitle = "🔄 Loading..."
        $operationText = "Operation: $operation"
        
        $titlePadding = [Math]::Max(0, ($consoleWidth - $loadingTitle.Length) / 2)
        $operationPadding = [Math]::Max(0, ($consoleWidth - $operationText.Length) / 2)
        
        $sb.AppendLine([VT]::RGB(100, 150, 255) + (" " * $titlePadding) + $loadingTitle + [VT]::Reset())
        $sb.AppendLine()
        $sb.AppendLine([VT]::RGB(150, 150, 150) + (" " * $operationPadding) + $operationText + [VT]::Reset())
        
        return $sb.ToString()
    }
    
    # Render degraded mode (when some features fail)
    [string] RenderDegradedMode([string[]]$failedFeatures, [string]$basicContent) {
        $sb = [System.Text.StringBuilder]::new()
        
        # Show degraded mode warning
        $warningLine = "⚠️  Degraded Mode - Some features unavailable: $($failedFeatures -join ', ')"
        $sb.AppendLine([VT]::RGB(255, 165, 0) + $warningLine + [VT]::Reset())
        $sb.AppendLine()
        
        # Show basic content
        $sb.AppendLine($basicContent)
        
        return $sb.ToString()
    }
    
    # Recover from render failure
    [void] RecoverFromRenderFailure() {
        try {
            # Clear console and reset
            [Console]::Clear()
            [Console]::Write([VT]::Reset() + [VT]::ShowCursor())
            
            # Restore fallback state if available
            if ($this._fallbackState.Count -gt 0) {
                # Attempt to restore minimal functionality
                $this.RestoreFallbackState()
            }
        } catch {
            # Last resort recovery
            try {
                [Console]::WriteLine("Critical error recovery - press any key to exit")
                [Console]::ReadKey() | Out-Null
            } catch {
                # Even console output failed - just exit
                exit 1
            }
        }
    }
    
    # Save current state as fallback
    [void] SaveFallbackState([hashtable]$currentState) {
        $this._fallbackState = @{
            BasicTaskList = $currentState.tasks | Select-Object -First 10 | ForEach-Object { "$($_.id): $($_.description)" }
            FilterInfo = $currentState.currentFilter
            Timestamp = [datetime]::Now
        }
    }
    
    # Restore fallback state
    hidden [void] RestoreFallbackState() {
        if ($this._fallbackState.Count -eq 0) { return }
        
        $sb = [System.Text.StringBuilder]::new()
        
        $sb.AppendLine("🔧 Emergency Mode - Basic Task List")
        $sb.AppendLine("=" * 50)
        
        if ($this._fallbackState.BasicTaskList) {
            foreach ($task in $this._fallbackState.BasicTaskList) {
                $sb.AppendLine($task)
            }
        }
        
        $sb.AppendLine()
        $sb.AppendLine("Press 'q' to quit, 'r' to retry full mode")
        
        [Console]::Write($sb.ToString())
    }
    
    # Record error for debugging
    hidden [void] RecordError([hashtable]$error) {
        $this._errorHistory.Add($error)
        
        # Limit error history size
        while ($this._errorHistory.Count -gt $this._maxErrorHistory) {
            $this._errorHistory.RemoveAt(0)
        }
        
        # Log the error
        if ($this._logger) {
            $this._logger.Error("Render error in $($error.OperationName)", $error.Exception)
        }
    }
    
    # Get error statistics
    [hashtable] GetErrorStatistics() {
        $errorsByOperation = @{}
        foreach ($error in $this._errorHistory) {
            if (-not $errorsByOperation.ContainsKey($error.OperationName)) {
                $errorsByOperation[$error.OperationName] = 0
            }
            $errorsByOperation[$error.OperationName]++
        }
        
        return @{
            TotalErrors = $this._errorHistory.Count
            ErrorsByOperation = $errorsByOperation
            LastError = if ($this._errorHistory.Count -gt 0) { $this._errorHistory[-1] } else { $null }
        }
    }
}
```

---

# PART 2: ADVANCED TASKWARRIOR COMPONENTS

## System 19: Advanced Filter Expression Parser

Complete filter expression parsing system supporting TaskWarrior's full filter syntax.

```powershell
class AdvancedFilterParser {
    hidden [hashtable] $_operatorPrecedence = @{
        'or' = 1
        'and' = 2
        'not' = 3
        '(' = 0
        ')' = 0
    }
    
    hidden [hashtable] $_dateAbbreviations = @{
        'now' = { [datetime]::Now }
        'today' = { [datetime]::Today }
        'tomorrow' = { [datetime]::Today.AddDays(1) }
        'yesterday' = { [datetime]::Today.AddDays(-1) }
        'eom' = { $this.GetEndOfMonth([datetime]::Now) }
        'som' = { [datetime]::new([datetime]::Now.Year, [datetime]::Now.Month, 1) }
        'sow' = { $this.GetStartOfWeek([datetime]::Now) }
        'eow' = { $this.GetEndOfWeek([datetime]::Now) }
    }
    
    hidden [string[]] $_virtualTags = @(
        'OVERDUE', 'TODAY', 'TOMORROW', 'WEEK', 'MONTH', 'YEAR',
        'PENDING', 'COMPLETED', 'DELETED', 'WAITING', 'RECURRING',
        'ACTIVE', 'BLOCKED', 'READY', 'URGENT', 'PRIORITY'
    )
    
    [hashtable] ParseFilterExpression([string]$expression) {
        if ([string]::IsNullOrWhiteSpace($expression)) {
            return @{ Type = 'Empty'; IsValid = $true }
        }
        
        try {
            # Tokenize the expression
            $tokens = $this.TokenizeExpression($expression)
            
            # Convert to postfix notation (Shunting Yard algorithm)
            $postfix = $this.ConvertToPostfix($tokens)
            
            # Build Abstract Syntax Tree
            $ast = $this.BuildAST($postfix)
            
            return @{
                Type = 'ParsedFilter'
                AST = $ast
                IsValid = $true
                OriginalExpression = $expression
                TokenCount = $tokens.Count
            }
        } catch {
            return @{
                Type = 'Error'
                IsValid = $false
                Error = $_.Exception.Message
                OriginalExpression = $expression
            }
        }
    }
    
    hidden [array] TokenizeExpression([string]$expression) {
        $tokens = @()
        $current = ''
        $inQuotes = $false
        $inRegex = $false
        
        for ($i = 0; $i -lt $expression.Length; $i++) {
            $char = $expression[$i]
            
            switch ($char) {
                '"' {
                    $inQuotes = -not $inQuotes
                    $current += $char
                }
                '/' {
                    if (-not $inQuotes) {
                        if ($inRegex) {
                            $current += $char
                            $tokens += @{ Type = 'Regex'; Value = $current }
                            $current = ''
                            $inRegex = $false
                        } elseif ($current -match '~$') {
                            $current += $char
                            $inRegex = $true
                        } else {
                            $current += $char
                        }
                    } else {
                        $current += $char
                    }
                }
                ' ' {
                    if ($inQuotes -or $inRegex) {
                        $current += $char
                    } elseif ($current.Length -gt 0) {
                        $tokens += $this.ClassifyToken($current)
                        $current = ''
                    }
                }
                '(' {
                    if ($inQuotes -or $inRegex) {
                        $current += $char
                    } else {
                        if ($current.Length -gt 0) {
                            $tokens += $this.ClassifyToken($current)
                            $current = ''
                        }
                        $tokens += @{ Type = 'LeftParen'; Value = '(' }
                    }
                }
                ')' {
                    if ($inQuotes -or $inRegex) {
                        $current += $char
                    } else {
                        if ($current.Length -gt 0) {
                            $tokens += $this.ClassifyToken($current)
                            $current = ''
                        }
                        $tokens += @{ Type = 'RightParen'; Value = ')' }
                    }
                }
                default {
                    $current += $char
                }
            }
        }
        
        if ($current.Length -gt 0) {
            $tokens += $this.ClassifyToken($current)
        }
        
        return $tokens
    }
    
    hidden [hashtable] ClassifyToken([string]$token) {
        # Logical operators
        if ($token -in @('and', 'or', 'not')) {
            return @{ Type = 'Operator'; Value = $token.ToLower() }
        }
        
        # Attribute filters (project:work, +urgent, -COMPLETED)
        if ($token -match '^([a-zA-Z_]+[a-zA-Z0-9_]*):(.*)$') {
            return @{
                Type = 'AttributeFilter'
                Attribute = $matches[1]
                Value = $matches[2]
                Operator = 'equals'
            }
        }
        
        # Attribute comparisons (urgency.over:5.0)
        if ($token -match '^([a-zA-Z_]+[a-zA-Z0-9_]*)\\.([a-z]+):(.*)$') {
            return @{
                Type = 'AttributeFilter'
                Attribute = $matches[1]
                Value = $matches[3]
                Operator = $matches[2]
            }
        }
        
        # Tag filters (+urgent, -COMPLETED)
        if ($token -match '^([+-])(.+)$') {
            $include = $matches[1] -eq '+'
            return @{
                Type = 'TagFilter'
                Tag = $matches[2]
                Include = $include
            }
        }
        
        # Regex filters (description~/work.*/)
        if ($token -match '^([a-zA-Z_]+[a-zA-Z0-9_]*)~(/.*/)$') {
            return @{
                Type = 'RegexFilter'
                Attribute = $matches[1]
                Pattern = $matches[2].Trim('/')
            }
        }
        
        # Virtual tags and simple values
        if ($token -in $this._virtualTags) {
            return @{ Type = 'VirtualTag'; Value = $token }
        }
        
        # Default to literal
        return @{ Type = 'Literal'; Value = $token }
    }
    
    hidden [array] ConvertToPostfix([array]$tokens) {
        $output = @()
        $operatorStack = [System.Collections.Generic.Stack[hashtable]]::new()
        
        foreach ($token in $tokens) {
            switch ($token.Type) {
                'AttributeFilter' { $output += $token }
                'TagFilter' { $output += $token }
                'RegexFilter' { $output += $token }
                'VirtualTag' { $output += $token }
                'Literal' { $output += $token }
                'LeftParen' {
                    $operatorStack.Push($token)
                }
                'RightParen' {
                    while ($operatorStack.Count -gt 0 -and $operatorStack.Peek().Type -ne 'LeftParen') {
                        $output += $operatorStack.Pop()
                    }
                    if ($operatorStack.Count -gt 0) {
                        $operatorStack.Pop()  # Remove left paren
                    }
                }
                'Operator' {
                    $currentPrec = $this._operatorPrecedence[$token.Value]
                    while ($operatorStack.Count -gt 0 -and
                           $operatorStack.Peek().Type -eq 'Operator' -and
                           $this._operatorPrecedence[$operatorStack.Peek().Value] -ge $currentPrec) {
                        $output += $operatorStack.Pop()
                    }
                    $operatorStack.Push($token)
                }
            }
        }
        
        while ($operatorStack.Count -gt 0) {
            $output += $operatorStack.Pop()
        }
        
        return $output
    }
    
    hidden [hashtable] BuildAST([array]$postfix) {
        $stack = [System.Collections.Generic.Stack[hashtable]]::new()
        
        foreach ($token in $postfix) {
            switch ($token.Type) {
                'Operator' {
                    if ($token.Value -eq 'not') {
                        $operand = $stack.Pop()
                        $stack.Push(@{
                            Type = 'UnaryOperation'
                            Operator = 'not'
                            Operand = $operand
                        })
                    } else {
                        $right = $stack.Pop()
                        $left = $stack.Pop()
                        $stack.Push(@{
                            Type = 'BinaryOperation'
                            Operator = $token.Value
                            Left = $left
                            Right = $right
                        })
                    }
                }
                default {
                    $stack.Push($token)
                }
            }
        }
        
        return $stack.Pop()
    }
    
    [bool] EvaluateFilter([hashtable]$ast, [Task]$task) {
        return $this.EvaluateNode($ast, $task)
    }
    
    hidden [bool] EvaluateNode([hashtable]$node, [Task]$task) {
        switch ($node.Type) {
            'BinaryOperation' {
                $leftResult = $this.EvaluateNode($node.Left, $task)
                $rightResult = $this.EvaluateNode($node.Right, $task)
                
                switch ($node.Operator) {
                    'and' { return $leftResult -and $rightResult }
                    'or' { return $leftResult -or $rightResult }
                }
            }
            'UnaryOperation' {
                $operandResult = $this.EvaluateNode($node.Operand, $task)
                return -not $operandResult
            }
            'AttributeFilter' {
                return $this.EvaluateAttributeFilter($node, $task)
            }
            'TagFilter' {
                $hasTag = $task.HasTag($node.Tag) -or ($node.Tag -in $task.GetVirtualTags())
                return $node.Include ? $hasTag : (-not $hasTag)
            }
            'RegexFilter' {
                return $this.EvaluateRegexFilter($node, $task)
            }
            'VirtualTag' {
                return $node.Value -in $task.GetVirtualTags()
            }
        }
        return $false
    }
    
    hidden [bool] EvaluateAttributeFilter([hashtable]$filter, [Task]$task) {
        $attribute = $filter.Attribute
        $value = $filter.Value
        $operator = $filter.Operator
        
        # Get task attribute value
        $taskValue = switch ($attribute) {
            'description' { $task.description }
            'project' { $task.project }
            'priority' { $task.priority }
            'status' { $task.status }
            'urgency' { $task.urgency }
            'due' { $task.due }
            'scheduled' { $task.scheduled }
            'entry' { $task.entry }
            'modified' { $task.modified }
            default {
                # Check UDAs
                $task.GetUDA($attribute)
            }
        }
        
        # Handle date attributes with date math
        if ($attribute -in @('due', 'scheduled', 'entry', 'modified', 'wait', 'until')) {
            return $this.EvaluateDateFilter($taskValue, $operator, $value)
        }
        
        # Handle numeric attributes
        if ($attribute -eq 'urgency') {
            return $this.EvaluateNumericFilter($taskValue, $operator, [double]$value)
        }
        
        # Handle string attributes
        return $this.EvaluateStringFilter($taskValue, $operator, $value)
    }
    
    hidden [bool] EvaluateDateFilter([nullable[datetime]]$taskDate, [string]$operator, [string]$value) {
        $compareDate = $this.ParseDateMath($value)
        if ($null -eq $compareDate) { return $false }
        if ($null -eq $taskDate) { return $operator -eq 'none' }
        
        switch ($operator) {
            'before' { return $taskDate -lt $compareDate }
            'after' { return $taskDate -gt $compareDate }
            'equals' { return $taskDate.Date -eq $compareDate.Date }
            'over' { return $taskDate -gt $compareDate }
            'under' { return $taskDate -lt $compareDate }
            'none' { return $null -eq $taskDate }
            default { return $taskDate.Date -eq $compareDate.Date }
        }
    }
    
    hidden [bool] EvaluateNumericFilter([double]$taskValue, [string]$operator, [double]$compareValue) {
        switch ($operator) {
            'over' { return $taskValue -gt $compareValue }
            'under' { return $taskValue -lt $compareValue }
            'equals' { return [Math]::Abs($taskValue - $compareValue) -lt 0.01 }
            default { return [Math]::Abs($taskValue - $compareValue) -lt 0.01 }
        }
    }
    
    hidden [bool] EvaluateStringFilter([string]$taskValue, [string]$operator, [string]$compareValue) {
        if ($null -eq $taskValue) { $taskValue = '' }
        
        switch ($operator) {
            'equals' { return $taskValue -eq $compareValue }
            'contains' { return $taskValue -like "*$compareValue*" }
            'startswith' { return $taskValue -like "$compareValue*" }
            'word' { return $taskValue -match "\b$compareValue\b" }
            'noword' { return $taskValue -notmatch "\b$compareValue\b" }
            default { return $taskValue -eq $compareValue }
        }
    }
    
    hidden [bool] EvaluateRegexFilter([hashtable]$filter, [Task]$task) {
        $attribute = $filter.Attribute
        $pattern = $filter.Pattern
        
        $taskValue = switch ($attribute) {
            'description' { $task.description }
            'project' { $task.project }
            default { $task.GetUDA($attribute) }
        }
        
        if ($null -eq $taskValue) { return $false }
        
        try {
            return $taskValue -match $pattern
        } catch {
            return $false
        }
    }
    
    [datetime] ParseDateMath([string]$expression) {
        if ([string]::IsNullOrWhiteSpace($expression)) {
            return [datetime]::Now
        }
        
        $expression = $expression.Trim().ToLower()
        
        # Handle direct abbreviations
        if ($this._dateAbbreviations.ContainsKey($expression)) {
            return $this._dateAbbreviations[$expression].Invoke()
        }
        
        # Handle date math (eom+1d, sow-2w, etc.)
        if ($expression -match '^(\w+)([+-])(\d+)([dwmy])$') {
            $baseExpr = $matches[1]
            $operation = $matches[2]
            $amount = [int]$matches[3]
            $unit = $matches[4]
            
            $baseDate = if ($this._dateAbbreviations.ContainsKey($baseExpr)) {
                $this._dateAbbreviations[$baseExpr].Invoke()
            } else {
                [datetime]::Now
            }
            
            $modifier = if ($operation -eq '+') { $amount } else { -$amount }
            
            switch ($unit) {
                'd' { return $baseDate.AddDays($modifier) }
                'w' { return $baseDate.AddDays($modifier * 7) }
                'm' { return $baseDate.AddMonths($modifier) }
                'y' { return $baseDate.AddYears($modifier) }
            }
        }
        
        # Try to parse as standard date
        try {
            return [datetime]::Parse($expression)
        } catch {
            return [datetime]::Now
        }
    }
    
    hidden [datetime] GetStartOfWeek([datetime]$date) {
        $daysFromSunday = [int]$date.DayOfWeek
        return $date.Date.AddDays(-$daysFromSunday)
    }
    
    hidden [datetime] GetEndOfWeek([datetime]$date) {
        return $this.GetStartOfWeek($date).AddDays(6)
    }
    
    hidden [datetime] GetEndOfMonth([datetime]$date) {
        return [datetime]::new($date.Year, $date.Month, [datetime]::DaysInMonth($date.Year, $date.Month))
    }
    
    [array] GetFilterSuggestions([string]$partialExpression, [int]$cursorPosition) {
        $suggestions = @()
        
        # Get the current word being typed
        $beforeCursor = $partialExpression.Substring(0, $cursorPosition)
        $lastSpace = $beforeCursor.LastIndexOf(' ')
        $currentWord = if ($lastSpace -ge 0) {
            $beforeCursor.Substring($lastSpace + 1)
        } else {
            $beforeCursor
        }
        
        # Suggest attributes
        $attributes = @('description', 'project', 'priority', 'status', 'urgency', 'due', 'scheduled', 'entry', 'modified')
        foreach ($attr in $attributes) {
            if ($attr.StartsWith($currentWord, 'CurrentCultureIgnoreCase')) {
                $suggestions += "$attr:"
            }
        }
        
        # Suggest operators
        $operators = @('and', 'or', 'not')
        foreach ($op in $operators) {
            if ($op.StartsWith($currentWord, 'CurrentCultureIgnoreCase')) {
                $suggestions += $op
            }
        }
        
        # Suggest virtual tags
        foreach ($vtag in $this._virtualTags) {
            if ($vtag.StartsWith($currentWord, 'CurrentCultureIgnoreCase')) {
                $suggestions += "+$vtag"
            }
        }
        
        # Suggest date abbreviations
        foreach ($dateAbbr in $this._dateAbbreviations.Keys) {
            if ($dateAbbr.StartsWith($currentWord, 'CurrentCultureIgnoreCase')) {
                $suggestions += $dateAbbr
            }
        }
        
        return $suggestions
    }
    
    [hashtable] ValidateFilterSyntax([string]$expression) {
        try {
            $parseResult = $this.ParseFilterExpression($expression)
            
            if ($parseResult.IsValid) {
                return @{
                    IsValid = $true
                    Message = 'Filter syntax is valid'
                    Suggestions = @()
                }
            } else {
                return @{
                    IsValid = $false
                    Message = $parseResult.Error
                    Suggestions = $this.GetFilterSuggestions($expression, $expression.Length)
                }
            }
        } catch {
            return @{
                IsValid = $false
                Message = "Parse error: $($_.Exception.Message)"
                Suggestions = @()
            }
        }
    }
}
```

## System 20: Dependency Visualization System

Complete dependency chain visualization and management system.

```powershell
class DependencyVisualizationSystem {
    hidden [hashtable] $_dependencyCache = @{}
    hidden [hashtable] $_dependencyGraph = @{}
    hidden [datetime] $_lastCacheUpdate = [datetime]::MinValue
    
    [void] UpdateDependencyCache([Task[]]$allTasks) {
        $this._dependencyCache.Clear()
        $this._dependencyGraph.Clear()
        
        # Build dependency mappings
        foreach ($task in $allTasks) {
            $this._dependencyGraph[$task.uuid] = @{
                Task = $task
                Dependencies = $task.depends
                Dependents = @()
                IsReady = $true
                CircularPath = @()
            }
        }
        
        # Build reverse dependency mapping (dependents)
        foreach ($taskId in $this._dependencyGraph.Keys) {
            $taskInfo = $this._dependencyGraph[$taskId]
            foreach ($depId in $taskInfo.Dependencies) {
                if ($this._dependencyGraph.ContainsKey($depId)) {
                    $this._dependencyGraph[$depId].Dependents += $taskId
                }
            }
        }
        
        # Calculate ready status and detect circular dependencies
        foreach ($taskId in $this._dependencyGraph.Keys) {
            $this.CalculateReadyStatus($taskId, @())
        }
        
        $this._lastCacheUpdate = [datetime]::Now
    }
    
    hidden [bool] CalculateReadyStatus([string]$taskId, [string[]]$visitedPath) {
        if ($taskId -in $visitedPath) {
            # Circular dependency detected
            $circularPath = $visitedPath + @($taskId)
            $startIndex = [Array]::IndexOf($circularPath, $taskId)
            $this._dependencyGraph[$taskId].CircularPath = $circularPath[$startIndex..($circularPath.Length-1)]
            $this._dependencyGraph[$taskId].IsReady = $false
            return $false
        }
        
        $taskInfo = $this._dependencyGraph[$taskId]
        if ($taskInfo.Dependencies.Count -eq 0) {
            $taskInfo.IsReady = $true
            return $true
        }
        
        $newPath = $visitedPath + @($taskId)
        $allDepsReady = $true
        
        foreach ($depId in $taskInfo.Dependencies) {
            if ($this._dependencyGraph.ContainsKey($depId)) {
                $depTask = $this._dependencyGraph[$depId].Task
                if ($depTask.status -notin @('completed', 'deleted')) {
                    $depReady = $this.CalculateReadyStatus($depId, $newPath)
                    if (-not $depReady) {
                        $allDepsReady = $false
                    }
                }
            }
        }
        
        $taskInfo.IsReady = $allDepsReady
        return $allDepsReady
    }
    
    [string] RenderDependencyIndicators([Task]$task, [int]$maxWidth = 20) {
        if ($task.depends.Count -eq 0 -and $this.GetDependents($task.uuid).Count -eq 0) {
            return ''
        }
        
        $sb = [System.Text.StringBuilder]::new()
        
        # Dependency status indicator
        if ($task.depends.Count -gt 0) {
            $taskInfo = $this._dependencyGraph[$task.uuid]
            if ($taskInfo -and $taskInfo.CircularPath.Count -gt 0) {
                $sb.Append('🔄')  # Circular dependency
            } elseif ($taskInfo -and -not $taskInfo.IsReady) {
                $sb.Append('🔒')  # Blocked
            } else {
                $sb.Append('⏳')  # Has dependencies
            }
        }
        
        # Dependent tasks indicator
        $dependents = $this.GetDependents($task.uuid)
        if ($dependents.Count -gt 0) {
            $sb.Append('📌')  # Blocks other tasks
        }
        
        $result = $sb.ToString()
        return $result.Length -le $maxWidth ? $result : $result.Substring(0, $maxWidth-1) + '…'
    }
    
    [string] RenderDependencyChain([Task]$task, [int]$maxDepth = 3) {
        $sb = [System.Text.StringBuilder]::new()
        
        # Show dependency chain
        if ($task.depends.Count -gt 0) {
            $sb.AppendLine('Dependencies:')
            $this.RenderDependencyBranch($task.uuid, 0, $maxDepth, @(), $sb, $true)
        }
        
        # Show dependent chain
        $dependents = $this.GetDependents($task.uuid)
        if ($dependents.Count -gt 0) {
            if ($sb.Length -gt 0) { $sb.AppendLine() }
            $sb.AppendLine('Blocks:')
            foreach ($depId in $dependents) {
                $this.RenderDependencyBranch($depId, 0, $maxDepth, @(), $sb, $false)
            }
        }
        
        return $sb.ToString()
    }
    
    hidden [void] RenderDependencyBranch([string]$taskId, [int]$depth, [int]$maxDepth, [string[]]$visited, [System.Text.StringBuilder]$sb, [bool]$showDependencies) {
        if ($depth -ge $maxDepth -or $taskId -in $visited) {
            return
        }
        
        $taskInfo = $this._dependencyGraph[$taskId]
        if (-not $taskInfo) { return }
        
        $task = $taskInfo.Task
        $indent = '  ' * $depth
        $statusIcon = switch ($task.status) {
            'completed' { '✓' }
            'deleted' { '✗' }
            'pending' { if ($taskInfo.IsReady) { '○' } else { '◐' } }
            default { '?' }
        }
        
        $urgencyColor = $task.GetUrgencyColor()
        $description = $task.description.Length -gt 40 ? $task.description.Substring(0, 37) + '...' : $task.description
        
        $sb.AppendLine("$indent$statusIcon [$($task.id)] $description")
        
        $newVisited = $visited + @($taskId)
        
        if ($showDependencies) {
            foreach ($depId in $taskInfo.Dependencies) {
                $this.RenderDependencyBranch($depId, $depth + 1, $maxDepth, $newVisited, $sb, $true)
            }
        } else {
            foreach ($depId in $taskInfo.Dependents) {
                $this.RenderDependencyBranch($depId, $depth + 1, $maxDepth, $newVisited, $sb, $false)
            }
        }
    }
    
    [string[]] GetDependents([string]$taskId) {
        if ($this._dependencyGraph.ContainsKey($taskId)) {
            return $this._dependencyGraph[$taskId].Dependents
        }
        return @()
    }
    
    [bool] IsTaskReady([string]$taskId) {
        if ($this._dependencyGraph.ContainsKey($taskId)) {
            return $this._dependencyGraph[$taskId].IsReady
        }
        return $true
    }
    
    [bool] HasCircularDependency([string]$taskId) {
        if ($this._dependencyGraph.ContainsKey($taskId)) {
            return $this._dependencyGraph[$taskId].CircularPath.Count -gt 0
        }
        return $false
    }
    
    [string[]] GetCircularPath([string]$taskId) {
        if ($this._dependencyGraph.ContainsKey($taskId)) {
            return $this._dependencyGraph[$taskId].CircularPath
        }
        return @()
    }
    
    [Task[]] GetReadyTasks([Task[]]$allTasks) {
        $readyTasks = @()
        foreach ($task in $allTasks) {
            if ($task.status -eq 'pending' -and $this.IsTaskReady($task.uuid)) {
                $readyTasks += $task
            }
        }
        return $readyTasks
    }
    
    [Task[]] GetBlockedTasks([Task[]]$allTasks) {
        $blockedTasks = @()
        foreach ($task in $allTasks) {
            if ($task.status -eq 'pending' -and -not $this.IsTaskReady($task.uuid)) {
                $blockedTasks += $task
            }
        }
        return $blockedTasks
    }
    
    [hashtable] GetDependencyStats([Task[]]$allTasks) {
        $stats = @{
            TotalTasks = $allTasks.Count
            TasksWithDependencies = 0
            TasksWithDependents = 0
            ReadyTasks = 0
            BlockedTasks = 0
            CircularDependencies = 0
            OrphanedDependencies = 0
        }
        
        foreach ($task in $allTasks) {
            if ($task.depends.Count -gt 0) {
                $stats.TasksWithDependencies++
            }
            
            $dependents = $this.GetDependents($task.uuid)
            if ($dependents.Count -gt 0) {
                $stats.TasksWithDependents++
            }
            
            if ($task.status -eq 'pending') {
                if ($this.IsTaskReady($task.uuid)) {
                    $stats.ReadyTasks++
                } else {
                    $stats.BlockedTasks++
                }
            }
            
            if ($this.HasCircularDependency($task.uuid)) {
                $stats.CircularDependencies++
            }
            
            # Check for orphaned dependencies
            foreach ($depId in $task.depends) {
                if (-not $this._dependencyGraph.ContainsKey($depId)) {
                    $stats.OrphanedDependencies++
                }
            }
        }
        
        return $stats
    }
    
    [string] RenderDependencyGraph([Task[]]$allTasks, [int]$maxWidth = 80) {
        $sb = [System.Text.StringBuilder]::new()
        $stats = $this.GetDependencyStats($allTasks)
        
        $sb.AppendLine('Dependency Overview:')
        $sb.AppendLine("  Ready Tasks: $($stats.ReadyTasks)")
        $sb.AppendLine("  Blocked Tasks: $($stats.BlockedTasks)")
        if ($stats.CircularDependencies -gt 0) {
            $sb.AppendLine("  ⚠️ Circular Dependencies: $($stats.CircularDependencies)")
        }
        if ($stats.OrphanedDependencies -gt 0) {
            $sb.AppendLine("  ⚠️ Orphaned Dependencies: $($stats.OrphanedDependencies)")
        }
        
        # Show circular dependencies if any
        if ($stats.CircularDependencies -gt 0) {
            $sb.AppendLine()
            $sb.AppendLine('Circular Dependencies:')
            foreach ($task in $allTasks) {
                if ($this.HasCircularDependency($task.uuid)) {
                    $path = $this.GetCircularPath($task.uuid)
                    $pathStr = ($path | ForEach-Object {
                        $pathTask = $allTasks | Where-Object { $_.uuid -eq $_ } | Select-Object -First 1
                        $pathTask ? "[$($pathTask.id)]" : '[?]'
                    }) -join ' -> '
                    $sb.AppendLine("  $pathStr")
                }
            }
        }
        
        return $sb.ToString()
    }
    
    [bool] NeedsCacheUpdate() {
        return ([datetime]::Now - $this._lastCacheUpdate).TotalMinutes -gt 5
    }
}
```

## System 21: Recurring Task Management System

Complete recurring task management with template/child distinction and next occurrence generation.

```powershell
class RecurringTaskManager {
    hidden [hashtable] $_recurringCache = @{}
    hidden [hashtable] $_patternParsers = @{}
    hidden [datetime] $_lastProcessingTime = [datetime]::MinValue
    hidden [int] $_futureHorizonDays = 90  # Generate recurring tasks 90 days ahead
    
    RecurringTaskManager() {
        $this.InitializePatternParsers()
    }
    
    hidden [void] InitializePatternParsers() {
        $this._patternParsers = @{
            # Standard patterns
            'daily' = @{ Unit = 'days'; Amount = 1 }
            'weekly' = @{ Unit = 'weeks'; Amount = 1 }
            'monthly' = @{ Unit = 'months'; Amount = 1 }
            'quarterly' = @{ Unit = 'months'; Amount = 3 }
            'yearly' = @{ Unit = 'years'; Amount = 1 }
            'annually' = @{ Unit = 'years'; Amount = 1 }
            'biweekly' = @{ Unit = 'weeks'; Amount = 2 }
            'semiannual' = @{ Unit = 'months'; Amount = 6 }
            
            # Work patterns
            'weekdays' = @{ Unit = 'workdays'; Amount = 1 }
            'business' = @{ Unit = 'workdays'; Amount = 1 }
        }
    }
    
    [hashtable] ParseRecurrencePattern([string]$pattern) {
        if ([string]::IsNullOrWhiteSpace($pattern)) {
            return @{ IsValid = $false; Error = 'Empty recurrence pattern' }
        }
        
        $pattern = $pattern.Trim().ToLower()
        
        # Check for standard patterns
        if ($this._patternParsers.ContainsKey($pattern)) {
            $parser = $this._patternParsers[$pattern]
            return @{
                IsValid = $true
                Pattern = $pattern
                Unit = $parser.Unit
                Amount = $parser.Amount
                Type = 'Standard'
            }
        }
        
        # Parse numeric patterns (e.g., 3d, 2w, 1m, 6y)
        if ($pattern -match '^(\d+)([dwmy])$') {
            $amount = [int]$matches[1]
            $unitChar = $matches[2]
            
            $unit = switch ($unitChar) {
                'd' { 'days' }
                'w' { 'weeks' }
                'm' { 'months' }
                'y' { 'years' }
            }
            
            return @{
                IsValid = $true
                Pattern = $pattern
                Unit = $unit
                Amount = $amount
                Type = 'Numeric'
            }
        }
        
        # Parse complex patterns (e.g., 2nd, 3rd, last)
        if ($pattern -match '^(1st|2nd|3rd|\d+th|last)\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)$') {
            return @{
                IsValid = $true
                Pattern = $pattern
                Type = 'MonthlyWeekday'
                Ordinal = $matches[1]
                Weekday = $matches[2]
            }
        }
        
        return @{
            IsValid = $false
            Error = "Unrecognized recurrence pattern: $pattern"
        }
    }
    
    [nullable[datetime]] CalculateNextOccurrence([Task]$templateTask, [nullable[datetime]]$fromDate = $null) {
        $baseDate = $fromDate ?? [datetime]::Now
        $parseResult = $this.ParseRecurrencePattern($templateTask.recur)
        
        if (-not $parseResult.IsValid) {
            return $null
        }
        
        # Use due date as reference if available, otherwise use entry date
        $referenceDate = $templateTask.due ?? $templateTask.entry ?? $baseDate
        
        switch ($parseResult.Type) {
            'Standard' {
                return $this.CalculateStandardRecurrence($referenceDate, $parseResult.Unit, $parseResult.Amount)
            }
            'Numeric' {
                return $this.CalculateStandardRecurrence($referenceDate, $parseResult.Unit, $parseResult.Amount)
            }
            'MonthlyWeekday' {
                return $this.CalculateMonthlyWeekdayRecurrence($referenceDate, $parseResult.Ordinal, $parseResult.Weekday)
            }
        }
        
        return $null
    }
    
    hidden [datetime] CalculateStandardRecurrence([datetime]$referenceDate, [string]$unit, [int]$amount) {
        switch ($unit) {
            'days' {
                return $referenceDate.AddDays($amount)
            }
            'weeks' {
                return $referenceDate.AddDays($amount * 7)
            }
            'months' {
                return $referenceDate.AddMonths($amount)
            }
            'years' {
                return $referenceDate.AddYears($amount)
            }
            'workdays' {
                $nextDate = $referenceDate
                $daysAdded = 0
                while ($daysAdded -lt $amount) {
                    $nextDate = $nextDate.AddDays(1)
                    if ($nextDate.DayOfWeek -notin @([DayOfWeek]::Saturday, [DayOfWeek]::Sunday)) {
                        $daysAdded++
                    }
                }
                return $nextDate
            }
        }
        return $referenceDate.AddDays(1)
    }
    
    hidden [datetime] CalculateMonthlyWeekdayRecurrence([datetime]$referenceDate, [string]$ordinal, [string]$weekday) {
        $targetWeekday = switch ($weekday) {
            'monday' { [DayOfWeek]::Monday }
            'tuesday' { [DayOfWeek]::Tuesday }
            'wednesday' { [DayOfWeek]::Wednesday }
            'thursday' { [DayOfWeek]::Thursday }
            'friday' { [DayOfWeek]::Friday }
            'saturday' { [DayOfWeek]::Saturday }
            'sunday' { [DayOfWeek]::Sunday }
        }
        
        $nextMonth = $referenceDate.AddMonths(1)
        $firstDayOfMonth = [datetime]::new($nextMonth.Year, $nextMonth.Month, 1)
        
        if ($ordinal -eq 'last') {
            # Find last occurrence of weekday in the month
            $lastDayOfMonth = $firstDayOfMonth.AddMonths(1).AddDays(-1)
            $candidateDate = $lastDayOfMonth
            while ($candidateDate.DayOfWeek -ne $targetWeekday) {
                $candidateDate = $candidateDate.AddDays(-1)
            }
            return $candidateDate
        } else {
            # Find nth occurrence of weekday in the month
            $ordinalNum = switch ($ordinal) {
                '1st' { 1 }
                '2nd' { 2 }
                '3rd' { 3 }
                '4th' { 4 }
                default { [int]$ordinal.Replace('th', '') }
            }
            
            $candidateDate = $firstDayOfMonth
            $occurrenceCount = 0
            
            while ($candidateDate.Month -eq $firstDayOfMonth.Month) {
                if ($candidateDate.DayOfWeek -eq $targetWeekday) {
                    $occurrenceCount++
                    if ($occurrenceCount -eq $ordinalNum) {
                        return $candidateDate
                    }
                }
                $candidateDate = $candidateDate.AddDays(1)
            }
        }
        
        # Fallback: return first day of next month
        return $firstDayOfMonth
    }
    
    [Task] CreateChildTask([Task]$templateTask, [datetime]$dueDate) {
        $childTask = [Task]::new(@{
            uuid = [guid]::NewGuid().ToString()
            description = $templateTask.description
            project = $templateTask.project
            priority = $templateTask.priority
            status = 'pending'
            tags = $templateTask.tags
            entry = [datetime]::Now
            due = $dueDate
            parent = $templateTask.uuid
            recur = ''  # Child tasks don't recurr themselves
        })
        
        # Copy UDAs from template
        foreach ($udaKey in $templateTask.uda.Keys) {
            $childTask.SetUDA($udaKey, $templateTask.uda[$udaKey])
        }
        
        # Calculate scheduled date if template has one
        if ($null -ne $templateTask.scheduled) {
            $scheduleDiff = $templateTask.scheduled - $templateTask.due
            $childTask.scheduled = $dueDate.Add($scheduleDiff)
        }
        
        return $childTask
    }
    
    [array] ProcessRecurringTasks([Task[]]$allTasks) {
        $now = [datetime]::Now
        $horizon = $now.AddDays($this._futureHorizonDays)
        $newTasks = @()
        
        # Find recurring templates that need processing
        $recurringTemplates = $allTasks | Where-Object { 
            $_.IsRecurringTemplate() -and 
            $_.status -eq 'pending' -and
            ($null -eq $_.until -or $_.until -gt $now)
        }
        
        foreach ($template in $recurringTemplates) {
            # Get existing child tasks for this template
            $existingChildren = $allTasks | Where-Object { $_.parent -eq $template.uuid }
            
            # Find the latest child task due date
            $lastChildDue = if ($existingChildren.Count -gt 0) {
                ($existingChildren | Where-Object { $null -ne $_.due } | Sort-Object due -Descending | Select-Object -First 1).due
            } else {
                $template.due
            }
            
            # Generate future occurrences up to horizon
            $nextDue = $lastChildDue
            while ($nextDue -lt $horizon) {
                $nextDue = $this.CalculateNextOccurrence($template, $nextDue)
                if ($null -eq $nextDue) { break }
                
                # Check if we already have a task for this date
                $existingChild = $existingChildren | Where-Object { 
                    $null -ne $_.due -and $_.due.Date -eq $nextDue.Date 
                }
                
                if (-not $existingChild) {
                    $newTask = $this.CreateChildTask($template, $nextDue)
                    $newTasks += $newTask
                }
                
                # Safety check to prevent infinite loops
                if ($newTasks.Count -gt 1000) {
                    break
                }
            }
        }
        
        $this._lastProcessingTime = $now
        return $newTasks
    }
    
    [string] RenderRecurringTaskInfo([Task]$task, [Task[]]$allTasks) {
        $sb = [System.Text.StringBuilder]::new()
        
        if ($task.IsRecurringTemplate()) {
            $sb.AppendLine('🔄 Recurring Template')
            $sb.AppendLine("Pattern: $($task.recur)")
            
            $parseResult = $this.ParseRecurrencePattern($task.recur)
            if ($parseResult.IsValid) {
                $sb.AppendLine("Type: $($parseResult.Type)")
                if ($parseResult.Unit) {
                    $sb.AppendLine("Frequency: Every $($parseResult.Amount) $($parseResult.Unit)")
                }
            }
            
            if ($null -ne $task.until) {
                $sb.AppendLine("Until: $($task.until.ToString('yyyy-MM-dd'))")
            }
            
            # Show child tasks
            $children = $allTasks | Where-Object { $_.parent -eq $task.uuid } | Sort-Object due
            if ($children.Count -gt 0) {
                $sb.AppendLine()
                $sb.AppendLine("Generated Tasks:")
                foreach ($child in $children | Select-Object -First 5) {
                    $statusIcon = switch ($child.status) {
                        'completed' { '✓' }
                        'deleted' { '✗' }
                        'pending' { '○' }
                        default { '?' }
                    }
                    $dueStr = $null -ne $child.due ? $child.due.ToString('MM/dd') : 'No due'
                    $sb.AppendLine("  $statusIcon [$($child.id)] $dueStr")
                }
                
                if ($children.Count -gt 5) {
                    $sb.AppendLine("  ... and $($children.Count - 5) more")
                }
            }
            
        } elseif ($task.IsRecurringChild()) {
            $sb.AppendLine('🔗 Recurring Task')
            
            # Find parent template
            $parent = $allTasks | Where-Object { $_.uuid -eq $task.parent } | Select-Object -First 1
            if ($parent) {
                $sb.AppendLine("Template: [$($parent.id)] $($parent.description)")
                $sb.AppendLine("Pattern: $($parent.recur)")
            }
            
            # Show sibling tasks
            $siblings = $allTasks | Where-Object { $_.parent -eq $task.parent -and $_.uuid -ne $task.uuid } | Sort-Object due
            if ($siblings.Count -gt 0) {
                $sb.AppendLine()
                $sb.AppendLine('Related Occurrences:')
                
                # Show previous and next few siblings
                $currentIndex = [Array]::IndexOf(($siblings + @($task) | Sort-Object due).uuid, $task.uuid)
                $contextStart = [Math]::Max(0, $currentIndex - 2)
                $contextEnd = [Math]::Min($siblings.Count + 1, $currentIndex + 3)
                
                $contextSiblings = ($siblings + @($task) | Sort-Object due)[$contextStart..($contextEnd-1)]
                
                foreach ($sibling in $contextSiblings) {
                    $statusIcon = switch ($sibling.status) {
                        'completed' { '✓' }
                        'deleted' { '✗' }
                        'pending' { '○' }
                        default { '?' }
                    }
                    $current = if ($sibling.uuid -eq $task.uuid) { ' ← Current' } else { '' }
                    $dueStr = $null -ne $sibling.due ? $sibling.due.ToString('MM/dd') : 'No due'
                    $sb.AppendLine("  $statusIcon [$($sibling.id)] $dueStr$current")
                }
            }
        }
        
        return $sb.ToString()
    }
    
    [string] RenderRecurringSummary([Task[]]$allTasks) {
        $templates = $allTasks | Where-Object { $_.IsRecurringTemplate() -and $_.status -eq 'pending' }
        $children = $allTasks | Where-Object { $_.IsRecurringChild() }
        
        $sb = [System.Text.StringBuilder]::new()
        $sb.AppendLine('Recurring Tasks Summary:')
        $sb.AppendLine("  Active Templates: $($templates.Count)")
        $sb.AppendLine("  Generated Tasks: $($children.Count)")
        
        if ($templates.Count -gt 0) {
            $sb.AppendLine()
            $sb.AppendLine('Active Recurring Templates:')
            foreach ($template in $templates) {
                $childCount = ($children | Where-Object { $_.parent -eq $template.uuid }).Count
                $nextDue = $this.CalculateNextOccurrence($template)
                $nextDueStr = $null -ne $nextDue ? $nextDue.ToString('MM/dd') : 'N/A'
                
                $sb.AppendLine("  [$($template.id)] $($template.description)")
                $sb.AppendLine("    Pattern: $($template.recur) | Children: $childCount | Next: $nextDueStr")
            }
        }
        
        # Show overdue recurring tasks
        $overdueChildren = $children | Where-Object { 
            $_.status -eq 'pending' -and 
            $null -ne $_.due -and 
            $_.due -lt [datetime]::Now.Date 
        }
        
        if ($overdueChildren.Count -gt 0) {
            $sb.AppendLine()
            $sb.AppendLine("⚠️ Overdue Recurring Tasks: $($overdueChildren.Count)")
            foreach ($overdueTask in $overdueChildren | Sort-Object due | Select-Object -First 5) {
                $daysOverdue = ([datetime]::Now.Date - $overdueTask.due.Date).Days
                $sb.AppendLine("  [$($overdueTask.id)] $($overdueTask.description) ($daysOverdue days overdue)")
            }
            if ($overdueChildren.Count -gt 5) {
                $sb.AppendLine("  ... and $($overdueChildren.Count - 5) more")
            }
        }
        
        return $sb.ToString()
    }
    
    [hashtable] ValidateRecurringTask([Task]$task) {
        $issues = @()
        
        if ($task.IsRecurringTemplate()) {
            $parseResult = $this.ParseRecurrencePattern($task.recur)
            if (-not $parseResult.IsValid) {
                $issues += "Invalid recurrence pattern: $($parseResult.Error)"
            }
            
            if ($null -eq $task.due) {
                $issues += 'Recurring template should have a due date'
            }
            
            if ($null -ne $task.until -and $null -ne $task.due -and $task.until -lt $task.due) {
                $issues += 'Until date is before due date'
            }
        }
        
        if ($task.IsRecurringChild()) {
            if ([string]::IsNullOrEmpty($task.parent)) {
                $issues += 'Recurring child task missing parent reference'
            }
            
            if (-not [string]::IsNullOrEmpty($task.recur)) {
                $issues += 'Recurring child should not have recur pattern'
            }
        }
        
        return @{
            IsValid = $issues.Count -eq 0
            Issues = $issues
        }
    }
    
    [bool] ShouldProcessRecurring() {
        return ([datetime]::Now - $this._lastProcessingTime).TotalHours -gt 1
    }
}
```

## System 22: Project Hierarchy Visualization System

Complete project hierarchy tree navigation and task count display.

```powershell
class ProjectHierarchyManager {
    hidden [hashtable] $_projectTree = @{}
    hidden [hashtable] $_projectStats = @{}
    hidden [datetime] $_lastUpdate = [datetime]::MinValue
    hidden [string] $_selectedProjectPath = ''
    
    [void] BuildProjectHierarchy([Task[]]$allTasks) {
        $this._projectTree = @{
            '' = @{  # Root level for tasks without projects
                Name = '(No Project)'
                FullPath = ''
                Level = 0
                Children = @{}
                Tasks = @()
                IsExpanded = $true
            }
        }
        $this._projectStats = @{}
        
        # First pass: collect all project paths and build tree structure
        $allProjects = $allTasks | Where-Object { -not [string]::IsNullOrEmpty($_.project) } | 
                       ForEach-Object { $_.project } | Sort-Object -Unique
        
        foreach ($projectPath in $allProjects) {
            $this.AddProjectToTree($projectPath)
        }
        
        # Second pass: assign tasks to their projects and calculate stats
        foreach ($task in $allTasks) {
            $projectPath = $task.project ?? ''
            
            # Add task to the appropriate project node
            if (-not $this._projectTree.ContainsKey($projectPath)) {
                $this.AddProjectToTree($projectPath)
            }
            
            $this._projectTree[$projectPath].Tasks += $task
            
            # Update parent projects' task counts
            $currentPath = $projectPath
            while ($true) {
                if (-not $this._projectStats.ContainsKey($currentPath)) {
                    $this._projectStats[$currentPath] = @{
                        TotalTasks = 0
                        PendingTasks = 0
                        CompletedTasks = 0
                        OverdueTasks = 0
                        UrgentTasks = 0
                    }
                }
                
                $stats = $this._projectStats[$currentPath]
                $stats.TotalTasks++
                
                switch ($task.status) {
                    'pending' { $stats.PendingTasks++ }
                    'completed' { $stats.CompletedTasks++ }
                }
                
                if ($null -ne $task.due -and $task.due -lt [datetime]::Now -and $task.status -eq 'pending') {
                    $stats.OverdueTasks++
                }
                
                if ($task.urgency -ge 10.0) {
                    $stats.UrgentTasks++
                }
                
                # Move to parent project
                if ([string]::IsNullOrEmpty($currentPath)) { break }
                $lastDot = $currentPath.LastIndexOf('.')
                $currentPath = if ($lastDot -ge 0) { $currentPath.Substring(0, $lastDot) } else { '' }
            }
        }
        
        $this._lastUpdate = [datetime]::Now
    }
    
    hidden [void] AddProjectToTree([string]$projectPath) {
        if ([string]::IsNullOrEmpty($projectPath)) { return }
        if ($this._projectTree.ContainsKey($projectPath)) { return }
        
        $pathParts = $projectPath -split '\.'
        $currentPath = ''
        
        for ($i = 0; $i -lt $pathParts.Length; $i++) {
            $part = $pathParts[$i]
            $parentPath = $currentPath
            $currentPath = if ($i -eq 0) { $part } else { "$currentPath.$part" }
            
            if (-not $this._projectTree.ContainsKey($currentPath)) {
                $this._projectTree[$currentPath] = @{
                    Name = $part
                    FullPath = $currentPath
                    Level = $i
                    Children = @{}
                    Tasks = @()
                    IsExpanded = $i -lt 2  # Auto-expand first 2 levels
                }
                
                # Link to parent
                if ($this._projectTree.ContainsKey($parentPath)) {
                    $this._projectTree[$parentPath].Children[$part] = $currentPath
                }
            }
        }
    }
    
    [string] RenderProjectTree([int]$maxWidth = 60) {
        $sb = [System.Text.StringBuilder]::new()
        
        $sb.AppendLine('Project Hierarchy:')
        $sb.AppendLine('=' * $maxWidth)
        
        # Render root level projects and no-project tasks
        $rootProjects = $this._projectTree.Keys | Where-Object { 
            -not [string]::IsNullOrEmpty($_) -and -not $_.Contains('.') 
        } | Sort-Object
        
        # Show no-project tasks first if any exist
        $noProjectStats = $this._projectStats[''] ?? @{ TotalTasks = 0; PendingTasks = 0 }
        if ($noProjectStats.TotalTasks -gt 0) {
            $sb.AppendLine($this.RenderProjectLine('', 0, $maxWidth))
        }
        
        # Render project tree
        foreach ($rootProject in $rootProjects) {
            $this.RenderProjectBranch($rootProject, 0, $sb, $maxWidth)
        }
        
        return $sb.ToString()
    }
    
    hidden [void] RenderProjectBranch([string]$projectPath, [int]$level, [System.Text.StringBuilder]$sb, [int]$maxWidth) {
        $projectInfo = $this._projectTree[$projectPath]
        if (-not $projectInfo) { return }
        
        # Render current project
        $sb.AppendLine($this.RenderProjectLine($projectPath, $level, $maxWidth))
        
        # Render children if expanded
        if ($projectInfo.IsExpanded -and $projectInfo.Children.Count -gt 0) {
            $childPaths = $projectInfo.Children.Values | Sort-Object
            foreach ($childPath in $childPaths) {
                $this.RenderProjectBranch($childPath, $level + 1, $sb, $maxWidth)
            }
        }
    }
    
    hidden [string] RenderProjectLine([string]$projectPath, [int]$level, [int]$maxWidth) {
        $projectInfo = $this._projectTree[$projectPath]
        $stats = $this._projectStats[$projectPath] ?? @{ TotalTasks = 0; PendingTasks = 0; OverdueTasks = 0; UrgentTasks = 0 }
        
        $indent = '  ' * $level
        $expandIcon = if ($projectInfo.Children.Count -gt 0) {
            if ($projectInfo.IsExpanded) { '▼' } else { '▶' }
        } else { ' ' }
        
        $name = if ([string]::IsNullOrEmpty($projectPath)) { '(No Project)' } else { $projectInfo.Name }
        
        # Build status indicators
        $indicators = @()
        if ($stats.PendingTasks -gt 0) { $indicators += "$($stats.PendingTasks)○" }
        if ($stats.OverdueTasks -gt 0) { $indicators += "$($stats.OverdueTasks)⚠" }
        if ($stats.UrgentTasks -gt 0) { $indicators += "$($stats.UrgentTasks)!" }
        
        $indicatorStr = if ($indicators.Count -gt 0) { " [$($indicators -join ' ')]" } else { '' }
        
        # Selection indicator
        $selected = if ($projectPath -eq $this._selectedProjectPath) { ' ◀' } else { '' }
        
        $projectLine = "$indent$expandIcon $name$indicatorStr$selected"
        
        # Truncate if too long
        if ($projectLine.Length -gt $maxWidth) {
            $projectLine = $projectLine.Substring(0, $maxWidth - 3) + '...'
        }
        
        return $projectLine
    }
    
    [string] RenderProjectDetails([string]$projectPath) {
        if (-not $this._projectTree.ContainsKey($projectPath)) {
            return "Project '$projectPath' not found"
        }
        
        $projectInfo = $this._projectTree[$projectPath]
        $stats = $this._projectStats[$projectPath] ?? @{}
        
        $sb = [System.Text.StringBuilder]::new()
        
        $displayName = if ([string]::IsNullOrEmpty($projectPath)) { '(No Project)' } else { $projectPath }
        $sb.AppendLine("Project: $displayName")
        $sb.AppendLine('=' * 50)
        
        # Statistics
        if ($stats.Count -gt 0) {
            $sb.AppendLine('Statistics:')
            $sb.AppendLine("  Total Tasks: $($stats.TotalTasks)")
            $sb.AppendLine("  Pending: $($stats.PendingTasks)")
            $sb.AppendLine("  Completed: $($stats.CompletedTasks)")
            if ($stats.OverdueTasks -gt 0) {
                $sb.AppendLine("  ⚠️ Overdue: $($stats.OverdueTasks)")
            }
            if ($stats.UrgentTasks -gt 0) {
                $sb.AppendLine("  🔥 Urgent: $($stats.UrgentTasks)")
            }
        }
        
        # Subprojects
        if ($projectInfo.Children.Count -gt 0) {
            $sb.AppendLine()
            $sb.AppendLine('Subprojects:')
            foreach ($childName in $projectInfo.Children.Keys | Sort-Object) {
                $childPath = $projectInfo.Children[$childName]
                $childStats = $this._projectStats[$childPath] ?? @{ TotalTasks = 0; PendingTasks = 0 }
                $sb.AppendLine("  $childName ($($childStats.PendingTasks) pending, $($childStats.TotalTasks) total)")
            }
        }
        
        # Recent tasks
        if ($projectInfo.Tasks.Count -gt 0) {
            $sb.AppendLine()
            $sb.AppendLine('Recent Tasks:')
            $recentTasks = $projectInfo.Tasks | Sort-Object { $_.entry ?? [datetime]::MinValue } -Descending | Select-Object -First 10
            foreach ($task in $recentTasks) {
                $statusIcon = switch ($task.status) {
                    'completed' { '✓' }
                    'deleted' { '✗' }
                    'pending' { '○' }
                    default { '?' }
                }
                $urgencyIcon = if ($task.urgency -ge 10.0) { ' 🔥' } else { '' }
                $overdueIcon = if ($null -ne $task.due -and $task.due -lt [datetime]::Now -and $task.status -eq 'pending') { ' ⚠️' } else { '' }
                
                $description = $task.description.Length -gt 40 ? $task.description.Substring(0, 37) + '...' : $task.description
                $sb.AppendLine("  $statusIcon [$($task.id)] $description$urgencyIcon$overdueIcon")
            }
            
            if ($projectInfo.Tasks.Count -gt 10) {
                $sb.AppendLine("  ... and $($projectInfo.Tasks.Count - 10) more tasks")
            }
        }
        
        return $sb.ToString()
    }
    
    [void] ToggleProjectExpansion([string]$projectPath) {
        if ($this._projectTree.ContainsKey($projectPath)) {
            $this._projectTree[$projectPath].IsExpanded = -not $this._projectTree[$projectPath].IsExpanded
        }
    }
    
    [void] SelectProject([string]$projectPath) {
        $this._selectedProjectPath = $projectPath
    }
    
    [string] GetSelectedProject() {
        return $this._selectedProjectPath
    }
    
    [string[]] GetProjectPaths() {
        return $this._projectTree.Keys | Where-Object { -not [string]::IsNullOrEmpty($_) } | Sort-Object
    }
    
    [Task[]] GetProjectTasks([string]$projectPath, [bool]$includeSubprojects = $false) {
        if (-not $this._projectTree.ContainsKey($projectPath)) {
            return @()
        }
        
        $tasks = $this._projectTree[$projectPath].Tasks
        
        if ($includeSubprojects) {
            $allSubprojectTasks = @()
            foreach ($childPath in $this._projectTree[$projectPath].Children.Values) {
                $allSubprojectTasks += $this.GetProjectTasks($childPath, $true)
            }
            $tasks += $allSubprojectTasks
        }
        
        return $tasks
    }
    
    [string[]] GetProjectSuggestions([string]$partialPath) {
        $suggestions = @()
        $searchTerm = $partialPath.ToLower()
        
        foreach ($projectPath in $this.GetProjectPaths()) {
            if ($projectPath.ToLower().Contains($searchTerm)) {
                $suggestions += $projectPath
            }
            
            # Also match on project name parts
            $projectName = ($projectPath -split '\.')[-1]
            if ($projectName.ToLower().StartsWith($searchTerm)) {
                $suggestions += $projectPath
            }
        }
        
        return $suggestions | Sort-Object -Unique | Select-Object -First 10
    }
    
    [hashtable] GetProjectStatistics() {
        $totalProjects = ($this._projectTree.Keys | Where-Object { -not [string]::IsNullOrEmpty($_) }).Count
        $rootProjects = ($this._projectTree.Keys | Where-Object { -not [string]::IsNullOrEmpty($_) -and -not $_.Contains('.') }).Count
        
        $allStats = $this._projectStats.Values
        $totalTasks = ($allStats | Measure-Object -Property TotalTasks -Sum).Sum
        $pendingTasks = ($allStats | Measure-Object -Property PendingTasks -Sum).Sum
        $overdueTasks = ($allStats | Measure-Object -Property OverdueTasks -Sum).Sum
        
        # Find most active project
        $mostActiveProject = $this._projectStats.GetEnumerator() | 
                           Where-Object { -not [string]::IsNullOrEmpty($_.Key) } |
                           Sort-Object { $_.Value.PendingTasks } -Descending | 
                           Select-Object -First 1
        
        return @{
            TotalProjects = $totalProjects
            RootProjects = $rootProjects
            TotalTasks = $totalTasks
            PendingTasks = $pendingTasks
            OverdueTasks = $overdueTasks
            MostActiveProject = if ($mostActiveProject) { $mostActiveProject.Key } else { '' }
            MostActiveTasks = if ($mostActiveProject) { $mostActiveProject.Value.PendingTasks } else { 0 }
        }
    }
    
    [bool] NeedsUpdate() {
        return ([datetime]::Now - $this._lastUpdate).TotalMinutes -gt 15
    }
}
```

## System 23: Annotation Management Interface

Complete multi-line annotation display and editing interface.

```powershell
class AnnotationManager {
    hidden [hashtable] $_annotationCache = @{}
    hidden [hashtable] $_editingState = @{}
    
    [string] RenderAnnotations([Task]$task, [int]$maxWidth = 80, [bool]$showTimestamps = $true) {
        if ($task.annotations.Count -eq 0) {
            return ''
        }
        
        $sb = [System.Text.StringBuilder]::new()
        $sb.AppendLine('Annotations:')
        $sb.AppendLine('─' * $maxWidth)
        
        # Sort annotations by timestamp
        $sortedAnnotations = $task.GetAnnotationsSorted()
        
        for ($i = 0; $i -lt $sortedAnnotations.Count; $i++) {
            $annotation = $sortedAnnotations[$i]
            $annotationIndex = $i + 1
            
            # Format timestamp
            if ($showTimestamps -and $null -ne $annotation.entry) {
                $timestamp = $annotation.entry.ToString('yyyy-MM-dd HH:mm')
                $sb.AppendLine("[$annotationIndex] $timestamp")
            } else {
                $sb.AppendLine("[$annotationIndex]")
            }
            
            # Word-wrap annotation text
            $wrappedText = $this.WrapText($annotation.description, $maxWidth - 4)
            foreach ($line in $wrappedText) {
                $sb.AppendLine("    $line")
            }
            
            # Add separator between annotations (except for last)
            if ($i -lt $sortedAnnotations.Count - 1) {
                $sb.AppendLine()
            }
        }
        
        return $sb.ToString()
    }
    
    [string] RenderAnnotationSummary([Task]$task, [int]$maxLength = 50) {
        if ($task.annotations.Count -eq 0) {
            return ''
        }
        
        $count = $task.annotations.Count
        $latest = $task.GetLatestAnnotation()
        
        if ([string]::IsNullOrEmpty($latest)) {
            return "📝 $count annotation$(if($count -gt 1){'s'})"
        }
        
        $summary = if ($latest.Length -gt $maxLength) {
            $latest.Substring(0, $maxLength - 3) + '...'
        } else {
            $latest
        }
        
        return "📝 $count: $summary"
    }
    
    [string] RenderAnnotationEditor([Task]$task, [int]$selectedIndex = -1, [string]$editBuffer = '') {
        $sb = [System.Text.StringBuilder]::new()
        
        if ($selectedIndex -eq -1) {
            # Adding new annotation
            $sb.AppendLine('Add New Annotation:')
            $sb.AppendLine('═' * 50)
            $sb.AppendLine($editBuffer + '█')  # Show cursor
            $sb.AppendLine()
            $sb.AppendLine('Enter: Save | Escape: Cancel | Ctrl+L: Line break')
        } else {
            # Editing existing annotation
            if ($selectedIndex -ge 0 -and $selectedIndex -lt $task.annotations.Count) {
                $annotation = $task.annotations[$selectedIndex]
                $timestamp = $null -ne $annotation.entry ? $annotation.entry.ToString('yyyy-MM-dd HH:mm') : 'No timestamp'
                
                $sb.AppendLine("Edit Annotation [$($selectedIndex + 1)] - $timestamp:")
                $sb.AppendLine('═' * 50)
                $sb.AppendLine($editBuffer + '█')  # Show cursor
                $sb.AppendLine()
                $sb.AppendLine('Enter: Save | Escape: Cancel | Ctrl+L: Line break | Delete: Remove annotation')
            } else {
                $sb.AppendLine('Invalid annotation index')
            }
        }
        
        return $sb.ToString()
    }
    
    [string] RenderAnnotationList([Task]$task, [int]$selectedIndex = 0) {
        $sb = [System.Text.StringBuilder]::new()
        
        $sb.AppendLine("Task [$($task.id)]: $($task.description)")
        $sb.AppendLine('═' * 60)
        
        if ($task.annotations.Count -eq 0) {
            $sb.AppendLine('No annotations')
            $sb.AppendLine()
            $sb.AppendLine('A: Add annotation | Escape: Back to task')
            return $sb.ToString()
        }
        
        $sb.AppendLine("Annotations ($($task.annotations.Count)):")
        $sb.AppendLine()
        
        $sortedAnnotations = $task.GetAnnotationsSorted()
        
        for ($i = 0; $i -lt $sortedAnnotations.Count; $i++) {
            $annotation = $sortedAnnotations[$i]
            $isSelected = ($i -eq $selectedIndex)
            
            $timestamp = $null -ne $annotation.entry ? $annotation.entry.ToString('MM/dd HH:mm') : 'No time'
            $preview = $annotation.description.Length -gt 60 ? 
                       $annotation.description.Substring(0, 57) + '...' : 
                       $annotation.description
            
            $cursor = if ($isSelected) { '▶ ' } else { '  ' }
            $highlight = if ($isSelected) { '[' } else { ' ' }
            $highlightEnd = if ($isSelected) { ']' } else { ' ' }
            
            $sb.AppendLine("$cursor$highlight$($i + 1)$highlightEnd $timestamp - $preview")
        }
        
        $sb.AppendLine()
        $sb.AppendLine('A: Add | E: Edit | D: Delete | Enter: View full | Escape: Back')
        
        return $sb.ToString()
    }
    
    [string] RenderFullAnnotation([Task]$task, [int]$annotationIndex) {
        if ($annotationIndex -lt 0 -or $annotationIndex -ge $task.annotations.Count) {
            return 'Annotation not found'
        }
        
        $annotation = $task.GetAnnotationsSorted()[$annotationIndex]
        $sb = [System.Text.StringBuilder]::new()
        
        $sb.AppendLine("Annotation [$($annotationIndex + 1)] Details:")
        $sb.AppendLine('═' * 60)
        
        if ($null -ne $annotation.entry) {
            $sb.AppendLine("Created: $($annotation.entry.ToString('yyyy-MM-dd HH:mm:ss'))")
            $sb.AppendLine("Age: $($this.GetAnnotationAge($annotation.entry))")
            $sb.AppendLine()
        }
        
        $sb.AppendLine('Content:')
        $sb.AppendLine('─' * 30)
        
        # Display full content with proper wrapping
        $wrappedLines = $this.WrapText($annotation.description, 70)
        foreach ($line in $wrappedLines) {
            $sb.AppendLine($line)
        }
        
        $sb.AppendLine()
        $sb.AppendLine('E: Edit | D: Delete | Escape: Back to list')
        
        return $sb.ToString()
    }
    
    hidden [string[]] WrapText([string]$text, [int]$width) {
        if ([string]::IsNullOrEmpty($text) -or $width -le 0) {
            return @($text)
        }
        
        $lines = @()
        $words = $text -split '\s+'
        $currentLine = ''
        
        foreach ($word in $words) {
            $testLine = if ($currentLine) { "$currentLine $word" } else { $word }
            
            if ($testLine.Length -le $width) {
                $currentLine = $testLine
            } else {
                if ($currentLine) {
                    $lines += $currentLine
                    $currentLine = $word
                } else {
                    # Word is longer than width, break it
                    while ($word.Length -gt $width) {
                        $lines += $word.Substring(0, $width)
                        $word = $word.Substring($width)
                    }
                    $currentLine = $word
                }
            }
        }
        
        if ($currentLine) {
            $lines += $currentLine
        }
        
        return $lines
    }
    
    hidden [string] GetAnnotationAge([datetime]$timestamp) {
        $now = [datetime]::Now
        $age = $now - $timestamp
        
        if ($age.Days -gt 365) {
            return "$([int]($age.Days / 365)) year$(if($age.Days -gt 730){'s'})"
        } elseif ($age.Days -gt 30) {
            return "$([int]($age.Days / 30)) month$(if($age.Days -gt 60){'s'})"
        } elseif ($age.Days -gt 0) {
            return "$($age.Days) day$(if($age.Days -gt 1){'s'})"
        } elseif ($age.Hours -gt 0) {
            return "$($age.Hours) hour$(if($age.Hours -gt 1){'s'})"
        } else {
            return "$($age.Minutes) minute$(if($age.Minutes -gt 1){'s'})"
        }
    }
    
    [hashtable] ValidateAnnotation([string]$content) {
        $issues = @()
        
        if ([string]::IsNullOrWhiteSpace($content)) {
            $issues += 'Annotation content cannot be empty'
        }
        
        if ($content.Length -gt 1000) {
            $issues += 'Annotation too long (max 1000 characters)'
        }
        
        # Check for problematic characters
        if ($content -match '[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]') {
            $issues += 'Annotation contains invalid control characters'
        }
        
        return @{
            IsValid = $issues.Count -eq 0
            Issues = $issues
            CharacterCount = $content.Length
            WordCount = ($content -split '\s+').Count
        }
    }
    
    [hashtable] ProcessAnnotationCommand([string]$command, [Task]$task, [string]$content = '') {
        switch ($command.ToLower()) {
            'add' {
                $validation = $this.ValidateAnnotation($content)
                if (-not $validation.IsValid) {
                    return @{
                        Success = $false
                        Message = "Validation failed: $($validation.Issues -join ', ')"
                    }
                }
                
                return @{
                    Success = $true
                    Action = 'AddAnnotation'
                    TaskId = $task.uuid
                    Content = $content
                    Message = "Annotation added successfully"
                }
            }
            'edit' {
                $validation = $this.ValidateAnnotation($content)
                if (-not $validation.IsValid) {
                    return @{
                        Success = $false
                        Message = "Validation failed: $($validation.Issues -join ', ')"
                    }
                }
                
                return @{
                    Success = $true
                    Action = 'EditAnnotation'
                    TaskId = $task.uuid
                    Content = $content
                    Message = "Annotation updated successfully"
                }
            }
            'delete' {
                return @{
                    Success = $true
                    Action = 'DeleteAnnotation'
                    TaskId = $task.uuid
                    Message = "Annotation deleted successfully"
                }
            }
            default {
                return @{
                    Success = $false
                    Message = "Unknown annotation command: $command"
                }
            }
        }
    }
    
    [string] GetAnnotationStats([Task[]]$allTasks) {
        $totalAnnotations = 0
        $tasksWithAnnotations = 0
        $recentAnnotations = 0
        $oneWeekAgo = [datetime]::Now.AddDays(-7)
        
        foreach ($task in $allTasks) {
            if ($task.annotations.Count -gt 0) {
                $tasksWithAnnotations++
                $totalAnnotations += $task.annotations.Count
                
                foreach ($annotation in $task.annotations) {
                    if ($null -ne $annotation.entry -and $annotation.entry -gt $oneWeekAgo) {
                        $recentAnnotations++
                    }
                }
            }
        }
        
        $sb = [System.Text.StringBuilder]::new()
        $sb.AppendLine('Annotation Statistics:')
        $sb.AppendLine("  Tasks with annotations: $tasksWithAnnotations")
        $sb.AppendLine("  Total annotations: $totalAnnotations")
        $sb.AppendLine("  Added this week: $recentAnnotations")
        
        if ($tasksWithAnnotations -gt 0) {
            $avgAnnotations = [Math]::Round($totalAnnotations / $tasksWithAnnotations, 1)
            $sb.AppendLine("  Average per task: $avgAnnotations")
        }
        
        return $sb.ToString()
    }
}
```

## System 24: Context/Workspace System

Complete context switching and workspace management system.

```powershell
class ContextManager {
    hidden [hashtable] $_contexts = @{}
    hidden [string] $_activeContext = ''
    hidden [hashtable] $_contextStats = @{}
    hidden [datetime] $_lastUpdate = [datetime]::MinValue
    
    ContextManager() {
        $this.InitializeDefaultContexts()
    }
    
    hidden [void] InitializeDefaultContexts() {
        # Define some common default contexts
        $this._contexts = @{
            'work' = @{
                Name = 'Work'
                Filter = 'project:work or +work'
                Description = 'Work-related tasks'
                Color = 'blue'
                IsActive = $false
                TaskCount = 0
            }
            'personal' = @{
                Name = 'Personal'
                Filter = 'project:personal or +personal'
                Description = 'Personal tasks and projects'
                Color = 'green'
                IsActive = $false
                TaskCount = 0
            }
            'urgent' = @{
                Name = 'Urgent'
                Filter = '+urgent or urgency.over:10'
                Description = 'High-priority urgent tasks'
                Color = 'red'
                IsActive = $false
                TaskCount = 0
            }
            'today' = @{
                Name = 'Today'
                Filter = '+TODAY or due:today'
                Description = 'Tasks due today'
                Color = 'yellow'
                IsActive = $false
                TaskCount = 0
            }
            'next' = @{
                Name = 'Next Actions'
                Filter = '+next or priority:H'
                Description = 'Next actionable tasks'
                Color = 'cyan'
                IsActive = $false
                TaskCount = 0
            }
        }
    }
    
    [void] LoadContextsFromConfig([hashtable]$taskrcConfig) {
        # Load contexts from .taskrc configuration
        foreach ($key in $taskrcConfig.Keys) {
            if ($key -match '^context\.([^.]+)\.(.+)$') {
                $contextName = $matches[1]
                $property = $matches[2]
                $value = $taskrcConfig[$key]
                
                if (-not $this._contexts.ContainsKey($contextName)) {
                    $this._contexts[$contextName] = @{
                        Name = $contextName
                        Filter = ''
                        Description = ''
                        Color = 'white'
                        IsActive = $false
                        TaskCount = 0
                    }
                }
                
                switch ($property) {
                    'read' { 
                        $this._contexts[$contextName].Filter = $value 
                        $this._contexts[$contextName].Name = $contextName.Substring(0,1).ToUpper() + $contextName.Substring(1)
                    }
                    'write' { $this._contexts[$contextName].WriteFilter = $value }
                    'description' { $this._contexts[$contextName].Description = $value }
                    'color' { $this._contexts[$contextName].Color = $value }
                }
            }
        }
    }
    
    [void] UpdateContextStats([Task[]]$allTasks) {
        $this._contextStats.Clear()
        
        foreach ($contextName in $this._contexts.Keys) {
            $context = $this._contexts[$contextName]
            $matchingTasks = $this.GetContextTasks($allTasks, $contextName)
            
            $stats = @{
                TotalTasks = $matchingTasks.Count
                PendingTasks = ($matchingTasks | Where-Object { $_.status -eq 'pending' }).Count
                CompletedTasks = ($matchingTasks | Where-Object { $_.status -eq 'completed' }).Count
                OverdueTasks = ($matchingTasks | Where-Object { 
                    $_.status -eq 'pending' -and $null -ne $_.due -and $_.due -lt [datetime]::Now 
                }).Count
                UrgentTasks = ($matchingTasks | Where-Object { $_.urgency -ge 10.0 }).Count
                LastActivity = $null
            }
            
            # Find most recent activity
            $recentTask = $matchingTasks | 
                         Where-Object { $null -ne $_.modified } | 
                         Sort-Object modified -Descending | 
                         Select-Object -First 1
            if ($recentTask) {
                $stats.LastActivity = $recentTask.modified
            }
            
            $context.TaskCount = $stats.PendingTasks
            $this._contextStats[$contextName] = $stats
        }
        
        $this._lastUpdate = [datetime]::Now
    }
    
    [Task[]] GetContextTasks([Task[]]$allTasks, [string]$contextName) {
        if (-not $this._contexts.ContainsKey($contextName)) {
            return @()
        }
        
        $context = $this._contexts[$contextName]
        if ([string]::IsNullOrEmpty($context.Filter)) {
            return @()
        }
        
        # Simple filter evaluation (would use AdvancedFilterParser in full implementation)
        $matchingTasks = @()
        foreach ($task in $allTasks) {
            if ($this.EvaluateContextFilter($task, $context.Filter)) {
                $matchingTasks += $task
            }
        }
        
        return $matchingTasks
    }
    
    hidden [bool] EvaluateContextFilter([Task]$task, [string]$filter) {
        # Simplified filter evaluation - in full implementation would use AdvancedFilterParser
        $filters = $filter -split ' or '
        
        foreach ($filterPart in $filters) {
            $filterPart = $filterPart.Trim()
            
            # Project filters
            if ($filterPart -match '^project:(.+)$') {
                $projectPattern = $matches[1]
                if ($task.project -like $projectPattern) {
                    return $true
                }
            }
            
            # Tag filters
            if ($filterPart -match '^\+(.+)$') {
                $tag = $matches[1]
                if ($task.HasTag($tag) -or ($tag -in $task.GetVirtualTags())) {
                    return $true
                }
            }
            
            # Urgency filters
            if ($filterPart -match '^urgency\.over:(.+)$') {
                $threshold = [double]$matches[1]
                if ($task.urgency -gt $threshold) {
                    return $true
                }
            }
            
            # Due date filters
            if ($filterPart -match '^due:(.+)$') {
                $dueFilter = $matches[1]
                if ($dueFilter -eq 'today' -and $null -ne $task.due -and $task.due.Date -eq [datetime]::Today) {
                    return $true
                }
            }
            
            # Priority filters
            if ($filterPart -match '^priority:(.+)$') {
                $priority = $matches[1]
                if ($task.priority -eq $priority) {
                    return $true
                }
            }
        }
        
        return $false
    }
    
    [string] RenderContextList([int]$selectedIndex = 0) {
        $sb = [System.Text.StringBuilder]::new()
        
        $sb.AppendLine('Available Contexts:')
        $sb.AppendLine('═' * 60)
        
        if ($this._contexts.Count -eq 0) {
            $sb.AppendLine('No contexts defined')
            return $sb.ToString()
        }
        
        $contextNames = $this._contexts.Keys | Sort-Object
        for ($i = 0; $i -lt $contextNames.Count; $i++) {
            $contextName = $contextNames[$i]
            $context = $this._contexts[$contextName]
            $stats = $this._contextStats[$contextName] ?? @{ PendingTasks = 0; OverdueTasks = 0 }
            
            $isSelected = ($i -eq $selectedIndex)
            $isActive = ($contextName -eq $this._activeContext)
            
            $cursor = if ($isSelected) { '▶ ' } else { '  ' }
            $active = if ($isActive) { '● ' } else { '○ ' }
            
            # Build status indicators
            $indicators = @()
            if ($stats.PendingTasks -gt 0) { $indicators += "$($stats.PendingTasks) pending" }
            if ($stats.OverdueTasks -gt 0) { $indicators += "$($stats.OverdueTasks) overdue" }
            
            $statusStr = if ($indicators.Count -gt 0) { " ($($indicators -join ', '))" } else { '' }
            
            $sb.AppendLine("$cursor$active$($context.Name)$statusStr")
            
            if (-not [string]::IsNullOrEmpty($context.Description)) {
                $sb.AppendLine("      $($context.Description)")
            }
            
            $sb.AppendLine("      Filter: $($context.Filter)")
            $sb.AppendLine()
        }
        
        $sb.AppendLine('Enter: Activate | N: New context | E: Edit | D: Delete | Escape: Back')
        
        return $sb.ToString()
    }
    
    [string] RenderActiveContext() {
        if ([string]::IsNullOrEmpty($this._activeContext)) {
            return ''
        }
        
        $context = $this._contexts[$this._activeContext]
        if (-not $context) {
            return ''
        }
        
        $stats = $this._contextStats[$this._activeContext] ?? @{ PendingTasks = 0; OverdueTasks = 0 }
        
        $indicators = @()
        if ($stats.PendingTasks -gt 0) { $indicators += "$($stats.PendingTasks)○" }
        if ($stats.OverdueTasks -gt 0) { $indicators += "$($stats.OverdueTasks)⚠" }
        
        $statusStr = if ($indicators.Count -gt 0) { " [$($indicators -join ' ')]" } else { '' }
        
        return "Context: $($context.Name)$statusStr"
    }
    
    [string] RenderContextDetails([string]$contextName) {
        if (-not $this._contexts.ContainsKey($contextName)) {
            return "Context '$contextName' not found"
        }
        
        $context = $this._contexts[$contextName]
        $stats = $this._contextStats[$contextName] ?? @{}
        
        $sb = [System.Text.StringBuilder]::new()
        
        $sb.AppendLine("Context: $($context.Name)")
        $sb.AppendLine('═' * 50)
        
        $sb.AppendLine("Description: $($context.Description)")
        $sb.AppendLine("Filter: $($context.Filter)")
        $sb.AppendLine("Color: $($context.Color)")
        $sb.AppendLine("Status: $(if($contextName -eq $this._activeContext){'Active'}else{'Inactive'})")
        
        if ($stats.Count -gt 0) {
            $sb.AppendLine()
            $sb.AppendLine('Statistics:')
            $sb.AppendLine("  Total Tasks: $($stats.TotalTasks)")
            $sb.AppendLine("  Pending: $($stats.PendingTasks)")
            $sb.AppendLine("  Completed: $($stats.CompletedTasks)")
            if ($stats.OverdueTasks -gt 0) {
                $sb.AppendLine("  ⚠️ Overdue: $($stats.OverdueTasks)")
            }
            if ($stats.UrgentTasks -gt 0) {
                $sb.AppendLine("  🔥 Urgent: $($stats.UrgentTasks)")
            }
            
            if ($null -ne $stats.LastActivity) {
                $sb.AppendLine("  Last Activity: $($stats.LastActivity.ToString('MM/dd HH:mm'))")
            }
        }
        
        return $sb.ToString()
    }
    
    [bool] ActivateContext([string]$contextName) {
        if (-not $this._contexts.ContainsKey($contextName)) {
            return $false
        }
        
        # Deactivate previous context
        if (-not [string]::IsNullOrEmpty($this._activeContext)) {
            $this._contexts[$this._activeContext].IsActive = $false
        }
        
        # Activate new context
        $this._activeContext = $contextName
        $this._contexts[$contextName].IsActive = $true
        
        return $true
    }
    
    [void] DeactivateContext() {
        if (-not [string]::IsNullOrEmpty($this._activeContext)) {
            $this._contexts[$this._activeContext].IsActive = $false
        }
        $this._activeContext = ''
    }
    
    [string] GetActiveContext() {
        return $this._activeContext
    }
    
    [string] GetActiveContextFilter() {
        if ([string]::IsNullOrEmpty($this._activeContext) -or -not $this._contexts.ContainsKey($this._activeContext)) {
            return ''
        }
        return $this._contexts[$this._activeContext].Filter
    }
    
    [bool] AddContext([string]$name, [string]$filter, [string]$description = '', [string]$color = 'white') {
        if ([string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($filter)) {
            return $false
        }
        
        $this._contexts[$name] = @{
            Name = $name
            Filter = $filter
            Description = $description
            Color = $color
            IsActive = $false
            TaskCount = 0
        }
        
        return $true
    }
    
    [bool] UpdateContext([string]$name, [hashtable]$properties) {
        if (-not $this._contexts.ContainsKey($name)) {
            return $false
        }
        
        $context = $this._contexts[$name]
        foreach ($key in $properties.Keys) {
            if ($key -in @('Name', 'Filter', 'Description', 'Color')) {
                $context[$key] = $properties[$key]
            }
        }
        
        return $true
    }
    
    [bool] RemoveContext([string]$name) {
        if (-not $this._contexts.ContainsKey($name)) {
            return $false
        }
        
        # Deactivate if it was active
        if ($name -eq $this._activeContext) {
            $this.DeactivateContext()
        }
        
        $this._contexts.Remove($name)
        $this._contextStats.Remove($name)
        
        return $true
    }
    
    [string[]] GetContextNames() {
        return $this._contexts.Keys | Sort-Object
    }
    
    [hashtable] GetContextStatistics() {
        $totalContexts = $this._contexts.Count
        $activeContext = if ([string]::IsNullOrEmpty($this._activeContext)) { 'None' } else { $this._contexts[$this._activeContext].Name }
        
        $allStats = $this._contextStats.Values
        $totalTasks = if ($allStats.Count -gt 0) { ($allStats | Measure-Object -Property TotalTasks -Sum).Sum } else { 0 }
        $pendingTasks = if ($allStats.Count -gt 0) { ($allStats | Measure-Object -Property PendingTasks -Sum).Sum } else { 0 }
        
        # Find most active context
        $mostActiveContext = $this._contextStats.GetEnumerator() | 
                           Sort-Object { $_.Value.PendingTasks } -Descending | 
                           Select-Object -First 1
        
        return @{
            TotalContexts = $totalContexts
            ActiveContext = $activeContext
            TotalTasks = $totalTasks
            PendingTasks = $pendingTasks
            MostActiveContext = if ($mostActiveContext) { $mostActiveContext.Key } else { '' }
            MostActiveTasks = if ($mostActiveContext) { $mostActiveContext.Value.PendingTasks } else { 0 }
        }
    }
    
    [string] GetContextSwitchHelp() {
        $sb = [System.Text.StringBuilder]::new()
        
        $sb.AppendLine('Context Quick Switch:')
        $sb.AppendLine('─' * 30)
        
        $contextNames = $this.GetContextNames()
        for ($i = 0; $i -lt [Math]::Min($contextNames.Count, 9); $i++) {
            $contextName = $contextNames[$i]
            $context = $this._contexts[$contextName]
            $stats = $this._contextStats[$contextName] ?? @{ PendingTasks = 0 }
            
            $activeIndicator = if ($contextName -eq $this._activeContext) { ' (active)' } else { '' }
            $sb.AppendLine("  $($i + 1): $($context.Name) ($($stats.PendingTasks) tasks)$activeIndicator")
        }
        
        if ($contextNames.Count -gt 9) {
            $sb.AppendLine("  ... and $($contextNames.Count - 9) more (use context menu)")
        }
        
        $sb.AppendLine()
        $sb.AppendLine('0: Deactivate context | C: Context menu')
        
        return $sb.ToString()
    }
    
    [bool] NeedsUpdate() {
        return ([datetime]::Now - $this._lastUpdate).TotalMinutes -gt 10
    }
}
```

## System 25: Comprehensive UDA Display System

Complete UDA display with type-specific formatting and column generation.

```powershell
class ComprehensiveUDADisplayManager {
    hidden [hashtable] $_udaDefinitions = @{}
    hidden [hashtable] $_udaValidators = @{}
    hidden [hashtable] $_formatters = @{}
    hidden [hashtable] $_columnCache = @{}
    
    ComprehensiveUDADisplayManager() {
        $this.InitializeFormatters()
    }
    
    hidden [void] InitializeFormatters() {
        $this._formatters = @{
            'string' = { param($value, $width) return $this.FormatString($value, $width) }
            'numeric' = { param($value, $width) return $this.FormatNumeric($value, $width) }
            'date' = { param($value, $width) return $this.FormatDate($value, $width) }
            'duration' = { param($value, $width) return $this.FormatDuration($value, $width) }
            'enum' = { param($value, $width, $values) return $this.FormatEnum($value, $width, $values) }
        }
    }
    
    [void] LoadUDADefinitions([hashtable]$taskrcConfig) {
        $this._udaDefinitions.Clear()
        
        # Parse UDA definitions from .taskrc
        foreach ($key in $taskrcConfig.Keys) {
            if ($key -match '^uda\.([^.]+)\.(.+)$') {
                $udaName = $matches[1]
                $property = $matches[2]
                $value = $taskrcConfig[$key]
                
                if (-not $this._udaDefinitions.ContainsKey($udaName)) {
                    $this._udaDefinitions[$udaName] = @{
                        Name = $udaName
                        Type = 'string'
                        Label = $udaName
                        Values = @()
                        Default = ''
                        Sortable = $true
                        Width = 10
                        Urgent = 0.0
                    }
                }
                
                $uda = $this._udaDefinitions[$udaName]
                switch ($property) {
                    'type' { $uda.Type = $value }
                    'label' { $uda.Label = $value }
                    'values' { $uda.Values = $value -split ',' | ForEach-Object { $_.Trim() } }
                    'default' { $uda.Default = $value }
                    'urgent' { $uda.Urgent = [double]$value }
                }
            }
        }
        
        # Auto-detect optimal column widths
        foreach ($udaName in $this._udaDefinitions.Keys) {
            $uda = $this._udaDefinitions[$udaName]
            $uda.Width = $this.CalculateOptimalWidth($uda)
        }
    }
    
    hidden [int] CalculateOptimalWidth([hashtable]$uda) {
        $maxWidth = $uda.Label.Length
        
        switch ($uda.Type) {
            'string' {
                # For string UDAs, use a reasonable default with enum consideration
                if ($uda.Values.Count -gt 0) {
                    $maxEnumWidth = ($uda.Values | Measure-Object -Property Length -Maximum).Maximum
                    return [Math]::Min([Math]::Max($maxWidth, $maxEnumWidth), 15)
                }
                return [Math]::Max($maxWidth, 12)
            }
            'numeric' {
                return [Math]::Max($maxWidth, 8)
            }
            'date' {
                return [Math]::Max($maxWidth, 10)  # YYYY-MM-DD format
            }
            'duration' {
                return [Math]::Max($maxWidth, 8)   # 1d 2h format
            }
            default {
                return [Math]::Max($maxWidth, 10)
            }
        }
    }
    
    [hashtable] CreateUDAColumnDefinition([string]$udaName) {
        if (-not $this._udaDefinitions.ContainsKey($udaName)) {
            return @{}
        }
        
        $uda = $this._udaDefinitions[$udaName]
        return @{
            Name = $uda.Name
            Header = $uda.Label
            Attribute = $uda.Name
            Width = $uda.Width
            UDAType = $uda.Type
            Sortable = $uda.Sortable
            Formatter = $this._formatters[$uda.Type]
            EnumValues = $uda.Values
        }
    }
    
    [string] FormatUDAValue([Task]$task, [string]$udaName, [int]$width = 0) {
        if (-not $this._udaDefinitions.ContainsKey($udaName)) {
            return ''
        }
        
        $uda = $this._udaDefinitions[$udaName]
        $value = $task.GetUDA($udaName)
        $displayWidth = if ($width -gt 0) { $width } else { $uda.Width }
        
        if ($null -eq $value -or $value -eq '') {
            return $this.PadToWidth('', $displayWidth)
        }
        
        $formatted = switch ($uda.Type) {
            'string' { $this.FormatString($value, $displayWidth) }
            'numeric' { $this.FormatNumeric($value, $displayWidth) }
            'date' { $this.FormatDate($value, $displayWidth) }
            'duration' { $this.FormatDuration($value, $displayWidth) }
            'enum' { $this.FormatEnum($value, $displayWidth, $uda.Values) }
            default { $this.FormatString($value, $displayWidth) }
        }
        
        return $formatted
    }
    
    hidden [string] FormatString([string]$value, [int]$width) {
        if ([string]::IsNullOrEmpty($value)) {
            return $this.PadToWidth('', $width)
        }
        
        if ($value.Length -gt $width) {
            return $value.Substring(0, $width - 1) + '…'
        }
        
        return $this.PadToWidth($value, $width)
    }
    
    hidden [string] FormatNumeric([object]$value, [int]$width) {
        if ($null -eq $value) {
            return $this.PadToWidth('', $width)
        }
        
        try {
            $numValue = [double]$value
            $formatted = if ($numValue % 1 -eq 0) {
                # Integer
                $numValue.ToString('0')
            } else {
                # Decimal - show appropriate precision
                if ([Math]::Abs($numValue) -lt 10) {
                    $numValue.ToString('0.##')
                } else {
                    $numValue.ToString('0.#')
                }
            }
            
            return $this.PadToWidth($formatted, $width, $true)  # Right-align numbers
        } catch {
            return $this.FormatString($value.ToString(), $width)
        }
    }
    
    hidden [string] FormatDate([object]$value, [int]$width) {
        if ($null -eq $value) {
            return $this.PadToWidth('', $width)
        }
        
        try {
            $dateValue = if ($value -is [datetime]) {
                $value
            } else {
                [datetime]::Parse($value.ToString())
            }
            
            $formatted = switch ($width) {
                { $_ -le 8 } { $dateValue.ToString('MM/dd/yy') }
                { $_ -le 10 } { $dateValue.ToString('yyyy-MM-dd') }
                { $_ -le 16 } { $dateValue.ToString('MM/dd/yy HH:mm') }
                default { $dateValue.ToString('yyyy-MM-dd HH:mm') }
            }
            
            return $this.PadToWidth($formatted, $width)
        } catch {
            return $this.FormatString($value.ToString(), $width)
        }
    }
    
    hidden [string] FormatDuration([object]$value, [int]$width) {
        if ($null -eq $value) {
            return $this.PadToWidth('', $width)
        }
        
        try {
            # Parse TaskWarrior duration format (1d, 2h, 30min, etc.)
            $durationStr = $value.ToString().ToLower()
            $totalMinutes = 0
            
            if ($durationStr -match '(\d+)d') { $totalMinutes += [int]$matches[1] * 1440 }
            if ($durationStr -match '(\d+)h') { $totalMinutes += [int]$matches[1] * 60 }
            if ($durationStr -match '(\d+)min') { $totalMinutes += [int]$matches[1] }
            if ($durationStr -match '^(\d+)$') { $totalMinutes = [int]$matches[1] }  # Just minutes
            
            # Format back to readable form
            $formatted = if ($totalMinutes -ge 1440) {
                $days = [int]($totalMinutes / 1440)
                $hours = [int](($totalMinutes % 1440) / 60)
                if ($hours -gt 0) { "$($days)d$($hours)h" } else { "$($days)d" }
            } elseif ($totalMinutes -ge 60) {
                $hours = [int]($totalMinutes / 60)
                $mins = $totalMinutes % 60
                if ($mins -gt 0) { "$($hours)h$($mins)m" } else { "$($hours)h" }
            } else {
                "$($totalMinutes)min"
            }
            
            return $this.PadToWidth($formatted, $width, $true)  # Right-align durations
        } catch {
            return $this.FormatString($value.ToString(), $width)
        }
    }
    
    hidden [string] FormatEnum([object]$value, [int]$width, [string[]]$enumValues) {
        if ($null -eq $value) {
            return $this.PadToWidth('', $width)
        }
        
        $valueStr = $value.ToString()
        
        # Validate against enum values
        if ($enumValues.Count -gt 0 -and $valueStr -notin $enumValues) {
            $valueStr = "[$valueStr]"  # Mark invalid values
        }
        
        return $this.FormatString($valueStr, $width)
    }
    
    hidden [string] PadToWidth([string]$text, [int]$width, [bool]$rightAlign = $false) {
        if ($width -le 0) { return $text }
        
        if ($rightAlign) {
            return $text.PadLeft($width)
        } else {
            return $text.PadRight($width)
        }
    }
    
    [string] RenderUDADetails([Task]$task) {
        $sb = [System.Text.StringBuilder]::new()
        
        if ($task.uda.Count -eq 0) {
            return 'No User Defined Attributes'
        }
        
        $sb.AppendLine("Task [$($task.id)] UDAs:")
        $sb.AppendLine('═' * 50)
        
        foreach ($udaName in $task.uda.Keys | Sort-Object) {
            $value = $task.uda[$udaName]
            $uda = $this._udaDefinitions[$udaName]
            
            if ($uda) {
                $sb.AppendLine("$($uda.Label) ($($uda.Type)):")
                
                # Show formatted value
                $formatted = $this.FormatUDAValue($task, $udaName, 0)
                $sb.AppendLine("  Value: $formatted")
                
                # Show enum options if applicable
                if ($uda.Values.Count -gt 0) {
                    $sb.AppendLine("  Options: $($uda.Values -join ', ')")
                }
                
                # Show urgency contribution if any
                if ($uda.Urgent -ne 0.0) {
                    $urgencyContrib = if ($null -ne $value -and $value -ne '') { 
                        $uda.Urgent 
                    } else { 
                        0 
                    }
                    $sb.AppendLine("  Urgency: +$urgencyContrib")
                }
            } else {
                # Undefined UDA
                $sb.AppendLine("$udaName (undefined):")
                $sb.AppendLine("  Value: $value")
            }
            
            $sb.AppendLine()
        }
        
        return $sb.ToString()
    }
    
    [string] RenderUDASummary([Task[]]$allTasks) {
        $udaUsage = @{}
        $undefinedUDAs = @{}
        
        foreach ($task in $allTasks) {
            foreach ($udaName in $task.uda.Keys) {
                if ($this._udaDefinitions.ContainsKey($udaName)) {
                    if (-not $udaUsage.ContainsKey($udaName)) {
                        $udaUsage[$udaName] = 0
                    }
                    $udaUsage[$udaName]++
                } else {
                    if (-not $undefinedUDAs.ContainsKey($udaName)) {
                        $undefinedUDAs[$udaName] = 0
                    }
                    $undefinedUDAs[$udaName]++
                }
            }
        }
        
        $sb = [System.Text.StringBuilder]::new()
        $sb.AppendLine('UDA Usage Summary:')
        $sb.AppendLine('═' * 40)
        
        if ($this._udaDefinitions.Count -eq 0) {
            $sb.AppendLine('No UDAs defined in configuration')
        } else {
            $sb.AppendLine('Defined UDAs:')
            foreach ($udaName in $this._udaDefinitions.Keys | Sort-Object) {
                $uda = $this._udaDefinitions[$udaName]
                $usage = $udaUsage[$udaName] ?? 0
                $usagePercent = if ($allTasks.Count -gt 0) { 
                    [Math]::Round(($usage / $allTasks.Count) * 100, 1) 
                } else { 
                    0 
                }
                
                $sb.AppendLine("  $($uda.Label) ($($uda.Type)): $usage tasks ($usagePercent%)")
            }
        }
        
        if ($undefinedUDAs.Count -gt 0) {
            $sb.AppendLine()
            $sb.AppendLine('Undefined UDAs (consider adding to .taskrc):')
            foreach ($udaName in $undefinedUDAs.Keys | Sort-Object) {
                $usage = $undefinedUDAs[$udaName]
                $sb.AppendLine("  $udaName: $usage tasks")
            }
        }
        
        return $sb.ToString()
    }
    
    [hashtable] ValidateUDAValue([string]$udaName, [object]$value) {
        if (-not $this._udaDefinitions.ContainsKey($udaName)) {
            return @{
                IsValid = $false
                Error = "UDA '$udaName' is not defined"
            }
        }
        
        $uda = $this._udaDefinitions[$udaName]
        $issues = @()
        
        # Type validation
        switch ($uda.Type) {
            'numeric' {
                try {
                    [double]$value | Out-Null
                } catch {
                    $issues += "Value '$value' is not a valid number"
                }
            }
            'date' {
                try {
                    [datetime]::Parse($value.ToString()) | Out-Null
                } catch {
                    $issues += "Value '$value' is not a valid date"
                }
            }
            'enum' {
                if ($uda.Values.Count -gt 0 -and $value -notin $uda.Values) {
                    $issues += "Value '$value' is not in allowed values: $($uda.Values -join ', ')"
                }
            }
        }
        
        return @{
            IsValid = $issues.Count -eq 0
            Issues = $issues
        }
    }
    
    [string[]] GetUDANames() {
        return $this._udaDefinitions.Keys | Sort-Object
    }
    
    [hashtable] GetUDADefinition([string]$udaName) {
        return $this._udaDefinitions[$udaName]
    }
    
    [string[]] GetUDAColumnNames() {
        return $this._udaDefinitions.Keys | Where-Object { $this._udaDefinitions[$_].Sortable } | Sort-Object
    }
}
```

## System 26: Advanced Date/Time Handling System

Complete date/time parsing and abbreviation support system.

```powershell
class AdvancedDateTimeHandler {
    hidden [hashtable] $_dateAbbreviations = @{}
    hidden [hashtable] $_dateFormatters = @{}
    hidden [hashtable] $_relativeDateCache = @{}
    
    AdvancedDateTimeHandler() {
        $this.InitializeDateAbbreviations()
        $this.InitializeFormatters()
    }
    
    hidden [void] InitializeDateAbbreviations() {
        $this._dateAbbreviations = @{
            # Current time references
            'now' = { [datetime]::Now }
            'today' = { [datetime]::Today }
            'tomorrow' = { [datetime]::Today.AddDays(1) }
            'yesterday' = { [datetime]::Today.AddDays(-1) }
            
            # Week references
            'sow' = { $this.GetStartOfWeek([datetime]::Now) }
            'eow' = { $this.GetEndOfWeek([datetime]::Now) }
            'soww' = { $this.GetStartOfWorkWeek([datetime]::Now) }
            'eoww' = { $this.GetEndOfWorkWeek([datetime]::Now) }
            
            # Month references
            'som' = { [datetime]::new([datetime]::Now.Year, [datetime]::Now.Month, 1) }
            'eom' = { $this.GetEndOfMonth([datetime]::Now) }
            
            # Quarter references
            'soq' = { $this.GetStartOfQuarter([datetime]::Now) }
            'eoq' = { $this.GetEndOfQuarter([datetime]::Now) }
            
            # Year references
            'soy' = { [datetime]::new([datetime]::Now.Year, 1, 1) }
            'eoy' = { [datetime]::new([datetime]::Now.Year, 12, 31) }
            
            # Relative weekdays
            'monday' = { $this.GetNextWeekday([DayOfWeek]::Monday) }
            'tuesday' = { $this.GetNextWeekday([DayOfWeek]::Tuesday) }
            'wednesday' = { $this.GetNextWeekday([DayOfWeek]::Wednesday) }
            'thursday' = { $this.GetNextWeekday([DayOfWeek]::Thursday) }
            'friday' = { $this.GetNextWeekday([DayOfWeek]::Friday) }
            'saturday' = { $this.GetNextWeekday([DayOfWeek]::Saturday) }
            'sunday' = { $this.GetNextWeekday([DayOfWeek]::Sunday) }
            
            # Special dates
            'easter' = { $this.GetEaster([datetime]::Now.Year) }
            'christmas' = { [datetime]::new([datetime]::Now.Year, 12, 25) }
            'newyear' = { [datetime]::new([datetime]::Now.Year, 1, 1) }
        }
    }
    
    hidden [void] InitializeFormatters() {
        $this._dateFormatters = @{
            'short' = { param($date) $date.ToString('MM/dd') }
            'medium' = { param($date) $date.ToString('MM/dd/yy') }
            'long' = { param($date) $date.ToString('yyyy-MM-dd') }
            'full' = { param($date) $date.ToString('yyyy-MM-dd HH:mm') }
            'iso' = { param($date) $date.ToString('yyyy-MM-ddTHH:mm:ss') }
            'relative' = { param($date) $this.FormatRelativeDate($date) }
            'age' = { param($date) $this.FormatAge($date) }
        }
    }
    
    [nullable[datetime]] ParseDateExpression([string]$expression) {
        if ([string]::IsNullOrWhiteSpace($expression)) {
            return $null
        }
        
        $expression = $expression.Trim().ToLower()
        
        # Cache check for performance
        if ($this._relativeDateCache.ContainsKey($expression)) {
            $cached = $this._relativeDateCache[$expression]
            if (([datetime]::Now - $cached.Timestamp).TotalMinutes -lt 5) {
                return $cached.Date
            }
        }
        
        $result = $this.ParseDateExpressionInternal($expression)
        
        # Cache the result
        if ($null -ne $result) {
            $this._relativeDateCache[$expression] = @{
                Date = $result
                Timestamp = [datetime]::Now
            }
        }
        
        return $result
    }
    
    hidden [nullable[datetime]] ParseDateExpressionInternal([string]$expression) {
        # Direct abbreviation lookup
        if ($this._dateAbbreviations.ContainsKey($expression)) {
            return $this._dateAbbreviations[$expression].Invoke()
        }
        
        # Date math expressions (eom+1d, sow-2w, etc.)
        if ($expression -match '^(\w+)([+-])(\d+)([dwmy])$') {
            $baseExpr = $matches[1]
            $operation = $matches[2]
            $amount = [int]$matches[3]
            $unit = $matches[4]
            
            $baseDate = if ($this._dateAbbreviations.ContainsKey($baseExpr)) {
                $this._dateAbbreviations[$baseExpr].Invoke()
            } else {
                [datetime]::Now
            }
            
            $modifier = if ($operation -eq '+') { $amount } else { -$amount }
            
            return switch ($unit) {
                'd' { $baseDate.AddDays($modifier) }
                'w' { $baseDate.AddDays($modifier * 7) }
                'm' { $baseDate.AddMonths($modifier) }
                'y' { $baseDate.AddYears($modifier) }
            }
        }
        
        # Relative date expressions (next monday, last friday, etc.)
        if ($expression -match '^(next|last)\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)$') {
            $direction = $matches[1]
            $weekdayName = $matches[2]
            $targetWeekday = [Enum]::Parse([DayOfWeek], $weekdayName, $true)
            
            return if ($direction -eq 'next') {
                $this.GetNextWeekday($targetWeekday)
            } else {
                $this.GetPreviousWeekday($targetWeekday)
            }
        }
        
        # Ordinal expressions (1st monday, 3rd friday, etc.)
        if ($expression -match '^(1st|2nd|3rd|\d+th)\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)(?:\s+of\s+(\w+))?$') {
            $ordinal = $matches[1]
            $weekdayName = $matches[2]
            $monthRef = $matches[3]
            
            $ordinalNum = switch ($ordinal) {
                '1st' { 1 }
                '2nd' { 2 }
                '3rd' { 3 }
                default { [int]$ordinal.Replace('th', '') }
            }
            
            $targetWeekday = [Enum]::Parse([DayOfWeek], $weekdayName, $true)
            $baseMonth = if ($monthRef -eq 'next') {
                [datetime]::Now.AddMonths(1)
            } else {
                [datetime]::Now
            }
            
            return $this.GetNthWeekdayOfMonth($baseMonth, $targetWeekday, $ordinalNum)
        }
        
        # Business day expressions (5 business days, -3 workdays)
        if ($expression -match '^([+-]?\d+)\s+(business|work)days?$') {
            $days = [int]$matches[1]
            return $this.AddBusinessDays([datetime]::Now, $days)
        }
        
        # Standard date parsing
        try {
            return [datetime]::Parse($expression)
        } catch {
            # ISO date parsing
            try {
                return [datetime]::ParseExact($expression, @('yyyy-MM-dd', 'yyyy-MM-ddTHH:mm:ss', 'MM/dd/yyyy', 'dd/MM/yyyy'), $null, [System.Globalization.DateTimeStyles]::None)
            } catch {
                return $null
            }
        }
    }
    
    [string] FormatDate([nullable[datetime]]$date, [string]$format = 'medium') {
        if ($null -eq $date) {
            return ''
        }
        
        if ($this._dateFormatters.ContainsKey($format)) {
            return $this._dateFormatters[$format].Invoke($date)
        }
        
        # Custom format string
        try {
            return $date.ToString($format)
        } catch {
            return $date.ToString('yyyy-MM-dd')
        }
    }
    
    [string] FormatRelativeDate([datetime]$date) {
        $now = [datetime]::Now
        $diff = $now - $date
        $absDiff = [Math]::Abs($diff.TotalDays)
        
        if ($date.Date -eq $now.Date) {
            return 'today'
        } elseif ($date.Date -eq $now.Date.AddDays(1)) {
            return 'tomorrow'
        } elseif ($date.Date -eq $now.Date.AddDays(-1)) {
            return 'yesterday'
        } elseif ($absDiff -lt 7) {
            $dayName = $date.ToString('dddd').ToLower()
            return if ($date > $now) { "this $dayName" } else { "last $dayName" }
        } elseif ($absDiff -lt 14) {
            $dayName = $date.ToString('dddd').ToLower()
            return if ($date > $now) { "next $dayName" } else { "last $dayName" }
        } elseif ($date.Year -eq $now.Year) {
            return $date.ToString('MMM dd')
        } else {
            return $date.ToString('MMM dd, yyyy')
        }
    }
    
    [string] FormatAge([datetime]$date) {
        $age = [datetime]::Now - $date
        
        if ($age.Days -gt 365) {
            return "$([int]($age.Days / 365))y"
        } elseif ($age.Days -gt 30) {
            return "$([int]($age.Days / 30))mo"
        } elseif ($age.Days -gt 0) {
            return "$($age.Days)d"
        } elseif ($age.Hours -gt 0) {
            return "$($age.Hours)h"
        } else {
            return "$($age.Minutes)min"
        }
    }
    
    [string] FormatDueStatus([nullable[datetime]]$dueDate) {
        if ($null -eq $dueDate) {
            return ''
        }
        
        $now = [datetime]::Now
        $days = ($dueDate - $now).Days
        
        if ($days -lt -1) {
            return "⚠️ $([Math]::Abs($days))d overdue"
        } elseif ($days -eq -1) {
            return "⚠️ 1d overdue"
        } elseif ($days -eq 0) {
            return "🔥 Due today"
        } elseif ($days -eq 1) {
            return "📅 Due tomorrow"
        } elseif ($days -le 7) {
            return "📅 Due in ${days}d"
        } else {
            return "📅 Due $($this.FormatRelativeDate($dueDate))"
        }
    }
    
    # Helper methods for date calculations
    hidden [datetime] GetStartOfWeek([datetime]$date) {
        $daysFromSunday = [int]$date.DayOfWeek
        return $date.Date.AddDays(-$daysFromSunday)
    }
    
    hidden [datetime] GetEndOfWeek([datetime]$date) {
        return $this.GetStartOfWeek($date).AddDays(6)
    }
    
    hidden [datetime] GetStartOfWorkWeek([datetime]$date) {
        $daysFromMonday = ([int]$date.DayOfWeek + 6) % 7
        return $date.Date.AddDays(-$daysFromMonday)
    }
    
    hidden [datetime] GetEndOfWorkWeek([datetime]$date) {
        return $this.GetStartOfWorkWeek($date).AddDays(4)  # Monday to Friday
    }
    
    hidden [datetime] GetEndOfMonth([datetime]$date) {
        return [datetime]::new($date.Year, $date.Month, [datetime]::DaysInMonth($date.Year, $date.Month))
    }
    
    hidden [datetime] GetStartOfQuarter([datetime]$date) {
        $quarterMonth = ((($date.Month - 1) / 3) * 3) + 1
        return [datetime]::new($date.Year, $quarterMonth, 1)
    }
    
    hidden [datetime] GetEndOfQuarter([datetime]$date) {
        return $this.GetStartOfQuarter($date).AddMonths(3).AddDays(-1)
    }
    
    hidden [datetime] GetNextWeekday([DayOfWeek]$targetWeekday) {
        $currentWeekday = [datetime]::Now.DayOfWeek
        $daysUntilTarget = ([int]$targetWeekday - [int]$currentWeekday + 7) % 7
        if ($daysUntilTarget -eq 0) { $daysUntilTarget = 7 }  # Next occurrence, not today
        return [datetime]::Today.AddDays($daysUntilTarget)
    }
    
    hidden [datetime] GetPreviousWeekday([DayOfWeek]$targetWeekday) {
        $currentWeekday = [datetime]::Now.DayOfWeek
        $daysSinceTarget = ([int]$currentWeekday - [int]$targetWeekday + 7) % 7
        if ($daysSinceTarget -eq 0) { $daysSinceTarget = 7 }  # Previous occurrence, not today
        return [datetime]::Today.AddDays(-$daysSinceTarget)
    }
    
    hidden [datetime] GetNthWeekdayOfMonth([datetime]$month, [DayOfWeek]$weekday, [int]$occurrence) {
        $firstDayOfMonth = [datetime]::new($month.Year, $month.Month, 1)
        $firstWeekdayOfMonth = $firstDayOfMonth
        
        # Find first occurrence of the weekday in the month
        while ($firstWeekdayOfMonth.DayOfWeek -ne $weekday) {
            $firstWeekdayOfMonth = $firstWeekdayOfMonth.AddDays(1)
        }
        
        # Add weeks to get to the nth occurrence
        $targetDate = $firstWeekdayOfMonth.AddDays(($occurrence - 1) * 7)
        
        # Ensure it's still in the same month
        if ($targetDate.Month -eq $month.Month) {
            return $targetDate
        } else {
            # Fallback to last occurrence if nth doesn't exist
            return $firstWeekdayOfMonth.AddDays((4 - 1) * 7)  # 4th occurrence as fallback
        }
    }
    
    hidden [datetime] AddBusinessDays([datetime]$startDate, [int]$businessDays) {
        $currentDate = $startDate
        $remainingDays = [Math]::Abs($businessDays)
        $direction = if ($businessDays -gt 0) { 1 } else { -1 }
        
        while ($remainingDays -gt 0) {
            $currentDate = $currentDate.AddDays($direction)
            if ($currentDate.DayOfWeek -notin @([DayOfWeek]::Saturday, [DayOfWeek]::Sunday)) {
                $remainingDays--
            }
        }
        
        return $currentDate
    }
    
    hidden [datetime] GetEaster([int]$year) {
        # Gregorian Easter calculation algorithm
        $a = $year % 19
        $b = [int]($year / 100)
        $c = $year % 100
        $d = [int]($b / 4)
        $e = $b % 4
        $f = [int](($b + 8) / 25)
        $g = [int](($b - $f + 1) / 3)
        $h = (19 * $a + $b - $d - $g + 15) % 30
        $i = [int]($c / 4)
        $k = $c % 4
        $l = (32 + 2 * $e + 2 * $i - $h - $k) % 7
        $m = [int](($a + 11 * $h + 22 * $l) / 451)
        $month = [int](($h + $l - 7 * $m + 114) / 31)
        $day = (($h + $l - 7 * $m + 114) % 31) + 1
        
        return [datetime]::new($year, $month, $day)
    }
    
    [string[]] GetAvailableAbbreviations() {
        return $this._dateAbbreviations.Keys | Sort-Object
    }
    
    [string] GetAbbreviationHelp() {
        $sb = [System.Text.StringBuilder]::new()
        
        $sb.AppendLine('Date Abbreviations:')
        $sb.AppendLine('─' * 30)
        
        $categories = @{
            'Current Time' = @('now', 'today', 'tomorrow', 'yesterday')
            'Week References' = @('sow', 'eow', 'soww', 'eoww')
            'Month References' = @('som', 'eom')
            'Quarter/Year' = @('soq', 'eoq', 'soy', 'eoy')
            'Weekdays' = @('monday', 'tuesday', 'wednesday', 'thursday', 'friday')
            'Special Dates' = @('easter', 'christmas', 'newyear')
        }
        
        foreach ($category in $categories.Keys) {
            $sb.AppendLine($category + ':')
            foreach ($abbr in $categories[$category]) {
                $example = $this.FormatDate($this.ParseDateExpression($abbr), 'short')
                $sb.AppendLine("  $abbr → $example")
            }
            $sb.AppendLine()
        }
        
        $sb.AppendLine('Date Math Examples:')
        $sb.AppendLine('  eom+1d → End of month + 1 day')
        $sb.AppendLine('  sow-2w → Start of week - 2 weeks')
        $sb.AppendLine('  next friday → Next Friday')
        $sb.AppendLine('  3 business days → 3 working days from now')
        
        return $sb.ToString()
    }
    
    [void] ClearCache() {
        $this._relativeDateCache.Clear()
    }
}
```

## System 27: Performance Monitoring Display System

Performance monitoring and health display for large datasets.

```powershell
class PerformanceMonitoringSystem {
    hidden [hashtable] $_performanceCounters = @{}
    hidden [hashtable] $_healthMetrics = @{}
    hidden [System.Collections.Generic.List[hashtable]] $_performanceHistory = [System.Collections.Generic.List[hashtable]]::new()
    hidden [int] $_maxHistorySize = 100
    hidden [hashtable] $_thresholds = @{}
    
    PerformanceMonitoringSystem() {
        $this.InitializeCounters()
        $this.InitializeThresholds()
    }
    
    hidden [void] InitializeCounters() {
        $this._performanceCounters = @{
            RenderTime = @{ Current = 0.0; Average = 0.0; Max = 0.0; Count = 0 }
            FilterTime = @{ Current = 0.0; Average = 0.0; Max = 0.0; Count = 0 }
            SortTime = @{ Current = 0.0; Average = 0.0; Max = 0.0; Count = 0 }
            TaskLoadTime = @{ Current = 0.0; Average = 0.0; Max = 0.0; Count = 0 }
            MemoryUsage = @{ Current = 0.0; Peak = 0.0; Baseline = 0.0 }
            TaskCount = @{ Current = 0; Peak = 0; Filtered = 0 }
            CacheHitRate = @{ Current = 0.0; Average = 0.0 }
            FrameRate = @{ Current = 0.0; Average = 0.0; Target = 60.0 }
        }
    }
    
    hidden [void] InitializeThresholds() {
        $this._thresholds = @{
            RenderTime = @{ Warning = 50.0; Critical = 100.0 }  # milliseconds
            FilterTime = @{ Warning = 200.0; Critical = 500.0 }
            SortTime = @{ Warning = 100.0; Critical = 300.0 }
            TaskLoadTime = @{ Warning = 1000.0; Critical = 3000.0 }
            MemoryUsage = @{ Warning = 100.0; Critical = 500.0 }  # MB
            FrameRate = @{ Warning = 30.0; Critical = 15.0 }  # FPS
            CacheHitRate = @{ Warning = 70.0; Critical = 50.0 }  # Percentage
        }
    }
    
    [void] RecordPerformanceMetric([string]$metric, [double]$value) {
        if (-not $this._performanceCounters.ContainsKey($metric)) {
            return
        }
        
        $counter = $this._performanceCounters[$metric]
        $counter.Current = $value
        $counter.Count++
        
        # Update max
        if ($value -gt $counter.Max) {
            $counter.Max = $value
        }
        
        # Update average (exponential moving average)
        if ($counter.Count -eq 1) {
            $counter.Average = $value
        } else {
            $counter.Average = ($counter.Average * 0.9) + ($value * 0.1)
        }
        
        # Record in history
        $this._performanceHistory.Add(@{
            Timestamp = [datetime]::Now
            Metric = $metric
            Value = $value
        })
        
        # Limit history size
        while ($this._performanceHistory.Count -gt $this._maxHistorySize) {
            $this._performanceHistory.RemoveAt(0)
        }
    }
    
    [void] UpdateSystemMetrics() {
        # Memory usage
        try {
            $process = [System.Diagnostics.Process]::GetCurrentProcess()
            $memoryMB = $process.WorkingSet64 / 1MB
            $this.RecordPerformanceMetric('MemoryUsage', $memoryMB)
            
            $memCounter = $this._performanceCounters['MemoryUsage']
            if ($memCounter.Baseline -eq 0) {
                $memCounter.Baseline = $memoryMB
            }
            if ($memoryMB -gt $memCounter.Peak) {
                $memCounter.Peak = $memoryMB
            }
        } catch {
            # Memory monitoring failed
        }
        
        # Calculate frame rate
        $recentRenderTimes = $this._performanceHistory | 
                           Where-Object { $_.Metric -eq 'RenderTime' -and $_.Timestamp -gt ([datetime]::Now.AddSeconds(-1)) }
        
        if ($recentRenderTimes.Count -gt 0) {
            $avgRenderTime = ($recentRenderTimes | Measure-Object -Property Value -Average).Average
            $frameRate = if ($avgRenderTime -gt 0) { 1000.0 / $avgRenderTime } else { 0.0 }
            $this._performanceCounters['FrameRate'].Current = $frameRate
            $this._performanceCounters['FrameRate'].Average = ($this._performanceCounters['FrameRate'].Average * 0.9) + ($frameRate * 0.1)
        }
    }
    
    [string] GetHealthStatus() {
        $issues = @()
        $warnings = @()
        $critical = $false
        
        foreach ($metric in $this._performanceCounters.Keys) {
            if (-not $this._thresholds.ContainsKey($metric)) { continue }
            
            $counter = $this._performanceCounters[$metric]
            $threshold = $this._thresholds[$metric]
            $currentValue = $counter.Current
            
            # Special handling for different metric types
            $checkValue = switch ($metric) {
                'FrameRate' { if ($currentValue -eq 0) { 60.0 } else { $currentValue } }
                'CacheHitRate' { $currentValue }
                default { $counter.Average }
            }
            
            if ($metric -eq 'FrameRate' -or $metric -eq 'CacheHitRate') {
                # Higher is better metrics
                if ($checkValue -lt $threshold.Critical) {
                    $issues += "Critical: $metric is $($checkValue.ToString('0.1')) (< $($threshold.Critical))"
                    $critical = $true
                } elseif ($checkValue -lt $threshold.Warning) {
                    $warnings += "Warning: $metric is $($checkValue.ToString('0.1')) (< $($threshold.Warning))"
                }
            } else {
                # Lower is better metrics
                if ($checkValue -gt $threshold.Critical) {
                    $issues += "Critical: $metric is $($checkValue.ToString('0.1')) (> $($threshold.Critical))"
                    $critical = $true
                } elseif ($checkValue -gt $threshold.Warning) {
                    $warnings += "Warning: $metric is $($checkValue.ToString('0.1')) (> $($threshold.Warning))"
                }
            }
        }
        
        if ($critical) {
            return '🔴 Critical Issues Detected'
        } elseif ($warnings.Count -gt 0) {
            return '🟡 Performance Warnings'
        } else {
            return '🟢 System Healthy'
        }
    }
    
    [string] RenderPerformanceDashboard([int]$width = 80) {
        $sb = [System.Text.StringBuilder]::new()
        
        $sb.AppendLine('Performance Dashboard')
        $sb.AppendLine('═' * $width)
        
        # Health status
        $healthStatus = $this.GetHealthStatus()
        $sb.AppendLine("Status: $healthStatus")
        $sb.AppendLine()
        
        # Key metrics in two columns
        $leftColumn = @()
        $rightColumn = @()
        
        $metrics = @('RenderTime', 'FilterTime', 'MemoryUsage', 'FrameRate')
        $halfWidth = [int]($width / 2) - 2
        
        for ($i = 0; $i -lt $metrics.Count; $i++) {
            $metric = $metrics[$i]
            $counter = $this._performanceCounters[$metric]
            
            $line = switch ($metric) {
                'RenderTime' { "Render: $($counter.Average.ToString('0.1'))ms (max: $($counter.Max.ToString('0.1'))ms)" }
                'FilterTime' { "Filter: $($counter.Average.ToString('0.1'))ms" }
                'MemoryUsage' { "Memory: $($counter.Current.ToString('0.1'))MB (peak: $($counter.Peak.ToString('0.1'))MB)" }
                'FrameRate' { "FPS: $($counter.Current.ToString('0.1')) (avg: $($counter.Average.ToString('0.1')))" }
                default { "$metric: $($counter.Current.ToString('0.1'))" }
            }
            
            if ($line.Length -gt $halfWidth) {
                $line = $line.Substring(0, $halfWidth - 3) + '...'
            }
            
            if ($i % 2 -eq 0) {
                $leftColumn += $line.PadRight($halfWidth)
            } else {
                $rightColumn += $line.PadRight($halfWidth)
            }
        }
        
        # Render two columns
        for ($i = 0; $i -lt [Math]::Max($leftColumn.Count, $rightColumn.Count); $i++) {
            $left = if ($i -lt $leftColumn.Count) { $leftColumn[$i] } else { ' ' * $halfWidth }
            $right = if ($i -lt $rightColumn.Count) { $rightColumn[$i] } else { '' }
            $sb.AppendLine("$left  $right")
        }
        
        $sb.AppendLine()
        
        # Task statistics
        $taskCounter = $this._performanceCounters['TaskCount']
        $sb.AppendLine("Tasks: $($taskCounter.Current) total, $($taskCounter.Filtered) filtered (peak: $($taskCounter.Peak))")
        
        # Cache statistics
        $cacheCounter = $this._performanceCounters['CacheHitRate']
        if ($cacheCounter.Current -gt 0) {
            $sb.AppendLine("Cache Hit Rate: $($cacheCounter.Current.ToString('0.1'))% (avg: $($cacheCounter.Average.ToString('0.1'))%)")
        }
        
        return $sb.ToString()
    }
    
    [string] RenderPerformanceGraph([string]$metric, [int]$width = 60, [int]$height = 10) {
        $sb = [System.Text.StringBuilder]::new()
        
        # Get recent data points for the metric
        $recentData = $this._performanceHistory | 
                     Where-Object { $_.Metric -eq $metric -and $_.Timestamp -gt ([datetime]::Now.AddMinutes(-5)) } |
                     Sort-Object Timestamp |
                     Select-Object -Last $width
        
        if ($recentData.Count -lt 2) {
            return "Insufficient data for $metric graph"
        }
        
        $values = $recentData | ForEach-Object { $_.Value }
        $minValue = ($values | Measure-Object -Minimum).Minimum
        $maxValue = ($values | Measure-Object -Maximum).Maximum
        $range = $maxValue - $minValue
        
        if ($range -eq 0) {
            $range = $maxValue * 0.1  # 10% range for flat lines
            $minValue = $maxValue - $range
        }
        
        $sb.AppendLine("$metric (${minValue:0.1} - ${maxValue:0.1})")
        $sb.AppendLine('┌' + ('─' * ($width - 2)) + '┐')
        
        # Render graph lines from top to bottom
        for ($row = $height - 1; $row -ge 0; $row--) {
            $line = '│'
            
            for ($col = 0; $col -lt [Math]::Min($width - 2, $recentData.Count); $col++) {
                $value = $values[$col]
                $normalizedValue = if ($range -gt 0) { ($value - $minValue) / $range } else { 0.5 }
                $pixelRow = [int]($normalizedValue * ($height - 1))
                
                if ($pixelRow -eq $row) {
                    $line += '█'
                } elseif ($pixelRow -gt $row) {
                    $line += '▄'
                } else {
                    $line += ' '
                }
            }
            
            # Pad remaining width
            $line += ' ' * (($width - 2) - [Math]::Min($width - 2, $recentData.Count))
            $line += '│'
            $sb.AppendLine($line)
        }
        
        $sb.AppendLine('└' + ('─' * ($width - 2)) + '┘')
        
        return $sb.ToString()
    }
    
    [string] RenderDetailedMetrics() {
        $sb = [System.Text.StringBuilder]::new()
        
        $sb.AppendLine('Detailed Performance Metrics:')
        $sb.AppendLine('═' * 50)
        
        foreach ($metric in $this._performanceCounters.Keys | Sort-Object) {
            $counter = $this._performanceCounters[$metric]
            $threshold = $this._thresholds[$metric]
            
            $sb.AppendLine("$metric:")
            $sb.AppendLine("  Current: $($counter.Current.ToString('0.00'))")
            $sb.AppendLine("  Average: $($counter.Average.ToString('0.00'))")
            if ($counter.Max -gt 0) {
                $sb.AppendLine("  Maximum: $($counter.Max.ToString('0.00'))")
            }
            if ($counter.Count -gt 0) {
                $sb.AppendLine("  Sample Count: $($counter.Count)")
            }
            if ($threshold) {
                $sb.AppendLine("  Thresholds: Warning > $($threshold.Warning), Critical > $($threshold.Critical)")
            }
            $sb.AppendLine()
        }
        
        return $sb.ToString()
    }
    
    [void] StartProgressIndicator([string]$operation, [int]$totalSteps) {
        $this._progressState = @{
            Operation = $operation
            TotalSteps = $totalSteps
            CurrentStep = 0
            StartTime = [datetime]::Now
        }
    }
    
    [void] UpdateProgress([int]$currentStep, [string]$status = '') {
        if (-not $this._progressState) { return }
        
        $this._progressState.CurrentStep = $currentStep
        $this._progressState.Status = $status
        
        # Calculate ETA
        $elapsed = [datetime]::Now - $this._progressState.StartTime
        if ($currentStep -gt 0) {
            $timePerStep = $elapsed.TotalMilliseconds / $currentStep
            $remainingSteps = $this._progressState.TotalSteps - $currentStep
            $eta = [timespan]::FromMilliseconds($timePerStep * $remainingSteps)
            $this._progressState.ETA = $eta
        }
    }
    
    [string] RenderProgressIndicator([int]$width = 50) {
        if (-not $this._progressState) {
            return ''
        }
        
        $progress = $this._progressState
        $percentage = if ($progress.TotalSteps -gt 0) { 
            ($progress.CurrentStep / $progress.TotalSteps) * 100 
        } else { 
            0 
        }
        
        $barWidth = $width - 20  # Leave room for percentage and numbers
        $filledWidth = [int](($percentage / 100) * $barWidth)
        $emptyWidth = $barWidth - $filledWidth
        
        $bar = '[' + ('█' * $filledWidth) + ('░' * $emptyWidth) + ']'
        $percentStr = "$($percentage.ToString('0.1'))%"
        $countStr = "$($progress.CurrentStep)/$($progress.TotalSteps)"
        
        $line1 = "$($progress.Operation): $bar $percentStr"
        
        $line2 = "$countStr"
        if ($progress.ETA -and $progress.ETA.TotalSeconds -gt 1) {
            $etaStr = if ($progress.ETA.TotalMinutes -gt 1) {
                "$([int]$progress.ETA.TotalMinutes)m $($progress.ETA.Seconds)s"
            } else {
                "$([int]$progress.ETA.TotalSeconds)s"
            }
            $line2 += " | ETA: $etaStr"
        }
        
        if (-not [string]::IsNullOrEmpty($progress.Status)) {
            $line2 += " | $($progress.Status)"
        }
        
        return "$line1`n$line2"
    }
    
    [void] CompleteProgress() {
        $this._progressState = $null
    }
    
    [hashtable] GetPerformanceReport() {
        return @{
            Timestamp = [datetime]::Now
            HealthStatus = $this.GetHealthStatus()
            Counters = $this._performanceCounters
            HistoryCount = $this._performanceHistory.Count
            SystemHealth = $this.CalculateSystemHealth()
        }
    }
    
    hidden [double] CalculateSystemHealth() {
        $healthScore = 100.0
        
        foreach ($metric in @('RenderTime', 'MemoryUsage', 'FrameRate')) {
            if (-not $this._performanceCounters.ContainsKey($metric)) { continue }
            if (-not $this._thresholds.ContainsKey($metric)) { continue }
            
            $counter = $this._performanceCounters[$metric]
            $threshold = $this._thresholds[$metric]
            $value = $counter.Average
            
            if ($metric -eq 'FrameRate') {
                # Higher is better
                if ($value -lt $threshold.Critical) {
                    $healthScore -= 30
                } elseif ($value -lt $threshold.Warning) {
                    $healthScore -= 10
                }
            } else {
                # Lower is better
                if ($value -gt $threshold.Critical) {
                    $healthScore -= 30
                } elseif ($value -gt $threshold.Warning) {
                    $healthScore -= 10
                }
            }
        }
        
        return [Math]::Max(0, $healthScore)
    }
    
    [void] ResetCounters() {
        foreach ($counter in $this._performanceCounters.Values) {
            $counter.Current = 0
            $counter.Average = 0
            $counter.Max = 0
            $counter.Count = 0
        }
        $this._performanceHistory.Clear()
    }
}
```

## System 28: Error Recovery Interface System

Complete error recovery and TaskWarrior failure handling system.

```powershell
class ErrorRecoverySystem {
    hidden [hashtable] $_errorHandlers = @{}
    hidden [System.Collections.Generic.List[hashtable]] $_errorHistory = [System.Collections.Generic.List[hashtable]]::new()
    hidden [int] $_maxErrorHistory = 50
    hidden [hashtable] $_recoveryStrategies = @{}
    hidden [hashtable] $_errorCounts = @{}
    hidden [Logger] $_logger = $null
    
    ErrorRecoverySystem([Logger]$logger = $null) {
        $this._logger = $logger
        $this.InitializeErrorHandlers()
        $this.InitializeRecoveryStrategies()
    }
    
    hidden [void] InitializeErrorHandlers() {
        $this._errorHandlers = @{
            'TaskWarriorNotFound' = { param($error) return $this.HandleTaskWarriorNotFound($error) }
            'TaskWarriorDataCorruption' = { param($error) return $this.HandleDataCorruption($error) }
            'TaskWarriorCommandFailure' = { param($error) return $this.HandleCommandFailure($error) }
            'TaskWarriorPermissionDenied' = { param($error) return $this.HandlePermissionError($error) }
            'InvalidFilterSyntax' = { param($error) return $this.HandleInvalidFilter($error) }
            'TaskNotFound' = { param($error) return $this.HandleTaskNotFound($error) }
            'ConfigurationError' = { param($error) return $this.HandleConfigError($error) }
            'RenderingError' = { param($error) return $this.HandleRenderingError($error) }
            'MemoryExhaustion' = { param($error) return $this.HandleMemoryError($error) }
            'TerminalError' = { param($error) return $this.HandleTerminalError($error) }
        }
    }
    
    hidden [void] InitializeRecoveryStrategies() {
        $this._recoveryStrategies = @{
            'TaskWarriorNotFound' = @{
                AutoRecover = $false
                UserActionRequired = $true
                ShowDiagnostics = $true
                FallbackMode = $false
            }
            'TaskWarriorDataCorruption' = @{
                AutoRecover = $false
                UserActionRequired = $true
                ShowDiagnostics = $true
                FallbackMode = $true
            }
            'TaskWarriorCommandFailure' = @{
                AutoRecover = $true
                MaxRetries = 3
                RetryDelay = 1000
                FallbackMode = $false
            }
            'RenderingError' = @{
                AutoRecover = $true
                MaxRetries = 2
                FallbackMode = $true
                SafeMode = $true
            }
        }
    }
    
    [hashtable] HandleError([string]$errorType, [hashtable]$errorDetails) {
        # Record error
        $errorEntry = @{
            Type = $errorType
            Details = $errorDetails
            Timestamp = [datetime]::Now
            RecoveryAttempted = $false
            Resolved = $false
        }
        
        $this._errorHistory.Add($errorEntry)
        
        # Limit history size
        while ($this._errorHistory.Count -gt $this._maxErrorHistory) {
            $this._errorHistory.RemoveAt(0)
        }
        
        # Update error counts
        if (-not $this._errorCounts.ContainsKey($errorType)) {
            $this._errorCounts[$errorType] = 0
        }
        $this._errorCounts[$errorType]++
        
        # Log the error
        if ($this._logger) {
            $this._logger.Error("Error occurred: $errorType", $errorDetails.Exception)
        }
        
        # Attempt recovery
        if ($this._errorHandlers.ContainsKey($errorType)) {
            $errorEntry.RecoveryAttempted = $true
            return $this._errorHandlers[$errorType].Invoke($errorDetails)
        } else {
            return $this.HandleGenericError($errorDetails)
        }
    }
    
    hidden [hashtable] HandleTaskWarriorNotFound([hashtable]$errorDetails) {
        return @{
            Success = $false
            UserMessage = "TaskWarrior not found. Please install TaskWarrior and ensure 'task' is in your PATH."
            TechnicalDetails = "Could not locate TaskWarrior executable. Check PATH environment variable."
            SuggestedActions = @(
                "Install TaskWarrior from https://taskwarrior.org",
                "Ensure 'task' command is available in PATH",
                "Restart the application after installation"
            )
            RequiresUserAction = $true
            CanContinue = $false
            DiagnosticInfo = $this.GetTaskWarriorDiagnostics()
        }
    }
    
    hidden [hashtable] HandleDataCorruption([hashtable]$errorDetails) {
        return @{
            Success = $false
            UserMessage = "TaskWarrior data appears corrupted. Please run 'task diagnostics' to check your data."
            TechnicalDetails = "Invalid JSON or malformed data received from TaskWarrior export command."
            SuggestedActions = @(
                "Run 'task diagnostics' in a terminal to check data integrity",
                "Consider backing up and rebuilding TaskWarrior database",
                "Check .taskrc file for configuration errors"
            )
            RequiresUserAction = $true
            CanContinue = $true
            FallbackMode = $true
            DiagnosticInfo = $this.GetDataDiagnostics()
        }
    }
    
    hidden [hashtable] HandleCommandFailure([hashtable]$errorDetails) {
        $strategy = $this._recoveryStrategies['TaskWarriorCommandFailure']
        
        # Check if we should retry
        $errorKey = "$($errorDetails.Command)_$($errorDetails.Arguments -join '_')"
        $retryCount = $errorDetails.RetryCount ?? 0
        
        if ($strategy.AutoRecover -and $retryCount -lt $strategy.MaxRetries) {
            # Wait before retry
            Start-Sleep -Milliseconds $strategy.RetryDelay
            
            return @{
                Success = $false
                Retry = $true
                RetryCount = $retryCount + 1
                UserMessage = "TaskWarrior command failed. Retrying... ($($retryCount + 1)/$($strategy.MaxRetries))"
                TechnicalDetails = $errorDetails.ErrorMessage
                CanContinue = $true
            }
        }
        
        # Max retries exceeded or non-recoverable
        return @{
            Success = $false
            UserMessage = "TaskWarrior command failed: $($errorDetails.ErrorMessage)"
            TechnicalDetails = "Command: $($errorDetails.Command) $($errorDetails.Arguments -join ' ')"
            SuggestedActions = @(
                "Check TaskWarrior installation",
                "Verify command syntax",
                "Check .taskrc configuration"
            )
            RequiresUserAction = $false
            CanContinue = $true
        }
    }
    
    hidden [hashtable] HandlePermissionError([hashtable]$errorDetails) {
        return @{
            Success = $false
            UserMessage = "Permission denied accessing TaskWarrior files. Check file permissions."
            TechnicalDetails = "Access denied to: $($errorDetails.FilePath)"
            SuggestedActions = @(
                "Check file permissions on TaskWarrior data directory",
                "Ensure current user has read/write access",
                "Consider running with elevated privileges if necessary"
            )
            RequiresUserAction = $true
            CanContinue = $true
            ReadOnlyMode = $true
        }
    }
    
    hidden [hashtable] HandleInvalidFilter([hashtable]$errorDetails) {
        return @{
            Success = $false
            UserMessage = "Invalid filter syntax: $($errorDetails.FilterExpression)"
            TechnicalDetails = $errorDetails.ParseError
            SuggestedActions = @(
                "Check filter syntax against TaskWarrior documentation",
                "Use simpler filter expressions",
                "Test filter with 'task <filter> count' command"
            )
            RequiresUserAction = $false
            CanContinue = $true
            ClearFilter = $true
        }
    }
    
    hidden [hashtable] HandleTaskNotFound([hashtable]$errorDetails) {
        return @{
            Success = $false
            UserMessage = "Task $($errorDetails.TaskId) not found. It may have been deleted or modified."
            TechnicalDetails = "Task ID not found in current dataset"
            SuggestedActions = @(
                "Refresh task list to get latest data",
                "Check if task was completed or deleted in another session"
            )
            RequiresUserAction = $false
            CanContinue = $true
            RefreshData = $true
        }
    }
    
    hidden [hashtable] HandleConfigError([hashtable]$errorDetails) {
        return @{
            Success = $false
            UserMessage = "Configuration error in .taskrc file."
            TechnicalDetails = $errorDetails.ConfigError
            SuggestedActions = @(
                "Check .taskrc file for syntax errors",
                "Validate configuration with 'task config'",
                "Backup and reset configuration if necessary"
            )
            RequiresUserAction = $true
            CanContinue = $true
            UseDefaults = $true
        }
    }
    
    hidden [hashtable] HandleRenderingError([hashtable]$errorDetails) {
        $strategy = $this._recoveryStrategies['RenderingError']
        
        return @{
            Success = $false
            UserMessage = "Display error occurred. Switching to safe mode."
            TechnicalDetails = $errorDetails.RenderError
            SuggestedActions = @(
                "Terminal display will use simplified rendering",
                "Check terminal compatibility",
                "Consider resizing terminal window"
            )
            RequiresUserAction = $false
            CanContinue = $true
            SafeMode = $strategy.SafeMode
            FallbackRendering = $true
        }
    }
    
    hidden [hashtable] HandleMemoryError([hashtable]$errorDetails) {
        return @{
            Success = $false
            UserMessage = "Memory exhaustion detected. Reducing memory usage."
            TechnicalDetails = "Working set: $($errorDetails.MemoryUsage)MB"
            SuggestedActions = @(
                "Reducing cache sizes",
                "Limiting task history",
                "Consider filtering large task lists"
            )
            RequiresUserAction = $false
            CanContinue = $true
            ReduceMemoryUsage = $true
            ClearCaches = $true
        }
    }
    
    hidden [hashtable] HandleTerminalError([hashtable]$errorDetails) {
        return @{
            Success = $false
            UserMessage = "Terminal compatibility issue detected."
            TechnicalDetails = $errorDetails.TerminalError
            SuggestedActions = @(
                "Using fallback display mode",
                "Consider using a different terminal emulator",
                "Check terminal size requirements (minimum 80x24)"
            )
            RequiresUserAction = $false
            CanContinue = $true
            FallbackMode = $true
            BasicRendering = $true
        }
    }
    
    hidden [hashtable] HandleGenericError([hashtable]$errorDetails) {
        return @{
            Success = $false
            UserMessage = "An unexpected error occurred."
            TechnicalDetails = $errorDetails.Exception.Message
            SuggestedActions = @(
                "Try refreshing the application",
                "Check for TaskWarrior updates",
                "Report this issue if it persists"
            )
            RequiresUserAction = $false
            CanContinue = $true
        }
    }
    
    [string] RenderErrorDialog([hashtable]$errorResult) {
        $sb = [System.Text.StringBuilder]::new()
        
        $sb.AppendLine('╔════════════════════════════════════════════════════════════════════════╗')
        $sb.AppendLine('║                                 ERROR                                  ║')
        $sb.AppendLine('╠════════════════════════════════════════════════════════════════════════╣')
        
        # Wrap long messages
        $wrappedMessage = $this.WrapText($errorResult.UserMessage, 68)
        foreach ($line in $wrappedMessage) {
            $sb.AppendLine("║ $($line.PadRight(68)) ║")
        }
        
        if (-not [string]::IsNullOrEmpty($errorResult.TechnicalDetails)) {
            $sb.AppendLine('║                                                                        ║')
            $sb.AppendLine('║ Technical Details:                                                     ║')
            $wrappedDetails = $this.WrapText($errorResult.TechnicalDetails, 68)
            foreach ($line in $wrappedDetails) {
                $sb.AppendLine("║ $($line.PadRight(68)) ║")
            }
        }
        
        if ($errorResult.SuggestedActions -and $errorResult.SuggestedActions.Count -gt 0) {
            $sb.AppendLine('║                                                                        ║')
            $sb.AppendLine('║ Suggested Actions:                                                     ║')
            for ($i = 0; $i -lt $errorResult.SuggestedActions.Count; $i++) {
                $action = "$($i + 1). $($errorResult.SuggestedActions[$i])"
                $wrappedAction = $this.WrapText($action, 68)
                foreach ($line in $wrappedAction) {
                    $sb.AppendLine("║ $($line.PadRight(68)) ║")
                }
            }
        }
        
        $sb.AppendLine('║                                                                        ║')
        
        if ($errorResult.CanContinue) {
            $sb.AppendLine('║ Press any key to continue or Escape to exit...                        ║')
        } else {
            $sb.AppendLine('║ Press any key to exit...                                              ║')
        }
        
        $sb.AppendLine('╚════════════════════════════════════════════════════════════════════════╝')
        
        return $sb.ToString()
    }
    
    [string] RenderErrorSummary() {
        if ($this._errorHistory.Count -eq 0) {
            return 'No errors recorded'
        }
        
        $sb = [System.Text.StringBuilder]::new()
        $sb.AppendLine('Error Summary:')
        $sb.AppendLine('═' * 40)
        
        # Error counts by type
        foreach ($errorType in $this._errorCounts.Keys | Sort-Object) {
            $count = $this._errorCounts[$errorType]
            $sb.AppendLine("$errorType: $count")
        }
        
        $sb.AppendLine()
        $sb.AppendLine('Recent Errors:')
        $recentErrors = $this._errorHistory | Sort-Object Timestamp -Descending | Select-Object -First 5
        
        foreach ($error in $recentErrors) {
            $timeAgo = $this.FormatTimeAgo($error.Timestamp)
            $resolved = if ($error.Resolved) { '✓' } else { '✗' }
            $sb.AppendLine("$resolved $($error.Type) - $timeAgo")
        }
        
        return $sb.ToString()
    }
    
    hidden [string[]] WrapText([string]$text, [int]$width) {
        if ([string]::IsNullOrEmpty($text) -or $width -le 0) {
            return @($text)
        }
        
        $lines = @()
        $words = $text -split '\s+'
        $currentLine = ''
        
        foreach ($word in $words) {
            $testLine = if ($currentLine) { "$currentLine $word" } else { $word }
            
            if ($testLine.Length -le $width) {
                $currentLine = $testLine
            } else {
                if ($currentLine) {
                    $lines += $currentLine
                    $currentLine = $word
                } else {
                    # Word is longer than width, break it
                    while ($word.Length -gt $width) {
                        $lines += $word.Substring(0, $width)
                        $word = $word.Substring($width)
                    }
                    $currentLine = $word
                }
            }
        }
        
        if ($currentLine) {
            $lines += $currentLine
        }
        
        return $lines
    }
    
    hidden [string] FormatTimeAgo([datetime]$timestamp) {
        $age = [datetime]::Now - $timestamp
        
        if ($age.Days -gt 0) {
            return "$($age.Days)d ago"
        } elseif ($age.Hours -gt 0) {
            return "$($age.Hours)h ago"
        } elseif ($age.Minutes -gt 0) {
            return "$($age.Minutes)m ago"
        } else {
            return "just now"
        }
    }
    
    hidden [hashtable] GetTaskWarriorDiagnostics() {
        $diagnostics = @{}
        
        try {
            # Check if task command exists
            $taskCmd = Get-Command 'task' -ErrorAction SilentlyContinue
            $diagnostics.TaskWarriorFound = $null -ne $taskCmd
            
            if ($taskCmd) {
                $diagnostics.TaskWarriorPath = $taskCmd.Source
                
                # Get version
                try {
                    $versionOutput = & task --version 2>&1
                    $diagnostics.Version = $versionOutput
                } catch {
                    $diagnostics.VersionError = $_.Exception.Message
                }
                
                # Check data directory
                try {
                    $dataOutput = & task _get rc.data.location 2>&1
                    $diagnostics.DataLocation = $dataOutput
                    $diagnostics.DataLocationExists = Test-Path $dataOutput
                } catch {
                    $diagnostics.DataLocationError = $_.Exception.Message
                }
            }
        } catch {
            $diagnostics.DiagnosticError = $_.Exception.Message
        }
        
        return $diagnostics
    }
    
    hidden [hashtable] GetDataDiagnostics() {
        $diagnostics = @{}
        
        try {
            # Try to get task count
            $countOutput = & task count 2>&1
            if ($LASTEXITCODE -eq 0) {
                $diagnostics.TaskCount = [int]$countOutput
                $diagnostics.DataAccessible = $true
            } else {
                $diagnostics.DataAccessible = $false
                $diagnostics.CountError = $countOutput
            }
            
            # Try basic export to check data integrity
            $exportOutput = & task export | ConvertFrom-Json 2>&1
            if ($LASTEXITCODE -eq 0) {
                $diagnostics.ExportWorking = $true
                $diagnostics.ExportedTasks = $exportOutput.Count
            } else {
                $diagnostics.ExportWorking = $false
                $diagnostics.ExportError = $exportOutput
            }
        } catch {
            $diagnostics.DiagnosticError = $_.Exception.Message
        }
        
        return $diagnostics
    }
    
    [void] MarkErrorResolved([int]$errorIndex) {
        if ($errorIndex -ge 0 -and $errorIndex -lt $this._errorHistory.Count) {
            $this._errorHistory[$errorIndex].Resolved = $true
        }
    }
    
    [void] ClearErrorHistory() {
        $this._errorHistory.Clear()
        $this._errorCounts.Clear()
    }
    
    [hashtable] GetErrorStatistics() {
        $totalErrors = $this._errorHistory.Count
        $recentErrors = ($this._errorHistory | Where-Object { $_.Timestamp -gt ([datetime]::Now.AddHours(-24)) }).Count
        $resolvedErrors = ($this._errorHistory | Where-Object { $_.Resolved }).Count
        
        return @{
            TotalErrors = $totalErrors
            RecentErrors = $recentErrors
            ResolvedErrors = $resolvedErrors
            ErrorTypes = $this._errorCounts.Keys.Count
            MostCommonError = if ($this._errorCounts.Count -gt 0) { 
                ($this._errorCounts.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1).Key 
            } else { 
                'None' 
            }
        }
    }
}
```

### 6. Reactive Architecture with Event Subscriptions

Event-driven system for coordinating state changes and render updates:

```powershell
class RenderEventCoordinator {
    hidden [hashtable] $_eventSubscriptions = @{}
    hidden [hashtable] $_eventHistory = @{}
    hidden [int] $_maxHistorySize = 100
    hidden [Logger] $_logger = $null
    
    RenderEventCoordinator([Logger]$logger = $null) {
        $this._logger = $logger
        $this.InitializeEventTypes()
    }
    
    # Initialize standard event types for TaskWarrior-TUI
}
```

---

# PART 3: DETAILED SPECIFICATIONS

## API Contracts Between Systems

### Core System Interfaces

```powershell
# Primary interface for all render systems
interface IRenderSystem {
    [string] Render([hashtable]$context)
    [void] Initialize([hashtable]$config)
    [bool] IsHealthy()
    [hashtable] GetMetrics()
    [void] Cleanup()
}

# Data provider interface
interface IDataProvider {
    [Task[]] GetTasks([hashtable]$filter = $null)
    [Task] GetTask([string]$uuid)
    [hashtable] ExecuteCommand([string]$command, [hashtable]$parameters = @{})
    [bool] IsAvailable()
    [string] GetVersion()
}

# Cache interface for performance systems
interface ICacheProvider {
    [object] Get([string]$key)
    [void] Set([string]$key, [object]$value, [int]$ttlSeconds = 300)
    [void] Remove([string]$key)
    [void] Clear()
    [hashtable] GetStats()
    [double] GetHitRate()
}

# Event system interface
interface IEventPublisher {
    [void] Subscribe([string]$eventType, [scriptblock]$handler)
    [void] Unsubscribe([string]$eventType, [scriptblock]$handler)
    [void] Publish([string]$eventType, [hashtable]$eventData)
    [void] PublishAsync([string]$eventType, [hashtable]$eventData)
}

# Configuration interface
interface IConfigurationProvider {
    [object] GetValue([string]$key, [object]$defaultValue = $null)
    [void] SetValue([string]$key, [object]$value)
    [hashtable] GetSection([string]$sectionName)
    [void] Reload()
    [bool] IsValid()
}
```

### System Integration Contracts

```powershell
# Contract between VirtualScrollingEngine and DataProvider
class VirtualScrollContract {
    static [hashtable] $RequiredMethods = @{
        'GetTasks' = @{
            Parameters = @('filter', 'offset', 'limit', 'sortBy')
            ReturnType = 'Task[]'
            Timeout = 5000
        }
        'GetTaskCount' = @{
            Parameters = @('filter')
            ReturnType = 'int'
            Timeout = 1000
        }
    }
    
    static [hashtable] $RequiredEvents = @{
        'TasksChanged' = @{ Handler = 'OnTasksChanged'; Priority = 'High' }
        'FilterChanged' = @{ Handler = 'OnFilterChanged'; Priority = 'Medium' }
    }
    
    static [hashtable] $PerformanceRequirements = @{
        'MaxRenderTime' = 50    # milliseconds
        'MaxScrollLatency' = 100 # milliseconds
        'MinFrameRate' = 30     # FPS
    }
}

# Contract between RenderEngine and ThemeManager
class RenderThemeContract {
    static [hashtable] $RequiredMethods = @{
        'GetColor' = @{
            Parameters = @('colorKey')
            ReturnType = 'string'
            CacheTime = 60
        }
        'GetBgColor' = @{
            Parameters = @('colorKey')
            ReturnType = 'string'
            CacheTime = 60
        }
        'ApplyTheme' = @{
            Parameters = @('themeName')
            ReturnType = 'bool'
        }
    }
    
    static [string[]] $RequiredColorKeys = @(
        'text.primary', 'text.secondary', 'text.error', 'text.warning',
        'background.primary', 'background.selected', 'background.hover',
        'border.normal', 'border.focused', 'border.error',
        'urgency.high', 'urgency.medium', 'urgency.low',
        'status.pending', 'status.completed', 'status.deleted'
    )
}

# Contract between FilterEngine and TaskProvider
class FilterContract {
    static [hashtable] $SupportedOperators = @{
        'equals' = @{ Symbol = ':'; Description = 'Exact match' }
        'contains' = @{ Symbol = '~'; Description = 'Contains text' }
        'before' = @{ Symbol = '.before:'; Description = 'Date before' }
        'after' = @{ Symbol = '.after:'; Description = 'Date after' }
        'over' = @{ Symbol = '.over:'; Description = 'Numeric greater than' }
        'under' = @{ Symbol = '.under:'; Description = 'Numeric less than' }
    }
    
    static [string[]] $SupportedAttributes = @(
        'description', 'project', 'priority', 'status', 'urgency',
        'due', 'scheduled', 'entry', 'modified', 'depends', 'tags'
    )
    
    static [hashtable] $ValidationRules = @{
        'MaxFilterLength' = 500
        'MaxFilterDepth' = 10
        'TimeoutMs' = 2000
    }
}
```

### Error Handling Contracts

```powershell
# Standardized error response format
class ErrorContract {
    static [hashtable] CreateErrorResponse([string]$errorType, [string]$message, [object]$details = $null) {
        return @{
            Success = $false
            ErrorType = $errorType
            Message = $message
            Details = $details
            Timestamp = [datetime]::Now
            CorrelationId = [guid]::NewGuid().ToString()
            Retryable = $false
            SuggestedActions = @()
        }
    }
    
    static [string[]] $StandardErrorTypes = @(
        'TaskWarriorNotFound', 'TaskWarriorCommandFailure', 'TaskWarriorDataCorruption',
        'InvalidFilter', 'TaskNotFound', 'ConfigurationError', 'RenderingError',
        'MemoryExhaustion', 'TerminalError', 'NetworkError', 'PermissionDenied'
    )
    
    static [hashtable] $RecoveryStrategies = @{
        'TaskWarriorCommandFailure' = @{ MaxRetries = 3; BackoffMs = 1000; Exponential = $true }
        'RenderingError' = @{ MaxRetries = 2; FallbackMode = $true }
        'MemoryExhaustion' = @{ ClearCaches = $true; ReduceMemory = $true }
        'ConfigurationError' = @{ UseDefaults = $true; ValidateConfig = $true }
    }
}
```

## State Machine Specifications

### Application State Machine

```powershell
class ApplicationStateMachine {
    enum AppState {
        Initializing
        Loading
        Ready
        Filtering
        Sorting
        Rendering
        Error
        Shutdown
    }
    
    static [hashtable] $StateTransitions = @{
        'Initializing' = @('Loading', 'Error')
        'Loading' = @('Ready', 'Error')
        'Ready' = @('Filtering', 'Sorting', 'Rendering', 'Error', 'Shutdown')
        'Filtering' = @('Loading', 'Ready', 'Error')
        'Sorting' = @('Ready', 'Error')
        'Rendering' = @('Ready', 'Error')
        'Error' = @('Ready', 'Shutdown')
        'Shutdown' = @()
    }
    
    static [hashtable] $StateActions = @{
        'Initializing' = @{
            OnEnter = { param($context) $context.InitializeSystems() }
            OnExit = { param($context) $context.ValidateInitialization() }
        }
        'Loading' = @{
            OnEnter = { param($context) $context.StartProgressIndicator('Loading tasks...') }
            OnExit = { param($context) $context.CompleteProgress() }
        }
        'Ready' = @{
            OnEnter = { param($context) $context.EnableUserInput() }
            OnExit = { param($context) $context.DisableUserInput() }
        }
        'Error' = @{
            OnEnter = { param($context) $context.ShowErrorDialog() }
            OnExit = { param($context) $context.ClearError() }
        }
    }
    
    static [hashtable] $StateTimeouts = @{
        'Initializing' = 10000  # 10 seconds
        'Loading' = 30000       # 30 seconds
        'Filtering' = 5000      # 5 seconds
        'Sorting' = 3000        # 3 seconds
        'Rendering' = 1000      # 1 second
    }
}
```

### Task Edit State Machine

```powershell
class TaskEditStateMachine {
    enum EditState {
        Viewing
        EditingField
        Validating
        Saving
        Error
        Cancelled
        Completed
    }
    
    static [hashtable] $StateTransitions = @{
        'Viewing' = @('EditingField', 'Cancelled')
        'EditingField' = @('Validating', 'Cancelled', 'Error')
        'Validating' = @('Saving', 'EditingField', 'Error')
        'Saving' = @('Completed', 'Error')
        'Error' = @('EditingField', 'Cancelled')
        'Cancelled' = @('Viewing')
        'Completed' = @('Viewing')
    }
    
    static [hashtable] $FieldValidationRules = @{
        'description' = @{
            Required = $true
            MaxLength = 200
            Validator = { param($value) -not [string]::IsNullOrWhiteSpace($value) }
        }
        'project' = @{
            Required = $false
            Pattern = '^[a-zA-Z0-9._-]+$'
            Validator = { param($value) $value -match '^[a-zA-Z0-9._-]+$' }
        }
        'priority' = @{
            Required = $false
            AllowedValues = @('H', 'M', 'L', '')
            Validator = { param($value) $value -in @('H', 'M', 'L', '') }
        }
        'due' = @{
            Required = $false
            Type = 'DateTime'
            Validator = { param($value) 
                try { [datetime]::Parse($value); return $true } 
                catch { return $false }
            }
        }
    }
}
```

## Performance Benchmarks and Acceptance Criteria

```powershell
class PerformanceBenchmarks {
    static [hashtable] $RenderingBenchmarks = @{
        'TaskListRender' = @{
            Target = 30         # ms
            Warning = 50        # ms
            Critical = 100      # ms
            TestData = '1000 tasks'
        }
        'FilterApplication' = @{
            Target = 100        # ms
            Warning = 250       # ms
            Critical = 500      # ms
            TestData = '10000 tasks with complex filter'
        }
        'VirtualScrolling' = @{
            Target = 16         # ms (60 FPS)
            Warning = 33        # ms (30 FPS)
            Critical = 100      # ms (10 FPS)
            TestData = 'Scrolling through 50000 tasks'
        }
        'TaskCreate' = @{
            Target = 200        # ms
            Warning = 500       # ms
            Critical = 1000     # ms
            TestData = 'Create task with validation'
        }
    }
    
    static [hashtable] $MemoryBenchmarks = @{
        'BaselineMemory' = @{
            Target = 50         # MB
            Warning = 100       # MB
            Critical = 200      # MB
            TestData = 'Empty application'
        }
        'TaskListMemory' = @{
            Target = 100        # MB
            Warning = 200       # MB
            Critical = 500      # MB
            TestData = '10000 loaded tasks'
        }
        'CacheEfficiency' = @{
            Target = 90         # % hit rate
            Warning = 75        # % hit rate
            Critical = 50       # % hit rate
            TestData = 'Typical usage patterns'
        }
    }
    
    static [hashtable] $ResponsivenessBenchmarks = @{
        'KeyboardLatency' = @{
            Target = 50         # ms
            Warning = 100       # ms
            Critical = 200      # ms
            TestData = 'Key press to screen update'
        }
        'NavigationSpeed' = @{
            Target = 100        # ms
            Warning = 200       # ms
            Critical = 500      # ms
            TestData = 'Screen to screen navigation'
        }
        'SearchResponse' = @{
            Target = 200        # ms
            Warning = 500       # ms
            Critical = 1000     # ms
            TestData = 'Search with live filtering'
        }
    }
    
    # Automated benchmark test framework
    static [hashtable] RunBenchmarks([hashtable]$testData) {
        $results = @{}
        
        foreach ($category in @('RenderingBenchmarks', 'MemoryBenchmarks', 'ResponsivenessBenchmarks')) {
            $results[$category] = @{}
            $benchmarks = [PerformanceBenchmarks]::$category
            
            foreach ($testName in $benchmarks.Keys) {
                $benchmark = $benchmarks[$testName]
                $testResult = [PerformanceBenchmarks]::RunSingleBenchmark($testName, $benchmark, $testData)
                $results[$category][$testName] = $testResult
            }
        }
        
        return $results
    }
    
    static [hashtable] RunSingleBenchmark([string]$testName, [hashtable]$benchmark, [hashtable]$testData) {
        $iterations = 10
        $measurements = @()
        
        for ($i = 0; $i -lt $iterations; $i++) {
            $measurement = [PerformanceBenchmarks]::MeasurePerformance($testName, $testData)
            $measurements += $measurement
        }
        
        $avgTime = ($measurements | Measure-Object -Average).Average
        $maxTime = ($measurements | Measure-Object -Maximum).Maximum
        $minTime = ($measurements | Measure-Object -Minimum).Minimum
        
        $status = if ($avgTime -le $benchmark.Target) {
            'Pass'
        } elseif ($avgTime -le $benchmark.Warning) {
            'Warning'
        } else {
            'Fail'
        }
        
        return @{
            TestName = $testName
            Status = $status
            AverageTime = $avgTime
            MaxTime = $maxTime
            MinTime = $minTime
            Target = $benchmark.Target
            Warning = $benchmark.Warning
            Critical = $benchmark.Critical
            Measurements = $measurements
        }
    }
    
    static [double] MeasurePerformance([string]$testName, [hashtable]$testData) {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        
        # Execute test based on test name
        switch ($testName) {
            'TaskListRender' {
                # Simulate task list rendering
                $tasks = $testData.Tasks
                $renderer = [TaskListRenderer]::new()
                $renderer.RenderTaskList($tasks)
            }
            'FilterApplication' {
                # Simulate filter application
                $tasks = $testData.Tasks
                $filter = $testData.Filter
                $filteredTasks = $tasks | Where-Object { $_.MatchesFilter($filter) }
            }
            # Add more test implementations...
        }
        
        $stopwatch.Stop()
        return $stopwatch.ElapsedMilliseconds
    }
}
```

## Detailed Error Scenarios and Test Cases

```powershell
class ErrorTestScenarios {
    static [hashtable] $TaskWarriorErrorScenarios = @{
        'TaskWarriorNotInstalled' = @{
            Setup = { Remove-Command 'task' -ErrorAction SilentlyContinue }
            ExpectedError = 'TaskWarriorNotFound'
            ExpectedRecovery = @{
                UserMessage = 'TaskWarrior not found*'
                CanContinue = $false
                SuggestedActions = @('Install TaskWarrior*')
            }
            TestCommands = @('task export', 'task add test', 'task count')
        }
        
        'CorruptedDataFile' = @{
            Setup = { 
                # Simulate corrupted pending.data
                "invalid json content" | Out-File -FilePath "~/.task/pending.data" -Force
            }
            ExpectedError = 'TaskWarriorDataCorruption'
            ExpectedRecovery = @{
                UserMessage = '*data appears corrupted*'
                CanContinue = $true
                FallbackMode = $true
            }
            TestCommands = @('task export')
        }
        
        'PermissionDenied' = @{
            Setup = {
                # Make task data directory read-only
                $dataDir = & task _get rc.data.location
                Set-ItemProperty -Path $dataDir -Name IsReadOnly -Value $true
            }
            ExpectedError = 'TaskWarriorPermissionDenied'
            ExpectedRecovery = @{
                UserMessage = '*Permission denied*'
                ReadOnlyMode = $true
            }
            TestCommands = @('task add test')
        }
        
        'InvalidConfiguration' = @{
            Setup = {
                # Add invalid config to .taskrc
                "invalid.config.line" | Add-Content -Path "~/.taskrc"
            }
            ExpectedError = 'ConfigurationError'
            ExpectedRecovery = @{
                UseDefaults = $true
                CanContinue = $true
            }
            TestCommands = @('task config')
        }
    }
    
    static [hashtable] $RenderingErrorScenarios = @{
        'TerminalTooSmall' = @{
            Setup = { 
                [Console]::SetWindowSize(20, 10)  # Too small
            }
            ExpectedError = 'TerminalError'
            ExpectedRecovery = @{
                FallbackMode = $true
                BasicRendering = $true
            }
            TestOperations = @('RenderTaskList', 'RenderMenus')
        }
        
        'UnicodeNotSupported' = @{
            Setup = {
                # Mock terminal without unicode support
                $env:LANG = 'C'
            }
            ExpectedError = 'RenderingError'
            ExpectedRecovery = @{
                SafeMode = $true
                FallbackRendering = $true
            }
            TestOperations = @('RenderBorders', 'RenderIcons')
        }
        
        'MemoryExhaustion' = @{
            Setup = {
                # Simulate high memory usage
                $largeArray = [byte[]]::new(500MB)
            }
            ExpectedError = 'MemoryExhaustion'
            ExpectedRecovery = @{
                ClearCaches = $true
                ReduceMemoryUsage = $true
            }
            TestOperations = @('LoadLargeTaskList', 'ApplyComplexFilter')
        }
    }
    
    static [hashtable] $FilterErrorScenarios = @{
        'InvalidSyntax' = @{
            TestFilters = @(
                'project:work and (', # Unclosed parenthesis
                'due.before:', # Missing value
                'invalid.operator.unknown:test', # Unknown operator
                '+tag and not (project:work', # Unclosed group
                'description~/[invalid regex' # Invalid regex
            )
            ExpectedError = 'InvalidFilterSyntax'
            ExpectedRecovery = @{
                ClearFilter = $true
                ShowSuggestions = $true
            }
        }
        
        'ComplexFilterTimeout' = @{
            TestFilters = @(
                ('project:work or ' * 1000) + 'status:pending', # Very long OR chain
                'description~/.{1000,}/' # Expensive regex
            )
            ExpectedError = 'FilterTimeout'
            ExpectedRecovery = @{
                SimplifyFilter = $true
                ShowWarning = $true
            }
        }
    }
    
    # Automated error scenario testing
    static [hashtable] RunErrorScenarioTests() {
        $results = @{}
        $scenarios = @('TaskWarriorErrorScenarios', 'RenderingErrorScenarios', 'FilterErrorScenarios')
        
        foreach ($scenarioCategory in $scenarios) {
            $results[$scenarioCategory] = @{}
            $categoryScenarios = [ErrorTestScenarios]::$scenarioCategory
            
            foreach ($scenarioName in $categoryScenarios.Keys) {
                $scenario = $categoryScenarios[$scenarioName]
                $testResult = [ErrorTestScenarios]::RunSingleErrorScenario($scenarioName, $scenario)
                $results[$scenarioCategory][$scenarioName] = $testResult
            }
        }
        
        return $results
    }
    
    static [hashtable] RunSingleErrorScenario([string]$scenarioName, [hashtable]$scenario) {
        $passed = $true
        $errors = @()
        
        try {
            # Setup the error condition
            if ($scenario.Setup) {
                $scenario.Setup.Invoke()
            }
            
            # Execute the operations that should trigger the error
            $operations = $scenario.TestCommands ?? $scenario.TestOperations ?? $scenario.TestFilters
            
            foreach ($operation in $operations) {
                try {
                    # Execute operation and check if expected error occurs
                    $result = [ErrorTestScenarios]::ExecuteOperation($operation)
                    
                    # Verify error was handled correctly
                    if (-not [ErrorTestScenarios]::ValidateErrorHandling($result, $scenario)) {
                        $passed = $false
                        $errors += "Operation '$operation' did not handle error as expected"
                    }
                } catch {
                    if ($_.Exception.Message -notlike "*$($scenario.ExpectedError)*") {
                        $passed = $false
                        $errors += "Unexpected error: $($_.Exception.Message)"
                    }
                }
            }
            
        } catch {
            $passed = $false
            $errors += "Test setup failed: $($_.Exception.Message)"
        } finally {
            # Cleanup
            [ErrorTestScenarios]::CleanupErrorScenario($scenarioName)
        }
        
        return @{
            ScenarioName = $scenarioName
            Passed = $passed
            Errors = $errors
            ExecutionTime = [datetime]::Now
        }
    }
    
    static [object] ExecuteOperation([string]$operation) {
        # Implementation would execute the actual operations
        # This is a placeholder for the test framework
        return $null
    }
    
    static [bool] ValidateErrorHandling([object]$result, [hashtable]$scenario) {
        # Implementation would validate that error handling matches expectations
        return $true
    }
    
    static [void] CleanupErrorScenario([string]$scenarioName) {
        # Implementation would clean up any test artifacts
    }
}
```
    [void] InitializeEventTypes() {
        $eventTypes = @(
            'TaskListChanged',
            'FilterChanged', 
            'SortOrderChanged',
            'ViewModeChanged',
            'SelectionChanged',
            'WindowResized',
            'ThemeChanged',
            'CommandModeEntered',
            'CommandModeExited',
            'RenderRequested',
            'StateUpdated',
            'ErrorOccurred'
        )
        
        foreach ($eventType in $eventTypes) {
            $this._eventSubscriptions[$eventType] = [System.Collections.Generic.List[hashtable]]::new()
        }
    }
    
    # Subscribe to events with callback
    [string] Subscribe([string]$eventType, [string]$subscriberId, [scriptblock]$callback) {
        if (-not $this._eventSubscriptions.ContainsKey($eventType)) {
            throw "Unknown event type: $eventType"
        }
        
        $subscription = @{
            Id = [guid]::NewGuid().ToString()
            SubscriberId = $subscriberId
            EventType = $eventType
            Callback = $callback
            CreatedAt = [datetime]::Now
            CallCount = 0
        }
        
        $this._eventSubscriptions[$eventType].Add($subscription)
        
        if ($this._logger) {
            $this._logger.Debug("RenderEventCoordinator: $subscriberId subscribed to $eventType")
        }
        
        return $subscription.Id
    }
    
    # Unsubscribe from events
    [void] Unsubscribe([string]$subscriptionId) {
        foreach ($eventType in $this._eventSubscriptions.Keys) {
            $subscriptions = $this._eventSubscriptions[$eventType]
            for ($i = $subscriptions.Count - 1; $i -ge 0; $i--) {
                if ($subscriptions[$i].Id -eq $subscriptionId) {
                    $subscription = $subscriptions[$i]
                    $subscriptions.RemoveAt($i)
                    
                    if ($this._logger) {
                        $this._logger.Debug("RenderEventCoordinator: Unsubscribed $($subscription.SubscriberId) from $eventType")
                    }
                    return
                }
            }
        }
    }
    
    # Publish event to all subscribers
    [void] PublishEvent([string]$eventType, [hashtable]$eventData = @{}) {
        if (-not $this._eventSubscriptions.ContainsKey($eventType)) {
            if ($this._logger) {
                $this._logger.Warn("RenderEventCoordinator: Unknown event type: $eventType")
            }
            return
        }
        
        # Record event in history
        $this.RecordEvent($eventType, $eventData)
        
        $subscriptions = $this._eventSubscriptions[$eventType]
        $successCount = 0
        $errorCount = 0
        
        foreach ($subscription in $subscriptions) {
            try {
                # Invoke callback with event data
                $eventArgs = @{
                    EventType = $eventType
                    Data = $eventData
                    Timestamp = [datetime]::Now
                    SubscriberId = $subscription.SubscriberId
                }
                
                $subscription.Callback.Invoke($eventArgs)
                $subscription.CallCount++
                $successCount++
                
            } catch {
                $errorCount++
                if ($this._logger) {
                    $this._logger.Error("RenderEventCoordinator: Error in $($subscription.SubscriberId) handling $eventType", $_)
                }
            }
        }
        
        if ($this._logger) {
            $this._logger.Debug("RenderEventCoordinator: Published $eventType to $($subscriptions.Count) subscribers ($successCount success, $errorCount errors)")
        }
    }
    
    # Record event for debugging/history
    hidden [void] RecordEvent([string]$eventType, [hashtable]$eventData) {
        if (-not $this._eventHistory.ContainsKey($eventType)) {
            $this._eventHistory[$eventType] = [System.Collections.Generic.List[hashtable]]::new()
        }
        
        $history = $this._eventHistory[$eventType]
        $history.Add(@{
            Timestamp = [datetime]::Now
            EventType = $eventType
            Data = $eventData.Clone()
        })
        
        # Limit history size
        while ($history.Count -gt $this._maxHistorySize) {
            $history.RemoveAt(0)
        }
    }
    
    # Get subscription statistics
    [hashtable] GetSubscriptionStats() {
        $stats = @{
            EventTypes = $this._eventSubscriptions.Count
            TotalSubscriptions = 0
            SubscriptionsByType = @{}
        }
        
        foreach ($eventType in $this._eventSubscriptions.Keys) {
            $count = $this._eventSubscriptions[$eventType].Count
            $stats.SubscriptionsByType[$eventType] = $count
            $stats.TotalSubscriptions += $count
        }
        
        return $stats
    }
    
    # Get event history for debugging
    [hashtable[]] GetEventHistory([string]$eventType = $null, [int]$limit = 50) {
        $events = @()
        
        if ($eventType) {
            if ($this._eventHistory.ContainsKey($eventType)) {
                $events = $this._eventHistory[$eventType] | Select-Object -Last $limit
            }
        } else {
            # Get events from all types, sorted by timestamp
            foreach ($type in $this._eventHistory.Keys) {
                $events += $this._eventHistory[$type]
            }
            $events = $events | Sort-Object Timestamp -Descending | Select-Object -First $limit
        }
        
        return $events
    }
    
    # Batch publish multiple events (for atomic updates)
    [void] PublishBatch([hashtable[]]$events) {
        foreach ($event in $events) {
            $this.PublishEvent($event.EventType, $event.Data)
        }
    }
    
    # Clear all subscriptions (for cleanup)
    [void] ClearAllSubscriptions() {
        foreach ($eventType in $this._eventSubscriptions.Keys) {
            $this._eventSubscriptions[$eventType].Clear()
        }
        
        if ($this._logger) {
            $this._logger.Debug("RenderEventCoordinator: Cleared all event subscriptions")
        }
    }
}

# Helper class for managing render subscriptions
class RenderSubscriptionManager {
    hidden [RenderEventCoordinator] $_eventCoordinator
    hidden [hashtable] $_componentSubscriptions = @{}
    
    RenderSubscriptionManager([RenderEventCoordinator]$eventCoordinator) {
        $this._eventCoordinator = $eventCoordinator
    }
    
    # Register component for automatic event handling
    [void] RegisterComponent([string]$componentName, [object]$component) {
        $subscriptions = @()
        
        # Auto-subscribe to relevant events based on component type
        switch -Regex ($componentName) {
            'TaskList' {
                $subscriptions += $this._eventCoordinator.Subscribe('TaskListChanged', $componentName, {
                    param($eventArgs)
                    $component.RefreshTaskList($eventArgs.Data)
                })
                
                $subscriptions += $this._eventCoordinator.Subscribe('FilterChanged', $componentName, {
                    param($eventArgs)
                    $component.ApplyFilter($eventArgs.Data.Filter)
                })
                
                $subscriptions += $this._eventCoordinator.Subscribe('SortOrderChanged', $componentName, {
                    param($eventArgs)
                    $component.UpdateSortOrder($eventArgs.Data.SortBy, $eventArgs.Data.Direction)
                })
            }
            
            'StatusBar' {
                $subscriptions += $this._eventCoordinator.Subscribe('SelectionChanged', $componentName, {
                    param($eventArgs)
                    $component.UpdateSelection($eventArgs.Data.SelectedTask)
                })
                
                $subscriptions += $this._eventCoordinator.Subscribe('StateUpdated', $componentName, {
                    param($eventArgs)
                    $component.UpdateStatus($eventArgs.Data)
                })
            }
            
            'FilterBar' {
                $subscriptions += $this._eventCoordinator.Subscribe('FilterChanged', $componentName, {
                    param($eventArgs)
                    $component.UpdateFilterDisplay($eventArgs.Data.Filter)
                })
                
                $subscriptions += $this._eventCoordinator.Subscribe('CommandModeEntered', $componentName, {
                    param($eventArgs)
                    $component.EnterEditMode()
                })
            }
        }
        
        $this._componentSubscriptions[$componentName] = $subscriptions
    }
    
    # Unregister component and cleanup subscriptions
    [void] UnregisterComponent([string]$componentName) {
        if ($this._componentSubscriptions.ContainsKey($componentName)) {
            foreach ($subscriptionId in $this._componentSubscriptions[$componentName]) {
                $this._eventCoordinator.Unsubscribe($subscriptionId)
            }
            $this._componentSubscriptions.Remove($componentName)
        }
    }
    
    # Get registered components
    [string[]] GetRegisteredComponents() {
        return $this._componentSubscriptions.Keys
    }
}
```

### 7. Enhanced Text Measurement and Unicode Support

Robust text handling for international TaskWarrior usage:

```powershell
class UnicodeTextMeasurement {
    hidden [hashtable] $_measurementCache = @{}
    hidden [System.Globalization.StringInfo] $_stringInfo = [System.Globalization.StringInfo]::new()
    
    # Accurate text width measurement considering ANSI sequences and Unicode
    [int] MeasureTextWidth([string]$text) {
        if ([string]::IsNullOrEmpty($text)) { return 0 }
        
        # Check cache first
        if ($this._measurementCache.ContainsKey($text)) {
            return $this._measurementCache[$text]
        }
        
        # Remove ANSI escape sequences
        $cleanText = $text -replace '\x1b\[[0-9;]*[a-zA-Z]', ''
        
        # Handle Unicode combining characters and wide characters
        $this._stringInfo.String = $cleanText
        $width = 0
        
        for ($i = 0; $i -lt $this._stringInfo.LengthInTextElements; $i++) {
            $element = $this._stringInfo.SubstringByTextElements($i, 1)
            $width += $this.GetCharacterWidth($element)
        }
        
        # Cache result
        $this._measurementCache[$text] = $width
        return $width
    }
    
    # Get display width of a single character
    hidden [int] GetCharacterWidth([string]$char) {
        if ([string]::IsNullOrEmpty($char)) { return 0 }
        
        $codepoint = [char]::ConvertToUtf32($char, 0)
        
        # Wide characters (CJK, etc.) take 2 columns
        if ($this.IsWideCharacter($codepoint)) { return 2 }
        
        # Zero-width characters
        if ($this.IsZeroWidthCharacter($codepoint)) { return 0 }
        
        # Normal characters take 1 column
        return 1
    }
    
    # Check if character is wide (takes 2 columns)
    hidden [bool] IsWideCharacter([int]$codepoint) {
        # CJK Unified Ideographs, Hangul, etc.
        return (
            ($codepoint -ge 0x1100 -and $codepoint -le 0x115F) -or     # Hangul Jamo
            ($codepoint -ge 0x2329 -and $codepoint -le 0x232A) -or     # Left/Right-Pointing Angle Brackets
            ($codepoint -ge 0x2E80 -and $codepoint -le 0x2E99) -or     # CJK Radicals Supplement
            ($codepoint -ge 0x2E9B -and $codepoint -le 0x2EF3) -or     # CJK Radicals Supplement
            ($codepoint -ge 0x2F00 -and $codepoint -le 0x2FD5) -or     # Kangxi Radicals
            ($codepoint -ge 0x2FF0 -and $codepoint -le 0x2FFB) -or     # Ideographic Description Characters
            ($codepoint -ge 0x3000 -and $codepoint -le 0x303E) -or     # CJK Symbols and Punctuation
            ($codepoint -ge 0x3041 -and $codepoint -le 0x3096) -or     # Hiragana
            ($codepoint -ge 0x3099 -and $codepoint -le 0x30FF) -or     # Katakana
            ($codepoint -ge 0x3105 -and $codepoint -le 0x312D) -or     # Bopomofo
            ($codepoint -ge 0x3131 -and $codepoint -le 0x318E) -or     # Hangul Compatibility Jamo
            ($codepoint -ge 0x3190 -and $codepoint -le 0x31BA) -or     # Kanbun
            ($codepoint -ge 0x31C0 -and $codepoint -le 0x31E3) -or     # CJK Strokes
            ($codepoint -ge 0x31F0 -and $codepoint -le 0x31FF) -or     # Katakana Phonetic Extensions
            ($codepoint -ge 0x3200 -and $codepoint -le 0x32FF) -or     # Enclosed CJK Letters and Months
            ($codepoint -ge 0x3300 -and $codepoint -le 0x33FF) -or     # CJK Compatibility
            ($codepoint -ge 0x3400 -and $codepoint -le 0x4DBF) -or     # CJK Extension A
            ($codepoint -ge 0x4E00 -and $codepoint -le 0x9FFF) -or     # CJK Unified Ideographs
            ($codepoint -ge 0xA000 -and $codepoint -le 0xA48C) -or     # Yi Syllables
            ($codepoint -ge 0xA490 -and $codepoint -le 0xA4C6) -or     # Yi Radicals
            ($codepoint -ge 0xAC00 -and $codepoint -le 0xD7A3) -or     # Hangul Syllables
            ($codepoint -ge 0xF900 -and $codepoint -le 0xFAFF) -or     # CJK Compatibility Ideographs
            ($codepoint -ge 0xFE10 -and $codepoint -le 0xFE19) -or     # Vertical Forms
            ($codepoint -ge 0xFE30 -and $codepoint -le 0xFE6F) -or     # CJK Compatibility Forms
            ($codepoint -ge 0xFF00 -and $codepoint -le 0xFF60) -or     # Fullwidth ASCII
            ($codepoint -ge 0xFFE0 -and $codepoint -le 0xFFE6) -or     # Fullwidth currency symbols
            ($codepoint -ge 0x20000 -and $codepoint -le 0x2FFFD) -or   # CJK Extension B, C, D
            ($codepoint -ge 0x30000 -and $codepoint -le 0x3FFFD)       # CJK Extension E
        )
    }
    
    # Check if character is zero-width (combining marks, etc.)
    hidden [bool] IsZeroWidthCharacter([int]$codepoint) {
        return (
            ($codepoint -ge 0x0300 -and $codepoint -le 0x036F) -or     # Combining Diacritical Marks
            ($codepoint -ge 0x1AB0 -and $codepoint -le 0x1AFF) -or     # Combining Diacritical Marks Extended
            ($codepoint -ge 0x1DC0 -and $codepoint -le 0x1DFF) -or     # Combining Diacritical Marks Supplement
            ($codepoint -ge 0x20D0 -and $codepoint -le 0x20FF) -or     # Combining Diacritical Marks for Symbols
            ($codepoint -ge 0xFE20 -and $codepoint -le 0xFE2F) -or     # Combining Half Marks
            ($codepoint -eq 0x200B) -or                                 # Zero Width Space
            ($codepoint -eq 0x200C) -or                                 # Zero Width Non-Joiner
            ($codepoint -eq 0x200D) -or                                 # Zero Width Joiner
            ($codepoint -eq 0xFEFF)                                     # Zero Width No-Break Space
        )
    }
    
    # Smart text truncation preserving Unicode boundaries
    [string] TruncateText([string]$text, [int]$maxWidth) {
        if ($this.MeasureTextWidth($text) -le $maxWidth) { return $text }
        
        $this._stringInfo.String = $text -replace '\x1b\[[0-9;]*[a-zA-Z]', ''
        $currentWidth = 0
        $truncateIndex = 0
        
        for ($i = 0; $i -lt $this._stringInfo.LengthInTextElements; $i++) {
            $element = $this._stringInfo.SubstringByTextElements($i, 1)
            $charWidth = $this.GetCharacterWidth($element)
            
            if ($currentWidth + $charWidth + 3 -gt $maxWidth) {  # +3 for "..."
                break
            }
            
            $currentWidth += $charWidth
            $truncateIndex = $i + 1
        }
        
        if ($truncateIndex -eq 0) { return "..." }
        
        $truncated = $this._stringInfo.SubstringByTextElements(0, $truncateIndex)
        return $truncated + "..."
    }
}
```

### 7. Async Command Execution System

Non-blocking TaskWarrior command execution:

```powershell
class AsyncCommandExecutor {
    hidden [hashtable] $_runningCommands = @{}
    hidden [int] $_commandIdCounter = 0
    hidden [System.Threading.Tasks.TaskScheduler] $_scheduler
    
    AsyncCommandExecutor() {
        $this._scheduler = [System.Threading.Tasks.TaskScheduler]::Default
    }
    
    # Execute TaskWarrior command asynchronously
    [int] ExecuteTaskCommandAsync([string]$command, [scriptblock]$callback = $null) {
        $commandId = ++$this._commandIdCounter
        
        $commandInfo = @{
            CommandId = $commandId
            Command = $command
            StartTime = [datetime]::Now
            Status = 'Running'
            Callback = $callback
        }
        
        $this._runningCommands[$commandId] = $commandInfo
        
        # Execute command in background task
        $task = [System.Threading.Tasks.Task]::Run({
            try {
                # Create temporary files for stdout/stderr
                $stdoutFile = [System.IO.Path]::GetTempFileName()
                $stderrFile = [System.IO.Path]::GetTempFileName()
                
                try {
                    # Execute TaskWarrior command
                    $process = [System.Diagnostics.Process]::new()
                    $process.StartInfo.FileName = 'task'
                    $process.StartInfo.Arguments = $command
                    $process.StartInfo.UseShellExecute = $false
                    $process.StartInfo.RedirectStandardOutput = $true
                    $process.StartInfo.RedirectStandardError = $true
                    $process.StartInfo.CreateNoWindow = $true
                    
                    $process.Start()
                    
                    # Read output asynchronously
                    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
                    $stderrTask = $process.StandardError.ReadToEndAsync()
                    
                    $process.WaitForExit()
                    
                    $stdout = $stdoutTask.Result
                    $stderr = $stderrTask.Result
                    
                    return @{
                        Success = ($process.ExitCode -eq 0)
                        ExitCode = $process.ExitCode
                        Stdout = $stdout
                        Stderr = $stderr
                        Command = $command
                    }
                } finally {
                    # Clean up temp files
                    if (Test-Path $stdoutFile) { Remove-Item $stdoutFile -Force -ErrorAction SilentlyContinue }
                    if (Test-Path $stderrFile) { Remove-Item $stderrFile -Force -ErrorAction SilentlyContinue }
                }
            } catch {
                return @{
                    IsValid = $false
                    Message = "Syntax error: $($_.Exception.Message)"
                    Suggestions = $this.GetFilterSuggestions($expression, $expression.Length)
                }
            }
        }
    }
}
```

## System Integration Patterns and Interfaces

### Integration Architecture Overview

```powershell
# Core integration contract for all systems
interface ISystemIntegration {
    [void] Initialize([IServiceContainer]$container)
    [hashtable] GetDependencies()
    [void] RegisterEventHandlers([IEventPublisher]$publisher)
    [void] ValidateConfiguration()
    [SystemStatus] GetHealthStatus()
}

# System dependency resolver
class DependencyResolver {
    hidden [hashtable] $_registrations = @{}
    hidden [hashtable] $_instances = @{}
    hidden [System.Collections.Generic.HashSet[string]] $_initializing = @()
    
    [void] Register([string]$name, [type]$type, [hashtable]$dependencies = @{}) {
        $this._registrations[$name] = @{
            Type = $type
            Dependencies = $dependencies
            Singleton = $true
        }
    }
    
    [object] Resolve([string]$name) {
        if ($this._instances.ContainsKey($name)) {
            return $this._instances[$name]
        }
        
        if ($this._initializing.Contains($name)) {
            throw "Circular dependency detected for service: $name"
        }
        
        $registration = $this._registrations[$name]
        if (-not $registration) {
            throw "Service not registered: $name"
        }
        
        $this._initializing.Add($name)
        
        try {
            # Resolve dependencies
            $resolvedDeps = @{}
            foreach ($dep in $registration.Dependencies.GetEnumerator()) {
                $resolvedDeps[$dep.Key] = $this.Resolve($dep.Value)
            }
            
            # Create instance
            $instance = $registration.Type::new()
            
            # Inject dependencies
            foreach ($dep in $resolvedDeps.GetEnumerator()) {
                $instance.($dep.Key) = $dep.Value
            }
            
            # Initialize if it implements ISystemIntegration
            if ($instance -is [ISystemIntegration]) {
                $instance.Initialize($this)
            }
            
            if ($registration.Singleton) {
                $this._instances[$name] = $instance
            }
            
            return $instance
            
        } finally {
            $this._initializing.Remove($name)
        }
    }
}

# System startup coordinator
class SystemStartupCoordinator {
    hidden [DependencyResolver] $_resolver
    hidden [System.Collections.Generic.List[string]] $_startupOrder = @()
    hidden [hashtable] $_healthChecks = @{}
    
    SystemStartupCoordinator([DependencyResolver]$resolver) {
        $this._resolver = $resolver
    }
    
    [void] DefineStartupOrder([string[]]$order) {
        $this._startupOrder.Clear()
        foreach ($system in $order) {
            $this._startupOrder.Add($system)
        }
    }
    
    [void] StartSystems() {
        foreach ($systemName in $this._startupOrder) {
            try {
                $system = $this._resolver.Resolve($systemName)
                Write-Host "Starting system: $systemName"
                
                if ($system -is [ISystemIntegration]) {
                    $system.ValidateConfiguration()
                    $health = $system.GetHealthStatus()
                    
                    if ($health.Status -ne 'Healthy') {
                        throw "System $systemName failed health check: $($health.Message)"
                    }
                }
                
                $this._healthChecks[$systemName] = @{
                    Status = 'Started'
                    Timestamp = Get-Date
                    System = $system
                }
                
            } catch {
                Write-Error "Failed to start system $systemName`: $_"
                throw
            }
        }
    }
    
    [hashtable] GetSystemStatus() {
        $status = @{}
        foreach ($check in $this._healthChecks.GetEnumerator()) {
            $system = $check.Value.System
            if ($system -is [ISystemIntegration]) {
                $status[$check.Key] = $system.GetHealthStatus()
            } else {
                $status[$check.Key] = @{ Status = 'Unknown'; Message = 'No health check available' }
            }
        }
        return $status
    }
}
```

### Inter-System Communication Contracts

```powershell
# Event-based system communication
class SystemEventContract {
    hidden [string] $_eventType
    hidden [hashtable] $_schema
    hidden [string[]] $_requiredFields
    
    SystemEventContract([string]$eventType, [hashtable]$schema, [string[]]$requiredFields) {
        $this._eventType = $eventType
        $this._schema = $schema
        $this._requiredFields = $requiredFields
    }
    
    [bool] ValidateEvent([hashtable]$eventData) {
        # Check required fields
        foreach ($field in $this._requiredFields) {
            if (-not $eventData.ContainsKey($field)) {
                return $false
            }
        }
        
        # Validate schema
        foreach ($field in $this._schema.GetEnumerator()) {
            if ($eventData.ContainsKey($field.Key)) {
                $expectedType = $field.Value
                $actualValue = $eventData[$field.Key]
                
                if (-not $this.ValidateType($actualValue, $expectedType)) {
                    return $false
                }
            }
        }
        
        return $true
    }
    
    [bool] ValidateType([object]$value, [string]$expectedType) {
        switch ($expectedType) {
            'string' { return $value -is [string] }
            'int' { return $value -is [int] }
            'datetime' { return $value -is [DateTime] }
            'hashtable' { return $value -is [hashtable] }
            'array' { return $value -is [array] }
            default { return $true }
        }
    }
}

# System event definitions
$systemEvents = @{
    'TaskChanged' = [SystemEventContract]::new('TaskChanged', @{
        'TaskId' = 'string'
        'ChangeType' = 'string'
        'OldValues' = 'hashtable'
        'NewValues' = 'hashtable'
        'Timestamp' = 'datetime'
    }, @('TaskId', 'ChangeType'))
    
    'FilterChanged' = [SystemEventContract]::new('FilterChanged', @{
        'FilterExpression' = 'string'
        'ResultCount' = 'int'
        'ExecutionTime' = 'int'
    }, @('FilterExpression'))
    
    'ViewChanged' = [SystemEventContract]::new('ViewChanged', @{
        'ViewName' = 'string'
        'ScrollPosition' = 'int'
        'SelectedIndex' = 'int'
    }, @('ViewName'))
}

# Cross-system data contracts
class DataSharingContract {
    hidden [string] $_contractName
    hidden [hashtable] $_dataSchema
    hidden [scriptblock] $_validator
    
    DataSharingContract([string]$name, [hashtable]$schema, [scriptblock]$validator = $null) {
        $this._contractName = $name
        $this._dataSchema = $schema
        $this._validator = $validator
    }
    
    [bool] ValidateData([object]$data) {
        if ($this._validator) {
            return & $this._validator $data
        }
        return $true
    }
    
    [hashtable] GetSchema() {
        return $this._dataSchema
    }
}

# Shared data contracts
$dataContracts = @{
    'TaskData' = [DataSharingContract]::new('TaskData', @{
        'ID' = @{ Type = 'string'; Required = $true }
        'Description' = @{ Type = 'string'; Required = $true }
        'Status' = @{ Type = 'string'; Values = @('pending', 'waiting', 'completed', 'deleted') }
        'Project' = @{ Type = 'string'; Required = $false }
        'Priority' = @{ Type = 'string'; Values = @('H', 'M', 'L'); Required = $false }
        'Due' = @{ Type = 'datetime'; Required = $false }
        'Tags' = @{ Type = 'array'; ElementType = 'string'; Required = $false }
        'Urgency' = @{ Type = 'double'; Min = 0; Max = 100; Required = $false }
        'UDAs' = @{ Type = 'hashtable'; Required = $false }
    }, {
        param($task)
        return ($task.ContainsKey('ID') -and $task.ContainsKey('Description'))
    })
    
    'FilterResult' = [DataSharingContract]::new('FilterResult', @{
        'Tasks' = @{ Type = 'array'; ElementType = 'TaskData'; Required = $true }
        'TotalCount' = @{ Type = 'int'; Required = $true }
        'FilterExpression' = @{ Type = 'string'; Required = $true }
        'ExecutionTimeMs' = @{ Type = 'int'; Required = $true }
        'CacheHit' = @{ Type = 'bool'; Required = $true }
    })
}
```

### Plugin Integration Framework

```powershell
# Plugin contract
interface ITaskWarriorPlugin {
    [string] GetName()
    [string] GetVersion()
    [string[]] GetRequiredServices()
    [void] Initialize([IServiceContainer]$container)
    [hashtable] GetCapabilities()
    [void] OnTaskChanged([hashtable]$task, [string]$changeType)
    [void] OnApplicationShutdown()
}

# Plugin manager
class PluginManager {
    hidden [System.Collections.Generic.List[ITaskWarriorPlugin]] $_plugins = @()
    hidden [hashtable] $_pluginCapabilities = @{}
    hidden [IServiceContainer] $_serviceContainer
    
    PluginManager([IServiceContainer]$container) {
        $this._serviceContainer = $container
    }
    
    [void] LoadPlugin([ITaskWarriorPlugin]$plugin) {
        try {
            # Validate required services
            $requiredServices = $plugin.GetRequiredServices()
            foreach ($service in $requiredServices) {
                if (-not $this._serviceContainer.IsRegistered($service)) {
                    throw "Required service not available: $service"
                }
            }
            
            # Initialize plugin
            $plugin.Initialize($this._serviceContainer)
            
            # Register capabilities
            $capabilities = $plugin.GetCapabilities()
            $this._pluginCapabilities[$plugin.GetName()] = $capabilities
            
            # Add to plugin list
            $this._plugins.Add($plugin)
            
            Write-Host "Loaded plugin: $($plugin.GetName()) v$($plugin.GetVersion())"
            
        } catch {
            Write-Error "Failed to load plugin $($plugin.GetName()): $_"
        }
    }
    
    [void] NotifyTaskChanged([hashtable]$task, [string]$changeType) {
        foreach ($plugin in $this._plugins) {
            try {
                $plugin.OnTaskChanged($task, $changeType)
            } catch {
                Write-Error "Plugin $($plugin.GetName()) error handling task change: $_"
            }
        }
    }
    
    [hashtable] GetPluginCapabilities([string]$capability) {
        $result = @{}
        foreach ($plugin in $this._pluginCapabilities.GetEnumerator()) {
            if ($plugin.Value.ContainsKey($capability)) {
                $result[$plugin.Key] = $plugin.Value[$capability]
            }
        }
        return $result
    }
}

# Example plugin implementation
class UrgencyCalculationPlugin : ITaskWarriorPlugin {
    hidden [IConfigurationProvider] $_config
    
    [string] GetName() { return "UrgencyCalculationPlugin" }
    [string] GetVersion() { return "1.0.0" }
    [string[]] GetRequiredServices() { return @('IConfigurationProvider') }
    
    [void] Initialize([IServiceContainer]$container) {
        $this._config = $container.GetService([IConfigurationProvider])
    }
    
    [hashtable] GetCapabilities() {
        return @{
            'urgency_calculation' = @{
                'supports_custom_coefficients' = $true
                'supports_age_calculation' = $true
                'supports_due_date_urgency' = $true
            }
        }
    }
    
    [void] OnTaskChanged([hashtable]$task, [string]$changeType) {
        if ($changeType -in @('created', 'modified')) {
            $urgency = $this.CalculateUrgency($task)
            $task['urgency'] = $urgency
        }
    }
    
    [void] OnApplicationShutdown() {
        # Cleanup if needed
    }
    
    [double] CalculateUrgency([hashtable]$task) {
        $urgency = 0.0
        
        # Priority coefficient
        if ($task.ContainsKey('priority')) {
            switch ($task.priority) {
                'H' { $urgency += 6.0 }
                'M' { $urgency += 3.9 }
                'L' { $urgency += 1.8 }
            }
        }
        
        # Age coefficient
        if ($task.ContainsKey('entry')) {
            $age = (Get-Date) - $task.entry
            $urgency += $age.TotalDays * 0.02
        }
        
        # Due date coefficient
        if ($task.ContainsKey('due')) {
            $daysUntilDue = ($task.due - (Get-Date)).TotalDays
            if ($daysUntilDue -lt 7) {
                $urgency += (7 - $daysUntilDue) * 2.0
            }
        }
        
        return [Math]::Max(0, $urgency)
    }
}
```

### System Lifecycle Management

```powershell
# Application lifecycle coordinator
class ApplicationLifecycleManager {
    hidden [DependencyResolver] $_resolver
    hidden [PluginManager] $_pluginManager
    hidden [IEventPublisher] $_eventPublisher
    hidden [System.Collections.Generic.List[string]] $_shutdownOrder = @()
    hidden [bool] $_isShuttingDown = $false
    
    ApplicationLifecycleManager([DependencyResolver]$resolver) {
        $this._resolver = $resolver
        $this._eventPublisher = $resolver.Resolve('IEventPublisher')
        $this._pluginManager = $resolver.Resolve('PluginManager')
    }
    
    [void] StartApplication() {
        try {
            Write-Host "Starting TaskWarrior-TUI..."
            
            # Start core systems
            $startupCoordinator = [SystemStartupCoordinator]::new($this._resolver)
            $startupCoordinator.DefineStartupOrder(@(
                'IConfigurationProvider',
                'ICacheProvider', 
                'IDataProvider',
                'FilterEngine',
                'VirtualScrollEngine',
                'RenderEngine',
                'ThemeManager',
                'UDAManager',
                'ComponentManager'
            ))
            
            $startupCoordinator.StartSystems()
            
            # Load plugins
            $this.LoadPlugins()
            
            # Publish startup complete event
            $this._eventPublisher.Publish('ApplicationStarted', @{
                StartupTime = Get-Date
                Systems = $startupCoordinator.GetSystemStatus()
            })
            
            Write-Host "TaskWarrior-TUI started successfully"
            
        } catch {
            Write-Error "Failed to start application: $_"
            $this.EmergencyShutdown()
            throw
        }
    }
    
    [void] LoadPlugins() {
        $pluginDir = "$PSScriptRoot/Plugins"
        if (Test-Path $pluginDir) {
            $pluginFiles = Get-ChildItem $pluginDir -Filter "*.ps1"
            foreach ($file in $pluginFiles) {
                try {
                    . $file.FullName
                    # Plugin registration happens in the script file
                } catch {
                    Write-Warning "Failed to load plugin $($file.Name): $_"
                }
            }
        }
    }
    
    [void] ShutdownApplication() {
        if ($this._isShuttingDown) { return }
        $this._isShuttingDown = $true
        
        Write-Host "Shutting down TaskWarrior-TUI..."
        
        try {
            # Notify plugins
            foreach ($plugin in $this._pluginManager._plugins) {
                try {
                    $plugin.OnApplicationShutdown()
                } catch {
                    Write-Warning "Plugin shutdown error: $_"
                }
            }
            
            # Shutdown systems in reverse order
            foreach ($systemName in $this._shutdownOrder) {
                try {
                    $system = $this._resolver._instances[$systemName]
                    if ($system -and $system.PSObject.Methods['Shutdown']) {
                        $system.Shutdown()
                    }
                } catch {
                    Write-Warning "System shutdown error for $systemName`: $_"
                }
            }
            
            # Final cleanup
            $renderEngine = $this._resolver._instances['RenderEngine']
            if ($renderEngine) {
                $renderEngine.RestoreConsole()
            }
            
            Write-Host "Shutdown complete"
            
        } catch {
            Write-Error "Error during shutdown: $_"
            $this.EmergencyShutdown()
        }
    }
    
    [void] EmergencyShutdown() {
        try {
            $renderEngine = $this._resolver._instances['RenderEngine']
            if ($renderEngine) {
                $renderEngine.EmergencyClear()
            }
        } catch {
            # Last resort
            try { [Console]::Clear() } catch { }
            try { [Console]::Write("`e[?25h`e[0m") } catch { }
        }
    }
}
```

## Configuration Schema and Validation

### Configuration System Architecture

```powershell
# Configuration schema definition
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
            
            if ($null -ne $fieldValue) {
                # Type validation
                if ($fieldSchema.ContainsKey('type')) {
                    $typeResult = $this.ValidateType($fieldValue, $fieldSchema.type, $fullFieldName)
                    if (-not $typeResult.IsValid) {
                        $errors += $typeResult.Error
                        continue
                    }
                }
                
                # Range validation
                if ($fieldSchema.ContainsKey('min') -or $fieldSchema.ContainsKey('max')) {
                    $rangeResult = $this.ValidateRange($fieldValue, $fieldSchema, $fullFieldName)
                    if (-not $rangeResult.IsValid) {
                        $errors += $rangeResult.Error
                        continue
                    }
                }
                
                # Enum validation
                if ($fieldSchema.ContainsKey('values')) {
                    if ($fieldValue -notin $fieldSchema.values) {
                        $errors += "Field '$fullFieldName' has invalid value '$fieldValue'. Valid values: $($fieldSchema.values -join ', ')"
                        continue
                    }
                }
                
                # Custom validation
                if ($this._validators.ContainsKey($fullFieldName)) {
                    $validator = $this._validators[$fullFieldName]
                    try {
                        $customResult = & $validator $fieldValue
                        if (-not $customResult.IsValid) {
                            $errors += "Field '$fullFieldName': $($customResult.Message)"
                        }
                        if ($customResult.ContainsKey('Warning')) {
                            $warnings += "Field '$fullFieldName': $($customResult.Warning)"
                        }
                    } catch {
                        $errors += "Field '$fullFieldName' custom validation failed: $($_.Exception.Message)"
                    }
                }
            }
        }
        
        return @{
            Errors = $errors
            Warnings = $warnings
        }
    }
    
    [hashtable] ValidateType([object]$value, [string]$expectedType, [string]$fieldName) {
        switch ($expectedType.ToLower()) {
            'string' {
                if ($value -is [string]) {
                    return @{ IsValid = $true }
                } else {
                    return @{ IsValid = $false; Error = "Field '$fieldName' must be a string" }
                }
            }
            'int' {
                if ($value -is [int] -or ($value -is [string] -and [int]::TryParse($value, [ref]$null))) {
                    return @{ IsValid = $true }
                } else {
                    return @{ IsValid = $false; Error = "Field '$fieldName' must be an integer" }
                }
            }
            'bool' {
                if ($value -is [bool] -or $value -in @('true', 'false', '1', '0', 'yes', 'no', 'on', 'off')) {
                    return @{ IsValid = $true }
                } else {
                    return @{ IsValid = $false; Error = "Field '$fieldName' must be a boolean value" }
                }
            }
            'path' {
                if ($value -is [string] -and -not [string]::IsNullOrWhiteSpace($value)) {
                    return @{ IsValid = $true }
                } else {
                    return @{ IsValid = $false; Error = "Field '$fieldName' must be a valid path" }
                }
            }
            'color' {
                if ($this.IsValidColor($value)) {
                    return @{ IsValid = $true }
                } else {
                    return @{ IsValid = $false; Error = "Field '$fieldName' must be a valid color (hex, rgb, or name)" }
                }
            }
            default {
                return @{ IsValid = $true }
            }
        }
    }
    
    [hashtable] ValidateRange([object]$value, [hashtable]$fieldSchema, [string]$fieldName) {
        $numValue = $null
        if ($value -is [int] -or $value -is [double]) {
            $numValue = $value
        } elseif ($value -is [string] -and [double]::TryParse($value, [ref]$numValue)) {
            # Parse succeeded, $numValue is set
        } else {
            return @{ IsValid = $false; Error = "Field '$fieldName' must be numeric for range validation" }
        }
        
        if ($fieldSchema.ContainsKey('min') -and $numValue -lt $fieldSchema.min) {
            return @{ IsValid = $false; Error = "Field '$fieldName' value $numValue is below minimum $($fieldSchema.min)" }
        }
        
        if ($fieldSchema.ContainsKey('max') -and $numValue -gt $fieldSchema.max) {
            return @{ IsValid = $false; Error = "Field '$fieldName' value $numValue is above maximum $($fieldSchema.max)" }
        }
        
        return @{ IsValid = $true }
    }
    
    [bool] IsValidColor([string]$color) {
        # Hex color
        if ($color -match '^#[0-9A-Fa-f]{6}$') { return $true }
        
        # RGB values
        if ($color -match '^\d{1,3},\d{1,3},\d{1,3}$') {
            $rgb = $color -split ','
            return $rgb[0] -le 255 -and $rgb[1] -le 255 -and $rgb[2] -le 255
        }
        
        # Named colors
        $namedColors = @('black', 'red', 'green', 'yellow', 'blue', 'magenta', 'cyan', 'white',
                        'bright_black', 'bright_red', 'bright_green', 'bright_yellow',
                        'bright_blue', 'bright_magenta', 'bright_cyan', 'bright_white')
        
        return $color -in $namedColors
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

# Configuration provider implementation
class TaskWarriorConfigProvider : IConfigurationProvider {
    hidden [string] $_configPath
    hidden [hashtable] $_config = @{}
    hidden [ConfigurationSchema] $_schema
    hidden [System.IO.FileSystemWatcher] $_fileWatcher
    hidden [IEventPublisher] $_eventPublisher
    hidden [datetime] $_lastLoad
    
    TaskWarriorConfigProvider([string]$configPath, [IEventPublisher]$eventPublisher) {
        $this._configPath = $configPath
        $this._eventPublisher = $eventPublisher
        $this._schema = $this.CreateSchema()
        $this.LoadConfiguration()
        $this.SetupFileWatcher()
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
        
        # TaskWarrior integration
        $schema.DefineSection('taskwarrior', @{
            'data_location' = @{ type = 'path'; required = $true; validator = {
                param($path)
                if (-not (Test-Path $path)) {
                    return @{ IsValid = $false; Message = "TaskWarrior data directory does not exist" }
                }
                $taskrcPath = Join-Path $path ".taskrc"
                if (-not (Test-Path $taskrcPath)) {
                    return @{ IsValid = $false; Warning = "No .taskrc found in data directory" }
                }
                return @{ IsValid = $true }
            }}
            'task_command' = @{ type = 'string'; default = 'task' }
            'sync_on_start' = @{ type = 'bool'; default = $false }
            'sync_on_exit' = @{ type = 'bool'; default = $false }
            'timeout_seconds' = @{ type = 'int'; min = 1; max = 300; default = 30 }
        })
        
        # Display columns configuration
        $schema.DefineSection('columns', @{
            'id' = @{ type = 'bool'; default = $true }
            'description' = @{ type = 'bool'; default = $true }
            'project' = @{ type = 'bool'; default = $true }
            'priority' = @{ type = 'bool'; default = $true }
            'due' = @{ type = 'bool'; default = $true }
            'urgency' = @{ type = 'bool'; default = $false }
            'tags' = @{ type = 'bool'; default = $false }
            'depends' = @{ type = 'bool'; default = $false }
        })
        
        # Keyboard shortcuts
        $schema.DefineSection('keys', @{
            'quit' = @{ type = 'string'; default = 'q' }
            'add_task' = @{ type = 'string'; default = 'a' }
            'edit_task' = @{ type = 'string'; default = 'e' }
            'delete_task' = @{ type = 'string'; default = 'd' }
            'complete_task' = @{ type = 'string'; default = 'c' }
            'filter_tasks' = @{ type = 'string'; default = 'f' }
            'clear_filter' = @{ type = 'string'; default = 'F' }
            'sync' = @{ type = 'string'; default = 's' }
            'help' = @{ type = 'string'; default = '?' }
            'refresh' = @{ type = 'string'; default = 'r' }
        })
        
        # Performance settings
        $schema.DefineSection('performance', @{
            'virtual_scroll_buffer' = @{ type = 'int'; min = 10; max = 1000; default = 100 }
            'cache_size_mb' = @{ type = 'int'; min = 1; max = 500; default = 50 }
            'max_undo_levels' = @{ type = 'int'; min = 5; max = 1000; default = 100 }
            'render_throttle_ms' = @{ type = 'int'; min = 1; max = 1000; default = 16 }
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
            
            # Validate configuration
            $validation = $this._schema.ValidateConfiguration($this._config)
            if (-not $validation.IsValid) {
                Write-Warning "Configuration validation errors:"
                foreach ($error in $validation.Errors) {
                    Write-Warning "  $error"
                }
            }
            
            if ($validation.Warnings.Count -gt 0) {
                foreach ($warning in $validation.Warnings) {
                    Write-Warning "  $warning"
                }
            }
            
            $this._lastLoad = Get-Date
            
            # Publish configuration loaded event
            $this._eventPublisher.Publish('ConfigurationLoaded', @{
                Path = $this._configPath
                ValidationResult = $validation
                Timestamp = $this._lastLoad
            })
            
        } catch {
            Write-Error "Failed to load configuration from $($this._configPath): $($_.Exception.Message)"
            $this._config = $this._schema.GetDefaults()
        }
    }
    
    [void] SaveConfiguration() {
        try {
            $validation = $this._schema.ValidateConfiguration($this._config)
            if (-not $validation.IsValid) {
                throw "Cannot save invalid configuration. Errors: $($validation.Errors -join '; ')"
            }
            
            $configJson = $this._config | ConvertTo-Json -Depth 10
            Set-Content -Path $this._configPath -Value $configJson -Encoding UTF8
            
            $this._eventPublisher.Publish('ConfigurationSaved', @{
                Path = $this._configPath
                Timestamp = Get-Date
            })
            
        } catch {
            Write-Error "Failed to save configuration to $($this._configPath): $($_.Exception.Message)"
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
            
            Register-ObjectEvent -InputObject $this._fileWatcher -EventName Changed -Action {
                param($sender, $e)
                
                # Debounce file changes (editors might write multiple times)
                Start-Sleep -Milliseconds 100
                
                try {
                    $this.LoadConfiguration()
                    $this._eventPublisher.Publish('ConfigurationChanged', @{
                        Path = $e.FullPath
                        ChangeType = $e.ChangeType
                        Timestamp = Get-Date
                    })
                } catch {
                    Write-Warning "Failed to reload configuration after file change: $_"
                }
            }
        }
    }
    
    [object] GetValue([string]$key, [object]$defaultValue = $null) {
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
    
    [void] ReloadConfiguration() {
        $this.LoadConfiguration()
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

# Configuration migration support
class ConfigurationMigrator {
    hidden [hashtable] $_migrations = @{}
    
    [void] RegisterMigration([string]$fromVersion, [string]$toVersion, [scriptblock]$migrationScript) {
        $migrationKey = "$fromVersion->$toVersion"
        $this._migrations[$migrationKey] = $migrationScript
    }
    
    [hashtable] MigrateConfiguration([hashtable]$config, [string]$fromVersion, [string]$toVersion) {
        $migrationKey = "$fromVersion->$toVersion"
        
        if (-not $this._migrations.ContainsKey($migrationKey)) {
            throw "No migration available from version $fromVersion to $toVersion"
        }
        
        try {
            $migrationScript = $this._migrations[$migrationKey]
            $migratedConfig = & $migrationScript $config
            
            return @{
                Success = $true
                Config = $migratedConfig
                Message = "Configuration migrated from $fromVersion to $toVersion"
            }
            
        } catch {
            return @{
                Success = $false
                Config = $config
                Error = "Migration failed: $($_.Exception.Message)"
            }
        }
    }
}

# Default configuration migrations
$configMigrator = [ConfigurationMigrator]::new()

# Example: Migration from v1.0 to v1.1 (theme format change)
$configMigrator.RegisterMigration('1.0', '1.1', {
    param($config)
    
    # Migrate old color format to new format
    if ($config.ContainsKey('colors')) {
        $config['theme'] = @{}
        foreach ($color in $config.colors.GetEnumerator()) {
            $config.theme[$color.Key] = $color.Value
        }
        $config.Remove('colors')
    }
    
    # Set version
    $config['version'] = '1.1'
    return $config
})
```

## Keyboard Navigation and Input Handling

### Input System Architecture

```powershell
# Input event definition
class InputEvent {
    [ConsoleKeyInfo] $KeyInfo
    [datetime] $Timestamp
    [string] $EventType  # 'KeyDown', 'KeyUp', 'KeyPress'
    [bool] $Handled = $false
    [object] $Context   # Current component or state context
    
    InputEvent([ConsoleKeyInfo]$keyInfo, [string]$eventType, [object]$context = $null) {
        $this.KeyInfo = $keyInfo
        $this.EventType = $eventType
        $this.Timestamp = Get-Date
        $this.Context = $context
    }
    
    [string] GetKeyString() {
        $key = $this.KeyInfo.Key
        $modifiers = @()
        
        if (($this.KeyInfo.Modifiers -band [ConsoleModifiers]::Control) -ne 0) {
            $modifiers += 'Ctrl'
        }
        if (($this.KeyInfo.Modifiers -band [ConsoleModifiers]::Alt) -ne 0) {
            $modifiers += 'Alt'
        }
        if (($this.KeyInfo.Modifiers -band [ConsoleModifiers]::Shift) -ne 0) {
            $modifiers += 'Shift'
        }
        
        if ($modifiers.Count -gt 0) {
            return "$($modifiers -join '+') + $key"
        } else {
            return $key.ToString()
        }
    }
    
    [bool] IsModified() {
        return $this.KeyInfo.Modifiers -ne [ConsoleModifiers]::None
    }
    
    [bool] IsNavigation() {
        return $this.KeyInfo.Key -in @(
            [ConsoleKey]::UpArrow, [ConsoleKey]::DownArrow,
            [ConsoleKey]::LeftArrow, [ConsoleKey]::RightArrow,
            [ConsoleKey]::Home, [ConsoleKey]::End,
            [ConsoleKey]::PageUp, [ConsoleKey]::PageDown,
            [ConsoleKey]::Tab
        )
    }
    
    [bool] IsAction() {
        return $this.KeyInfo.Key -in @(
            [ConsoleKey]::Enter, [ConsoleKey]::Escape,
            [ConsoleKey]::Delete, [ConsoleKey]::Backspace,
            [ConsoleKey]::F1, [ConsoleKey]::F2, [ConsoleKey]::F3,
            [ConsoleKey]::F4, [ConsoleKey]::F5, [ConsoleKey]::F6,
            [ConsoleKey]::F7, [ConsoleKey]::F8, [ConsoleKey]::F9,
            [ConsoleKey]::F10, [ConsoleKey]::F11, [ConsoleKey]::F12
        )
    }
}

# Key binding definition
class KeyBinding {
    [string] $Name
    [string] $KeyCombination
    [ConsoleKey] $Key
    [ConsoleModifiers] $Modifiers
    [scriptblock] $Action
    [string] $Description
    [string[]] $Contexts  # Which UI contexts this applies to
    [int] $Priority = 0   # Higher priority bindings are checked first
    
    KeyBinding([string]$name, [string]$keyCombination, [scriptblock]$action, [string]$description = '', [string[]]$contexts = @('*'), [int]$priority = 0) {
        $this.Name = $name
        $this.KeyCombination = $keyCombination
        $this.Action = $action
        $this.Description = $description
        $this.Contexts = $contexts
        $this.Priority = $priority
        
        $this.ParseKeyBinding($keyCombination)
    }
    
    hidden [void] ParseKeyBinding([string]$combination) {
        $parts = $combination.Split('+').Trim()
        $this.Modifiers = [ConsoleModifiers]::None
        
        for ($i = 0; $i -lt $parts.Count - 1; $i++) {
            switch ($parts[$i].ToLower()) {
                'ctrl' { $this.Modifiers = $this.Modifiers -bor [ConsoleModifiers]::Control }
                'alt' { $this.Modifiers = $this.Modifiers -bor [ConsoleModifiers]::Alt }
                'shift' { $this.Modifiers = $this.Modifiers -bor [ConsoleModifiers]::Shift }
            }
        }
        
        $keyString = $parts[-1]
        if ([ConsoleKey]::TryParse($keyString, [ref]$this.Key)) {
            # Successfully parsed
        } elseif ($keyString.Length -eq 1) {
            # Single character - convert to key
            $char = $keyString.ToUpper()[0]
            $this.Key = [ConsoleKey]::Parse([ConsoleKey], $char.ToString())
        } else {
            throw "Invalid key combination: $combination"
        }
    }
    
    [bool] Matches([InputEvent]$inputEvent) {
        return $inputEvent.KeyInfo.Key -eq $this.Key -and 
               $inputEvent.KeyInfo.Modifiers -eq $this.Modifiers
    }
    
    [bool] IsValidInContext([string]$context) {
        return $this.Contexts -contains '*' -or $this.Contexts -contains $context
    }
}

# Input handler interface
interface IInputHandler {
    [bool] HandleInput([InputEvent]$inputEvent)
    [string[]] GetSupportedContexts()
    [int] GetPriority()
}

# Keyboard navigation manager
class KeyboardNavigationManager {
    hidden [System.Collections.Generic.List[KeyBinding]] $_keyBindings = @()
    hidden [System.Collections.Generic.List[IInputHandler]] $_inputHandlers = @()
    hidden [hashtable] $_contextStack = @()
    hidden [string] $_currentContext = 'global'
    hidden [IEventPublisher] $_eventPublisher
    hidden [bool] $_isCapturingInput = $false
    hidden [System.Threading.CancellationTokenSource] $_inputCancellation
    
    KeyboardNavigationManager([IEventPublisher]$eventPublisher) {
        $this._eventPublisher = $eventPublisher
        $this.RegisterDefaultBindings()
    }
    
    [void] RegisterKeyBinding([KeyBinding]$binding) {
        # Remove existing binding with same name
        $existingIndex = -1
        for ($i = 0; $i -lt $this._keyBindings.Count; $i++) {
            if ($this._keyBindings[$i].Name -eq $binding.Name) {
                $existingIndex = $i
                break
            }
        }
        
        if ($existingIndex -ge 0) {
            $this._keyBindings.RemoveAt($existingIndex)
        }
        
        # Insert by priority (highest first)
        $insertIndex = 0
        while ($insertIndex -lt $this._keyBindings.Count -and 
               $this._keyBindings[$insertIndex].Priority -ge $binding.Priority) {
            $insertIndex++
        }
        
        $this._keyBindings.Insert($insertIndex, $binding)
    }
    
    [void] RegisterInputHandler([IInputHandler]$handler) {
        if ($handler -notin $this._inputHandlers) {
            # Insert by priority
            $insertIndex = 0
            while ($insertIndex -lt $this._inputHandlers.Count -and
                   $this._inputHandlers[$insertIndex].GetPriority() -ge $handler.GetPriority()) {
                $insertIndex++
            }
            
            $this._inputHandlers.Insert($insertIndex, $handler)
        }
    }
    
    [void] UnregisterInputHandler([IInputHandler]$handler) {
        $this._inputHandlers.Remove($handler)
    }
    
    [void] PushContext([string]$context) {
        if (-not $this._contextStack.ContainsKey($context)) {
            $this._contextStack[$context] = @()
        }
        $this._contextStack[$context] += $this._currentContext
        $this._currentContext = $context
        
        $this._eventPublisher.Publish('ContextChanged', @{
            PreviousContext = $this._contextStack[$context][-1]
            CurrentContext = $context
            Action = 'Push'
        })
    }
    
    [void] PopContext() {
        $contextEntries = $this._contextStack[$this._currentContext]
        if ($contextEntries -and $contextEntries.Count -gt 0) {
            $previousContext = $this._currentContext
            $this._currentContext = $contextEntries[-1]
            $this._contextStack[$previousContext] = $contextEntries[0..($contextEntries.Count - 2)]
            
            $this._eventPublisher.Publish('ContextChanged', @{
                PreviousContext = $previousContext
                CurrentContext = $this._currentContext
                Action = 'Pop'
            })
        }
    }
    
    [void] SetContext([string]$context) {
        $previousContext = $this._currentContext
        $this._currentContext = $context
        
        $this._eventPublisher.Publish('ContextChanged', @{
            PreviousContext = $previousContext
            CurrentContext = $context
            Action = 'Set'
        })
    }
    
    [string] GetCurrentContext() {
        return $this._currentContext
    }
    
    [void] StartInputCapture() {
        if ($this._isCapturingInput) { return }
        
        $this._isCapturingInput = $true
        $this._inputCancellation = [System.Threading.CancellationTokenSource]::new()
        
        # Start background input capture
        $inputTask = {
            param($manager, $cancellationToken)
            
            try {
                while (-not $cancellationToken.IsCancellationRequested) {
                    if ([Console]::KeyAvailable) {
                        $keyInfo = [Console]::ReadKey($true)
                        $inputEvent = [InputEvent]::new($keyInfo, 'KeyPress', $manager._currentContext)
                        
                        # Process input on main thread
                        $manager.ProcessInputEvent($inputEvent)
                    }
                    
                    # Small sleep to prevent excessive CPU usage
                    Start-Sleep -Milliseconds 10
                }
            } catch {
                # Input capture stopped
            }
        }
        
        # Run input capture in background runspace
        $this.StartBackgroundTask($inputTask, @($this, $this._inputCancellation.Token))
    }
    
    [void] StopInputCapture() {
        if (-not $this._isCapturingInput) { return }
        
        $this._isCapturingInput = $false
        if ($this._inputCancellation) {
            $this._inputCancellation.Cancel()
            $this._inputCancellation.Dispose()
            $this._inputCancellation = $null
        }
    }
    
    [void] ProcessInputEvent([InputEvent]$inputEvent) {
        try {
            # First, try input handlers (highest priority)
            foreach ($handler in $this._inputHandlers) {
                $contexts = $handler.GetSupportedContexts()
                if ($contexts -contains '*' -or $contexts -contains $this._currentContext) {
                    if ($handler.HandleInput($inputEvent)) {
                        $inputEvent.Handled = $true
                        return
                    }
                }
            }
            
            # Then try key bindings
            foreach ($binding in $this._keyBindings) {
                if ($binding.IsValidInContext($this._currentContext) -and $binding.Matches($inputEvent)) {
                    try {
                        & $binding.Action $inputEvent
                        $inputEvent.Handled = $true
                        
                        $this._eventPublisher.Publish('KeyBindingExecuted', @{
                            BindingName = $binding.Name
                            KeyCombination = $binding.KeyCombination
                            Context = $this._currentContext
                            Timestamp = $inputEvent.Timestamp
                        })
                        
                        return
                    } catch {
                        $this._eventPublisher.Publish('KeyBindingError', @{
                            BindingName = $binding.Name
                            Error = $_.Exception.Message
                            Context = $this._currentContext
                        })
                    }
                }
            }
            
            # If no handler processed the input, publish unhandled event
            if (-not $inputEvent.Handled) {
                $this._eventPublisher.Publish('UnhandledInput', @{
                    KeyString = $inputEvent.GetKeyString()
                    Context = $this._currentContext
                    Timestamp = $inputEvent.Timestamp
                })
            }
            
        } catch {
            Write-Error "Error processing input event: $($_.Exception.Message)"
        }
    }
    
    hidden [void] StartBackgroundTask([scriptblock]$task, [array]$arguments) {
        $runspace = [runspacefactory]::CreateRunspace()
        $runspace.Open()
        
        $powerShell = [powershell]::Create()
        $powerShell.Runspace = $runspace
        $powerShell.AddScript($task).AddParameters($arguments)
        
        $asyncResult = $powerShell.BeginInvoke()
    }
    
    [void] RegisterDefaultBindings() {
        # Global navigation
        $this.RegisterKeyBinding([KeyBinding]::new('quit', 'Ctrl+C', {
            param($event)
            [Environment]::Exit(0)
        }, 'Quit application', @('*'), 1000))
        
        $this.RegisterKeyBinding([KeyBinding]::new('escape', 'Escape', {
            param($event)
            # Context-dependent escape handling
        }, 'Context-dependent escape', @('*'), 900))
        
        # List navigation
        $this.RegisterKeyBinding([KeyBinding]::new('move_up', 'UpArrow', {
            param($event)
            $event.Context.NavigateUp()
        }, 'Move selection up', @('list', 'table'), 100))
        
        $this.RegisterKeyBinding([KeyBinding]::new('move_down', 'DownArrow', {
            param($event)
            $event.Context.NavigateDown()
        }, 'Move selection down', @('list', 'table'), 100))
        
        $this.RegisterKeyBinding([KeyBinding]::new('page_up', 'PageUp', {
            param($event)
            $event.Context.PageUp()
        }, 'Page up', @('list', 'table'), 100))
        
        $this.RegisterKeyBinding([KeyBinding]::new('page_down', 'PageDown', {
            param($event)
            $event.Context.PageDown()
        }, 'Page down', @('list', 'table'), 100))
        
        # Text editing
        $this.RegisterKeyBinding([KeyBinding]::new('move_left', 'LeftArrow', {
            param($event)
            $event.Context.MoveCursorLeft()
        }, 'Move cursor left', @('edit', 'input'), 100))
        
        $this.RegisterKeyBinding([KeyBinding]::new('move_right', 'RightArrow', {
            param($event)
            $event.Context.MoveCursorRight()
        }, 'Move cursor right', @('edit', 'input'), 100))
        
        $this.RegisterKeyBinding([KeyBinding]::new('word_left', 'Ctrl+LeftArrow', {
            param($event)
            $event.Context.MoveCursorWordLeft()
        }, 'Move cursor word left', @('edit', 'input'), 100))
        
        $this.RegisterKeyBinding([KeyBinding]::new('word_right', 'Ctrl+RightArrow', {
            param($event)
            $event.Context.MoveCursorWordRight()
        }, 'Move cursor word right', @('edit', 'input'), 100))
        
        $this.RegisterKeyBinding([KeyBinding]::new('home', 'Home', {
            param($event)
            $event.Context.MoveCursorToStart()
        }, 'Move to start', @('edit', 'input', 'list'), 100))
        
        $this.RegisterKeyBinding([KeyBinding]::new('end', 'End', {
            param($event)
            $event.Context.MoveCursorToEnd()
        }, 'Move to end', @('edit', 'input', 'list'), 100))
        
        $this.RegisterKeyBinding([KeyBinding]::new('backspace', 'Backspace', {
            param($event)
            $event.Context.DeletePrevious()
        }, 'Delete previous character', @('edit', 'input'), 100))
        
        $this.RegisterKeyBinding([KeyBinding]::new('delete', 'Delete', {
            param($event)
            $event.Context.DeleteNext()
        }, 'Delete next character', @('edit', 'input'), 100))
        
        # Selection and clipboard
        $this.RegisterKeyBinding([KeyBinding]::new('select_all', 'Ctrl+A', {
            param($event)
            $event.Context.SelectAll()
        }, 'Select all', @('edit', 'input', 'list'), 100))
        
        $this.RegisterKeyBinding([KeyBinding]::new('copy', 'Ctrl+C', {
            param($event)
            $event.Context.Copy()
        }, 'Copy selection', @('edit', 'input', 'list'), 200))
        
        $this.RegisterKeyBinding([KeyBinding]::new('paste', 'Ctrl+V', {
            param($event)
            $event.Context.Paste()
        }, 'Paste clipboard', @('edit', 'input'), 100))
        
        $this.RegisterKeyBinding([KeyBinding]::new('cut', 'Ctrl+X', {
            param($event)
            $event.Context.Cut()
        }, 'Cut selection', @('edit', 'input'), 100))
        
        # Undo/Redo
        $this.RegisterKeyBinding([KeyBinding]::new('undo', 'Ctrl+Z', {
            param($event)
            $event.Context.Undo()
        }, 'Undo last action', @('edit', 'input'), 100))
        
        $this.RegisterKeyBinding([KeyBinding]::new('redo', 'Ctrl+Y', {
            param($event)
            $event.Context.Redo()
        }, 'Redo last action', @('edit', 'input'), 100))
    }
    
    [array] GetKeyBindingsForContext([string]$context) {
        return $this._keyBindings | Where-Object { $_.IsValidInContext($context) }
    }
    
    [hashtable] GetHelpForContext([string]$context) {
        $bindings = $this.GetKeyBindingsForContext($context)
        $help = @{}
        
        foreach ($binding in $bindings) {
            if (-not [string]::IsNullOrWhiteSpace($binding.Description)) {
                $help[$binding.KeyCombination] = $binding.Description
            }
        }
        
        return $help
    }
}

# Focus management system
class FocusManager {
    hidden [System.Collections.Generic.List[object]] $_focusableElements = @()
    hidden [int] $_currentFocusIndex = -1
    hidden [object] $_currentFocusElement = $null
    hidden [IEventPublisher] $_eventPublisher
    
    FocusManager([IEventPublisher]$eventPublisher) {
        $this._eventPublisher = $eventPublisher
    }
    
    [void] RegisterFocusableElement([object]$element) {
        if ($element -notin $this._focusableElements) {
            $this._focusableElements.Add($element)
            
            # Set focus to first element if none focused
            if ($this._currentFocusIndex -eq -1) {
                $this.SetFocus($element)
            }
        }
    }
    
    [void] UnregisterFocusableElement([object]$element) {
        $index = $this._focusableElements.IndexOf($element)
        if ($index -ge 0) {
            $this._focusableElements.RemoveAt($index)
            
            # Adjust focus index if needed
            if ($this._currentFocusIndex -eq $index) {
                if ($this._focusableElements.Count -gt 0) {
                    $newIndex = [Math]::Min($index, $this._focusableElements.Count - 1)
                    $this.SetFocusByIndex($newIndex)
                } else {
                    $this._currentFocusIndex = -1
                    $this._currentFocusElement = $null
                }
            } elseif ($this._currentFocusIndex -gt $index) {
                $this._currentFocusIndex--
            }
        }
    }
    
    [void] SetFocus([object]$element) {
        $index = $this._focusableElements.IndexOf($element)
        if ($index -ge 0) {
            $this.SetFocusByIndex($index)
        }
    }
    
    [void] SetFocusByIndex([int]$index) {
        if ($index -ge 0 -and $index -lt $this._focusableElements.Count) {
            $previousElement = $this._currentFocusElement
            $previousIndex = $this._currentFocusIndex
            
            # Remove focus from previous element
            if ($previousElement -and $previousElement.PSObject.Methods['OnLostFocus']) {
                $previousElement.OnLostFocus()
            }
            
            # Set focus to new element
            $this._currentFocusIndex = $index
            $this._currentFocusElement = $this._focusableElements[$index]
            
            if ($this._currentFocusElement.PSObject.Methods['OnGotFocus']) {
                $this._currentFocusElement.OnGotFocus()
            }
            
            # Publish focus change event
            $this._eventPublisher.Publish('FocusChanged', @{
                PreviousElement = $previousElement
                PreviousIndex = $previousIndex
                CurrentElement = $this._currentFocusElement
                CurrentIndex = $this._currentFocusIndex
            })
        }
    }
    
    [void] FocusNext() {
        if ($this._focusableElements.Count -gt 0) {
            $nextIndex = ($this._currentFocusIndex + 1) % $this._focusableElements.Count
            $this.SetFocusByIndex($nextIndex)
        }
    }
    
    [void] FocusPrevious() {
        if ($this._focusableElements.Count -gt 0) {
            $prevIndex = $this._currentFocusIndex - 1
            if ($prevIndex -lt 0) {
                $prevIndex = $this._focusableElements.Count - 1
            }
            $this.SetFocusByIndex($prevIndex)
        }
    }
    
    [object] GetCurrentFocus() {
        return $this._currentFocusElement
    }
    
    [int] GetCurrentFocusIndex() {
        return $this._currentFocusIndex
    }
    
    [bool] HasFocus([object]$element) {
        return $this._currentFocusElement -eq $element
    }
}

# Input validation system
class InputValidator {
    hidden [hashtable] $_validators = @{}
    
    [void] RegisterValidator([string]$name, [scriptblock]$validator, [string]$errorMessage = '') {
        $this._validators[$name] = @{
            Validator = $validator
            ErrorMessage = $errorMessage
        }
    }
    
    [hashtable] ValidateInput([string]$input, [string[]]$validatorNames) {
        $errors = @()
        
        foreach ($validatorName in $validatorNames) {
            if ($this._validators.ContainsKey($validatorName)) {
                $validator = $this._validators[$validatorName]
                try {
                    $result = & $validator.Validator $input
                    if (-not $result) {
                        $message = if ($validator.ErrorMessage) { 
                            $validator.ErrorMessage 
                        } else { 
                            "Input failed validation: $validatorName" 
                        }
                        $errors += $message
                    }
                } catch {
                    $errors += "Validation error for $validatorName`: $($_.Exception.Message)"
                }
            }
        }
        
        return @{
            IsValid = $errors.Count -eq 0
            Errors = $errors
        }
    }
    
    [void] RegisterCommonValidators() {
        $this.RegisterValidator('not_empty', {
            param($input)
            return -not [string]::IsNullOrWhiteSpace($input)
        }, 'Input cannot be empty')
        
        $this.RegisterValidator('integer', {
            param($input)
            $dummy = 0
            return [int]::TryParse($input, [ref]$dummy)
        }, 'Input must be a valid integer')
        
        $this.RegisterValidator('positive_integer', {
            param($input)
            $value = 0
            return [int]::TryParse($input, [ref]$value) -and $value -gt 0
        }, 'Input must be a positive integer')
        
        $this.RegisterValidator('email', {
            param($input)
            return $input -match '^[^@]+@[^@]+\.[^@]+$'
        }, 'Input must be a valid email address')
        
        $this.RegisterValidator('date', {
            param($input)
            $dummy = [datetime]::MinValue
            return [datetime]::TryParse($input, [ref]$dummy)
        }, 'Input must be a valid date')
    }
}
```

## Threading and Async Operation Patterns

### Async Architecture Overview

```powershell
# Async operation result
class AsyncResult {
    [bool] $IsCompleted = $false
    [bool] $IsSuccess = $false
    [object] $Result = $null
    [System.Exception] $Exception = $null
    [datetime] $StartTime
    [datetime] $CompletedTime
    [string] $OperationId
    [hashtable] $Metadata = @{}
    
    AsyncResult([string]$operationId) {
        $this.OperationId = $operationId
        $this.StartTime = Get-Date
    }
    
    [void] SetSuccess([object]$result) {
        $this.IsCompleted = $true
        $this.IsSuccess = $true
        $this.Result = $result
        $this.CompletedTime = Get-Date
    }
    
    [void] SetError([System.Exception]$exception) {
        $this.IsCompleted = $true
        $this.IsSuccess = $false
        $this.Exception = $exception
        $this.CompletedTime = Get-Date
    }
    
    [timespan] GetDuration() {
        if ($this.IsCompleted) {
            return $this.CompletedTime - $this.StartTime
        } else {
            return (Get-Date) - $this.StartTime
        }
    }
}

# Async operation manager
class AsyncOperationManager {
    hidden [hashtable] $_operations = @{}
    hidden [System.Collections.Concurrent.ConcurrentQueue[AsyncResult]] $_completedOperations
    hidden [IEventPublisher] $_eventPublisher
    hidden [bool] $_isRunning = $false
    hidden [System.Threading.CancellationTokenSource] $_cancellationSource
    hidden [int] $_maxConcurrentOperations = 10
    hidden [System.Threading.Semaphore] $_semaphore
    
    AsyncOperationManager([IEventPublisher]$eventPublisher) {
        $this._eventPublisher = $eventPublisher
        $this._completedOperations = [System.Collections.Concurrent.ConcurrentQueue[AsyncResult]]::new()
        $this._semaphore = [System.Threading.Semaphore]::new($this._maxConcurrentOperations, $this._maxConcurrentOperations)
    }
    
    [AsyncResult] StartOperation([string]$operationName, [scriptblock]$operation, [hashtable]$parameters = @{}, [int]$timeoutMs = 30000) {
        $operationId = [guid]::NewGuid().ToString()
        $asyncResult = [AsyncResult]::new($operationId)
        $asyncResult.Metadata = $parameters
        
        $this._operations[$operationId] = $asyncResult
        
        # Start operation in background
        $this.StartBackgroundOperation($operationName, $operation, $asyncResult, $parameters, $timeoutMs)
        
        # Publish operation started event
        $this._eventPublisher.Publish('AsyncOperationStarted', @{
            OperationId = $operationId
            OperationName = $operationName
            StartTime = $asyncResult.StartTime
            Parameters = $parameters
        })
        
        return $asyncResult
    }
    
    hidden [void] StartBackgroundOperation([string]$operationName, [scriptblock]$operation, [AsyncResult]$asyncResult, [hashtable]$parameters, [int]$timeoutMs) {
        $operationTask = {
            param($opName, $op, $result, $params, $timeout, $eventPublisher, $semaphore, $completedQueue)
            
            try {
                # Acquire semaphore (limit concurrent operations)
                $semaphore.WaitOne()
                
                try {
                    # Create cancellation token for timeout
                    $cts = [System.Threading.CancellationTokenSource]::new($timeout)
                    
                    # Execute operation
                    $operationResult = & $op $params $cts.Token
                    
                    if ($cts.Token.IsCancellationRequested) {
                        throw [System.TimeoutException]::new("Operation timed out after $timeout ms")
                    }
                    
                    $result.SetSuccess($operationResult)
                    
                    # Publish success event
                    $eventPublisher.Publish('AsyncOperationCompleted', @{
                        OperationId = $result.OperationId
                        OperationName = $opName
                        IsSuccess = $true
                        Duration = $result.GetDuration()
                        Result = $operationResult
                    })
                    
                } finally {
                    $semaphore.Release()
                }
                
            } catch {
                $result.SetError($_.Exception)
                
                # Publish error event
                $eventPublisher.Publish('AsyncOperationCompleted', @{
                    OperationId = $result.OperationId
                    OperationName = $opName
                    IsSuccess = $false
                    Duration = $result.GetDuration()
                    Error = $_.Exception.Message
                })
                
                $semaphore.Release()
            }
            
            # Add to completed queue
            $completedQueue.Enqueue($result)
        }
        
        # Start in new runspace
        $runspace = [runspacefactory]::CreateRunspace()
        $runspace.Open()
        
        $powerShell = [powershell]::Create()
        $powerShell.Runspace = $runspace
        $powerShell.AddScript($operationTask).AddParameters(@(
            $operationName, $operation, $asyncResult, $parameters, $timeoutMs,
            $this._eventPublisher, $this._semaphore, $this._completedOperations
        ))
        
        $asyncResult.Metadata['PowerShell'] = $powerShell
        $asyncResult.Metadata['Runspace'] = $runspace
        
        $null = $powerShell.BeginInvoke()
    }
    
    [AsyncResult] GetOperation([string]$operationId) {
        return $this._operations[$operationId]
    }
    
    [array] GetActiveOperations() {
        return $this._operations.Values | Where-Object { -not $_.IsCompleted }
    }
    
    [array] GetCompletedOperations() {
        $completed = @()
        while ($this._completedOperations.TryDequeue([ref]$null)) {
            $completed += $_
        }
        return $completed
    }
    
    [void] CancelOperation([string]$operationId) {
        $operation = $this._operations[$operationId]
        if ($operation -and -not $operation.IsCompleted) {
            $powerShell = $operation.Metadata['PowerShell']
            $runspace = $operation.Metadata['Runspace']
            
            if ($powerShell) {
                $powerShell.Stop()
                $powerShell.Dispose()
            }
            
            if ($runspace) {
                $runspace.Close()
                $runspace.Dispose()
            }
            
            $operation.SetError([System.OperationCanceledException]::new('Operation was cancelled'))
            
            $this._eventPublisher.Publish('AsyncOperationCancelled', @{
                OperationId = $operationId
                CancelledTime = Get-Date
            })
        }
    }
    
    [void] CancelAllOperations() {
        foreach ($operation in $this.GetActiveOperations()) {
            $this.CancelOperation($operation.OperationId)
        }
    }
    
    [void] WaitForCompletion([string]$operationId, [int]$timeoutMs = 30000) {
        $operation = $this._operations[$operationId]
        if ($operation) {
            $startTime = Get-Date
            while (-not $operation.IsCompleted -and (Get-Date) -lt $startTime.AddMilliseconds($timeoutMs)) {
                Start-Sleep -Milliseconds 100
            }
        }
    }
    
    [void] CleanupCompletedOperations([int]$maxAge = 300000) {  # 5 minutes default
        $cutoffTime = (Get-Date).AddMilliseconds(-$maxAge)
        $toRemove = @()
        
        foreach ($op in $this._operations.GetEnumerator()) {
            if ($op.Value.IsCompleted -and $op.Value.CompletedTime -lt $cutoffTime) {
                $toRemove += $op.Key
                
                # Cleanup PowerShell resources
                $powerShell = $op.Value.Metadata['PowerShell']
                $runspace = $op.Value.Metadata['Runspace']
                
                if ($powerShell) { $powerShell.Dispose() }
                if ($runspace) { $runspace.Dispose() }
            }
        }
        
        foreach ($key in $toRemove) {
            $this._operations.Remove($key)
        }
    }
}

# Background task scheduler
class BackgroundTaskScheduler {
    hidden [System.Collections.Generic.PriorityQueue[hashtable, int]] $_taskQueue
    hidden [hashtable] $_scheduledTasks = @{}
    hidden [bool] $_isRunning = $false
    hidden [System.Threading.CancellationTokenSource] $_cancellationSource
    hidden [IEventPublisher] $_eventPublisher
    hidden [int] $_workerCount = 3
    hidden [System.Collections.Generic.List[object]] $_workers = @()
    
    BackgroundTaskScheduler([IEventPublisher]$eventPublisher) {
        $this._eventPublisher = $eventPublisher
        $this._taskQueue = [System.Collections.Generic.PriorityQueue[hashtable, int]]::new()
    }
    
    [void] Start() {
        if ($this._isRunning) { return }
        
        $this._isRunning = $true
        $this._cancellationSource = [System.Threading.CancellationTokenSource]::new()
        
        # Start worker threads
        for ($i = 0; $i -lt $this._workerCount; $i++) {
            $worker = $this.CreateWorker($i, $this._cancellationSource.Token)
            $this._workers.Add($worker)
        }
        
        $this._eventPublisher.Publish('TaskSchedulerStarted', @{
            WorkerCount = $this._workerCount
            StartTime = Get-Date
        })
    }
    
    [void] Stop() {
        if (-not $this._isRunning) { return }
        
        $this._isRunning = $false
        
        if ($this._cancellationSource) {
            $this._cancellationSource.Cancel()
        }
        
        # Wait for workers to complete
        foreach ($worker in $this._workers) {
            if ($worker.PowerShell) {
                $worker.PowerShell.Stop()
                $worker.PowerShell.Dispose()
            }
            if ($worker.Runspace) {
                $worker.Runspace.Close()
                $worker.Runspace.Dispose()
            }
        }
        
        $this._workers.Clear()
        
        if ($this._cancellationSource) {
            $this._cancellationSource.Dispose()
            $this._cancellationSource = $null
        }
        
        $this._eventPublisher.Publish('TaskSchedulerStopped', @{
            StopTime = Get-Date
        })
    }
    
    [string] ScheduleTask([scriptblock]$task, [int]$priority = 0, [hashtable]$parameters = @{}, [datetime]$scheduledTime = [datetime]::Now) {
        $taskId = [guid]::NewGuid().ToString()
        
        $taskInfo = @{
            TaskId = $taskId
            Task = $task
            Priority = $priority
            Parameters = $parameters
            ScheduledTime = $scheduledTime
            CreatedTime = Get-Date
            Status = 'Scheduled'
        }
        
        $this._scheduledTasks[$taskId] = $taskInfo
        
        # Add to queue if it's time to run
        if ($scheduledTime -le (Get-Date)) {
            $this._taskQueue.Enqueue($taskInfo, -$priority)  # Negative for max-heap behavior
            $taskInfo.Status = 'Queued'
        }
        
        $this._eventPublisher.Publish('TaskScheduled', @{
            TaskId = $taskId
            Priority = $priority
            ScheduledTime = $scheduledTime
        })
        
        return $taskId
    }
    
    [void] ScheduleRecurringTask([scriptblock]$task, [timespan]$interval, [int]$priority = 0, [hashtable]$parameters = @{}) {
        $recurringTask = {
            param($originalTask, $interval, $priority, $parameters, $scheduler)
            
            # Execute the task
            & $originalTask $parameters
            
            # Reschedule for next execution
            $nextRun = (Get-Date).Add($interval)
            $scheduler.ScheduleTask($originalTask, $priority, $parameters, $nextRun)
        }
        
        $this.ScheduleTask($recurringTask, $priority, @{
            originalTask = $task
            interval = $interval
            priority = $priority
            parameters = $parameters
            scheduler = $this
        })
    }
    
    [void] CancelTask([string]$taskId) {
        if ($this._scheduledTasks.ContainsKey($taskId)) {
            $this._scheduledTasks[$taskId].Status = 'Cancelled'
            
            $this._eventPublisher.Publish('TaskCancelled', @{
                TaskId = $taskId
                CancelledTime = Get-Date
            })
        }
    }
    
    hidden [hashtable] CreateWorker([int]$workerId, [System.Threading.CancellationToken]$cancellationToken) {
        $workerScript = {
            param($id, $token, $taskQueue, $scheduledTasks, $eventPublisher)
            
            while (-not $token.IsCancellationRequested) {
                try {
                    # Check for scheduled tasks that are ready to run
                    $currentTime = Get-Date
                    foreach ($scheduledTask in $scheduledTasks.Values) {
                        if ($scheduledTask.Status -eq 'Scheduled' -and $scheduledTask.ScheduledTime -le $currentTime) {
                            $taskQueue.Enqueue($scheduledTask, -$scheduledTask.Priority)
                            $scheduledTask.Status = 'Queued'
                        }
                    }
                    
                    # Process queued tasks
                    $taskInfo = $null
                    if ($taskQueue.TryDequeue([ref]$taskInfo, [ref]$null)) {
                        if ($taskInfo.Status -ne 'Cancelled') {
                            try {
                                $taskInfo.Status = 'Running'
                                $taskInfo.StartTime = Get-Date
                                
                                $eventPublisher.Publish('TaskStarted', @{
                                    TaskId = $taskInfo.TaskId
                                    WorkerId = $id
                                    StartTime = $taskInfo.StartTime
                                })
                                
                                # Execute the task
                                $result = & $taskInfo.Task $taskInfo.Parameters
                                
                                $taskInfo.Status = 'Completed'
                                $taskInfo.CompletedTime = Get-Date
                                $taskInfo.Result = $result
                                
                                $eventPublisher.Publish('TaskCompleted', @{
                                    TaskId = $taskInfo.TaskId
                                    WorkerId = $id
                                    CompletedTime = $taskInfo.CompletedTime
                                    Duration = $taskInfo.CompletedTime - $taskInfo.StartTime
                                    IsSuccess = $true
                                })
                                
                            } catch {
                                $taskInfo.Status = 'Failed'
                                $taskInfo.CompletedTime = Get-Date
                                $taskInfo.Error = $_.Exception
                                
                                $eventPublisher.Publish('TaskCompleted', @{
                                    TaskId = $taskInfo.TaskId
                                    WorkerId = $id
                                    CompletedTime = $taskInfo.CompletedTime
                                    Duration = $taskInfo.CompletedTime - $taskInfo.StartTime
                                    IsSuccess = $false
                                    Error = $_.Exception.Message
                                })
                            }
                        }
                    }
                    
                    # Small sleep to prevent excessive CPU usage
                    Start-Sleep -Milliseconds 100
                    
                } catch {
                    # Worker error - continue running
                    Start-Sleep -Milliseconds 1000
                }
            }
        }
        
        $runspace = [runspacefactory]::CreateRunspace()
        $runspace.Open()
        
        $powerShell = [powershell]::Create()
        $powerShell.Runspace = $runspace
        $powerShell.AddScript($workerScript).AddParameters(@(
            $workerId, $cancellationToken, $this._taskQueue, $this._scheduledTasks, $this._eventPublisher
        ))
        
        $asyncResult = $powerShell.BeginInvoke()
        
        return @{
            WorkerId = $workerId
            PowerShell = $powerShell
            Runspace = $runspace
            AsyncResult = $asyncResult
        }
    }
    
    [hashtable] GetTaskStatus([string]$taskId) {
        return $this._scheduledTasks[$taskId]
    }
    
    [array] GetAllTasks() {
        return $this._scheduledTasks.Values
    }
    
    [int] GetQueuedTaskCount() {
        return $this._taskQueue.Count
    }
}

# Thread-safe data access layer
class ThreadSafeDataManager {
    hidden [System.Collections.Concurrent.ConcurrentDictionary[string, object]] $_cache
    hidden [System.Threading.ReaderWriterLockSlim] $_rwLock
    hidden [hashtable] $_subscriptions = @{}
    hidden [IEventPublisher] $_eventPublisher
    
    ThreadSafeDataManager([IEventPublisher]$eventPublisher) {
        $this._cache = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new()
        $this._rwLock = [System.Threading.ReaderWriterLockSlim]::new()
        $this._eventPublisher = $eventPublisher
    }
    
    [object] GetData([string]$key) {
        return $this._cache.GetValueOrDefault($key)
    }
    
    [void] SetData([string]$key, [object]$value) {
        $oldValue = $this._cache.GetValueOrDefault($key)
        $this._cache[$key] = $value
        
        # Notify subscribers
        if ($this._subscriptions.ContainsKey($key)) {
            foreach ($callback in $this._subscriptions[$key]) {
                try {
                    & $callback $key $oldValue $value
                } catch {
                    Write-Warning "Error in data change callback for key '$key': $($_.Exception.Message)"
                }
            }
        }
        
        # Publish change event
        $this._eventPublisher.Publish('DataChanged', @{
            Key = $key
            OldValue = $oldValue
            NewValue = $value
            Timestamp = Get-Date
        })
    }
    
    [bool] TryGetData([string]$key, [ref]$value) {
        return $this._cache.TryGetValue($key, $value)
    }
    
    [object] GetOrAdd([string]$key, [scriptblock]$valueFactory) {
        return $this._cache.GetOrAdd($key, {
            param($k)
            return & $valueFactory $k
        })
    }
    
    [void] RemoveData([string]$key) {
        $removed = $null
        if ($this._cache.TryRemove($key, [ref]$removed)) {
            # Notify subscribers
            if ($this._subscriptions.ContainsKey($key)) {
                foreach ($callback in $this._subscriptions[$key]) {
                    try {
                        & $callback $key $removed $null
                    } catch {
                        Write-Warning "Error in data removal callback for key '$key': $($_.Exception.Message)"
                    }
                }
            }
            
            # Publish removal event
            $this._eventPublisher.Publish('DataRemoved', @{
                Key = $key
                RemovedValue = $removed
                Timestamp = Get-Date
            })
        }
    }
    
    [void] SubscribeToChanges([string]$key, [scriptblock]$callback) {
        $this._rwLock.EnterWriteLock()
        try {
            if (-not $this._subscriptions.ContainsKey($key)) {
                $this._subscriptions[$key] = @()
            }
            $this._subscriptions[$key] += $callback
        } finally {
            $this._rwLock.ExitWriteLock()
        }
    }
    
    [void] UnsubscribeFromChanges([string]$key, [scriptblock]$callback) {
        $this._rwLock.EnterWriteLock()
        try {
            if ($this._subscriptions.ContainsKey($key)) {
                $this._subscriptions[$key] = $this._subscriptions[$key] | Where-Object { $_ -ne $callback }
                if ($this._subscriptions[$key].Count -eq 0) {
                    $this._subscriptions.Remove($key)
                }
            }
        } finally {
            $this._rwLock.ExitWriteLock()
        }
    }
    
    [void] BatchUpdate([scriptblock]$updateBlock) {
        $this._rwLock.EnterWriteLock()
        try {
            $changes = @{}
            
            # Capture original values
            $originalNotifications = $this._subscriptions
            $this._subscriptions = @{}  # Temporarily disable notifications
            
            try {
                # Execute updates
                & $updateBlock $this
                
                # Restore notifications and notify all at once
                $this._subscriptions = $originalNotifications
                
                # Batch notify all changes
                $this._eventPublisher.Publish('BatchDataChanged', @{
                    Changes = $changes
                    Timestamp = Get-Date
                })
                
            } finally {
                $this._subscriptions = $originalNotifications
            }
            
        } finally {
            $this._rwLock.ExitWriteLock()
        }
    }
    
    [array] GetAllKeys() {
        return $this._cache.Keys
    }
    
    [void] Clear() {
        $this._rwLock.EnterWriteLock()
        try {
            $this._cache.Clear()
            $this._subscriptions.Clear()
            
            $this._eventPublisher.Publish('DataCleared', @{
                Timestamp = Get-Date
            })
        } finally {
            $this._rwLock.ExitWriteLock()
        }
    }
    
    [void] Dispose() {
        if ($this._rwLock) {
            $this._rwLock.Dispose()
        }
    }
}

# Async TaskWarrior operations
class AsyncTaskWarriorOperations {
    hidden [AsyncOperationManager] $_asyncManager
    hidden [IDataProvider] $_dataProvider
    hidden [BackgroundTaskScheduler] $_scheduler
    
    AsyncTaskWarriorOperations([AsyncOperationManager]$asyncManager, [IDataProvider]$dataProvider, [BackgroundTaskScheduler]$scheduler) {
        $this._asyncManager = $asyncManager
        $this._dataProvider = $dataProvider
        $this._scheduler = $scheduler
    }
    
    [AsyncResult] LoadTasksAsync([string]$filter = '', [int]$timeoutMs = 30000) {
        return $this._asyncManager.StartOperation('LoadTasks', {
            param($params, $cancellationToken)
            
            $filter = $params.Filter
            return $this._dataProvider.GetTasks($filter)
            
        }, @{ Filter = $filter }, $timeoutMs)
    }
    
    [AsyncResult] SaveTaskAsync([hashtable]$task, [int]$timeoutMs = 10000) {
        return $this._asyncManager.StartOperation('SaveTask', {
            param($params, $cancellationToken)
            
            $task = $params.Task
            return $this._dataProvider.SaveTask($task)
            
        }, @{ Task = $task }, $timeoutMs)
    }
    
    [AsyncResult] SyncTasksAsync([int]$timeoutMs = 60000) {
        return $this._asyncManager.StartOperation('SyncTasks', {
            param($params, $cancellationToken)
            
            # Perform TaskWarrior sync
            $result = & task sync
            return @{
                Success = $LASTEXITCODE -eq 0
                Output = $result
                ExitCode = $LASTEXITCODE
            }
            
        }, @{}, $timeoutMs)
    }
    
    [void] SchedulePeriodicSync([int]$intervalMinutes = 30) {
        $syncInterval = [timespan]::FromMinutes($intervalMinutes)
        
        $this._scheduler.ScheduleRecurringTask({
            param($params)
            
            $asyncOps = $params.AsyncOps
            $result = $asyncOps.SyncTasksAsync(60000)
            $asyncOps._asyncManager.WaitForCompletion($result.OperationId, 60000)
            
            if ($result.IsSuccess) {
                Write-Host "Periodic sync completed successfully"
            } else {
                Write-Warning "Periodic sync failed: $($result.Exception.Message)"
            }
            
        }, 1, @{ AsyncOps = $this })
    }
    
    [void] SchedulePeriodicDataRefresh([int]$intervalSeconds = 30) {
        $refreshInterval = [timespan]::FromSeconds($intervalSeconds)
        
        $this._scheduler.ScheduleRecurringTask({
            param($params)
            
            $asyncOps = $params.AsyncOps
            $result = $asyncOps.LoadTasksAsync('status:pending', 15000)
            $asyncOps._asyncManager.WaitForCompletion($result.OperationId, 15000)
            
        }, 2, @{ AsyncOps = $this })
    }
}
                    Success = $false
                    Error = $_.Exception.Message
                    Command = $command
                }
            }
        })
        
        # Handle task completion
        $task.ContinueWith({
            param($completedTask)
            
            $commandInfo = $this._runningCommands[$commandId]
            $commandInfo.Status = 'Completed'
            $commandInfo.EndTime = [datetime]::Now
            $commandInfo.Result = $completedTask.Result
            
            # Execute callback if provided
            if ($commandInfo.Callback) {
                try {
                    & $commandInfo.Callback $completedTask.Result
                } catch {
                    # Log callback errors but continue
                    [Logger]::Error("Command callback error for command $commandId", $_)
                }
            }
        })
        
        return $commandId
    }
    
    # Check if command is complete
    [bool] IsCommandComplete([int]$commandId) {
        if (-not $this._runningCommands.ContainsKey($commandId)) { return $false }
        return $this._runningCommands[$commandId].Status -eq 'Completed'
    }
    
    # Get command result (blocking until complete)
    [hashtable] GetCommandResult([int]$commandId, [int]$timeoutMs = 10000) {
        if (-not $this._runningCommands.ContainsKey($commandId)) {
            return @{ Success = $false; Error = "Command not found: $commandId" }
        }
        
        $commandInfo = $this._runningCommands[$commandId]
        $startWait = [datetime]::Now
        
        # Wait for completion
        while ($commandInfo.Status -ne 'Completed') {
            if (([datetime]::Now - $startWait).TotalMilliseconds -gt $timeoutMs) {
                return @{ Success = $false; Error = "Command timeout: $commandId" }
            }
            Start-Sleep -Milliseconds 50
        }
        
        $result = $commandInfo.Result
        $this._runningCommands.Remove($commandId)  # Clean up
        return $result
    }
    
    # Get command result (non-blocking)
    [hashtable] TryGetCommandResult([int]$commandId) {
        if (-not $this._runningCommands.ContainsKey($commandId)) {
            return @{ Success = $false; Error = "Command not found: $commandId" }
        }
        
        $commandInfo = $this._runningCommands[$commandId]
        if ($commandInfo.Status -eq 'Completed') {
            $result = $commandInfo.Result
            $this._runningCommands.Remove($commandId)
            return $result
        }
        
        return $null  # Still running
    }
    
    # Cancel running command
    [bool] CancelCommand([int]$commandId) {
        if (-not $this._runningCommands.ContainsKey($commandId)) { return $false }
        
        $commandInfo = $this._runningCommands[$commandId]
        if ($commandInfo.Status -ne 'Running') { return $false }
        
        # Mark as cancelled (actual process cancellation is complex)
        $commandInfo.Status = 'Cancelled'
        $commandInfo.EndTime = [datetime]::Now
        return $true
    }
    
    # Get statistics about running commands
    [hashtable] GetExecutorStatistics() {
        $runningCount = ($this._runningCommands.Values | Where-Object { $_.Status -eq 'Running' }).Count
        $completedCount = ($this._runningCommands.Values | Where-Object { $_.Status -eq 'Completed' }).Count
        $cancelledCount = ($this._runningCommands.Values | Where-Object { $_.Status -eq 'Cancelled' }).Count
        
        return @{
            RunningCommands = $runningCount
            CompletedCommands = $completedCount
            CancelledCommands = $cancelledCount
            TotalCommands = $this._runningCommands.Count
        }
    }
}
```

### 8. Unified Theme/Color Composition System

Advanced theming system supporting TaskWarrior's visual requirements:

```powershell
class TaskWarriorThemeManager {
    hidden [hashtable] $_themes = @{}
    hidden [string] $_currentTheme = "default"
    hidden [hashtable] $_colorCache = @{}
    hidden [hashtable] $_urgencyColorMap = @{}
    hidden [hashtable] $_customColors = @{}
    
    TaskWarriorThemeManager() {
        $this.InitializeDefaultThemes()
        $this.InitializeUrgencyColors()
    }
    
    # Initialize built-in themes
    [void] InitializeDefaultThemes() {
        # Default light theme
        $this._themes["default"] = @{
            Name = "Default Light"
            Colors = @{
                'text.primary' = [VT]::RGB(40, 40, 40)
                'text.secondary' = [VT]::RGB(100, 100, 100)
                'text.muted' = [VT]::RGB(150, 150, 150)
                'text.highlight' = [VT]::RGB(20, 20, 20)
                'text.error' = [VT]::RGB(220, 50, 47)
                'text.warning' = [VT]::RGB(181, 137, 0)
                'text.success' = [VT]::RGB(133, 153, 0)
                'text.info' = [VT]::RGB(38, 139, 210)
                
                'background.normal' = [VT]::RGB(253, 246, 227)
                'background.selected' = [VT]::RGB(238, 232, 213)
                'background.focused' = [VT]::RGB(220, 220, 220)
                'background.urgent' = [VT]::RGB(255, 230, 230)
                
                'border.normal' = [VT]::RGB(147, 161, 161)
                'border.focused' = [VT]::RGB(38, 139, 210)
                'border.error' = [VT]::RGB(220, 50, 47)
                
                'task.completed' = [VT]::RGB(108, 113, 196)
                'task.pending' = [VT]::RGB(40, 40, 40)
                'task.deleted' = [VT]::RGB(220, 50, 47)
                'task.waiting' = [VT]::RGB(181, 137, 0)
                
                'priority.high' = [VT]::RGB(220, 50, 47)
                'priority.medium' = [VT]::RGB(181, 137, 0)
                'priority.low' = [VT]::RGB(38, 139, 210)
                'priority.none' = [VT]::RGB(147, 161, 161)
                
                'project.color' = [VT]::RGB(42, 161, 152)
                'tag.color' = [VT]::RGB(108, 113, 196)
                'due.overdue' = [VT]::RGB(220, 50, 47)
                'due.today' = [VT]::RGB(181, 137, 0)
                'due.soon' = [VT]::RGB(38, 139, 210)
                'due.normal' = [VT]::RGB(147, 161, 161)
                
                'filter.active' = [VT]::RGB(42, 161, 152)
                'filter.inactive' = [VT]::RGB(147, 161, 161)
                'command.prompt' = [VT]::RGB(38, 139, 210)
                'status.ready' = [VT]::RGB(133, 153, 0)
                'status.error' = [VT]::RGB(220, 50, 47)
            }
        }
        
        # Dark theme
        $this._themes["dark"] = @{
            Name = "Dark"
            Colors = @{
                'text.primary' = [VT]::RGB(230, 230, 230)
                'text.secondary' = [VT]::RGB(180, 180, 180)
                'text.muted' = [VT]::RGB(120, 120, 120)
                'text.highlight' = [VT]::RGB(255, 255, 255)
                'text.error' = [VT]::RGB(255, 85, 85)
                'text.warning' = [VT]::RGB(255, 215, 0)
                'text.success' = [VT]::RGB(85, 255, 85)
                'text.info' = [VT]::RGB(85, 170, 255)
                
                'background.normal' = [VT]::RGB(40, 40, 40)
                'background.selected' = [VT]::RGB(60, 60, 60)
                'background.focused' = [VT]::RGB(80, 80, 80)
                'background.urgent' = [VT]::RGB(80, 40, 40)
                
                'border.normal' = [VT]::RGB(100, 100, 100)
                'border.focused' = [VT]::RGB(85, 170, 255)
                'border.error' = [VT]::RGB(255, 85, 85)
                
                'task.completed' = [VT]::RGB(130, 150, 255)
                'task.pending' = [VT]::RGB(230, 230, 230)
                'task.deleted' = [VT]::RGB(255, 85, 85)
                'task.waiting' = [VT]::RGB(255, 215, 0)
                
                'priority.high' = [VT]::RGB(255, 85, 85)
                'priority.medium' = [VT]::RGB(255, 215, 0)
                'priority.low' = [VT]::RGB(85, 170, 255)
                'priority.none' = [VT]::RGB(150, 150, 150)
                
                'project.color' = [VT]::RGB(85, 255, 170)
                'tag.color' = [VT]::RGB(170, 170, 255)
                'due.overdue' = [VT]::RGB(255, 85, 85)
                'due.today' = [VT]::RGB(255, 215, 0)
                'due.soon' = [VT]::RGB(85, 170, 255)
                'due.normal' = [VT]::RGB(180, 180, 180)
                
                'filter.active' = [VT]::RGB(85, 255, 170)
                'filter.inactive' = [VT]::RGB(120, 120, 120)
                'command.prompt' = [VT]::RGB(85, 170, 255)
                'status.ready' = [VT]::RGB(85, 255, 85)
                'status.error' = [VT]::RGB(255, 85, 85)
            }
        }
        
        # TaskWarrior-compatible theme
        $this._themes["taskwarrior"] = @{
            Name = "TaskWarrior Compatible"
            Colors = @{
                'text.primary' = [VT]::RGB(255, 255, 255)
                'text.secondary' = [VT]::RGB(192, 192, 192)
                'text.muted' = [VT]::RGB(128, 128, 128)
                'text.highlight' = [VT]::RGB(255, 255, 0)
                'text.error' = [VT]::RGB(255, 0, 0)
                'text.warning' = [VT]::RGB(255, 128, 0)
                'text.success' = [VT]::RGB(0, 255, 0)
                'text.info' = [VT]::RGB(0, 128, 255)
                
                'background.normal' = [VT]::RGB(0, 0, 0)
                'background.selected' = [VT]::RGB(0, 0, 128)
                'background.focused' = [VT]::RGB(0, 64, 0)
                'background.urgent' = [VT]::RGB(128, 0, 0)
                
                'border.normal' = [VT]::RGB(128, 128, 128)
                'border.focused' = [VT]::RGB(0, 255, 255)
                'border.error' = [VT]::RGB(255, 0, 0)
                
                'task.completed' = [VT]::RGB(0, 255, 0)
                'task.pending' = [VT]::RGB(255, 255, 255)
                'task.deleted' = [VT]::RGB(255, 0, 0)
                'task.waiting' = [VT]::RGB(255, 255, 0)
                
                'priority.high' = [VT]::RGB(255, 0, 0)
                'priority.medium' = [VT]::RGB(255, 255, 0)
                'priority.low' = [VT]::RGB(0, 255, 255)
                'priority.none' = [VT]::RGB(192, 192, 192)
                
                'project.color' = [VT]::RGB(0, 255, 128)
                'tag.color' = [VT]::RGB(128, 128, 255)
                'due.overdue' = [VT]::RGB(255, 0, 0)
                'due.today' = [VT]::RGB(255, 128, 0)
                'due.soon' = [VT]::RGB(255, 255, 0)
                'due.normal' = [VT]::RGB(192, 192, 192)
                
                'filter.active' = [VT]::RGB(0, 255, 255)
                'filter.inactive' = [VT]::RGB(128, 128, 128)
                'command.prompt' = [VT]::RGB(0, 255, 255)
                'status.ready' = [VT]::RGB(0, 255, 0)
                'status.error' = [VT]::RGB(255, 0, 0)
            }
        }
    }
    
    # Initialize urgency-based color mapping
    [void] InitializeUrgencyColors() {
        $this._urgencyColorMap = @{
            'critical' = @{ Min = 15.0; ColorKey = 'priority.high' }
            'high' = @{ Min = 10.0; ColorKey = 'text.error' }
            'elevated' = @{ Min = 8.0; ColorKey = 'text.warning' }
            'medium' = @{ Min = 5.0; ColorKey = 'text.info' }
            'normal' = @{ Min = 1.0; ColorKey = 'text.primary' }
            'low' = @{ Min = 0.0; ColorKey = 'text.muted' }
        }
    }
    
    # Get color for a specific theme key
    [string] GetColor([string]$colorKey) {
        # Check cache first
        $cacheKey = "$($this._currentTheme)_$colorKey"
        if ($this._colorCache.ContainsKey($cacheKey)) {
            return $this._colorCache[$cacheKey]
        }
        
        # Check custom colors first
        if ($this._customColors.ContainsKey($colorKey)) {
            $color = $this._customColors[$colorKey]
            $this._colorCache[$cacheKey] = $color
            return $color
        }
        
        # Get from current theme
        $theme = $this._themes[$this._currentTheme]
        if ($theme -and $theme.Colors.ContainsKey($colorKey)) {
            $color = $theme.Colors[$colorKey]
            $this._colorCache[$cacheKey] = $color
            return $color
        }
        
        # Fallback to default theme
        if ($this._currentTheme -ne "default" -and $this._themes["default"].Colors.ContainsKey($colorKey)) {
            $color = $this._themes["default"].Colors[$colorKey]
            $this._colorCache[$cacheKey] = $color
            return $color
        }
        
        # Ultimate fallback
        return [VT]::RGB(255, 255, 255)
    }
    
    # Get color based on task urgency
    [string] GetUrgencyColor([double]$urgency) {
        foreach ($level in $this._urgencyColorMap.Keys) {
            $mapping = $this._urgencyColorMap[$level]
            if ($urgency -ge $mapping.Min) {
                return $this.GetColor($mapping.ColorKey)
            }
        }
        
        return $this.GetColor('text.muted')
    }
    
    # Get color for task status
    [string] GetTaskStatusColor([string]$status) {
        $colorKey = "task.$($status.ToLower())"
        return $this.GetColor($colorKey)
    }
    
    # Get color for task priority
    [string] GetPriorityColor([string]$priority) {
        switch ($priority) {
            'H' { return $this.GetColor('priority.high') }
            'M' { return $this.GetColor('priority.medium') }
            'L' { return $this.GetColor('priority.low') }
            default { return $this.GetColor('priority.none') }
        }
    }
    
    # Get color for due date
    [string] GetDueColor([datetime]$dueDate) {
        $now = [datetime]::Now
        $daysUntilDue = ($dueDate - $now).Days
        
        if ($daysUntilDue -lt 0) {
            return $this.GetColor('due.overdue')
        } elseif ($daysUntilDue -eq 0) {
            return $this.GetColor('due.today')
        } elseif ($daysUntilDue -le 7) {
            return $this.GetColor('due.soon')
        } else {
            return $this.GetColor('due.normal')
        }
    }
    
    # Apply theme colors to text with proper reset
    [string] ColorizeText([string]$text, [string]$colorKey, [bool]$includeReset = $true) {
        $color = $this.GetColor($colorKey)
        if ($includeReset) {
            return "${color}${text}$([VT]::Reset())"
        } else {
            return "${color}${text}"
        }
    }
    
    # Switch to different theme
    [void] SetTheme([string]$themeName) {
        if ($this._themes.ContainsKey($themeName)) {
            $this._currentTheme = $themeName
            $this._colorCache.Clear()  # Clear cache when theme changes
        } else {
            throw "Unknown theme: $themeName"
        }
    }
    
    # Add custom color override
    [void] SetCustomColor([string]$colorKey, [string]$color) {
        $this._customColors[$colorKey] = $color
        
        # Clear affected cache entries
        $keysToRemove = @()
        foreach ($cacheKey in $this._colorCache.Keys) {
            if ($cacheKey.EndsWith("_$colorKey")) {
                $keysToRemove += $cacheKey
            }
        }
        foreach ($key in $keysToRemove) {
            $this._colorCache.Remove($key)
        }
    }
    
    # Get available themes
    [string[]] GetAvailableThemes() {
        return $this._themes.Keys
    }
    
    # Get current theme info
    [hashtable] GetCurrentTheme() {
        return $this._themes[$this._currentTheme]
    }
    
    # Create complex styled text with multiple colors
    [string] CreateStyledText([hashtable[]]$segments) {
        $result = ""
        foreach ($segment in $segments) {
            $text = $segment.Text
            $colorKey = $segment.Color
            $color = $this.GetColor($colorKey)
            $result += "${color}${text}"
        }
        $result += [VT]::Reset()
        return $result
    }
    
    # Format task line with appropriate colors
    [string] FormatTaskLine([hashtable]$task, [string]$format = "standard") {
        switch ($format) {
            "standard" {
                return $this.FormatStandardTaskLine($task)
            }
            "compact" {
                return $this.FormatCompactTaskLine($task)
            }
            "detailed" {
                return $this.FormatDetailedTaskLine($task)
            }
            default {
                return $this.FormatStandardTaskLine($task)
            }
        }
    }
    
    # Format standard task line
    hidden [string] FormatStandardTaskLine([hashtable]$task) {
        $segments = @()
        
        # ID
        $segments += @{ Text = $task.id.ToString().PadLeft(3); Color = 'text.muted' }
        $segments += @{ Text = " "; Color = 'text.primary' }
        
        # Priority
        if ($task.priority) {
            $priorityColor = $this.GetPriorityColor($task.priority)
            $segments += @{ Text = "[$($task.priority)]"; Color = $this.GetColorKeyFromVTSequence($priorityColor) }
            $segments += @{ Text = " "; Color = 'text.primary' }
        }
        
        # Project
        if ($task.project) {
            $segments += @{ Text = "$($task.project):"; Color = 'project.color' }
            $segments += @{ Text = " "; Color = 'text.primary' }
        }
        
        # Description
        $descColor = $this.GetTaskStatusColor($task.status)
        $segments += @{ Text = $task.description; Color = $this.GetColorKeyFromVTSequence($descColor) }
        
        # Tags
        if ($task.tags -and $task.tags.Count -gt 0) {
            $segments += @{ Text = " +"; Color = 'text.muted' }
            foreach ($tag in $task.tags) {
                $segments += @{ Text = $tag; Color = 'tag.color' }
                if ($tag -ne $task.tags[-1]) {
                    $segments += @{ Text = " +"; Color = 'text.muted' }
                }
            }
        }
        
        # Due date
        if ($task.due) {
            $dueColor = $this.GetDueColor($task.due)
            $segments += @{ Text = " due:$($task.due.ToString('yyyy-MM-dd'))"; Color = $this.GetColorKeyFromVTSequence($dueColor) }
        }
        
        return $this.CreateStyledText($segments)
    }
    
    # Convert VT sequence back to color key (helper method)
    hidden [string] GetColorKeyFromVTSequence([string]$vtSequence) {
        # This is a simplified reverse lookup - in practice you'd maintain a reverse mapping
        return 'text.primary'  # Fallback
    }
    
    # Clear color cache
    [void] ClearColorCache() {
        $this._colorCache.Clear()
    }
}
```

### 9. Input/Output Coordination Layer

Dedicated system for handling all terminal I/O operations:

```powershell
class InputOutputCoordinator {
    hidden [hashtable] $_inputHandlers = @{}
    hidden [hashtable] $_focusStack = @{}
    hidden [string] $_currentFocusId = $null
    hidden [bool] $_inputEnabled = $true
    hidden [System.Threading.CancellationTokenSource] $_cancellationSource
    hidden [Logger] $_logger = $null
    hidden [RenderEventCoordinator] $_eventCoordinator = $null
    
    # Mouse support
    hidden [bool] $_mouseEnabled = $false
    hidden [hashtable] $_mouseState = @{
        LastX = 0
        LastY = 0
        ButtonState = 0
        DragStartX = 0
        DragStartY = 0
        IsDragging = $false
    }
    
    InputOutputCoordinator([Logger]$logger, [RenderEventCoordinator]$eventCoordinator) {
        $this._logger = $logger
        $this._eventCoordinator = $eventCoordinator
        $this._cancellationSource = [System.Threading.CancellationTokenSource]::new()
        $this.InitializeInputSystem()
    }
    
    # Initialize input processing system
    [void] InitializeInputSystem() {
        # Enable mouse reporting if supported
        try {
            [Console]::Write("`e[?1000h`e[?1002h`e[?1015h`e[?1006h")
            $this._mouseEnabled = $true
            if ($this._logger) {
                $this._logger.Debug("InputOutputCoordinator: Mouse support enabled")
            }
        } catch {
            if ($this._logger) {
                $this._logger.Warn("InputOutputCoordinator: Mouse support not available")
            }
        }
        
        # Set up signal handlers
        $this.SetupSignalHandlers()
    }
    
    # Register input handler for component
    [void] RegisterInputHandler([string]$componentId, [int]$priority, [scriptblock]$handler) {
        if (-not $this._inputHandlers.ContainsKey($priority)) {
            $this._inputHandlers[$priority] = @{}
        }
        
        $this._inputHandlers[$priority][$componentId] = @{
            Handler = $handler
            ComponentId = $componentId
            Enabled = $true
            RegisteredAt = [datetime]::Now
        }
        
        if ($this._logger) {
            $this._logger.Debug("InputOutputCoordinator: Registered input handler for $componentId (priority $priority)")
        }
    }
    
    # Unregister input handler
    [void] UnregisterInputHandler([string]$componentId) {
        foreach ($priority in $this._inputHandlers.Keys) {
            if ($this._inputHandlers[$priority].ContainsKey($componentId)) {
                $this._inputHandlers[$priority].Remove($componentId)
                if ($this._logger) {
                    $this._logger.Debug("InputOutputCoordinator: Unregistered input handler for $componentId")
                }
                break
            }
        }
    }
    
    # Set focus to specific component
    [void] SetFocus([string]$componentId, [bool]$pushToStack = $true) {
        if ($pushToStack -and $this._currentFocusId) {
            # Push current focus to stack
            $stackKey = [guid]::NewGuid().ToString()
            $this._focusStack[$stackKey] = @{
                ComponentId = $this._currentFocusId
                Timestamp = [datetime]::Now
            }
        }
        
        $previousFocus = $this._currentFocusId
        $this._currentFocusId = $componentId
        
        # Publish focus change event
        if ($this._eventCoordinator) {
            $this._eventCoordinator.PublishEvent('FocusChanged', @{
                PreviousFocus = $previousFocus
                NewFocus = $componentId
                Timestamp = [datetime]::Now
            })
        }
        
        if ($this._logger) {
            $this._logger.Debug("InputOutputCoordinator: Focus changed from $previousFocus to $componentId")
        }
    }
    
    # Restore previous focus from stack
    [void] RestorePreviousFocus() {
        if ($this._focusStack.Count -gt 0) {
            $latestEntry = $this._focusStack.Values | Sort-Object Timestamp -Descending | Select-Object -First 1
            $this.SetFocus($latestEntry.ComponentId, $false)
            
            # Remove from stack
            $keyToRemove = $this._focusStack.Keys | Where-Object { $this._focusStack[$_].ComponentId -eq $latestEntry.ComponentId } | Select-Object -First 1
            if ($keyToRemove) {
                $this._focusStack.Remove($keyToRemove)
            }
        }
    }
    
    # Main input processing loop
    [void] StartInputProcessing() {
        $task = [System.Threading.Tasks.Task]::Run({
            while (-not $this._cancellationSource.Token.IsCancellationRequested) {
                try {
                    if ([Console]::KeyAvailable) {
                        $keyInfo = [Console]::ReadKey($true)
                        $this.ProcessKeyInput($keyInfo)
                    }
                    
                    # Check for mouse input (simplified - real implementation would parse ANSI sequences)
                    $this.ProcessMouseInput()
                    
                    # Small delay to prevent CPU spinning
                    [System.Threading.Thread]::Sleep(10)
                    
                } catch {
                    if ($this._logger) {
                        $this._logger.Error("InputOutputCoordinator: Error in input processing loop", $_)
                    }
                }
            }
        })
    }
    
    # Process keyboard input
    hidden [void] ProcessKeyInput([System.ConsoleKeyInfo]$keyInfo) {
        if (-not $this._inputEnabled) { return }
        
        $inputEvent = @{
            Type = 'Keyboard'
            Key = $keyInfo.Key
            KeyChar = $keyInfo.KeyChar
            Modifiers = $keyInfo.Modifiers
            Timestamp = [datetime]::Now
            FocusedComponent = $this._currentFocusId
        }
        
        $handled = $false
        
        # Process global hotkeys first (highest priority)
        $handled = $this.ProcessGlobalHotkeys($inputEvent)
        
        if (-not $handled) {
            # Process handlers in priority order (highest first)
            $priorities = $this._inputHandlers.Keys | Sort-Object -Descending
            foreach ($priority in $priorities) {
                $handlers = $this._inputHandlers[$priority]
                foreach ($componentId in $handlers.Keys) {
                    $handlerInfo = $handlers[$componentId]
                    if ($handlerInfo.Enabled) {
                        try {
                            $result = $handlerInfo.Handler.Invoke($inputEvent)
                            if ($result -eq $true) {
                                $handled = $true
                                break
                            }
                        } catch {
                            if ($this._logger) {
                                $this._logger.Error("InputOutputCoordinator: Error in input handler for $componentId", $_)
                            }
                        }
                    }
                }
                if ($handled) { break }
            }
        }
        
        # Log unhandled input for debugging
        if (-not $handled -and $this._logger) {
            $this._logger.Debug("InputOutputCoordinator: Unhandled input - Key: $($keyInfo.Key), Char: '$($keyInfo.KeyChar)', Modifiers: $($keyInfo.Modifiers)")
        }
    }
    
    # Process global hotkeys
    hidden [bool] ProcessGlobalHotkeys([hashtable]$inputEvent) {
        # Global quit
        if ($inputEvent.Key -eq 'Q' -or ($inputEvent.Key -eq 'C' -and $inputEvent.Modifiers.HasFlag([System.ConsoleModifiers]::Control))) {
            if ($this._eventCoordinator) {
                $this._eventCoordinator.PublishEvent('ApplicationExit', @{ ExitReason = 'UserRequest' })
            }
            return $true
        }
        
        # Global help
        if ($inputEvent.Key -eq 'F1' -or ($inputEvent.Key -eq 'H' -and $inputEvent.Modifiers.HasFlag([System.ConsoleModifiers]::Control))) {
            if ($this._eventCoordinator) {
                $this._eventCoordinator.PublishEvent('ShowHelp', @{})
            }
            return $true
        }
        
        # Global refresh
        if ($inputEvent.Key -eq 'F5' -or ($inputEvent.Key -eq 'R' -and $inputEvent.Modifiers.HasFlag([System.ConsoleModifiers]::Control))) {
            if ($this._eventCoordinator) {
                $this._eventCoordinator.PublishEvent('RefreshRequested', @{})
            }
            return $true
        }
        
        return $false
    }
    
    # Process mouse input (simplified implementation)
    hidden [void] ProcessMouseInput() {
        # In a real implementation, this would parse ANSI mouse sequences
        # For now, this is a placeholder showing the structure
    }
    
    # Setup signal handlers for terminal events
    hidden [void] SetupSignalHandlers() {
        # Window resize handling
        [Console]::TreatControlCAsInput = $false
        
        # Register for console events (Windows-specific, Linux would use different approach)
        try {
            $handler = {
                param($eventType)
                if ($eventType -eq 'WindowBufferSizeChanged') {
                    if ($this._eventCoordinator) {
                        $this._eventCoordinator.PublishEvent('WindowResized', @{
                            NewWidth = [Console]::WindowWidth
                            NewHeight = [Console]::WindowHeight
                        })
                    }
                }
            }
            
            # This would need platform-specific implementation
            if ($this._logger) {
                $this._logger.Debug("InputOutputCoordinator: Signal handlers configured")
            }
        } catch {
            if ($this._logger) {
                $this._logger.Warn("InputOutputCoordinator: Could not setup signal handlers: $_")
            }
        }
    }
    
    # Enable/disable input processing
    [void] EnableInput([bool]$enabled) {
        $this._inputEnabled = $enabled
        if ($this._logger) {
            $this._logger.Debug("InputOutputCoordinator: Input processing $(if ($enabled) { 'enabled' } else { 'disabled' })")
        }
    }
    
    # Get input statistics
    [hashtable] GetInputStatistics() {
        $totalHandlers = 0
        $enabledHandlers = 0
        
        foreach ($priority in $this._inputHandlers.Keys) {
            $handlers = $this._inputHandlers[$priority]
            $totalHandlers += $handlers.Count
            $enabledHandlers += ($handlers.Values | Where-Object { $_.Enabled }).Count
        }
        
        return @{
            TotalHandlers = $totalHandlers
            EnabledHandlers = $enabledHandlers
            CurrentFocus = $this._currentFocusId
            FocusStackDepth = $this._focusStack.Count
            MouseEnabled = $this._mouseEnabled
            InputEnabled = $this._inputEnabled
        }
    }
    
    # Cleanup and dispose
    [void] Dispose() {
        $this._cancellationSource.Cancel()
        
        # Disable mouse reporting
        if ($this._mouseEnabled) {
            try {
                [Console]::Write("`e[?1000l`e[?1002l`e[?1015l`e[?1006l")
            } catch { }
        }
        
        $this._inputHandlers.Clear()
        $this._focusStack.Clear()
        
        if ($this._logger) {
            $this._logger.Debug("InputOutputCoordinator: Disposed successfully")
        }
    }
}
```

### 10. Window/Terminal Management System

Comprehensive terminal state management and restoration:

```powershell
class TerminalManager {
    hidden [hashtable] $_originalState = @{}
    hidden [hashtable] $_currentState = @{}
    hidden [bool] $_isRawMode = $false
    hidden [bool] $_isAlternateBuffer = $false
    hidden [Logger] $_logger = $null
    hidden [RenderEventCoordinator] $_eventCoordinator = $null
    
    # Terminal capabilities
    hidden [hashtable] $_capabilities = @{}
    hidden [bool] $_capabilitiesDetected = $false
    
    TerminalManager([Logger]$logger, [RenderEventCoordinator]$eventCoordinator) {
        $this._logger = $logger
        $this._eventCoordinator = $eventCoordinator
        $this.DetectCapabilities()
        $this.SaveOriginalState()
    }
    
    # Detect terminal capabilities
    [void] DetectCapabilities() {
        $this._capabilities = @{
            # VT100 capabilities
            SupportsColors = $this.TestColorSupport()
            Supports256Colors = $this.Test256ColorSupport()
            SupportsTrueColor = $this.TestTrueColorSupport()
            SupportsAlternateBuffer = $this.TestAlternateBufferSupport()
            SupportsMouse = $this.TestMouseSupport()
            SupportsUnicode = $this.TestUnicodeSupport()
            
            # Terminal identification
            TerminalType = $env:TERM
            TerminalProgram = $env:TERM_PROGRAM
            WindowsTerminal = $env:WT_SESSION -ne $null
            
            # Screen dimensions
            MaxWidth = [Console]::LargestWindowWidth
            MaxHeight = [Console]::LargestWindowHeight
            CurrentWidth = [Console]::WindowWidth
            CurrentHeight = [Console]::WindowHeight
            
            # Platform detection
            IsWindows = [System.Environment]::OSVersion.Platform -eq 'Win32NT'
            IsLinux = [System.Environment]::OSVersion.Platform -eq 'Unix'
            IsMacOS = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::OSX)
        }
        
        $this._capabilitiesDetected = $true
        
        if ($this._logger) {
            $this._logger.Info("TerminalManager: Capabilities detected - Colors: $($this._capabilities.SupportsColors), 256: $($this._capabilities.Supports256Colors), TrueColor: $($this._capabilities.SupportsTrueColor)")
        }
    }
    
    # Test color support
    hidden [bool] TestColorSupport() {
        try {
            $originalColor = [Console]::ForegroundColor
            [Console]::ForegroundColor = [ConsoleColor]::Red
            [Console]::ForegroundColor = $originalColor
            return $true
        } catch {
            return $false
        }
    }
    
    # Test 256-color support
    hidden [bool] Test256ColorSupport() {
        $colorTerms = @('xterm-256color', 'screen-256color', 'tmux-256color')
        return $env:TERM -in $colorTerms -or $env:COLORTERM -eq 'truecolor'
    }
    
    # Test true color support
    hidden [bool] TestTrueColorSupport() {
        return $env:COLORTERM -eq 'truecolor' -or $this._capabilities.WindowsTerminal
    }
    
    # Test alternate buffer support
    hidden [bool] TestAlternateBufferSupport() {
        # Most modern terminals support this
        return $env:TERM -like '*xterm*' -or $env:TERM -like '*screen*' -or $this._capabilities.WindowsTerminal
    }
    
    # Test mouse support
    hidden [bool] TestMouseSupport() {
        # Most terminals support basic mouse reporting
        return -not ($env:TERM -eq 'dumb' -or $env:TERM -eq 'unknown')
    }
    
    # Test Unicode support
    hidden [bool] TestUnicodeSupport() {
        try {
            $encoding = [Console]::OutputEncoding
            return $encoding.EncodingName -like '*UTF*' -or $encoding.CodePage -eq 65001
        } catch {
            return $false
        }
    }
    
    # Save original terminal state
    [void] SaveOriginalState() {
        try {
            $this._originalState = @{
                # Console properties
                ForegroundColor = [Console]::ForegroundColor
                BackgroundColor = [Console]::BackgroundColor
                CursorVisible = [Console]::CursorVisible
                CursorLeft = [Console]::CursorLeft
                CursorTop = [Console]::CursorTop
                OutputEncoding = [Console]::OutputEncoding
                InputEncoding = [Console]::InputEncoding
                TreatControlCAsInput = [Console]::TreatControlCAsInput
                
                # Window properties
                WindowWidth = [Console]::WindowWidth
                WindowHeight = [Console]::WindowHeight
                WindowLeft = [Console]::WindowLeft
                WindowTop = [Console]::WindowTop
                BufferWidth = [Console]::BufferWidth
                BufferHeight = [Console]::BufferHeight
                
                # Environment
                TerminalState = 'Normal'
                Timestamp = [datetime]::Now
            }
            
            if ($this._logger) {
                $this._logger.Debug("TerminalManager: Original terminal state saved")
            }
        } catch {
            if ($this._logger) {
                $this._logger.Error("TerminalManager: Failed to save original state", $_)
            }
        }
    }
    
    # Enter raw mode for TUI
    [void] EnterRawMode() {
        if ($this._isRawMode) { return }
        
        try {
            # Configure console for TUI mode
            [Console]::TreatControlCAsInput = $true
            [Console]::CursorVisible = $false
            
            # Set UTF-8 encoding for Unicode support
            if ($this._capabilities.SupportsUnicode) {
                [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
                [Console]::InputEncoding = [System.Text.Encoding]::UTF8
            }
            
            # Enter alternate screen buffer if supported
            if ($this._capabilities.SupportsAlternateBuffer) {
                [Console]::Write("`e[?1049h")  # Enable alternate buffer
                $this._isAlternateBuffer = $true
            }
            
            # Configure mouse reporting if supported
            if ($this._capabilities.SupportsMouse) {
                [Console]::Write("`e[?1000h`e[?1002h`e[?1015h`e[?1006h")
            }
            
            # Disable cursor blinking
            [Console]::Write("`e[?12l")
            
            # Save cursor position
            [Console]::Write("`e[s")
            
            $this._isRawMode = $true
            
            if ($this._logger) {
                $this._logger.Info("TerminalManager: Entered raw mode successfully")
            }
            
            # Publish event
            if ($this._eventCoordinator) {
                $this._eventCoordinator.PublishEvent('TerminalModeChanged', @{
                    Mode = 'Raw'
                    AlternateBuffer = $this._isAlternateBuffer
                })
            }
            
        } catch {
            if ($this._logger) {
                $this._logger.Error("TerminalManager: Failed to enter raw mode", $_)
            }
            throw
        }
    }
    
    # Exit raw mode and restore normal terminal
    [void] ExitRawMode() {
        if (-not $this._isRawMode) { return }
        
        try {
            # Restore cursor position
            [Console]::Write("`e[u")
            
            # Show cursor
            [Console]::Write("`e[?25h")
            
            # Disable mouse reporting
            if ($this._capabilities.SupportsMouse) {
                [Console]::Write("`e[?1000l`e[?1002l`e[?1015l`e[?1006l")
            }
            
            # Exit alternate screen buffer
            if ($this._isAlternateBuffer) {
                [Console]::Write("`e[?1049l")
                $this._isAlternateBuffer = $false
            }
            
            # Reset terminal attributes
            [Console]::Write("`e[0m")
            
            $this._isRawMode = $false
            
            if ($this._logger) {
                $this._logger.Info("TerminalManager: Exited raw mode successfully")
            }
            
            # Publish event
            if ($this._eventCoordinator) {
                $this._eventCoordinator.PublishEvent('TerminalModeChanged', @{
                    Mode = 'Normal'
                    AlternateBuffer = $false
                })
            }
            
        } catch {
            if ($this._logger) {
                $this._logger.Error("TerminalManager: Failed to exit raw mode", $_)
            }
        }
    }
    
    # Restore original terminal state
    [void] RestoreOriginalState() {
        try {
            # Exit raw mode first
            $this.ExitRawMode()
            
            # Restore console properties
            if ($this._originalState.Count -gt 0) {
                [Console]::ForegroundColor = $this._originalState.ForegroundColor
                [Console]::BackgroundColor = $this._originalState.BackgroundColor
                [Console]::CursorVisible = $this._originalState.CursorVisible
                [Console]::TreatControlCAsInput = $this._originalState.TreatControlCAsInput
                [Console]::OutputEncoding = $this._originalState.OutputEncoding
                [Console]::InputEncoding = $this._originalState.InputEncoding
                
                # Try to restore cursor position (may fail if window size changed)
                try {
                    [Console]::SetCursorPosition($this._originalState.CursorLeft, $this._originalState.CursorTop)
                } catch { }
            }
            
            if ($this._logger) {
                $this._logger.Info("TerminalManager: Original terminal state restored")
            }
            
        } catch {
            if ($this._logger) {
                $this._logger.Error("TerminalManager: Failed to restore original state", $_)
            }
        }
    }
    
    # Handle window resize
    [void] HandleWindowResize([int]$newWidth, [int]$newHeight) {
        $oldWidth = $this._currentState.WindowWidth
        $oldHeight = $this._currentState.WindowHeight
        
        $this._currentState.WindowWidth = $newWidth
        $this._currentState.WindowHeight = $newHeight
        
        if ($this._logger) {
            $this._logger.Info("TerminalManager: Window resized from ${oldWidth}x${oldHeight} to ${newWidth}x${newHeight}")
        }
        
        # Publish resize event
        if ($this._eventCoordinator) {
            $this._eventCoordinator.PublishEvent('WindowResized', @{
                OldWidth = $oldWidth
                OldHeight = $oldHeight
                NewWidth = $newWidth
                NewHeight = $newHeight
                Timestamp = [datetime]::Now
            })
        }
    }
    
    # Clear screen with proper method based on capabilities
    [void] ClearScreen() {
        if ($this._capabilities.SupportsAlternateBuffer -and $this._isAlternateBuffer) {
            [Console]::Write("`e[2J`e[H")
        } else {
            [Console]::Clear()
        }
    }
    
    # Emergency recovery (for crash situations)
    [void] EmergencyRestore() {
        try {
            # Force restore terminal to safe state
            [Console]::Write("`e[?25h`e[0m`e[?1049l`e[?1000l")
            [Console]::CursorVisible = $true
            [Console]::TreatControlCAsInput = $false
            
            if ($this._logger) {
                $this._logger.Warn("TerminalManager: Emergency restore performed")
            }
        } catch {
            # Last resort - just try to show cursor
            try {
                [Console]::Write("`e[?25h")
            } catch { }
        }
    }
    
    # Get terminal capabilities
    [hashtable] GetCapabilities() {
        return $this._capabilities.Clone()
    }
    
    # Get current terminal state
    [hashtable] GetCurrentState() {
        return @{
            IsRawMode = $this._isRawMode
            IsAlternateBuffer = $this._isAlternateBuffer
            CurrentWidth = [Console]::WindowWidth
            CurrentHeight = [Console]::WindowHeight
            CursorVisible = [Console]::CursorVisible
            Capabilities = $this._capabilities.Clone()
        }
    }
    
    # Dispose and cleanup
    [void] Dispose() {
        $this.RestoreOriginalState()
        
        if ($this._logger) {
            $this._logger.Debug("TerminalManager: Disposed successfully")
        }
    }
}
```

### 11. Component Lifecycle Management

Manages component creation, initialization, and disposal:

```powershell
class ComponentLifecycleManager {
    hidden [hashtable] $_components = @{}
    hidden [hashtable] $_componentFactories = @{}
    hidden [hashtable] $_dependencies = @{}
    hidden [hashtable] $_initializationOrder = @{}
    hidden [Logger] $_logger = $null
    hidden [RenderEventCoordinator] $_eventCoordinator = $null
    hidden [object] $_serviceContainer = $null
    
    ComponentLifecycleManager([Logger]$logger, [RenderEventCoordinator]$eventCoordinator, [object]$serviceContainer) {
        $this._logger = $logger
        $this._eventCoordinator = $eventCoordinator
        $this._serviceContainer = $serviceContainer
        $this.RegisterBuiltInFactories()
    }
    
    # Register component factories
    [void] RegisterBuiltInFactories() {
        # Task list component factory
        $this._componentFactories['TaskList'] = {
            param($config, $dependencies)
            
            $taskList = [TaskListComponent]::new()
            $taskList.SetLogger($dependencies.Logger)
            $taskList.SetThemeManager($dependencies.ThemeManager)
            $taskList.SetVirtualScroller($dependencies.VirtualScroller)
            $taskList.Initialize($config)
            
            return $taskList
        }
        
        # Header component factory
        $this._componentFactories['Header'] = {
            param($config, $dependencies)
            
            $header = [HeaderComponent]::new()
            $header.SetLogger($dependencies.Logger)
            $header.SetThemeManager($dependencies.ThemeManager)
            $header.Initialize($config)
            
            return $header
        }
        
        # Filter bar component factory
        $this._componentFactories['FilterBar'] = {
            param($config, $dependencies)
            
            $filterBar = [FilterBarComponent]::new()
            $filterBar.SetLogger($dependencies.Logger)
            $filterBar.SetThemeManager($dependencies.ThemeManager)
            $filterBar.SetInputCoordinator($dependencies.InputCoordinator)
            $filterBar.Initialize($config)
            
            return $filterBar
        }
        
        # Status bar component factory
        $this._componentFactories['StatusBar'] = {
            param($config, $dependencies)
            
            $statusBar = [StatusBarComponent]::new()
            $statusBar.SetLogger($dependencies.Logger)
            $statusBar.SetThemeManager($dependencies.ThemeManager)
            $statusBar.Initialize($config)
            
            return $statusBar
        }
        
        # Command bar component factory
        $this._componentFactories['CommandBar'] = {
            param($config, $dependencies)
            
            $commandBar = [CommandBarComponent]::new()
            $commandBar.SetLogger($dependencies.Logger)
            $commandBar.SetThemeManager($dependencies.ThemeManager)
            $commandBar.SetInputCoordinator($dependencies.InputCoordinator)
            $commandBar.Initialize($config)
            
            return $commandBar
        }
    }
    
    # Register custom component factory
    [void] RegisterFactory([string]$componentType, [scriptblock]$factory) {
        $this._componentFactories[$componentType] = $factory
        
        if ($this._logger) {
            $this._logger.Debug("ComponentLifecycleManager: Registered factory for $componentType")
        }
    }
    
    # Define component dependencies
    [void] SetDependencies([string]$componentType, [string[]]$dependencies) {
        $this._dependencies[$componentType] = $dependencies
        
        if ($this._logger) {
            $this._logger.Debug("ComponentLifecycleManager: Set dependencies for $componentType - $($dependencies -join ', ')")
        }
    }
    
    # Create component with dependencies
    [object] CreateComponent([string]$componentType, [hashtable]$config = @{}) {
        if (-not $this._componentFactories.ContainsKey($componentType)) {
            throw "No factory registered for component type: $componentType"
        }
        
        # Check if already created
        if ($this._components.ContainsKey($componentType)) {
            if ($this._logger) {
                $this._logger.Debug("ComponentLifecycleManager: Component $componentType already exists, returning existing instance")
            }
            return $this._components[$componentType].Instance
        }
        
        # Resolve dependencies first
        $dependencyInstances = $this.ResolveDependencies($componentType)
        
        try {
            # Create component using factory
            $factory = $this._componentFactories[$componentType]
            $component = $factory.Invoke($config, $dependencyInstances)
            
            # Store component info
            $this._components[$componentType] = @{
                Instance = $component
                Type = $componentType
                Config = $config.Clone()
                Dependencies = $dependencyInstances
                CreatedAt = [datetime]::Now
                State = 'Created'
            }
            
            # Subscribe to lifecycle events
            $this.SubscribeToLifecycleEvents($componentType, $component)
            
            if ($this._logger) {
                $this._logger.Info("ComponentLifecycleManager: Created component $componentType successfully")
            }
            
            # Publish creation event
            if ($this._eventCoordinator) {
                $this._eventCoordinator.PublishEvent('ComponentCreated', @{
                    ComponentType = $componentType
                    ComponentId = $component.GetId()
                })
            }
            
            return $component
            
        } catch {
            if ($this._logger) {
                $this._logger.Error("ComponentLifecycleManager: Failed to create component $componentType", $_)
            }
            throw
        }
    }
    
    # Resolve component dependencies
    hidden [hashtable] ResolveDependencies([string]$componentType) {
        $dependencies = @{}
        
        if ($this._dependencies.ContainsKey($componentType)) {
            foreach ($dependencyType in $this._dependencies[$componentType]) {
                switch ($dependencyType) {
                    'Logger' { 
                        $dependencies.Logger = $this._logger 
                    }
                    'EventCoordinator' { 
                        $dependencies.EventCoordinator = $this._eventCoordinator 
                    }
                    'ThemeManager' { 
                        $dependencies.ThemeManager = $this._serviceContainer.GetService('ThemeManager')
                    }
                    'VirtualScroller' { 
                        $dependencies.VirtualScroller = $this._serviceContainer.GetService('VirtualScroller')
                    }
                    'InputCoordinator' { 
                        $dependencies.InputCoordinator = $this._serviceContainer.GetService('InputCoordinator')
                    }
                    'TerminalManager' { 
                        $dependencies.TerminalManager = $this._serviceContainer.GetService('TerminalManager')
                    }
                    'CacheManager' { 
                        $dependencies.CacheManager = $this._serviceContainer.GetService('CacheManager')
                    }
                    default {
                        # Try to resolve as component or service
                        if ($this._components.ContainsKey($dependencyType)) {
                            $dependencies[$dependencyType] = $this._components[$dependencyType].Instance
                        } else {
                            $dependencies[$dependencyType] = $this._serviceContainer.GetService($dependencyType)
                        }
                    }
                }
            }
        }
        
        return $dependencies
    }
    
    # Subscribe component to lifecycle events
    hidden [void] SubscribeToLifecycleEvents([string]$componentType, [object]$component) {
        # Subscribe to window resize events
        if ($component.PSObject.Methods['OnWindowResize']) {
            $this._eventCoordinator.Subscribe('WindowResized', $componentType, {
                param($eventArgs)
                $component.OnWindowResize($eventArgs.Data.NewWidth, $eventArgs.Data.NewHeight)
            })
        }
        
        # Subscribe to theme changes
        if ($component.PSObject.Methods['OnThemeChanged']) {
            $this._eventCoordinator.Subscribe('ThemeChanged', $componentType, {
                param($eventArgs)
                $component.OnThemeChanged($eventArgs.Data.NewTheme)
            })
        }
        
        # Subscribe to focus changes
        if ($component.PSObject.Methods['OnFocusChanged']) {
            $this._eventCoordinator.Subscribe('FocusChanged', $componentType, {
                param($eventArgs)
                $focused = $eventArgs.Data.NewFocus -eq $component.GetId()
                $component.OnFocusChanged($focused)
            })
        }
        
        # Subscribe to application shutdown
        $this._eventCoordinator.Subscribe('ApplicationExit', $componentType, {
            param($eventArgs)
            $this.DisposeComponent($componentType)
        })
    }
    
    # Initialize component (after creation)
    [void] InitializeComponent([string]$componentType) {
        if (-not $this._components.ContainsKey($componentType)) {
            throw "Component $componentType not found"
        }
        
        $componentInfo = $this._components[$componentType]
        
        if ($componentInfo.State -eq 'Initialized') {
            return
        }
        
        try {
            $component = $componentInfo.Instance
            
            # Call initialization method if exists
            if ($component.PSObject.Methods['Initialize']) {
                $component.Initialize($componentInfo.Config)
            }
            
            # Update state
            $componentInfo.State = 'Initialized'
            $componentInfo.InitializedAt = [datetime]::Now
            
            if ($this._logger) {
                $this._logger.Debug("ComponentLifecycleManager: Initialized component $componentType")
            }
            
            # Publish initialization event
            if ($this._eventCoordinator) {
                $this._eventCoordinator.PublishEvent('ComponentInitialized', @{
                    ComponentType = $componentType
                    ComponentId = $component.GetId()
                })
            }
            
        } catch {
            if ($this._logger) {
                $this._logger.Error("ComponentLifecycleManager: Failed to initialize component $componentType", $_)
            }
            throw
        }
    }
    
    # Get component by type
    [object] GetComponent([string]$componentType) {
        if ($this._components.ContainsKey($componentType)) {
            return $this._components[$componentType].Instance
        }
        return $null
    }
    
    # Get all components of a specific state
    [hashtable[]] GetComponentsByState([string]$state) {
        return $this._components.Values | Where-Object { $_.State -eq $state }
    }
    
    # Start component (make it active)
    [void] StartComponent([string]$componentType) {
        if (-not $this._components.ContainsKey($componentType)) {
            throw "Component $componentType not found"
        }
        
        $componentInfo = $this._components[$componentType]
        
        if ($componentInfo.State -eq 'Running') {
            return
        }
        
        # Initialize if not already done
        if ($componentInfo.State -eq 'Created') {
            $this.InitializeComponent($componentType)
        }
        
        try {
            $component = $componentInfo.Instance
            
            # Call start method if exists
            if ($component.PSObject.Methods['Start']) {
                $component.Start()
            }
            
            # Update state
            $componentInfo.State = 'Running'
            $componentInfo.StartedAt = [datetime]::Now
            
            if ($this._logger) {
                $this._logger.Debug("ComponentLifecycleManager: Started component $componentType")
            }
            
            # Publish start event
            if ($this._eventCoordinator) {
                $this._eventCoordinator.PublishEvent('ComponentStarted', @{
                    ComponentType = $componentType
                    ComponentId = $component.GetId()
                })
            }
            
        } catch {
            if ($this._logger) {
                $this._logger.Error("ComponentLifecycleManager: Failed to start component $componentType", $_)
            }
            throw
        }
    }
    
    # Stop component
    [void] StopComponent([string]$componentType) {
        if (-not $this._components.ContainsKey($componentType)) {
            return
        }
        
        $componentInfo = $this._components[$componentType]
        
        if ($componentInfo.State -ne 'Running') {
            return
        }
        
        try {
            $component = $componentInfo.Instance
            
            # Call stop method if exists
            if ($component.PSObject.Methods['Stop']) {
                $component.Stop()
            }
            
            # Update state
            $componentInfo.State = 'Stopped'
            $componentInfo.StoppedAt = [datetime]::Now
            
            if ($this._logger) {
                $this._logger.Debug("ComponentLifecycleManager: Stopped component $componentType")
            }
            
            # Publish stop event
            if ($this._eventCoordinator) {
                $this._eventCoordinator.PublishEvent('ComponentStopped', @{
                    ComponentType = $componentType
                    ComponentId = $component.GetId()
                })
            }
            
        } catch {
            if ($this._logger) {
                $this._logger.Error("ComponentLifecycleManager: Failed to stop component $componentType", $_)
            }
        }
    }
    
    # Dispose component and cleanup resources
    [void] DisposeComponent([string]$componentType) {
        if (-not $this._components.ContainsKey($componentType)) {
            return
        }
        
        $componentInfo = $this._components[$componentType]
        
        try {
            # Stop component if running
            if ($componentInfo.State -eq 'Running') {
                $this.StopComponent($componentType)
            }
            
            $component = $componentInfo.Instance
            
            # Call dispose method if exists
            if ($component.PSObject.Methods['Dispose']) {
                $component.Dispose()
            }
            
            # Unsubscribe from events
            if ($this._eventCoordinator) {
                $this._eventCoordinator.ClearSubscriptionsForSubscriber($componentType)
            }
            
            # Remove from components
            $this._components.Remove($componentType)
            
            if ($this._logger) {
                $this._logger.Debug("ComponentLifecycleManager: Disposed component $componentType")
            }
            
            # Publish disposal event
            if ($this._eventCoordinator) {
                $this._eventCoordinator.PublishEvent('ComponentDisposed', @{
                    ComponentType = $componentType
                    ComponentId = $component.GetId()
                })
            }
            
        } catch {
            if ($this._logger) {
                $this._logger.Error("ComponentLifecycleManager: Failed to dispose component $componentType", $_)
            }
        }
    }
    
    # Initialize all components in dependency order
    [void] InitializeAllComponents([string[]]$componentTypes) {
        $sortedTypes = $this.TopologicalSort($componentTypes)
        
        foreach ($componentType in $sortedTypes) {
            if ($this._components.ContainsKey($componentType)) {
                $this.InitializeComponent($componentType)
            }
        }
    }
    
    # Start all components in dependency order
    [void] StartAllComponents([string[]]$componentTypes) {
        $sortedTypes = $this.TopologicalSort($componentTypes)
        
        foreach ($componentType in $sortedTypes) {
            if ($this._components.ContainsKey($componentType)) {
                $this.StartComponent($componentType)
            }
        }
    }
    
    # Stop all components in reverse dependency order
    [void] StopAllComponents() {
        $runningComponents = $this._components.Keys | Where-Object { $this._components[$_].State -eq 'Running' }
        $sortedTypes = $this.TopologicalSort($runningComponents)
        
        # Reverse the order for shutdown
        [array]::Reverse($sortedTypes)
        
        foreach ($componentType in $sortedTypes) {
            $this.StopComponent($componentType)
        }
    }
    
    # Dispose all components
    [void] DisposeAllComponents() {
        $allComponents = $this._components.Keys
        $sortedTypes = $this.TopologicalSort($allComponents)
        
        # Reverse the order for disposal
        [array]::Reverse($sortedTypes)
        
        foreach ($componentType in $sortedTypes) {
            $this.DisposeComponent($componentType)
        }
    }
    
    # Topological sort for dependency resolution
    hidden [string[]] TopologicalSort([string[]]$componentTypes) {
        $visited = @{}
        $visiting = @{}
        $result = @()
        
        function Visit([string]$componentType) {
            if ($visiting.ContainsKey($componentType)) {
                throw "Circular dependency detected involving $componentType"
            }
            
            if ($visited.ContainsKey($componentType)) {
                return
            }
            
            $visiting[$componentType] = $true
            
            if ($this._dependencies.ContainsKey($componentType)) {
                foreach ($dependency in $this._dependencies[$componentType]) {
                    if ($componentTypes -contains $dependency) {
                        Visit $dependency
                    }
                }
            }
            
            $visiting.Remove($componentType)
            $visited[$componentType] = $true
            $result += $componentType
        }
        
        foreach ($componentType in $componentTypes) {
            if (-not $visited.ContainsKey($componentType)) {
                Visit $componentType
            }
        }
        
        return $result
    }
    
    # Get component statistics
    [hashtable] GetComponentStatistics() {
        $states = @{}
        foreach ($component in $this._components.Values) {
            if (-not $states.ContainsKey($component.State)) {
                $states[$component.State] = 0
            }
            $states[$component.State]++
        }
        
        return @{
            TotalComponents = $this._components.Count
            RegisteredFactories = $this._componentFactories.Count
            StateBreakdown = $states
            ComponentTypes = $this._components.Keys
        }
    }
    
    # Dispose manager and all components
    [void] Dispose() {
        $this.DisposeAllComponents()
        $this._componentFactories.Clear()
        $this._dependencies.Clear()
        
        if ($this._logger) {
            $this._logger.Debug("ComponentLifecycleManager: Disposed successfully")
        }
    }
}
```

### 12. Performance Monitoring & Diagnostics

Comprehensive performance tracking and diagnostics system:

```powershell
class PerformanceMonitor {
    hidden [hashtable] $_metrics = @{}
    hidden [hashtable] $_timers = @{}
    hidden [hashtable] $_counters = @{}
    hidden [hashtable] $_histograms = @{}
    hidden [int] $_maxHistorySize = 1000
    hidden [Logger] $_logger = $null
    hidden [System.Diagnostics.Stopwatch] $_globalTimer
    
    # Performance thresholds
    hidden [hashtable] $_thresholds = @{
        RenderFrameMs = 16.67  # 60 FPS target
        ComponentRenderMs = 5.0
        CacheHitRatio = 0.85
        MemoryUsageMB = 100
        InputResponseMs = 10.0
        FilterProcessingMs = 50.0
    }
    
    PerformanceMonitor([Logger]$logger) {
        $this._logger = $logger
        $this._globalTimer = [System.Diagnostics.Stopwatch]::StartNew()
        $this.InitializeMetrics()
    }
    
    # Initialize metric tracking
    [void] InitializeMetrics() {
        # Frame rendering metrics
        $this._metrics['Rendering'] = @{
            FrameCount = 0
            TotalFrameTimeMs = 0.0
            AverageFrameTimeMs = 0.0
            MinFrameTimeMs = [double]::MaxValue
            MaxFrameTimeMs = 0.0
            SlowFrames = 0
            DroppedFrames = 0
            FrameHistory = [System.Collections.Generic.Queue[double]]::new()
        }
        
        # Component performance metrics
        $this._metrics['Components'] = @{
            RenderTimes = @{}
            UpdateTimes = @{}
            InitializationTimes = @{}
            MemoryUsage = @{}
        }
        
        # Cache performance metrics
        $this._metrics['Caching'] = @{
            UrgencyCache = @{ Hits = 0; Misses = 0; Size = 0 }
            FilterCache = @{ Hits = 0; Misses = 0; Size = 0 }
            FormattedLineCache = @{ Hits = 0; Misses = 0; Size = 0 }
            VirtualTagCache = @{ Hits = 0; Misses = 0; Size = 0 }
            TotalHitRatio = 0.0
        }
        
        # Input/Output metrics
        $this._metrics['InputOutput'] = @{
            Keystrokes = 0
            InputResponseTimes = [System.Collections.Generic.Queue[double]]::new()
            AverageInputResponseMs = 0.0
            UnhandledInputs = 0
        }
        
        # Memory metrics
        $this._metrics['Memory'] = @{
            WorkingSetMB = 0.0
            PrivateMemoryMB = 0.0
            GCCollections = @{ Gen0 = 0; Gen1 = 0; Gen2 = 0 }
            StringBuilderPoolUsage = 0
            ComponentCount = 0
        }
        
        # TaskWarrior integration metrics
        $this._metrics['TaskWarrior'] = @{
            CommandExecutions = 0
            AverageCommandTimeMs = 0.0
            FailedCommands = 0
            TaskCount = 0
            FilterProcessingTimeMs = 0.0
        }
        
        # Error metrics
        $this._metrics['Errors'] = @{
            RenderErrors = 0
            ComponentErrors = 0
            CacheErrors = 0
            InputErrors = 0
            RecoveryAttempts = 0
            CriticalErrors = 0
        }
    }
    
    # Start timing operation
    [string] StartTimer([string]$operationName) {
        $timerId = [guid]::NewGuid().ToString()
        $this._timers[$timerId] = @{
            OperationName = $operationName
            StartTime = [System.Diagnostics.Stopwatch]::StartNew()
            Started = [datetime]::Now
        }
        return $timerId
    }
    
    # Stop timer and record duration
    [double] StopTimer([string]$timerId) {
        if (-not $this._timers.ContainsKey($timerId)) {
            return 0.0
        }
        
        $timer = $this._timers[$timerId]
        $timer.StartTime.Stop()
        $durationMs = $timer.StartTime.Elapsed.TotalMilliseconds
        $operationName = $timer.OperationName
        
        # Record the timing
        $this.RecordTiming($operationName, $durationMs)
        
        # Clean up timer
        $this._timers.Remove($timerId)
        
        return $durationMs
    }
    
    # Record timing measurement
    [void] RecordTiming([string]$operationName, [double]$durationMs) {
        # Update operation-specific metrics
        switch -Regex ($operationName) {
            'RenderFrame' {
                $metrics = $this._metrics['Rendering']
                $metrics.FrameCount++
                $metrics.TotalFrameTimeMs += $durationMs
                $metrics.AverageFrameTimeMs = $metrics.TotalFrameTimeMs / $metrics.FrameCount
                $metrics.MinFrameTimeMs = [Math]::Min($metrics.MinFrameTimeMs, $durationMs)
                $metrics.MaxFrameTimeMs = [Math]::Max($metrics.MaxFrameTimeMs, $durationMs)
                
                # Track slow frames
                if ($durationMs -gt $this._thresholds.RenderFrameMs) {
                    $metrics.SlowFrames++
                }
                
                # Maintain frame history
                $metrics.FrameHistory.Enqueue($durationMs)
                if ($metrics.FrameHistory.Count -gt $this._maxHistorySize) {
                    $metrics.FrameHistory.Dequeue()
                }
            }
            
            'Component_.*_Render' {
                $componentName = $operationName -replace 'Component_(.*)_Render', '$1'
                if (-not $this._metrics['Components'].RenderTimes.ContainsKey($componentName)) {
                    $this._metrics['Components'].RenderTimes[$componentName] = @{
                        Count = 0
                        TotalMs = 0.0
                        AverageMs = 0.0
                        MaxMs = 0.0
                    }
                }
                
                $compMetrics = $this._metrics['Components'].RenderTimes[$componentName]
                $compMetrics.Count++
                $compMetrics.TotalMs += $durationMs
                $compMetrics.AverageMs = $compMetrics.TotalMs / $compMetrics.Count
                $compMetrics.MaxMs = [Math]::Max($compMetrics.MaxMs, $durationMs)
            }
            
            'InputResponse' {
                $metrics = $this._metrics['InputOutput']
                $metrics.InputResponseTimes.Enqueue($durationMs)
                if ($metrics.InputResponseTimes.Count -gt $this._maxHistorySize) {
                    $metrics.InputResponseTimes.Dequeue()
                }
                
                # Calculate average
                $sum = 0.0
                foreach ($time in $metrics.InputResponseTimes) {
                    $sum += $time
                }
                $metrics.AverageInputResponseMs = $sum / $metrics.InputResponseTimes.Count
            }
            
            'TaskWarriorCommand' {
                $metrics = $this._metrics['TaskWarrior']
                $metrics.CommandExecutions++
                $metrics.AverageCommandTimeMs = (($metrics.AverageCommandTimeMs * ($metrics.CommandExecutions - 1)) + $durationMs) / $metrics.CommandExecutions
            }
        }
        
        # Log slow operations
        $threshold = $this.GetThreshold($operationName)
        if ($threshold -gt 0 -and $durationMs -gt $threshold -and $this._logger) {
            $this._logger.Warn("PerformanceMonitor: Slow operation detected - $operationName took ${durationMs}ms (threshold: ${threshold}ms)")
        }
    }
    
    # Get threshold for operation type
    hidden [double] GetThreshold([string]$operationName) {
        switch -Regex ($operationName) {
            'RenderFrame' { return $this._thresholds.RenderFrameMs }
            'Component_.*_Render' { return $this._thresholds.ComponentRenderMs }
            'InputResponse' { return $this._thresholds.InputResponseMs }
            'FilterProcessing' { return $this._thresholds.FilterProcessingMs }
            default { return 0.0 }
        }
    }
    
    # Record cache hit/miss
    [void] RecordCacheAccess([string]$cacheType, [bool]$hit) {
        if ($this._metrics['Caching'].ContainsKey($cacheType)) {
            $cacheMetrics = $this._metrics['Caching'][$cacheType]
            if ($hit) {
                $cacheMetrics.Hits++
            } else {
                $cacheMetrics.Misses++
            }
            
            # Update overall hit ratio
            $this.UpdateCacheHitRatio()
        }
    }
    
    # Update overall cache hit ratio
    hidden [void] UpdateCacheHitRatio() {
        $totalHits = 0
        $totalAccesses = 0
        
        foreach ($cacheType in @('UrgencyCache', 'FilterCache', 'FormattedLineCache', 'VirtualTagCache')) {
            $cache = $this._metrics['Caching'][$cacheType]
            $totalHits += $cache.Hits
            $totalAccesses += $cache.Hits + $cache.Misses
        }
        
        if ($totalAccesses -gt 0) {
            $this._metrics['Caching'].TotalHitRatio = $totalHits / $totalAccesses
            
            # Alert if hit ratio is below threshold
            if ($this._metrics['Caching'].TotalHitRatio -lt $this._thresholds.CacheHitRatio -and $this._logger) {
                $this._logger.Warn("PerformanceMonitor: Cache hit ratio below threshold: $($this._metrics['Caching'].TotalHitRatio * 100)%")
            }
        }
    }
    
    # Record error occurrence
    [void] RecordError([string]$errorType, [string]$details = '') {
        switch ($errorType) {
            'Render' { $this._metrics['Errors'].RenderErrors++ }
            'Component' { $this._metrics['Errors'].ComponentErrors++ }
            'Cache' { $this._metrics['Errors'].CacheErrors++ }
            'Input' { $this._metrics['Errors'].InputErrors++ }
            'Critical' { $this._metrics['Errors'].CriticalErrors++ }
        }
        
        if ($this._logger) {
            $this._logger.Debug("PerformanceMonitor: Recorded $errorType error - $details")
        }
    }
    
    # Update memory metrics
    [void] UpdateMemoryMetrics() {
        try {
            $process = [System.Diagnostics.Process]::GetCurrentProcess()
            $this._metrics['Memory'].WorkingSetMB = $process.WorkingSet64 / 1MB
            $this._metrics['Memory'].PrivateMemoryMB = $process.PrivateMemorySize64 / 1MB
            
            # GC metrics
            $this._metrics['Memory'].GCCollections.Gen0 = [System.GC]::CollectionCount(0)
            $this._metrics['Memory'].GCCollections.Gen1 = [System.GC]::CollectionCount(1)
            $this._metrics['Memory'].GCCollections.Gen2 = [System.GC]::CollectionCount(2)
            
            # Check memory usage threshold
            if ($this._metrics['Memory'].WorkingSetMB -gt $this._thresholds.MemoryUsageMB -and $this._logger) {
                $this._logger.Warn("PerformanceMonitor: Memory usage above threshold: $($this._metrics['Memory'].WorkingSetMB)MB")
            }
            
        } catch {
            if ($this._logger) {
                $this._logger.Error("PerformanceMonitor: Failed to update memory metrics", $_)
            }
        }
    }
    
    # Get performance summary
    [hashtable] GetPerformanceSummary() {
        $this.UpdateMemoryMetrics()
        
        return @{
            Uptime = $this._globalTimer.Elapsed
            FrameRate = if ($this._metrics['Rendering'].AverageFrameTimeMs -gt 0) { 1000.0 / $this._metrics['Rendering'].AverageFrameTimeMs } else { 0.0 }
            AverageFrameTime = $this._metrics['Rendering'].AverageFrameTimeMs
            SlowFramePercentage = if ($this._metrics['Rendering'].FrameCount -gt 0) { ($this._metrics['Rendering'].SlowFrames / $this._metrics['Rendering'].FrameCount) * 100 } else { 0.0 }
            CacheHitRatio = $this._metrics['Caching'].TotalHitRatio * 100
            MemoryUsageMB = $this._metrics['Memory'].WorkingSetMB
            InputResponseMs = $this._metrics['InputOutput'].AverageInputResponseMs
            ErrorCount = $this._metrics['Errors'].RenderErrors + $this._metrics['Errors'].ComponentErrors + $this._metrics['Errors'].CacheErrors
            HealthStatus = $this.CalculateHealthStatus()
        }
    }
    
    # Calculate overall health status
    hidden [string] CalculateHealthStatus() {
        $issues = 0
        
        # Check frame rate
        if ($this._metrics['Rendering'].AverageFrameTimeMs -gt $this._thresholds.RenderFrameMs) {
            $issues++
        }
        
        # Check cache performance
        if ($this._metrics['Caching'].TotalHitRatio -lt $this._thresholds.CacheHitRatio) {
            $issues++
        }
        
        # Check memory usage
        if ($this._metrics['Memory'].WorkingSetMB -gt $this._thresholds.MemoryUsageMB) {
            $issues++
        }
        
        # Check error count
        $totalErrors = $this._metrics['Errors'].RenderErrors + $this._metrics['Errors'].ComponentErrors + $this._metrics['Errors'].CacheErrors
        if ($totalErrors -gt 10) {
            $issues++
        }
        
        # Check critical errors
        if ($this._metrics['Errors'].CriticalErrors -gt 0) {
            return 'Critical'
        }
        
        switch ($issues) {
            0 { return 'Excellent' }
            1 { return 'Good' }
            2 { return 'Fair' }
            3 { return 'Poor' }
            default { return 'Critical' }
        }
    }
    
    # Get detailed metrics
    [hashtable] GetDetailedMetrics() {
        $this.UpdateMemoryMetrics()
        return $this._metrics.Clone()
    }
    
    # Export metrics to file
    [void] ExportMetrics([string]$filePath) {
        try {
            $summary = $this.GetPerformanceSummary()
            $detailed = $this.GetDetailedMetrics()
            
            $export = @{
                Timestamp = [datetime]::Now
                Summary = $summary
                Detailed = $detailed
                Thresholds = $this._thresholds
            }
            
            $json = $export | ConvertTo-Json -Depth 10
            [System.IO.File]::WriteAllText($filePath, $json)
            
            if ($this._logger) {
                $this._logger.Info("PerformanceMonitor: Metrics exported to $filePath")
            }
            
        } catch {
            if ($this._logger) {
                $this._logger.Error("PerformanceMonitor: Failed to export metrics", $_)
            }
        }
    }
    
    # Reset metrics
    [void] Reset() {
        $this._metrics.Clear()
        $this._timers.Clear()
        $this._counters.Clear()
        $this._histograms.Clear()
        $this._globalTimer.Restart()
        $this.InitializeMetrics()
        
        if ($this._logger) {
            $this._logger.Info("PerformanceMonitor: Metrics reset")
        }
    }
    
    # Get performance report
    [string] GetPerformanceReport() {
        $summary = $this.GetPerformanceSummary()
        $sb = [System.Text.StringBuilder]::new()
        
        $sb.AppendLine("=== TaskWarrior-TUI Performance Report ===")
        $sb.AppendLine("Generated: $([datetime]::Now)")
        $sb.AppendLine("Uptime: $($summary.Uptime)")
        $sb.AppendLine("Health Status: $($summary.HealthStatus)")
        $sb.AppendLine()
        
        $sb.AppendLine("Rendering Performance:")
        $sb.AppendLine("  Frame Rate: $([Math]::Round($summary.FrameRate, 2)) FPS")
        $sb.AppendLine("  Average Frame Time: $([Math]::Round($summary.AverageFrameTime, 2))ms")
        $sb.AppendLine("  Slow Frames: $([Math]::Round($summary.SlowFramePercentage, 2))%")
        $sb.AppendLine()
        
        $sb.AppendLine("Cache Performance:")
        $sb.AppendLine("  Hit Ratio: $([Math]::Round($summary.CacheHitRatio, 2))%")
        $sb.AppendLine()
        
        $sb.AppendLine("Memory Usage:")
        $sb.AppendLine("  Working Set: $([Math]::Round($summary.MemoryUsageMB, 2))MB")
        $sb.AppendLine()
        
        $sb.AppendLine("Input Response:")
        $sb.AppendLine("  Average Response Time: $([Math]::Round($summary.InputResponseMs, 2))ms")
        $sb.AppendLine()
        
        $sb.AppendLine("Error Summary:")
        $sb.AppendLine("  Total Errors: $($summary.ErrorCount)")
        $sb.AppendLine("  Critical Errors: $($this._metrics['Errors'].CriticalErrors)")
        
        return $sb.ToString()
    }
    
    # Start background monitoring
    [void] StartBackgroundMonitoring([int]$intervalSeconds = 30) {
        [System.Threading.Tasks.Task]::Run({
            while ($true) {
                $this.UpdateMemoryMetrics()
                
                # Generate alerts if needed
                $summary = $this.GetPerformanceSummary()
                if ($summary.HealthStatus -eq 'Poor' -or $summary.HealthStatus -eq 'Critical') {
                    if ($this._logger) {
                        $this._logger.Warn("PerformanceMonitor: Performance degraded - Health: $($summary.HealthStatus)")
                    }
                }
                
                [System.Threading.Thread]::Sleep($intervalSeconds * 1000)
            }
        })
    }
    
    # Dispose
    [void] Dispose() {
        $this._globalTimer.Stop()
        
        if ($this._logger) {
            $this._logger.Debug("PerformanceMonitor: Disposed successfully")
        }
    }
}
```

### 13. Configuration Management System

Comprehensive configuration system with TaskWarrior .taskrc integration:

```powershell
class ConfigurationManager {
    hidden [hashtable] $_config = @{}
    hidden [hashtable] $_defaults = @{}
    hidden [string] $_configPath = ""
    hidden [string] $_taskrcPath = ""
    hidden [bool] $_watchFileChanges = $true
    hidden [Logger] $_logger = $null
    hidden [RenderEventCoordinator] $_eventCoordinator = $null
    hidden [System.IO.FileSystemWatcher] $_fileWatcher = $null
    
    ConfigurationManager([Logger]$logger, [RenderEventCoordinator]$eventCoordinator) {
        $this._logger = $logger
        $this._eventCoordinator = $eventCoordinator
        $this.InitializeDefaults()
        $this.DiscoverConfigurationPaths()
        $this.LoadConfiguration()
        $this.SetupFileWatching()
    }
    
    # Initialize default configuration values
    [void] InitializeDefaults() {
        $this._defaults = @{
            # UI Settings
            'ui.theme' = 'default'
            'ui.show_urgency' = $true
            'ui.show_project' = $true
            'ui.show_tags' = $true
            'ui.show_due' = $true
            'ui.show_priority' = $true
            'ui.column_width_id' = 3
            'ui.column_width_priority' = 3
            'ui.column_width_project' = 15
            'ui.column_width_description' = 30
            'ui.column_width_due' = 10
            'ui.column_width_urgency' = 6
            'ui.refresh_interval' = 5
            'ui.auto_refresh' = $true
            
            # Display Settings
            'display.max_tasks' = 1000
            'display.virtual_scroll_buffer' = 15
            'display.truncate_description' = 50
            'display.show_completed' = $false
            'display.show_deleted' = $false
            'display.show_waiting' = $true
            'display.urgency_threshold_high' = 10.0
            'display.urgency_threshold_medium' = 5.0
            
            # Filter Settings
            'filter.default' = 'status:pending'
            'filter.enable_regex' = $true
            'filter.case_sensitive' = $false
            'filter.auto_apply' = $true
            'filter.history_size' = 50
            
            # Keybindings
            'keys.quit' = 'q'
            'keys.refresh' = 'F5'
            'keys.help' = 'F1'
            'keys.new_task' = 'a'
            'keys.edit_task' = 'Enter'
            'keys.delete_task' = 'd'
            'keys.complete_task' = 'c'
            'keys.filter' = '/'
            'keys.clear_filter' = 'Escape'
            'keys.next_theme' = 'F2'
            'keys.up' = 'Up'
            'keys.down' = 'Down'
            'keys.page_up' = 'PageUp'
            'keys.page_down' = 'PageDown'
            
            # Performance Settings
            'performance.cache_size' = 5000
            'performance.max_render_time_ms' = 16.67
            'performance.enable_background_processing' = $true
            'performance.max_background_threads' = 4
            'performance.gc_interval_seconds' = 300
            
            # Logging Settings
            'logging.level' = 'Info'
            'logging.file_path' = '$HOME/.taskwarrior-tui/logs/app.log'
            'logging.max_file_size_mb' = 10
            'logging.max_backup_files' = 5
            
            # TaskWarrior Integration
            'taskwarrior.command' = 'task'
            'taskwarrior.data_location' = '$HOME/.task'
            'taskwarrior.rc_file' = '$HOME/.taskrc'
            'taskwarrior.hooks_enabled' = $true
            'taskwarrior.sync_on_change' = $false
            
            # Advanced Settings
            'advanced.unicode_support' = $true
            'advanced.mouse_support' = $true
            'advanced.alternate_screen' = $true
            'advanced.debug_mode' = $false
            'advanced.performance_monitoring' = $true
        }
    }
    
    # Discover configuration file paths
    [void] DiscoverConfigurationPaths() {
        # TaskWarrior-TUI config path
        if ($env:XDG_CONFIG_HOME) {
            $configDir = Join-Path $env:XDG_CONFIG_HOME 'taskwarrior-tui'
        } else {
            $configDir = Join-Path $env:HOME '.config/taskwarrior-tui'
        }
        
        if (-not (Test-Path $configDir)) {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        }
        
        $this._configPath = Join-Path $configDir 'config.json'
        
        # TaskWarrior .taskrc path
        $this._taskrcPath = $this.ExpandPath($this._defaults['taskwarrior.rc_file'])
        
        if ($this._logger) {
            $this._logger.Debug("ConfigurationManager: Config path: $($this._configPath)")
            $this._logger.Debug("ConfigurationManager: TaskRC path: $($this._taskrcPath)")
        }
    }
    
    # Expand environment variables in paths
    hidden [string] ExpandPath([string]$path) {
        $expandedPath = $path -replace '\$HOME', $env:HOME
        $expandedPath = $expandedPath -replace '\$USER', $env:USER
        return $expandedPath
    }
    
    # Load configuration from files
    [void] LoadConfiguration() {
        # Start with defaults
        $this._config = $this._defaults.Clone()
        
        # Load TaskWarrior .taskrc
        $this.LoadTaskRcConfiguration()
        
        # Load TaskWarrior-TUI specific config
        $this.LoadTUIConfiguration()
        
        if ($this._logger) {
            $this._logger.Info("ConfigurationManager: Configuration loaded successfully")
        }
    }
    
    # Load TaskWarrior .taskrc configuration
    [void] LoadTaskRcConfiguration() {
        if (-not (Test-Path $this._taskrcPath)) {
            if ($this._logger) {
                $this._logger.Debug("ConfigurationManager: .taskrc not found at $($this._taskrcPath)")
            }
            return
        }
        
        try {
            $lines = Get-Content $this._taskrcPath
            foreach ($line in $lines) {
                $line = $line.Trim()
                
                # Skip comments and empty lines
                if ($line.StartsWith('#') -or $line -eq '') {
                    continue
                }
                
                # Parse key=value pairs
                if ($line -match '^([^=]+)=(.*)$') {
                    $key = $matches[1].Trim()
                    $value = $matches[2].Trim()
                    
                    # Map TaskWarrior settings to TUI config
                    $this.MapTaskRcSetting($key, $value)
                }
            }
            
            if ($this._logger) {
                $this._logger.Debug("ConfigurationManager: Loaded .taskrc configuration")
            }
            
        } catch {
            if ($this._logger) {
                $this._logger.Error("ConfigurationManager: Failed to load .taskrc", $_)
            }
        }
    }
    
    # Map TaskWarrior settings to TUI configuration
    hidden [void] MapTaskRcSetting([string]$key, [string]$value) {
        switch ($key) {
            'data.location' {
                $this._config['taskwarrior.data_location'] = $this.ExpandPath($value)
            }
            'urgency.user.project.default' {
                if ([double]::TryParse($value, [ref]$null)) {
                    $this._config['display.urgency_threshold_medium'] = [double]$value
                }
            }
            'urgency.priority.H.coefficient' {
                if ([double]::TryParse($value, [ref]$null)) {
                    $urgencyValue = [double]$value * 5  # Convert to threshold
                    $this._config['display.urgency_threshold_high'] = $urgencyValue
                }
            }
            'report.next.filter' {
                $this._config['filter.default'] = $value
            }
            'color.due' {
                $this._config['theme.due.normal'] = $this.ConvertTaskWarriorColor($value)
            }
            'color.due.today' {
                $this._config['theme.due.today'] = $this.ConvertTaskWarriorColor($value)
            }
            'color.overdue' {
                $this._config['theme.due.overdue'] = $this.ConvertTaskWarriorColor($value)
            }
            'color.priority.H' {
                $this._config['theme.priority.high'] = $this.ConvertTaskWarriorColor($value)
            }
            'color.priority.M' {
                $this._config['theme.priority.medium'] = $this.ConvertTaskWarriorColor($value)
            }
            'color.priority.L' {
                $this._config['theme.priority.low'] = $this.ConvertTaskWarriorColor($value)
            }
            'color.completed' {
                $this._config['theme.task.completed'] = $this.ConvertTaskWarriorColor($value)
            }
            'color.deleted' {
                $this._config['theme.task.deleted'] = $this.ConvertTaskWarriorColor($value)
            }
            default {
                # Store unknown TaskWarrior settings for potential future use
                $this._config["taskrc.$key"] = $value
            }
        }
    }
    
    # Convert TaskWarrior color format to VT100
    hidden [string] ConvertTaskWarriorColor([string]$colorSpec) {
        # This is a simplified conversion - full implementation would handle all TaskWarrior color formats
        switch ($colorSpec.ToLower()) {
            'red' { return "`e[31m" }
            'green' { return "`e[32m" }
            'yellow' { return "`e[33m" }
            'blue' { return "`e[34m" }
            'magenta' { return "`e[35m" }
            'cyan' { return "`e[36m" }
            'white' { return "`e[37m" }
            'black' { return "`e[30m" }
            'bright_red' { return "`e[91m" }
            'bright_green' { return "`e[92m" }
            'bright_yellow' { return "`e[93m" }
            'bright_blue' { return "`e[94m" }
            'bright_magenta' { return "`e[95m" }
            'bright_cyan' { return "`e[96m" }
            'bright_white' { return "`e[97m" }
            default { return "`e[0m" }
        }
    }
    
    # Load TUI-specific configuration
    [void] LoadTUIConfiguration() {
        if (-not (Test-Path $this._configPath)) {
            # Create default config file
            $this.SaveConfiguration()
            return
        }
        
        try {
            $configJson = Get-Content $this._configPath -Raw
            $tuiConfig = $configJson | ConvertFrom-Json
            
            # Merge TUI config over defaults
            foreach ($key in $tuiConfig.PSObject.Properties.Name) {
                $this._config[$key] = $tuiConfig.$key
            }
            
            if ($this._logger) {
                $this._logger.Debug("ConfigurationManager: Loaded TUI configuration")
            }
            
        } catch {
            if ($this._logger) {
                $this._logger.Error("ConfigurationManager: Failed to load TUI configuration", $_)
            }
        }
    }
    
    # Save configuration to file
    [void] SaveConfiguration() {
        try {
            # Filter out TaskRC settings and defaults for clean config file
            $configToSave = @{}
            foreach ($key in $this._config.Keys) {
                if (-not $key.StartsWith('taskrc.') -and $this._config[$key] -ne $this._defaults[$key]) {
                    $configToSave[$key] = $this._config[$key]
                }
            }
            
            $configJson = $configToSave | ConvertTo-Json -Depth 10
            [System.IO.File]::WriteAllText($this._configPath, $configJson)
            
            if ($this._logger) {
                $this._logger.Debug("ConfigurationManager: Configuration saved")
            }
            
        } catch {
            if ($this._logger) {
                $this._logger.Error("ConfigurationManager: Failed to save configuration", $_)
            }
        }
    }
    
    # Get configuration value
    [object] GetValue([string]$key, [object]$defaultValue = $null) {
        if ($this._config.ContainsKey($key)) {
            return $this._config[$key]
        }
        
        if ($defaultValue -ne $null) {
            return $defaultValue
        }
        
        if ($this._defaults.ContainsKey($key)) {
            return $this._defaults[$key]
        }
        
        return $null
    }
    
    # Set configuration value
    [void] SetValue([string]$key, [object]$value, [bool]$save = $true) {
        $oldValue = $this._config[$key]
        $this._config[$key] = $value
        
        if ($this._logger) {
            $this._logger.Debug("ConfigurationManager: Set $key = $value (was: $oldValue)")
        }
        
        # Publish configuration change event
        if ($this._eventCoordinator) {
            $this._eventCoordinator.PublishEvent('ConfigurationChanged', @{
                Key = $key
                OldValue = $oldValue
                NewValue = $value
            })
        }
        
        # Handle special configuration changes
        $this.HandleConfigurationChange($key, $value, $oldValue)
        
        if ($save) {
            $this.SaveConfiguration()
        }
    }
    
    # Handle specific configuration changes
    hidden [void] HandleConfigurationChange([string]$key, [object]$newValue, [object]$oldValue) {
        switch ($key) {
            'ui.theme' {
                if ($this._eventCoordinator) {
                    $this._eventCoordinator.PublishEvent('ThemeChanged', @{
                        NewTheme = $newValue
                        OldTheme = $oldValue
                    })
                }
            }
            'logging.level' {
                if ($this._logger) {
                    $this._logger.SetLevel($newValue)
                }
            }
            'performance.cache_size' {
                if ($this._eventCoordinator) {
                    $this._eventCoordinator.PublishEvent('CacheSizeChanged', @{
                        NewSize = $newValue
                        OldSize = $oldValue
                    })
                }
            }
            { $_ -like 'keys.*' } {
                if ($this._eventCoordinator) {
                    $this._eventCoordinator.PublishEvent('KeyBindingChanged', @{
                        Action = $key -replace 'keys\.', ''
                        NewKey = $newValue
                        OldKey = $oldValue
                    })
                }
            }
        }
    }
    
    # Get all configuration values
    [hashtable] GetAllValues() {
        return $this._config.Clone()
    }
    
    # Get configuration section
    [hashtable] GetSection([string]$sectionPrefix) {
        $section = @{}
        $prefix = "$sectionPrefix."
        
        foreach ($key in $this._config.Keys) {
            if ($key.StartsWith($prefix)) {
                $sectionKey = $key.Substring($prefix.Length)
                $section[$sectionKey] = $this._config[$key]
            }
        }
        
        return $section
    }
    
    # Reset configuration to defaults
    [void] ResetToDefaults([string[]]$keys = @()) {
        if ($keys.Count -eq 0) {
            # Reset all to defaults
            $this._config = $this._defaults.Clone()
        } else {
            # Reset specific keys
            foreach ($key in $keys) {
                if ($this._defaults.ContainsKey($key)) {
                    $this.SetValue($key, $this._defaults[$key], $false)
                }
            }
        }
        
        $this.SaveConfiguration()
        
        if ($this._eventCoordinator) {
            $this._eventCoordinator.PublishEvent('ConfigurationReset', @{
                Keys = $keys
            })
        }
        
        if ($this._logger) {
            $this._logger.Info("ConfigurationManager: Configuration reset to defaults")
        }
    }
    
    # Validate configuration
    [hashtable] ValidateConfiguration() {
        $issues = @()
        
        # Validate numeric values
        $numericKeys = @('ui.refresh_interval', 'display.max_tasks', 'performance.cache_size')
        foreach ($key in $numericKeys) {
            $value = $this.GetValue($key)
            if ($value -isnot [int] -or $value -le 0) {
                $issues += "Invalid numeric value for $key: $value"
            }
        }
        
        # Validate boolean values
        $booleanKeys = @('ui.auto_refresh', 'display.show_completed', 'advanced.unicode_support')
        foreach ($key in $booleanKeys) {
            $value = $this.GetValue($key)
            if ($value -isnot [bool]) {
                $issues += "Invalid boolean value for $key: $value"
            }
        }
        
        # Validate file paths
        $pathKeys = @('taskwarrior.data_location', 'taskwarrior.rc_file')
        foreach ($key in $pathKeys) {
            $path = $this.ExpandPath($this.GetValue($key))
            if ($path -and -not (Test-Path (Split-Path $path -Parent))) {
                $issues += "Invalid path for $key: $path (parent directory does not exist)"
            }
        }
        
        # Validate theme
        $theme = $this.GetValue('ui.theme')
        $validThemes = @('default', 'dark', 'taskwarrior')
        if ($theme -notin $validThemes) {
            $issues += "Invalid theme: $theme (valid themes: $($validThemes -join ', '))"
        }
        
        return @{
            IsValid = $issues.Count -eq 0
            Issues = $issues
        }
    }
    
    # Setup file watching for automatic reload
    [void] SetupFileWatching() {
        if (-not $this._watchFileChanges) {
            return
        }
        
        try {
            # Watch TUI config file
            if (Test-Path $this._configPath) {
                $configDir = Split-Path $this._configPath -Parent
                $configFile = Split-Path $this._configPath -Leaf
                
                $this._fileWatcher = [System.IO.FileSystemWatcher]::new($configDir, $configFile)
                $this._fileWatcher.NotifyFilter = [System.IO.NotifyFilters]::LastWrite
                $this._fileWatcher.EnableRaisingEvents = $true
                
                # Handle file changes
                Register-ObjectEvent $this._fileWatcher 'Changed' -Action {
                    Start-Sleep -Milliseconds 500  # Debounce
                    $this.LoadTUIConfiguration()
                    
                    if ($this._eventCoordinator) {
                        $this._eventCoordinator.PublishEvent('ConfigurationReloaded', @{
                            Source = 'FileSystem'
                            Path = $this._configPath
                        })
                    }
                } | Out-Null
                
                if ($this._logger) {
                    $this._logger.Debug("ConfigurationManager: File watching enabled for $($this._configPath)")
                }
            }
            
        } catch {
            if ($this._logger) {
                $this._logger.Warn("ConfigurationManager: Could not setup file watching", $_)
            }
        }
    }
    
    # Reload configuration from files
    [void] ReloadConfiguration() {
        $this.LoadConfiguration()
        
        if ($this._eventCoordinator) {
            $this._eventCoordinator.PublishEvent('ConfigurationReloaded', @{
                Source = 'Manual'
            })
        }
        
        if ($this._logger) {
            $this._logger.Info("ConfigurationManager: Configuration reloaded manually")
        }
    }
    
    # Export configuration to file
    [void] ExportConfiguration([string]$filePath) {
        try {
            $export = @{
                Timestamp = [datetime]::Now
                Configuration = $this._config
                Defaults = $this._defaults
                Validation = $this.ValidateConfiguration()
            }
            
            $json = $export | ConvertTo-Json -Depth 10
            [System.IO.File]::WriteAllText($filePath, $json)
            
            if ($this._logger) {
                $this._logger.Info("ConfigurationManager: Configuration exported to $filePath")
            }
            
        } catch {
            if ($this._logger) {
                $this._logger.Error("ConfigurationManager: Failed to export configuration", $_)
            }
        }
    }
    
    # Import configuration from file
    [void] ImportConfiguration([string]$filePath) {
        try {
            if (-not (Test-Path $filePath)) {
                throw "Configuration file not found: $filePath"
            }
            
            $configJson = Get-Content $filePath -Raw
            $importedConfig = $configJson | ConvertFrom-Json
            
            # If it's an exported config with metadata
            if ($importedConfig.Configuration) {
                $configToImport = $importedConfig.Configuration
            } else {
                $configToImport = $importedConfig
            }
            
            # Import configuration values
            foreach ($key in $configToImport.PSObject.Properties.Name) {
                $this.SetValue($key, $configToImport.$key, $false)
            }
            
            $this.SaveConfiguration()
            
            if ($this._eventCoordinator) {
                $this._eventCoordinator.PublishEvent('ConfigurationImported', @{
                    Source = $filePath
                })
            }
            
            if ($this._logger) {
                $this._logger.Info("ConfigurationManager: Configuration imported from $filePath")
            }
            
        } catch {
            if ($this._logger) {
                $this._logger.Error("ConfigurationManager: Failed to import configuration", $_)
            }
            throw
        }
    }
    
    # Dispose and cleanup
    [void] Dispose() {
        if ($this._fileWatcher) {
            $this._fileWatcher.EnableRaisingEvents = $false
            $this._fileWatcher.Dispose()
        }
        
        if ($this._logger) {
            $this._logger.Debug("ConfigurationManager: Disposed successfully")
        }
    }
}
```

### 14. UDA (User Defined Attributes) Support System

Enhanced TaskWarrior integration with full UDA support:

```powershell
class UDAManager {
    hidden [hashtable] $_udaDefinitions = @{}
    hidden [hashtable] $_udaCache = @{}
    hidden [hashtable] $_udaValidators = @{}
    hidden [Logger] $_logger = $null
    hidden [ConfigurationManager] $_configManager = $null
    
    UDAManager([Logger]$logger, [ConfigurationManager]$configManager) {
        $this._logger = $logger
        $this._configManager = $configManager
        $this.LoadUDADefinitions()
        $this.SetupBuiltInValidators()
    }
    
    # Load UDA definitions from TaskWarrior configuration
    [void] LoadUDADefinitions() {
        $taskrcConfig = $this._configManager.GetSection('taskrc')
        
        foreach ($key in $taskrcConfig.Keys) {
            if ($key -like 'uda.*') {
                $this.ParseUDADefinition($key, $taskrcConfig[$key])
            }
        }
        
        if ($this._logger) {
            $this._logger.Info("UDAManager: Loaded $($this._udaDefinitions.Count) UDA definitions")
        }
    }
    
    # Parse individual UDA definition from .taskrc
    hidden [void] ParseUDADefinition([string]$key, [string]$value) {
        # Parse UDA key: uda.attribute.property=value
        if ($key -match '^uda\.([^.]+)\.(.+)$') {
            $udaName = $matches[1]
            $property = $matches[2]
            
            if (-not $this._udaDefinitions.ContainsKey($udaName)) {
                $this._udaDefinitions[$udaName] = @{
                    Name = $udaName
                    Type = 'string'  # Default type
                    Label = $udaName
                    Values = @()
                    Default = ''
                    Urgent = $false
                    Width = 10
                    Format = 'default'
                    Searchable = $true
                    Sortable = $true
                    Visible = $true
                }
            }
            
            $uda = $this._udaDefinitions[$udaName]
            
            switch ($property) {
                'type' { 
                    $uda.Type = $value.ToLower()
                    $this.SetupUDAValidator($udaName, $value.ToLower())
                }
                'label' { $uda.Label = $value }
                'values' { 
                    # Parse comma-separated values
                    $uda.Values = $value -split ',' | ForEach-Object { $_.Trim() }
                }
                'default' { $uda.Default = $value }
                'urgent' { 
                    $uda.Urgent = $value.ToLower() -in @('true', '1', 'yes', 'on')
                }
                default {
                    # Store unknown properties for potential future use
                    $uda["Custom_$property"] = $value
                }
            }
        }
    }
    
    # Setup built-in validators for UDA types
    [void] SetupBuiltInValidators() {
        $this._udaValidators['string'] = {
            param($value)
            return @{ IsValid = $true; Error = '' }
        }
        
        $this._udaValidators['numeric'] = {
            param($value)
            if ([double]::TryParse($value, [ref]$null)) {
                return @{ IsValid = $true; Error = '' }
            }
            return @{ IsValid = $false; Error = "Value must be numeric" }
        }
        
        $this._udaValidators['date'] = {
            param($value)
            if ([datetime]::TryParse($value, [ref]$null)) {
                return @{ IsValid = $true; Error = '' }
            }
            return @{ IsValid = $false; Error = "Value must be a valid date" }
        }
        
        $this._udaValidators['duration'] = {
            param($value)
            if ($value -match '^\d+[smhdwMy]$') {
                return @{ IsValid = $true; Error = '' }
            }
            return @{ IsValid = $false; Error = "Value must be a duration (e.g., 1d, 2w, 3M)" }
        }
    }
    
    # Setup validator for specific UDA
    hidden [void] SetupUDAValidator([string]$udaName, [string]$type) {
        $uda = $this._udaDefinitions[$udaName]
        
        if ($uda.Values.Count -gt 0) {
            # Enumerated values validator
            $this._udaValidators[$udaName] = {
                param($value)
                if ($value -in $uda.Values -or [string]::IsNullOrEmpty($value)) {
                    return @{ IsValid = $true; Error = '' }
                }
                return @{ IsValid = $false; Error = "Value must be one of: $($uda.Values -join ', ')" }
            }.GetNewClosure()
        } elseif ($this._udaValidators.ContainsKey($type)) {
            # Use type-based validator
            $this._udaValidators[$udaName] = $this._udaValidators[$type]
        }
    }
    
    # Get all UDA definitions
    [hashtable[]] GetUDADefinitions() {
        return $this._udaDefinitions.Values
    }
    
    # Get specific UDA definition
    [hashtable] GetUDADefinition([string]$udaName) {
        if ($this._udaDefinitions.ContainsKey($udaName)) {
            return $this._udaDefinitions[$udaName]
        }
        return $null
    }
    
    # Validate UDA value
    [hashtable] ValidateUDAValue([string]$udaName, [string]$value) {
        if (-not $this._udaDefinitions.ContainsKey($udaName)) {
            return @{ IsValid = $false; Error = "Unknown UDA: $udaName" }
        }
        
        if ($this._udaValidators.ContainsKey($udaName)) {
            return $this._udaValidators[$udaName].Invoke($value)
        }
        
        # Default validation (string)
        return @{ IsValid = $true; Error = '' }
    }
    
    # Format UDA value for display
    [string] FormatUDAValue([string]$udaName, [string]$value) {
        if ([string]::IsNullOrEmpty($value)) {
            return ''
        }
        
        $uda = $this.GetUDADefinition($udaName)
        if (-not $uda) {
            return $value
        }
        
        switch ($uda.Type) {
            'date' {
                if ([datetime]::TryParse($value, [ref]$date)) {
                    return $date.ToString('yyyy-MM-dd')
                }
            }
            'duration' {
                return $this.FormatDuration($value)
            }
            'numeric' {
                if ([double]::TryParse($value, [ref]$num)) {
                    return $num.ToString('F2')
                }
            }
            default {
                return $value
            }
        }
        
        return $value
    }
    
    # Format duration values
    hidden [string] FormatDuration([string]$duration) {
        if ($duration -match '^(\d+)([smhdwMy])$') {
            $amount = [int]$matches[1]
            $unit = $matches[2]
            
            $unitNames = @{
                's' = 'sec'; 'm' = 'min'; 'h' = 'hr'
                'd' = 'day'; 'w' = 'wk'; 'M' = 'mon'; 'y' = 'yr'
            }
            
            $unitName = $unitNames[$unit]
            if ($amount -ne 1) {
                $unitName += 's'
            }
            
            return "$amount $unitName"
        }
        
        return $duration
    }
    
    # Get UDA value from task
    [string] GetUDAValue([hashtable]$task, [string]$udaName) {
        if ($task.ContainsKey($udaName)) {
            return $task[$udaName]
        }
        
        # Return default value
        $uda = $this.GetUDADefinition($udaName)
        if ($uda) {
            return $uda.Default
        }
        
        return ''
    }
    
    # Set UDA value on task
    [hashtable] SetUDAValue([hashtable]$task, [string]$udaName, [string]$value) {
        $validation = $this.ValidateUDAValue($udaName, $value)
        if (-not $validation.IsValid) {
            throw "Invalid UDA value for $udaName: $($validation.Error)"
        }
        
        $task[$udaName] = $value
        return $task
    }
    
    # Get UDAs for display in columns
    [hashtable[]] GetDisplayableUDAs() {
        return $this._udaDefinitions.Values | Where-Object { $_.Visible }
    }
    
    # Get UDAs that affect urgency
    [string[]] GetUrgencyUDAs() {
        return ($this._udaDefinitions.Values | Where-Object { $_.Urgent }).Name
    }
    
    # Create column definition for UDA
    [hashtable] CreateUDAColumnDefinition([string]$udaName) {
        $uda = $this.GetUDADefinition($udaName)
        if (-not $uda) {
            return $null
        }
        
        return @{
            Name = $uda.Name
            Header = $uda.Label
            Attribute = $uda.Name
            MinWidth = 3
            MaxWidth = [Math]::Max($uda.Width, 50)
            Weight = 0.1
            Alignment = if ($uda.Type -eq 'numeric') { 'Right' } else { 'Left' }
            Format = "UDA_$($uda.Name)"
            Visible = $uda.Visible
            Sortable = $uda.Sortable
            UDAType = $uda.Type
        }
    }
    
    # Parse UDA filter expressions
    [hashtable] ParseUDAFilter([string]$expression) {
        # Handle UDA filter patterns: uda.attribute:value, attribute:value
        if ($expression -match '^(uda\.)?([^:]+):(.*)$') {
            $udaName = $matches[2]
            $value = $matches[3]
            
            if ($this._udaDefinitions.ContainsKey($udaName)) {
                return @{
                    Type = 'UDA'
                    Attribute = $udaName
                    Operator = 'equals'
                    Value = $value
                    UDADefinition = $this._udaDefinitions[$udaName]
                }
            }
        }
        
        return $null
    }
    
    # Get UDA suggestions for autocomplete
    [string[]] GetUDASuggestions([string]$partial) {
        $suggestions = @()
        
        # Suggest UDA names
        foreach ($udaName in $this._udaDefinitions.Keys) {
            if ($udaName -like "*$partial*") {
                $suggestions += $udaName
            }
        }
        
        # Suggest UDA values for enumerated types
        foreach ($uda in $this._udaDefinitions.Values) {
            if ($uda.Values.Count -gt 0) {
                foreach ($value in $uda.Values) {
                    if ($value -like "*$partial*") {
                        $suggestions += "$($uda.Name):$value"
                    }
                }
            }
        }
        
        return $suggestions | Sort-Object | Select-Object -First 10
    }
    
    # Export UDA definitions for debugging
    [hashtable] ExportUDADefinitions() {
        return @{
            Timestamp = [datetime]::Now
            UDACount = $this._udaDefinitions.Count
            Definitions = $this._udaDefinitions
            Validators = $this._udaValidators.Keys
        }
    }
}
```

### 15. Enhanced Layout Engine (Basic+)

Improved constraint-based layout with responsive features:

```powershell
class EnhancedLayoutEngine {
    hidden [hashtable] $_layouts = @{}
    hidden [hashtable] $_constraints = @{}
    hidden [hashtable] $_breakpoints = @{}
    hidden [hashtable] $_currentLayout = @{}
    hidden [int] $_lastWidth = 0
    hidden [int] $_lastHeight = 0
    hidden [Logger] $_logger = $null
    
    EnhancedLayoutEngine([Logger]$logger) {
        $this._logger = $logger
        $this.InitializeBreakpoints()
        $this.RegisterBuiltInLayouts()
    }
    
    # Initialize responsive breakpoints
    [void] InitializeBreakpoints() {
        $this._breakpoints = @{
            'xs' = @{ MinWidth = 0; MaxWidth = 79; Name = 'Extra Small' }
            'sm' = @{ MinWidth = 80; MaxWidth = 99; Name = 'Small' }
            'md' = @{ MinWidth = 100; MaxWidth = 119; Name = 'Medium' }
            'lg' = @{ MinWidth = 120; MaxWidth = 139; Name = 'Large' }
            'xl' = @{ MinWidth = 140; MaxWidth = 999; Name = 'Extra Large' }
        }
    }
    
    # Register built-in layout definitions
    [void] RegisterBuiltInLayouts() {
        # Standard TaskWarrior layout
        $this._layouts['standard'] = @{
            Name = 'Standard'
            Regions = @{
                'header' = @{
                    X = 0; Y = 0; Width = '100%'; Height = 1
                    ZIndex = 10; Visible = $true
                }
                'filter' = @{
                    X = 0; Y = 1; Width = '100%'; Height = 1
                    ZIndex = 5; Visible = $true
                }
                'content' = @{
                    X = 0; Y = 2; Width = '100%'; Height = 'fill-3'
                    ZIndex = 1; Visible = $true; Scrollable = $true
                }
                'status' = @{
                    X = 0; Y = 'bottom-1'; Width = '100%'; Height = 1
                    ZIndex = 10; Visible = $true
                }
                'command' = @{
                    X = 0; Y = 'bottom'; Width = '100%'; Height = 1
                    ZIndex = 15; Visible = $true
                }
            }
            Responsive = @{
                'xs' = @{ 
                    'filter' = @{ Visible = $false }
                    'content' = @{ Y = 1; Height = 'fill-2' }
                }
                'sm' = @{
                    'content' = @{ Height = 'fill-3' }
                }
            }
        }
        
        # Compact layout for small screens
        $this._layouts['compact'] = @{
            Name = 'Compact'
            Regions = @{
                'header' = @{
                    X = 0; Y = 0; Width = '50%'; Height = 1
                    ZIndex = 10; Visible = $true
                }
                'status' = @{
                    X = '50%'; Y = 0; Width = '50%'; Height = 1
                    ZIndex = 10; Visible = $true
                }
                'content' = @{
                    X = 0; Y = 1; Width = '100%'; Height = 'fill-1'
                    ZIndex = 1; Visible = $true; Scrollable = $true
                }
                'command' = @{
                    X = 0; Y = 'bottom'; Width = '100%'; Height = 1
                    ZIndex = 15; Visible = $true
                }
            }
        }
        
        # Split-pane layout with task details
        $this._layouts['split'] = @{
            Name = 'Split Pane'
            Regions = @{
                'header' = @{
                    X = 0; Y = 0; Width = '100%'; Height = 1
                    ZIndex = 10; Visible = $true
                }
                'content' = @{
                    X = 0; Y = 1; Width = '60%'; Height = 'fill-2'
                    ZIndex = 1; Visible = $true; Scrollable = $true
                }
                'details' = @{
                    X = '60%'; Y = 1; Width = '40%'; Height = 'fill-2'
                    ZIndex = 1; Visible = $true; Border = $true
                }
                'command' = @{
                    X = 0; Y = 'bottom'; Width = '100%'; Height = 1
                    ZIndex = 15; Visible = $true
                }
            }
            Responsive = @{
                'xs' = @{
                    'details' = @{ Visible = $false }
                    'content' = @{ Width = '100%' }
                }
                'sm' = @{
                    'details' = @{ Visible = $false }
                    'content' = @{ Width = '100%' }
                }
            }
        }
    }
    
    # Calculate layout for current screen size
    [hashtable] CalculateLayout([string]$layoutName, [int]$width, [int]$height) {
        if (-not $this._layouts.ContainsKey($layoutName)) {
            throw "Unknown layout: $layoutName"
        }
        
        $layout = $this._layouts[$layoutName]
        $breakpoint = $this.GetCurrentBreakpoint($width)
        $calculatedRegions = @{}
        
        # Start with base layout
        foreach ($regionName in $layout.Regions.Keys) {
            $region = $layout.Regions[$regionName].Clone()
            
            # Apply responsive overrides
            if ($layout.Responsive -and $layout.Responsive.ContainsKey($breakpoint)) {
                $responsive = $layout.Responsive[$breakpoint]
                if ($responsive.ContainsKey($regionName)) {
                    $overrides = $responsive[$regionName]
                    foreach ($key in $overrides.Keys) {
                        $region[$key] = $overrides[$key]
                    }
                }
            }
            
            # Calculate actual pixel values
            $calculatedRegions[$regionName] = $this.ResolveRegionConstraints($region, $width, $height)
        }
        
        # Store current layout for reference
        $this._currentLayout = @{
            Name = $layoutName
            Breakpoint = $breakpoint
            Width = $width
            Height = $height
            Regions = $calculatedRegions
            Timestamp = [datetime]::Now
        }
        
        if ($this._logger) {
            $this._logger.Debug("EnhancedLayoutEngine: Calculated $layoutName layout for ${width}x${height} ($breakpoint)")
        }
        
        return $this._currentLayout
    }
    
    # Resolve region constraints to pixel values
    hidden [hashtable] ResolveRegionConstraints([hashtable]$region, [int]$width, [int]$height) {
        $resolved = $region.Clone()
        
        # Resolve X position
        $resolved.X = $this.ResolvePosition($region.X, $width, $true)
        
        # Resolve Y position
        $resolved.Y = $this.ResolvePosition($region.Y, $height, $false)
        
        # Resolve Width
        $resolved.Width = $this.ResolveDimension($region.Width, $width)
        
        # Resolve Height
        $resolved.Height = $this.ResolveDimension($region.Height, $height)
        
        # Ensure regions don't exceed boundaries
        if ($resolved.X + $resolved.Width -gt $width) {
            $resolved.Width = $width - $resolved.X
        }
        
        if ($resolved.Y + $resolved.Height -gt $height) {
            $resolved.Height = $height - $resolved.Y
        }
        
        return $resolved
    }
    
    # Resolve position values (X or Y)
    hidden [int] ResolvePosition([object]$position, [int]$maxSize, [bool]$isHorizontal) {
        if ($position -is [int]) {
            return $position
        }
        
        $posStr = $position.ToString()
        
        # Handle special values
        switch -Regex ($posStr) {
            '^center$' {
                return [int]($maxSize / 2)
            }
            '^right$' {
                return $maxSize - 1
            }
            '^bottom$' {
                return $maxSize - 1
            }
            '^bottom-(\d+)$' {
                $offset = [int]$matches[1]
                return $maxSize - 1 - $offset
            }
            '^right-(\d+)$' {
                $offset = [int]$matches[1]
                return $maxSize - 1 - $offset
            }
            '^(\d+)%$' {
                $percentage = [int]$matches[1]
                return [int](($percentage / 100.0) * $maxSize)
            }
            '^\d+$' {
                return [int]$posStr
            }
            default {
                return 0
            }
        }
    }
    
    # Resolve dimension values (Width or Height)
    hidden [int] ResolveDimension([object]$dimension, [int]$maxSize) {
        if ($dimension -is [int]) {
            return $dimension
        }
        
        $dimStr = $dimension.ToString()
        
        switch -Regex ($dimStr) {
            '^100%$' {
                return $maxSize
            }
            '^(\d+)%$' {
                $percentage = [int]$matches[1]
                return [int](($percentage / 100.0) * $maxSize)
            }
            '^fill$' {
                return $maxSize
            }
            '^fill-(\d+)$' {
                $offset = [int]$matches[1]
                return [Math]::Max(1, $maxSize - $offset)
            }
            '^\d+$' {
                return [int]$dimStr
            }
            default {
                return 10  # Default minimum size
            }
        }
    }
    
    # Get current breakpoint based on screen width
    [string] GetCurrentBreakpoint([int]$width) {
        foreach ($bp in $this._breakpoints.Keys) {
            $breakpoint = $this._breakpoints[$bp]
            if ($width -ge $breakpoint.MinWidth -and $width -le $breakpoint.MaxWidth) {
                return $bp
            }
        }
        return 'md'  # Default breakpoint
    }
    
    # Check if layout needs recalculation
    [bool] NeedsRecalculation([int]$width, [int]$height) {
        return $width -ne $this._lastWidth -or $height -ne $this._lastHeight
    }
    
    # Get region by name from current layout
    [hashtable] GetRegion([string]$regionName) {
        if ($this._currentLayout.Regions -and $this._currentLayout.Regions.ContainsKey($regionName)) {
            return $this._currentLayout.Regions[$regionName]
        }
        return $null
    }
    
    # Get all visible regions
    [hashtable[]] GetVisibleRegions() {
        if (-not $this._currentLayout.Regions) {
            return @()
        }
        
        return $this._currentLayout.Regions.Values | Where-Object { $_.Visible }
    }
    
    # Register custom layout
    [void] RegisterLayout([string]$name, [hashtable]$layoutDefinition) {
        $this._layouts[$name] = $layoutDefinition
        
        if ($this._logger) {
            $this._logger.Debug("EnhancedLayoutEngine: Registered custom layout: $name")
        }
    }
    
    # Get available layouts
    [string[]] GetAvailableLayouts() {
        return $this._layouts.Keys
    }
    
    # Get layout information
    [hashtable] GetLayoutInfo([string]$layoutName) {
        if ($this._layouts.ContainsKey($layoutName)) {
            return @{
                Name = $this._layouts[$layoutName].Name
                Regions = $this._layouts[$layoutName].Regions.Keys
                ResponsiveBreakpoints = if ($this._layouts[$layoutName].Responsive) { $this._layouts[$layoutName].Responsive.Keys } else { @() }
            }
        }
        return $null
    }
    
    # Get current layout state
    [hashtable] GetCurrentLayoutState() {
        return @{
            CurrentLayout = $this._currentLayout
            Breakpoints = $this._breakpoints
            LastCalculation = $this._currentLayout.Timestamp
            ScreenSize = @{
                Width = $this._lastWidth
                Height = $this._lastHeight
            }
        }
    }
    
    # Export layout for debugging
    [hashtable] ExportLayouts() {
        return @{
            Timestamp = [datetime]::Now
            RegisteredLayouts = $this._layouts.Keys
            CurrentLayout = $this._currentLayout
            Breakpoints = $this._breakpoints
        }
    }
}
```

### 16. Complete Integration Example (Updated)

How all systems work together with UDA and enhanced layout support:

```powershell
class ProductionTaskWarriorRenderEngine : TaskWarriorRenderEngine {
    hidden [VirtualScrollingEngine] $_virtualScroller
    hidden [TaskProcessingPipeline] $_processingPipeline  
    hidden [RenderStateManager] $_stateManager
    hidden [RenderCacheManager] $_cacheManager
    hidden [RenderErrorHandler] $_errorHandler
    hidden [UnicodeTextMeasurement] $_textMeasurement
    hidden [AsyncCommandExecutor] $_commandExecutor
    hidden [RenderEventCoordinator] $_eventCoordinator
    hidden [InputOutputCoordinator] $_inputCoordinator
    hidden [TerminalManager] $_terminalManager
    hidden [ComponentLifecycleManager] $_componentManager
    hidden [PerformanceMonitor] $_performanceMonitor
    hidden [ConfigurationManager] $_configManager
    hidden [TaskWarriorThemeManager] $_themeManager
    hidden [UDAManager] $_udaManager
    hidden [EnhancedLayoutEngine] $_layoutEngine
    
    ProductionTaskWarriorRenderEngine([hashtable]$initialState) : base() {
        # Initialize core subsystems first
        $logger = [Logger]::Instance
        $this._eventCoordinator = [RenderEventCoordinator]::new($logger)
        $this._configManager = [ConfigurationManager]::new($logger, $this._eventCoordinator)
        
        # Initialize all subsystems
        $this._virtualScroller = [VirtualScrollingEngine]::new(15)  # 15 row buffer
        $this._processingPipeline = [TaskProcessingPipeline]::new()
        $this._stateManager = [RenderStateManager]::new($initialState, $this._eventCoordinator)
        $this._cacheManager = [RenderCacheManager]::new(5000)  # 5000 entry cache
        $this._errorHandler = [RenderErrorHandler]::new($logger)
        $this._textMeasurement = [UnicodeTextMeasurement]::new()
        $this._commandExecutor = [AsyncCommandExecutor]::new()
        $this._inputCoordinator = [InputOutputCoordinator]::new($logger, $this._eventCoordinator)
        $this._terminalManager = [TerminalManager]::new($logger, $this._eventCoordinator)
        $this._performanceMonitor = [PerformanceMonitor]::new($logger)
        $this._themeManager = [TaskWarriorThemeManager]::new()
        
        # Initialize enhanced systems
        $this._udaManager = [UDAManager]::new($logger, $this._configManager)
        $this._layoutEngine = [EnhancedLayoutEngine]::new($logger)
        
        # Initialize component lifecycle manager
        $serviceContainer = $this.CreateServiceContainer()
        $this._componentManager = [ComponentLifecycleManager]::new($logger, $this._eventCoordinator, $serviceContainer)
        
        # Setup reactive subscriptions
        $this.SetupReactiveSystem()
        
        # Configure layout based on screen size
        $this.InitializeLayout()
    }
    
    # Create service container for dependency injection
    hidden [hashtable] CreateServiceContainer() {
        return @{
            'Logger' = [Logger]::Instance
            'EventCoordinator' = $this._eventCoordinator
            'ConfigManager' = $this._configManager
            'ThemeManager' = $this._themeManager
            'VirtualScroller' = $this._virtualScroller
            'InputCoordinator' = $this._inputCoordinator
            'TerminalManager' = $this._terminalManager
            'CacheManager' = $this._cacheManager
            'PerformanceMonitor' = $this._performanceMonitor
            'UDAManager' = $this._udaManager
            'LayoutEngine' = $this._layoutEngine
        }
    }
    
    # Initialize layout system
    hidden [void] InitializeLayout() {
        $width = [Console]::WindowWidth
        $height = [Console]::WindowHeight
        $layoutName = $this._configManager.GetValue('ui.layout', 'standard')
        
        $layout = $this._layoutEngine.CalculateLayout($layoutName, $width, $height)
        
        if ($this._logger) {
            $this._logger.Info("ProductionTaskWarriorRenderEngine: Initialized with $layoutName layout (${width}x${height})")
        }
    }
    
    # Enhanced render method with UDA support
    [string] RenderTaskList([hashtable[]]$tasks, [hashtable]$displayOptions = @{}) {
        $timerId = $this._performanceMonitor.StartTimer('RenderFrame')
        
        try {
            # Get current layout
            $layout = $this._layoutEngine.GetCurrentLayoutState()
            $contentRegion = $layout.CurrentLayout.Regions['content']
            
            if (-not $contentRegion -or -not $contentRegion.Visible) {
                return ""
            }
            
            # Build column definitions including UDAs
            $columns = $this.BuildColumnDefinitions($displayOptions)
            
            # Calculate column widths
            $columnWidths = $this.CalculateColumnWidths($columns, $contentRegion.Width)
            
            # Render with virtual scrolling
            $scrollTop = $displayOptions.ScrollTop ?? 0
            $selectedIndex = $displayOptions.SelectedIndex ?? 0
            
            $visibleRange = $this._virtualScroller.CalculateVisibleRange($scrollTop, $contentRegion.Height, $tasks.Count)
            
            $sb = $this.GetPooledStringBuilder()
            
            # Render header
            $headerContent = $this.RenderColumnHeaders($columns, $columnWidths, $contentRegion.Width)
            $sb.Append($this.MoveTo($contentRegion.X, $contentRegion.Y))
            $sb.Append($headerContent)
            
            # Render visible task rows
            $currentY = $contentRegion.Y + 1  # Skip header
            for ($i = $visibleRange.Start; $i -lt $visibleRange.End; $i++) {
                if ($i -ge $tasks.Count) { break }
                
                $task = $tasks[$i]
                $isSelected = ($i -eq $selectedIndex)
                
                $rowContent = $this.RenderTaskRow($task, $columns, $columnWidths, $isSelected)
                $sb.Append($this.MoveTo($contentRegion.X, $currentY))
                $sb.Append($rowContent)
                
                $currentY++
                if ($currentY -ge $contentRegion.Y + $contentRegion.Height) { break }
            }
            
            # Clear remaining space
            while ($currentY -lt $contentRegion.Y + $contentRegion.Height) {
                $sb.Append($this.MoveTo($contentRegion.X, $currentY))
                $sb.Append($this.ClearLine())
                $currentY++
            }
            
            $result = $sb.ToString()
            $this.ReturnPooledStringBuilder($sb)
            
            # Cache successful render
            $this._errorHandler.CacheSuccessfulRender('TaskList', $result)
            
            return $result
            
        } catch {
            return $this._errorHandler.HandleRenderError('TaskList', $_, '[Task list unavailable]')
        } finally {
            $this._performanceMonitor.StopTimer($timerId)
        }
    }
    
    # Build column definitions including UDAs
    hidden [hashtable[]] BuildColumnDefinitions([hashtable]$displayOptions) {
        $columns = @()
        
        # Standard columns
        $standardColumns = @('ID', 'Priority', 'Project', 'Description', 'Due', 'Urgency', 'Tags')
        
        foreach ($columnName in $standardColumns) {
            $configKey = "ui.show_$($columnName.ToLower())"
            if ($this._configManager.GetValue($configKey, $true)) {
                $columns += $this.GetStandardColumnDefinition($columnName)
            }
        }
        
        # Add UDA columns
        $udas = $this._udaManager.GetDisplayableUDAs()
        foreach ($uda in $udas) {
            if ($uda.Visible) {
                $columns += $this._udaManager.CreateUDAColumnDefinition($uda.Name)
            }
        }
        
        return $columns
    }
    
    # Get standard column definition
    hidden [hashtable] GetStandardColumnDefinition([string]$columnName) {
        $definitions = @{
            'ID' = @{ Name = 'ID'; Header = 'ID'; Attribute = 'id'; MinWidth = 3; Weight = 0.05; Alignment = 'Right' }
            'Priority' = @{ Name = 'Priority'; Header = 'Pri'; Attribute = 'priority'; MinWidth = 3; Weight = 0.05; Alignment = 'Center' }
            'Project' = @{ Name = 'Project'; Header = 'Project'; Attribute = 'project'; MinWidth = 8; Weight = 0.15; Alignment = 'Left' }
            'Description' = @{ Name = 'Description'; Header = 'Description'; Attribute = 'description'; MinWidth = 20; Weight = 0.40; Alignment = 'Left' }
            'Due' = @{ Name = 'Due'; Header = 'Due'; Attribute = 'due'; MinWidth = 10; Weight = 0.12; Alignment = 'Left' }
            'Urgency' = @{ Name = 'Urgency'; Header = 'Urg'; Attribute = 'urgency'; MinWidth = 6; Weight = 0.08; Alignment = 'Right' }
            'Tags' = @{ Name = 'Tags'; Header = 'Tags'; Attribute = 'tags'; MinWidth = 8; Weight = 0.15; Alignment = 'Left' }
        }
        
        return $definitions[$columnName]
    }
    
    # Render individual task row with UDA support
    hidden [string] RenderTaskRow([hashtable]$task, [hashtable[]]$columns, [hashtable]$columnWidths, [bool]$isSelected) {
        $sb = $this.GetPooledStringBuilder()
        
        # Apply row styling
        if ($isSelected) {
            $sb.Append($this._themeManager.GetColor('background.selected'))
            $sb.Append($this._themeManager.GetColor('text.highlight'))
        }
        
        $xOffset = 0
        foreach ($column in $columns) {
            $width = $columnWidths[$column.Name]
            $content = $this.FormatColumnContent($task, $column, $width)
            
            # Add padding for alignment
            switch ($column.Alignment) {
                'Right' { $content = $content.PadLeft($width) }
                'Center' { 
                    $padding = [Math]::Max(0, $width - $content.Length)
                    $leftPad = [int]($padding / 2)
                    $rightPad = $padding - $leftPad
                    $content = (' ' * $leftPad) + $content + (' ' * $rightPad)
                }
                default { $content = $content.PadRight($width) }
            }
            
            # Truncate if too long
            if ($content.Length -gt $width) {
                $content = $content.Substring(0, $width - 3) + '...'
            }
            
            $sb.Append($content)
            $xOffset += $width
        }
        
        if ($isSelected) {
            $sb.Append($this.Reset())
        }
        
        $result = $sb.ToString()
        $this.ReturnPooledStringBuilder($sb)
        return $result
    }
    
    # Format column content with UDA support
    hidden [string] FormatColumnContent([hashtable]$task, [hashtable]$column, [int]$width) {
        $attribute = $column.Attribute
        
        # Handle UDA columns
        if ($column.ContainsKey('UDAType')) {
            $value = $this._udaManager.GetUDAValue($task, $attribute)
            return $this._udaManager.FormatUDAValue($attribute, $value)
        }
        
        # Handle standard columns
        switch ($attribute) {
            'tags' {
                if ($task.tags -and $task.tags.Count -gt 0) {
                    return '+' + ($task.tags -join ' +')
                }
                return ''
            }
            'due' {
                if ($task.due) {
                    $dueDate = [datetime]$task.due
                    $color = $this._themeManager.GetDueColor($dueDate)
                    return $this._themeManager.ColorizeText($dueDate.ToString('MM/dd'), 'due.normal')
                }
                return ''
            }
            'urgency' {
                if ($task.urgency) {
                    $urgency = [double]$task.urgency
                    $color = $this._themeManager.GetUrgencyColor($urgency)
                    return $this._themeManager.ColorizeText($urgency.ToString('F1'), 'text.primary')
                }
                return ''
            }
            'priority' {
                if ($task.priority) {
                    return $this._themeManager.ColorizeText("[$($task.priority)]", "priority.$($task.priority.ToLower())")
                }
                return ''
            }
            default {
                if ($task.ContainsKey($attribute)) {
                    return $task[$attribute].ToString()
                }
                return ''
            }
        }
    }
        $this._textMeasurement = [UnicodeTextMeasurement]::new()
        $this._commandExecutor = [AsyncCommandExecutor]::new()
        
        # Set up reactive subscriptions
        $this.SetupReactiveSystem()
    }
    
    # Set up event subscriptions for reactive updates
    [void] SetupReactiveSystem() {
        # When tasks change, invalidate caches and queue background processing
        $this._stateManager.Subscribe('TasksChanged', {
            param($eventData)
            $this._cacheManager.InvalidateFilterCache()
            $this._virtualScroller.ClearCache()
            
            # Queue urgency recalculation in background
            $this._processingPipeline.QueueUrgencyCalculation($eventData.NewTasks, $this._stateManager.GetStateValue('urgencyConfig'))
        })
        
        # When filter changes, queue filter evaluation
        $this._stateManager.Subscribe('FilterChanged', {
            param($eventData)
            $tasks = $this._stateManager.GetStateValue('tasks')
            $this._processingPipeline.QueueFilterEvaluation($tasks, $eventData.NewFilter)
        })
        
        # When configuration changes, invalidate related caches
        $this._stateManager.Subscribe('ConfigChanged', {
            param($eventData)
            $this._cacheManager.ClearAll()
            
            # Recalculate all urgencies with new config
            $tasks = $this._stateManager.GetStateValue('tasks')
            $this._processingPipeline.QueueUrgencyCalculation($tasks, $eventData.Changes)
        })
    }
    
    # Production-ready frame rendering with all optimizations
    [void] RenderFrame([hashtable]$appState) {
        $this._errorHandler.ExecuteWithErrorBoundary('RenderFrame', {
            # Begin state transaction
            $this._stateManager.BeginTransaction()
            
            try {
                # Update state
                $this._stateManager.UpdateTaskList($appState.tasks)
                if ($appState.currentFilter -ne $this._stateManager.GetStateValue('currentFilter')) {
                    $this._stateManager.UpdateFilter($appState.currentFilter)
                }
                
                # Calculate virtual scrolling range
                $visibleRange = $this._virtualScroller.CalculateVisibleRange(
                    $appState.scrollOffset,
                    $appState.viewportHeight,
                    $appState.visibleTasks.Count
                )
                
                # Render only visible tasks with caching
                $renderedContent = $this.RenderVisibleTasks($appState.visibleTasks, $visibleRange)
                
                # Compose final frame
                $sb = $this.GetPooledStringBuilder()
                try {
                    $sb.Append([VT]::HideCursor())
                    $sb.Append($renderedContent)
                    $sb.Append([VT]::ShowCursor())
                    
                    [Console]::Write($sb.ToString())
                } finally {
                    $this.ReturnPooledStringBuilder($sb)
                }
                
                # Commit state changes
                $this._stateManager.CommitTransaction()
                
            } catch {
                # Rollback on any error
                $this._stateManager.RollbackTransaction()
                throw
            }
        })
    }
    
    # Render only the visible portion of tasks
    hidden [string] RenderVisibleTasks([Task[]]$tasks, [hashtable]$visibleRange) {
        $sb = $this.GetPooledStringBuilder()
        
        try {
            for ($i = $visibleRange.BufferStart; $i -le $visibleRange.BufferEnd; $i++) {
                if ($i -lt 0 -or $i -ge $tasks.Count) { continue }
                
                $task = $tasks[$i]
                $isVisible = ($i -ge $visibleRange.StartIndex -and $i -le $visibleRange.EndIndex)
                
                # Use cached rendering when possible
                $renderedLine = $this._virtualScroller.GetRenderedLine($i, $task, {
                    param($taskToRender)
                    return $this.FormatTaskLineWithCache($taskToRender)
                })
                
                if ($isVisible) {
                    $sb.AppendLine($renderedLine)
                }
            }
            
            return $sb.ToString()
        } finally {
            $this.ReturnPooledStringBuilder($sb)
        }
    }
    
    # Format task line with comprehensive caching
    hidden [string] FormatTaskLineWithCache([Task]$task) {
        $formatHash = $this.GetFormatHash($task)
        $cachedLine = $this._cacheManager.GetCachedFormattedLine($task.uuid, $formatHash)
        
        if ($cachedLine) { return $cachedLine }
        
        # Render with Unicode-aware text measurement
        $formattedLine = $this.FormatTaskLineContent($task, [Console]::WindowWidth, @())
        
        $this._cacheManager.CacheFormattedLine($task.uuid, $formatHash, $formattedLine)
        return $formattedLine
    }
}
```

## Migration Path

### 1. From Praxis Components

Existing Praxis components can be adapted:

- **VT100.ps1** → Direct integration (no changes needed)
- **RenderHelper.ps1** → Extend with TaskWarrior-specific methods
- **RenderEngine.ps1** → Subclass for TaskWarrior specialization
- **StringCache.ps1** → Direct integration for performance

### 2. Implementation Phases

**Phase 1**: Basic frame rendering with static task list
**Phase 2**: Interactive selection and scrolling  
**Phase 3**: Mode-specific command/edit interfaces
**Phase 4**: Advanced features (filtering, in-place editing)
**Phase 5**: Performance optimization and polish

This specification provides a complete, performance-optimized rendering solution that combines the best practices from the Praxis framework with the specific requirements of the TaskWarrior-TUI application.