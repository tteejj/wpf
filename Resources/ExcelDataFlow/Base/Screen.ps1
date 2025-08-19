# Screen.ps1 - Base class for all screens in ExcelDataFlow
# Simplified for standalone operation

class Screen : Container {
    [string]$Title = "Screen"
    [bool]$Active = $true
    
    Screen() : base() {
        $this.IsFocusable = $false  # Screens are containers, not focusable elements
    }
    
    # Initialize with services
    [void] Initialize([object]$services) {
        # Call base initialization
        ([UIElement]$this).Initialize($services)
        $this.OnInitialize()
    }
    
    # Override for custom initialization
    [void] OnInitialize() {
        # Override in derived classes
    }
    
    # Override this method in derived screens to handle screen-specific input
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$keyInfo) {
        return $false  # Base implementation - no screen-specific handling
    }
    
    # Input handling with delegation
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        # 1. Let focused child handle first (components get priority)
        $handled = ([Container]$this).HandleInput($keyInfo)
        if ($handled) {
            return $true
        }
        
        # 2. Screen shortcuts as fallback
        return $this.HandleScreenInput($keyInfo)
    }
    
    # Lifecycle methods
    [void] OnActivated() {
        # Force a render when screen is activated
        $this.Invalidate()
        
        # Ensure first focusable child gets focus
        $this.FocusFirst()
    }
    
    [void] OnDeactivated() {
        # Override in derived classes if needed
    }
    
    # Clear screen and render border
    [string] OnRender() {
        $result = ""
        
        # Clear screen
        $result += [VT]::ClearScreen()
        
        # Draw title bar
        $result += [VT]::MoveTo(0, 0)
        $titleLine = $this.Title.PadRight([Console]::WindowWidth)
        $result += $titleLine
        
        # Draw separator line
        $result += [VT]::MoveTo(0, 1)
        $result += ("─" * [Console]::WindowWidth)
        
        # Render children
        foreach ($child in $this.Children) {
            if ($child.Visible) {
                $result += $child.Render()
            }
        }
        
        return $result
    }
    
    # Request a re-render
    [void] RequestRender() {
        $this.Invalidate()
    }
}