# Phase 7: Performance & Threading Tests
# Background processing, multi-threading, and performance optimization

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
        . "$PSScriptRoot/../Core/UIComponents.ps1"
        . "$PSScriptRoot/../Core/AdvancedFeatures.ps1"
        . "$PSScriptRoot/../Core/PerformanceThreading.ps1"
    } catch {
        Write-Warning "Core classes not yet implemented: $_"
    }
    
    # Create large test dataset for performance testing
    $Global:LargeTaskSet = @()
    for ($i = 1; $i -le 10000; $i++) {
        $Global:LargeTaskSet += @{
            uuid = "12345678-1234-1234-1234-$('{0:D12}' -f $i)"
            id = $i
            description = "Performance test task $i with detailed description and multiple tags for comprehensive testing scenarios to ensure proper handling of realistic data volumes"
            status = @("pending", "completed", "waiting", "deleted")[($i - 1) % 4]
            project = @("work", "personal", "home", $null)[($i - 1) % 4]
            priority = @("H", "M", "L", $null)[($i - 1) % 4]
            tags = @(@("urgent", "important"), @("routine"), @("bug", "critical"), @())[($i - 1) % 4]
            urgency = [math]::Round((Get-Random -Minimum 0 -Maximum 20), 2)
            entry = (Get-Date).AddDays(-($i % 365)).ToString("yyyyMMddTHHmmssZ")
            due = if ($i % 5 -eq 0) { (Get-Date).AddDays($i % 30).ToString("yyyyMMddTHHmmssZ") } else { $null }
        }
    }
}

Describe "Background Processing" {
    Context "Asynchronous Operations" {
        It "Should create background processor instance" {
            $eventPublisher = [EventPublisher]::new()
            $backgroundProcessor = [BackgroundProcessor]::new($eventPublisher)
            
            $backgroundProcessor | Should -Not -BeNullOrEmpty
            $backgroundProcessor.GetType().Name | Should -Be "BackgroundProcessor"
        }
        
        It "Should queue background tasks" {
            $eventPublisher = [EventPublisher]::new()
            $backgroundProcessor = [BackgroundProcessor]::new($eventPublisher)
            
            $task = @{
                Name = "TestTask"
                Action = { Start-Sleep -Milliseconds 100; return "completed" }
                Priority = "Normal"
            }
            
            $taskId = $backgroundProcessor.QueueTask($task)
            $taskId | Should -Not -BeNullOrEmpty
            
            $queuedTasks = $backgroundProcessor.GetQueuedTasks()
            $queuedTasks.Count | Should -Be 1
        }
        
        It "Should execute background tasks asynchronously" {
            $eventPublisher = [EventPublisher]::new()
            $backgroundProcessor = [BackgroundProcessor]::new($eventPublisher)
            
            $Global:taskCompleted = $false
            $Global:taskResult = $null
            
            $eventPublisher.Subscribe('TaskCompleted', {
                param($eventData)
                $Global:taskCompleted = $true
                $Global:taskResult = $eventData.Result
            })
            
            $task = @{
                Name = "AsyncTest"
                Action = { return "success" }
                Priority = "High"
            }
            
            $taskId = $backgroundProcessor.QueueTask($task)
            $backgroundProcessor.StartProcessing()
            
            # Wait for completion
            $timeout = 0
            while (-not $Global:taskCompleted -and $timeout -lt 50) {
                Start-Sleep -Milliseconds 100
                $timeout++
            }
            
            $Global:taskCompleted | Should -Be $true
            $Global:taskResult | Should -Be "success"
        }
        
        It "Should handle task priorities" {
            $eventPublisher = [EventPublisher]::new()
            $backgroundProcessor = [BackgroundProcessor]::new($eventPublisher)
            
            $Global:executionOrder = @()
            
            $eventPublisher.Subscribe('TaskCompleted', {
                param($eventData)
                $Global:executionOrder += $eventData.TaskName
            })
            
            # Queue tasks in reverse priority order
            $backgroundProcessor.QueueTask(@{
                Name = "LowPriority"
                Action = { $Global:executionOrder += "Low"; return "low" }
                Priority = "Low"
            })
            
            $backgroundProcessor.QueueTask(@{
                Name = "HighPriority"
                Action = { $Global:executionOrder += "High"; return "high" }
                Priority = "High"
            })
            
            $backgroundProcessor.QueueTask(@{
                Name = "NormalPriority"
                Action = { $Global:executionOrder += "Normal"; return "normal" }
                Priority = "Normal"
            })
            
            $backgroundProcessor.StartProcessing()
            
            # Wait for all tasks to complete
            $timeout = 0
            while ($Global:executionOrder.Count -lt 6 -and $timeout -lt 100) {
                Start-Sleep -Milliseconds 50
                $timeout++
            }
            
            # High priority should execute first
            $Global:executionOrder[0] | Should -Be "High"
        }
        
        It "Should support task cancellation" {
            $eventPublisher = [EventPublisher]::new()
            $backgroundProcessor = [BackgroundProcessor]::new($eventPublisher)
            
            $task = @{
                Name = "CancellableTask"
                Action = { 
                    for ($i = 0; $i -lt 100; $i++) {
                        Start-Sleep -Milliseconds 10
                        # Check for cancellation token here in real implementation
                    }
                    return "completed"
                }
                Priority = "Normal"
            }
            
            $taskId = $backgroundProcessor.QueueTask($task)
            $backgroundProcessor.StartProcessing()
            
            # Cancel the task
            Start-Sleep -Milliseconds 50
            $result = $backgroundProcessor.CancelTask($taskId)
            $result.Success | Should -Be $true
        }
        
        It "Should limit concurrent tasks" {
            $eventPublisher = [EventPublisher]::new()
            $backgroundProcessor = [BackgroundProcessor]::new($eventPublisher, 2)  # Max 2 concurrent
            
            $Global:concurrentCount = 0
            $Global:maxConcurrent = 0
            
            $action = {
                $Global:concurrentCount++
                if ($Global:concurrentCount -gt $Global:maxConcurrent) {
                    $Global:maxConcurrent = $Global:concurrentCount
                }
                Start-Sleep -Milliseconds 200
                $Global:concurrentCount--
                return "done"
            }
            
            # Queue 5 tasks
            for ($i = 1; $i -le 5; $i++) {
                $backgroundProcessor.QueueTask(@{
                    Name = "Task$i"
                    Action = $action
                    Priority = "Normal"
                })
            }
            
            $backgroundProcessor.StartProcessing()
            Start-Sleep -Milliseconds 1000
            
            $Global:maxConcurrent | Should -BeLessOrEqual 2
        }
    }
    
    Context "Data Synchronization" {
        It "Should create data synchronizer instance" {
            $eventPublisher = [EventPublisher]::new()
            $config = @{ taskwarrior = @{ data_location = "/tmp/.task" } }
            $dataProvider = [TaskWarriorDataProvider]::new($config)
            $synchronizer = [DataSynchronizer]::new($eventPublisher, $dataProvider)
            
            $synchronizer | Should -Not -BeNullOrEmpty
            $synchronizer.GetType().Name | Should -Be "DataSynchronizer"
        }
        
        It "Should detect data changes" {
            $eventPublisher = [EventPublisher]::new()
            $config = @{ taskwarrior = @{ data_location = "/tmp/.task" } }
            $dataProvider = [TaskWarriorDataProvider]::new($config)
            $synchronizer = [DataSynchronizer]::new($eventPublisher, $dataProvider)
            
            $Global:changeDetected = $false
            $eventPublisher.Subscribe('DataChanged', {
                $Global:changeDetected = $true
            })
            
            # Simulate data change detection
            $synchronizer.CheckForChanges()
            
            # Would normally detect file system changes
            # For test, we'll trigger manually
            $synchronizer.NotifyDataChanged()
            
            $Global:changeDetected | Should -Be $true
        }
        
        It "Should sync data in background" {
            $eventPublisher = [EventPublisher]::new()
            $config = @{ taskwarrior = @{ data_location = "/tmp/.task" } }
            $dataProvider = [TaskWarriorDataProvider]::new($config)
            $synchronizer = [DataSynchronizer]::new($eventPublisher, $dataProvider)
            
            $Global:syncCompleted = $false
            $eventPublisher.Subscribe('SyncCompleted', {
                $Global:syncCompleted = $true
            })
            
            $synchronizer.StartBackgroundSync(1000)  # Sync every 1 second
            
            # Trigger immediate sync
            $synchronizer.SyncNow()
            
            # Wait for sync completion
            $timeout = 0
            while (-not $Global:syncCompleted -and $timeout -lt 50) {
                Start-Sleep -Milliseconds 100
                $timeout++
            }
            
            $Global:syncCompleted | Should -Be $true
        }
        
        It "Should handle sync conflicts" {
            $eventPublisher = [EventPublisher]::new()
            $config = @{ taskwarrior = @{ data_location = "/tmp/.task" } }
            $dataProvider = [TaskWarriorDataProvider]::new($config)
            $synchronizer = [DataSynchronizer]::new($eventPublisher, $dataProvider)
            
            $Global:conflictDetected = $false
            $eventPublisher.Subscribe('SyncConflict', {
                $Global:conflictDetected = $true
            })
            
            # Simulate conflict scenario
            $synchronizer.SimulateConflict()
            
            $Global:conflictDetected | Should -Be $true
        }
    }
}

Describe "Performance Monitoring" {
    Context "Metrics Collection" {
        It "Should create performance monitor instance" {
            $eventPublisher = [EventPublisher]::new()
            $perfMonitor = [PerformanceMonitor]::new($eventPublisher)
            
            $perfMonitor | Should -Not -BeNullOrEmpty
            $perfMonitor.GetType().Name | Should -Be "PerformanceMonitor"
        }
        
        It "Should track rendering performance" {
            $eventPublisher = [EventPublisher]::new()
            $perfMonitor = [PerformanceMonitor]::new($eventPublisher)
            $renderEngine = [RenderEngine]::new()
            
            $perfMonitor.StartTracking("RenderPerformance")
            
            # Simulate rendering work
            $buffer = $renderEngine.CreateBuffer(80, 24)
            for ($i = 0; $i -lt 100; $i++) {
                $buffer.SetLine($i % 24, "Test line $i")
            }
            
            $metrics = $perfMonitor.StopTracking("RenderPerformance")
            
            $metrics.ElapsedMilliseconds | Should -BeGreaterThan 0
            $metrics.ElapsedMilliseconds | Should -BeLessThan 1000
        }
        
        It "Should monitor memory usage" {
            $eventPublisher = [EventPublisher]::new()
            $perfMonitor = [PerformanceMonitor]::new($eventPublisher)
            
            $initialMemory = $perfMonitor.GetMemoryUsage()
            
            # Allocate some memory
            $largeArray = New-Object byte[] 1MB
            
            $currentMemory = $perfMonitor.GetMemoryUsage()
            
            $currentMemory.WorkingSet | Should -BeGreaterThan $initialMemory.WorkingSet
        }
        
        It "Should track frame rates" {
            $eventPublisher = [EventPublisher]::new()
            $perfMonitor = [PerformanceMonitor]::new($eventPublitor)
            
            # Simulate multiple frame renders
            for ($i = 0; $i -lt 60; $i++) {
                $perfMonitor.RecordFrame()
                Start-Sleep -Milliseconds 16  # ~60 FPS
            }
            
            $fps = $perfMonitor.GetAverageFrameRate()
            $fps | Should -BeGreaterThan 50
            $fps | Should -BeLessThan 70
        }
        
        It "Should detect performance bottlenecks" {
            $eventPublisher = [EventPublisher]::new()
            $perfMonitor = [PerformanceMonitor]::new($eventPublisher)
            
            $Global:bottleneckDetected = $false
            $eventPublisher.Subscribe('PerformanceBottleneck', {
                $Global:bottleneckDetected = $true
            })
            
            # Simulate slow operation
            $perfMonitor.StartTracking("SlowOperation")
            Start-Sleep -Milliseconds 200  # Simulate slow operation
            $perfMonitor.StopTracking("SlowOperation")
            
            $perfMonitor.AnalyzePerformance()
            
            $Global:bottleneckDetected | Should -Be $true
        }
    }
    
    Context "Resource Management" {
        It "Should create resource manager instance" {
            $eventPublisher = [EventPublisher]::new()
            $resourceManager = [ResourceManager]::new($eventPublisher)
            
            $resourceManager | Should -Not -BeNullOrEmpty
            $resourceManager.GetType().Name | Should -Be "ResourceManager"
        }
        
        It "Should manage memory pools" {
            $eventPublisher = [EventPublisher]::new()
            $resourceManager = [ResourceManager]::new($eventPublisher)
            
            # Create memory pool for buffers
            $poolId = $resourceManager.CreateMemoryPool("RenderBuffers", 1024, 10)
            $poolId | Should -Not -BeNullOrEmpty
            
            # Allocate from pool
            $buffer1 = $resourceManager.AllocateFromPool($poolId)
            $buffer2 = $resourceManager.AllocateFromPool($poolId)
            
            $buffer1 | Should -Not -BeNullOrEmpty
            $buffer2 | Should -Not -BeNullOrEmpty
            
            # Return to pool
            $resourceManager.ReturnToPool($poolId, $buffer1)
            $resourceManager.ReturnToPool($poolId, $buffer2)
            
            $poolStats = $resourceManager.GetPoolStatistics($poolId)
            $poolStats.AvailableCount | Should -Be 2
        }
        
        It "Should cleanup unused resources" {
            $eventPublisher = [EventPublisher]::new()
            $resourceManager = [ResourceManager]::new($eventPublisher)
            
            # Create resources
            $resources = @()
            for ($i = 0; $i -lt 100; $i++) {
                $resources += $resourceManager.CreateResource("TestResource$i")
            }
            
            # Mark some as unused
            for ($i = 0; $i -lt 50; $i++) {
                $resourceManager.MarkUnused($resources[$i])
            }
            
            $cleanedUp = $resourceManager.CleanupUnusedResources()
            $cleanedUp | Should -Be 50
        }
        
        It "Should prevent memory leaks" {
            $eventPublisher = [EventPublisher]::new()
            $resourceManager = [ResourceManager]::new($eventPublisher)
            
            $initialMemory = [GC]::GetTotalMemory($false)
            
            # Create and immediately dispose many resources
            for ($i = 0; $i -lt 1000; $i++) {
                $resource = $resourceManager.CreateResource("TempResource$i")
                $resourceManager.DisposeResource($resource)
            }
            
            [GC]::Collect()
            [GC]::WaitForPendingFinalizers()
            [GC]::Collect()
            
            $finalMemory = [GC]::GetTotalMemory($false)
            $memoryIncrease = $finalMemory - $initialMemory
            
            $memoryIncrease | Should -BeLessThan (1 * 1024 * 1024)  # Less than 1MB increase
        }
    }
}

Describe "Threading Safety" {
    Context "Thread-Safe Operations" {
        It "Should create thread-safe collections" {
            $eventPublisher = [EventPublisher]::new()
            $threadSafeCollection = [ThreadSafeCollection]::new()
            
            $threadSafeCollection | Should -Not -BeNullOrEmpty
            $threadSafeCollection.GetType().Name | Should -Be "ThreadSafeCollection"
        }
        
        It "Should handle concurrent access safely" {
            $eventPublisher = [EventPublisher]::new()
            $threadSafeCollection = [ThreadSafeCollection]::new()
            
            # Simulate concurrent adds (in real scenario would use actual threads)
            $jobs = @()
            for ($i = 0; $i -lt 10; $i++) {
                $jobs += Start-Job -ScriptBlock {
                    param($collection, $startIndex)
                    for ($j = 0; $j -lt 100; $j++) {
                        $collection.Add("Item$($startIndex + $j)")
                    }
                } -ArgumentList $threadSafeCollection, ($i * 100)
            }
            
            # Wait for all jobs
            $jobs | Wait-Job | Out-Null
            $jobs | Remove-Job
            
            $threadSafeCollection.Count | Should -Be 1000
        }
        
        It "Should prevent race conditions in event publishing" {
            $eventPublisher = [ThreadSafeEventPublisher]::new()
            
            $Global:eventCount = 0
            $eventPublisher.Subscribe('TestEvent', {
                $Global:eventCount++
            })
            
            # Simulate concurrent event publishing
            $jobs = @()
            for ($i = 0; $i -lt 10; $i++) {
                $jobs += Start-Job -ScriptBlock {
                    param($publisher)
                    for ($j = 0; $j -lt 50; $j++) {
                        $publisher.Publish('TestEvent', @{ Data = $j })
                    }
                } -ArgumentList $eventPublisher
            }
            
            $jobs | Wait-Job | Out-Null
            $jobs | Remove-Job
            
            $Global:eventCount | Should -Be 500
        }
    }
    
    Context "Synchronization Primitives" {
        It "Should create reader-writer locks" {
            $eventPublisher = [EventPublisher]::new()
            $rwLock = [System.Threading.ReaderWriterLockSlim]::new()
            
            $rwLock | Should -Not -BeNullOrEmpty
            $rwLock.GetType().Name | Should -Be "ReaderWriterLockSlim"
        }
        
        It "Should allow multiple readers" {
            $rwLock = [System.Threading.ReaderWriterLockSlim]::new()
            $sharedResource = @{ Value = 0 }
            
            # Simulate multiple readers
            $readerJobs = @()
            for ($i = 0; $i -lt 5; $i++) {
                $readerJobs += Start-Job -ScriptBlock {
                    param($lock, $resource)
                    $lock.EnterReadLock()
                    try {
                        $value = $resource.Value
                        Start-Sleep -Milliseconds 100
                        return $value
                    } finally {
                        $lock.ExitReadLock()
                    }
                } -ArgumentList $rwLock, $sharedResource
            }
            
            $readerJobs | Wait-Job | Out-Null
            $results = $readerJobs | Receive-Job
            $readerJobs | Remove-Job
            
            $results.Count | Should -Be 5
        }
        
        It "Should serialize writers" {
            $rwLock = [System.Threading.ReaderWriterLockSlim]::new()
            $sharedResource = @{ Value = 0 }
            $Global:writeOperations = @()
            
            # Simulate multiple writers
            $writerJobs = @()
            for ($i = 0; $i -lt 3; $i++) {
                $writerJobs += Start-Job -ScriptBlock {
                    param($lock, $resource, $writerIndex)
                    $lock.EnterWriteLock()
                    try {
                        $resource.Value = $writerIndex
                        Start-Sleep -Milliseconds 50
                        return "Writer$writerIndex completed"
                    } finally {
                        $lock.ExitWriteLock()
                    }
                } -ArgumentList $rwLock, $sharedResource, $i
            }
            
            $writerJobs | Wait-Job | Out-Null
            $results = $writerJobs | Receive-Job
            $writerJobs | Remove-Job
            
            $results.Count | Should -Be 3
        }
    }
}

Describe "Performance Benchmarks" {
    Context "Large Dataset Performance" {
        It "Should handle 10K tasks efficiently" {
            $eventPublisher = [EventPublisher]::new()
            $dataSource = [VirtualDataSource]::new($Global:LargeTaskSet)
            $viewport = [VirtualScrollingViewport]::new($dataSource, $eventPublisher)
            
            $renderTime = Measure-Command {
                $viewport.SetViewport(0, 50)  # Render first 50 items
                $lines = $viewport.GetVisibleLines()
            }
            
            $renderTime.TotalMilliseconds | Should -BeLessThan 100  # Render 50 items in under 100ms
        }
        
        It "Should filter large datasets quickly" {
            $eventPublisher = [EventPublisher]::new()
            $filterEngine = [FilterEngine]::new($eventPublisher)
            $dataSource = [VirtualDataSource]::new($Global:LargeTaskSet)
            $filterEngine.SetDataSource($dataSource)
            
            $statusFilter = [StatusFilter]::new("pending")
            $filterEngine.AddFilter($statusFilter)
            
            $filterTime = Measure-Command {
                $results = $filterEngine.GetFilteredResults()
            }
            
            $filterTime.TotalMilliseconds | Should -BeLessThan 500  # Filter 10K items in under 500ms
            $results.Count | Should -Be 2500  # 25% are pending
        }
        
        It "Should maintain 60 FPS rendering" {
            $eventPublisher = [EventPublisher]::new()
            $renderEngine = [RenderEngine]::new()
            $buffer = $renderEngine.CreateBuffer(80, 24)
            
            $frameTime = Measure-Command {
                # Simulate 60 frame renders
                for ($i = 0; $i -lt 60; $i++) {
                    for ($row = 0; $row -lt 24; $row++) {
                        $buffer.SetLine($row, "Frame $i Line $row content with sufficient length to test rendering performance")
                    }
                    $renderEngine.RenderBuffer($buffer)
                }
            }
            
            $avgFrameTime = $frameTime.TotalMilliseconds / 60
            $avgFrameTime | Should -BeLessThan 16.67  # 60 FPS = 16.67ms per frame
        }
        
        It "Should keep memory usage under control" {
            $eventPublisher = [EventPublisher]::new()
            $cache = [TaskCacheManager]::new($eventPublisher, 100)  # 100MB limit
            
            # Cache large amounts of data
            for ($i = 0; $i -lt 1000; $i++) {
                $largeData = $Global:LargeTaskSet[($i % $Global:LargeTaskSet.Count)..($i % $Global:LargeTaskSet.Count + 10)]
                $cache.CacheTasks("large_dataset_$i", $largeData, 300)
            }
            
            $memoryUsage = $cache.GetMemoryUsage()
            $memoryUsage.TotalMB | Should -BeLessOrEqual 100
        }
        
        It "Should scale with concurrent operations" {
            $eventPublisher = [EventPublisher]::new()
            $backgroundProcessor = [BackgroundProcessor]::new($eventPublisher, 4)  # 4 threads
            
            $tasks = @()
            for ($i = 0; $i -lt 100; $i++) {
                $tasks += @{
                    Name = "ScaleTest$i"
                    Action = { 
                        # Simulate work
                        Start-Sleep -Milliseconds (Get-Random -Minimum 10 -Maximum 50)
                        return "Task completed"
                    }
                    Priority = "Normal"
                }
            }
            
            $startTime = Get-Date
            
            foreach ($task in $tasks) {
                $backgroundProcessor.QueueTask($task)
            }
            
            $backgroundProcessor.StartProcessing()
            
            # Wait for all tasks to complete
            while ($backgroundProcessor.GetActiveTaskCount() -gt 0) {
                Start-Sleep -Milliseconds 100
            }
            
            $totalTime = (Get-Date) - $startTime
            
            # Should complete faster than sequential execution
            $totalTime.TotalSeconds | Should -BeLessThan 30  # Much faster than 100 * 30ms = 3s sequential
        }
    }
    
    Context "Memory Optimization" {
        It "Should use memory efficiently" {
            $initialMemory = [GC]::GetTotalMemory($false)
            
            # Create and use various components
            $eventPublisher = [EventPublisher]::new()
            $renderEngine = [RenderEngine]::new()
            $config = @{ taskwarrior = @{ data_location = "/tmp/.task" } }
            $dataProvider = [TaskWarriorDataProvider]::new($config)
            $cache = [TaskCacheManager]::new($eventPublisher)
            
            # Use the components
            $buffer = $renderEngine.CreateBuffer(80, 24)
            $tasks = @($Global:LargeTaskSet[0..99])  # Use 100 tasks
            $cache.CacheTasks("memory_test", $tasks, 300)
            
            $peakMemory = [GC]::GetTotalMemory($false)
            
            # Cleanup
            $buffer = $null
            $tasks = $null
            $cache = $null
            $renderEngine = $null
            $eventPublisher = $null
            
            [GC]::Collect()
            [GC]::WaitForPendingFinalizers()
            [GC]::Collect()
            
            $finalMemory = [GC]::GetTotalMemory($false)
            $memoryIncrease = $finalMemory - $initialMemory
            
            $memoryIncrease | Should -BeLessThan (5 * 1024 * 1024)  # Less than 5MB permanent increase
        }
    }
}