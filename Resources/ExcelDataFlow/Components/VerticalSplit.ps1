# VerticalSplit.ps1 - Fast vertical layout component for PRAXIS
# COPIED FROM PRAXIS - ACTUAL WORKING VERSION

class VerticalSplit : Container {
    [UIElement]$TopPane
    [UIElement]$BottomPane
    [int]$SplitRatio = 50  # Percentage for top pane (0-100)
    [int]$MinPaneHeight = 3
    [bool]$ShowBorder = $false
    [bool]$Resizable = $false  # Future: allow dragging the split
    
    # Cached layout calculations
    hidden [int]$_cachedTopHeight = 0
    hidden [int]$_cachedBottomHeight = 0
    hidden [int]$_cachedBottomY = 0
    hidden [bool]$_layoutInvalid = $true
    hidden [int]$_lastHeight = 0
    hidden [int]$_lastSplitRatio = 0
    hidden [hashtable]$_colors = @{}
    hidden [object]$Theme
    
    VerticalSplit() : base() {
        $this.DrawBackground = $false
    }
    
    [void] OnInitialize() {
        ([Container]$this).OnInitialize()
        # Theme may not exist in standalone
        if ($this.ServiceContainer -and $this.ServiceContainer.HasService('ThemeManager')) {
            $this.Theme = $this.ServiceContainer.GetService('ThemeManager')
            if ($this.Theme) {
                $this.OnThemeChanged()
            }
        }
    }
    
    [void] OnThemeChanged() {
        if ($this.Theme) {
            $this._colors = @{
                'border' = $this.Theme.GetColor('border.normal')
            }
        }
        $this.Invalidate()
    }
    
    [void] SetTopPane([UIElement]$pane) {
        if ($this.TopPane) {
            $this.RemoveChild($this.TopPane)
        }
        $this.TopPane = $pane
        if ($pane) {
            $this.AddChild($pane)
        }
        $this.InvalidateLayout()
    }
    
    [void] SetBottomPane([UIElement]$pane) {
        if ($this.BottomPane) {
            $this.RemoveChild($this.BottomPane)
        }
        $this.BottomPane = $pane
        if ($pane) {
            $this.AddChild($pane)
        }
        $this.InvalidateLayout()
    }
    
    [void] SetSplitRatio([int]$ratio) {
        $this.SplitRatio = [Math]::Max(10, [Math]::Min(90, $ratio))
        $this.InvalidateLayout()
    }
    
    [void] InvalidateLayout() {
        $this._layoutInvalid = $true
        $this.Invalidate()
    }
    
    [void] OnBoundsChanged() {
        $this.InvalidateLayout()
        $this.UpdateLayout()
    }
    
    [void] UpdateLayout() {
        if (-not $this._layoutInvalid -and 
            $this._lastHeight -eq $this.Height -and 
            $this._lastSplitRatio -eq $this.SplitRatio) {
            return  # Layout is still valid
        }
        
        # Calculate pane dimensions
        $totalHeight = $this.Height
        $topHeight = [int](($totalHeight * $this.SplitRatio) / 100)
        $topHeight = [Math]::Max($this.MinPaneHeight, [Math]::Min($topHeight, $totalHeight - $this.MinPaneHeight))
        $bottomHeight = $totalHeight - $topHeight
        $bottomY = $this.Y + $topHeight
        
        # Update top pane
        if ($this.TopPane) {
            $this.TopPane.SetBounds($this.X, $this.Y, $this.Width, $topHeight)
        }
        
        # Update bottom pane
        if ($this.BottomPane) {
            $this.BottomPane.SetBounds($this.X, $bottomY, $this.Width, $bottomHeight)
        }
        
        # Cache calculations
        $this._cachedTopHeight = $topHeight
        $this._cachedBottomHeight = $bottomHeight
        $this._cachedBottomY = $bottomY
        $this._lastHeight = $this.Height
        $this._lastSplitRatio = $this.SplitRatio
        $this._layoutInvalid = $false
    }
    
    [void] LayoutChildren() {
        $this.UpdateLayout()
    }
}