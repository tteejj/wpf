# Core Render Engine Implementation
# This implements the basic rendering functionality to pass Phase 1 tests

class RenderBuffer {
    hidden [string[]] $_lines
    hidden [int] $_width
    hidden [int] $_height
    hidden [bool] $_disposed = $false
    
    RenderBuffer([int]$width, [int]$height) {
        $this._width = $width
        $this._height = $height
        $this._lines = @(' ' * $width) * $height
    }
    
    [string] GetText([int]$x, [int]$y, [int]$length) {
        if ($y -ge $this._lines.Count -or $x -ge $this._width) {
            return ''
        }
        
        $line = $this._lines[$y]
        $endPos = [Math]::Min($x + $length, $line.Length)
        
        if ($x -ge $line.Length) {
            return ''
        }
        
        return $line.Substring($x, $endPos - $x)
    }
    
    [string] GetLine([int]$y) {
        if ($y -ge $this._lines.Count) {
            return ''
        }
        return $this._lines[$y]
    }
    
    [void] SetLine([int]$y, [string]$content) {
        if ($y -lt $this._lines.Count) {
            # Pad or truncate to buffer width
            if ($content.Length -lt $this._width) {
                $content = $content.PadRight($this._width)
            } elseif ($content.Length -gt $this._width) {
                $content = $content.Substring(0, $this._width)
            }
            $this._lines[$y] = $content
        }
    }
    
    [void] SetText([int]$x, [int]$y, [string]$text) {
        if ($y -ge $this._lines.Count -or $x -ge $this._width) {
            return
        }
        
        $line = $this._lines[$y].ToCharArray()
        $textChars = $text.ToCharArray()
        
        for ($i = 0; $i -lt $textChars.Count -and ($x + $i) -lt $this._width; $i++) {
            $line[$x + $i] = $textChars[$i]
        }
        
        $this._lines[$y] = [string]::new($line)
    }
    
    [int] GetWidth() { return $this._width }
    [int] GetHeight() { return $this._height }
    
    [void] Dispose() {
        if (-not $this._disposed) {
            $this._lines = $null
            $this._disposed = $true
        }
    }
}

class RenderEngine {
    hidden [bool] $_initialized = $false
    hidden [int] $_frameRate = 60
    hidden [hashtable] $_vtSequences = @{
        Clear = "`e[2J`e[H"
        ClearLine = "`e[K"
        Reset = "`e[0m"
        HideCursor = "`e[?25l"
        ShowCursor = "`e[?25h"
    }
    
    RenderEngine() {
        $this._initialized = $true
    }
    
    [bool] IsInitialized() {
        return $this._initialized
    }
    
    [int] GetFrameRate() {
        return $this._frameRate
    }
    
    # Property for tests
    [int] $FrameRate = 60
    
    [string] ClearScreen() {
        return $this._vtSequences.Clear
    }
    
    [string] MoveTo([int]$x, [int]$y) {
        # Convert to 1-based coordinates for VT100
        return "`e[$($y + 1);$($x + 1)H"
    }
    
    [string] SetForegroundColor([int]$r, [int]$g, [int]$b) {
        return "`e[38;2;$r;$g;${b}m"
    }
    
    [string] SetBackgroundColor([int]$r, [int]$g, [int]$b) {
        return "`e[48;2;$r;$g;${b}m"
    }
    
    [RenderBuffer] CreateBuffer([int]$width, [int]$height) {
        return [RenderBuffer]::new($width, $height)
    }
    
    [void] WriteText([RenderBuffer]$buffer, [int]$x, [int]$y, [string]$text) {
        $this.WriteText($buffer, $x, $y, $text, $false)
    }
    
    [void] WriteText([RenderBuffer]$buffer, [int]$x, [int]$y, [string]$text, [bool]$wrap) {
        if (-not $wrap) {
            # Simple case - no wrapping
            $buffer.SetText($x, $y, $text)
        } else {
            # Handle text wrapping
            $remainingText = $text
            $currentY = $y
            $bufferWidth = $buffer.GetWidth()
            
            while ($remainingText.Length -gt 0 -and $currentY -lt $buffer.GetHeight()) {
                $availableWidth = $bufferWidth - $x
                
                if ($remainingText.Length -le $availableWidth) {
                    # Remaining text fits on current line
                    $buffer.SetText($x, $currentY, $remainingText)
                    break
                } else {
                    # Need to wrap
                    $lineText = $remainingText.Substring(0, $availableWidth)
                    $buffer.SetText($x, $currentY, $lineText)
                    $remainingText = $remainingText.Substring($availableWidth)
                    $currentY++
                    $x = 0  # Start at beginning of next line
                }
            }
        }
    }
    
    [string] RenderBuffer([RenderBuffer]$buffer) {
        # Pre-allocate StringBuilder with estimated size
        $estimatedSize = $buffer.GetHeight() * ($buffer.GetWidth() + 20)  # +20 for VT sequences
        $sb = [System.Text.StringBuilder]::new($estimatedSize)
        
        # Hide cursor during rendering
        [void]$sb.Append($this._vtSequences.HideCursor)
        
        # Batch operations for better performance
        $moveSequences = [string[]]::new($buffer.GetHeight())
        $lines = [string[]]::new($buffer.GetHeight())
        
        for ($y = 0; $y -lt $buffer.GetHeight(); $y++) {
            $moveSequences[$y] = "`e[$($y + 1);1H"
            $lines[$y] = $buffer.GetLine($y)
        }
        
        # Single append operations
        for ($y = 0; $y -lt $buffer.GetHeight(); $y++) {
            [void]$sb.Append($moveSequences[$y])
            [void]$sb.Append($lines[$y])
        }
        
        # Show cursor after rendering
        [void]$sb.Append($this._vtSequences.ShowCursor)
        
        return $sb.ToString()
    }
    
    # Additional helper methods
    [string] ClearLine() {
        return $this._vtSequences.ClearLine
    }
    
    [string] Reset() {
        return $this._vtSequences.Reset
    }
}