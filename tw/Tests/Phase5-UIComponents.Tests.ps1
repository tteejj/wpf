# Phase 5: UI Components Tests
# Input handling, keyboard shortcuts, and interactive UI elements

BeforeAll {
    # Import required classes
    try {
        . "$PSScriptRoot/../Core/RenderEngine.ps1"
        . "$PSScriptRoot/../Core/EventSystem.ps1"
        . "$PSScriptRoot/../Core/ConfigurationProvider.ps1"
        . "$PSScriptRoot/../Core/TaskDataProvider.ps1"
        . "$PSScriptRoot/../Core/CachingSystem.ps1"
        . "$PSScriptRoot/../Core/VirtualScrolling.ps1"
        . "$PSScriptRoot/../Core/FilterEngine.ps1"
        . "$PSScriptRoot/../Core/UIComponents.ps1"
    } catch {
        Write-Warning "Core classes not yet implemented: $_"
    }
    
    # Create mock console input for testing
    $Global:MockInputSequences = @()
    $Global:CurrentInputIndex = 0
    
    # Helper function to mock key inputs
    function Add-MockKeyInput {
        param([string]$Key, [bool]$Ctrl = $false, [bool]$Alt = $false, [bool]$Shift = $false)
        $Global:MockInputSequences += @{
            Key = $Key
            Ctrl = $Ctrl
            Alt = $Alt
            Shift = $Shift
        }
    }
    
    function Reset-MockInput {
        $Global:MockInputSequences = @()
        $Global:CurrentInputIndex = 0
    }
}

Describe "Keyboard Input Handler" {
    Context "Basic Input Processing" {
        It "Should create input handler instance" {
            $eventPublisher = [EventPublisher]::new()
            $inputHandler = [KeyboardInputHandler]::new($eventPublisher)
            
            $inputHandler | Should -Not -BeNullOrEmpty
            $inputHandler.GetType().Name | Should -Be "KeyboardInputHandler"
        }
        
        It "Should process single character input" {
            $eventPublisher = [EventPublisher]::new()
            $inputHandler = [KeyboardInputHandler]::new($eventPublisher)
            
            $Global:keyEventReceived = $false
            $Global:keyEventData = $null
            
            $eventPublisher.Subscribe('KeyPressed', {
                param($eventData)
                $Global:keyEventReceived = $true
                $Global:keyEventData = $eventData
            })
            
            # Simulate 'j' key press
            $inputHandler.ProcessKey('j', $false, $false, $false)
            
            $Global:keyEventReceived | Should -Be $true
            $Global:keyEventData.Key | Should -Be 'j'
            $Global:keyEventData.Ctrl | Should -Be $false
        }
        
        It "Should detect modifier keys" {
            $eventPublisher = [EventPublisher]::new()
            $inputHandler = [KeyboardInputHandler]::new($eventPublisher)
            
            $Global:keyEventReceived = $false
            $Global:keyEventData = $null
            
            $eventPublisher.Subscribe('KeyPressed', {
                param($eventData)
                $Global:keyEventReceived = $true
                $Global:keyEventData = $eventData
            })
            
            # Simulate Ctrl+C
            $inputHandler.ProcessKey('c', $true, $false, $false)
            
            $Global:keyEventReceived | Should -Be $true
            $Global:keyEventData.Key | Should -Be 'c'
            $Global:keyEventData.Ctrl | Should -Be $true
        }
        
        It "Should handle special keys" {
            $eventPublisher = [EventPublisher]::new()
            $inputHandler = [KeyboardInputHandler]::new($eventPublisher)
            
            $Global:keyEventReceived = $false
            $Global:keyEventData = $null
            
            $eventPublisher.Subscribe('KeyPressed', {
                param($eventData)
                $Global:keyEventReceived = $true
                $Global:keyEventData = $eventData
            })
            
            # Simulate Arrow Down
            $inputHandler.ProcessKey('ArrowDown', $false, $false, $false)
            
            $Global:keyEventReceived | Should -Be $true
            $Global:keyEventData.Key | Should -Be 'ArrowDown'
        }
    }
    
    Context "Key Sequences" {
        It "Should handle multi-key sequences" {
            $eventPublisher = [EventPublisher]::new()
            $inputHandler = [KeyboardInputHandler]::new($eventPublisher)
            
            $Global:sequenceEventReceived = $false
            $Global:sequenceEventData = $null
            
            $eventPublisher.Subscribe('KeySequence', {
                param($eventData)
                $Global:sequenceEventReceived = $true
                $Global:sequenceEventData = $eventData
            })
            
            # Simulate 'gg' sequence (go to top)
            $inputHandler.ProcessKey('g', $false, $false, $false)
            $inputHandler.ProcessKey('g', $false, $false, $false)
            
            $Global:sequenceEventReceived | Should -Be $true
            $Global:sequenceEventData.Sequence | Should -Be 'gg'
        }
        
        It "Should timeout incomplete sequences" {
            $eventPublisher = [EventPublisher]::new()
            $inputHandler = [KeyboardInputHandler]::new($eventPublisher, 100)  # 100ms timeout
            
            $Global:timeoutEventReceived = $false
            
            $eventPublisher.Subscribe('SequenceTimeout', {
                $Global:timeoutEventReceived = $true
            })
            
            # Start a sequence but don't complete it
            $inputHandler.ProcessKey('g', $false, $false, $false)
            
            # Simulate timeout
            Start-Sleep -Milliseconds 150
            $inputHandler.CheckSequenceTimeout()
            
            $Global:timeoutEventReceived | Should -Be $true
        }
    }
    
    Context "Input Modes" {
        It "Should switch between normal and command mode" {
            $eventPublisher = [EventPublisher]::new()
            $inputHandler = [KeyboardInputHandler]::new($eventPublisher)
            
            # Should start in normal mode
            $inputHandler.GetCurrentMode() | Should -Be 'Normal'
            
            # Switch to command mode with ':'
            $inputHandler.ProcessKey(':', $false, $false, $false)
            $inputHandler.GetCurrentMode() | Should -Be 'Command'
            
            # Escape back to normal mode
            $inputHandler.ProcessKey('Escape', $false, $false, $false)
            $inputHandler.GetCurrentMode() | Should -Be 'Normal'
        }
        
        It "Should handle search mode" {
            $eventPublisher = [EventPublisher]::new()
            $inputHandler = [KeyboardInputHandler]::new($eventPublisher)
            
            # Switch to search mode with '/'
            $inputHandler.ProcessKey('/', $false, $false, $false)
            $inputHandler.GetCurrentMode() | Should -Be 'Search'
            
            # Type search query
            $inputHandler.ProcessKey('p', $false, $false, $false)
            $inputHandler.ProcessKey('e', $false, $false, $false)
            $inputHandler.ProcessKey('n', $false, $false, $false)
            
            $inputHandler.GetCurrentInput() | Should -Be 'pen'
        }
        
        It "Should handle edit mode" {
            $eventPublisher = [EventPublisher]::new()
            $inputHandler = [KeyboardInputHandler]::new($eventPublisher)
            
            # Switch to edit mode
            $inputHandler.SetMode('Edit')
            $inputHandler.GetCurrentMode() | Should -Be 'Edit'
            
            # Should accept text input
            $inputHandler.ProcessKey('T', $false, $false, $false)
            $inputHandler.ProcessKey('e', $false, $false, $false)
            $inputHandler.ProcessKey('s', $false, $false, $false)
            $inputHandler.ProcessKey('t', $false, $false, $false)
            
            $inputHandler.GetCurrentInput() | Should -Be 'Test'
        }
    }
}

Describe "Command Line Interface" {
    Context "Command Input" {
        It "Should create command line interface" {
            $eventPublisher = [EventPublisher]::new()
            $renderEngine = [RenderEngine]::new()
            $commandLine = [CommandLineInterface]::new($eventPublisher, $renderEngine)
            
            $commandLine | Should -Not -BeNullOrEmpty
            $commandLine.GetType().Name | Should -Be "CommandLineInterface"
        }
        
        It "Should display command prompt" {
            $eventPublisher = [EventPublisher]::new()
            $renderEngine = [RenderEngine]::new()
            $commandLine = [CommandLineInterface]::new($eventPublisher, $renderEngine)
            $buffer = $renderEngine.CreateBuffer(80, 24)
            
            $commandLine.SetPrompt(":")
            $commandLine.SetInput("add New task")
            $commandLine.RenderToBuffer($buffer, 23)  # Bottom line
            
            $bottomLine = $buffer.GetLine(23)
            $bottomLine | Should -Match ":add New task"
        }
        
        It "Should handle command history" {
            $eventPublisher = [EventPublisher]::new()
            $renderEngine = [RenderEngine]::new()
            $commandLine = [CommandLineInterface]::new($eventPublisher, $renderEngine)
            
            # Add commands to history
            $commandLine.AddToHistory("add First task")
            $commandLine.AddToHistory("add Second task")
            $commandLine.AddToHistory("status:pending")
            
            # Navigate history with arrows
            $commandLine.HistoryUp()
            $commandLine.GetCurrentInput() | Should -Be "status:pending"
            
            $commandLine.HistoryUp()
            $commandLine.GetCurrentInput() | Should -Be "add Second task"
            
            $commandLine.HistoryDown()
            $commandLine.GetCurrentInput() | Should -Be "status:pending"
        }
        
        It "Should support command completion" {
            $eventPublisher = [EventPublisher]::new()
            $renderEngine = [RenderEngine]::new()
            $commandLine = [CommandLineInterface]::new($eventPublisher, $renderEngine)
            
            # Set up completion candidates
            $completions = @("add", "modify", "delete", "done", "start", "stop")
            $commandLine.SetCompletionCandidates($completions)
            
            # Type partial command
            $commandLine.SetInput("ad")
            
            # Request completion
            $suggestion = $commandLine.GetCompletion()
            $suggestion | Should -Be "add"
        }
        
        It "Should execute commands" {
            $eventPublisher = [EventPublisher]::new()
            $renderEngine = [RenderEngine]::new()
            $commandLine = [CommandLineInterface]::new($eventPublisher, $renderEngine)
            
            $Global:commandExecuted = $false
            $Global:executedCommand = ""
            
            $eventPublisher.Subscribe('CommandExecuted', {
                param($eventData)
                $Global:commandExecuted = $true
                $Global:executedCommand = $eventData.Command
            })
            
            $commandLine.SetInput("add New task")
            $commandLine.ExecuteCommand()
            
            $Global:commandExecuted | Should -Be $true
            $Global:executedCommand | Should -Be "add New task"
        }
    }
    
    Context "Search Interface" {
        It "Should handle incremental search" {
            $eventPublisher = [EventPublisher]::new()
            $renderEngine = [RenderEngine]::new()
            $searchInterface = [SearchInterface]::new($eventPublisher, $renderEngine)
            
            $Global:searchQueryChanged = $false
            $Global:searchQuery = ""
            
            $eventPublisher.Subscribe('SearchQueryChanged', {
                param($eventData)
                $Global:searchQueryChanged = $true
                $Global:searchQuery = $eventData.Query
            })
            
            $searchInterface.SetQuery("pend")
            
            $Global:searchQueryChanged | Should -Be $true
            $Global:searchQuery | Should -Be "pend"
        }
        
        It "Should highlight search matches" {
            $eventPublisher = [EventPublisher]::new()
            $renderEngine = [RenderEngine]::new()
            $searchInterface = [SearchInterface]::new($eventPublisher, $renderEngine)
            
            $searchInterface.SetQuery("task")
            $searchInterface.SetMatches(@(1, 3, 5, 7))  # Matching line numbers
            
            $matches = $searchInterface.GetCurrentMatches()
            $matches.Count | Should -Be 4
            $matches[0] | Should -Be 1
        }
        
        It "Should navigate between search results" {
            $eventPublisher = [EventPublisher]::new()
            $renderEngine = [RenderEngine]::new()
            $searchInterface = [SearchInterface]::new($eventPublisher, $renderEngine)
            
            $searchInterface.SetQuery("test")
            $searchInterface.SetMatches(@(2, 5, 8, 12))
            
            # Navigate to next match
            $searchInterface.NextMatch()
            $searchInterface.GetCurrentMatchIndex() | Should -Be 0
            
            $searchInterface.NextMatch()
            $searchInterface.GetCurrentMatchIndex() | Should -Be 1
            
            # Navigate to previous match
            $searchInterface.PrevMatch()
            $searchInterface.GetCurrentMatchIndex() | Should -Be 0
        }
    }
}

Describe "Status Bar" {
    Context "Status Display" {
        It "Should create status bar" {
            $eventPublisher = [EventPublisher]::new()
            $renderEngine = [RenderEngine]::new()
            $statusBar = [StatusBar]::new($eventPublisher, $renderEngine)
            
            $statusBar | Should -Not -BeNullOrEmpty
            $statusBar.GetType().Name | Should -Be "StatusBar"
        }
        
        It "Should display current mode" {
            $eventPublisher = [EventPublisher]::new()
            $renderEngine = [RenderEngine]::new()
            $statusBar = [StatusBar]::new($eventPublisher, $renderEngine)
            $buffer = $renderEngine.CreateBuffer(80, 24)
            
            $statusBar.SetMode("Normal")
            $statusBar.RenderToBuffer($buffer, 22)  # Second to last line
            
            $statusLine = $buffer.GetLine(22)
            $statusLine | Should -Match "Normal"
        }
        
        It "Should display task statistics" {
            $eventPublisher = [EventPublisher]::new()
            $renderEngine = [RenderEngine]::new()
            $statusBar = [StatusBar]::new($eventPublisher, $renderEngine)
            $buffer = $renderEngine.CreateBuffer(80, 24)
            
            $stats = @{
                Total = 150
                Pending = 89
                Completed = 45
                Waiting = 16
            }
            
            $statusBar.SetTaskStatistics($stats)
            $statusBar.RenderToBuffer($buffer, 22)
            
            $statusLine = $buffer.GetLine(22)
            $statusLine | Should -Match "150"
            $statusLine | Should -Match "89"
        }
        
        It "Should display filter information" {
            $eventPublisher = [EventPublisher]::new()
            $renderEngine = [RenderEngine]::new()
            $statusBar = [StatusBar]::new($eventPublisher, $renderEngine)
            $buffer = $renderEngine.CreateBuffer(80, 24)
            
            $statusBar.SetActiveFilter("status:pending project:work")
            $statusBar.RenderToBuffer($buffer, 22)
            
            $statusLine = $buffer.GetLine(22)
            $statusLine | Should -Match "status:pending"
        }
        
        It "Should show progress indicators" {
            $eventPublisher = [EventPublisher]::new()
            $renderEngine = [RenderEngine]::new()
            $statusBar = [StatusBar]::new($eventPublisher, $renderEngine)
            $buffer = $renderEngine.CreateBuffer(80, 24)
            
            $statusBar.SetProgress("Loading tasks...", 0.6)  # 60% complete
            $statusBar.RenderToBuffer($buffer, 22)
            
            $statusLine = $buffer.GetLine(22)
            $statusLine | Should -Match "Loading tasks"
            $statusLine | Should -Match "60%"
        }
    }
    
    Context "Dynamic Updates" {
        It "Should update automatically on events" {
            $eventPublisher = [EventPublisher]::new()
            $renderEngine = [RenderEngine]::new()
            $statusBar = [StatusBar]::new($eventPublisher, $renderEngine)
            
            $Global:statusUpdated = $false
            
            $eventPublisher.Subscribe('StatusBarUpdated', {
                $Global:statusUpdated = $true
            })
            
            # Simulate filter change event
            $eventPublisher.Publish('FiltersChanged', @{
                FilterCount = 2
                Filters = @("status:pending", "project:work")
            })
            
            $Global:statusUpdated | Should -Be $true
        }
    }
}

Describe "Dialog System" {
    Context "Modal Dialogs" {
        It "Should create confirmation dialog" {
            $eventPublisher = [EventPublisher]::new()
            $renderEngine = [RenderEngine]::new()
            $dialog = [ConfirmationDialog]::new($eventPublisher, $renderEngine)
            
            $dialog | Should -Not -BeNullOrEmpty
            $dialog.GetType().Name | Should -Be "ConfirmationDialog"
        }
        
        It "Should display confirmation message" {
            $eventPublisher = [EventPublisher]::new()
            $renderEngine = [RenderEngine]::new()
            $dialog = [ConfirmationDialog]::new($eventPublisher, $renderEngine)
            $buffer = $renderEngine.CreateBuffer(80, 24)
            
            $dialog.SetMessage("Delete task 'Important task'?")
            $dialog.SetOptions(@("Yes", "No"))
            $dialog.Show()  # Make dialog visible before rendering
            $dialog.RenderToBuffer($buffer)
            
            # Check that dialog content is rendered in center area
            $foundMessage = $false
            for ($i = 8; $i -lt 16; $i++) {
                $line = $buffer.GetLine($i)
                if ($line -match "Important task") {
                    $foundMessage = $true
                    break
                }
            }
            $foundMessage | Should -Be $true
        }
        
        It "Should handle dialog navigation" {
            $eventPublisher = [EventPublisher]::new()
            $renderEngine = [RenderEngine]::new()
            $dialog = [ConfirmationDialog]::new($eventPublisher, $renderEngine)
            
            $dialog.SetOptions(@("Yes", "No", "Cancel"))
            
            # Should start with first option selected
            $dialog.GetSelectedOption() | Should -Be 0
            
            # Navigate right
            $dialog.NextOption()
            $dialog.GetSelectedOption() | Should -Be 1
            
            $dialog.NextOption()
            $dialog.GetSelectedOption() | Should -Be 2
            
            # Navigate left
            $dialog.PreviousOption()
            $dialog.GetSelectedOption() | Should -Be 1
        }
        
        It "Should publish dialog results" {
            $eventPublisher = [EventPublisher]::new()
            $renderEngine = [RenderEngine]::new()
            $dialog = [ConfirmationDialog]::new($eventPublisher, $renderEngine)
            
            $Global:dialogResult = $null
            
            $eventPublisher.Subscribe('DialogResult', {
                param($eventData)
                $Global:dialogResult = $eventData.Result
            })
            
            $dialog.SetOptions(@("OK", "Cancel"))
            $dialog.SetSelectedOption(0)
            $dialog.Confirm()
            
            $Global:dialogResult | Should -Be "OK"
        }
    }
    
    Context "Input Dialogs" {
        It "Should create text input dialog" {
            $eventPublisher = [EventPublisher]::new()
            $renderEngine = [RenderEngine]::new()
            $dialog = [InputDialog]::new($eventPublisher, $renderEngine)
            
            $dialog | Should -Not -BeNullOrEmpty
            $dialog.GetType().Name | Should -Be "InputDialog"
        }
        
        It "Should handle text input" {
            $eventPublisher = [EventPublisher]::new()
            $renderEngine = [RenderEngine]::new()
            $dialog = [InputDialog]::new($eventPublisher, $renderEngine)
            
            $dialog.SetPrompt("Enter task description:")
            $dialog.SetInput("New task")
            
            $dialog.GetCurrentInput() | Should -Be "New task"
        }
        
        It "Should validate input" {
            $eventPublisher = [EventPublisher]::new()
            $renderEngine = [RenderEngine]::new()
            $dialog = [InputDialog]::new($eventPublisher, $renderEngine)
            
            # Set up validation (non-empty)
            $dialog.SetValidator({ param($input) $input.Length -gt 0 })
            
            $dialog.SetInput("Valid input")
            $dialog.IsValid() | Should -Be $true
            
            $dialog.SetInput("")
            $dialog.IsValid() | Should -Be $false
        }
    }
}

Describe "Help System" {
    Context "Help Display" {
        It "Should create help overlay" {
            $eventPublisher = [EventPublisher]::new()
            $renderEngine = [RenderEngine]::new()
            $helpSystem = [HelpOverlay]::new($eventPublisher, $renderEngine)
            
            $helpSystem | Should -Not -BeNullOrEmpty
            $helpSystem.GetType().Name | Should -Be "HelpOverlay"
        }
        
        It "Should display keyboard shortcuts" {
            $eventPublisher = [EventPublisher]::new()
            $renderEngine = [RenderEngine]::new()
            $helpSystem = [HelpOverlay]::new($eventPublisher, $renderEngine)
            $buffer = $renderEngine.CreateBuffer(80, 24)
            
            $shortcuts = @{
                "j/k" = "Move up/down"
                "gg" = "Go to top"
                "G" = "Go to bottom"
                "/" = "Search"
                ":" = "Command mode"
                "q" = "Quit"
            }
            
            $helpSystem.SetShortcuts($shortcuts)
            $helpSystem.Show()  # Make help overlay visible before rendering
            $helpSystem.RenderToBuffer($buffer)
            
            # Verify shortcuts are displayed
            $helpText = ""
            for ($i = 0; $i -lt 24; $i++) {
                $helpText += $buffer.GetLine($i)
            }
            
            $helpText | Should -Match "j/k"
            $helpText | Should -Match "Move up/down"
            $helpText | Should -Match "Search"
        }
        
        It "Should support context-sensitive help" {
            $eventPublisher = [EventPublisher]::new()
            $renderEngine = [RenderEngine]::new()
            $helpSystem = [HelpOverlay]::new($eventPublisher, $renderEngine)
            
            # Set context to search mode
            $helpSystem.SetContext("Search")
            $contextShortcuts = $helpSystem.GetContextShortcuts()
            
            $contextShortcuts | Should -Contain "n - Next match"
            $contextShortcuts | Should -Contain "Shift+n - Previous match"
            $contextShortcuts | Should -Contain "Escape - Exit search"
        }
    }
}

Describe "Performance Requirements" {
    Context "Input Responsiveness" {
        It "Should process key events quickly" {
            $eventPublisher = [EventPublisher]::new()
            $inputHandler = [KeyboardInputHandler]::new($eventPublisher)
            
            $processingTime = Measure-Command {
                for ($i = 0; $i -lt 100; $i++) {
                    $inputHandler.ProcessKey('j', $false, $false, $false)
                }
            }
            
            $processingTime.TotalMilliseconds | Should -BeLessThan 1000  # 100 key presses in under 1 second
        }
        
        It "Should render UI components efficiently" {
            $eventPublisher = [EventPublisher]::new()
            $renderEngine = [RenderEngine]::new()
            $buffer = $renderEngine.CreateBuffer(80, 24)
            
            $commandLine = [CommandLineInterface]::new($eventPublisher, $renderEngine)
            $statusBar = [StatusBar]::new($eventPublisher, $renderEngine)
            
            $renderTime = Measure-Command {
                for ($i = 0; $i -lt 60; $i++) {  # 60 FPS target
                    $commandLine.RenderToBuffer($buffer, 23)
                    $statusBar.RenderToBuffer($buffer, 22)
                }
            }
            
            $renderTime.TotalMilliseconds | Should -BeLessThan 1000  # 60 renders in under 1 second
        }
    }
    
    Context "Memory Usage" {
        It "Should not leak memory during UI operations" {
            $eventPublisher = [EventPublisher]::new()
            $renderEngine = [RenderEngine]::new()
            $inputHandler = [KeyboardInputHandler]::new($eventPublisher)
            
            $initialMemory = [GC]::GetTotalMemory($false)
            
            # Perform many UI operations
            for ($i = 0; $i -lt 1000; $i++) {
                $buffer = $renderEngine.CreateBuffer(80, 24)
                $inputHandler.ProcessKey([char]($i % 26 + 97), $false, $false, $false)  # a-z
                $buffer.Dispose()
            }
            
            [GC]::Collect()
            [GC]::WaitForPendingFinalizers()
            [GC]::Collect()
            
            $finalMemory = [GC]::GetTotalMemory($false)
            $memoryIncrease = $finalMemory - $initialMemory
            
            $memoryIncrease | Should -BeLessThan (3 * 1024 * 1024)  # Less than 3MB increase
        }
    }
}