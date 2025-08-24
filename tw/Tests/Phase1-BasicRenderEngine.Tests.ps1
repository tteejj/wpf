# Phase 1: Basic Render Engine Tests
# These tests will fail initially and drive the implementation

BeforeAll {
    # Import the render engine classes (will fail initially)
    try {
        . "$PSScriptRoot/../Core/RenderEngine.ps1"
        . "$PSScriptRoot/../Core/EventSystem.ps1"
        . "$PSScriptRoot/../Core/ConfigurationProvider.ps1"
    } catch {
        Write-Warning "Core classes not yet implemented: $_"
    }
}

Describe "Basic Render Engine" {
    Context "Initialization" {
        It "Should create render engine instance" {
            $renderEngine = [RenderEngine]::new()
            $renderEngine | Should -Not -BeNullOrEmpty
            $renderEngine.GetType().Name | Should -Be "RenderEngine"
        }
        
        It "Should initialize with default settings" {
            $renderEngine = [RenderEngine]::new()
            $renderEngine.IsInitialized | Should -Be $true
            $renderEngine.FrameRate | Should -Be 60
        }
    }
    
    Context "VT100 Control Sequences" {
        It "Should generate clear screen sequence" {
            $renderEngine = [RenderEngine]::new()
            $clearSeq = $renderEngine.ClearScreen()
            $clearSeq | Should -Be "`e[2J`e[H"
        }
        
        It "Should generate cursor positioning sequence" {
            $renderEngine = [RenderEngine]::new()
            $moveSeq = $renderEngine.MoveTo(10, 5)
            $moveSeq | Should -Be "`e[6;11H"  # 1-based coordinates
        }
        
        It "Should generate color sequences" {
            $renderEngine = [RenderEngine]::new()
            $colorSeq = $renderEngine.SetForegroundColor(255, 0, 0)
            $colorSeq | Should -Be "`e[38;2;255;0;0m"
        }
    }
    
    Context "Text Rendering" {
        It "Should render simple text to buffer" {
            $renderEngine = [RenderEngine]::new()
            $buffer = $renderEngine.CreateBuffer(80, 24)
            $renderEngine.WriteText($buffer, 0, 0, "Hello World")
            
            $buffer.GetText(0, 0, 11) | Should -Be "Hello World"
        }
        
        It "Should handle text wrapping" {
            $renderEngine = [RenderEngine]::new()
            $buffer = $renderEngine.CreateBuffer(10, 5)
            $longText = "This is a very long line of text"
            
            $renderEngine.WriteText($buffer, 0, 0, $longText, $true)  # Enable wrapping
            $buffer.GetLine(0) | Should -Be "This is a "
            $buffer.GetLine(1) | Should -Match "very long"
        }
        
        It "Should handle Unicode text correctly" {
            $renderEngine = [RenderEngine]::new()
            $buffer = $renderEngine.CreateBuffer(20, 5)
            $unicodeText = "Hello 世界 🌍"
            
            $renderEngine.WriteText($buffer, 0, 0, $unicodeText)
            $buffer.GetText(0, 0, $unicodeText.Length) | Should -Be $unicodeText
        }
    }
    
    Context "Performance Requirements" {
        It "Should meet reasonable rendering performance" {
            $renderEngine = [RenderEngine]::new()
            $buffer = $renderEngine.CreateBuffer(80, 24)  # Smaller buffer
            
            # Fill buffer with test data
            for ($i = 0; $i -lt 24; $i++) {
                $renderEngine.WriteText($buffer, 0, $i, "Line $i with some content")
            }
            
            $renderTime = Measure-Command {
                $output = $renderEngine.RenderBuffer($buffer)
            }
            
            $renderTime.TotalMilliseconds | Should -BeLessThan 300  # Very realistic target for PowerShell
        }
        
        It "Should handle large content efficiently" {
            $renderEngine = [RenderEngine]::new()
            $buffer = $renderEngine.CreateBuffer(200, 100)
            
            # Fill with 10K characters
            $largeContent = "x" * 10000
            
            $renderTime = Measure-Command {
                $renderEngine.WriteText($buffer, 0, 0, $largeContent, $true)
            }
            
            $renderTime.TotalMilliseconds | Should -BeLessThan 100
        }
    }
    
    Context "Memory Management" {
        It "Should not leak memory during repeated operations" {
            $renderEngine = [RenderEngine]::new()
            
            $initialMemory = [GC]::GetTotalMemory($false)
            
            # Perform 1000 render operations
            for ($i = 0; $i -lt 1000; $i++) {
                $buffer = $renderEngine.CreateBuffer(80, 24)
                $renderEngine.WriteText($buffer, 0, 0, "Test $i")
                $null = $renderEngine.RenderBuffer($buffer)
                $buffer.Dispose()
            }
            
            [GC]::Collect()
            [GC]::WaitForPendingFinalizers()
            [GC]::Collect()
            
            $finalMemory = [GC]::GetTotalMemory($false)
            $memoryIncrease = $finalMemory - $initialMemory
            
            # Should not increase by more than 5MB
            $memoryIncrease | Should -BeLessThan (5 * 1024 * 1024)
        }
    }
}

Describe "Event System" {
    Context "Basic Event Publishing" {
        It "Should create event publisher instance" {
            $eventPublisher = [EventPublisher]::new()
            $eventPublisher | Should -Not -BeNullOrEmpty
        }
        
        It "Should publish events to subscribers" {
            $eventPublisher = [EventPublisher]::new()
            $Global:eventReceived = $false
            $Global:receivedData = $null
            
            $eventPublisher.Subscribe('TestEvent', {
                param($eventData)
                $Global:eventReceived = $true
                $Global:receivedData = $eventData
            })
            
            $eventPublisher.Publish('TestEvent', @{ Message = "Test" })
            
            $Global:eventReceived | Should -Be $true
            $Global:receivedData.Message | Should -Be "Test"
        }
        
        It "Should handle multiple subscribers" {
            $eventPublisher = [EventPublisher]::new()
            $Global:subscriber1Called = $false
            $Global:subscriber2Called = $false
            
            $eventPublisher.Subscribe('TestEvent', { $Global:subscriber1Called = $true })
            $eventPublisher.Subscribe('TestEvent', { $Global:subscriber2Called = $true })
            
            $eventPublisher.Publish('TestEvent', @{})
            
            $Global:subscriber1Called | Should -Be $true
            $Global:subscriber2Called | Should -Be $true
        }
        
        It "Should filter events by type" {
            $eventPublisher = [EventPublisher]::new()
            $Global:event1Received = $false
            $Global:event2Received = $false
            
            $eventPublisher.Subscribe('Event1', { $Global:event1Received = $true })
            $eventPublisher.Subscribe('Event2', { $Global:event2Received = $true })
            
            $eventPublisher.Publish('Event1', @{})
            
            $Global:event1Received | Should -Be $true
            $Global:event2Received | Should -Be $false
        }
        
        It "Should unsubscribe properly" {
            $eventPublisher = [EventPublisher]::new()
            $Global:eventReceived = $false
            
            $callback = { $Global:eventReceived = $true }
            $eventPublisher.Subscribe('TestEvent', $callback)
            $eventPublisher.Unsubscribe('TestEvent', $callback)
            
            $eventPublisher.Publish('TestEvent', @{})
            
            $Global:eventReceived | Should -Be $false
        }
    }
    
    Context "Event Performance" {
        It "Should handle high-frequency events efficiently" {
            $eventPublisher = [EventPublisher]::new()
            $Global:eventCount = 0
            
            $eventPublisher.Subscribe('HighFreqEvent', { 
                $Global:eventCount++
            })
            
            $publishTime = Measure-Command {
                for ($i = 0; $i -lt 1000; $i++) {  # Reduced for test speed
                    $eventPublisher.Publish('HighFreqEvent', @{ Count = $i })
                }
            }
            
            $publishTime.TotalMilliseconds | Should -BeLessThan 1000  # 1s for 1K events
            $Global:eventCount | Should -Be 1000
        }
    }
}

Describe "Configuration Management" {
    Context "Configuration Loading" {
        BeforeEach {
            # Create test config file
            $testConfig = @{
                app = @{
                    refresh_rate = 2
                    max_tasks_display = 1000
                }
                theme = @{
                    background = "black"
                    foreground = "white"
                }
            } | ConvertTo-Json -Depth 10
            
            $script:testConfigPath = "$TestDrive/test-config.json"
            Set-Content -Path $script:testConfigPath -Value $testConfig
        }
        
        It "Should load configuration from file" {
            $configProvider = [TaskWarriorConfigProvider]::new($script:testConfigPath, $null)
            
            $configProvider.GetValue('app.refresh_rate') | Should -Be 2
            $configProvider.GetValue('theme.background') | Should -Be "black"
        }
        
        It "Should validate configuration schema" {
            $configProvider = [TaskWarriorConfigProvider]::new($script:testConfigPath, $null)
            $validation = $configProvider.ValidateConfiguration()
            
            $validation.IsValid | Should -Be $true
            $validation.Errors.Count | Should -Be 0
        }
        
        It "Should apply defaults for missing values" {
            # Create minimal config
            $minimalConfig = @{
                app = @{
                    refresh_rate = 5
                }
            } | ConvertTo-Json
            
            $minimalConfigPath = "$TestDrive/minimal-config.json"
            Set-Content -Path $minimalConfigPath -Value $minimalConfig
            
            $configProvider = [TaskWarriorConfigProvider]::new($minimalConfigPath, $null)
            
            $configProvider.GetValue('app.refresh_rate') | Should -Be 5  # User value
            $configProvider.GetValue('app.max_tasks_display') | Should -Be 1000  # Default value
            $configProvider.GetValue('theme.background') | Should -Be "black"  # Default value
        }
        
        It "Should handle invalid configuration gracefully" {
            $invalidConfig = "{ invalid json }"
            $invalidConfigPath = "$TestDrive/invalid-config.json"
            Set-Content -Path $invalidConfigPath -Value $invalidConfig
            
            { $configProvider = [TaskWarriorConfigProvider]::new($invalidConfigPath, $null) } | Should -Not -Throw
        }
    }
    
    Context "Configuration Watching" {
        It "Should detect file changes" {
            $eventPublisher = [EventPublisher]::new()
            $Global:configChangedEventReceived = $false
            
            $eventPublisher.Subscribe('ConfigurationChanged', {
                $Global:configChangedEventReceived = $true
            })
            
            $configProvider = [TaskWarriorConfigProvider]::new($script:testConfigPath, $eventPublisher)
            
            # Modify config file
            Start-Sleep -Milliseconds 200  # Ensure file watcher is ready
            $newConfig = @{
                app = @{ refresh_rate = 10 }
                theme = @{ background = "blue" }
            } | ConvertTo-Json
            Set-Content -Path $script:testConfigPath -Value $newConfig
            
            # Wait for file watcher with longer timeout
            Start-Sleep -Milliseconds 1000
            
            $Global:configChangedEventReceived | Should -Be $true
            $configProvider.GetValue('app.refresh_rate') | Should -Be 10
        }
    }
}