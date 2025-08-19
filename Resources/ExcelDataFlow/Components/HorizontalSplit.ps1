# HorizontalSplit.ps1 - Fast horizontal layout component for PRAXIS
# COPIED FROM PRAXIS - ACTUAL WORKING VERSION

class HorizontalSplit : Container {
    [UIElement]$LeftPane
    [UIElement]$RightPane
    [int]$SplitRatio = 50  # Percentage for left pane (0-100)
    [int]$MinPaneWidth = 5
    [bool]$ShowBorder = $false
    [bool]$Resizable = $false  # Future: allow dragging the split
    
    # Cached layout calculations
    hidden [int]$_cachedLeftWidth = 0
    hidden [int]$_cachedRightWidth = 0
    hidden [int]$_cachedRightX = 0
    hidden [bool]$_layoutInvalid = $true
    hidden [int]$_lastWidth = 0
    hidden [int]$_lastSplitRatio = 0
    hidden [hashtable]$_colors = @{}
    hidden [object]$Theme
    
    HorizontalSplit() : base() {
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
    
    [void] SetLeftPane([UIElement]$pane) {
        if ($this.LeftPane) {
            $this.RemoveChild($this.LeftPane)
        }
        $this.LeftPane = $pane
        if ($pane) {
            $this.AddChild($pane)
        }
        $this.InvalidateLayout()
    }
    
    [void] SetRightPane([UIElement]$pane) {
        if ($this.RightPane) {
            $this.RemoveChild($this.RightPane)
        }
        $this.RightPane = $pane
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
            $this._lastWidth -eq $this.Width -and 
            $this._lastSplitRatio -eq $this.SplitRatio) {
            return  # Layout is still valid
        }
        
        # Calculate pane dimensions
        $totalWidth = $this.Width
        $leftWidth = [int](($totalWidth * $this.SplitRatio) / 100)
        $leftWidth = [Math]::Max($this.MinPaneWidth, [Math]::Min($leftWidth, $totalWidth - $this.MinPaneWidth))
        $rightWidth = $totalWidth - $leftWidth
        $rightX = $this.X + $leftWidth
        
        # Update left pane
        if ($this.LeftPane) {
            $this.LeftPane.SetBounds($this.X, $this.Y, $leftWidth, $this.Height)
        }
        
        # Update right pane
        if ($this.RightPane) {
            $this.RightPane.SetBounds($rightX, $this.Y, $rightWidth, $this.Height)
        }
        
        # Cache calculations
        $this._cachedLeftWidth = $leftWidth
        $this._cachedRightWidth = $rightWidth
        $this._cachedRightX = $rightX
        $this._lastWidth = $this.Width
        $this._lastSplitRatio = $this.SplitRatio
        $this._layoutInvalid = $false
    }
    
    [void] LayoutChildren() {
        $this.UpdateLayout()
    }
}