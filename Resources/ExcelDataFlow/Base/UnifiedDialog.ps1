# UnifiedDialog.ps1 - Working dialog system for ExcelDataFlow
# Simplified version that actually renders fields inside the dialog

class UnifiedDialog : Screen {
    # Core properties
    [string]$DialogTitle = "Dialog"
    [int]$DialogWidth = 60
    [int]$DialogHeight = 20
    [BorderType]$BorderType = [BorderType]::Rounded
    
    # Event handlers
    [scriptblock]$OnSubmit = {}
    [scriptblock]$OnCancel = {}
    
    # Internal state
    hidden [int]$_dialogX = 0
    hidden [int]$_dialogY = 0
    hidden [System.Collections.Generic.List[UIElement]]$_fields
    hidden [System.Collections.Generic.List[MinimalButton]]$_buttons
    hidden [bool]$_initialized = $false
    
    UnifiedDialog([string]$title) : base() {
        $this.DialogTitle = $title
        $this.Title = $title
        $this._fields = [System.Collections.Generic.List[UIElement]]::new()
        $this._buttons = [System.Collections.Generic.List[MinimalButton]]::new()
        $this.DrawBackground = $false
    }
    
    UnifiedDialog([string]$title, [int]$width, [int]$height) : base() {
        $this.DialogTitle = $title
        $this.Title = $title
        $this.DialogWidth = $width
        $this.DialogHeight = $height
        $this._fields = [System.Collections.Generic.List[UIElement]]::new()
        $this._buttons = [System.Collections.Generic.List[MinimalButton]]::new()
        $this.DrawBackground = $false
    }
    
    # Simple field API
    [void] AddField([string]$name, [string]$label, [string]$defaultValue = "") {
        $field = [MinimalTextBox]::new()
        $field.Height = 1
        $field.Placeholder = $label
        $field.Text = $defaultValue
        
        # Store field name for retrieval
        $field | Add-Member -NotePropertyName "FieldName" -NotePropertyValue $name
        $field | Add-Member -NotePropertyName "Label" -NotePropertyValue $label
        
        $this._fields.Add($field)
        $this.AddChild($field)
    }
    
    # Advanced control API
    [void] AddControl([UIElement]$control) {
        $this._fields.Add($control)
        $this.AddChild($control)
    }
    
    # Get field values
    [string] GetFieldValue([string]$name) {
        foreach ($field in $this._fields) {
            if ($field.FieldName -eq $name -and $field -is [MinimalTextBox]) {
                return $field.Text
            }
        }
        return ""
    }
    
    [hashtable] GetAllFieldValues() {
        $values = @{}
        foreach ($field in $this._fields) {
            if ($field.FieldName -and $field -is [MinimalTextBox]) {
                $values[$field.FieldName] = $field.Text
            }
        }
        return $values
    }
    
    # Button management
    [void] SetButtons([string]$primaryText, [string]$secondaryText = "Cancel") {
        # Clear existing buttons
        foreach ($button in $this._buttons) {
            $this.RemoveChild($button)
        }
        $this._buttons.Clear()
        
        # Create primary button
        $primaryButton = [MinimalButton]::new($primaryText)
        $primaryButton.IsDefault = $true
        $dialog = $this
        $primaryButton.OnClick = {
            if ($dialog.OnSubmit) { & $dialog.OnSubmit }
        }.GetNewClosure()
        
        # Create secondary button
        $secondaryButton = [MinimalButton]::new($secondaryText)
        $secondaryButton.OnClick = {
            if ($dialog.OnCancel) { & $dialog.OnCancel }
            $dialog.Close()
        }.GetNewClosure()
        
        $this._buttons.Add($primaryButton)
        $this._buttons.Add($secondaryButton)
        $this.AddChild($primaryButton)
        $this.AddChild($secondaryButton)
    }
    
    # Initialization
    [void] OnInitialize() {
        if ($this._initialized) { return }
        $this._initialized = $true
        
        # Call parent initialization
        ([Screen]$this).OnInitialize()
        
        # Calculate dialog position
        $this.CalculatePosition()
        
        # Create default buttons if none exist
        if ($this._buttons.Count -eq 0) {
            $this.SetButtons("OK", "Cancel")
        }
        
        # Layout all fields and buttons
        $this.LayoutFields()
    }
    
    # Position calculation
    [void] CalculatePosition() {
        $consoleW = [Console]::WindowWidth
        $consoleH = [Console]::WindowHeight
        
        # Use almost full screen for large content
        $this.DialogWidth = [Math]::Min($this.DialogWidth, $consoleW - 4)
        $this.DialogHeight = [Math]::Min($this.DialogHeight, $consoleH - 1)  # Use almost full screen height
        
        # Center dialog
        $this._dialogX = [Math]::Max(1, [int](($consoleW - $this.DialogWidth) / 2))
        $this._dialogY = [Math]::Max(1, [int](($consoleH - $this.DialogHeight) / 2))
    }
    
    # Layout fields inside dialog
    [void] LayoutFields() {
        # Content area inside dialog borders
        $contentX = $this._dialogX + 2  # Inside border
        $contentY = $this._dialogY + 3  # Below title and border
        $contentWidth = $this.DialogWidth - 4  # Account for borders
        
        # Calculate required space for fields
        $fieldsHeight = 0
        foreach ($field in $this._fields) {
            if ($field.Visible) {
                if ($field.Label) {
                    $fieldsHeight += 1  # Space for label
                }
                $fieldsHeight += $field.Height + 1  # Field height + spacing
            }
        }
        
        # Reserve space for buttons (3 lines: spacing + button + spacing)
        $buttonSpace = 5
        $availableHeight = $this.DialogHeight - 6  # Title + borders
        
        # Ensure we have enough height, expand dialog if needed
        $requiredHeight = $fieldsHeight + $buttonSpace
        if ($requiredHeight -gt $availableHeight) {
            $this.DialogHeight = $requiredHeight + 6  # Add back title + borders
            $this.CalculatePosition()  # Recalculate position with new height
        }
        
        # Layout fields vertically with labels
        $currentY = $contentY
        foreach ($field in $this._fields) {
            if ($field.Visible) {
                # Reserve space for label if field has one
                if ($field.Label) {
                    $currentY += 1  # Space for label
                }
                
                $field.SetBounds($contentX, $currentY, $contentWidth, $field.Height)
                $currentY += $field.Height + 1  # Field height + spacing
            }
        }
        
        # Layout buttons at bottom with proper spacing
        if ($this._buttons.Count -gt 0) {
            $buttonY = $this._dialogY + $this.DialogHeight - 4  # Leave room at bottom
            $buttonWidth = 12
            $buttonSpacing = 4
            $totalButtonWidth = ($this._buttons.Count * $buttonWidth) + (($this._buttons.Count - 1) * $buttonSpacing)
            $startX = $this._dialogX + [int](($this.DialogWidth - $totalButtonWidth) / 2)
            
            for ($i = 0; $i -lt $this._buttons.Count; $i++) {
                $buttonX = $startX + ($i * ($buttonWidth + $buttonSpacing))
                $this._buttons[$i].SetBounds($buttonX, $buttonY, $buttonWidth, 1)
            }
        }
    }
    
    # Rendering
    [string] OnRender() {
        if (-not $this._initialized) {
            $this.OnInitialize()
        }
        
        $result = ""
        
        # Clear screen
        $result += [VT]::ClearScreen()
        
        # Draw dialog border and background
        $result += $this.RenderDialogBox()
        
        # Draw title
        $result += $this.RenderTitle()
        
        # Render field labels
        $result += $this.RenderFieldLabels()
        
        # Render all children (fields and buttons) - temporarily disable bounds check
        foreach ($child in $this.Children) {
            if ($child.Visible) {
                $result += $child.Render()
            }
        }
        
        return $result
    }
    
    [string] RenderDialogBox() {
        $result = ""
        
        # Get basic colors or use defaults
        $borderColor = ""
        $bgColor = ""
        if ($this.Theme) {
            $borderColor = $this.Theme.GetColor("border.dialog")
            $bgColor = $this.Theme.GetBgColor("surface.dialog")
        }
        
        # Fill background
        for ($i = 0; $i -lt $this.DialogHeight; $i++) {
            $result += [VT]::MoveTo($this._dialogX, $this._dialogY + $i)
            if ($bgColor) { $result += $bgColor }
            $result += (" " * $this.DialogWidth)
            if ($bgColor) { $result += [VT]::Reset() }
        }
        
        # Draw border
        $result += [BorderStyle]::RenderBorder(
            $this._dialogX, $this._dialogY, 
            $this.DialogWidth, $this.DialogHeight,
            $this.BorderType, $borderColor
        )
        
        return $result
    }
    
    [string] RenderTitle() {
        $result = ""
        if ($this.DialogTitle) {
            $titleText = " $($this.DialogTitle) "
            $titleX = $this._dialogX + [int](($this.DialogWidth - $titleText.Length) / 2)
            
            $result += [VT]::MoveTo($titleX, $this._dialogY)
            $result += $titleText
        }
        return $result
    }
    
    [string] RenderFieldLabels() {
        $result = ""
        
        foreach ($field in $this._fields) {
            if ($field.Label -and $field.Visible) {
                # Render label above the field
                $labelY = $field.Y - 1
                if ($labelY -gt $this._dialogY) {
                    $result += [VT]::MoveTo($field.X, $labelY)
                    $result += "$($field.Label):"
                }
            }
        }
        
        return $result
    }
    
    # Check if child control is within dialog boundaries
    [bool] IsChildWithinDialogBounds([UIElement]$child) {
        # For now, always return true - but log position for debugging
        $dialogLeft = $this._dialogX + 1
        $dialogRight = $this._dialogX + $this.DialogWidth - 1
        $dialogTop = $this._dialogY + 1
        $dialogBottom = $this._dialogY + $this.DialogHeight - 1
        
        $childLeft = $child.X
        $childRight = $child.X + $child.Width
        $childTop = $child.Y
        $childBottom = $child.Y + $child.Height
        
        # Check if child overlaps with dialog area
        $withinBounds = $childLeft -ge $dialogLeft -and $childRight -le $dialogRight -and $childTop -ge $dialogTop -and $childBottom -le $dialogBottom
        
        return $withinBounds
    }
    
    # Input handling with Tab navigation support
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([System.ConsoleKey]::Tab) {
                if ($key.Modifiers -band [System.ConsoleModifiers]::Shift) {
                    $this.FocusPrevious()
                } else {
                    $this.FocusNext()
                }
                return $true
            }
            ([System.ConsoleKey]::Enter) {
                # If a button is focused, activate it; otherwise submit
                $focused = $this.GetFocusedControl()
                if ($focused -and $focused -is [MinimalButton]) {
                    if ($focused.OnClick) { & $focused.OnClick }
                } else {
                    if ($this.OnSubmit) { & $this.OnSubmit }
                }
                return $true
            }
            ([System.ConsoleKey]::Escape) {
                if ($this.OnCancel) { & $this.OnCancel }
                $this.Close()
                return $true
            }
        }
        return $false
    }
    
    # Get all focusable controls in tab order
    [UIElement[]] GetFocusableControls() {
        $focusable = @()
        foreach ($field in $this._fields) {
            if ($field.IsFocusable -and $field.Visible) {
                $focusable += $field
            }
        }
        foreach ($button in $this._buttons) {
            if ($button.IsFocusable -and $button.Visible) {
                $focusable += $button
            }
        }
        return $focusable
    }
    
    # Get currently focused control
    [UIElement] GetFocusedControl() {
        $focusable = $this.GetFocusableControls()
        foreach ($control in $focusable) {
            if ($control.IsFocused) {
                return $control
            }
        }
        return $null
    }
    
    # Focus next control in tab order
    [void] FocusNext() {
        $focusable = $this.GetFocusableControls()
        if ($focusable.Length -eq 0) { return }
        
        $current = $this.GetFocusedControl()
        if (-not $current) {
            # Nothing focused, focus first
            $focusable[0].Focus()
            return
        }
        
        # Find current index and move to next
        for ($i = 0; $i -lt $focusable.Length; $i++) {
            if ($focusable[$i] -eq $current) {
                $nextIndex = ($i + 1) % $focusable.Length
                $focusable[$nextIndex].Focus()
                return
            }
        }
        
        # Fallback: focus first
        $focusable[0].Focus()
    }
    
    # Focus previous control in tab order
    [void] FocusPrevious() {
        $focusable = $this.GetFocusableControls()
        if ($focusable.Length -eq 0) { return }
        
        $current = $this.GetFocusedControl()
        if (-not $current) {
            # Nothing focused, focus last
            $focusable[-1].Focus()
            return
        }
        
        # Find current index and move to previous
        for ($i = 0; $i -lt $focusable.Length; $i++) {
            if ($focusable[$i] -eq $current) {
                $prevIndex = if ($i -eq 0) { $focusable.Length - 1 } else { $i - 1 }
                $focusable[$prevIndex].Focus()
                return
            }
        }
        
        # Fallback: focus last
        $focusable[-1].Focus()
    }
    
    # Close dialog
    [void] Close() {
        [Environment]::Exit(0)
    }
    
    # Focus management
    [void] OnActivated() {
        ([Screen]$this).OnActivated()
        
        # Focus first focusable control
        $focusable = $this.GetFocusableControls()
        if ($focusable.Length -gt 0) {
            $focusable[0].Focus()
        }
    }
}