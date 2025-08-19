# SearchableListBox.ps1 - ListBox with built-in search/filter functionality
# High-performance search with real-time filtering

class SearchableListBox : UIElement {
    [System.Collections.ArrayList]$Items
    [System.Collections.ArrayList]$_filteredItems
    [int]$SelectedIndex = 0
    [int]$ScrollOffset = 0
    [bool]$ShowBorder = $true
    [string]$Title = ""
    [string]$SearchQuery = ""
    [bool]$ShowSearchBox = $true
    [bool]$CaseSensitive = $false
    [bool]$UseRegex = $false
    [scriptblock]$ItemRenderer = $null
    [scriptblock]$OnSelectionChanged = {}
    [scriptblock]$OnItemActivated = {}
    
    # Search configuration
    [int]$MinSearchLength = 0  # Start filtering immediately
    [bool]$SearchInDescription = $false
    [scriptblock]$SearchFilter = $null  # Custom filter function
    
    # Visual settings
    [string]$SearchPrompt = "Search: "
    [string]$NoResultsText = "No items found"
    [string]$SearchIcon = "🔍"  # Search icon
    [char[]]$ExcludedSearchKeys = @('n', 'e', 'd')  # Keys that should not trigger search mode
    
    hidden [ThemeManager]$Theme
    hidden [string]$_cachedRender = ""
    hidden [int]$_searchBoxHeight = 3
    hidden [bool]$_searchMode = $false
    hidden [int]$_lastFilteredCount = -1
    hidden [System.Collections.Generic.HashSet[string]]$_highlightCache
    hidden [hashtable]$_colors = @{}
    
    SearchableListBox() : base() {
        $this.Items = [System.Collections.ArrayList]::new()
        $this._filteredItems = [System.Collections.ArrayList]::new()
        $this._highlightCache = [System.Collections.Generic.HashSet[string]]::new()
        $this.IsFocusable = $true
    }
    
    [void] Initialize([ServiceContainer]$services) {
        $this.Theme = $services.GetService("ThemeManager")
        if ($this.Theme) {
            # Subscribe to EventBus theme changes instead of legacy ThemeManager subscription
            $eventBus = $services.GetService('EventBus')
            if ($eventBus) {
                $component = $this
                $eventBus.Subscribe('theme.changed', {
                    $component.OnThemeChanged()
                }.GetNewClosure())
            }
            $this.OnThemeChanged()
        }
        $this.ApplyFilter()
    }
    
    # Island Components Theme Interface - Cache all colors this component uses
    [void] OnThemeChanged() {
        if ($this.Theme) {
            $this._colors = @{
                'border' = $this.Theme.GetColor('border.normal')
                'title' = $this.Theme.GetColor('text.heading')
                'selected' = $this.Theme.GetBgColor("menu.background.selected")
                'normal' = $this.Theme.GetColor('text.primary')
                # 'background' = removed to prevent grey bleed
                'search' = $this.Theme.GetColor("search.background")
                'highlight' = $this.Theme.GetColor("highlight.background")
                'border.focused' = $this.Theme.GetColor("border.focused")
                'selectedText' = $this.Theme.GetColor('menu.text.selected')
                'accent' = $this.Theme.GetColor('color.primary')
            }
        }
        $this._cachedRender = ""
        $this.Invalidate()
    }
    
    [void] Invalidate() {
        $this._cachedRender = ""
        ([UIElement]$this).Invalidate()
    }
    
    # Public API
    [void] SetItems($items) {
        $this.Items.Clear()
        if ($items) {
            foreach ($item in $items) {
                $this.Items.Add($item) | Out-Null
            }
        }
        $this.ApplyFilter()
        $this.SelectedIndex = 0
        $this.ScrollOffset = 0
        $this.Invalidate()
    }
    
    [void] AddItem($item) {
        $this.Items.Add($item) | Out-Null
        $this.ApplyFilter()
        $this.Invalidate()
    }
    
    [void] RemoveItem($item) {
        $this.Items.Remove($item) | Out-Null
        $this.ApplyFilter()
        $this.EnsureSelectionValid()
        $this.Invalidate()
    }
    
    [object] GetSelectedItem() {
        if ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this._filteredItems.Count) {
            return $this._filteredItems[$this.SelectedIndex]
        }
        return $null
    }
    
    [void] SelectIndex([int]$index) {
        if ($index -ge 0 -and $index -lt $this._filteredItems.Count) {
            $oldIndex = $this.SelectedIndex
            $this.SelectedIndex = $index
            $this.EnsureVisible()
            
            if ($oldIndex -ne $this.SelectedIndex -and $this.OnSelectionChanged) {
                & $this.OnSelectionChanged
            }
            
            $this.Invalidate()
        }
    }
    
    [void] SetSearchQuery([string]$query) {
        if ($this.SearchQuery -ne $query) {
            $this.SearchQuery = $query
            $this.ApplyFilter()
            $this.SelectedIndex = 0  # Reset to top when search changes
            $this.ScrollOffset = 0
            $this.Invalidate()
        }
    }
    
    [void] ClearSearch() {
        $this.SetSearchQuery("")
    }
    
    [void] EnterSearchMode() {
        $this._searchMode = $true
        $this.Invalidate()
    }
    
    [void] ExitSearchMode() {
        $this._searchMode = $false
        $this.Invalidate()
    }
    
    [void] ToggleSearchMode() {
        $this._searchMode = -not $this._searchMode
        $this.Invalidate()
    }
    
    # Internal methods
    [void] ApplyFilter() {
        $this._filteredItems.Clear()
        $this._highlightCache.Clear()
        
        # If no search query, show all items
        if ([string]::IsNullOrEmpty($this.SearchQuery) -or $this.SearchQuery.Length -lt $this.MinSearchLength) {
            foreach ($item in $this.Items) {
                $this._filteredItems.Add($item) | Out-Null
            }
        } else {
            # Apply filtering - optimize by pre-calculating normalized query
            $normalizedQuery = if ($this.CaseSensitive) { $this.SearchQuery } else { $this.SearchQuery.ToLower() }
            foreach ($item in $this.Items) {
                if ($this.MatchesSearchOptimized($item, $this.SearchQuery, $normalizedQuery)) {
                    $this._filteredItems.Add($item) | Out-Null
                }
            }
        }
        
        $this._lastFilteredCount = $this._filteredItems.Count
        $this.EnsureSelectionValid()
    }
    
    # Optimized version that avoids repeated ToLower() calls
    [bool] MatchesSearchOptimized($item, [string]$query, [string]$normalizedQuery) {
        # Custom filter takes precedence
        if ($this.SearchFilter) {
            try {
                return & $this.SearchFilter $item $query
            } catch {
                # Fall back to default behavior on error
            }
        }
        
        # Get searchable text from item
        $searchText = $this.GetSearchableText($item)
        
        if ([string]::IsNullOrEmpty($searchText)) {
            return $false
        }
        
        # Apply case sensitivity using pre-normalized query
        if (-not $this.CaseSensitive) {
            $searchText = $searchText.ToLower()
            $query = $normalizedQuery  # Use pre-normalized query
        }
        
        # Apply search logic
        if ($this.UseRegex) {
            try {
                return $searchText -match $query
            } catch {
                return $false
            }
        } else {
            return $searchText.Contains($query)
        }
    }

    [bool] MatchesSearch($item, [string]$query) {
        # Custom filter takes precedence
        if ($this.SearchFilter) {
            try {
                return & $this.SearchFilter $item $query
            } catch {
                # Fall back to default behavior on error
            }
        }
        
        # Get searchable text from item
        $searchText = $this.GetSearchableText($item)
        
        if ([string]::IsNullOrEmpty($searchText)) {
            return $false
        }
        
        # Apply case sensitivity
        if (-not $this.CaseSensitive) {
            $searchText = $searchText.ToLower()
            $query = $query.ToLower()
        }
        
        # Apply search logic
        if ($this.UseRegex) {
            try {
                return $searchText -match $query
            } catch {
                # Invalid regex, fall back to simple contains
                return $searchText -like "*$query*"
            }
        } else {
            # Simple contains search
            return $searchText -like "*$query*"
        }
    }
    
    [string] GetSearchableText($item) {
        if ($item -eq $null) {
            return ""
        }
        
        # If item has a specific string representation method
        if ($item.PSObject.Methods['ToString'] -and $item.ToString() -ne $item.GetType().FullName) {
            return $item.ToString()
        }
        
        # If it's a hashtable or PSObject, try common text properties
        if ($item -is [hashtable]) {
            $textProps = @('Name', 'Title', 'Text', 'Description', 'Label')
            foreach ($prop in $textProps) {
                if ($item.ContainsKey($prop) -and $item[$prop]) {
                    return $item[$prop].ToString()
                }
            }
            # Fall back to all values if SearchInDescription is enabled
            if ($this.SearchInDescription) {
                return ($item.Values -join ' ')
            }
        }
        
        # Try common properties for objects
        $textProps = @('Name', 'Title', 'Text', 'Description', 'Label')
        foreach ($prop in $textProps) {
            $value = $item.PSObject.Properties[$prop]
            if ($value -and $value.Value) {
                return $value.Value.ToString()
            }
        }
        
        # Fall back to string conversion
        return $item.ToString()
    }
    
    [void] EnsureSelectionValid() {
        if ($this.SelectedIndex -ge $this._filteredItems.Count) {
            $this.SelectedIndex = [Math]::Max(0, $this._filteredItems.Count - 1)
        }
        if ($this.SelectedIndex -lt 0 -and $this._filteredItems.Count -gt 0) {
            $this.SelectedIndex = 0
        }
    }
    
    [void] EnsureVisible() {
        $contentHeight = $this.Height - ($this.ShowBorder ? 2 : 0) - ($this.Title ? 1 : 0)
        if ($this.ShowSearchBox) {
            $contentHeight -= $this._searchBoxHeight
        }
        
        if ($this.SelectedIndex -lt $this.ScrollOffset) {
            $this.ScrollOffset = $this.SelectedIndex
        } elseif ($this.SelectedIndex -ge $this.ScrollOffset + $contentHeight) {
            $this.ScrollOffset = $this.SelectedIndex - $contentHeight + 1
        }
        
        $this.ScrollOffset = [Math]::Max(0, $this.ScrollOffset)
    }
    
    # Rendering
    [string] OnRender() {
        if ([string]::IsNullOrEmpty($this._cachedRender)) {
            $this.RebuildCache()
        }
        return $this._cachedRender
    }
    
    [void] RebuildCache() {
        $sb = Get-PooledStringBuilder 2048  # SearchableListBox with search box and items
        
        # Colors from cache
        $borderColor = $this._colors['border']
        $titleColor = $this._colors['title']
        $selectedBg = $this._colors['selected']
        $normalColor = $this._colors['normal']
        $bgColor = ''  # No background to prevent grey bleed
        $searchColor = if ($this._colors['search']) { $this._colors['search'] } else { $normalColor }
        $highlightColor = if ($this._colors['highlight']) { $this._colors['highlight'] } else { $this.Theme.GetColor('color.primary') }
        $focusBorder = if ($this._colors['border.focused']) { $this._colors['border.focused'] } else { $borderColor }
        
        $currentBorderColor = if ($this.IsFocused) { $focusBorder } else { $borderColor }
        
        # Calculate content area
        $contentY = $this.Y
        $contentHeight = $this.Height
        $contentWidth = [Math]::Max(1, $this.Width - ($this.ShowBorder ? 2 : 0))
        
        if ($this.ShowBorder) {
            # Top border
            $sb.Append([VT]::MoveTo($this.X, $this.Y))
            $sb.Append($currentBorderColor)
            # Island Components: use spaces instead of horizontal lines
            $sb.Append([VT]::TL() + [StringCache]::GetVTHorizontalNoLines($this.Width - 2) + [VT]::TR())
            $contentY++
            $contentHeight--
            
            # Title
            if ($this.Title) {
                $sb.Append([VT]::MoveTo($this.X + 1, $contentY))
                $sb.Append($titleColor)
                $titleText = "$($this.Title)"
                if ($this._filteredItems.Count -ne $this.Items.Count) {
                    $titleText += " ($($this._filteredItems.Count)/$($this.Items.Count))"
                }
                $titleLine = if ($contentWidth -le 0) { "" } else { $titleText.PadRight($contentWidth).Substring(0, $contentWidth) }
                $sb.Append($titleLine)
                $contentY++
                $contentHeight--
            }
        } else {
            # Title without border
            if ($this.Title) {
                $sb.Append([VT]::MoveTo($this.X, $contentY))
                $sb.Append($titleColor)
                $titleText = "$($this.Title)"
                if ($this._filteredItems.Count -ne $this.Items.Count) {
                    $titleText += " ($($this._filteredItems.Count)/$($this.Items.Count))"
                }
                $titleLine = if ($this.Width -le 0) { "" } else { $titleText.PadRight($this.Width).Substring(0, $this.Width) }
                $sb.Append($titleLine)
                $contentY++
                $contentHeight--
            }
        }
        
        # Search box
        if ($this.ShowSearchBox) {
            $sb.Append([VT]::MoveTo($this.X + ($this.ShowBorder ? 1 : 0), $contentY))
            $sb.Append($searchColor)
            
            $searchText = "$($this.SearchIcon) $($this.SearchPrompt)$($this.SearchQuery)"
            if ($this._searchMode) {
                $searchText += "|"  # Cursor indicator
            }
            
            $searchLine = if ($contentWidth -le 0) { "" } else { $searchText.PadRight($contentWidth).Substring(0, $contentWidth) }
            $sb.Append($searchLine)
            $contentY++
            $contentHeight--
            
            # Search box separator
            $sb.Append([VT]::MoveTo($this.X + ($this.ShowBorder ? 1 : 0), $contentY))
            $sb.Append($borderColor)
            # Island Components: use spaces instead of horizontal lines
            $sb.Append([StringCache]::GetVTHorizontalNoLines($contentWidth))
            $contentY++
            $contentHeight--
            
            # Side borders for search area
            if ($this.ShowBorder) {
                for ($y = $contentY - 2; $y -lt $contentY; $y++) {
                    $sb.Append([VT]::MoveTo($this.X, $y))
                    $sb.Append($currentBorderColor)
                    $sb.Append([VT]::V())
                    
                    $sb.Append([VT]::MoveTo($this.X + $this.Width - 1, $y))
                    $sb.Append($currentBorderColor)
                    $sb.Append([VT]::V())
                }
            }
        }
        
        # List content
        $visibleLines = $contentHeight - ($this.ShowBorder ? 1 : 0)  # Reserve bottom border
        $startIndex = $this.ScrollOffset
        $endIndex = [Math]::Min($startIndex + $visibleLines, $this._filteredItems.Count)
        
        if ($this._filteredItems.Count -eq 0) {
            # Fill all empty lines first
            for ($i = 0; $i -lt $visibleLines; $i++) {
                $y = $contentY + $i
                $sb.Append([VT]::MoveTo($this.X + ($this.ShowBorder ? 1 : 0), $y))
                $sb.Append($normalColor)
                $sb.Append($bgColor)
                $sb.Append([StringCache]::GetSpaces($contentWidth))
                
                if ($this.ShowBorder) {
                    $sb.Append([VT]::MoveTo($this.X, $y))
                    $sb.Append($currentBorderColor)
                    $sb.Append([VT]::V())
                    
                    $sb.Append([VT]::MoveTo($this.X + $this.Width - 1, $y))
                    $sb.Append($currentBorderColor)
                    $sb.Append([VT]::V())
                }
            }
            
            # No results message centered in the content area
            if ($visibleLines -gt 0) {
                $noResultsY = $contentY + [int]($visibleLines / 2)
                $messageX = $this.X + ($this.ShowBorder ? 1 : 0) + [Math]::Max(0, [int](($contentWidth - $this.NoResultsText.Length) / 2))
                $sb.Append([VT]::MoveTo($messageX, $noResultsY))
                $sb.Append($normalColor)
                $sb.Append($bgColor)
                $sb.Append($this.NoResultsText)
            }
        } else {
            # Render items
            for ($i = $startIndex; $i -lt $endIndex; $i++) {
                $item = $this._filteredItems[$i]
                $y = $contentY + ($i - $startIndex)
                
                $sb.Append([VT]::MoveTo($this.X + ($this.ShowBorder ? 1 : 0), $y))
                
                # Background for selected item
                if ($i -eq $this.SelectedIndex) {
                    $sb.Append($selectedBg)
                } else {
                    $sb.Append($normalColor)
                    $sb.Append($bgColor)
                }
                
                # Get display text
                $displayText = if ($this.ItemRenderer) {
                    & $this.ItemRenderer $item
                } else {
                    $this.GetSearchableText($item)
                }
                
                # Highlight search terms
                if (-not [string]::IsNullOrEmpty($this.SearchQuery) -and $displayText) {
                    $displayText = $this.HighlightSearchTerms($displayText, $highlightColor, $normalColor)
                }
                
                # Pad and truncate to fit
                if ($displayText.Length -gt $contentWidth) {
                    $displayText = $displayText.Substring(0, $contentWidth - 3) + "..."
                }
                $displayLine = if ($contentWidth -le 0) { "" } else { $displayText.PadRight($contentWidth).Substring(0, $contentWidth) }
                $sb.Append($displayLine)
                
                # Side borders
                if ($this.ShowBorder) {
                    $sb.Append([VT]::MoveTo($this.X, $y))
                    $sb.Append($currentBorderColor)
                    $sb.Append([VT]::V())
                    
                    $sb.Append([VT]::MoveTo($this.X + $this.Width - 1, $y))
                    $sb.Append($currentBorderColor)
                    $sb.Append([VT]::V())
                }
            }
        }
        
        # Fill empty lines
        for ($i = $endIndex - $startIndex; $i -lt $visibleLines; $i++) {
            $y = $contentY + $i
            $sb.Append([VT]::MoveTo($this.X + ($this.ShowBorder ? 1 : 0), $y))
            $sb.Append($normalColor)
            $sb.Append($bgColor)
            $sb.Append([StringCache]::GetSpaces($contentWidth))
            
            if ($this.ShowBorder) {
                $sb.Append([VT]::MoveTo($this.X, $y))
                $sb.Append($currentBorderColor)
                $sb.Append([VT]::V())
                
                $sb.Append([VT]::MoveTo($this.X + $this.Width - 1, $y))
                $sb.Append($currentBorderColor)
                $sb.Append([VT]::V())
            }
        }
        
        if ($this.ShowBorder) {
            # Bottom border
            $bottomY = $this.Y + $this.Height - 1
            $sb.Append([VT]::MoveTo($this.X, $bottomY))
            $sb.Append($currentBorderColor)
            # Island Components: use spaces instead of horizontal lines
            $sb.Append([VT]::BL() + [StringCache]::GetVTHorizontalNoLines($this.Width - 2) + [VT]::BR())
        }

        $this._cachedRender = $sb.ToString()
        Return-PooledStringBuilder $sb  # Return to pool for reuse
    }
    
    [string] HighlightSearchTerms([string]$text, [string]$highlightColor, [string]$normalColor) {
        if ([string]::IsNullOrEmpty($this.SearchQuery)) {
            return $text
        }
        
        # Simple highlighting - replace matches with colored versions
        try {
            $query = $this.SearchQuery
            if (-not $this.CaseSensitive) {
                # Case-insensitive replacement
                return [regex]::Replace($text, [regex]::Escape($query), "$highlightColor`$0$normalColor", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            } else {
                return $text.Replace($query, "$highlightColor$query$normalColor")
            }
        } catch {
            # If highlighting fails, return original text
            return $text
        }
    }
    
    # Input handling
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        $handled = $false
        $oldIndex = $this.SelectedIndex
        
        # Search mode input
        if ($this._searchMode) {
            switch ($key.Key) {
                ([System.ConsoleKey]::Escape) {
                    $this.ExitSearchMode()
                    $handled = $true
                }
                ([System.ConsoleKey]::Enter) {
                    $this.ExitSearchMode()
                    $handled = $true
                }
                ([System.ConsoleKey]::Backspace) {
                    if ($this.SearchQuery.Length -gt 0) {
                        $this.SetSearchQuery($this.SearchQuery.Substring(0, $this.SearchQuery.Length - 1))
                    }
                    $handled = $true
                }
                default {
                    if ($key.KeyChar -ge 32 -and $key.KeyChar -lt 127) {  # Printable characters
                        $this.SetSearchQuery($this.SearchQuery + $key.KeyChar)
                        $handled = $true
                    }
                }
            }
        } else {
            # Normal navigation mode
            switch ($key.Key) {
                ([System.ConsoleKey]::UpArrow) {
                    if ($this.SelectedIndex -gt 0) {
                        $this.SelectedIndex--
                        $handled = $true
                    }
                }
                ([System.ConsoleKey]::DownArrow) {
                    if ($this.SelectedIndex -lt $this._filteredItems.Count - 1) {
                        $this.SelectedIndex++
                        $handled = $true
                    }
                }
                ([System.ConsoleKey]::PageUp) {
                    $pageSize = $this.Height - 5
                    $this.SelectedIndex = [Math]::Max(0, $this.SelectedIndex - $pageSize)
                    $handled = $true
                }
                ([System.ConsoleKey]::PageDown) {
                    $pageSize = $this.Height - 5
                    $this.SelectedIndex = [Math]::Min($this._filteredItems.Count - 1, $this.SelectedIndex + $pageSize)
                    $handled = $true
                }
                ([System.ConsoleKey]::Home) {
                    $this.SelectedIndex = 0
                    $handled = $true
                }
                ([System.ConsoleKey]::End) {
                    $this.SelectedIndex = [Math]::Max(0, $this._filteredItems.Count - 1)
                    $handled = $true
                }
                ([System.ConsoleKey]::F3) {
                    $this.ToggleSearchMode()
                    $handled = $true
                }
                ([System.ConsoleKey]::Enter) {
                    if ($this.OnItemActivated -and $this._filteredItems.Count -gt 0 -and $this.SelectedIndex -ge 0) {
                        & $this.OnItemActivated $this.GetSelectedItem()
                    }
                    $handled = $true
                }
            }
            
            # Character-based search activation (exclude shortcut keys)
            if (-not $handled -and $key.KeyChar -ge 32 -and $key.KeyChar -lt 127 -and $key.KeyChar -notin $this.ExcludedSearchKeys) {
                $this.SetSearchQuery([string]$key.KeyChar)
                $this.EnterSearchMode()
                $handled = $true
            }
        }
        
        if ($handled) {
            $this.EnsureVisible()
            $this.Invalidate()
            
            # Fire selection changed event
            if ($oldIndex -ne $this.SelectedIndex -and $this.OnSelectionChanged) {
                & $this.OnSelectionChanged
            }
        }
        
        return $handled
    }
    
    [void] OnGotFocus() {
        $this._cachedRender = ""
        $this.Invalidate()
    }
    
    [void] OnLostFocus() {
        $this._searchMode = $false  # Exit search mode when losing focus
        $this._cachedRender = ""
        $this.Invalidate()
    }
}