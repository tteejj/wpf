# RenderHelper.ps1 - Centralized rendering utilities for consistent UI behavior

class RenderHelper {
    # Static cache for commonly used strings
    static [hashtable]$_stringCache = @{}
    static [bool]$_initialized = $false
    
    # Performance tracking
    static [hashtable]$_renderStats = @{}
    
    # Clipping bounds for render operations
    static [hashtable]$_clipBounds = @{
        X = 0
        Y = 0
        Width = [Console]::WindowWidth
        Height = [Console]::WindowHeight
    }
    
    static [void] Initialize() {
        if ([RenderHelper]::_initialized) { return }
        
        # Pre-cache common strings
        [RenderHelper]::_stringCache = @{
            'spaces_1' = ' '
            'spaces_2' = '  '
            'spaces_3' = '   '
            'spaces_4' = '    '
            'reset' = [VT]::Reset()
        }
        
        [RenderHelper]::_initialized = $true
    }
    
    # Set clipping bounds for subsequent render operations
    static [void] SetClipBounds([int]$x, [int]$y, [int]$width, [int]$height) {
        [RenderHelper]::_clipBounds = @{
            X = $x
            Y = $y
            Width = $width
            Height = $height
        }
    }
    
    # Reset clipping bounds to full console
    static [void] ResetClipBounds() {
        [RenderHelper]::_clipBounds = @{
            X = 0
            Y = 0
            Width = [Console]::WindowWidth
            Height = [Console]::WindowHeight
        }
    }
    
    # Check if position is within clip bounds
    static [bool] IsInClipBounds([int]$x, [int]$y) {
        $bounds = [RenderHelper]::_clipBounds
        return $x -ge $bounds.X -and $x -lt ($bounds.X + $bounds.Width) -and
               $y -ge $bounds.Y -and $y -lt ($bounds.Y + $bounds.Height)
    }
    
    # Safe padding calculation - prevents negative padding crashes
    static [int] CalculatePadding([int]$totalWidth, [int]$contentWidth, [int]$minPadding = 0) {
        $padding = $totalWidth - $contentWidth
        return [Math]::Max($minPadding, $padding)
    }
    
    # Safe padding string - returns spaces or empty if negative
    static [string] GetPaddingSpaces([int]$count) {
        if ($count -le 0) { return '' }
        if ($count -le 4 -and [RenderHelper]::_stringCache.ContainsKey("spaces_$count")) {
            return [RenderHelper]::_stringCache["spaces_$count"]
        }
        return [StringCache]::GetSpaces($count)
    }
    
    # Render list item without background bleed
    static [string] RenderListItem([string]$text, [bool]$isSelected, [bool]$isFocused, [int]$width, [ThemeManager]$theme) {
        $sb = Get-PooledStringBuilder 256
        
        if ($isSelected -and $isFocused) {
            # Selected + focused: reverse highlighting
            $sb.Append($theme.GetBgColor('focus.reverse.background'))
            $sb.Append($theme.GetColor('focus.reverse.text'))
            $sb.Append("▸ ")
            $sb.Append($text)
        } elseif ($isSelected) {
            # Selected but not focused: normal selection colors
            $sb.Append($theme.GetBgColor('menu.background.selected'))
            $sb.Append($theme.GetColor('menu.text.selected'))
            $sb.Append("  ")
            $sb.Append($text)
        } else {
            # Normal item: NO BACKGROUND COLOR (this fixes grey bleed)
            $sb.Append($theme.GetColor('text.primary'))
            $sb.Append("  ")
            $sb.Append($text)
        }
        
        # Pad to width if needed
        $currentLength = $text.Length + 2  # 2 for prefix
        if ($currentLength -lt $width) {
            $padding = $width - $currentLength
            $sb.Append([RenderHelper]::GetPaddingSpaces($padding))
        }
        
        # Always reset
        $sb.Append([VT]::Reset())
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
    
    # Render border with focus awareness (only when focused)
    static [string] RenderBorderWithFocus([UIElement]$element, [ThemeManager]$theme) {
        if (-not $element.IsFocused) {
            return ''  # No border when not focused
        }
        
        $borderColor = $theme.GetColor('border.input.focused')
        return [BorderStyle]::RenderBorder($element.X, $element.Y, $element.Width, $element.Height, [BorderType]::Single, $borderColor)
    }
    
    # Render focus state for buttons and inputs
    static [string] RenderFocusState([UIElement]$element, [string]$content, [ThemeManager]$theme) {
        $sb = Get-PooledStringBuilder 256
        
        if ($element.IsFocused) {
            # Focused: reverse highlighting
            $sb.Append($theme.GetBgColor('focus.reverse.background'))
            $sb.Append($theme.GetColor('focus.reverse.text'))
            $sb.Append($content)
            $sb.Append([VT]::Reset())
        } else {
            # Not focused: normal colors
            $sb.Append($theme.GetColor('text.primary'))
            $sb.Append($content)
            $sb.Append([VT]::Reset())
        }
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
    
    # Safe button content rendering with padding
    static [string] RenderButtonContent([string]$text, [int]$width, [ThemeManager]$theme, [bool]$isFocused) {
        $sb = Get-PooledStringBuilder 128
        
        # Calculate safe padding
        $textLength = $text.Length
        $totalPadding = [RenderHelper]::CalculatePadding($width - 2, $textLength, 0)  # -2 for borders
        $leftPadding = [int]($totalPadding / 2)
        $rightPadding = $totalPadding - $leftPadding
        
        # Add left padding
        $sb.Append([RenderHelper]::GetPaddingSpaces($leftPadding))
        
        # Add text with appropriate colors
        if ($isFocused) {
            $sb.Append($theme.GetBgColor('focus.reverse.background'))
            $sb.Append($theme.GetColor('focus.reverse.text'))
        } else {
            $sb.Append($theme.GetColor('text.primary'))
        }
        $sb.Append($text)
        
        # Add right padding
        $sb.Append([RenderHelper]::GetPaddingSpaces($rightPadding))
        $sb.Append([VT]::Reset())
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
    
    # Record performance metrics (optional, for debugging)
    static [void] RecordRenderTime([string]$component, [int]$milliseconds) {
        if (-not [RenderHelper]::_renderStats.ContainsKey($component)) {
            [RenderHelper]::_renderStats[$component] = @{
                'TotalTime' = 0
                'CallCount' = 0
                'AverageTime' = 0
            }
        }
        
        $stats = [RenderHelper]::_renderStats[$component]
        $stats.TotalTime += $milliseconds
        $stats.CallCount += 1
        $stats.AverageTime = $stats.TotalTime / $stats.CallCount
    }
    
    # Get performance statistics
    static [hashtable] GetRenderStats() {
        return [RenderHelper]::_renderStats
    }
    
    # Render themed text with proper reset
    static [string] RenderThemedText([string]$text, [string]$colorKey, [ThemeManager]$theme) {
        if (-not $theme) { return $text }
        
        $sb = Get-PooledStringBuilder 128
        $sb.Append($theme.GetColor($colorKey))
        $sb.Append($text)
        $sb.Append([VT]::Reset())
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
    
    # Render dialog content with proper bounds checking
    static [string] RenderDialogContent([string]$content, [int]$x, [int]$y, [int]$width, [ThemeManager]$theme) {
        if (-not [RenderHelper]::IsInClipBounds($x, $y)) {
            return ""  # Don't render outside clip bounds
        }
        
        $sb = Get-PooledStringBuilder 256
        $sb.Append([VT]::MoveTo($x, $y))
        
        if ($theme) {
            $sb.Append($theme.GetColor('text.primary'))
        }
        
        # Truncate content if too wide
        if ($content.Length -gt $width) {
            $content = $content.Substring(0, $width - 3) + "..."
        }
        
        $sb.Append($content)
        
        # Pad to full width to ensure clean rendering
        $padding = $width - $content.Length
        if ($padding -gt 0) {
            $sb.Append([RenderHelper]::GetPaddingSpaces($padding))
        }
        
        $sb.Append([VT]::Reset())
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
    
    # Apply theme color consistently
    static [string] ApplyThemeColor([string]$content, [string]$colorKey, [ThemeManager]$theme, [bool]$includeReset = $true) {
        if (-not $theme) { return $content }
        
        $color = $theme.GetColor($colorKey)
        if (-not $color) { return $content }
        
        if ($includeReset) {
            return "${color}${content}$([VT]::Reset())"
        } else {
            return "${color}${content}"
        }
    }
    
    # Ensure component renders within parent bounds
    static [string] ClipToParentBounds([UIElement]$element, [string]$content) {
        # If element is outside clip bounds, don't render
        if (-not [RenderHelper]::IsInClipBounds($element.X, $element.Y)) {
            return ""
        }
        
        # TODO: Implement line-by-line clipping for multi-line content
        return $content
    }
}
