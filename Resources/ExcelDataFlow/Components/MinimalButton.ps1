# MinimalButton.ps1 - Simple button component for ExcelDataFlow

class MinimalButton : UIElement {
    [string]$Text = "Button"
    [scriptblock]$OnClick = {}
    [bool]$IsDefault = $false
    
    MinimalButton() : base() {
        $this.Height = 3  # Height for border
        $this.IsFocusable = $true
    }
    
    MinimalButton([string]$text) : base() {
        $this.Text = $text
        $this.Height = 3
        $this.IsFocusable = $true
    }
    
    [void] SetText([string]$text) {
        if ($this.Text -ne $text) {
            $this.Text = $text
            $this.Invalidate()
        }
    }
    
    [string] OnRender() {
        $result = ""
        
        # Enhanced focus styling
        if ($this.IsFocused) {
            $borderColor = [VT]::RGB(0, 200, 255)      # Bright cyan border
            $textColor = [VT]::RGB(255, 255, 255)      # White text
            $bgColor = [VT]::RGBBG(0, 100, 200)        # Blue background
            $borderChar = "═"                          # Double line border
        } elseif ($this.IsDefault) {
            $borderColor = [VT]::RGB(0, 255, 0)        # Green for default
            $textColor = [VT]::RGB(255, 255, 255)      # White text
            $bgColor = ""                              # No background
            $borderChar = "─"                          # Single line
        } else {
            $borderColor = [VT]::RGB(150, 150, 150)    # Gray border
            $textColor = [VT]::RGB(200, 200, 200)      # Light gray text
            $bgColor = ""                              # No background
            $borderChar = "─"                          # Single line
        }
        
        # Top border
        $result += [VT]::MoveTo($this.X, $this.Y)
        $result += $borderColor
        $borderWidth = [Math]::Max(0, $this.Width - 2)
        $result += "╔" + ($borderChar * $borderWidth) + "╗"
        $result += [VT]::Reset()
        
        # Middle line with text and enhanced styling
        $result += [VT]::MoveTo($this.X, $this.Y + 1)
        $result += $borderColor + "║" + [VT]::Reset()
        
        $buttonText = $this.Text
        if ($this.IsDefault) {
            $buttonText += " ●"  # Solid circle for default
        }
        
        # Center the text with background
        $innerWidth = [Math]::Max(1, $this.Width - 2)
        $padding = [Math]::Max(0, ($innerWidth - $buttonText.Length) / 2)
        $leftPad = [int]$padding
        $rightPad = [Math]::Max(0, $innerWidth - $leftPad - $buttonText.Length)
        
        $result += $bgColor + (" " * $leftPad) + $textColor + $buttonText + [VT]::Reset() + $bgColor + (" " * $rightPad) + [VT]::Reset()
        $result += $borderColor + "║" + [VT]::Reset()
        
        # Bottom border
        $result += [VT]::MoveTo($this.X, $this.Y + 2)
        $result += $borderColor
        $result += "╚" + ($borderChar * $borderWidth) + "╝"
        $result += [VT]::Reset()
        
        return $result
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([System.ConsoleKey]::Enter) {
                $this.Click()
                return $true
            }
            ([System.ConsoleKey]::Spacebar) {
                $this.Click()
                return $true
            }
        }
        return $false
    }
    
    [void] Click() {
        if ($this.OnClick) {
            & $this.OnClick
        }
    }
}