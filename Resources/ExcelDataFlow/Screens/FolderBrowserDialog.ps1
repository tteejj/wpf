# FolderBrowserDialog.ps1 - Simple folder selection dialog

. "$PSScriptRoot\..\Components\SimpleFileTree.ps1"
. "$PSScriptRoot\..\Base\SimpleDialog.ps1"
. "$PSScriptRoot\..\Core\VT100.ps1"

class FolderBrowserDialog : SimpleDialog {
    [SimpleFileNode]$RootNode
    [SimpleFileNode]$SelectedNode
    [System.Collections.ArrayList]$VisibleNodes
    [int]$SelectedIndex = 0
    [int]$ScrollOffset = 0
    [string]$SelectedPath = ""
    [string]$StartPath
    
    FolderBrowserDialog([string]$startPath = "") {
        $this.VisibleNodes = [System.Collections.ArrayList]::new()
        $this.StartPath = if ($startPath) { $startPath } else { $PWD.Path }
        $this.InitializeTree()
    }
    
    [void] InitializeTree() {
        $this.RootNode = [SimpleFileNode]::new($this.StartPath)
        $this.RootNode.IsExpanded = $true
        $this.RootNode.LoadChildren()
        
        # Expand first few levels for easier navigation
        foreach ($child in $this.RootNode.Children) {
            if ($child.IsDirectory) {
                $child.LoadChildren()
            }
        }
        
        $this.BuildVisibleList()
        $this.SelectedNode = $this.RootNode
    }
    
    [void] BuildVisibleList() {
        $this.VisibleNodes.Clear()
        $this.AddNodeToVisible($this.RootNode)
    }
    
    [void] AddNodeToVisible([SimpleFileNode]$node) {
        if ($node.IsDirectory) {
            $this.VisibleNodes.Add($node) | Out-Null
            
            if ($node.IsExpanded) {
                foreach ($child in $node.Children) {
                    $this.AddNodeToVisible($child)
                }
            }
        }
    }
    
    [string] RenderContent() {
        $sb = [System.Text.StringBuilder]::new()
        
        # Header
        [void]$sb.AppendLine("Select Project Folder:")
        [void]$sb.AppendLine("Current: $($this.SelectedNode.FullPath)")
        [void]$sb.AppendLine("")
        
        # File tree
        $visibleHeight = $this.Height - 8  # Leave space for header and buttons
        $endIndex = [Math]::Min($this.ScrollOffset + $visibleHeight, $this.VisibleNodes.Count)
        
        for ($i = $this.ScrollOffset; $i -lt $endIndex; $i++) {
            $node = $this.VisibleNodes[$i]
            $isSelected = ($i -eq $this.SelectedIndex)
            
            # Indentation
            $indent = "  " * $node.Level
            
            # Selection indicator and icon
            $prefix = if ($isSelected) { "► " } else { "  " }
            $icon = $node.GetIcon()
            
            # Color based on selection
            if ($isSelected) {
                [void]$sb.Append("`e[7m")  # Reverse video
            }
            
            [void]$sb.AppendLine("$prefix$indent$icon $($node.Name)")
            
            if ($isSelected) {
                [void]$sb.Append("`e[0m")  # Reset
            }
        }
        
        # Fill remaining space
        $currentLines = $endIndex - $this.ScrollOffset + 3
        while ($currentLines -lt $visibleHeight + 3) {
            [void]$sb.AppendLine("")
            $currentLines++
        }
        
        # Instructions
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("↑↓: Navigate  →: Expand  ←: Collapse  Enter: Select  Escape: Cancel")
        
        return $sb.ToString()
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([System.ConsoleKey]::UpArrow) {
                if ($this.SelectedIndex -gt 0) {
                    $this.SelectedIndex--
                    $this.SelectedNode = $this.VisibleNodes[$this.SelectedIndex]
                    $this.EnsureVisible()
                }
                return $true
            }
            ([System.ConsoleKey]::DownArrow) {
                if ($this.SelectedIndex -lt ($this.VisibleNodes.Count - 1)) {
                    $this.SelectedIndex++
                    $this.SelectedNode = $this.VisibleNodes[$this.SelectedIndex]
                    $this.EnsureVisible()
                }
                return $true
            }
            ([System.ConsoleKey]::RightArrow) {
                if ($this.SelectedNode.IsDirectory -and -not $this.SelectedNode.IsExpanded) {
                    $this.SelectedNode.IsExpanded = $true
                    $this.SelectedNode.LoadChildren()
                    $this.BuildVisibleList()
                }
                return $true
            }
            ([System.ConsoleKey]::LeftArrow) {
                if ($this.SelectedNode.IsDirectory -and $this.SelectedNode.IsExpanded) {
                    $this.SelectedNode.IsExpanded = $false
                    $this.BuildVisibleList()
                    # Adjust selection if it was in collapsed area
                    if ($this.SelectedIndex -ge $this.VisibleNodes.Count) {
                        $this.SelectedIndex = $this.VisibleNodes.Count - 1
                        $this.SelectedNode = $this.VisibleNodes[$this.SelectedIndex]
                    }
                }
                return $true
            }
            ([System.ConsoleKey]::Enter) {
                $this.SelectedPath = $this.SelectedNode.FullPath
                return $false  # Close dialog
            }
            ([System.ConsoleKey]::Escape) {
                $this.SelectedPath = ""
                return $false  # Close dialog
            }
        }
        return $true
    }
    
    [void] EnsureVisible() {
        if ($this.SelectedIndex -lt $this.ScrollOffset) {
            $this.ScrollOffset = $this.SelectedIndex
        } elseif ($this.SelectedIndex -ge ($this.ScrollOffset + $this.Height - 8)) {
            $this.ScrollOffset = $this.SelectedIndex - ($this.Height - 8) + 1
        }
        
        # Ensure scroll offset is valid
        $this.ScrollOffset = [Math]::Max(0, [Math]::Min($this.ScrollOffset, $this.VisibleNodes.Count - 1))
    }
    
    [string] GetSelectedPath() {
        return $this.SelectedPath
    }
}

# Quick test function
function Show-FolderBrowser {
    param([string]$startPath = "")
    
    $dialog = [FolderBrowserDialog]::new($startPath)
    $dialog.SetBounds(5, 5, 70, 20)
    
    # Simple render loop
    $originalCursor = [Console]::CursorVisible
    [Console]::CursorVisible = $false
    
    try {
        while ($true) {
            [Console]::Clear()
            Write-Host $dialog.RenderContent() -NoNewline
            
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                if (-not $dialog.HandleInput($key)) {
                    break
                }
            }
            
            Start-Sleep -Milliseconds 50
        }
    } finally {
        [Console]::CursorVisible = $originalCursor
    }
    
    return $dialog.GetSelectedPath()
}