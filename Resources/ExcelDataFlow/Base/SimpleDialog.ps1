# SimpleDialog.ps1 - Simplified dialog based on TaskPro patterns
# Replaces the overly complex UnifiedDialog

class SimpleDialog {
    [string]$Title = "Dialog"
    [int]$Width = 80
    [int]$Height = 20
    [int]$X = 0
    [int]$Y = 0
    [bool]$DialogResult = $false
    [string[]]$Options = @()
    [int]$SelectedIndex = 0
    [string]$Description = ""
    [string]$Instructions = "Use Up/Down arrows to select, Enter to continue"
    
    # Events
    [scriptblock]$OnSelect = {}
    [scriptblock]$OnCancel = {}
    
    SimpleDialog([string]$title) {
        $this.Title = $title
        $this.CalculatePosition()
    }
    
    SimpleDialog([string]$title, [string[]]$options) {
        $this.Title = $title
        $this.Options = $options
        $this.CalculatePosition()
    }
    
    [void] CalculatePosition() {
        $consoleW = [Console]::WindowWidth
        $consoleH = [Console]::WindowHeight
        
        # Center dialog
        $this.X = [Math]::Max(1, [int](($consoleW - $this.Width) / 2))
        $this.Y = [Math]::Max(1, [int](($consoleH - $this.Height) / 2))
    }
    
    [string] Render() {
        $sb = [System.Text.StringBuilder]::new(4096)
        
        # Clear screen
        $sb.Append([VT]::Clear())
        $sb.Append([VT]::MoveTo(1, 1))
        
        # Draw dialog box
        $sb.Append($this.RenderBox())
        
        # Draw title
        $sb.Append($this.RenderTitle())
        
        # Draw content
        $sb.Append($this.RenderContent())
        
        # Draw options
        $sb.Append($this.RenderOptions())
        
        # Draw instructions
        $sb.Append($this.RenderInstructions())
        
        return $sb.ToString()
    }
    
    [string] RenderBox() {
        $sb = [System.Text.StringBuilder]::new(1024)
        
        # Top border
        $sb.Append([VT]::MoveTo($this.X, $this.Y))
        $sb.Append("╭")
        $sb.Append("─" * ($this.Width - 2))
        $sb.Append("╮")
        
        # Side borders
        for ($i = 1; $i -lt $this.Height - 1; $i++) {
            $sb.Append([VT]::MoveTo($this.X, $this.Y + $i))
            $sb.Append("│")
            $sb.Append(" " * ($this.Width - 2))
            $sb.Append("│")
        }
        
        # Bottom border
        $sb.Append([VT]::MoveTo($this.X, $this.Y + $this.Height - 1))
        $sb.Append("╰")
        $sb.Append("─" * ($this.Width - 2))
        $sb.Append("╯")
        
        return $sb.ToString()
    }
    
    [string] RenderTitle() {
        $titleText = " $($this.Title) "
        $titleX = $this.X + [int](($this.Width - $titleText.Length) / 2)
        
        $sb = [System.Text.StringBuilder]::new(128)
        $sb.Append([VT]::MoveTo($titleX, $this.Y))
        $sb.Append([VT]::Blue())
        $sb.Append($titleText)
        $sb.Append([VT]::Reset())
        
        return $sb.ToString()
    }
    
    [string] RenderContent() {
        if ([string]::IsNullOrEmpty($this.Description)) {
            return ""
        }
        
        $sb = [System.Text.StringBuilder]::new(512)
        $contentX = $this.X + 2
        $contentY = $this.Y + 2
        $maxWidth = $this.Width - 4
        
        # Word wrap the description
        $words = $this.Description -split ' '
        $line = ""
        $currentY = $contentY
        
        foreach ($word in $words) {
            if (($line + " " + $word).Length -le $maxWidth) {
                if ($line) { $line += " " }
                $line += $word
            } else {
                if ($line) {
                    $sb.Append([VT]::MoveTo($contentX, $currentY))
                    $sb.Append([VT]::White())
                    $sb.Append($line)
                    $currentY++
                }
                $line = $word
            }
        }
        
        # Output the last line
        if ($line) {
            $sb.Append([VT]::MoveTo($contentX, $currentY))
            $sb.Append([VT]::White())
            $sb.Append($line)
        }
        
        return $sb.ToString()
    }
    
    [string] RenderOptions() {
        if ($this.Options.Count -eq 0) {
            return ""
        }
        
        $sb = [System.Text.StringBuilder]::new(512)
        $startY = $this.Y + 6  # Start options after title and description
        $contentX = $this.X + 4
        $maxWidth = $this.Width - 8
        
        for ($i = 0; $i -lt $this.Options.Count; $i++) {
            $optionY = $startY + ($i * 2)  # 2 lines per option for spacing
            
            # Selection indicator and number
            $sb.Append([VT]::MoveTo($contentX, $optionY))
            if ($i -eq $this.SelectedIndex) {
                $sb.Append([VT]::RGBBG(0, 100, 200))
                $sb.Append([VT]::White())
                $sb.Append("→ ")
            } else {
                $sb.Append([VT]::Reset())
                $sb.Append("  ")
            }
            
            # Option text
            $sb.Append("$($i + 1). $($this.Options[$i])")
            if ($i -eq $this.SelectedIndex) {
                $sb.Append([VT]::Reset())
            }
        }
        
        return $sb.ToString()
    }
    
    [string] RenderInstructions() {
        $instructY = $this.Y + $this.Height - 3
        $contentX = $this.X + 2
        
        $sb = [System.Text.StringBuilder]::new(128)
        $sb.Append([VT]::MoveTo($contentX, $instructY))
        $sb.Append([VT]::Yellow())
        $sb.Append($this.Instructions)
        $sb.Append([VT]::Reset())
        
        return $sb.ToString()
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([System.ConsoleKey]::UpArrow) {
                if ($this.Options.Count -gt 0) {
                    $this.SelectedIndex = if ($this.SelectedIndex -eq 0) { $this.Options.Count - 1 } else { $this.SelectedIndex - 1 }
                }
                return $true
            }
            ([System.ConsoleKey]::DownArrow) {
                if ($this.Options.Count -gt 0) {
                    $this.SelectedIndex = ($this.SelectedIndex + 1) % $this.Options.Count
                }
                return $true
            }
            ([System.ConsoleKey]::Enter) {
                [Logger]::Info("=== SimpleDialog.HandleInput - Enter key pressed ===")
                $this.DialogResult = $true
                [Logger]::Info("SimpleDialog DialogResult set to true")
                if ($this.OnSelect) { 
                    [Logger]::Info("Calling OnSelect handler...")
                    & $this.OnSelect 
                } else {
                    [Logger]::Error("No OnSelect handler defined")
                }
                [Logger]::Info("Returning false to exit dialog")
                return $false  # Exit dialog
            }
            ([System.ConsoleKey]::Escape) {
                $this.DialogResult = $false
                if ($this.OnCancel) { & $this.OnCancel }
                return $false  # Exit dialog
            }
            ([System.ConsoleKey]::D1) {
                if ($this.Options.Count -gt 0) { $this.SelectedIndex = 0 }
                return $true
            }
            ([System.ConsoleKey]::D2) {
                if ($this.Options.Count -gt 1) { $this.SelectedIndex = 1 }
                return $true
            }
            ([System.ConsoleKey]::D3) {
                if ($this.Options.Count -gt 2) { $this.SelectedIndex = 2 }
                return $true
            }
            ([System.ConsoleKey]::D4) {
                if ($this.Options.Count -gt 3) { $this.SelectedIndex = 3 }
                return $true
            }
        }
        return $true
    }
    
    [string] GetSelectedOption() {
        if ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this.Options.Count) {
            return $this.Options[$this.SelectedIndex]
        }
        return ""
    }
    
    [int] GetSelectedIndex() {
        return $this.SelectedIndex
    }
    
    [void] Show() {
        # Hide cursor
        Write-Host -NoNewline ([VT]::Hide())
        
        try {
            while ($true) {
                # Render
                Write-Host -NoNewline $this.Render()
                
                # Wait for input with proper console detection
                try {
                    if ([Console]::KeyAvailable) {
                        $key = [Console]::ReadKey($true)
                        if (-not $this.HandleInput($key)) {
                            break  # Exit dialog
                        }
                    }
                } catch {
                    # If console input is not available (redirected), use Read-Host fallback
                    [Logger]::Debug("Console input not available, using fallback")
                    Write-Host "Enter option number (1-$($this.Options.Count)) or press Enter for option $($this.SelectedIndex + 1): " -NoNewline
                    $input = Read-Host
                    
                    # Check if user entered a number to select an option
                    if ($input -match '^\d+$') {
                        $optionNumber = [int]$input
                        if ($optionNumber -ge 1 -and $optionNumber -le $this.Options.Count) {
                            # Set the selected index (convert from 1-based to 0-based)
                            $this.SelectedIndex = $optionNumber - 1
                            [Logger]::Debug("User selected option $optionNumber (index $($this.SelectedIndex))")
                        } else {
                            [Logger]::Debug("Invalid option number: $optionNumber")
                            continue  # Ask again
                        }
                    }
                    
                    # Simulate Enter key press to confirm selection
                    $enterKey = [System.ConsoleKeyInfo]::new([char]13, [System.ConsoleKey]::Enter, $false, $false, $false)
                    if (-not $this.HandleInput($enterKey)) {
                        break  # Exit dialog
                    }
                }
                
                Start-Sleep -Milliseconds 50
            }
        } finally {
            # Show cursor
            Write-Host -NoNewline ([VT]::Show())
        }
    }
}