# SimpleFileTree.ps1 - Simplified file browser for ExcelDataFlow
# Based on FastFileTree but streamlined for basic file/folder selection

class SimpleFileNode {
    [string]$Name
    [string]$FullPath
    [bool]$IsDirectory
    [bool]$IsExpanded = $false
    [System.Collections.ArrayList]$Children
    [int]$Level = 0
    
    SimpleFileNode([string]$fullPath) {
        $this.FullPath = $fullPath
        $this.Name = Split-Path $fullPath -Leaf
        $this.Children = [System.Collections.ArrayList]::new()
        
        if (Test-Path $fullPath) {
            $item = Get-Item $fullPath -ErrorAction SilentlyContinue
            if ($item) {
                $this.IsDirectory = $item.PSIsContainer
            }
        }
    }
    
    [void] LoadChildren() {
        if (-not $this.IsDirectory) {
            return
        }
        
        try {
            $items = Get-ChildItem $this.FullPath -Force -ErrorAction Stop | Sort-Object @{Expression={$_.PSIsContainer}; Descending=$true}, Name
            
            $this.Children.Clear()
            foreach ($item in $items) {
                $child = [SimpleFileNode]::new($item.FullName)
                $child.Level = $this.Level + 1
                $this.Children.Add($child) | Out-Null
            }
            
        } catch {
            # Access denied or other error - mark as empty
        }
    }
    
    [string] GetIcon() {
        if ($this.IsDirectory) {
            return if ($this.IsExpanded) { "📂" } else { "📁" }
        } else {
            return "📄"
        }
    }
}

class SimpleFileTree : SimpleDialog {
    [string]$RootPath = ""
    [SimpleFileNode]$RootNode
    [System.Collections.ArrayList]$_flatView
    [int]$SelectedIndex = 0
    [int]$ScrollOffset = 0
    [string]$DialogTitle = "Select Folder"
    [bool]$AllowFiles = $false
    [bool]$AllowDirectories = $true
    
    # Results
    [string]$SelectedPath = ""
    [bool]$DialogResult = $false
    
    # Events
    [scriptblock]$OnPathSelected = {}
    
    SimpleFileTree() : base("Select Folder") {
        $this.Width = 70
        $this.Height = 20
        $this._flatView = [System.Collections.ArrayList]::new()
        $this.RootPath = $PWD.Path
        $this.LoadDirectory($this.RootPath)
    }
    
    SimpleFileTree([string]$rootPath) : base("Select Folder") {
        $this.Width = 70
        $this.Height = 20
        $this._flatView = [System.Collections.ArrayList]::new()
        $this.RootPath = $rootPath
    }
    
    [void] InitializeContent() {
        # Set up primary action handler
        $dialog = $this
        $this.OnSubmit = {
            $dialog.SelectPath()
        }.GetNewClosure()
        
        # Load initial directory
        $this.LoadDirectory($this.RootPath)
    }
    
    [void] LoadDirectory([string]$path) {
        if (-not (Test-Path $path -PathType Container)) {
            return
        }
        
        try {
            $this.RootPath = Resolve-Path $path
            $this.RootNode = [SimpleFileNode]::new($this.RootPath)
            $this.RootNode.IsExpanded = $true
            $this.RootNode.LoadChildren()
            
            $this.RebuildFlatView()
            $this.SelectedIndex = 0
            $this.ScrollOffset = 0
            
        } catch {
            # Handle errors gracefully
        }
    }
    
    [void] RebuildFlatView() {
        $this._flatView.Clear()
        if ($this.RootNode) {
            $this.AddNodeToFlatView($this.RootNode)
        }
        
        if ($this.SelectedIndex -ge $this._flatView.Count) {
            $this.SelectedIndex = [Math]::Max(0, $this._flatView.Count - 1)
        }
    }
    
    [void] AddNodeToFlatView([SimpleFileNode]$node) {
        # Only add directories if we're in directory mode, or files if in file mode
        if (($node.IsDirectory -and $this.AllowDirectories) -or (-not $node.IsDirectory -and $this.AllowFiles)) {
            $this._flatView.Add($node) | Out-Null
        }
        
        if ($node.IsExpanded) {
            foreach ($child in $node.Children) {
                $this.AddNodeToFlatView($child)
            }
        }
    }
    
    [SimpleFileNode] GetSelectedNode() {
        if ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this._flatView.Count) {
            return $this._flatView[$this.SelectedIndex]
        }
        return $null
    }
    
    [void] ToggleExpanded([SimpleFileNode]$node) {
        if (-not $node.IsDirectory) {
            return
        }
        
        $node.IsExpanded = -not $node.IsExpanded
        
        if ($node.IsExpanded) {
            $node.LoadChildren()
        }
        
        $this.RebuildFlatView()
        $this.SetSelectedNode($node)
    }
    
    [void] SetSelectedNode([SimpleFileNode]$node) {
        for ($i = 0; $i -lt $this._flatView.Count; $i++) {
            if ($this._flatView[$i].FullPath -eq $node.FullPath) {
                $this.SelectedIndex = $i
                $this.EnsureVisible()
                break
            }
        }
    }
    
    [void] EnsureVisible() {
        $visibleLines = $this.DialogHeight - 6  # Account for borders and buttons
        
        if ($visibleLines -gt 0) {
            if ($this.SelectedIndex -lt $this.ScrollOffset) {
                $this.ScrollOffset = $this.SelectedIndex
            } elseif ($this.SelectedIndex -ge $this.ScrollOffset + $visibleLines) {
                $this.ScrollOffset = $this.SelectedIndex - $visibleLines + 1
            }
            
            $this.ScrollOffset = [Math]::Max(0, $this.ScrollOffset)
        }
    }
    
    [void] SelectPath() {
        $selected = $this.GetSelectedNode()
        
        if ($selected) {
            $this.SelectedPath = $selected.FullPath
            $this.DialogResult = $true
            
            if ($this.OnPathSelected) {
                & $this.OnPathSelected $selected.FullPath
            }
            
            $this.CloseDialog()
        }
    }
    
    [string] OnRender() {
        $sb = [System.Text.StringBuilder]::new(2048)
        
        # Render base dialog
        $baseRender = ([SimpleDialog]$this).Render()
        $sb.Append($baseRender)
        
        # Calculate content area
        $contentX = $this.DialogX + 2
        $contentY = $this.DialogY + 3
        $contentWidth = $this.DialogWidth - 4
        $contentHeight = $this.DialogHeight - 6
        
        # Title
        $sb.Append([VT]::MoveTo($contentX, $contentY - 1))
        $sb.Append([VT]::Blue())
        $titleText = "Path: $($this.RootPath)"
        if ($titleText.Length -gt $contentWidth) {
            $titleText = "..." + $titleText.Substring($titleText.Length - $contentWidth + 3)
        }
        $sb.Append($titleText.PadRight($contentWidth))
        
        # File/folder entries
        $visibleLines = $contentHeight
        $startIndex = $this.ScrollOffset
        $endIndex = [Math]::Min($startIndex + $visibleLines, $this._flatView.Count)
        
        for ($i = $startIndex; $i -lt $endIndex; $i++) {
            $node = $this._flatView[$i]
            $y = $contentY + ($i - $startIndex)
            
            $sb.Append([VT]::MoveTo($contentX, $y))
            
            # Background for selected item
            if ($i -eq $this.SelectedIndex) {
                $sb.Append([VT]::RGBBG(0, 100, 200))
                $sb.Append([VT]::White())
            } else {
                $sb.Append([VT]::Reset())
            }
            
            # Build display line
            $line = ""
            
            # Indentation
            $line += " " * ($node.Level * 2)
            
            # Expand/collapse icon for directories
            if ($node.IsDirectory -and $node.Children.Count -gt 0) {
                $line += if ($node.IsExpanded) { "▼ " } else { "▶ " }
            } else {
                $line += "  "
            }
            
            # File/directory icon and name
            $line += $node.GetIcon() + " " + $node.Name
            
            # Pad and truncate to fit
            if ($line.Length -gt $contentWidth) {
                $line = $line.Substring(0, $contentWidth)
            } else {
                $line = $line.PadRight($contentWidth)
            }
            
            $sb.Append($line)
        }
        
        # Fill empty lines
        for ($i = $endIndex - $startIndex; $i -lt $visibleLines; $i++) {
            $y = $contentY + $i
            $sb.Append([VT]::MoveTo($contentX, $y))
            $sb.Append([VT]::Reset())
            $sb.Append(" " * $contentWidth)
        }
        
        # Scroll indicator
        if ($this._flatView.Count -gt $visibleLines) {
            $scrollY = $contentY + [Math]::Floor(($this.ScrollOffset / $this._flatView.Count) * $visibleLines)
            $sb.Append([VT]::MoveTo($contentX + $contentWidth - 1, $scrollY))
            $sb.Append([VT]::Yellow())
            $sb.Append("█")
        }
        
        return $sb.ToString()
    }
    
    [bool] HandleDialogInput([System.ConsoleKeyInfo]$key) {
        $handled = $false
        
        switch ($key.Key) {
            ([System.ConsoleKey]::UpArrow) {
                if ($this.SelectedIndex -gt 0) {
                    $this.SelectedIndex--
                    $this.EnsureVisible()
                    $handled = $true
                }
            }
            ([System.ConsoleKey]::DownArrow) {
                if ($this.SelectedIndex -lt $this._flatView.Count - 1) {
                    $this.SelectedIndex++
                    $this.EnsureVisible()
                    $handled = $true
                }
            }
            ([System.ConsoleKey]::Enter) {
                $selected = $this.GetSelectedNode()
                if ($selected) {
                    if ($selected.IsDirectory -and $selected.Children.Count -gt 0) {
                        $this.ToggleExpanded($selected)
                    } else {
                        $this.SelectPath()
                    }
                }
                $handled = $true
            }
            ([System.ConsoleKey]::Spacebar) {
                $selected = $this.GetSelectedNode()
                if ($selected -and $selected.IsDirectory) {
                    $this.ToggleExpanded($selected)
                    $handled = $true
                }
            }
            ([System.ConsoleKey]::Backspace) {
                $parentPath = Split-Path $this.RootPath -Parent
                if ($parentPath -and (Test-Path $parentPath)) {
                    $this.LoadDirectory($parentPath)
                    $handled = $true
                }
            }
            ([System.ConsoleKey]::PageUp) {
                $pageSize = $this.DialogHeight - 6
                $this.SelectedIndex = [Math]::Max(0, $this.SelectedIndex - $pageSize)
                $this.EnsureVisible()
                $handled = $true
            }
            ([System.ConsoleKey]::PageDown) {
                $pageSize = $this.DialogHeight - 6
                $this.SelectedIndex = [Math]::Min($this._flatView.Count - 1, $this.SelectedIndex + $pageSize)
                $this.EnsureVisible()
                $handled = $true
            }
        }
        
        if ($handled) {
            $this.Invalidate()
        }
        
        return $handled
    }
}