# Event System Implementation
# Implements publish/subscribe event handling

class EventPublisher {
    hidden [hashtable] $_subscribers = @{}
    hidden [System.Threading.ReaderWriterLockSlim] $_lock
    
    EventPublisher() {
        $this._lock = [System.Threading.ReaderWriterLockSlim]::new()
    }
    
    [void] Subscribe([string]$eventType, [scriptblock]$callback) {
        $this._lock.EnterWriteLock()
        try {
            if (-not $this._subscribers.ContainsKey($eventType)) {
                $this._subscribers[$eventType] = @()
            }
            $this._subscribers[$eventType] += $callback
        } finally {
            $this._lock.ExitWriteLock()
        }
    }
    
    [void] Unsubscribe([string]$eventType, [scriptblock]$callback) {
        $this._lock.EnterWriteLock()
        try {
            if ($this._subscribers.ContainsKey($eventType)) {
                $this._subscribers[$eventType] = $this._subscribers[$eventType] | Where-Object { $_ -ne $callback }
                if ($this._subscribers[$eventType].Count -eq 0) {
                    $this._subscribers.Remove($eventType)
                }
            }
        } finally {
            $this._lock.ExitWriteLock()
        }
    }
    
    [void] Publish([string]$eventType, [hashtable]$eventData) {
        $callbacks = @()
        
        $this._lock.EnterReadLock()
        try {
            if ($this._subscribers.ContainsKey($eventType)) {
                $callbacks = $this._subscribers[$eventType].Clone()
            }
        } finally {
            $this._lock.ExitReadLock()
        }
        
        # Execute callbacks outside of lock to prevent deadlocks
        foreach ($callback in $callbacks) {
            try {
                & $callback $eventData
            } catch {
                Write-Warning "Error in event callback for $eventType`: $($_.Exception.Message)"
            }
        }
    }
    
    [void] PublishAsync([string]$eventType, [hashtable]$eventData) {
        # For async publishing, we'll use background jobs
        $callbacks = @()
        
        $this._lock.EnterReadLock()
        try {
            if ($this._subscribers.ContainsKey($eventType)) {
                $callbacks = $this._subscribers[$eventType].Clone()
            }
        } finally {
            $this._lock.ExitReadLock()
        }
        
        # Execute callbacks in background
        foreach ($callback in $callbacks) {
            Start-Job -ScriptBlock {
                param($cb, $data)
                try {
                    & $cb $data
                } catch {
                    Write-Warning "Error in async event callback: $($_.Exception.Message)"
                }
            } -ArgumentList $callback, $eventData | Out-Null
        }
    }
    
    [array] GetSubscribers([string]$eventType) {
        $this._lock.EnterReadLock()
        try {
            if ($this._subscribers.ContainsKey($eventType)) {
                return $this._subscribers[$eventType].Clone()
            }
            return @()
        } finally {
            $this._lock.ExitReadLock()
        }
    }
    
    [int] GetSubscriberCount([string]$eventType) {
        $this._lock.EnterReadLock()
        try {
            if ($this._subscribers.ContainsKey($eventType)) {
                return $this._subscribers[$eventType].Count
            }
            return 0
        } finally {
            $this._lock.ExitReadLock()
        }
    }
    
    [void] ClearAllSubscriptions() {
        $this._lock.EnterWriteLock()
        try {
            $this._subscribers.Clear()
        } finally {
            $this._lock.ExitWriteLock()
        }
    }
    
    [void] Dispose() {
        if ($this._lock) {
            $this._lock.Dispose()
            $this._lock = $null
        }
    }
}

# Event filtering support
class EventFilter {
    hidden [string] $_eventType
    hidden [scriptblock] $_predicate
    
    EventFilter([string]$eventType, [scriptblock]$predicate) {
        $this._eventType = $eventType
        $this._predicate = $predicate
    }
    
    [bool] Matches([string]$eventType, [hashtable]$eventData) {
        if ($eventType -ne $this._eventType) {
            return $false
        }
        
        if ($this._predicate) {
            try {
                return & $this._predicate $eventData
            } catch {
                return $false
            }
        }
        
        return $true
    }
}

# Filtered event publisher
class FilteredEventPublisher : EventPublisher {
    hidden [System.Collections.Generic.List[object]] $_filters = @()
    
    FilteredEventPublisher() : base() {
    }
    
    [void] AddFilter([EventFilter]$filter) {
        $this._filters.Add($filter)
    }
    
    [void] RemoveFilter([EventFilter]$filter) {
        $this._filters.Remove($filter)
    }
    
    [void] Publish([string]$eventType, [hashtable]$eventData) {
        # Check if event passes all filters
        foreach ($filter in $this._filters) {
            if (-not $filter.Matches($eventType, $eventData)) {
                return  # Event filtered out
            }
        }
        
        # Event passed filters, publish normally
        ([EventPublisher]$this).Publish($eventType, $eventData)
    }
}