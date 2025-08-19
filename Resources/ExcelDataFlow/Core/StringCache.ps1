# StringCache.ps1 - Pre-cached strings for common rendering patterns
# COPIED FROM PRAXIS - ACTUAL WORKING VERSION

class StringCache {
    # Cache for space strings of various lengths
    static [hashtable]$Spaces = @{}
    
    # Cache for horizontal line strings
    static [hashtable]$HLines = @{}
    
    # Maximum cached length
    static [int]$MaxCacheLength = 200
    
    # Initialize the cache with common sizes
    static [void] Initialize() {
        # Pre-populate common sizes for spaces
        for ($i = 1; $i -le [StringCache]::MaxCacheLength; $i++) {
            [StringCache]::Spaces[$i] = " " * $i
        }
        
        # Pre-populate common sizes for horizontal lines
        for ($i = 1; $i -le [StringCache]::MaxCacheLength; $i++) {
            [StringCache]::HLines[$i] = "─" * $i
        }
    }
    
    # Get spaces of specified width
    static [string] GetSpaces([int]$width) {
        if ($width -le 0) { return "" }
        if ($width -le [StringCache]::MaxCacheLength) {
            return [StringCache]::Spaces[$width]
        }
        # For larger widths, build dynamically
        return " " * $width
    }
    
    # Get horizontal lines of specified width
    static [string] GetHorizontalLine([int]$width) {
        if ($width -le 0) { return "" }
        if ($width -le [StringCache]::MaxCacheLength) {
            return [StringCache]::HLines[$width]
        }
        # For larger widths, build dynamically
        return "─" * $width
    }
    
    # Get repeated character string
    static [string] GetRepeatedChar([char]$char, [int]$count) {
        if ($count -le 0) { return "" }
        if ($char -eq ' ' -and $count -le [StringCache]::MaxCacheLength) {
            return [StringCache]::Spaces[$count]
        }
        if ($char -eq '─' -and $count -le [StringCache]::MaxCacheLength) {
            return [StringCache]::HLines[$count]
        }
        # For other characters or large counts, build dynamically
        return [string]$char * $count
    }
}

# Initialize the cache on module load
[StringCache]::Initialize()

# Simple pooled string builder functions for compatibility
function Get-PooledStringBuilder([int]$initialCapacity = 256) {
    return [System.Text.StringBuilder]::new($initialCapacity)
}

function Return-PooledStringBuilder([System.Text.StringBuilder]$sb) {
    # In a real pool implementation, this would return the builder to a pool
    # For simplicity, we just do nothing here
}