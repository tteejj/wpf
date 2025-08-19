# VT100/ANSI Core for ExcelDataFlow
# Simplified for standalone operation

class VT {
    # Cursor movement
    static [string] MoveTo([int]$x, [int]$y) { 
        # Use TaskPro's working coordinate system: row=y, column=x
        return "`e[$($y + 1);$($x + 1)H" 
    }
    static [string] SavePos() { return "`e[s" }
    static [string] RestorePos() { return "`e[u" }
    
    # Cursor visibility
    static [string] Hide() { return "`e[?25l" }
    static [string] Show() { return "`e[?25h" }
    static [string] HideCursor() { return "`e[?25l" }
    static [string] ShowCursor() { return "`e[?25h" }
    
    # Cursor movement methods
    static [string] MoveUp([int]$n) { return "`e[$($n)A" }
    static [string] MoveDown([int]$n) { return "`e[$($n)B" }
    static [string] MoveRight([int]$n) { return "`e[$($n)C" }
    static [string] MoveLeft([int]$n) { return "`e[$($n)D" }
    
    # Screen control
    static [string] Clear() { return "`e[2J" }
    static [string] ClearLine() { return "`e[2K" }
    static [string] Home() { return "`e[H" }
    static [string] ClearToEnd() { return "`e[J" }
    static [string] ClearScreen() { return "`e[2J`e[H" }
    
    # Basic styles
    static [string] Reset() { return "`e[0m" }
    static [string] Bold() { return "`e[1m" }
    static [string] Dim() { return "`e[2m" }
    static [string] Italic() { return "`e[3m" }
    static [string] Underline() { return "`e[4m" }
    static [string] NoUnderline() { return "`e[24m" }
    
    # 24-bit True Color
    static [string] RGB([int]$r, [int]$g, [int]$b) { 
        return "`e[38;2;$r;$g;$($b)m" 
    }
    static [string] RGBBG([int]$r, [int]$g, [int]$b) { 
        return "`e[48;2;$r;$g;$($b)m" 
    }
    
    # 256-color support
    static [string] Color256Fg([int]$color) { 
        return "`e[38;5;$($color)m" 
    }
    static [string] Color256Bg([int]$color) { 
        return "`e[48;5;$($color)m" 
    }
    
    # Basic colors
    static [string] Red() { return "`e[31m" }
    static [string] Green() { return "`e[32m" }
    static [string] Yellow() { return "`e[33m" }
    static [string] Blue() { return "`e[34m" }
    static [string] Magenta() { return "`e[35m" }
    static [string] Cyan() { return "`e[36m" }
    static [string] White() { return "`e[37m" }
    static [string] Gray() { return "`e[90m" }
    
    # Box drawing - single lines
    static [string] TL() { return "┌" }     # Top left
    static [string] TR() { return "┐" }     # Top right
    static [string] BL() { return "└" }     # Bottom left
    static [string] BR() { return "┘" }     # Bottom right
    static [string] H() { return "─" }      # Horizontal
    static [string] V() { return "│" }      # Vertical
    static [string] Cross() { return "┼" }  # Cross
    static [string] T() { return "┬" }      # T down
    static [string] B() { return "┴" }      # T up
    static [string] L() { return "├" }      # T right
    static [string] R() { return "┤" }      # T left
    
    # Double lines for emphasis
    static [string] DTL() { return "╔" }
    static [string] DTR() { return "╗" }
    static [string] DBL() { return "╚" }
    static [string] DBR() { return "╝" }
    static [string] DH() { return "═" }
    static [string] DV() { return "║" }
}

# Layout measurement helpers
class Measure {
    static [int] TextWidth([string]$text) {
        # Remove ANSI sequences for accurate measurement
        $clean = $text -replace '\x1b\[[0-9;]*m', ''
        return $clean.Length
    }
    
    static [string] Truncate([string]$text, [int]$maxWidth) {
        $clean = $text -replace '\x1b\[[0-9;]*m', ''
        if ($clean.Length -le $maxWidth) { return $text }
        return $clean.Substring(0, $maxWidth - 3) + "..."
    }
    
    static [string] Pad([string]$text, [int]$width, [string]$align = "Left") {
        $textWidth = [Measure]::TextWidth($text)
        if ($textWidth -ge $width) { return [Measure]::Truncate($text, $width) }
        
        $padding = $width - $textWidth
        switch ($align) {
            "Left" { return $text + (" " * $padding) }
            "Right" { return (" " * $padding) + $text }
            "Center" { 
                $left = [int]($padding / 2)
                $right = $padding - $left
                return (" " * $left) + $text + (" " * $right)
            }
        }
        return $text
    }
}