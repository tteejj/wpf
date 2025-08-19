# MinimalTextBox.ps1 - Simple text input component for ExcelDataFlow

class MinimalTextBox : UIElement {
    [string]$Text = ""
    [string]$Placeholder = ""
    [bool]$IsPassword = $false
    [int]$MaxLength = 0
    [int]$ScrollOffset = 0
    
    MinimalTextBox() : base() {
        $this.Height = 1
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
        
        # Position cursor
        $result += [VT]::MoveTo($this.X, $this.Y)
        
        # Determine what to display
        $displayText = if ($this.Text.Length -gt 0) {
            if ($this.IsPassword) {
                "*" * $this.Text.Length
            } else {
                $this.Text
            }
        } else {
            $this.Placeholder
        }
        
        # Handle scrolling for long text
        $availableWidth = [Math]::Max(1, $this.Width)  # Ensure positive width
        if ($displayText.Length -gt $availableWidth) {
            $displayText = $displayText.Substring($this.ScrollOffset, [Math]::Min($availableWidth, $displayText.Length - $this.ScrollOffset))
        }
        
        # Apply improved focus indicators
        if ($this.IsFocused) {
            # Strong focus indicator: bright background + contrasting text
            $result += [VT]::RGBBG(0, 100, 200)  # Blue background
            $result += [VT]::White()              # White text
        } elseif ($this.Text.Length -eq 0) {
            # Placeholder style: subtle gray
            $result += [VT]::RGB(120, 120, 120)
        } else {
            # Normal text: bright and readable
            $result += [VT]::RGB(220, 220, 220)
        }
        
        # Render text with proper padding
        $paddedText = $displayText.PadRight($availableWidth)
        if ($paddedText.Length -gt $availableWidth) {
            $paddedText = $paddedText.Substring(0, $availableWidth)
        }
        $result += $paddedText
        $result += [VT]::Reset()
        
        # Show cursor if focused - make it more visible
        if ($this.IsFocused) {
            $cursorPos = [Math]::Min($this.Text.Length - $this.ScrollOffset, $availableWidth - 1)
            $result += [VT]::MoveTo($this.X + $cursorPos, $this.Y)
            $result += [VT]::RGB(255, 255, 0) + "│" + [VT]::Reset()  # Bright yellow cursor
        }
        
        return $result
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        $handled = $false
        
        switch ($key.Key) {
            ([System.ConsoleKey]::Backspace) {
                if ($this.Text.Length -gt 0) {
                    $this.Text = $this.Text.Substring(0, $this.Text.Length - 1)
                    $this.AdjustScrollOffset()
                    $this.Invalidate()
                    $handled = $true
                }
            }
            ([System.ConsoleKey]::Delete) {
                # For simplicity, treat as backspace
                if ($this.Text.Length -gt 0) {
                    $this.Text = $this.Text.Substring(0, $this.Text.Length - 1)
                    $this.AdjustScrollOffset()
                    $this.Invalidate()
                    $handled = $true
                }
            }
            default {
                # Add character if it's printable
                if ($key.KeyChar -and [char]::IsControl($key.KeyChar) -eq $false) {
                    if ($this.MaxLength -eq 0 -or $this.Text.Length -lt $this.MaxLength) {
                        $this.Text += $key.KeyChar
                        $this.AdjustScrollOffset()
                        $this.Invalidate()
                        $handled = $true
                    }
                }
            }
        }
        
        return $handled
    }
    
    [void] AdjustScrollOffset() {
        # Ensure cursor is visible
        $textLength = $this.Text.Length
        $availableWidth = $this.Width
        
        if ($textLength -ge $availableWidth) {
            $this.ScrollOffset = $textLength - $availableWidth + 1
        } else {
            $this.ScrollOffset = 0
        }
    }
}