# Virtual Scrolling Implementation
# Efficient rendering of large datasets by only rendering visible items

# Virtual data source that provides efficient access to large datasets
class VirtualDataSource {
    hidden [array] $_data
    hidden [int] $_totalCount
    hidden [scriptblock] $_filter = $null
    hidden [array] $_filteredIndices = $null
    hidden [bool] $_isFiltered = $false
    
    VirtualDataSource([array]$data) {
        $this._data = $data
        $this._totalCount = $data.Count
    }
    
    [int] GetTotalCount() {
        if ($this._isFiltered) {
            return $this._filteredIndices.Count
        }
        return $this._totalCount
    }
    
    [object] GetItem([int]$index) {
        if ($this._isFiltered) {
            if ($index -lt 0 -or $index -ge $this._filteredIndices.Count) {
                return $null
            }
            $actualIndex = $this._filteredIndices[$index]
            return $this._data[$actualIndex]
        } else {
            if ($index -lt 0 -or $index -ge $this._totalCount) {
                return $null
            }
            return $this._data[$index]
        }
    }
    
    [array] GetRange([int]$startIndex, [int]$count) {
        $result = @()
        $endIndex = [math]::Min($startIndex + $count - 1, $this.GetTotalCount() - 1)
        
        for ($i = $startIndex; $i -le $endIndex; $i++) {
            $item = $this.GetItem($i)
            if ($null -ne $item) {
                $result += $item
            }
        }
        
        return $result
    }
    
    [void] SetFilter([scriptblock]$filter) {
        $this._filter = $filter
        if ($null -eq $filter) {
            $this._isFiltered = $false
            $this._filteredIndices = $null
        } else {
            $this.ApplyFilter()
        }
    }
    
    hidden [void] ApplyFilter() {
        $this._filteredIndices = @()
        
        for ($i = 0; $i -lt $this._totalCount; $i++) {
            $item = $this._data[$i]
            if ($this._filter.Invoke($item)) {
                $this._filteredIndices += $i
            }
        }
        
        $this._isFiltered = $true
    }
    
    [int] GetFilteredCount() {
        if ($this._isFiltered) {
            return $this._filteredIndices.Count
        }
        return $this._totalCount
    }
    
    [void] ClearFilter() {
        $this._filter = $null
        $this._filteredIndices = $null
        $this._isFiltered = $false
    }
}

# Virtual scrolling viewport that manages what's visible
class VirtualScrollingViewport {
    hidden [int] $_width
    hidden [int] $_height
    hidden [int] $_scrollPosition = 0
    hidden [VirtualDataSource] $_dataSource
    hidden [object] $_itemRenderer  # TaskRenderer
    hidden [object] $_eventPublisher  # EventPublisher
    hidden [array] $_visibleItems = @()
    hidden [array] $_previousVisibleItems = @()
    
    VirtualScrollingViewport([int]$width, [int]$height) {
        $this._width = $width
        $this._height = $height
        $this.Width = $width
        $this.Height = $height
    }
    
    VirtualScrollingViewport([int]$width, [int]$height, [object]$eventPublisher) {
        $this._width = $width
        $this._height = $height
        $this._eventPublisher = $eventPublisher
        $this.Width = $width
        $this.Height = $height
    }
    
    [int] GetWidth() { return $this._width }
    [int] GetHeight() { return $this._height }
    
    # Properties for test access
    [int] $Width
    [int] $Height
    
    [void] SetDataSource([VirtualDataSource]$dataSource) {
        $this._dataSource = $dataSource
        $this.UpdateVisibleItems()
    }
    
    [void] SetItemRenderer([object]$renderer) {
        $this._itemRenderer = $renderer
    }
    
    [int] GetTotalItemCount() {
        if ($null -eq $this._dataSource) {
            return 0
        }
        return $this._dataSource.GetTotalCount()
    }
    
    [int] GetScrollPosition() {
        return $this._scrollPosition
    }
    
    [int] GetMaxScrollPosition() {
        $totalItems = $this.GetTotalItemCount()
        return [math]::Max(0, $totalItems - $this._height)
    }
    
    [void] ScrollTo([int]$position) {
        $oldPosition = $this._scrollPosition
        
        # Clamp position to valid range
        $maxScroll = $this.GetMaxScrollPosition()
        $this._scrollPosition = [math]::Max(0, [math]::Min($position, $maxScroll))
        
        if ($this._scrollPosition -ne $oldPosition) {
            $this.UpdateVisibleItems()
            $this.PublishScrollEvent($oldPosition, $this._scrollPosition)
        }
    }
    
    [void] ScrollBy([int]$delta) {
        $this.ScrollTo($this._scrollPosition + $delta)
    }
    
    [array] GetVisibleItems() {
        return $this._visibleItems
    }
    
    hidden [void] UpdateVisibleItems() {
        if ($null -eq $this._dataSource) {
            $this._visibleItems = @()
            return
        }
        
        $this._previousVisibleItems = $this._visibleItems
        $this._visibleItems = $this._dataSource.GetRange($this._scrollPosition, $this._height)
        
        $this.PublishVisibilityChanges()
    }
    
    hidden [void] PublishScrollEvent([int]$oldPosition, [int]$newPosition) {
        if ($null -ne $this._eventPublisher) {
            $this._eventPublisher.Publish('ViewportScrolled', @{
                OldPosition = $oldPosition
                NewPosition = $newPosition
                ScrollPosition = $newPosition
                MaxPosition = $this.GetMaxScrollPosition()
                TotalItems = $this.GetTotalItemCount()
            })
        }
    }
    
    hidden [void] PublishVisibilityChanges() {
        if ($null -ne $this._eventPublisher) {
            # Find items that became visible/invisible
            $previousIds = @()
            $currentIds = @()
            
            foreach ($item in $this._previousVisibleItems) {
                if ($item -and $item.ContainsKey('id')) {
                    $previousIds += $item.id
                }
            }
            
            foreach ($item in $this._visibleItems) {
                if ($item -and $item.ContainsKey('id')) {
                    $currentIds += $item.id
                }
            }
            
            # Items that became visible
            $newlyVisible = $currentIds | Where-Object { $_ -notin $previousIds }
            # Items that became invisible
            $newlyInvisible = $previousIds | Where-Object { $_ -notin $currentIds }
            
            if ($newlyVisible.Count -gt 0 -or $newlyInvisible.Count -gt 0) {
                $this._eventPublisher.Publish('ItemVisibilityChanged', @{
                    NewlyVisible = $newlyVisible
                    NewlyInvisible = $newlyInvisible
                    TotalVisible = $currentIds.Count
                })
            }
        }
    }
    
    [void] RenderToBuffer([object]$buffer) {
        if ($null -eq $this._itemRenderer -or $null -eq $buffer) {
            return
        }
        
        $row = 0
        foreach ($item in $this._visibleItems) {
            if ($row -ge $this._height) {
                break
            }
            
            $formattedLines = $this._itemRenderer.FormatItem($item, $this._width)
            
            # Handle single line or multi-line output
            if ($formattedLines -is [array]) {
                foreach ($line in $formattedLines) {
                    if ($row -ge $this._height) {
                        break
                    }
                    $buffer.SetLine($row, $line)
                    $row++
                }
            } else {
                $buffer.SetLine($row, $formattedLines)
                $row++
            }
        }
        
        # Clear any remaining lines in viewport
        for ($i = $row; $i -lt $this._height; $i++) {
            $buffer.SetLine($i, "")
        }
    }
}

# Task renderer for formatting individual task items
class TaskRenderer {
    hidden [hashtable] $_colorScheme = @{
        'pending' = "$([char]27)[37m"      # White
        'completed' = "$([char]27)[32m"    # Green  
        'waiting' = "$([char]27)[33m"      # Yellow
        'deleted' = "$([char]27)[90m"      # Dark gray
        'reset' = "$([char]27)[0m"         # Reset
    }
    
    hidden [hashtable] $_urgencyColors = @{
        'low' = "$([char]27)[36m"          # Cyan (urgency < 5)
        'medium' = "$([char]27)[37m"       # White (urgency 5-8)
        'high' = "$([char]27)[31m"         # Red (urgency > 8)
    }
    
    TaskRenderer() {
        # Initialize with default color scheme
    }
    
    [object] FormatItem([hashtable]$task, [int]$width) {
        $description = $task.description
        $status = if ($task.status) { $task.status } else { 'pending' }
        $urgency = if ($task.urgency) { $task.urgency } else { 0.0 }
        $project = if ($task.project) { $task.project } else { '' }
        $tags = if ($task.tags) { $task.tags } else { @() }
        
        # Choose colors based on status and urgency
        $statusColor = $this._colorScheme[$status]
        if (-not $statusColor) {
            $statusColor = $this._colorScheme['pending']
        }
        
        $urgencyColor = if ($urgency -gt 8) { 
            $this._urgencyColors['high'] 
        } elseif ($urgency -ge 5) { 
            $this._urgencyColors['medium'] 
        } else { 
            $this._urgencyColors['low'] 
        }
        
        # Build the display line
        $idPart = "$('{0,4}' -f $task.id)"
        $statusPart = "[$status]"
        $urgencyPart = "($('{0:F1}' -f $urgency))"
        
        # Project and tags
        $projectPart = if ($project) { " @$project" } else { '' }
        $tagsPart = if ($tags.Count -gt 0) { " +" + ($tags -join " +") } else { '' }
        
        # Calculate available space for description
        $metadataLength = $idPart.Length + $statusPart.Length + $urgencyPart.Length + $projectPart.Length + $tagsPart.Length + 4  # spaces
        $descriptionSpace = $width - $metadataLength
        
        if ($descriptionSpace -le 10) {
            # Very narrow, just show ID and description
            $descriptionSpace = $width - $idPart.Length - 2
        }
        
        # Handle text wrapping for long descriptions
        if ($description.Length -le $descriptionSpace) {
            # Fits on one line
            $line = "$statusColor$idPart $statusPart $urgencyColor$urgencyPart$statusColor $description$projectPart$tagsPart$($this._colorScheme['reset'])"
            return $line
        } else {
            # Needs wrapping
            $lines = @()
            
            # First line with metadata
            $truncatedDesc = $description.Substring(0, [math]::Min($description.Length, $descriptionSpace - 3)) + "..."
            $firstLine = "$statusColor$idPart $statusPart $urgencyColor$urgencyPart$statusColor $truncatedDesc$($this._colorScheme['reset'])"
            $lines += $firstLine
            
            # Additional lines for wrapped text (if space allows)
            $remainingDesc = $description.Substring([math]::Min($description.Length, $descriptionSpace - 3))
            if ($remainingDesc.Length -gt 0) {
                $indent = " " * ($idPart.Length + 2)
                while ($remainingDesc.Length -gt 0 -and $lines.Count -lt 3) {  # Limit to 3 lines total
                    $chunkSize = [math]::Min($remainingDesc.Length, $width - $indent.Length)
                    $chunk = $remainingDesc.Substring(0, $chunkSize)
                    $lines += "$statusColor$indent$chunk$($this._colorScheme['reset'])"
                    $remainingDesc = $remainingDesc.Substring($chunkSize)
                }
            }
            
            # Add project and tags to last line if they fit
            if ($lines.Count -gt 0 -and ($projectPart.Length + $tagsPart.Length) -gt 0) {
                $lastLineIndex = $lines.Count - 1
                $availableSpace = $width - $lines[$lastLineIndex].Length + ($this._colorScheme['reset']).Length  # Account for color reset
                if ($availableSpace -ge ($projectPart.Length + $tagsPart.Length)) {
                    $lines[$lastLineIndex] = $lines[$lastLineIndex].Replace($this._colorScheme['reset'], "$projectPart$tagsPart$($this._colorScheme['reset'])")
                }
            }
            
            return $lines
        }
    }
    
    [void] SetColorScheme([hashtable]$colorScheme) {
        foreach ($key in $colorScheme.Keys) {
            $this._colorScheme[$key] = $colorScheme[$key]
        }
    }
    
    [hashtable] GetColorScheme() {
        return $this._colorScheme.Clone()
    }
}