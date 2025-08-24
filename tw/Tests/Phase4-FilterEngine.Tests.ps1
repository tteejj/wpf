# Phase 4: Filter Engine Tests
# Advanced filtering, sorting, and search capabilities

BeforeAll {
    # Import required classes
    try {
        . "$PSScriptRoot/../Core/RenderEngine.ps1"
        . "$PSScriptRoot/../Core/EventSystem.ps1"
        . "$PSScriptRoot/../Core/ConfigurationProvider.ps1"
        . "$PSScriptRoot/../Core/TaskDataProvider.ps1"
        . "$PSScriptRoot/../Core/CachingSystem.ps1"
        . "$PSScriptRoot/../Core/VirtualScrolling.ps1"
        . "$PSScriptRoot/../Core/FilterEngine.ps1"
    } catch {
        Write-Warning "Core classes not yet implemented: $_"
    }
    
    # Create comprehensive mock dataset for filter testing
    $Global:FilterTestTasks = @()
    
    # Create varied tasks for comprehensive filter testing
    $projects = @("personal", "work", "home", $null)
    $statuses = @("pending", "completed", "waiting", "deleted")
    $priorities = @("H", "M", "L", $null)
    $tags = @(@("urgent", "important"), @("routine", "maintenance"), @("creative"), @(), @("bug", "critical"))
    
    for ($i = 1; $i -le 500; $i++) {
        $project = $projects[($i - 1) % $projects.Count]
        $status = $statuses[($i - 1) % $statuses.Count]
        $priority = $priorities[($i - 1) % $priorities.Count]
        $taskTags = $tags[($i - 1) % $tags.Count]
        
        $Global:FilterTestTasks += @{
            uuid = "12345678-1234-1234-1234-$('{0:D12}' -f $i)"
            id = $i
            description = "Filter test task $i with varied content and descriptions for comprehensive testing scenarios"
            status = $status
            project = $project
            priority = $priority
            tags = $taskTags
            urgency = [math]::Round((Get-Random -Minimum 0 -Maximum 15), 2)
            entry = (Get-Date).AddDays(-($i % 30)).ToString("yyyyMMddTHHmmssZ")
            due = if ($i % 7 -eq 0) { (Get-Date).AddDays($i % 14).ToString("yyyyMMddTHHmmssZ") } else { $null }
            depends = if ($i % 15 -eq 0 -and $i -gt 1) { @($i - 1) } else { @() }
            annotations = if ($i % 10 -eq 0) { @(@{entry=(Get-Date).ToString(); description="Test annotation"}) } else { @() }
        }
    }
}

Describe "Filter Engine Core" {
    Context "Basic Filter Engine" {
        It "Should create filter engine instance" {
            $eventPublisher = [EventPublisher]::new()
            $filterEngine = [FilterEngine]::new($eventPublisher)
            
            $filterEngine | Should -Not -BeNullOrEmpty
            $filterEngine.GetType().Name | Should -Be "FilterEngine"
        }
        
        It "Should set data source" {
            $eventPublisher = [EventPublisher]::new()
            $filterEngine = [FilterEngine]::new($eventPublisher)
            $dataSource = [VirtualDataSource]::new($Global:FilterTestTasks)
            
            $filterEngine.SetDataSource($dataSource)
            $filterEngine.GetTotalItemCount() | Should -Be 500
        }
        
        It "Should return all items when no filters applied" {
            $eventPublisher = [EventPublisher]::new()
            $filterEngine = [FilterEngine]::new($eventPublisher)
            $dataSource = [VirtualDataSource]::new($Global:FilterTestTasks)
            $filterEngine.SetDataSource($dataSource)
            
            $results = $filterEngine.GetFilteredResults()
            $results.Count | Should -Be 500
        }
    }
    
    Context "Basic Filtering" {
        It "Should filter by status" {
            $eventPublisher = [EventPublisher]::new()
            $filterEngine = [FilterEngine]::new($eventPublisher)
            $dataSource = [VirtualDataSource]::new($Global:FilterTestTasks)
            $filterEngine.SetDataSource($dataSource)
            
            # Add status filter
            $statusFilter = [StatusFilter]::new("pending")
            $filterEngine.AddFilter($statusFilter)
            
            $results = $filterEngine.GetFilteredResults()
            $results.Count | Should -Be 125  # 500 / 4 statuses = 125 pending
            
            foreach ($task in $results) {
                $task.status | Should -Be "pending"
            }
        }
        
        It "Should filter by project" {
            $eventPublisher = [EventPublisher]::new()
            $filterEngine = [FilterEngine]::new($eventPublisher)
            $dataSource = [VirtualDataSource]::new($Global:FilterTestTasks)
            $filterEngine.SetDataSource($dataSource)
            
            # Add project filter
            $projectFilter = [ProjectFilter]::new("work")
            $filterEngine.AddFilter($projectFilter)
            
            $results = $filterEngine.GetFilteredResults()
            $results.Count | Should -Be 125  # 500 / 4 projects = 125 work tasks
            
            foreach ($task in $results) {
                $task.project | Should -Be "work"
            }
        }
        
        It "Should filter by priority" {
            $eventPublisher = [EventPublisher]::new()
            $filterEngine = [FilterEngine]::new($eventPublisher)
            $dataSource = [VirtualDataSource]::new($Global:FilterTestTasks)
            $filterEngine.SetDataSource($dataSource)
            
            # Add priority filter
            $priorityFilter = [PriorityFilter]::new("H")
            $filterEngine.AddFilter($priorityFilter)
            
            $results = $filterEngine.GetFilteredResults()
            $results.Count | Should -Be 125  # 500 / 4 priorities = 125 high priority
            
            foreach ($task in $results) {
                $task.priority | Should -Be "H"
            }
        }
        
        It "Should filter by tags" {
            $eventPublisher = [EventPublisher]::new()
            $filterEngine = [FilterEngine]::new($eventPublisher)
            $dataSource = [VirtualDataSource]::new($Global:FilterTestTasks)
            $filterEngine.SetDataSource($dataSource)
            
            # Add tag filter
            $tagFilter = [TagFilter]::new("urgent")
            $filterEngine.AddFilter($tagFilter)
            
            $results = $filterEngine.GetFilteredResults()
            $results.Count | Should -BeGreaterThan 0
            
            foreach ($task in $results) {
                $task.tags | Should -Contain "urgent"
            }
        }
    }
    
    Context "Advanced Filtering" {
        It "Should support multiple filters (AND logic)" {
            $eventPublisher = [EventPublisher]::new()
            $filterEngine = [FilterEngine]::new($eventPublisher)
            $dataSource = [VirtualDataSource]::new($Global:FilterTestTasks)
            $filterEngine.SetDataSource($dataSource)
            
            # Add multiple filters
            $statusFilter = [StatusFilter]::new("pending")
            $projectFilter = [ProjectFilter]::new("work")
            $filterEngine.AddFilter($statusFilter)
            $filterEngine.AddFilter($projectFilter)
            
            $results = $filterEngine.GetFilteredResults()
            
            foreach ($task in $results) {
                $task.status | Should -Be "pending"
                $task.project | Should -Be "work"
            }
        }
        
        It "Should filter by urgency range" {
            $eventPublisher = [EventPublisher]::new()
            $filterEngine = [FilterEngine]::new($eventPublisher)
            $dataSource = [VirtualDataSource]::new($Global:FilterTestTasks)
            $filterEngine.SetDataSource($dataSource)
            
            # Filter for high urgency tasks (> 10)
            $urgencyFilter = [UrgencyFilter]::new(10, 15)  # Min 10, Max 15
            $filterEngine.AddFilter($urgencyFilter)
            
            $results = $filterEngine.GetFilteredResults()
            
            foreach ($task in $results) {
                $task.urgency | Should -BeGreaterOrEqual 10
                $task.urgency | Should -BeLessOrEqual 15
            }
        }
        
        It "Should filter by date ranges" {
            $eventPublisher = [EventPublisher]::new()
            $filterEngine = [FilterEngine]::new($eventPublisher)
            $dataSource = [VirtualDataSource]::new($Global:FilterTestTasks)
            $filterEngine.SetDataSource($dataSource)
            
            # Filter for tasks due in next 7 days
            $dateFilter = [DueDateFilter]::new((Get-Date), (Get-Date).AddDays(7))
            $filterEngine.AddFilter($dateFilter)
            
            $results = $filterEngine.GetFilteredResults()
            $results.Count | Should -BeGreaterThan 0
            
            foreach ($task in $results) {
                $task.due | Should -Not -BeNullOrEmpty
                $dueDate = [DateTime]::ParseExact($task.due.Substring(0,8), "yyyyMMdd", $null)
                $dueDate | Should -BeLessOrEqual (Get-Date).AddDays(7)
                $dueDate | Should -BeGreaterOrEqual (Get-Date).Date
            }
        }
        
        It "Should support text search in descriptions" {
            $eventPublisher = [EventPublisher]::new()
            $filterEngine = [FilterEngine]::new($eventPublisher)
            $dataSource = [VirtualDataSource]::new($Global:FilterTestTasks)
            $filterEngine.SetDataSource($dataSource)
            
            # Search for tasks containing "comprehensive"
            $textFilter = [TextSearchFilter]::new("comprehensive")
            $filterEngine.AddFilter($textFilter)
            
            $results = $filterEngine.GetFilteredResults()
            $results.Count | Should -Be 500  # All our test tasks contain "comprehensive"
            
            foreach ($task in $results) {
                $task.description | Should -Match "comprehensive"
            }
        }
    }
    
    Context "Filter Combinations" {
        It "Should support OR logic between filters" {
            $eventPublisher = [EventPublisher]::new()
            $filterEngine = [FilterEngine]::new($eventPublisher)
            $dataSource = [VirtualDataSource]::new($Global:FilterTestTasks)
            $filterEngine.SetDataSource($dataSource)
            
            # Create OR filter group
            $orGroup = [FilterGroup]::new("OR")
            $orGroup.AddFilter([StatusFilter]::new("pending"))
            $orGroup.AddFilter([StatusFilter]::new("waiting"))
            $filterEngine.AddFilter($orGroup)
            
            $results = $filterEngine.GetFilteredResults()
            $results.Count | Should -Be 250  # 125 pending + 125 waiting
            
            foreach ($task in $results) {
                @("pending", "waiting") | Should -Contain $task.status
            }
        }
        
        It "Should support nested filter groups" {
            $eventPublisher = [EventPublisher]::new()
            $filterEngine = [FilterEngine]::new($eventPublisher)
            $dataSource = [VirtualDataSource]::new($Global:FilterTestTasks)
            $filterEngine.SetDataSource($dataSource)
            
            # Create nested filter: (pending OR waiting) AND work
            $statusOrGroup = [FilterGroup]::new("OR")
            $statusOrGroup.AddFilter([StatusFilter]::new("pending"))
            $statusOrGroup.AddFilter([StatusFilter]::new("waiting"))
            
            $mainAndGroup = [FilterGroup]::new("AND")
            $mainAndGroup.AddFilter($statusOrGroup)
            $mainAndGroup.AddFilter([ProjectFilter]::new("work"))
            
            $filterEngine.AddFilter($mainAndGroup)
            
            $results = $filterEngine.GetFilteredResults()
            
            foreach ($task in $results) {
                @("pending", "waiting") | Should -Contain $task.status
                $task.project | Should -Be "work"
            }
        }
    }
    
    Context "Sorting" {
        It "Should sort by urgency descending" {
            $eventPublisher = [EventPublisher]::new()
            $filterEngine = [FilterEngine]::new($eventPublisher)
            $dataSource = [VirtualDataSource]::new($Global:FilterTestTasks)
            $filterEngine.SetDataSource($dataSource)
            
            $sorter = [UrgencySorter]::new($true)  # Descending
            $filterEngine.SetSorter($sorter)
            
            $results = $filterEngine.GetFilteredResults()
            
            # Check that results are sorted by urgency descending
            for ($i = 1; $i -lt $results.Count; $i++) {
                $results[$i-1].urgency | Should -BeGreaterOrEqual $results[$i].urgency
            }
        }
        
        It "Should sort by due date ascending" {
            $eventPublisher = [EventPublisher]::new()
            $filterEngine = [FilterEngine]::new($eventPublisher)
            $dataSource = [VirtualDataSource]::new($Global:FilterTestTasks)
            $filterEngine.SetDataSource($dataSource)
            
            # Filter to tasks with due dates first
            $dueDateFilter = [HasDueDateFilter]::new()
            $filterEngine.AddFilter($dueDateFilter)
            
            $sorter = [DueDateSorter]::new($false)  # Ascending
            $filterEngine.SetSorter($sorter)
            
            $results = $filterEngine.GetFilteredResults()
            $results.Count | Should -BeGreaterThan 0
            
            # Check that results are sorted by due date ascending
            for ($i = 1; $i -lt $results.Count; $i++) {
                $prevDate = [DateTime]::ParseExact($results[$i-1].due.Substring(0,8), "yyyyMMdd", $null)
                $currDate = [DateTime]::ParseExact($results[$i].due.Substring(0,8), "yyyyMMdd", $null)
                $prevDate | Should -BeLessOrEqual $currDate
            }
        }
        
        It "Should sort by project alphabetically" {
            $eventPublisher = [EventPublisher]::new()
            $filterEngine = [FilterEngine]::new($eventPublisher)
            $dataSource = [VirtualDataSource]::new($Global:FilterTestTasks)
            $filterEngine.SetDataSource($dataSource)
            
            # Filter to tasks with projects
            $projectFilter = [HasProjectFilter]::new()
            $filterEngine.AddFilter($projectFilter)
            
            $sorter = [ProjectSorter]::new($false)  # Ascending
            $filterEngine.SetSorter($sorter)
            
            $results = $filterEngine.GetFilteredResults()
            
            # Check that results are sorted by project alphabetically
            for ($i = 1; $i -lt $results.Count; $i++) {
                $results[$i-1].project | Should -BeLessOrEqual $results[$i].project
            }
        }
    }
    
    Context "Performance Requirements" {
        It "Should filter large datasets efficiently" {
            $eventPublisher = [EventPublisher]::new()
            $filterEngine = [FilterEngine]::new($eventPublisher)
            $dataSource = [VirtualDataSource]::new($Global:FilterTestTasks)
            $filterEngine.SetDataSource($dataSource)
            
            # Add multiple complex filters
            $statusFilter = [StatusFilter]::new("pending")
            $urgencyFilter = [UrgencyFilter]::new(5, 15)
            $textFilter = [TextSearchFilter]::new("test")
            
            $filterEngine.AddFilter($statusFilter)
            $filterEngine.AddFilter($urgencyFilter)
            $filterEngine.AddFilter($textFilter)
            
            $filterTime = Measure-Command {
                $results = $filterEngine.GetFilteredResults()
            }
            
            $filterTime.TotalMilliseconds | Should -BeLessThan 150  # Should filter in under 150ms
        }
        
        It "Should maintain filter performance across multiple operations" {
            $eventPublisher = [EventPublisher]::new()
            $filterEngine = [FilterEngine]::new($eventPublisher)
            $dataSource = [VirtualDataSource]::new($Global:FilterTestTasks)
            $filterEngine.SetDataSource($dataSource)
            
            $times = @()
            
            # Test multiple filter operations
            for ($i = 0; $i -lt 10; $i++) {
                $filterEngine.ClearFilters()
                
                # Add different filter combinations each time
                $statusFilter = [StatusFilter]::new(@("pending", "waiting", "completed")[$i % 3])
                $filterEngine.AddFilter($statusFilter)
                
                $filterTime = Measure-Command {
                    $null = $filterEngine.GetFilteredResults()
                }
                
                $times += $filterTime.TotalMilliseconds
            }
            
            $avgTime = ($times | Measure-Object -Average).Average
            $maxTime = ($times | Measure-Object -Maximum).Maximum
            
            $avgTime | Should -BeLessThan 150   # Average under 150ms
            $maxTime | Should -BeLessThan 200  # Max under 200ms
        }
    }
    
    Context "Caching Integration" {
        It "Should cache filter results" {
            $eventPublisher = [EventPublisher]::new()
            $cache = [TaskCacheManager]::new($eventPublisher)
            $filterEngine = [FilterEngine]::new($eventPublisher, $cache)
            $dataSource = [VirtualDataSource]::new($Global:FilterTestTasks)
            $filterEngine.SetDataSource($dataSource)
            
            $statusFilter = [StatusFilter]::new("pending")
            $filterEngine.AddFilter($statusFilter)
            
            # First call should populate cache
            $results1 = $filterEngine.GetFilteredResults()
            
            # Second call should hit cache
            $results2 = $filterEngine.GetFilteredResults()
            
            $results1.Count | Should -Be $results2.Count
            
            # Verify cache was used
            $stats = $cache.GetCacheStatistics()
            $stats.Hits | Should -BeGreaterThan 0
        }
        
        It "Should invalidate cache when filters change" {
            $eventPublisher = [EventPublisher]::new()
            $cache = [TaskCacheManager]::new($eventPublisher)
            $filterEngine = [FilterEngine]::new($eventPublisher, $cache)
            $dataSource = [VirtualDataSource]::new($Global:FilterTestTasks)
            $filterEngine.SetDataSource($dataSource)
            
            # Initial filter and results
            $statusFilter = [StatusFilter]::new("pending")
            $filterEngine.AddFilter($statusFilter)
            $results1 = $filterEngine.GetFilteredResults()
            
            # Change filter
            $filterEngine.ClearFilters()
            $statusFilter2 = [StatusFilter]::new("completed")
            $filterEngine.AddFilter($statusFilter2)
            $results2 = $filterEngine.GetFilteredResults()
            
            # Results should be different (even if counts are same, content is different)
            $results1.Count | Should -Be 125
            $results2.Count | Should -Be 125
            
            # But the actual tasks should be different
            $firstTaskId1 = $results1[0].id
            $firstTaskId2 = $results2[0].id
            $firstTaskId1 | Should -Not -Be $firstTaskId2
        }
    }
    
    Context "Event Publishing" {
        It "Should publish filter change events" {
            $eventPublisher = [EventPublisher]::new()
            $filterEngine = [FilterEngine]::new($eventPublisher)
            $dataSource = [VirtualDataSource]::new($Global:FilterTestTasks)
            $filterEngine.SetDataSource($dataSource)
            
            $Global:filterEventReceived = $false
            $Global:filterEventData = $null
            
            $eventPublisher.Subscribe('FiltersChanged', {
                param($eventData)
                $Global:filterEventReceived = $true
                $Global:filterEventData = $eventData
            })
            
            $statusFilter = [StatusFilter]::new("pending")
            $filterEngine.AddFilter($statusFilter)
            
            $Global:filterEventReceived | Should -Be $true
            $Global:filterEventData.FilterCount | Should -Be 1
        }
        
        It "Should publish result change events" {
            $eventPublisher = [EventPublisher]::new()
            $filterEngine = [FilterEngine]::new($eventPublisher)
            $dataSource = [VirtualDataSource]::new($Global:FilterTestTasks)
            $filterEngine.SetDataSource($dataSource)
            
            $Global:resultEventReceived = $false
            $Global:resultEventData = $null
            
            $eventPublisher.Subscribe('FilterResultsChanged', {
                param($eventData)
                $Global:resultEventReceived = $true
                $Global:resultEventData = $eventData
            })
            
            $statusFilter = [StatusFilter]::new("pending")
            $filterEngine.AddFilter($statusFilter)
            $null = $filterEngine.GetFilteredResults()  # Trigger filtering
            
            $Global:resultEventReceived | Should -Be $true
            $Global:resultEventData.ResultCount | Should -BeGreaterThan 0
        }
    }
}

Describe "TaskWarrior Query Language" {
    Context "Query Parser" {
        It "Should parse simple TaskWarrior queries" {
            $parser = [TaskWarriorQueryParser]::new()
            
            # Test basic status query
            $filters = $parser.ParseQuery("status:pending")
            $filters.Count | Should -Be 1
            $filters[0].GetType().Name | Should -Be "StatusFilter"
        }
        
        It "Should parse complex TaskWarrior queries" {
            $parser = [TaskWarriorQueryParser]::new()
            
            # Test complex query: project:work status:pending priority:H +urgent
            $filters = $parser.ParseQuery("project:work status:pending priority:H +urgent")
            $filters.Count | Should -Be 4
            
            # Should have project, status, priority, and tag filters
            $filterTypes = $filters | ForEach-Object { $_.GetType().Name } | Sort-Object
            $expectedTypes = @("ProjectFilter", "StatusFilter", "PriorityFilter", "TagFilter") | Sort-Object
            
            for ($i = 0; $i -lt $filterTypes.Count; $i++) {
                $filterTypes[$i] | Should -Be $expectedTypes[$i]
            }
        }
        
        It "Should handle TaskWarrior date expressions" {
            $parser = [TaskWarriorQueryParser]::new()
            
            # Test relative dates: due:today, due:tomorrow, due:eow (end of week)
            $filters1 = $parser.ParseQuery("due:today")
            $filters1.Count | Should -Be 1
            $filters1[0].GetType().Name | Should -Be "DueDateFilter"
            
            $filters2 = $parser.ParseQuery("due:tomorrow")
            $filters2.Count | Should -Be 1
            
            $filters3 = $parser.ParseQuery("due:eow")
            $filters3.Count | Should -Be 1
        }
        
        It "Should support urgency operators" {
            $parser = [TaskWarriorQueryParser]::new()
            
            # Test urgency comparisons: urgency.gt:5, urgency.lt:10
            $filters1 = $parser.ParseQuery("urgency.gt:5")
            $filters1.Count | Should -Be 1
            $filters1[0].GetType().Name | Should -Be "UrgencyFilter"
            
            $filters2 = $parser.ParseQuery("urgency.lt:10")
            $filters2.Count | Should -Be 1
        }
    }
    
    Context "Query Integration" {
        It "Should apply parsed queries to filter engine" {
            $eventPublisher = [EventPublisher]::new()
            $filterEngine = [FilterEngine]::new($eventPublisher)
            $dataSource = [VirtualDataSource]::new($Global:FilterTestTasks)
            $filterEngine.SetDataSource($dataSource)
            
            # Apply TaskWarrior query
            $filterEngine.ApplyQuery("status:pending project:work")
            
            $results = $filterEngine.GetFilteredResults()
            
            foreach ($task in $results) {
                $task.status | Should -Be "pending"
                $task.project | Should -Be "work"
            }
        }
        
        It "Should handle invalid queries gracefully" {
            $eventPublisher = [EventPublisher]::new()
            $filterEngine = [FilterEngine]::new($eventPublisher)
            $dataSource = [VirtualDataSource]::new($Global:FilterTestTasks)
            $filterEngine.SetDataSource($dataSource)
            
            # Apply invalid query
            { $filterEngine.ApplyQuery("invalid:badquery nonsense:value") } | Should -Not -Throw
            
            # Should return all results when query is invalid
            $results = $filterEngine.GetFilteredResults()
            $results.Count | Should -Be 500
        }
    }
}