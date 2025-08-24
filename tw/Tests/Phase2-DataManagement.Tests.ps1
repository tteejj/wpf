# Phase 2: Data Management Tests
# TaskWarrior integration, caching, and data providers

BeforeAll {
    # Import required classes
    try {
        . "$PSScriptRoot/../Core/RenderEngine.ps1"
        . "$PSScriptRoot/../Core/EventSystem.ps1"
        . "$PSScriptRoot/../Core/ConfigurationProvider.ps1"
        . "$PSScriptRoot/../Core/TaskDataProvider.ps1"
        . "$PSScriptRoot/../Core/CachingSystem.ps1"
    } catch {
        Write-Warning "Core classes not yet implemented: $_"
    }
    
    # Mock TaskWarrior data for testing
    $Global:MockTasks = @(
        @{
            uuid = '12345678-1234-1234-1234-123456789012'
            id = 1
            description = 'Test task 1'
            status = 'pending'
            entry = '20240101T120000Z'
            urgency = 5.0
            project = 'testproject'
            tags = @('work', 'urgent')
        },
        @{
            uuid = '12345678-1234-1234-1234-123456789013'
            id = 2
            description = 'Test task 2'
            status = 'completed'
            entry = '20240101T130000Z'
            end = '20240101T140000Z'
            urgency = 3.0
        }
    )
}

Describe "Task Data Provider" {
    Context "TaskWarrior Integration" {
        It "Should create TaskWarrior data provider" {
            $config = @{
                taskwarrior = @{
                    data_location = "$HOME/.task"
                    task_command = "task"
                    timeout_seconds = 30
                }
            }
            
            $provider = [TaskWarriorDataProvider]::new($config)
            $provider | Should -Not -BeNullOrEmpty
            $provider.GetType().Name | Should -Be "TaskWarriorDataProvider"
        }
        
        It "Should parse TaskWarrior JSON output" {
            $jsonOutput = $Global:MockTasks | ConvertTo-Json -Depth 10
            $provider = [TaskWarriorDataProvider]::new(@{})
            
            $tasks = $provider.ParseTaskWarriorJson($jsonOutput)
            
            $tasks.Count | Should -Be 2
            $tasks[0].id | Should -Be 1
            $tasks[0].description | Should -Be 'Test task 1'
            $tasks[0].status | Should -Be 'pending'
        }
        
        It "Should handle TaskWarrior command execution" {
            $provider = [TaskWarriorDataProvider]::new(@{
                taskwarrior = @{
                    task_command = "echo"  # Mock with echo
                    timeout_seconds = 5
                }
            })
            
            $result = $provider.ExecuteTaskWarriorCommand("echo test")
            $result.Success | Should -Be $true
            $result.Output | Should -Be "test"
            $result.ExitCode | Should -Be 0
        }
        
        It "Should handle TaskWarrior command failures gracefully" {
            $provider = [TaskWarriorDataProvider]::new(@{
                taskwarrior = @{
                    task_command = "nonexistentcommand"
                    timeout_seconds = 5
                }
            })
            
            $result = $provider.ExecuteTaskWarriorCommand("test")
            $result.Success | Should -Be $false
            $result.Error | Should -Not -BeNullOrEmpty
        }
        
        It "Should load tasks with filtering" {
            # Mock the command execution to return our test data
            $provider = [MockTaskWarriorDataProvider]::new($Global:MockTasks)
            
            $tasks = $provider.GetTasks("status:pending")
            $tasks.Count | Should -Be 1  # Only pending tasks
            $tasks[0].status | Should -Be 'pending'
        }
        
        It "Should save tasks back to TaskWarrior" {
            $provider = [MockTaskWarriorDataProvider]::new($Global:MockTasks)
            $task = @{
                id = 1
                description = 'Updated test task'
                status = 'pending'
            }
            
            $result = $provider.SaveTask($task)
            $result.Success | Should -Be $true
        }
        
        It "Should handle UDA fields correctly" {
            $tasksWithUDA = @(
                @{
                    uuid = '12345678-1234-1234-1234-123456789014'
                    id = 3
                    description = 'Task with UDA'
                    status = 'pending'
                    customfield = 'custom value'
                    priority_score = 10
                }
            )
            
            $provider = [MockTaskWarriorDataProvider]::new($tasksWithUDA)
            $tasks = $provider.GetTasks()
            
            $tasks[0].customfield | Should -Be 'custom value'
            $tasks[0].priority_score | Should -Be 10
        }
    }
    
    Context "Data Validation" {
        It "Should validate task data structure" {
            $provider = [TaskWarriorDataProvider]::new(@{})
            
            $validTask = @{
                uuid = '12345678-1234-1234-1234-123456789012'
                description = 'Valid task'
                status = 'pending'
            }
            
            $result = $provider.ValidateTask($validTask)
            $result.IsValid | Should -Be $true
        }
        
        It "Should reject invalid task data" {
            $provider = [TaskWarriorDataProvider]::new(@{})
            
            $invalidTask = @{
                # Missing required fields
                status = 'pending'
            }
            
            $result = $provider.ValidateTask($invalidTask)
            $result.IsValid | Should -Be $false
            $result.Errors.Count | Should -BeGreaterThan 0
        }
    }
    
    Context "Performance Requirements" {
        It "Should load large task sets efficiently" {
            # Generate 1000 mock tasks
            $largeTasks = @()
            for ($i = 1; $i -le 1000; $i++) {
                $largeTasks += @{
                    uuid = "12345678-1234-1234-1234-12345678$('{0:D4}' -f $i)"
                    id = $i
                    description = "Task $i"
                    status = if ($i % 2 -eq 0) { 'completed' } else { 'pending' }
                    urgency = [math]::Round((Get-Random -Maximum 10), 2)
                }
            }
            
            $provider = [MockTaskWarriorDataProvider]::new($largeTasks)
            
            $loadTime = Measure-Command {
                $tasks = $provider.GetTasks()
            }
            
            $loadTime.TotalMilliseconds | Should -BeLessThan 1000  # 1 second for 1K tasks
            $tasks.Count | Should -Be 1000
        }
    }
}

Describe "Caching System" {
    Context "Basic Cache Operations" {
        It "Should create cache instance" {
            $eventPublisher = [EventPublisher]::new()
            $cache = [TaskCacheManager]::new($eventPublisher)
            
            $cache | Should -Not -BeNullOrEmpty
            $cache.GetType().Name | Should -Be "TaskCacheManager"
        }
        
        It "Should cache task data with expiration" {
            $eventPublisher = [EventPublisher]::new()
            $cache = [TaskCacheManager]::new($eventPublisher)
            $testTasks = $Global:MockTasks
            
            # Cache the data
            $cache.CacheTasks("status:pending", $testTasks, 60)  # 60 second expiry
            
            # Retrieve from cache
            $cachedTasks = $cache.GetCachedTasks("status:pending")
            $cachedTasks.Count | Should -Be $testTasks.Count
            $cachedTasks[0].id | Should -Be $testTasks[0].id
        }
        
        It "Should handle cache expiration" {
            $eventPublisher = [EventPublisher]::new()
            $cache = [TaskCacheManager]::new($eventPublisher)
            $testTasks = $Global:MockTasks
            
            # Cache with very short expiry
            $cache.CacheTasks("test", $testTasks, 0.1)  # 0.1 second expiry
            
            # Wait for expiration
            Start-Sleep -Milliseconds 200
            
            # Should return null for expired cache
            $cachedTasks = $cache.GetCachedTasks("test")
            $cachedTasks | Should -BeNullOrEmpty
        }
        
        It "Should invalidate cache on data changes" {
            $eventPublisher = [EventPublisher]::new()
            $cache = [TaskCacheManager]::new($eventPublisher)
            $testTasks = $Global:MockTasks
            
            # Cache the data
            $cache.CacheTasks("all", $testTasks, 60)
            
            # Invalidate cache
            $cache.InvalidateCache("all")
            
            # Should return null after invalidation
            $cachedTasks = $cache.GetCachedTasks("all")
            $cachedTasks | Should -BeNullOrEmpty
        }
        
        It "Should respect memory limits" {
            $eventPublisher = [EventPublisher]::new()
            $cache = [TaskCacheManager]::new($eventPublisher, 1)  # 1MB limit
            
            # Try to cache data that exceeds limit
            $largeTasks = @()
            for ($i = 1; $i -le 10000; $i++) {
                $largeTasks += @{
                    id = $i
                    description = "Very long task description " * 100  # Make it large
                    status = 'pending'
                }
            }
            
            $cache.CacheTasks("large", $largeTasks, 60)
            
            # Should handle memory pressure gracefully
            $memoryUsage = $cache.GetMemoryUsage()
            $memoryUsage.TotalMB | Should -BeLessThan 5  # Should stay reasonable
        }
        
        It "Should provide cache hit statistics" {
            $eventPublisher = [EventPublisher]::new()
            $cache = [TaskCacheManager]::new($eventPublisher)
            $testTasks = $Global:MockTasks
            
            # Cache some data
            $cache.CacheTasks("stats", $testTasks, 60)
            
            # Hit the cache multiple times
            for ($i = 0; $i -lt 5; $i++) {
                $null = $cache.GetCachedTasks("stats")
            }
            
            # Check statistics
            $stats = $cache.GetCacheStatistics()
            $stats.Hits | Should -Be 5
            $stats.Misses | Should -Be 0
            $stats.HitRate | Should -Be 1.0
        }
    }
    
    Context "Multi-level Caching" {
        It "Should support multiple cache levels" {
            $eventPublisher = [EventPublisher]::new()
            $cache = [TaskCacheManager]::new($eventPublisher)
            
            # Cache at different levels
            $cache.CacheTasks("L1:pending", $Global:MockTasks, 60, "L1")
            $cache.CacheUrgency("urgency:task1", 5.0, 30, "L2")
            $cache.CacheFormattedLines("format:pending", @("Line 1", "Line 2"), 15, "L3")
            
            # Verify different levels work
            $l1Data = $cache.GetCachedTasks("L1:pending")
            $l2Data = $cache.GetCachedUrgency("urgency:task1")
            $l3Data = $cache.GetCachedFormattedLines("format:pending")
            
            $l1Data | Should -Not -BeNullOrEmpty
            $l2Data | Should -Be 5.0
            $l3Data | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Integrated Data Management" {
    Context "Provider with Cache Integration" {
        It "Should use cache when available" {
            $eventPublisher = [EventPublisher]::new()
            $cache = [TaskCacheManager]::new($eventPublisher)
            $provider = [MockTaskWarriorDataProvider]::new($Global:MockTasks)
            
            # Create integrated data manager
            $dataManager = [IntegratedDataManager]::new($provider, $cache)
            
            # First call should hit provider and populate cache
            $tasks1 = $dataManager.GetTasks("status:pending")
            
            # Second call should hit cache
            $tasks2 = $dataManager.GetTasks("status:pending")
            
            $tasks1.Count | Should -Be $tasks2.Count
            
            # Verify cache was used
            $stats = $cache.GetCacheStatistics()
            $stats.Hits | Should -BeGreaterThan 0
        }
        
        It "Should invalidate cache on data updates" {
            $eventPublisher = [EventPublisher]::new()
            $cache = [TaskCacheManager]::new($eventPublisher)
            $provider = [MockTaskWarriorDataProvider]::new($Global:MockTasks)
            $dataManager = [IntegratedDataManager]::new($provider, $cache)
            
            # Load and cache data
            $tasks = $dataManager.GetTasks()
            
            # Update a task
            $updatedTask = $tasks[0].Clone()
            $updatedTask.description = "Updated description"
            $result = $dataManager.SaveTask($updatedTask)
            
            $result.Success | Should -Be $true
            
            # Cache should be invalidated
            $cachedTasks = $cache.GetCachedTasks("all")
            $cachedTasks | Should -BeNullOrEmpty
        }
    }
}