# PostConfigurationDialog.ps1 - Options after configuration is complete

. "$PSScriptRoot\..\Base\SimpleDialog.ps1"

class PostConfigurationDialog : SimpleDialog {
    [string]$SelectedOption = ""
    [int]$FieldCount = 0
    
    PostConfigurationDialog([int]$fieldCount) : base("Configuration Complete!") {
        $this.Width = 100
        $this.Height = 22
        $this.FieldCount = $fieldCount
        $this.Description = "✅ Configuration saved successfully! Configured $fieldCount field mappings"
        $this.Options = @(
            "Create Export Profile & Export Now",
            "Test Data Processing", 
            "Run Full Excel Processing",
            "Exit"
        )
        $this.Instructions = "Use Up/Down arrows to select, Enter to continue"
        
        # Set up event handlers
        $dialog = $this
        $this.OnSelect = {
            switch ($dialog.SelectedIndex) {
                0 { $dialog.SelectedOption = "profile_export" }
                1 { $dialog.SelectedOption = "test_processing" }
                2 { $dialog.SelectedOption = "full_processing" }
                3 { $dialog.SelectedOption = "exit" }
            }
        }.GetNewClosure()
        
        # Default to first option
        $this.SelectedOption = "profile_export"
    }
    
    [string] RenderContent() {
        $sb = [System.Text.StringBuilder]::new(1024)
        
        # Success message
        $contentX = $this.X + 4
        $contentY = $this.Y + 3
        
        $sb.Append([VT]::MoveTo($contentX, $contentY))
        $sb.Append([VT]::Green())
        $sb.Append("✅ Configuration saved successfully!")
        
        $sb.Append([VT]::MoveTo($contentX, $contentY + 1))
        $sb.Append([VT]::Cyan())
        $sb.Append("Configured $($this.FieldCount) field mappings")
        
        $sb.Append([VT]::MoveTo($contentX, $contentY + 3))
        $sb.Append([VT]::Reset())
        $sb.Append("What would you like to do next?")
        
        return $sb.ToString()
    }
    
    [string] RenderOptions() {
        $sb = [System.Text.StringBuilder]::new(1024)
        
        # Start options after content
        $startY = $this.Y + 8
        $contentX = $this.X + 4
        $maxWidth = $this.Width - 8
        
        for ($i = 0; $i -lt $this.Options.Count; $i++) {
            $optionY = $startY + ($i * 3)  # 3 lines per option for spacing
            
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
            
            # Option descriptions
            $sb.Append([VT]::MoveTo($contentX + 4, $optionY + 1))
            $sb.Append([VT]::Gray())
            
            switch ($i) {
                0 { $sb.Append("Choose fields to export and save as a reusable profile") }
                1 { $sb.Append("Preview data extraction from your Excel file") }
                2 { $sb.Append("Extract data and write to destination Excel file") }
                3 { $sb.Append("Exit the application") }
            }
        }
        
        return $sb.ToString()
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        # Handle number key shortcuts
        switch ($key.Key) {
            ([System.ConsoleKey]::D1) {
                $this.SelectedIndex = 0
                $this.SelectedOption = "profile_export"
                return $true
            }
            ([System.ConsoleKey]::D2) {
                $this.SelectedIndex = 1
                $this.SelectedOption = "test_processing"
                return $true
            }
            ([System.ConsoleKey]::D3) {
                $this.SelectedIndex = 2
                $this.SelectedOption = "full_processing"
                return $true
            }
            ([System.ConsoleKey]::D4) {
                $this.SelectedIndex = 3
                $this.SelectedOption = "exit"
                return $true
            }
        }
        
        # Handle arrow keys and update selection
        if ($key.Key -eq [System.ConsoleKey]::UpArrow -or $key.Key -eq [System.ConsoleKey]::DownArrow) {
            $result = ([SimpleDialog]$this).HandleInput($key)
            # Update SelectedOption based on SelectedIndex
            switch ($this.SelectedIndex) {
                0 { $this.SelectedOption = "profile_export" }
                1 { $this.SelectedOption = "test_processing" }
                2 { $this.SelectedOption = "full_processing" }
                3 { $this.SelectedOption = "exit" }
            }
            return $result
        }
        
        # Handle other keys
        return ([SimpleDialog]$this).HandleInput($key)
    }
}