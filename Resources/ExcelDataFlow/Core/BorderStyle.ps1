# BorderStyle.ps1 - Unified border rendering system for minimal, elegant UI
# COPIED FROM PRAXIS - ACTUAL WORKING VERSION

enum BorderType {
    None = 0
    Single = 1
    Double = 2
    Rounded = 3
    Minimal = 4  # Just corners
    Dotted = 5
    RoundedNoLines = 6  # Rounded corners with vertical sides only
}

class BorderStyle {
    # Border characters for different styles
    static [hashtable] $Styles = @{
        Single = @{
            TL = '┌'; TR = '┐'; BL = '└'; BR = '┘'
            H = '─'; V = '│'
            LT = '├'; RT = '┤'; TT = '┬'; BT = '┴'
            Cross = '┼'
        }
        Double = @{
            TL = '╔'; TR = '╗'; BL = '╚'; BR = '╝'
            H = '═'; V = '║'
            LT = '╠'; RT = '╣'; TT = '╦'; BT = '╩'
            Cross = '╬'
        }
        Rounded = @{
            TL = '╭'; TR = '╮'; BL = '╰'; BR = '╯'
            H = '─'; V = '│'
            LT = '├'; RT = '┤'; TT = '┬'; BT = '┴'
            Cross = '┼'
        }
        Minimal = @{
            TL = '·'; TR = '·'; BL = '·'; BR = '·'
            H = ' '; V = ' '
            LT = ' '; RT = ' '; TT = ' '; BT = ' '
            Cross = ' '
        }
        Dotted = @{
            TL = '·'; TR = '·'; BL = '·'; BR = '·'
            H = '·'; V = '┊'
            LT = '┊'; RT = '┊'; TT = '·'; BT = '·'
            Cross = '·'
        }
        RoundedNoLines = @{
            TL = '╭'; TR = '╮'; BL = '╰'; BR = '╯'
            H = ' '; V = '│'  # NO HORIZONTAL LINES - just spaces
            LT = '│'; RT = '│'; TT = ' '; BT = ' '
            Cross = ' '
        }
    }
    
    # Pre-render border for a given size and style
    static [string] RenderBorder(
        [int]$x, [int]$y, [int]$width, [int]$height,
        [BorderType]$type, [string]$color
    ) {
        if ($type -eq [BorderType]::None -or $width -lt 2 -or $height -lt 2) {
            return ""
        }
        
        $style = [BorderStyle]::Styles[$type.ToString()]
        if (-not $style) { return "" }
        
        $result = ""
        
        # Apply color if specified
        if ($color) { $result += $color }
        
        # Top border
        $result += [VT]::MoveTo($x, $y)
        $result += $style.TL
        if ($width -gt 2) {
            $horizontalLine = $style.H * ($width - 2)
            $result += $horizontalLine
        }
        $result += $style.TR
        
        # Side borders
        if ($height -gt 2) {
            for ($i = 1; $i -lt ($height - 1); $i++) {
                $result += [VT]::MoveTo($x, $y + $i)
                $result += $style.V
                if ($type -ne [BorderType]::Minimal) {
                    $result += [VT]::MoveTo($x + $width - 1, $y + $i)
                    $result += $style.V
                }
            }
        }
        
        # Bottom border
        $result += [VT]::MoveTo($x, $y + $height - 1)
        $result += $style.BL
        if ($width -gt 2) {
            if ($type -eq [BorderType]::Minimal) {
                # Minimal - just corners
                $result += (' ' * ($width - 2))
            } else {
                $bottomLine = $style.H * ($width - 2)
                $result += $bottomLine
            }
        }
        $result += $style.BR
        
        # Reset color
        if ($color) { $result += [VT]::Reset() }
        
        return $result
    }
    
    # Render border with title (elegant placement)
    static [string] RenderBorderWithTitle(
        [int]$x, [int]$y, [int]$width, [int]$height,
        [BorderType]$type, [string]$color,
        [string]$title, [string]$titleColor
    ) {
        if ($type -eq [BorderType]::None) { return "" }
        
        # Start with basic border
        $border = [BorderStyle]::RenderBorder($x, $y, $width, $height, $type, $color)
        
        if (-not $title -or $title.Length -eq 0) { return $border }
        
        $result = $border
        
        # Calculate title position (centered with padding)
        $titleWithPadding = " $title "
        $titleStart = $x + [Math]::Max(2, ($width - $titleWithPadding.Length) / 2)
        
        # Overlay title on top border
        $result += [VT]::MoveTo($titleStart, $y)
        if ($titleColor) { $result += $titleColor }
        $result += $titleWithPadding
        if ($titleColor) { $result += [VT]::Reset() }
        if ($color) { $result += $color }
        
        return $result
    }
}