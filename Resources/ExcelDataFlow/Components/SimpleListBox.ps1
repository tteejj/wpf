# SimpleListBox.ps1 - Simple scrollable list component for wizard steps

class SimpleListBox : UIElement {
    [System.Collections.ArrayList]$Items
    [int]$SelectedIndex = 0
    [int]$ScrollOffset = 0
    [bool]$ShowBorder = $true
    [scriptblock]$OnSelectionChanged = {}
    
    SimpleListBox() : base() {
        $this.Items = [System.Collections.ArrayList]::new()
        $this.Height = 10
        $this.IsFocusable = $true
    }
    
    [void] AddItem([string]$item) {
        $this.Items.Add($item) | Out-Null
        $this.Invalidate()
    }
    
    [void] Clear() {
        $this.Items.Clear()
        $this.SelectedIndex = 0
        $this.ScrollOffset = 0
        $this.Invalidate()
    }
    
    [void] MoveSelection([int]$delta) {
        if ($this.Items.Count -eq 0) { return }
        
        $newIndex = $this.SelectedIndex + $delta
        $newIndex = [Math]::Max(0, [Math]::Min($newIndex, $this.Items.Count - 1))
        
        if ($newIndex -ne $this.SelectedIndex) {
            $this.SelectedIndex = $newIndex
            
            # Adjust scroll offset if needed
            $visibleRows = $this.Height
            if ($this.ShowBorder) { $visibleRows -= 2 }
            
            if ($this.SelectedIndex -lt $this.ScrollOffset) {
                $this.ScrollOffset = $this.SelectedIndex
            } elseif ($this.SelectedIndex -ge ($this.ScrollOffset + $visibleRows)) {
                $this.ScrollOffset = $this.SelectedIndex - $visibleRows + 1
            }
            
            # Trigger selection changed event
            if ($this.OnSelectionChanged) {
                & $this.OnSelectionChanged
            }
            
            $this.Invalidate()
        }
    }
    
    [string] OnRender() {
        $result = ""
        
        # Calculate visible area
        $contentY = $this.Y
        $contentHeight = $this.Height
        
        if ($this.ShowBorder) {
            # Draw border
            $result += [VT]::MoveTo($this.X, $this.Y)
            $result += "┌" + ("─" * ($this.Width - 2)) + "┐"
            
            for ($i = 1; $i -lt ($this.Height - 1); $i++) {
                $result += [VT]::MoveTo($this.X, $this.Y + $i)
                $result += "│" + (" " * ($this.Width - 2)) + "│"
            }
            
            $result += [VT]::MoveTo($this.X, $this.Y + $this.Height - 1)
            $result += "└" + ("─" * ($this.Width - 2)) + "┘"
            
            $contentY += 1
            $contentHeight -= 2
        }
        
        # Render items
        $visibleRows = $contentHeight
        $endIndex = [Math]::Min($this.Items.Count, $this.ScrollOffset + $visibleRows)
        
        for ($i = $this.ScrollOffset; $i -lt $endIndex; $i++) {
            $displayY = $contentY + ($i - $this.ScrollOffset)
            $result += [VT]::MoveTo($this.X + 1, $displayY)
            
            $item = $this.Items[$i]
            $isSelected = ($i -eq $this.SelectedIndex)
            
            # Highlight selected item with consistent blue theme
            if ($isSelected -and $this.IsFocused) {
                # Focused and selected: bright blue background with white text
                $result += [VT]::RGBBG(0, 120, 200) + [VT]::White()
            } elseif ($isSelected) {
                # Selected but not focused: gray background
                $result += [VT]::RGBBG(80, 80, 80) + [VT]::White()
            } else {
                # Normal item: light gray text
                $result += [VT]::RGB(200, 200, 200)
            }
            
            # Truncate text to fit width
            $maxWidth = $this.Width - 2
            if ($this.ShowBorder) { $maxWidth -= 2 }
            
            $displayText = $item
            if ($displayText.Length -gt $maxWidth) {
                $displayText = $displayText.Substring(0, $maxWidth - 3) + "..."
            }
            
            $result += $displayText.PadRight($maxWidth)
            $result += [VT]::Reset()
        }
        
        return $result
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([System.ConsoleKey]::UpArrow) {
                $this.MoveSelection(-1)
                return $true
            }
            ([System.ConsoleKey]::DownArrow) {
                $this.MoveSelection(1)
                return $true
            }
            ([System.ConsoleKey]::PageUp) {
                $this.MoveSelection(-5)
                return $true
            }
            ([System.ConsoleKey]::PageDown) {
                $this.MoveSelection(5)
                return $true
            }
            ([System.ConsoleKey]::Home) {
                $this.MoveSelection(-$this.Items.Count)
                return $true
            }
            ([System.ConsoleKey]::End) {
                $this.MoveSelection($this.Items.Count)
                return $true
            }
        }
        
        return $false
    }
}