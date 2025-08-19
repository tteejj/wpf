# MinimalDataGrid.ps1 - Simple data grid for ExcelDataFlow
# Three-column editable grid for field mappings

class MinimalDataGrid : UIElement {
    [System.Collections.ArrayList]$Items
    [int]$SelectedIndex = 0
    [int]$ScrollOffset = 0
    [bool]$ShowHeaders = $true
    [string[]]$Headers = @("Field Name", "Source Cell", "Dest Cell")
    [int[]]$ColumnWidths = @(20, 15, 15)
    [scriptblock]$OnItemChanged = {}
    [scriptblock]$OnSelectionChanged = {}
    
    # Edit mode
    [bool]$IsEditing = $false
    [int]$EditColumn = 0
    [MinimalTextBox]$EditBox
    
    MinimalDataGrid() : base() {
        $this.IsFocusable = $true
        $this.Items = [System.Collections.ArrayList]::new()
        $this.EditBox = [MinimalTextBox]::new()
        $this.EditBox.Visible = $false
    }
    
    [void] Initialize([ServiceContainer]$services) {
        ([UIElement]$this).Initialize($services)
        $this.EditBox.Initialize($services)
    }
    
    [void] AddItem([hashtable]$item) {
        $this.Items.Add($item) | Out-Null
        $this.Invalidate()
    }
    
    [void] RemoveSelectedItem() {
        if ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this.Items.Count) {
            $this.Items.RemoveAt($this.SelectedIndex)
            if ($this.SelectedIndex -ge $this.Items.Count -and $this.Items.Count -gt 0) {
                $this.SelectedIndex = $this.Items.Count - 1
            }
            $this.Invalidate()
        }
    }
    
    [hashtable] GetSelectedItem() {
        if ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this.Items.Count) {
            return $this.Items[$this.SelectedIndex]
        }
        return $null
    }
    
    [string] OnRender() {
        $result = ""
        $currentY = $this.Y
        
        # Add scroll indicator at top if needed
        if ($this.ScrollOffset -gt 0 -or ($this.ScrollOffset + $this.GetVisibleRows() -lt $this.Items.Count)) {
            $result += [VT]::MoveTo($this.X + $this.Width - 15, $this.Y)
            $result += [VT]::RGB(100, 100, 100)
            $scrollInfo = "[$($this.ScrollOffset + 1)-$([Math]::Min($this.Items.Count, $this.ScrollOffset + $this.GetVisibleRows()))/$($this.Items.Count)]"
            $result += $scrollInfo
            $result += [VT]::Reset()
        }
        
        # Render headers with improved styling
        if ($this.ShowHeaders) {
            $result += [VT]::MoveTo($this.X, $currentY)
            $result += [VT]::RGBBG(50, 50, 100) + [VT]::White() + [VT]::Bold()
            
            $headerText = ""
            for ($i = 0; $i -lt $this.Headers.Length; $i++) {
                if ($i -lt $this.ColumnWidths.Length) {
                    $width = $this.ColumnWidths[$i]
                } else {
                    $width = 15
                }
                $headerText += $this.Headers[$i].PadRight($width).Substring(0, [Math]::Min($width, $this.Headers[$i].Length))
                if ($i -lt $this.Headers.Length - 1) { $headerText += " │ " }
            }
            $result += $headerText
            $result += [VT]::Reset()
            $currentY++
            
            # Header separator with improved styling
            $result += [VT]::MoveTo($this.X, $currentY)
            $result += [VT]::RGB(100, 100, 100)
            $separatorLength = [Math]::Max(0, ($this.ColumnWidths | Measure-Object -Sum).Sum + (($this.ColumnWidths.Length - 1) * 3))
            $result += ("─" * $separatorLength)
            $result += [VT]::Reset()
            $currentY++
        }
        
        # Render items with improved focus indicators
        $visibleRows = $this.GetVisibleRows()
        $endIndex = [Math]::Min($this.Items.Count, $this.ScrollOffset + $visibleRows)
        
        for ($i = $this.ScrollOffset; $i -lt $endIndex; $i++) {
            $item = $this.Items[$i]
            $isSelected = ($i -eq $this.SelectedIndex)
            
            $result += [VT]::MoveTo($this.X, $currentY)
            
            # Enhanced row highlighting
            if ($isSelected -and $this.IsFocused) {
                if ($this.IsEditing) {
                    $result += [VT]::RGBBG(0, 80, 160) + [VT]::White()  # Edit mode: darker blue
                } else {
                    $result += [VT]::RGBBG(0, 120, 200) + [VT]::White()  # Selected: bright blue
                }
            } elseif ($isSelected) {
                $result += [VT]::RGBBG(80, 80, 80) + [VT]::White()     # Selected but not focused: gray
            } else {
                $result += [VT]::RGB(200, 200, 200)                    # Normal: light gray
            }
            
            # Render columns with better formatting
            $rowText = ""
            $columns = @($item.FieldName, $item.SourceCell, $item.DestCell)
            for ($col = 0; $col -lt $columns.Length; $col++) {
                if ($col -lt $this.ColumnWidths.Length) {
                    $width = $this.ColumnWidths[$col]
                } else {
                    $width = 15
                }
                
                if ($columns[$col]) {
                    $text = $columns[$col]
                } else {
                    $text = ""
                }
                
                # Highlight edit cell with distinct styling
                if ($isSelected -and $this.IsEditing -and $col -eq $this.EditColumn) {
                    $rowText += [VT]::Reset() + [VT]::RGBBG(255, 255, 0) + [VT]::Black()  # Yellow edit highlight
                    $rowText += $text.PadRight($width).Substring(0, [Math]::Min($width, $text.Length))
                    $rowText += [VT]::Reset()
                    if ($isSelected -and $this.IsFocused) { 
                        $rowText += [VT]::RGBBG(0, 120, 200) + [VT]::White()
                    }
                } else {
                    $rowText += $text.PadRight($width).Substring(0, [Math]::Min($width, $text.Length))
                }
                
                if ($col -lt $columns.Length - 1) { $rowText += " │ " }
            }
            
            $result += $rowText
            $result += [VT]::Reset()
            $currentY++
        }
        
        # Clear remaining lines
        for ($i = $currentY; $i -lt ($this.Y + $this.Height); $i++) {
            $result += [VT]::MoveTo($this.X, $i)
            $clearWidth = [Math]::Max(0, $this.Width)
            $result += (" " * $clearWidth)
        }
        
        # Add navigation help at bottom if focused
        if ($this.IsFocused -and -not $this.IsEditing) {
            $helpY = $this.Y + $this.Height
            $result += [VT]::MoveTo($this.X, $helpY)
            $result += [VT]::RGB(120, 120, 120)
            $result += "↑↓: Navigate │ ←→: Select Column │ Enter/F2: Edit │ Del: Delete Row │ PgUp/PgDn: Scroll"
            $result += [VT]::Reset()
        }
        
        # Render edit box if editing
        if ($this.IsEditing -and $this.EditBox.Visible) {
            $result += $this.EditBox.Render()
        }
        
        return $result
    }
    
    [int] GetVisibleRows() {
        if ($this.ShowHeaders) {
            return [Math]::Max(1, $this.Height - 2)
        } else {
            return [Math]::Max(1, $this.Height)
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        # If editing, route to edit box
        if ($this.IsEditing) {
            switch ($key.Key) {
                ([System.ConsoleKey]::Enter) {
                    $this.FinishEditing($true)
                    return $true
                }
                ([System.ConsoleKey]::Escape) {
                    $this.FinishEditing($false)
                    return $true
                }
                default {
                    return $this.EditBox.HandleInput($key)
                }
            }
        }
        
        # Enhanced navigation with scrolling support
        switch ($key.Key) {
            ([System.ConsoleKey]::UpArrow) {
                $this.MoveSelection(-1)
                return $true
            }
            ([System.ConsoleKey]::DownArrow) {
                $this.MoveSelection(1)
                return $true
            }
            ([System.ConsoleKey]::LeftArrow) {
                $this.MoveEditColumn(-1)
                return $true
            }
            ([System.ConsoleKey]::RightArrow) {
                $this.MoveEditColumn(1)
                return $true
            }
            ([System.ConsoleKey]::PageUp) {
                $pageSize = [Math]::Max(1, $this.GetVisibleRows() - 1)
                $this.MoveSelection(-$pageSize)
                return $true
            }
            ([System.ConsoleKey]::PageDown) {
                $pageSize = [Math]::Max(1, $this.GetVisibleRows() - 1)
                $this.MoveSelection($pageSize)
                return $true
            }
            ([System.ConsoleKey]::Home) {
                if ($key.Modifiers -band [System.ConsoleModifiers]::Control) {
                    # Ctrl+Home: Go to first item
                    $newIndex = 0
                } else {
                    # Home: Go to first column
                    $this.EditColumn = 0
                    $this.Invalidate()
                    return $true
                }
                if ($newIndex -ne $this.SelectedIndex) {
                    $this.SelectedIndex = $newIndex
                    $this.AdjustScroll()
                    $this.Invalidate()
                }
                return $true
            }
            ([System.ConsoleKey]::End) {
                if ($key.Modifiers -band [System.ConsoleModifiers]::Control) {
                    # Ctrl+End: Go to last item
                    $newIndex = [Math]::Max(0, $this.Items.Count - 1)
                } else {
                    # End: Go to last column
                    $this.EditColumn = 2
                    $this.Invalidate()
                    return $true
                }
                if ($newIndex -ne $this.SelectedIndex) {
                    $this.SelectedIndex = $newIndex
                    $this.AdjustScroll()
                    $this.Invalidate()
                }
                return $true
            }
            ([System.ConsoleKey]::Enter) {
                $this.StartEditing()
                return $true
            }
            ([System.ConsoleKey]::F2) {
                $this.StartEditing()
                return $true
            }
            ([System.ConsoleKey]::Delete) {
                $this.RemoveSelectedItem()
                return $true
            }
            ([System.ConsoleKey]::Insert) {
                # Add new row
                $newItem = @{ FieldName = "New Field"; SourceCell = ""; DestCell = "" }
                $this.AddItem($newItem)
                $this.SelectedIndex = $this.Items.Count - 1
                $this.AdjustScroll()
                $this.Invalidate()
                return $true
            }
        }
        
        return $false
    }
    
    [void] MoveSelection([int]$delta) {
        $newIndex = $this.SelectedIndex + $delta
        $newIndex = [Math]::Max(0, [Math]::Min($this.Items.Count - 1, $newIndex))
        
        if ($newIndex -ne $this.SelectedIndex) {
            $this.SelectedIndex = $newIndex
            $this.AdjustScroll()
            $this.Invalidate()
            
            if ($this.OnSelectionChanged) {
                & $this.OnSelectionChanged
            }
        }
    }
    
    [void] MoveEditColumn([int]$delta) {
        $newColumn = $this.EditColumn + $delta
        $newColumn = [Math]::Max(0, [Math]::Min(2, $newColumn))  # 3 columns (0, 1, 2)
        
        if ($newColumn -ne $this.EditColumn) {
            $this.EditColumn = $newColumn
            $this.Invalidate()
        }
    }
    
    [void] StartEditing() {
        if ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this.Items.Count) {
            $item = $this.Items[$this.SelectedIndex]
            $this.IsEditing = $true
            
            # Position edit box
            if ($this.ShowHeaders) {
                $headerRows = 2
            } else {
                $headerRows = 0
            }
            $rowY = $this.Y + $headerRows + ($this.SelectedIndex - $this.ScrollOffset)
            
            $colX = $this.X
            for ($i = 0; $i -lt $this.EditColumn; $i++) {
                $colX += $this.ColumnWidths[$i] + 3  # +3 for " | "
            }
            
            $editWidth = [Math]::Max(1, $this.ColumnWidths[$this.EditColumn])
            $this.EditBox.SetBounds($colX, $rowY, $editWidth, 1)
            
            # Set current text
            $currentText = switch ($this.EditColumn) {
                0 { $item.FieldName }
                1 { $item.SourceCell }
                2 { $item.DestCell }
                default { "" }
            }
            
            $this.EditBox.SetText($currentText)
            $this.EditBox.Visible = $true
            $this.EditBox.Focus()
            $this.Invalidate()
        }
    }
    
    [void] FinishEditing([bool]$save) {
        if ($this.IsEditing) {
            if ($save -and $this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this.Items.Count) {
                $item = $this.Items[$this.SelectedIndex]
                $newText = $this.EditBox.Text
                
                switch ($this.EditColumn) {
                    0 { $item.FieldName = $newText }
                    1 { $item.SourceCell = $newText }
                    2 { $item.DestCell = $newText }
                }
                
                if ($this.OnItemChanged) {
                    & $this.OnItemChanged $item
                }
            }
            
            $this.IsEditing = $false
            $this.EditBox.Visible = $false
            $this.Focus()  # Return focus to grid
            $this.Invalidate()
        }
    }
    
    [void] AdjustScroll() {
        if ($this.ShowHeaders) {
            $visibleRows = [Math]::Max(1, $this.Height - 2)
        } else {
            $visibleRows = [Math]::Max(1, $this.Height)
        }
        
        if ($this.SelectedIndex -lt $this.ScrollOffset) {
            $this.ScrollOffset = $this.SelectedIndex
        } elseif ($this.SelectedIndex -ge ($this.ScrollOffset + $visibleRows)) {
            $this.ScrollOffset = $this.SelectedIndex - $visibleRows + 1
        }
        
        $this.ScrollOffset = [Math]::Max(0, $this.ScrollOffset)
    }
}