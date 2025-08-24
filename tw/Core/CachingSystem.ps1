# Caching System Implementation
# Multi-level caching with expiration and memory management

class CacheEntry {
    [object] $Data
    [datetime] $CreatedAt
    [datetime] $ExpiresAt
    [string] $Level
    [int] $SizeBytes
    [int] $AccessCount = 0
    [datetime] $LastAccess
    
    CacheEntry([object]$data, [int]$ttlSeconds) {
        $this.Data = $data
        $this.CreatedAt = Get-Date
        $this.ExpiresAt = $this.CreatedAt.AddSeconds($ttlSeconds)
        $this.Level = "L1"
        $this.LastAccess = $this.CreatedAt
        $this.SizeBytes = $this.CalculateSize($data)
    }
    
    CacheEntry([object]$data, [int]$ttlSeconds, [string]$level) {
        $this.Data = $data
        $this.CreatedAt = Get-Date
        $this.ExpiresAt = $this.CreatedAt.AddSeconds($ttlSeconds)
        $this.Level = $level
        $this.LastAccess = $this.CreatedAt
        $this.SizeBytes = $this.CalculateSize($data)
    }
    
    [bool] IsExpired() {
        return (Get-Date) -gt $this.ExpiresAt
    }
    
    [object] GetData() {
        $this.AccessCount++
        $this.LastAccess = Get-Date
        return $this.Data
    }
    
    hidden [int] CalculateSize([object]$data) {
        try {
            if ($null -eq $data) { return 0 }
            
            # Rough estimation of object size in memory
            $json = $data | ConvertTo-Json -Depth 10 -Compress
            return $json.Length * 2  # Unicode characters are 2 bytes each
        } catch {
            return 1000  # Default estimate
        }
    }
}

class TaskCacheManager {
    hidden [hashtable] $_cache = @{}
    hidden [object] $_eventPublisher  # IEventPublisher interface
    hidden [int] $_maxMemoryMB
    hidden [hashtable] $_statistics = @{
        Hits = 0
        Misses = 0
        Evictions = 0
        TotalRequests = 0
    }
    
    TaskCacheManager([object]$eventPublisher) {
        $this._eventPublisher = $eventPublisher
        $this._maxMemoryMB = 50
    }
    
    TaskCacheManager([object]$eventPublisher, [int]$maxMemoryMB) {
        $this._eventPublisher = $eventPublisher
        $this._maxMemoryMB = $maxMemoryMB
    }
    
    # Task caching methods
    [void] CacheTasks([string]$key, [array]$tasks, [int]$ttlSeconds) {
        $this.SetCacheEntry($key, $tasks, $ttlSeconds, "L1")
    }
    
    [void] CacheTasks([string]$key, [array]$tasks, [int]$ttlSeconds, [string]$level) {
        $this.SetCacheEntry($key, $tasks, $ttlSeconds, $level)
    }
    
    [array] GetCachedTasks([string]$key) {
        return $this.GetCacheEntry($key)
    }
    
    # Urgency caching methods
    [void] CacheUrgency([string]$key, [double]$urgency, [int]$ttlSeconds) {
        $this.SetCacheEntry($key, $urgency, $ttlSeconds, "L2")
    }
    
    [void] CacheUrgency([string]$key, [double]$urgency, [int]$ttlSeconds, [string]$level) {
        $this.SetCacheEntry($key, $urgency, $ttlSeconds, $level)
    }
    
    [double] GetCachedUrgency([string]$key) {
        return $this.GetCacheEntry($key)
    }
    
    # Formatted lines caching methods
    [void] CacheFormattedLines([string]$key, [array]$lines, [int]$ttlSeconds) {
        $this.SetCacheEntry($key, $lines, $ttlSeconds, "L3")
    }
    
    [void] CacheFormattedLines([string]$key, [array]$lines, [int]$ttlSeconds, [string]$level) {
        $this.SetCacheEntry($key, $lines, $ttlSeconds, $level)
    }
    
    [array] GetCachedFormattedLines([string]$key) {
        return $this.GetCacheEntry($key)
    }
    
    # Core cache operations
    hidden [void] SetCacheEntry([string]$key, [object]$data, [int]$ttlSeconds, [string]$level) {
        $entry = [CacheEntry]::new($data, $ttlSeconds, $level)
        
        # If this single entry exceeds our total memory limit, reject it
        $entrySizeMB = $entry.SizeBytes / 1MB
        if ($entrySizeMB -gt $this._maxMemoryMB) {
            # Entry is too large for cache, reject it
            return
        }
        
        # Check memory limits before caching
        if ($this.WouldExceedMemoryLimit($entry)) {
            $this.EvictOldEntries()
            # Check again after eviction
            if ($this.WouldExceedMemoryLimit($entry)) {
                # Still too big after eviction, reject
                return
            }
        }
        
        $this._cache[$key] = $entry
        
        # Publish cache event
        if ($this._eventPublisher) {
            $this._eventPublisher.Publish('CacheEntryAdded', @{
                Key = $key
                Level = $level
                SizeBytes = $entry.SizeBytes
                TTL = $ttlSeconds
            })
        }
    }
    
    hidden [object] GetCacheEntry([string]$key) {
        $this._statistics.TotalRequests++
        
        if (-not $this._cache.ContainsKey($key)) {
            $this._statistics.Misses++
            return $null
        }
        
        $entry = $this._cache[$key]
        
        if ($entry.IsExpired()) {
            $this._cache.Remove($key)
            $this._statistics.Misses++
            return $null
        }
        
        $this._statistics.Hits++
        return $entry.GetData()
    }
    
    [void] InvalidateCache([string]$key) {
        if ($this._cache.ContainsKey($key)) {
            $this._cache.Remove($key)
            
            if ($this._eventPublisher) {
                $this._eventPublisher.Publish('CacheEntryInvalidated', @{
                    Key = $key
                })
            }
        }
    }
    
    [void] InvalidateAll() {
        $this._cache.Clear()
        
        if ($this._eventPublisher) {
            $this._eventPublisher.Publish('CacheCleared', @{
                Timestamp = Get-Date
            })
        }
    }
    
    [void] InvalidateByPattern([string]$pattern) {
        $keysToRemove = @()
        foreach ($key in $this._cache.Keys) {
            if ($key -like $pattern) {
                $keysToRemove += $key
            }
        }
        
        foreach ($key in $keysToRemove) {
            $this.InvalidateCache($key)
        }
    }
    
    hidden [bool] WouldExceedMemoryLimit([CacheEntry]$newEntry) {
        $currentMemoryMB = $this.GetMemoryUsage().TotalMB
        $newSizeMB = $newEntry.SizeBytes / 1MB
        
        return ($currentMemoryMB + $newSizeMB) -gt $this._maxMemoryMB
    }
    
    hidden [void] EvictOldEntries() {
        # LRU eviction - remove least recently used entries
        $entries = @()
        foreach ($key in $this._cache.Keys) {
            $entries += @{
                Key = $key
                Entry = $this._cache[$key]
                LastAccess = $this._cache[$key].LastAccess
            }
        }
        
        # Sort by last access time (oldest first)
        $sorted = $entries | Sort-Object LastAccess
        
        # Only evict if we have entries
        $toRemove = 0
        if ($sorted -and $sorted.Count -gt 0) {
            # Remove oldest 25% of entries
            $toRemove = [math]::Max(1, [math]::Floor($sorted.Count * 0.25))
            
            for ($i = 0; $i -lt $toRemove; $i++) {
                $this._cache.Remove($sorted[$i].Key)
                $this._statistics.Evictions++
            }
        }
        
        if ($this._eventPublisher -and $toRemove -gt 0) {
            $this._eventPublisher.Publish('CacheEviction', @{
                EntriesRemoved = $toRemove
                Reason = 'MemoryPressure'
            })
        }
    }
    
    [hashtable] GetMemoryUsage() {
        $totalBytes = 0
        $entryCount = 0
        
        foreach ($entry in $this._cache.Values) {
            $totalBytes += $entry.SizeBytes
            $entryCount++
        }
        
        return @{
            TotalBytes = $totalBytes
            TotalMB = [math]::Round($totalBytes / 1MB, 2)
            EntryCount = $entryCount
        }
    }
    
    [hashtable] GetCacheStatistics() {
        $totalRequests = $this._statistics.TotalRequests
        $hits = $this._statistics.Hits
        $hitRate = if ($totalRequests -gt 0) { $hits / $totalRequests } else { 0 }
        
        return @{
            Hits = $hits
            Misses = $this._statistics.Misses
            Evictions = $this._statistics.Evictions
            TotalRequests = $totalRequests
            HitRate = [math]::Round($hitRate, 3)
            MemoryUsage = $this.GetMemoryUsage()
        }
    }
    
    [void] CleanupExpiredEntries() {
        $expiredKeys = @()
        foreach ($key in $this._cache.Keys) {
            if ($this._cache[$key].IsExpired()) {
                $expiredKeys += $key
            }
        }
        
        foreach ($key in $expiredKeys) {
            $this._cache.Remove($key)
        }
        
        if ($expiredKeys.Count -gt 0 -and $this._eventPublisher) {
            $this._eventPublisher.Publish('ExpiredEntriesCleanup', @{
                EntriesRemoved = $expiredKeys.Count
            })
        }
    }
}

# Integrated data manager that combines provider and cache
class IntegratedDataManager {
    hidden [object] $_provider  # TaskWarriorDataProvider
    hidden [TaskCacheManager] $_cache
    
    IntegratedDataManager([object]$provider, [TaskCacheManager]$cache) {
        $this._provider = $provider
        $this._cache = $cache
    }
    
    [array] GetTasks() {
        return $this.GetTasks("")
    }
    
    [array] GetTasks([string]$filter) {
        $cacheKey = if ($filter) { "tasks:$filter" } else { "tasks:all" }
        
        # Try cache first
        $cachedTasks = $this._cache.GetCachedTasks($cacheKey)
        if ($null -ne $cachedTasks) {
            return $cachedTasks
        }
        
        # Cache miss - load from provider
        $tasks = $this._provider.GetTasks($filter)
        
        # Cache the result for 60 seconds
        $this._cache.CacheTasks($cacheKey, $tasks, 60)
        
        return $tasks
    }
    
    [hashtable] SaveTask([hashtable]$task) {
        $result = $this._provider.SaveTask($task)
        
        if ($result.Success) {
            # Invalidate relevant cache entries
            $this._cache.InvalidateByPattern("tasks:*")
        }
        
        return $result
    }
    
    [hashtable] ValidateTask([hashtable]$task) {
        return $this._provider.ValidateTask($task)
    }
}