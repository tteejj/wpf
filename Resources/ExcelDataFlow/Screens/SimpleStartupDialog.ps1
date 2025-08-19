# SimpleStartupDialog.ps1 - Simplified startup dialog using TaskPro patterns

. "$PSScriptRoot\..\Base\SimpleDialog.ps1"

class SimpleStartupDialog : SimpleDialog {
    [string]$SelectedOption = ""
    
    SimpleStartupDialog() : base("ExcelDataFlow - Welcome") {
        $this.Width = 100
        $this.Height = 20
        $this.Description = "Welcome to ExcelDataFlow! Choose how you want to proceed:"
        $this.Options = @(
            "Quick Export using Saved Profile",
            "Configure Excel Mappings"
        )
        
        # Set up event handlers
        $dialog = $this
        $this.OnSelect = {
            switch ($dialog.SelectedIndex) {
                0 { $dialog.SelectedOption = "profile" }
                1 { $dialog.SelectedOption = "configure" }
            }
        }.GetNewClosure()
    }
    
    [string] RenderContent() {
        $sb = [System.Text.StringBuilder]::new(512)
        
        # Call base content rendering
        $sb.Append(([SimpleDialog]$this).RenderContent())
        
        # Add option descriptions below the main description
        $descY = $this.Y + 4
        $contentX = $this.X + 4
        $maxWidth = $this.Width - 8
        
        # Add spacing
        $sb.Append([VT]::MoveTo($contentX, $descY))
        
        return $sb.ToString()
    }
    
    [string] RenderOptions() {
        $sb = [System.Text.StringBuilder]::new(1024)
        
        # Draw options box
        $boxY = $this.Y + 6
        $boxX = $this.X + 4
        $boxWidth = $this.Width - 8
        $boxHeight = 6
        
        # Top border
        $sb.Append([VT]::MoveTo($boxX, $boxY))
        $sb.Append("┌")
        $sb.Append("─" * ($boxWidth - 2))
        $sb.Append("┐")
        
        # Options inside box
        for ($i = 0; $i -lt $this.Options.Count; $i++) {
            $optionY = $boxY + 1 + $i
            $sb.Append([VT]::MoveTo($boxX, $optionY))
            $sb.Append("│")
            
            # Selection indicator
            if ($i -eq $this.SelectedIndex) {
                $sb.Append([VT]::RGBBG(0, 100, 200))
                $sb.Append([VT]::White())
            } else {
                $sb.Append([VT]::Reset())
            }
            
            $optionText = "$($i + 1). $($this.Options[$i])"
            $sb.Append($optionText)
            
            # Pad to box width
            $padding = $boxWidth - 2 - $optionText.Length
            if ($padding -gt 0) {
                $sb.Append(" " * $padding)
            }
            
            $sb.Append([VT]::Reset())
            $sb.Append("│")
        }
        
        # Empty lines in box
        for ($i = $this.Options.Count; $i -lt 4; $i++) {
            $optionY = $boxY + 1 + $i
            $sb.Append([VT]::MoveTo($boxX, $optionY))
            $sb.Append("│")
            $sb.Append(" " * ($boxWidth - 2))
            $sb.Append("│")
        }
        
        # Bottom border
        $sb.Append([VT]::MoveTo($boxX, $boxY + 5))
        $sb.Append("└")
        $sb.Append("─" * ($boxWidth - 2))
        $sb.Append("┘")
        
        # Add description below box
        $descY = $boxY + 7
        $description = ""
        if ($this.SelectedIndex -eq 0) {
            $description = "Select a saved export profile and choose output location. Fast workflow for repeat exports."
        } elseif ($this.SelectedIndex -eq 1) {
            $description = "Set up field mappings between Excel files. Required for first-time setup or changes."
        }
        
        if ($description) {
            $sb.Append([VT]::MoveTo($this.X + 4, $descY))
            $sb.Append([VT]::Gray())
            
            # Word wrap description
            $words = $description -split ' '
            $line = ""
            $currentY = $descY
            $maxWidth = $this.Width - 8
            
            foreach ($word in $words) {
                if (($line + " " + $word).Length -le $maxWidth) {
                    if ($line) { $line += " " }
                    $line += $word
                } else {
                    if ($line) {
                        $sb.Append([VT]::MoveTo($this.X + 4, $currentY))
                        $sb.Append($line)
                        $currentY++
                    }
                    $line = $word
                }
            }
            
            # Output the last line
            if ($line) {
                $sb.Append([VT]::MoveTo($this.X + 4, $currentY))
                $sb.Append($line)
            }
        }
        
        return $sb.ToString()
    }
}

# Test function
function Test-SimpleStartupDialog {
    . "$PSScriptRoot\..\Core\VT100.ps1"
    
    $dialog = [SimpleStartupDialog]::new()
    $dialog.Show()
    
    Write-Host "`nSelected: $($dialog.SelectedOption)" -ForegroundColor Green
    Write-Host "Dialog Result: $($dialog.DialogResult)" -ForegroundColor Cyan
}