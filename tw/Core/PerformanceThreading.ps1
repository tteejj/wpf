# Performance & Threading Implementation
# Background processing, multi-threading, performance monitoring, and resource management

# Background task processor for asynchronous operations
class BackgroundProcessor {
    hidden [object] $_eventPublisher  # EventPublisher
    hidden [System.Collections.Concurrent.ConcurrentQueue[object]] $_taskQueue
    hidden [hashtable] $_activeTasks = @{}
    hidden [hashtable] $_completedTasks = @{}
    hidden [int] $_maxConcurrentTasks
    hidden [bool] $_isProcessing = $false
    hidden [System.Threading.CancellationTokenSource] $_cancellationSource
    
    BackgroundProcessor([object]$eventPublisher) {
        $this._eventPublisher = $eventPublisher
        $this._maxConcurrentTasks = [Environment]::ProcessorCount
        $this._taskQueue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
        $this._cancellationSource = [System.Threading.CancellationTokenSource]::new()
    }
    
    BackgroundProcessor([object]$eventPublisher, [int]$maxConcurrentTasks) {
        $this._eventPublisher = $eventPublisher
        $this._maxConcurrentTasks = $maxConcurrentTasks
        $this._taskQueue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
        $this._cancellationSource = [System.Threading.CancellationTokenSource]::new()
    }
    
    [string] QueueTask([hashtable]$task) {
        $taskId = [Guid]::NewGuid().ToString()
        $taskWrapper = @{
            Id = $taskId
            Name = $task.Name
            Action = $task.Action
            Priority = if ($task.Priority) { $task.Priority } else { "Normal" }
            QueueTime = Get-Date
            Status = "Queued"
        }
        
        $this._taskQueue.Enqueue($taskWrapper)
        
        if ($this._eventPublisher) {
            $this._eventPublisher.Publish('TaskQueued', @{
                TaskId = $taskId
                TaskName = $task.Name
                Priority = $taskWrapper.Priority
                QueueTime = $taskWrapper.QueueTime
            })
        }
        
        return $taskId
    }
    
    [array] GetQueuedTasks() {
        return $this._taskQueue.ToArray()
    }
    
    [int] GetActiveTaskCount() {
        return $this._activeTasks.Count
    }
    
    [void] StartProcessing() {
        if ($this._isProcessing) {
            return
        }
        
        $this._isProcessing = $true
        
        # Start background processing thread
        $runspace = [PowerShell]::Create()
        $runspace.AddScript({
            param($processor, $eventPublisher, $maxConcurrent, $cancellationToken)
            
            while (-not $cancellationToken.Token.IsCancellationRequested) {
                if ($processor._activeTasks.Count -lt $maxConcurrent) {
                    $task = $null
                    if ($processor._taskQueue.TryDequeue([ref]$task)) {
                        # Execute task
                        $processor.ExecuteTaskAsync($task)
                    }
                }
                Start-Sleep -Milliseconds 50
            }
        }).AddArgument($this).AddArgument($this._eventPublisher).AddArgument($this._maxConcurrentTasks).AddArgument($this._cancellationSource)
        
        $runspace.BeginInvoke()
    }
    
    [void] ExecuteTaskAsync([hashtable]$task) {
        $task.Status = "Running"
        $task.StartTime = Get-Date
        $this._activeTasks[$task.Id] = $task
        
        try {
            # Execute the task action
            $result = & $task.Action
            
            $task.Status = "Completed"
            $task.EndTime = Get-Date
            $task.Result = $result
            $task.Duration = ($task.EndTime - $task.StartTime).TotalMilliseconds
            
            $this._completedTasks[$task.Id] = $task
            $this._activeTasks.Remove($task.Id)
            
            if ($this._eventPublisher) {
                $this._eventPublisher.Publish('TaskCompleted', @{
                    TaskId = $task.Id
                    TaskName = $task.Name
                    Result = $result
                    Duration = $task.Duration
                    Timestamp = Get-Date
                })
            }
            
        } catch {
            $task.Status = "Failed"
            $task.EndTime = Get-Date
            $task.Error = $_.Exception.Message
            $task.Duration = ($task.EndTime - $task.StartTime).TotalMilliseconds
            
            $this._activeTasks.Remove($task.Id)
            
            if ($this._eventPublisher) {
                $this._eventPublisher.Publish('TaskFailed', @{
                    TaskId = $task.Id
                    TaskName = $task.Name
                    Error = $task.Error
                    Duration = $task.Duration
                    Timestamp = Get-Date
                })
            }
        }
    }
    
    [hashtable] CancelTask([string]$taskId) {
        if ($this._activeTasks.ContainsKey($taskId)) {
            $task = $this._activeTasks[$taskId]
            $task.Status = "Cancelled"
            $task.EndTime = Get-Date
            $this._activeTasks.Remove($taskId)
            
            return @{ Success = $true; Message = "Task cancelled successfully" }
        }
        
        return @{ Success = $false; Message = "Task not found or already completed" }
    }
    
    [void] StopProcessing() {
        $this._isProcessing = $false
        $this._cancellationSource.Cancel()
    }
}

# Data synchronizer for background data updates
class DataSynchronizer {
    hidden [object] $_eventPublisher  # EventPublisher
    hidden [object] $_dataProvider    # TaskWarriorDataProvider
    hidden [System.IO.FileSystemWatcher] $_fileWatcher
    hidden [System.Timers.Timer] $_syncTimer
    hidden [DateTime] $_lastSyncTime
    hidden [bool] $_isMonitoring = $false
    
    DataSynchronizer([object]$eventPublisher, [object]$dataProvider) {
        $this._eventPublisher = $eventPublisher
        $this._dataProvider = $dataProvider
        $this._lastSyncTime = Get-Date
    }
    
    [void] CheckForChanges() {
        # In a real implementation, this would check file modification times
        # For testing, we'll use a simple timestamp comparison
        $currentTime = Get-Date
        if (($currentTime - $this._lastSyncTime).TotalSeconds -gt 10) {
            $this.NotifyDataChanged()
        }
    }
    
    [void] NotifyDataChanged() {
        if ($this._eventPublisher) {
            $this._eventPublisher.Publish('DataChanged', @{
                Timestamp = Get-Date
                Source = "FileSystem"
            })
        }
    }
    
    [void] StartBackgroundSync([int]$intervalMs) {
        if ($this._syncTimer) {
            $this._syncTimer.Stop()
            $this._syncTimer.Dispose()
        }
        
        $this._syncTimer = [System.Timers.Timer]::new($intervalMs)
        $this._syncTimer.AutoReset = $true
        
        $syncTimerRef = $this._syncTimer
        $selfRef = $this
        
        Register-ObjectEvent -InputObject $this._syncTimer -EventName Elapsed -Action {
            $selfRef.SyncNow()
        } | Out-Null
        
        $this._syncTimer.Start()
        $this._isMonitoring = $true
    }
    
    [void] SyncNow() {
        try {
            # Simulate sync operation
            $this._lastSyncTime = Get-Date
            
            if ($this._eventPublisher) {
                $this._eventPublisher.Publish('SyncCompleted', @{
                    Timestamp = $this._lastSyncTime
                    Success = $true
                })
            }
        } catch {
            if ($this._eventPublisher) {
                $this._eventPublisher.Publish('SyncFailed', @{
                    Timestamp = Get-Date
                    Error = $_.Exception.Message
                })
            }
        }
    }
    
    [void] SimulateConflict() {
        if ($this._eventPublisher) {
            $this._eventPublisher.Publish('SyncConflict', @{
                ConflictType = "ModificationConflict"
                LocalVersion = "1.0"
                RemoteVersion = "1.1"
                Timestamp = Get-Date
            })
        }
    }
    
    [void] StopBackgroundSync() {
        if ($this._syncTimer) {
            $this._syncTimer.Stop()
            $this._syncTimer.Dispose()
            $this._syncTimer = $null
        }
        
        if ($this._fileWatcher) {
            $this._fileWatcher.Dispose()
            $this._fileWatcher = $null
        }
        
        $this._isMonitoring = $false
    }
}

# Performance monitoring for metrics collection
class PerformanceMonitor {
    hidden [object] $_eventPublisher  # EventPublisher
    hidden [hashtable] $_activeTrackings = @{}
    hidden [hashtable] $_completedTrackings = @{}
    hidden [array] $_frameRates = @()
    hidden [DateTime] $_lastFrameTime
    hidden [int] $_frameCount = 0
    
    PerformanceMonitor([object]$eventPublisher) {
        $this._eventPublisher = $eventPublisher
        $this._lastFrameTime = Get-Date
    }
    
    [void] StartTracking([string]$operationName) {
        $this._activeTrackings[$operationName] = @{
            StartTime = Get-Date
            StartMemory = [GC]::GetTotalMemory($false)
        }
    }
    
    [hashtable] StopTracking([string]$operationName) {
        if (-not $this._activeTrackings.ContainsKey($operationName)) {
            throw "No active tracking found for operation: $operationName"
        }
        
        $tracking = $this._activeTrackings[$operationName]
        $endTime = Get-Date
        $endMemory = [GC]::GetTotalMemory($false)
        
        $metrics = @{
            OperationName = $operationName
            StartTime = $tracking.StartTime
            EndTime = $endTime
            ElapsedMilliseconds = ($endTime - $tracking.StartTime).TotalMilliseconds
            StartMemory = $tracking.StartMemory
            EndMemory = $endMemory
            MemoryDelta = $endMemory - $tracking.StartMemory
        }
        
        $this._completedTrackings[$operationName] = $metrics
        $this._activeTrackings.Remove($operationName)
        
        if ($this._eventPublisher) {
            $this._eventPublisher.Publish('PerformanceMetric', $metrics)
        }
        
        return $metrics
    }
    
    [hashtable] GetMemoryUsage() {
        $process = [System.Diagnostics.Process]::GetCurrentProcess()
        
        return @{
            WorkingSet = $process.WorkingSet64
            PrivateMemory = $process.PrivateMemorySize64
            VirtualMemory = $process.VirtualMemorySize64
            GCMemory = [GC]::GetTotalMemory($false)
        }
    }
    
    [void] RecordFrame() {
        $currentTime = Get-Date
        if ($this._frameCount -gt 0) {
            $frameDuration = ($currentTime - $this._lastFrameTime).TotalMilliseconds
            $fps = if ($frameDuration -gt 0) { 1000 / $frameDuration } else { 0 }
            $this._frameRates += $fps
            
            # Keep only last 60 frames
            if ($this._frameRates.Count -gt 60) {
                $this._frameRates = $this._frameRates[-60..-1]
            }
        }
        
        $this._lastFrameTime = $currentTime
        $this._frameCount++
    }
    
    [double] GetAverageFrameRate() {
        if ($this._frameRates.Count -eq 0) {
            return 0
        }
        
        return ($this._frameRates | Measure-Object -Average).Average
    }
    
    [void] AnalyzePerformance() {
        foreach ($tracking in $this._completedTrackings.Values) {
            if ($tracking.ElapsedMilliseconds -gt 100) {  # Threshold for bottleneck
                if ($this._eventPublisher) {
                    $this._eventPublisher.Publish('PerformanceBottleneck', @{
                        OperationName = $tracking.OperationName
                        Duration = $tracking.ElapsedMilliseconds
                        MemoryUsage = $tracking.MemoryDelta
                        Timestamp = Get-Date
                    })
                }
            }
        }
    }
    
    [hashtable] GetPerformanceReport() {
        $avgFrameRate = $this.GetAverageFrameRate()
        $memoryUsage = $this.GetMemoryUsage()
        
        return @{
            AverageFrameRate = $avgFrameRate
            MemoryUsage = $memoryUsage
            ActiveTrackings = $this._activeTrackings.Count
            CompletedOperations = $this._completedTrackings.Count
            ReportTime = Get-Date
        }
    }
}

# Resource manager for memory and object pooling
class ResourceManager {
    hidden [object] $_eventPublisher  # EventPublisher
    hidden [hashtable] $_memoryPools = @{}
    hidden [hashtable] $_resources = @{}
    hidden [hashtable] $_resourceUsage = @{}
    
    ResourceManager([object]$eventPublisher) {
        $this._eventPublisher = $eventPublisher
    }
    
    [string] CreateMemoryPool([string]$poolName, [int]$itemSize, [int]$initialCount) {
        $poolId = [Guid]::NewGuid().ToString()
        
        $pool = @{
            Id = $poolId
            Name = $poolName
            ItemSize = $itemSize
            Available = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
            InUse = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new()
            TotalAllocated = 0
            MaxSize = $initialCount * 2
        }
        
        # Pre-allocate initial items
        for ($i = 0; $i -lt $initialCount; $i++) {
            $item = New-Object byte[] $itemSize
            $pool.Available.Enqueue(@{ Id = [Guid]::NewGuid().ToString(); Data = $item })
            $pool.TotalAllocated++
        }
        
        $this._memoryPools[$poolId] = $pool
        
        if ($this._eventPublisher) {
            $this._eventPublisher.Publish('MemoryPoolCreated', @{
                PoolId = $poolId
                PoolName = $poolName
                InitialCount = $initialCount
                ItemSize = $itemSize
            })
        }
        
        return $poolId
    }
    
    [object] AllocateFromPool([string]$poolId) {
        if (-not $this._memoryPools.ContainsKey($poolId)) {
            throw "Memory pool not found: $poolId"
        }
        
        $pool = $this._memoryPools[$poolId]
        $item = $null
        
        if ($pool.Available.TryDequeue([ref]$item)) {
            $pool.InUse.TryAdd($item.Id, $item)
            return $item
        }
        
        # Pool exhausted, create new item if under limit
        if ($pool.TotalAllocated -lt $pool.MaxSize) {
            $newItem = @{ Id = [Guid]::NewGuid().ToString(); Data = New-Object byte[] $pool.ItemSize }
            $pool.InUse.TryAdd($newItem.Id, $newItem)
            $pool.TotalAllocated++
            return $newItem
        }
        
        throw "Memory pool exhausted: $poolId"
    }
    
    [void] ReturnToPool([string]$poolId, [object]$item) {
        if (-not $this._memoryPools.ContainsKey($poolId)) {
            return
        }
        
        $pool = $this._memoryPools[$poolId]
        $removed = $null
        if ($pool.InUse.TryRemove($item.Id, [ref]$removed)) {
            $pool.Available.Enqueue($item)
        }
    }
    
    [hashtable] GetPoolStatistics([string]$poolId) {
        if (-not $this._memoryPools.ContainsKey($poolId)) {
            throw "Memory pool not found: $poolId"
        }
        
        $pool = $this._memoryPools[$poolId]
        
        return @{
            PoolId = $poolId
            Name = $pool.Name
            TotalAllocated = $pool.TotalAllocated
            AvailableCount = $pool.Available.Count
            InUseCount = $pool.InUse.Count
            ItemSize = $pool.ItemSize
            MaxSize = $pool.MaxSize
        }
    }
    
    [object] CreateResource([string]$resourceName) {
        $resourceId = [Guid]::NewGuid().ToString()
        $resource = @{
            Id = $resourceId
            Name = $resourceName
            CreatedAt = Get-Date
            LastAccessed = Get-Date
            AccessCount = 0
            Size = Get-Random -Minimum 1024 -Maximum 10240  # Simulate varying sizes
        }
        
        $this._resources[$resourceId] = $resource
        $this._resourceUsage[$resourceId] = @{
            IsActive = $true
            LastAccess = Get-Date
        }
        
        return $resource
    }
    
    [void] MarkUnused([object]$resource) {
        if ($this._resourceUsage.ContainsKey($resource.Id)) {
            $this._resourceUsage[$resource.Id].IsActive = $false
        }
    }
    
    [int] CleanupUnusedResources() {
        $cleanedUp = 0
        $resourcesToRemove = @()
        
        foreach ($resourceId in $this._resourceUsage.Keys) {
            $usage = $this._resourceUsage[$resourceId]
            if (-not $usage.IsActive) {
                $resourcesToRemove += $resourceId
            }
        }
        
        foreach ($resourceId in $resourcesToRemove) {
            $this._resources.Remove($resourceId)
            $this._resourceUsage.Remove($resourceId)
            $cleanedUp++
        }
        
        if ($cleanedUp -gt 0 -and $this._eventPublisher) {
            $this._eventPublisher.Publish('ResourcesCleanedUp', @{
                Count = $cleanedUp
                Timestamp = Get-Date
            })
        }
        
        return $cleanedUp
    }
    
    [void] DisposeResource([object]$resource) {
        if ($this._resources.ContainsKey($resource.Id)) {
            $this._resources.Remove($resource.Id)
            $this._resourceUsage.Remove($resource.Id)
        }
    }
}

# Thread-safe collection for concurrent operations
class ThreadSafeCollection {
    hidden [System.Collections.Concurrent.ConcurrentBag[object]] $_items
    hidden [object] $_lock = [object]::new()
    
    ThreadSafeCollection() {
        $this._items = [System.Collections.Concurrent.ConcurrentBag[object]]::new()
    }
    
    [void] Add([object]$item) {
        $this._items.Add($item)
    }
    
    [bool] TryTake([ref]$result) {
        return $this._items.TryTake($result)
    }
    
    [int] get_Count() {
        return $this._items.Count
    }
    
    [array] ToArray() {
        return $this._items.ToArray()
    }
    
    [void] Clear() {
        # Create new concurrent bag (no direct clear method)
        $this._items = [System.Collections.Concurrent.ConcurrentBag[object]]::new()
    }
}

# Thread-safe event publisher
class ThreadSafeEventPublisher {
    hidden [System.Collections.Concurrent.ConcurrentDictionary[string, System.Collections.Concurrent.ConcurrentBag[scriptblock]]] $_subscribers
    hidden [object] $_lock = [object]::new()
    
    ThreadSafeEventPublisher() {
        $this._subscribers = [System.Collections.Concurrent.ConcurrentDictionary[string, System.Collections.Concurrent.ConcurrentBag[scriptblock]]]::new()
    }
    
    [void] Subscribe([string]$eventName, [scriptblock]$handler) {
        $handlers = $this._subscribers.GetOrAdd($eventName, [System.Collections.Concurrent.ConcurrentBag[scriptblock]]::new())
        $handlers.Add($handler)
    }
    
    [void] Publish([string]$eventName, [hashtable]$eventData) {
        if ($this._subscribers.ContainsKey($eventName)) {
            $handlers = $this._subscribers[$eventName]
            $handlersArray = $handlers.ToArray()
            
            foreach ($handler in $handlersArray) {
                try {
                    & $handler $eventData
                } catch {
                    Write-Warning "Event handler failed: $_"
                }
            }
        }
    }
    
    [void] Unsubscribe([string]$eventName, [scriptblock]$handler) {
        # Note: ConcurrentBag doesn't support removal, so we'd need a different approach
        # For testing purposes, this is a placeholder implementation
        Write-Warning "Unsubscribe not fully implemented for thread-safe version"
    }
    
    [array] GetEventNames() {
        return $this._subscribers.Keys
    }
    
    [int] GetSubscriberCount([string]$eventName) {
        if ($this._subscribers.ContainsKey($eventName)) {
            return $this._subscribers[$eventName].Count
        }
        return 0
    }
}