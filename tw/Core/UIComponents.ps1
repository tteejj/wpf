# UI Components Implementation
# Input handling, keyboard shortcuts, and interactive interface elements

# Keyboard input handler for processing key events and sequences
class KeyboardInputHandler {
    hidden [object] $_eventPublisher  # EventPublisher
    hidden [string] $_currentMode = "Normal"  # Normal, Command, Search, Edit
    hidden [string] $_currentInput = ""
    hidden [string] $_pendingSequence = ""
    hidden [DateTime] $_sequenceStartTime
    hidden [int] $_sequenceTimeoutMs
    hidden [hashtable] $_keySequences = @{}
    
    KeyboardInputHandler([object]$eventPublisher) {
        $this._eventPublisher = $eventPublisher
        $this._sequenceTimeoutMs = 1000  # 1 second timeout
        $this.InitializeKeySequences()
    }
    
    KeyboardInputHandler([object]$eventPublisher, [int]$sequenceTimeoutMs) {
        $this._eventPublisher = $eventPublisher
        $this._sequenceTimeoutMs = $sequenceTimeoutMs
        $this.InitializeKeySequences()
    }
    
    [void] InitializeKeySequences() {
        # Common vim-like sequences
        $this._keySequences = @{
            'gg' = 'GoToTop'
            'dd' = 'DeleteLine'
            'yy' = 'YankLine'
            'cc' = 'ChangeLine'
        }
    }
    
    [void] ProcessKey([string]$key, [bool]$ctrl, [bool]$alt, [bool]$shift) {
        $keyEvent = @{
            Key = $key
            Ctrl = $ctrl
            Alt = $alt
            Shift = $shift
            Mode = $this._currentMode
            Timestamp = Get-Date
        }
        
        # Handle mode switching keys
        if ($this._currentMode -eq "Normal") {
            switch ($key) {
                ':' {
                    $this.SetMode('Command')
                    return
                }
                '/' {
                    $this.SetMode('Search')
                    return
                }
                'Escape' {
                    $this.ClearPendingSequence()
                    return
                }
            }
        } elseif ($key -eq 'Escape') {
            $this.SetMode('Normal')
            $this._currentInput = ""
            return
        }
        
        # Handle key sequences in normal mode
        if ($this._currentMode -eq "Normal" -and $key.Length -eq 1) {
            $this.HandleKeySequence($key)
        }
        
        # Handle text input in input modes
        if ($this._currentMode -in @('Command', 'Search', 'Edit')) {
            $this.HandleTextInput($key)
        }
        
        # Publish key event
        if ($this._eventPublisher) {
            $this._eventPublisher.Publish('KeyPressed', $keyEvent)
        }
    }
    
    [void] HandleKeySequence([string]$key) {
        if ($this._pendingSequence -eq "") {
            $this._pendingSequence = $key
            $this._sequenceStartTime = Get-Date
        } else {
            $fullSequence = $this._pendingSequence + $key
            
            if ($this._keySequences.ContainsKey($fullSequence)) {
                # Complete sequence found
                if ($this._eventPublisher) {
                    $this._eventPublisher.Publish('KeySequence', @{
                        Sequence = $fullSequence
                        Action = $this._keySequences[$fullSequence]
                        Timestamp = Get-Date
                    })
                }
                $this._pendingSequence = ""
            } else {
                # No matching sequence, clear and start new
                $this._pendingSequence = $key
                $this._sequenceStartTime = Get-Date
            }
        }
    }
    
    [void] HandleTextInput([string]$key) {
        if ($key -eq 'Backspace') {
            if ($this._currentInput.Length -gt 0) {
                $this._currentInput = $this._currentInput.Substring(0, $this._currentInput.Length - 1)
            }
        } elseif ($key -eq 'Enter') {
            if ($this._eventPublisher) {
                $eventType = switch ($this._currentMode) {
                    'Command' { 'CommandEntered' }
                    'Search' { 'SearchEntered' }
                    'Edit' { 'EditCompleted' }
                    default { 'InputEntered' }
                }
                
                $this._eventPublisher.Publish($eventType, @{
                    Input = $this._currentInput
                    Mode = $this._currentMode
                })
            }
        } elseif ($key.Length -eq 1) {
            $this._currentInput += $key
        }
    }
    
    [void] CheckSequenceTimeout() {
        if ($this._pendingSequence -ne "" -and 
            ((Get-Date) - $this._sequenceStartTime).TotalMilliseconds -gt $this._sequenceTimeoutMs) {
            
            if ($this._eventPublisher) {
                $this._eventPublisher.Publish('SequenceTimeout', @{
                    PendingSequence = $this._pendingSequence
                })
            }
            $this._pendingSequence = ""
        }
    }
    
    [void] ClearPendingSequence() {
        $this._pendingSequence = ""
    }
    
    [void] SetMode([string]$mode) {
        $oldMode = $this._currentMode
        $this._currentMode = $mode
        
        if ($mode -ne 'Edit' -and $mode -ne 'Command' -and $mode -ne 'Search') {
            $this._currentInput = ""
        }
        
        if ($this._eventPublisher) {
            $this._eventPublisher.Publish('ModeChanged', @{
                OldMode = $oldMode
                NewMode = $mode
                Timestamp = Get-Date
            })
        }
    }
    
    [string] GetCurrentMode() {
        return $this._currentMode
    }
    
    [string] GetCurrentInput() {
        return $this._currentInput
    }
    
    [void] SetCurrentInput([string]$input) {
        $this._currentInput = $input
    }
}

# Command line interface for command input and execution
class CommandLineInterface {
    hidden [object] $_eventPublisher  # EventPublisher
    hidden [object] $_renderEngine    # RenderEngine
    hidden [string] $_prompt = ":"
    hidden [string] $_currentInput = ""
    hidden [array] $_history = @()
    hidden [int] $_historyIndex = -1
    hidden [array] $_completionCandidates = @()
    hidden [int] $_cursorPosition = 0
    
    CommandLineInterface([object]$eventPublisher, [object]$renderEngine) {
        $this._eventPublisher = $eventPublisher
        $this._renderEngine = $renderEngine
    }
    
    [void] SetPrompt([string]$prompt) {
        $this._prompt = $prompt
    }
    
    [void] SetInput([string]$input) {
        $this._currentInput = $input
        $this._cursorPosition = $input.Length
    }
    
    [string] GetCurrentInput() {
        return $this._currentInput
    }
    
    [void] AddToHistory([string]$command) {
        if ($command -and $command.Trim() -ne "") {
            $this._history += $command
            # Limit history size
            if ($this._history.Count -gt 100) {
                $this._history = $this._history[-100..-1]
            }
        }
        $this._historyIndex = -1
    }
    
    [void] HistoryUp() {
        if ($this._history.Count -eq 0) { return }
        
        if ($this._historyIndex -eq -1) {
            $this._historyIndex = $this._history.Count - 1
        } elseif ($this._historyIndex -gt 0) {
            $this._historyIndex--
        }
        
        $this.SetInput($this._history[$this._historyIndex])
    }
    
    [void] HistoryDown() {
        if ($this._historyIndex -eq -1 -or $this._history.Count -eq 0) { return }
        
        if ($this._historyIndex -lt ($this._history.Count - 1)) {
            $this._historyIndex++
            $this.SetInput($this._history[$this._historyIndex])
        } else {
            $this._historyIndex = -1
            $this.SetInput("")
        }
    }
    
    [void] SetCompletionCandidates([array]$candidates) {
        $this._completionCandidates = $candidates
    }
    
    [string] GetCompletion() {
        if ($this._currentInput -eq "" -or $this._completionCandidates.Count -eq 0) {
            return ""
        }
        
        # Use foreach loop instead of Where-Object to avoid PowerShell class method scoping issues
        foreach ($candidate in $this._completionCandidates) {
            if ($candidate.StartsWith($this._currentInput, [StringComparison]::OrdinalIgnoreCase)) {
                return $candidate
            }
        }
        
        return ""
    }
    
    [void] ExecuteCommand() {
        if ($this._currentInput.Trim() -ne "") {
            $this.AddToHistory($this._currentInput)
            
            if ($this._eventPublisher) {
                $this._eventPublisher.Publish('CommandExecuted', @{
                    Command = $this._currentInput.Trim()
                    Timestamp = Get-Date
                })
            }
            
            $this._currentInput = ""
            $this._cursorPosition = 0
        }
    }
    
    [void] RenderToBuffer([object]$buffer, [int]$row) {
        $displayText = $this._prompt + $this._currentInput
        $buffer.SetLine($row, $displayText.PadRight($buffer.GetWidth()))
        
        # TODO: Handle cursor position visualization
    }
}

# Search interface for incremental search functionality
class SearchInterface {
    hidden [object] $_eventPublisher  # EventPublisher
    hidden [object] $_renderEngine    # RenderEngine
    hidden [string] $_query = ""
    hidden [array] $_matches = @()
    hidden [int] $_currentMatchIndex = -1
    hidden [bool] $_caseSensitive = $false
    
    SearchInterface([object]$eventPublisher, [object]$renderEngine) {
        $this._eventPublisher = $eventPublisher
        $this._renderEngine = $renderEngine
    }
    
    [void] SetQuery([string]$query) {
        $this._query = $query
        
        if ($this._eventPublisher) {
            $this._eventPublisher.Publish('SearchQueryChanged', @{
                Query = $query
                CaseSensitive = $this._caseSensitive
                Timestamp = Get-Date
            })
        }
    }
    
    [string] GetQuery() {
        return $this._query
    }
    
    [void] SetMatches([array]$matches) {
        $this._matches = $matches
        if ($matches.Count -gt 0) {
            $this._currentMatchIndex = -1  # Will be incremented to 0 on first NextMatch()
        } else {
            $this._currentMatchIndex = -1
        }
    }
    
    [array] GetCurrentMatches() {
        return $this._matches
    }
    
    [int] GetCurrentMatchIndex() {
        return $this._currentMatchIndex
    }
    
    [void] NextMatch() {
        if ($this._matches.Count -eq 0) { return }
        
        $this._currentMatchIndex = ($this._currentMatchIndex + 1) % $this._matches.Count
        
        if ($this._eventPublisher) {
            $this._eventPublisher.Publish('SearchMatchChanged', @{
                MatchIndex = $this._currentMatchIndex
                Match = $this._matches[$this._currentMatchIndex]
            })
        }
    }
    
    [void] PrevMatch() {
        if ($this._matches.Count -eq 0) { return }
        
        $this._currentMatchIndex--
        if ($this._currentMatchIndex -lt 0) {
            $this._currentMatchIndex = $this._matches.Count - 1
        }
        
        if ($this._eventPublisher) {
            $this._eventPublisher.Publish('SearchMatchChanged', @{
                MatchIndex = $this._currentMatchIndex
                Match = $this._matches[$this._currentMatchIndex]
            })
        }
    }
    
    [void] ClearSearch() {
        $this._query = ""
        $this._matches = @()
        $this._currentMatchIndex = -1
    }
}

# Status bar for displaying application state
class StatusBar {
    hidden [object] $_eventPublisher  # EventPublisher
    hidden [object] $_renderEngine    # RenderEngine
    hidden [string] $_currentMode = "Normal"
    hidden [hashtable] $_taskStats = @{}
    hidden [string] $_activeFilter = ""
    hidden [string] $_progressMessage = ""
    hidden [double] $_progressPercent = 0.0
    hidden [hashtable] $_colorScheme = @{
        'Normal' = "$([char]27)[37m"      # White
        'Command' = "$([char]27)[33m"     # Yellow
        'Search' = "$([char]27)[36m"      # Cyan
        'Edit' = "$([char]27)[32m"        # Green
        'Reset' = "$([char]27)[0m"        # Reset
    }
    
    StatusBar([object]$eventPublisher, [object]$renderEngine) {
        $this._eventPublisher = $eventPublisher
        $this._renderEngine = $renderEngine
        
        # Subscribe to relevant events
        if ($this._eventPublisher) {
            $statusBarRef = $this
            
            $this._eventPublisher.Subscribe('ModeChanged', {
                param($eventData)
                $statusBarRef.SetMode($eventData.NewMode)
            }.GetNewClosure())
            
            $this._eventPublisher.Subscribe('FiltersChanged', {
                param($eventData)
                $filterText = $eventData.Filters -join " "
                $statusBarRef.SetActiveFilter($filterText)
            }.GetNewClosure())
        }
    }
    
    [void] SetMode([string]$mode) {
        $this._currentMode = $mode
        $this.PublishUpdate()
    }
    
    [void] SetTaskStatistics([hashtable]$stats) {
        $this._taskStats = $stats
        $this.PublishUpdate()
    }
    
    [void] SetActiveFilter([string]$filter) {
        $this._activeFilter = $filter
        $this.PublishUpdate()
    }
    
    [void] SetProgress([string]$message, [double]$percent) {
        $this._progressMessage = $message
        $this._progressPercent = $percent
        $this.PublishUpdate()
    }
    
    [void] ClearProgress() {
        $this._progressMessage = ""
        $this._progressPercent = 0.0
        $this.PublishUpdate()
    }
    
    [void] RenderToBuffer([object]$buffer, [int]$row) {
        $width = $buffer.GetWidth()
        $statusLine = ""
        
        # Left side: Mode and task stats
        $modeColor = $this._colorScheme[$this._currentMode]
        if (-not $modeColor) { $modeColor = $this._colorScheme['Normal'] }
        
        $leftSide = "$modeColor$($this._currentMode)$($this._colorScheme['Reset'])"
        
        if ($this._taskStats.Count -gt 0) {
            $statsText = " | "
            if ($this._taskStats.Total) {
                $statsText += "Total: $($this._taskStats.Total)"
            }
            if ($this._taskStats.Pending) {
                $statsText += " Pending: $($this._taskStats.Pending)"
            }
            if ($this._taskStats.Completed) {
                $statsText += " Completed: $($this._taskStats.Completed)"
            }
            $leftSide += $statsText
        }
        
        # Right side: Filter and progress
        $rightSide = ""
        if ($this._progressMessage) {
            $progressBar = $this.BuildProgressBar($this._progressPercent, 20)
            $rightSide = "$($this._progressMessage) $progressBar $('{0:F0}' -f ($this._progressPercent * 100))%"
        } elseif ($this._activeFilter) {
            $rightSide = "Filter: $($this._activeFilter)"
        }
        
        # Combine and pad
        $availableSpace = $width - $leftSide.Length - $rightSide.Length
        if ($availableSpace -lt 0) {
            # Truncate right side if needed
            $maxRightLength = $width - $leftSide.Length - 3  # Leave space for "..."
            if ($maxRightLength -gt 0) {
                $rightSide = $rightSide.Substring(0, [Math]::Min($rightSide.Length, $maxRightLength)) + "..."
            } else {
                $rightSide = ""
            }
            $availableSpace = $width - $leftSide.Length - $rightSide.Length
        }
        
        $statusLine = $leftSide + (" " * [Math]::Max(0, $availableSpace)) + $rightSide
        $buffer.SetLine($row, $statusLine.PadRight($width))
    }
    
    hidden [string] BuildProgressBar([double]$percent, [int]$width) {
        $filled = [Math]::Round($percent * $width)
        $bar = "[" + ("=" * $filled) + (" " * ($width - $filled)) + "]"
        return $bar
    }
    
    hidden [void] PublishUpdate() {
        if ($this._eventPublisher) {
            $this._eventPublisher.Publish('StatusBarUpdated', @{
                Mode = $this._currentMode
                TaskStats = $this._taskStats
                ActiveFilter = $this._activeFilter
                Progress = @{
                    Message = $this._progressMessage
                    Percent = $this._progressPercent
                }
                Timestamp = Get-Date
            })
        }
    }
}

# Confirmation dialog for user choices
class ConfirmationDialog {
    hidden [object] $_eventPublisher  # EventPublisher
    hidden [object] $_renderEngine    # RenderEngine
    hidden [string] $_message = ""
    hidden [array] $_options = @("OK", "Cancel")
    hidden [int] $_selectedOption = 0
    hidden [bool] $_isVisible = $false
    
    ConfirmationDialog([object]$eventPublisher, [object]$renderEngine) {
        $this._eventPublisher = $eventPublisher
        $this._renderEngine = $renderEngine
    }
    
    [void] SetMessage([string]$message) {
        $this._message = $message
    }
    
    [void] SetOptions([array]$options) {
        $this._options = $options
        $this._selectedOption = 0
    }
    
    [int] GetSelectedOption() {
        return $this._selectedOption
    }
    
    [void] SetSelectedOption([int]$index) {
        if ($index -ge 0 -and $index -lt $this._options.Count) {
            $this._selectedOption = $index
        }
    }
    
    [void] NextOption() {
        $this._selectedOption = ($this._selectedOption + 1) % $this._options.Count
    }
    
    [void] PreviousOption() {
        $this._selectedOption--
        if ($this._selectedOption -lt 0) {
            $this._selectedOption = $this._options.Count - 1
        }
    }
    
    [void] Show() {
        $this._isVisible = $true
    }
    
    [void] Hide() {
        $this._isVisible = $false
    }
    
    [void] Confirm() {
        if ($this._eventPublisher) {
            $this._eventPublisher.Publish('DialogResult', @{
                Result = $this._options[$this._selectedOption]
                SelectedIndex = $this._selectedOption
                Timestamp = Get-Date
            })
        }
        $this.Hide()
    }
    
    [void] Cancel() {
        if ($this._eventPublisher) {
            $this._eventPublisher.Publish('DialogCancelled', @{
                Timestamp = Get-Date
            })
        }
        $this.Hide()
    }
    
    [void] RenderToBuffer([object]$buffer) {
        if (-not $this._isVisible) { return }
        
        $width = $buffer.GetWidth()
        $height = $buffer.GetHeight()
        
        # Calculate dialog dimensions
        $dialogWidth = [Math]::Min($width - 4, 60)
        $dialogHeight = 8
        $startX = ($width - $dialogWidth) / 2
        $startY = ($height - $dialogHeight) / 2
        
        # Draw dialog box
        $borderChar = "+"
        $horizontalChar = "-"
        $verticalChar = "|"
        
        # Top border
        $topBorder = $borderChar + ($horizontalChar * ($dialogWidth - 2)) + $borderChar
        $buffer.SetLine($startY, (" " * $startX) + $topBorder + (" " * ($width - $startX - $topBorder.Length)))
        
        # Message area
        $messageLines = $this.WrapText($this._message, $dialogWidth - 4)
        $messageStartY = $startY + 2
        
        for ($i = 0; $i -lt $messageLines.Count -and $i -lt 3; $i++) {
            $messageLine = $verticalChar + " " + $messageLines[$i].PadRight($dialogWidth - 4) + " " + $verticalChar
            $buffer.SetLine($messageStartY + $i, (" " * $startX) + $messageLine + (" " * ($width - $startX - $messageLine.Length)))
        }
        
        # Options area
        $optionsY = $startY + $dialogHeight - 3
        $optionsText = ""
        for ($i = 0; $i -lt $this._options.Count; $i++) {
            if ($i -eq $this._selectedOption) {
                $optionsText += "[$($this._options[$i])]"
            } else {
                $optionsText += " $($this._options[$i]) "
            }
            
            if ($i -lt $this._options.Count - 1) {
                $optionsText += "  "
            }
        }
        
        $centeredOptions = $optionsText.PadLeft(($dialogWidth - 2 - $optionsText.Length) / 2 + $optionsText.Length)
        $optionsLine = $verticalChar + " " + $centeredOptions.PadRight($dialogWidth - 4) + " " + $verticalChar
        $buffer.SetLine($optionsY, (" " * $startX) + $optionsLine + (" " * ($width - $startX - $optionsLine.Length)))
        
        # Bottom border
        $bottomBorder = $borderChar + ($horizontalChar * ($dialogWidth - 2)) + $borderChar
        $buffer.SetLine($startY + $dialogHeight - 1, (" " * $startX) + $bottomBorder + (" " * ($width - $startX - $bottomBorder.Length)))
    }
    
    hidden [array] WrapText([string]$text, [int]$width) {
        $lines = @()
        $words = $text -split '\s+'
        $currentLine = ""
        
        foreach ($word in $words) {
            if (($currentLine + " " + $word).Length -le $width) {
                if ($currentLine) {
                    $currentLine += " " + $word
                } else {
                    $currentLine = $word
                }
            } else {
                if ($currentLine) {
                    $lines += $currentLine
                }
                $currentLine = $word
            }
        }
        
        if ($currentLine) {
            $lines += $currentLine
        }
        
        return $lines
    }
}

# Input dialog for text entry
class InputDialog {
    hidden [object] $_eventPublisher  # EventPublisher
    hidden [object] $_renderEngine    # RenderEngine
    hidden [string] $_prompt = ""
    hidden [string] $_currentInput = ""
    hidden [scriptblock] $_validator = $null
    hidden [bool] $_isVisible = $false
    
    InputDialog([object]$eventPublisher, [object]$renderEngine) {
        $this._eventPublisher = $eventPublisher
        $this._renderEngine = $renderEngine
    }
    
    [void] SetPrompt([string]$prompt) {
        $this._prompt = $prompt
    }
    
    [void] SetInput([string]$input) {
        $this._currentInput = $input
    }
    
    [string] GetCurrentInput() {
        return $this._currentInput
    }
    
    [void] SetValidator([scriptblock]$validator) {
        $this._validator = $validator
    }
    
    [bool] IsValid() {
        if ($null -eq $this._validator) {
            return $true
        }
        
        try {
            return $this._validator.Invoke($this._currentInput)
        } catch {
            return $false
        }
    }
    
    [void] Show() {
        $this._isVisible = $true
    }
    
    [void] Hide() {
        $this._isVisible = $false
    }
}

# Help overlay for displaying keyboard shortcuts and help
class HelpOverlay {
    hidden [object] $_eventPublisher  # EventPublisher
    hidden [object] $_renderEngine    # RenderEngine
    hidden [hashtable] $_shortcuts = @{}
    hidden [string] $_currentContext = "Normal"
    hidden [bool] $_isVisible = $false
    
    HelpOverlay([object]$eventPublisher, [object]$renderEngine) {
        $this._eventPublisher = $eventPublisher
        $this._renderEngine = $renderEngine
        $this.InitializeShortcuts()
    }
    
    [void] InitializeShortcuts() {
        $this._shortcuts = @{
            'Normal' = @{
                'j/k' = 'Move up/down'
                'gg' = 'Go to top'
                'G' = 'Go to bottom'
                '/' = 'Search'
                ':' = 'Command mode'
                'q' = 'Quit'
                'a' = 'Add task'
                'd' = 'Delete task'
                'e' = 'Edit task'
                'Enter' = 'Complete task'
                '?' = 'Show help'
            }
            'Search' = @{
                'n' = 'Next match'
                'Shift+n' = 'Previous match'
                'Escape' = 'Exit search'
                'Enter' = 'Go to match'
            }
            'Command' = @{
                'Tab' = 'Auto-complete'
                'Up/Down' = 'Command history'
                'Enter' = 'Execute command'
                'Escape' = 'Cancel command'
            }
        }
    }
    
    [void] SetShortcuts([hashtable]$shortcuts) {
        $this._shortcuts['Custom'] = $shortcuts
    }
    
    [void] SetContext([string]$context) {
        $this._currentContext = $context
    }
    
    [array] GetContextShortcuts() {
        if ($this._shortcuts.ContainsKey($this._currentContext)) {
            $contextShortcuts = @()
            foreach ($shortcut in $this._shortcuts[$this._currentContext].GetEnumerator()) {
                $contextShortcuts += "$($shortcut.Key) - $($shortcut.Value)"
            }
            return $contextShortcuts
        }
        return @()
    }
    
    [void] Show() {
        $this._isVisible = $true
    }
    
    [void] Hide() {
        $this._isVisible = $false
    }
    
    [void] RenderToBuffer([object]$buffer) {
        if (-not $this._isVisible) { return }
        
        $width = $buffer.GetWidth()
        $height = $buffer.GetHeight()
        
        # Clear buffer area for help
        for ($row = 0; $row -lt $height; $row++) {
            $buffer.SetLine($row, " " * $width)
        }
        
        # Title
        $title = "TaskWarrior-TUI Help"
        $titleLine = $title.PadLeft(($width - $title.Length) / 2 + $title.Length)
        $buffer.SetLine(1, $titleLine.PadRight($width))
        
        # Underline
        $underline = "=" * $title.Length
        $underlineLine = $underline.PadLeft(($width - $underline.Length) / 2 + $underline.Length)
        $buffer.SetLine(2, $underlineLine.PadRight($width))
        
        # Shortcuts for current context
        $currentRow = 4
        if ($this._shortcuts.ContainsKey($this._currentContext)) {
            $contextTitle = "$($this._currentContext) Mode:"
            $buffer.SetLine($currentRow, $contextTitle.PadRight($width))
            $currentRow += 2
            
            foreach ($shortcut in $this._shortcuts[$this._currentContext].GetEnumerator()) {
                $shortcutLine = "  $($shortcut.Key.PadRight(12)) $($shortcut.Value)"
                $buffer.SetLine($currentRow, $shortcutLine.PadRight($width))
                $currentRow++
                
                if ($currentRow -ge $height - 2) { break }
            }
        }
        
        # Footer
        $footer = "Press any key to close help"
        $footerLine = $footer.PadLeft(($width - $footer.Length) / 2 + $footer.Length)
        $buffer.SetLine($height - 2, $footerLine.PadRight($width))
    }
}