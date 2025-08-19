# Container.ps1 - Base class for components that contain other components
# Simplified for ExcelDataFlow standalone app

class Container : UIElement {
    # Optional background
    [bool]$DrawBackground = $false
    
    Container() : base() {
    }
    
    # Render all children
    [string] OnRender() {
        $result = ""
        
        # Render all visible children
        foreach ($child in $this.Children) {
            if ($child.Visible) {
                $result += $child.Render()
            }
        }
        
        return $result
    }
    
    [void] OnBoundsChanged() {
        # Let derived classes handle child layout
        $this.LayoutChildren()
    }
    
    # Override in derived classes for custom layouts
    [void] LayoutChildren() {
        # Base implementation does nothing
    }
    
    # Find child at specific coordinates
    [UIElement] HitTest([int]$x, [int]$y) {
        # Check if point is within our bounds
        if ($x -lt $this.X -or $x -ge ($this.X + $this.Width) -or
            $y -lt $this.Y -or $y -ge ($this.Y + $this.Height)) {
            return $null
        }
        
        # Check children in reverse order (top to bottom)
        for ($i = $this.Children.Count - 1; $i -ge 0; $i--) {
            $child = $this.Children[$i]
            if ($child.Visible) {
                $hit = if ($child -is [Container]) {
                    $child.HitTest($x, $y)
                } else {
                    # Non-containers do simple bounds check
                    if ($x -ge $child.X -and $x -lt ($child.X + $child.Width) -and
                        $y -ge $child.Y -and $y -lt ($child.Y + $child.Height)) {
                        $child
                    } else {
                        $null
                    }
                }
                
                if ($hit) { return $hit }
            }
        }
        
        # No child hit, return self
        return $this
    }
    
    # Route input to focused child
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        # Handle Tab navigation first
        if ($key.Key -eq [System.ConsoleKey]::Tab) {
            if ($key.Modifiers -band [System.ConsoleModifiers]::Shift) {
                $this.FocusPrevious()
            } else {
                $this.FocusNext()
            }
            return $true
        }
        
        # Find focused child and route input
        $focused = $this.FindFocusedChild()
        if ($focused) {
            return $focused.HandleInput($key)
        }
        
        return $false
    }
    
    # Find focused child (not deep search)
    [UIElement] FindFocusedChild() {
        foreach ($child in $this.Children) {
            if ($child.Visible -and $child.IsFocused) {
                return $child
            }
        }
        return $null
    }
    
    # Tab navigation
    [void] FocusNext() {
        $focusables = @()
        $this.CollectFocusables($focusables)
        
        $currentIndex = -1
        for ($i = 0; $i -lt $focusables.Count; $i++) {
            if ($focusables[$i].IsFocused) {
                $currentIndex = $i
                break
            }
        }
        
        if ($focusables.Count -gt 0) {
            $nextIndex = ($currentIndex + 1) % $focusables.Count
            $focusables[$nextIndex].Focus()
        }
    }
    
    [void] FocusPrevious() {
        $focusables = @()
        $this.CollectFocusables($focusables)
        
        $currentIndex = -1
        for ($i = 0; $i -lt $focusables.Count; $i++) {
            if ($focusables[$i].IsFocused) {
                $currentIndex = $i
                break
            }
        }
        
        if ($focusables.Count -gt 0) {
            $prevIndex = if ($currentIndex -le 0) { $focusables.Count - 1 } else { $currentIndex - 1 }
            $focusables[$prevIndex].Focus()
        }
    }
    
    [void] CollectFocusables([System.Collections.ArrayList]$focusables) {
        foreach ($child in $this.Children) {
            if ($child.Visible) {
                if ($child.IsFocusable) {
                    $focusables.Add($child) | Out-Null
                }
                if ($child -is [Container]) {
                    $child.CollectFocusables($focusables)
                }
            }
        }
    }
    
    # Focus first focusable child
    [void] FocusFirst() {
        $focusable = $this.Children | Where-Object { $_.IsFocusable -and $_.Visible } | Select-Object -First 1
        if ($focusable) {
            $focusable.Focus()
        }
    }
}