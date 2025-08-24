# Phase 3: Virtual Scrolling Tests
# Efficient rendering of large datasets using virtual scrolling

BeforeAll {
    # Import required classes
    try {
        . "$PSScriptRoot/../Core/RenderEngine.ps1"
        . "$PSScriptRoot/../Core/EventSystem.ps1"
        . "$PSScriptRoot/../Core/ConfigurationProvider.ps1"
        . "$PSScriptRoot/../Core/TaskDataProvider.ps1"
        . "$PSScriptRoot/../Core/CachingSystem.ps1"
        . "$PSScriptRoot/../Core/VirtualScrolling.ps1"
    } catch {
        Write-Warning "Core classes not yet implemented: $_"
    }
    
    # Create mock task data for virtual scrolling tests
    $Global:VirtualScrollingMockTasks = @()
    for ($i = 1; $i -le 10000; $i++) {
        $Global:VirtualScrollingMockTasks += @{
            uuid = "12345678-1234-1234-1234-$('{0:D12}' -f $i)"
            id = $i
            description = "Virtual scrolling test task $i with some content to make it realistic"
            status = if ($i % 3 -eq 0) { 'completed' } elseif ($i % 7 -eq 0) { 'waiting' } else { 'pending' }
            urgency = [math]::Round((Get-Random -Maximum 10), 2)
            project = if ($i % 5 -eq 0) { "project$($i % 10)" } else { $null }
            tags = if ($i % 4 -eq 0) { @("tag$($i % 3)", "virtual") } else { @() }
        }
    }
}

Describe "Virtual Scrolling Engine" {
    Context "Basic Virtual Scrolling" {
        It "Should create virtual scrolling viewport" {
            $viewport = [VirtualScrollingViewport]::new(80, 24)  # 80 cols, 24 rows
            
            $viewport | Should -Not -BeNullOrEmpty
            $viewport.GetType().Name | Should -Be "VirtualScrollingViewport"
            $viewport.Width | Should -Be 80
            $viewport.Height | Should -Be 24
        }
        
        It "Should set data source for scrolling" {
            $viewport = [VirtualScrollingViewport]::new(80, 24)
            $dataSource = [VirtualDataSource]::new($Global:VirtualScrollingMockTasks)
            
            $viewport.SetDataSource($dataSource)
            $viewport.GetTotalItemCount() | Should -Be 10000
        }
        
        It "Should render visible items only" {
            $viewport = [VirtualScrollingViewport]::new(80, 24)
            $dataSource = [VirtualDataSource]::new($Global:VirtualScrollingMockTasks)
            $viewport.SetDataSource($dataSource)
            
            # Should only render items that fit in viewport
            $visibleItems = $viewport.GetVisibleItems()
            $visibleItems.Count | Should -BeLessOrEqual 24  # Can't exceed viewport height
            $visibleItems.Count | Should -BeGreaterThan 0   # Should have some items
        }
        
        It "Should handle scroll position changes" {
            $viewport = [VirtualScrollingViewport]::new(80, 24)
            $dataSource = [VirtualDataSource]::new($Global:VirtualScrollingMockTasks)
            $viewport.SetDataSource($dataSource)
            
            # Initial position
            $viewport.GetScrollPosition() | Should -Be 0
            
            # Scroll down
            $viewport.ScrollTo(100)
            $viewport.GetScrollPosition() | Should -Be 100
            
            # Get visible items at new position
            $visibleItems = $viewport.GetVisibleItems()
            $visibleItems[0].id | Should -BeGreaterThan 100  # Should show items from scroll position
        }
        
        It "Should handle scroll boundaries correctly" {
            $viewport = [VirtualScrollingViewport]::new(80, 24)
            $dataSource = [VirtualDataSource]::new($Global:VirtualScrollingMockTasks)
            $viewport.SetDataSource($dataSource)
            
            # Try to scroll beyond start
            $viewport.ScrollTo(-10)
            $viewport.GetScrollPosition() | Should -Be 0  # Should clamp to 0
            
            # Try to scroll beyond end
            $viewport.ScrollTo(20000)
            $maxScroll = $viewport.GetMaxScrollPosition()
            $viewport.GetScrollPosition() | Should -Be $maxScroll  # Should clamp to max
        }
        
        It "Should support relative scrolling" {
            $viewport = [VirtualScrollingViewport]::new(80, 24)
            $dataSource = [VirtualDataSource]::new($Global:VirtualScrollingMockTasks)
            $viewport.SetDataSource($dataSource)
            
            $initialPos = 50
            $viewport.ScrollTo($initialPos)
            
            # Scroll down by 10 items
            $viewport.ScrollBy(10)
            $viewport.GetScrollPosition() | Should -Be ($initialPos + 10)
            
            # Scroll up by 5 items
            $viewport.ScrollBy(-5)
            $viewport.GetScrollPosition() | Should -Be ($initialPos + 5)
        }
    }
    
    Context "Virtual Data Source" {
        It "Should create data source from array" {
            $dataSource = [VirtualDataSource]::new($Global:VirtualScrollingMockTasks)
            
            $dataSource.GetTotalCount() | Should -Be 10000
            $dataSource.GetItem(0).id | Should -Be 1
            $dataSource.GetItem(999).id | Should -Be 1000
        }
        
        It "Should support range queries efficiently" {
            $dataSource = [VirtualDataSource]::new($Global:VirtualScrollingMockTasks)
            
            $loadTime = Measure-Command {
                $range = $dataSource.GetRange(100, 50)  # Get 50 items starting from index 100
            }
            
            $loadTime.TotalMilliseconds | Should -BeLessThan 50  # Should be very fast
            $range.Count | Should -Be 50
            $range[0].id | Should -Be 101  # First item should be item 101
            $range[49].id | Should -Be 150  # Last item should be item 150
        }
        
        It "Should handle out-of-bounds range queries" {
            $dataSource = [VirtualDataSource]::new($Global:VirtualScrollingMockTasks)
            
            # Request range beyond data
            $range = $dataSource.GetRange(9990, 50)
            $range.Count | Should -Be 10  # Should only return remaining 10 items
            $range[0].id | Should -Be 9991
        }
        
        It "Should support filtering without loading all data" {
            $dataSource = [VirtualDataSource]::new($Global:VirtualScrollingMockTasks)
            
            # Filter for completed tasks only
            $dataSource.SetFilter({ param($item) $item.status -eq 'completed' })
            
            $filteredCount = $dataSource.GetFilteredCount()
            $filteredCount | Should -BeGreaterThan 0
            $filteredCount | Should -BeLessThan 10000  # Should be subset
            
            # Get filtered range
            $range = $dataSource.GetRange(0, 10)
            foreach ($item in $range) {
                $item.status | Should -Be 'completed'
            }
        }
    }
    
    Context "Rendering Integration" {
        It "Should integrate with render engine" {
            $renderEngine = [RenderEngine]::new()
            $buffer = $renderEngine.CreateBuffer(80, 24)
            $viewport = [VirtualScrollingViewport]::new(80, 24)
            $dataSource = [VirtualDataSource]::new($Global:VirtualScrollingMockTasks)
            $viewport.SetDataSource($dataSource)
            
            # Create task renderer
            $taskRenderer = [TaskRenderer]::new()
            $viewport.SetItemRenderer($taskRenderer)
            
            # Render viewport to buffer
            $viewport.RenderToBuffer($buffer)
            
            # Should have content in buffer
            $firstLine = $buffer.GetLine(0)
            $firstLine | Should -Not -BeNullOrEmpty
            $firstLine | Should -Match "Virtual scrolling test task"  # Should contain task description
        }
        
        It "Should handle dynamic content height" {
            $renderEngine = [RenderEngine]::new()
            $buffer = $renderEngine.CreateBuffer(80, 24)
            $viewport = [VirtualScrollingViewport]::new(80, 24)
            
            # Create tasks with varying content lengths
            $variableHeightTasks = @()
            for ($i = 1; $i -le 100; $i++) {
                $description = if ($i % 5 -eq 0) {
                    "Very long task description that spans multiple lines and requires text wrapping to display properly in the terminal interface"
                } else {
                    "Short task $i"
                }
                $variableHeightTasks += @{
                    id = $i
                    description = $description
                    status = 'pending'
                }
            }
            
            $dataSource = [VirtualDataSource]::new($variableHeightTasks)
            $viewport.SetDataSource($dataSource)
            $taskRenderer = [TaskRenderer]::new()
            $viewport.SetItemRenderer($taskRenderer)
            
            # Should handle variable heights correctly
            $viewport.RenderToBuffer($buffer)
            
            # Verify content fits in viewport
            $usedLines = 0
            for ($i = 0; $i -lt 24; $i++) {
                $line = $buffer.GetLine($i)
                if ($line -and $line.Trim()) {
                    $usedLines++
                }
            }
            
            $usedLines | Should -BeGreaterThan 0
            $usedLines | Should -BeLessOrEqual 24
        }
    }
    
    Context "Performance Requirements" {
        It "Should handle large datasets efficiently" {
            $viewport = [VirtualScrollingViewport]::new(80, 24)
            $dataSource = [VirtualDataSource]::new($Global:VirtualScrollingMockTasks)
            $viewport.SetDataSource($dataSource)
            
            # Test performance of scrolling through large dataset
            $scrollTime = Measure-Command {
                for ($i = 0; $i -lt 100; $i++) {
                    $viewport.ScrollTo($i * 100)
                    $null = $viewport.GetVisibleItems()
                }
            }
            
            $scrollTime.TotalMilliseconds | Should -BeLessThan 1000  # Should complete in under 1 second
        }
        
        It "Should maintain consistent frame rates during scrolling" {
            $viewport = [VirtualScrollingViewport]::new(80, 24)
            $dataSource = [VirtualDataSource]::new($Global:VirtualScrollingMockTasks)
            $viewport.SetDataSource($dataSource)
            $taskRenderer = [TaskRenderer]::new()
            $viewport.SetItemRenderer($taskRenderer)
            
            $renderEngine = [RenderEngine]::new()
            $buffer = $renderEngine.CreateBuffer(80, 24)
            
            # Measure rendering performance across multiple scroll positions
            $renderTimes = @()
            for ($i = 0; $i -lt 10; $i++) {
                $viewport.ScrollTo($i * 500)
                
                $renderTime = Measure-Command {
                    $viewport.RenderToBuffer($buffer)
                }
                
                $renderTimes += $renderTime.TotalMilliseconds
            }
            
            # All renders should be reasonably fast
            $maxRenderTime = ($renderTimes | Measure-Object -Maximum).Maximum
            $avgRenderTime = ($renderTimes | Measure-Object -Average).Average
            
            $maxRenderTime | Should -BeLessThan 100   # No single render > 100ms
            $avgRenderTime | Should -BeLessThan 50    # Average < 50ms
        }
        
        It "Should use minimal memory for viewport rendering" {
            $viewport = [VirtualScrollingViewport]::new(80, 24)
            $dataSource = [VirtualDataSource]::new($Global:VirtualScrollingMockTasks)
            $viewport.SetDataSource($dataSource)
            
            $initialMemory = [GC]::GetTotalMemory($false)
            
            # Scroll through dataset multiple times
            for ($i = 0; $i -lt 50; $i++) {
                $viewport.ScrollTo((Get-Random -Maximum 9000))
                $null = $viewport.GetVisibleItems()
            }
            
            [GC]::Collect()
            [GC]::WaitForPendingFinalizers()
            [GC]::Collect()
            
            $finalMemory = [GC]::GetTotalMemory($false)
            $memoryIncrease = $finalMemory - $initialMemory
            
            # Should not significantly increase memory usage
            $memoryIncrease | Should -BeLessThan (2 * 1024 * 1024)  # Less than 2MB increase
        }
    }
    
    Context "Event System Integration" {
        It "Should publish scroll events" {
            $eventPublisher = [EventPublisher]::new()
            $viewport = [VirtualScrollingViewport]::new(80, 24, $eventPublisher)
            $dataSource = [VirtualDataSource]::new($Global:VirtualScrollingMockTasks)
            $viewport.SetDataSource($dataSource)
            
            $Global:scrollEventReceived = $false
            $Global:scrollEventData = $null
            
            $eventPublisher.Subscribe('ViewportScrolled', {
                param($eventData)
                $Global:scrollEventReceived = $true
                $Global:scrollEventData = $eventData
            })
            
            $viewport.ScrollTo(100)
            
            $Global:scrollEventReceived | Should -Be $true
            $Global:scrollEventData.ScrollPosition | Should -Be 100
        }
        
        It "Should publish item visibility events" {
            $eventPublisher = [EventPublisher]::new()
            $viewport = [VirtualScrollingViewport]::new(80, 24, $eventPublisher)
            $dataSource = [VirtualDataSource]::new($Global:VirtualScrollingMockTasks)
            $viewport.SetDataSource($dataSource)
            
            $Global:visibilityEvents = @()
            
            $eventPublisher.Subscribe('ItemVisibilityChanged', {
                param($eventData)
                $Global:visibilityEvents += $eventData
            })
            
            # Scroll to make new items visible
            $viewport.ScrollTo(50)
            $viewport.ScrollTo(100)
            
            $Global:visibilityEvents.Count | Should -BeGreaterThan 0
        }
    }
}

Describe "Task Item Renderer" {
    Context "Task Formatting" {
        It "Should create task renderer" {
            $renderer = [TaskRenderer]::new()
            
            $renderer | Should -Not -BeNullOrEmpty
            $renderer.GetType().Name | Should -Be "TaskRenderer"
        }
        
        It "Should format task items for display" {
            $renderer = [TaskRenderer]::new()
            $task = @{
                id = 1
                description = "Test task"
                status = 'pending'
                urgency = 5.0
                project = 'testproject'
                tags = @('work', 'urgent')
            }
            
            $formatted = $renderer.FormatItem($task, 80)  # 80 character width
            
            $formatted | Should -Not -BeNullOrEmpty
            $formatted | Should -Match "Test task"
            $formatted | Should -Match "pending"
        }
        
        It "Should handle text wrapping for long descriptions" {
            $renderer = [TaskRenderer]::new()
            $task = @{
                id = 1
                description = "This is a very long task description that should wrap to multiple lines when displayed in a narrow terminal window"
                status = 'pending'
                urgency = 2.0
            }
            
            $lines = @($renderer.FormatItem($task, 20))  # Very narrow width to force wrapping, ensure array
            
            
            # Should return multiple lines for wrapped text
            # The result should be either an array or at least contain wrapped content
            if ($lines -is [array]) {
                $lines.Count | Should -BeGreaterThan 1
            } else {
                # Even if PowerShell flattens the array, verify it's formatted content
                $lines | Should -Not -BeNullOrEmpty
                $lines | Should -Match "pending"
            }
            
            # First line should contain start of description
            $firstLine = if ($lines -is [array]) { $lines[0] } else { $lines }
            $firstLine | Should -Match "This is a v"  # Shorter match for truncated text
        }
        
        It "Should apply color coding based on task properties" {
            $renderer = [TaskRenderer]::new()
            
            # High urgency task
            $urgentTask = @{
                id = 1
                description = "Urgent task"
                status = 'pending'
                urgency = 9.0
            }
            
            # Completed task
            $completedTask = @{
                id = 2
                description = "Done task"
                status = 'completed'
                urgency = 1.0
            }
            
            $urgentFormatted = $renderer.FormatItem($urgentTask, 80)
            $completedFormatted = $renderer.FormatItem($completedTask, 80)
            
            # Should contain different ANSI color codes
            $urgentLine = if ($urgentFormatted -is [array]) { $urgentFormatted[0] } else { $urgentFormatted }
            $completedLine = if ($completedFormatted -is [array]) { $completedFormatted[0] } else { $completedFormatted }
            
            $urgentLine | Should -Match "\x1b\["    # Should contain ANSI escape (ESC character)
            $completedLine | Should -Match "\x1b\[" # Should contain ANSI escape (ESC character)
            
            # Color codes should be different for different priorities/status
            $urgentLine | Should -Not -Be $completedLine
        }
    }
    
    Context "Performance" {
        It "Should format items efficiently" {
            $renderer = [TaskRenderer]::new()
            $testTasks = $Global:VirtualScrollingMockTasks[0..99]  # First 100 tasks
            
            $formatTime = Measure-Command {
                foreach ($task in $testTasks) {
                    $null = $renderer.FormatItem($task, 80)
                }
            }
            
            $formatTime.TotalMilliseconds | Should -BeLessThan 500  # Should format 100 tasks in under 500ms
        }
    }
}