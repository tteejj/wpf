# Filter Engine Implementation
# Advanced filtering, sorting, and search capabilities for TaskWarrior data

# Base filter interface
class BaseFilter {
    hidden [string] $_filterType
    
    BaseFilter([string]$filterType) {
        $this._filterType = $filterType
    }
    
    [string] GetFilterType() {
        return $this._filterType
    }
    
    # Virtual method to be overridden by concrete filters
    [bool] Matches([hashtable]$task) {
        throw "Matches method must be implemented by concrete filter classes"
    }
    
    [string] GetCacheKey() {
        return "$($this._filterType):$($this.ToString())"
    }
}

# Concrete filter implementations
class StatusFilter : BaseFilter {
    hidden [string[]] $_statuses
    
    StatusFilter([string]$status) : base("status") {
        $this._statuses = @($status)
    }
    
    StatusFilter([string[]]$statuses) : base("status") {
        $this._statuses = $statuses
    }
    
    [bool] Matches([hashtable]$task) {
        $taskStatus = if ($task.status) { $task.status } else { "pending" }
        return $taskStatus -in $this._statuses
    }
    
    [string] ToString() {
        return $this._statuses -join ","
    }
}

class ProjectFilter : BaseFilter {
    hidden [string[]] $_projects
    
    ProjectFilter([string]$project) : base("project") {
        $this._projects = @($project)
    }
    
    ProjectFilter([string[]]$projects) : base("project") {
        $this._projects = $projects
    }
    
    [bool] Matches([hashtable]$task) {
        $taskProject = if ($task.project) { $task.project } else { "" }
        return $taskProject -in $this._projects
    }
    
    [string] ToString() {
        return $this._projects -join ","
    }
}

class PriorityFilter : BaseFilter {
    hidden [string[]] $_priorities
    
    PriorityFilter([string]$priority) : base("priority") {
        $this._priorities = @($priority)
    }
    
    PriorityFilter([string[]]$priorities) : base("priority") {
        $this._priorities = $priorities
    }
    
    [bool] Matches([hashtable]$task) {
        $taskPriority = if ($task.priority) { $task.priority } else { "" }
        return $taskPriority -in $this._priorities
    }
    
    [string] ToString() {
        return $this._priorities -join ","
    }
}

class TagFilter : BaseFilter {
    hidden [string] $_tag
    hidden [bool] $_mustHave
    
    TagFilter([string]$tag) : base("tag") {
        $this._tag = $tag
        $this._mustHave = $true
    }
    
    TagFilter([string]$tag, [bool]$mustHave) : base("tag") {
        $this._tag = $tag
        $this._mustHave = $mustHave
    }
    
    [bool] Matches([hashtable]$task) {
        $taskTags = if ($task.tags) { $task.tags } else { @() }
        $hasTag = $this._tag -in $taskTags
        
        if ($this._mustHave) { 
            return $hasTag 
        } else { 
            return (-not $hasTag) 
        }
    }
    
    [string] ToString() {
        $prefix = if ($this._mustHave) { "+" } else { "-" }
        return "$prefix$($this._tag)"
    }
}

class UrgencyFilter : BaseFilter {
    hidden [double] $_minUrgency
    hidden [double] $_maxUrgency
    
    UrgencyFilter([double]$minUrgency, [double]$maxUrgency) : base("urgency") {
        $this._minUrgency = $minUrgency
        $this._maxUrgency = $maxUrgency
    }
    
    [bool] Matches([hashtable]$task) {
        $taskUrgency = if ($task.urgency) { [double]$task.urgency } else { 0.0 }
        return $taskUrgency -ge $this._minUrgency -and $taskUrgency -le $this._maxUrgency
    }
    
    [string] ToString() {
        return "$($this._minUrgency)-$($this._maxUrgency)"
    }
}

class DueDateFilter : BaseFilter {
    hidden [DateTime] $_startDate
    hidden [DateTime] $_endDate
    
    DueDateFilter([DateTime]$startDate, [DateTime]$endDate) : base("due") {
        $this._startDate = $startDate
        $this._endDate = $endDate
    }
    
    [bool] Matches([hashtable]$task) {
        if (-not $task.due) {
            return $false
        }
        
        try {
            $dueDate = [DateTime]::ParseExact($task.due.Substring(0,8), "yyyyMMdd", $null)
            return $dueDate -ge $this._startDate.Date -and $dueDate -le $this._endDate.Date
        } catch {
            return $false
        }
    }
    
    [string] ToString() {
        return "$($this._startDate.ToString('yyyyMMdd'))-$($this._endDate.ToString('yyyyMMdd'))"
    }
}

class TextSearchFilter : BaseFilter {
    hidden [string] $_searchText
    hidden [bool] $_caseSensitive
    
    TextSearchFilter([string]$searchText) : base("text") {
        $this._searchText = $searchText
        $this._caseSensitive = $false
    }
    
    TextSearchFilter([string]$searchText, [bool]$caseSensitive) : base("text") {
        $this._searchText = $searchText
        $this._caseSensitive = $caseSensitive
    }
    
    [bool] Matches([hashtable]$task) {
        $description = if ($task.description) { $task.description } else { "" }
        
        if ($this._caseSensitive) {
            return $description.Contains($this._searchText)
        } else {
            return $description.ToLower().Contains($this._searchText.ToLower())
        }
    }
    
    [string] ToString() {
        return $this._searchText
    }
}

class HasDueDateFilter : BaseFilter {
    HasDueDateFilter() : base("hasdue") {
    }
    
    [bool] Matches([hashtable]$task) {
        return $null -ne $task.due -and $task.due -ne ""
    }
    
    [string] ToString() {
        return "hasdue"
    }
}

class HasProjectFilter : BaseFilter {
    HasProjectFilter() : base("hasproject") {
    }
    
    [bool] Matches([hashtable]$task) {
        return $null -ne $task.project -and $task.project -ne ""
    }
    
    [string] ToString() {
        return "hasproject"
    }
}

# Filter group for combining filters with AND/OR logic
class FilterGroup : BaseFilter {
    hidden [string] $_logic  # "AND" or "OR"
    hidden [array] $_filters = @()
    
    FilterGroup([string]$logic) : base("group") {
        $this._logic = $logic.ToUpper()
        if ($this._logic -notin @("AND", "OR")) {
            throw "FilterGroup logic must be 'AND' or 'OR'"
        }
    }
    
    [void] AddFilter([BaseFilter]$filter) {
        $this._filters += $filter
    }
    
    [void] RemoveFilter([BaseFilter]$filter) {
        $this._filters = $this._filters | Where-Object { $_ -ne $filter }
    }
    
    [array] GetFilters() {
        return $this._filters
    }
    
    [bool] Matches([hashtable]$task) {
        if ($this._filters.Count -eq 0) {
            return $true
        }
        
        if ($this._logic -eq "AND") {
            foreach ($filter in $this._filters) {
                if (-not $filter.Matches($task)) {
                    return $false
                }
            }
            return $true
        } else {
            foreach ($filter in $this._filters) {
                if ($filter.Matches($task)) {
                    return $true
                }
            }
            return $false
        }
    }
    
    [string] ToString() {
        $filterStrings = @()
        foreach ($filter in $this._filters) {
            $filterStrings += $filter.ToString()
        }
        return "($($filterStrings -join " $($this._logic) "))"
    }
}

# Base sorter interface
class BaseSorter {
    hidden [bool] $_descending
    hidden [string] $_sortField
    
    BaseSorter([string]$sortField, [bool]$descending) {
        $this._sortField = $sortField
        $this._descending = $descending
    }
    
    [string] GetSortField() {
        return $this._sortField
    }
    
    [bool] IsDescending() {
        return $this._descending
    }
    
    # Virtual method for comparison
    [int] Compare([hashtable]$task1, [hashtable]$task2) {
        throw "Compare method must be implemented by concrete sorter classes"
    }
}

# Concrete sorter implementations
class UrgencySorter : BaseSorter {
    UrgencySorter([bool]$descending) : base("urgency", $descending) {
    }
    
    [int] Compare([hashtable]$task1, [hashtable]$task2) {
        $urgency1 = if ($task1.urgency) { [double]$task1.urgency } else { 0.0 }
        $urgency2 = if ($task2.urgency) { [double]$task2.urgency } else { 0.0 }
        
        $result = if ($urgency1 -lt $urgency2) { -1 } elseif ($urgency1 -gt $urgency2) { 1 } else { 0 }
        
        return if ($this._descending) { -$result } else { $result }
    }
}

class DueDateSorter : BaseSorter {
    DueDateSorter([bool]$descending) : base("due", $descending) {
    }
    
    [int] Compare([hashtable]$task1, [hashtable]$task2) {
        $date1 = if ($task1.due) { 
            try { [DateTime]::ParseExact($task1.due.Substring(0,8), "yyyyMMdd", $null) } 
            catch { [DateTime]::MaxValue }
        } else { [DateTime]::MaxValue }
        
        $date2 = if ($task2.due) { 
            try { [DateTime]::ParseExact($task2.due.Substring(0,8), "yyyyMMdd", $null) } 
            catch { [DateTime]::MaxValue }
        } else { [DateTime]::MaxValue }
        
        $result = if ($date1 -lt $date2) { -1 } elseif ($date1 -gt $date2) { 1 } else { 0 }
        
        return if ($this._descending) { -$result } else { $result }
    }
}

class ProjectSorter : BaseSorter {
    ProjectSorter([bool]$descending) : base("project", $descending) {
    }
    
    [int] Compare([hashtable]$task1, [hashtable]$task2) {
        $project1 = if ($task1.project) { $task1.project } else { "" }
        $project2 = if ($task2.project) { $task2.project } else { "" }
        
        $result = $project1.CompareTo($project2)
        
        return if ($this._descending) { -$result } else { $result }
    }
}

# Main filter engine
class FilterEngine {
    hidden [array] $_filters = @()
    hidden [VirtualDataSource] $_dataSource
    hidden [BaseSorter] $_sorter = $null
    hidden [object] $_eventPublisher  # EventPublisher
    hidden [TaskCacheManager] $_cache = $null
    hidden [array] $_lastResults = @()
    hidden [string] $_lastCacheKey = ""
    
    FilterEngine([object]$eventPublisher) {
        $this._eventPublisher = $eventPublisher
    }
    
    FilterEngine([object]$eventPublisher, [TaskCacheManager]$cache) {
        $this._eventPublisher = $eventPublisher
        $this._cache = $cache
    }
    
    [void] SetDataSource([VirtualDataSource]$dataSource) {
        $this._dataSource = $dataSource
        $this.InvalidateCache()
    }
    
    [void] AddFilter([BaseFilter]$filter) {
        $this._filters += $filter
        $this.PublishFilterChangeEvent()
        $this.InvalidateCache()
    }
    
    [void] RemoveFilter([BaseFilter]$filter) {
        $this._filters = $this._filters | Where-Object { $_ -ne $filter }
        $this.PublishFilterChangeEvent()
        $this.InvalidateCache()
    }
    
    [void] ClearFilters() {
        $this._filters = @()
        $this.PublishFilterChangeEvent()
        $this.InvalidateCache()
    }
    
    [array] GetFilters() {
        return $this._filters
    }
    
    [void] SetSorter([BaseSorter]$sorter) {
        $this._sorter = $sorter
        $this.InvalidateCache()
    }
    
    [BaseSorter] GetSorter() {
        return $this._sorter
    }
    
    [int] GetTotalItemCount() {
        if ($null -eq $this._dataSource) {
            return 0
        }
        return $this._dataSource.GetTotalCount()
    }
    
    [array] GetFilteredResults() {
        # Generate cache key
        $cacheKey = $this.GenerateCacheKey()
        
        # Check external cache first (TaskCacheManager)
        if ($this._cache) {
            $cachedResults = $this._cache.GetCachedTasks($cacheKey)
            if ($null -ne $cachedResults) {
                $this._lastResults = $cachedResults
                $this._lastCacheKey = $cacheKey
                return $cachedResults
            }
        }
        
        # Check internal cache second
        if ($cacheKey -eq $this._lastCacheKey -and $this._lastResults.Count -gt 0) {
            return $this._lastResults
        }
        
        # Apply filters
        $results = $this.ApplyFilters()
        
        # Apply sorting
        if ($null -ne $this._sorter) {
            $results = $this.ApplySorting($results)
        }
        
        # Cache results
        if ($this._cache) {
            $this._cache.CacheTasks($cacheKey, $results, 300)  # Cache for 5 minutes
        }
        
        $this._lastResults = $results
        $this._lastCacheKey = $cacheKey
        
        # Publish results change event
        $this.PublishResultChangeEvent($results)
        
        return $results
    }
    
    hidden [array] ApplyFilters() {
        if ($null -eq $this._dataSource) {
            return @()
        }
        
        if ($this._filters.Count -eq 0) {
            # No filters, return all data
            return $this._dataSource.GetRange(0, $this._dataSource.GetTotalCount())
        }
        
        $results = @()
        $totalItems = $this._dataSource.GetTotalCount()
        
        for ($i = 0; $i -lt $totalItems; $i++) {
            $task = $this._dataSource.GetItem($i)
            if ($null -eq $task) {
                continue
            }
            
            $matches = $true
            foreach ($filter in $this._filters) {
                if (-not $filter.Matches($task)) {
                    $matches = $false
                    break
                }
            }
            
            if ($matches) {
                $results += $task
            }
        }
        
        return $results
    }
    
    hidden [array] ApplySorting([array]$items) {
        if ($null -eq $this._sorter -or $items.Count -le 1) {
            return $items
        }
        
        # Use a manual sorting approach for better control
        $sortField = $this._sorter.GetSortField()
        $descending = $this._sorter.IsDescending()
        
        switch ($sortField) {
            "urgency" {
                $sortedItems = $items | Sort-Object -Property { 
                    if ($_.urgency) { [double]$_.urgency } else { 0.0 }
                } -Descending:$descending
                return $sortedItems
            }
            "due" {
                # First, separate tasks with and without due dates
                $tasksWithDue = $items | Where-Object { $_.due }
                $tasksWithoutDue = $items | Where-Object { -not $_.due }
                
                # Sort tasks with due dates
                $sortedWithDue = $tasksWithDue | Sort-Object -Property {
                    try {
                        [DateTime]::ParseExact($_.due.Substring(0,8), "yyyyMMdd", $null)
                    } catch {
                        [DateTime]::MaxValue
                    }
                } -Descending:$descending
                
                # Combine: tasks with due dates first, then tasks without
                if ($descending) {
                    return $sortedWithDue + $tasksWithoutDue
                } else {
                    return $sortedWithDue + $tasksWithoutDue
                }
            }
            "project" {
                $sortedItems = $items | Sort-Object -Property { 
                    if ($_.project) { $_.project } else { "" }
                } -Descending:$descending
                return $sortedItems
            }
            default {
                return $items
            }
        }
        
        # This should never be reached due to switch cases, but PowerShell requires it
        return $items
    }
    
    hidden [string] GenerateCacheKey() {
        $filterKeys = @()
        foreach ($filter in $this._filters) {
            $filterKeys += $filter.GetCacheKey()
        }
        
        $sorterKey = if ($this._sorter) { 
            "sort:$($this._sorter.GetSortField()):$($this._sorter.IsDescending())" 
        } else { 
            "nosort" 
        }
        
        return "filtered:$($filterKeys -join ';'):$sorterKey"
    }
    
    hidden [void] InvalidateCache() {
        $this._lastResults = @()
        $this._lastCacheKey = ""
    }
    
    hidden [void] PublishFilterChangeEvent() {
        if ($null -ne $this._eventPublisher) {
            $this._eventPublisher.Publish('FiltersChanged', @{
                FilterCount = $this._filters.Count
                Filters = $this._filters | ForEach-Object { $_.ToString() }
                Timestamp = Get-Date
            })
        }
    }
    
    hidden [void] PublishResultChangeEvent([array]$results) {
        if ($null -ne $this._eventPublisher) {
            $this._eventPublisher.Publish('FilterResultsChanged', @{
                ResultCount = $results.Count
                TotalCount = $this.GetTotalItemCount()
                FilterCount = $this._filters.Count
                Timestamp = Get-Date
            })
        }
    }
    
    # TaskWarrior query integration
    [void] ApplyQuery([string]$query) {
        $parser = [TaskWarriorQueryParser]::new()
        $filters = $parser.ParseQuery($query)
        
        $this.ClearFilters()
        foreach ($filter in $filters) {
            $this.AddFilter($filter)
        }
    }
}

# TaskWarrior query language parser
class TaskWarriorQueryParser {
    TaskWarriorQueryParser() {
    }
    
    [array] ParseQuery([string]$query) {
        $filters = @()
        
        if ([string]::IsNullOrWhiteSpace($query)) {
            return $filters
        }
        
        # Split query into components
        $components = $query -split '\s+'
        
        foreach ($component in $components) {
            $component = $component.Trim()
            if ([string]::IsNullOrEmpty($component)) {
                continue
            }
            
            try {
                $filter = $this.ParseComponent($component)
                if ($null -ne $filter) {
                    $filters += $filter
                }
            } catch {
                # Skip invalid components
                Write-Warning "Failed to parse query component: $component"
            }
        }
        
        return $filters
    }
    
    hidden [BaseFilter] ParseComponent([string]$component) {
        # Handle tags (+tag or -tag)
        if ($component.StartsWith('+')) {
            $tag = $component.Substring(1)
            return [TagFilter]::new($tag, $true)
        }
        
        if ($component.StartsWith('-')) {
            $tag = $component.Substring(1)
            return [TagFilter]::new($tag, $false)
        }
        
        # Handle field:value patterns
        if ($component.Contains(':')) {
            $parts = $component -split ':', 2
            $field = $parts[0].ToLower()
            $value = $parts[1]
            
            switch ($field) {
                'status' {
                    return [StatusFilter]::new($value)
                }
                'project' {
                    return [ProjectFilter]::new($value)
                }
                'priority' {
                    return [PriorityFilter]::new($value)
                }
                'due' {
                    return $this.ParseDateFilter($value)
                }
                'urgency.gt' {
                    return [UrgencyFilter]::new([double]$value, 999.0)
                }
                'urgency.lt' {
                    return [UrgencyFilter]::new(0.0, [double]$value)
                }
                default {
                    # Unknown field, return null
                    return $null
                }
            }
        }
        
        return $null
    }
    
    hidden [BaseFilter] ParseDateFilter([string]$dateValue) {
        $today = (Get-Date).Date
        
        switch ($dateValue.ToLower()) {
            'today' {
                return [DueDateFilter]::new($today, $today)
            }
            'tomorrow' {
                $tomorrow = $today.AddDays(1)
                return [DueDateFilter]::new($tomorrow, $tomorrow)
            }
            'eow' {
                # End of week (Sunday)
                $daysUntilSunday = 7 - [int]$today.DayOfWeek
                $endOfWeek = $today.AddDays($daysUntilSunday)
                return [DueDateFilter]::new($today, $endOfWeek)
            }
            default {
                # Try to parse as absolute date
                try {
                    $parsedDate = [DateTime]::Parse($dateValue)
                    return [DueDateFilter]::new($parsedDate.Date, $parsedDate.Date)
                } catch {
                    return $null
                }
            }
        }
        
        # This should never be reached due to default case, but PowerShell requires it
        return $null
    }
}