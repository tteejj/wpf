# UIElement.ps1 - Base class for all UI components in ExcelDataFlow
# Simplified from Praxis for standalone operation

class UIElement {
    # Position and dimensions
    [int]$X = 0
    [int]$Y = 0
    [int]$Width = 0
    [int]$Height = 0
    
    # Visibility and focus
    [bool]$Visible = $true
    [bool]$IsFocusable = $false
    [bool]$IsFocused = $false
    [int]$TabIndex = 0
    
    # Hierarchy
    [UIElement]$Parent = $null
    [System.Collections.Generic.List[UIElement]]$Children
    
    # Service container for dependency injection
    hidden [ServiceContainer]$ServiceContainer
    
    # Caching for performance
    hidden [string]$_renderCache = ""
    hidden [bool]$_cacheInvalid = $true
    
    UIElement() {
        $this.Children = [System.Collections.Generic.List[UIElement]]::new()
    }
    
    # Fast render - returns cached string if valid
    [string] Render() {
        if (-not $this.Visible) { return "" }
        
        if ($this._cacheInvalid) {
            # Rebuild cache only when needed
            $this._renderCache = $this.OnRender()
            $this._cacheInvalid = $false
        }
        
        return $this._renderCache
    }
    
    # Override in derived classes
    [string] OnRender() {
        return ""
    }
    
    # Mark this element (and parents) as needing re-render
    [void] Invalidate() {
        if ($this._cacheInvalid) { return }  # Already invalid
        
        $this._cacheInvalid = $true
        
        # Propagate up the tree
        if ($this.Parent) {
            $this.Parent.Invalidate()
        }
    }
    
    # Layout management
    [void] SetBounds([int]$x, [int]$y, [int]$width, [int]$height) {
        if ($this.X -eq $x -and $this.Y -eq $y -and 
            $this.Width -eq $width -and $this.Height -eq $height) {
            return  # No change
        }
        
        $this.X = $x
        $this.Y = $y
        $this.Width = $width
        $this.Height = $height
        
        $this.Invalidate()
        $this.OnBoundsChanged()
    }
    
    # Override for custom layout logic
    [void] OnBoundsChanged() {
        # Base implementation does nothing
    }
    
    # Child management
    [void] AddChild([UIElement]$child) {
        $child.Parent = $this
        $this.Children.Add($child)

        # Initialize the child with the container's services.
        if ($this.ServiceContainer) {
            $child.Initialize($this.ServiceContainer)
        }

        $this.Invalidate()
    }
    
    [void] RemoveChild([UIElement]$child) {
        $child.Parent = $null
        $this.Children.Remove($child)
        $this.Invalidate()
    }
    
    # Focus management
    [void] Focus() {
        if (-not $this.IsFocusable) { return }
        
        # Remove focus from others
        $root = $this.GetRoot()
        $this.ClearFocus($root)
        
        # Set focus on this element
        $this.IsFocused = $true
        $this.OnGotFocus()
        $this.Invalidate()
    }
    
    [void] ClearFocus([UIElement]$element) {
        if ($element.IsFocused) {
            $element.IsFocused = $false
            $element.OnLostFocus()
            $element.Invalidate()
        }
        foreach ($child in $element.Children) {
            $this.ClearFocus($child)
        }
    }
    
    [UIElement] GetRoot() {
        $current = $this
        while ($current.Parent) {
            $current = $current.Parent
        }
        return $current
    }
    
    [UIElement] FindFocused() {
        if ($this.IsFocused) { return $this }
        
        foreach ($child in $this.Children) {
            $focused = $child.FindFocused()
            if ($focused) { return $focused }
        }
        
        return $null
    }
    
    # Override for focus behavior
    [void] OnGotFocus() {}
    [void] OnLostFocus() {}
    
    # Initialize with service container
    [void] Initialize([ServiceContainer]$services) {
        if ($this.ServiceContainer) { return } # Already initialized

        $this.ServiceContainer = $services
        
        # Recursively initialize children
        foreach ($child in $this.Children) {
            $child.Initialize($services)
        }

        $this.OnInitialize()
    }
    
    # Override for custom initialization
    [void] OnInitialize() {}
    
    # Input handling
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        # Base implementation does nothing
        return $false
    }
}