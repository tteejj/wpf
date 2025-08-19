# DialogField.ps1 - Key:Value field component for dialogs with reverse highlighting

class DialogField : FocusableComponent {
    [string]$Key = ""
    [string]$Value = ""
    [string]$Placeholder = ""
    [int]$KeyWidth = 12  # Width reserved for the key
    [int]$MaxLength = 0  # 0 = no limit
    [bool]$IsPassword = $false
    [scriptblock]$OnTextChanged = {}
    [scriptblock]$OnEnter = {}
    
    # Internal textbox for value input
    hidden [int]$_cursorPosition = 0
    hidden [int]$_viewportStart = 0
    hidden [bool]$_showCursor = $true
    
    # Cached colors
    hidden [string]$_keyNormalColor = ""
    hidden [string]$_valueNormalColor = ""
    hidden [string]$_placeholderColor = ""
    hidden [string]$_focusReverseBg = ""
    hidden [string]$_focusReverseText = ""
    hidden [string]$_borderFocusedColor = ""
    
    DialogField([string]$key) : base() {
        $this.Key = $key
        $this.Height = 1  # Single row, NO border
        $this.FocusStyle = 'minimal'
    }
    
    DialogField([string]$key, [string]$placeholder) : base() {
        $this.Key = $key
        $this.Placeholder = $placeholder
        $this.Height = 1  # Single row, NO border
        $this.FocusStyle = 'minimal'
    }
    
    [void] OnInitialize() {
        ([FocusableComponent]$this).OnInitialize()
        $this.UpdateColors()
        if ($this.Theme) {
            # Subscribe to theme changes
            $eventBus = $this.ServiceContainer.GetService('EventBus')
            if ($eventBus) {
                $eventBus.Subscribe('theme.changed', {
                    param($sender, $eventData)
                    $this.UpdateColors()
                }.GetNewClosure())
            }
        }
    }
    
    [void] UpdateColors() {
        if ($this.Theme) {
            $this._keyNormalColor = $this.Theme.GetColor('text.secondary')
            $this._valueNormalColor = $this.Theme.GetColor('input.text')
            $this._placeholderColor = $this.Theme.GetColor('input.placeholder')
            $this._focusReverseBg = $this.Theme.GetBgColor('focus.reverse.background')
            $this._focusReverseText = $this.Theme.GetColor('focus.reverse.text')
            $this._borderFocusedColor = $this.Theme.GetColor('border.input.focused')
        }
    }
    
    [void] SetValue([string]$newValue) {
        if ($this.MaxLength -gt 0 -and $newValue.Length -gt $this.MaxLength) {
            $newValue = $newValue.Substring(0, $this.MaxLength)
        }
        
        if ($this.Value -ne $newValue) {
            $this.Value = $newValue
            $this._cursorPosition = $newValue.Length
            $this.UpdateViewport()
            $this.Invalidate()
            
            if ($this.OnTextChanged) {
                & $this.OnTextChanged
            }
        }
    }
    
    [string] RenderContent() {
        $sb = Get-PooledStringBuilder 512
        
        # NO BORDERS - just highlight the line when focused
        
        # Calculate positions - no border adjustments needed
        $contentX = $this.X
        $contentY = $this.Y
        $availableWidth = $this.Width
        
        # Key positioning (left side)
        $keyText = "$($this.Key):"
        $keyDisplayWidth = [Math]::Min($this.KeyWidth, $keyText.Length)
        
        # Value field positioning (right side)
        $valueX = $contentX + $this.KeyWidth + 1  # +1 for space
        $valueWidth = $availableWidth - $this.KeyWidth - 1
        
        if ($valueWidth -le 0) { $valueWidth = 10 }  # Minimum width
        
        # Position for rendering
        $sb.Append([VT]::MoveTo($contentX, $contentY))
        
        if ($this.IsFocused) {
            # REVERSE HIGHLIGHTING: Key gets bold reverse treatment
            $sb.Append($this._focusReverseBg)
            $sb.Append($this._focusReverseText)
            $sb.Append($keyText.PadRight($this.KeyWidth))
            
            # Space between key and value (normal background)
            $sb.Append([VT]::Reset())
            $sb.Append(' ')
            
            # Value field - normal colors but with focused styling
            $sb.Append($this._valueNormalColor)
            $this.RenderValueField($sb, $valueX, $contentY, $valueWidth)
        } else {
            # Unfocused - clean, no borders
            $sb.Append($this._keyNormalColor)
            $sb.Append($keyText.PadRight($this.KeyWidth))
            $sb.Append(' ')
            
            # Value field
            $sb.Append($this._valueNormalColor)
            $this.RenderValueField($sb, $valueX, $contentY, $valueWidth)
        }
        
        $sb.Append([VT]::Reset())
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
    
    [void] RenderValueField([System.Text.StringBuilder]$sb, [int]$x, [int]$y, [int]$width) {
        # Move to value field position
        $sb.Append([VT]::MoveTo($x, $y))
        
        # Determine display text
        $displayText = ""
        if ($this.Value.Length -gt 0) {
            if ($this.IsPassword) {
                $displayText = '•' * $this.Value.Length
            } else {
                $displayText = $this.Value
            }
        } elseif (-not $this.IsFocused -and $this.Placeholder) {
            $sb.Append($this._placeholderColor)
            $displayText = $this.Placeholder
        }
        
        # Handle viewport for long text
        if ($displayText.Length -gt $width) {
            $displayText = $displayText.Substring($this._viewportStart, [Math]::Min($width, $displayText.Length - $this._viewportStart))
        }
        
        # Render value with cursor if focused
        if ($this.IsFocused -and $this._showCursor) {
            $cursorPos = $this._cursorPosition - $this._viewportStart
            
            if ($cursorPos -ge 0 -and $cursorPos -le $displayText.Length) {
                # Text before cursor
                if ($cursorPos -gt 0) {
                    $sb.Append($displayText.Substring(0, $cursorPos))
                }
                
                # Cursor
                $sb.Append($this.Theme.GetColor('color.primary'))
                $sb.Append('▌')
                $sb.Append($this._valueNormalColor)
                
                # Text after cursor
                if ($cursorPos -lt $displayText.Length) {
                    $sb.Append($displayText.Substring($cursorPos))
                }
                
                # Pad remaining width
                $totalRendered = $displayText.Length + 1  # +1 for cursor
                if ($totalRendered -lt $width) {
                    $sb.Append(' ' * ($width - $totalRendered))
                }
            } else {
                $sb.Append($displayText.PadRight($width))
            }
        } else {
            $sb.Append($displayText.PadRight($width))
        }
    }
    
    [void] UpdateViewport() {
        $valueWidth = $this.Width - $this.KeyWidth - 3  # Account for border and spacing
        if ($valueWidth -le 0) { $valueWidth = 10 }
        
        # Ensure cursor is visible in value field
        if ($this._cursorPosition -lt $this._viewportStart) {
            $this._viewportStart = $this._cursorPosition
        } elseif ($this._cursorPosition -ge ($this._viewportStart + $valueWidth)) {
            $this._viewportStart = $this._cursorPosition - $valueWidth + 1
        }
        
        $this._viewportStart = [Math]::Max(0, $this._viewportStart)
    }
    
    [bool] OnHandleInput([System.ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([System.ConsoleKey]::LeftArrow) {
                if ($this._cursorPosition -gt 0) {
                    $this._cursorPosition--
                    $this.UpdateViewport()
                    $this.Invalidate()
                }
                return $true
            }
            ([System.ConsoleKey]::RightArrow) {
                if ($this._cursorPosition -lt $this.Value.Length) {
                    $this._cursorPosition++
                    $this.UpdateViewport()
                    $this.Invalidate()
                }
                return $true
            }
            ([System.ConsoleKey]::Home) {
                $this._cursorPosition = 0
                $this._viewportStart = 0
                $this.Invalidate()
                return $true
            }
            ([System.ConsoleKey]::End) {
                $this._cursorPosition = $this.Value.Length
                $this.UpdateViewport()
                $this.Invalidate()
                return $true
            }
            ([System.ConsoleKey]::Backspace) {
                if ($this._cursorPosition -gt 0) {
                    $this.Value = $this.Value.Remove($this._cursorPosition - 1, 1)
                    $this._cursorPosition--
                    $this.UpdateViewport()
                    $this.Invalidate()
                    if ($this.OnTextChanged) { & $this.OnTextChanged }
                }
                return $true
            }
            ([System.ConsoleKey]::Delete) {
                if ($this._cursorPosition -lt $this.Value.Length) {
                    $this.Value = $this.Value.Remove($this._cursorPosition, 1)
                    $this.Invalidate()
                    if ($this.OnTextChanged) { & $this.OnTextChanged }
                }
                return $true
            }
            ([System.ConsoleKey]::Enter) {
                if ($this.OnEnter) {
                    & $this.OnEnter
                }
                return $true
            }
            default {
                # Handle character input
                if ($key.KeyChar -and $key.KeyChar -ge ' ') {
                    if ($this.MaxLength -eq 0 -or $this.Value.Length -lt $this.MaxLength) {
                        $this.Value = $this.Value.Insert($this._cursorPosition, $key.KeyChar)
                        $this._cursorPosition++
                        $this.UpdateViewport()
                        $this.Invalidate()
                        if ($this.OnTextChanged) { & $this.OnTextChanged }
                    }
                    return $true
                }
            }
        }
        
        return $false
    }
    
    [void] OnGotFocus() {
        $this._showCursor = $true
        ([FocusableComponent]$this).OnGotFocus()
    }
    
    [void] OnLostFocus() {
        $this._showCursor = $false
        ([FocusableComponent]$this).OnLostFocus()
    }
}