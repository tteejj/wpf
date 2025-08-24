# Phase 6: Advanced Features Tests
# Configuration management, themes, plugins, keybinding customization

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
        . "$PSScriptRoot/../Core/AdvancedFeatures.ps1"
    } catch {
        Write-Warning "Core classes not yet implemented: $_"
    }
    
    # Create test configuration directory
    $tempDir = if ($env:TEMP) { $env:TEMP } else { "/tmp" }
    $Global:TestConfigDir = Join-Path $tempDir "tw-test-config"
    if (Test-Path $Global:TestConfigDir) {
        Remove-Item $Global:TestConfigDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $Global:TestConfigDir -Force | Out-Null
}

Describe "Theme System" {
    Context "Theme Loading" {
        It "Should create theme manager instance" {
            $eventPublisher = [EventPublisher]::new()
            $themeManager = [ThemeManager]::new($eventPublisher)
            
            $themeManager | Should -Not -BeNullOrEmpty
            $themeManager.GetType().Name | Should -Be "ThemeManager"
        }
        
        It "Should load default theme" {
            $eventPublisher = [EventPublisher]::new()
            $themeManager = [ThemeManager]::new($eventPublisher)
            
            $defaultTheme = $themeManager.GetCurrentTheme()
            $defaultTheme | Should -Not -BeNullOrEmpty
            $defaultTheme.Name | Should -Be "Default"
        }
        
        It "Should support multiple themes" {
            $eventPublisher = [EventPublisher]::new()
            $themeManager = [ThemeManager]::new($eventPublisher)
            
            # Should have at least default, dark, and light themes
            $themes = $themeManager.GetAvailableThemes()
            $themes.Count | Should -BeGreaterOrEqual 3
            
            $themeNames = $themes | ForEach-Object { $_.Name }
            $themeNames | Should -Contain "Default"
            $themeNames | Should -Contain "Dark"
            $themeNames | Should -Contain "Light"
        }
        
        It "Should switch between themes" {
            $eventPublisher = [EventPublisher]::new()
            $themeManager = [ThemeManager]::new($eventPublisher)
            
            # Start with default theme
            $themeManager.GetCurrentTheme().Name | Should -Be "Default"
            
            # Switch to dark theme
            $themeManager.SetTheme("Dark")
            $themeManager.GetCurrentTheme().Name | Should -Be "Dark"
            
            # Switch to light theme
            $themeManager.SetTheme("Light")
            $themeManager.GetCurrentTheme().Name | Should -Be "Light"
        }
        
        It "Should provide color schemes for different elements" {
            $eventPublisher = [EventPublisher]::new()
            $themeManager = [ThemeManager]::new($eventPublisher)
            $themeManager.SetTheme("Dark")
            
            $theme = $themeManager.GetCurrentTheme()
            
            # Should have colors for task statuses
            $theme.GetColor("task.pending") | Should -Not -BeNullOrEmpty
            $theme.GetColor("task.completed") | Should -Not -BeNullOrEmpty
            $theme.GetColor("task.waiting") | Should -Not -BeNullOrEmpty
            
            # Should have colors for UI elements
            $theme.GetColor("ui.border") | Should -Not -BeNullOrEmpty
            $theme.GetColor("ui.background") | Should -Not -BeNullOrEmpty
            $theme.GetColor("ui.text") | Should -Not -BeNullOrEmpty
        }
        
        It "Should support priority-based styling" {
            $eventPublisher = [EventPublisher]::new()
            $themeManager = [ThemeManager]::new($eventPublisher)
            
            $theme = $themeManager.GetCurrentTheme()
            
            # Should have different colors for different priorities
            $theme.GetColor("priority.high") | Should -Not -BeNullOrEmpty
            $theme.GetColor("priority.medium") | Should -Not -BeNullOrEmpty
            $theme.GetColor("priority.low") | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Custom Theme Support" {
        It "Should load theme from file" {
            $eventPublisher = [EventPublisher]::new()
            $themeManager = [ThemeManager]::new($eventPublisher)
            
            # Create custom theme file
            $customTheme = @{
                name = "CustomTest"
                colors = @{
                    "task.pending" = "#FFD700"
                    "task.completed" = "#32CD32"
                    "ui.background" = "#2F4F4F"
                    "ui.text" = "#F5F5F5"
                }
            }
            
            $themeFile = Join-Path $Global:TestConfigDir "custom-theme.json"
            $customTheme | ConvertTo-Json -Depth 10 | Set-Content $themeFile
            
            $themeManager.LoadThemeFromFile($themeFile)
            $themes = $themeManager.GetAvailableThemes()
            
            $customThemeName = $themes | Where-Object { $_.Name -eq "CustomTest" } | Select-Object -First 1
            $customThemeName | Should -Not -BeNullOrEmpty
        }
        
        It "Should validate theme files" {
            $eventPublisher = [EventPublisher]::new()
            $themeManager = [ThemeManager]::new($eventPublisher)
            
            # Create invalid theme file (missing required colors)
            $invalidTheme = @{
                name = "InvalidTheme"
                colors = @{
                    "some.color" = "#FF0000"
                }
            }
            
            $themeFile = Join-Path $Global:TestConfigDir "invalid-theme.json"
            $invalidTheme | ConvertTo-Json -Depth 10 | Set-Content $themeFile
            
            { $themeManager.LoadThemeFromFile($themeFile) } | Should -Throw
        }
    }
    
    Context "Theme Events" {
        It "Should publish theme change events" {
            $eventPublisher = [EventPublisher]::new()
            $themeManager = [ThemeManager]::new($eventPublisher)
            
            $Global:themeChanged = $false
            $Global:themeChangeData = $null
            
            $eventPublisher.Subscribe('ThemeChanged', {
                param($eventData)
                $Global:themeChanged = $true
                $Global:themeChangeData = $eventData
            })
            
            $themeManager.SetTheme("Dark")
            
            $Global:themeChanged | Should -Be $true
            $Global:themeChangeData.NewTheme | Should -Be "Dark"
        }
    }
}

Describe "Plugin System" {
    Context "Plugin Management" {
        It "Should create plugin manager instance" {
            $eventPublisher = [EventPublisher]::new()
            $pluginManager = [PluginManager]::new($eventPublisher)
            
            $pluginManager | Should -Not -BeNullOrEmpty
            $pluginManager.GetType().Name | Should -Be "PluginManager"
        }
        
        It "Should discover plugins in directory" {
            $eventPublisher = [EventPublisher]::new()
            $pluginManager = [PluginManager]::new($eventPublisher)
            
            # Create test plugin directory
            $pluginDir = Join-Path $Global:TestConfigDir "plugins"
            New-Item -ItemType Directory -Path $pluginDir -Force | Out-Null
            
            # Create a simple plugin
            $pluginScript = @'
class TestPlugin : BasePlugin {
    TestPlugin() : base("TestPlugin", "1.0.0", "Test Plugin") {
    }
    
    [void] Initialize([object]$context) {
        # Plugin initialization
    }
    
    [void] Execute([string]$command, [array]$args) {
        # Plugin execution
    }
}
'@
            
            $pluginFile = Join-Path $pluginDir "TestPlugin.ps1"
            $pluginScript | Set-Content $pluginFile
            
            $pluginManager.DiscoverPlugins($pluginDir)
            $plugins = $pluginManager.GetAvailablePlugins()
            
            $plugins.Count | Should -BeGreaterOrEqual 1
        }
        
        It "Should load and initialize plugins" {
            $eventPublisher = [EventPublisher]::new()
            $pluginManager = [PluginManager]::new($eventPublisher)
            
            $Global:pluginInitialized = $false
            
            # Create plugin with initialization tracking
            $mockPlugin = [PSCustomObject]@{
                Name = "MockPlugin"
                Version = "1.0.0"
                Description = "Mock Plugin"
                Initialize = {
                    $Global:pluginInitialized = $true
                }
                Execute = { param($command, $args) }
            }
            
            $pluginManager.RegisterPlugin($mockPlugin)
            $pluginManager.InitializePlugin("MockPlugin", @{})
            
            $Global:pluginInitialized | Should -Be $true
        }
        
        It "Should execute plugin commands" {
            $eventPublisher = [EventPublisher]::new()
            $pluginManager = [PluginManager]::new($eventPublisher)
            
            $Global:pluginExecuted = $false
            $Global:pluginCommand = ""
            $Global:pluginArgs = @()
            
            # Create plugin with command execution tracking
            $mockPlugin = [PSCustomObject]@{
                Name = "MockPlugin"
                Version = "1.0.0"
                Description = "Mock Plugin"
                Initialize = { }
                Execute = { 
                    param($command, $arguments)
                    $Global:pluginExecuted = $true
                    $Global:pluginCommand = $command
                    $Global:pluginArgs = $arguments
                }
            }
            
            $pluginManager.RegisterPlugin($mockPlugin)
            $pluginManager.InitializePlugin("MockPlugin", @{})  # Initialize before execution
            $pluginManager.ExecutePlugin("MockPlugin", "test-command", @("arg1", "arg2"))
            
            $Global:pluginExecuted | Should -Be $true
            $Global:pluginCommand | Should -Be "test-command"
            $Global:pluginArgs.Count | Should -Be 2
        }
        
        It "Should handle plugin dependencies" {
            $eventPublisher = [EventPublisher]::new()
            $pluginManager = [PluginManager]::new($eventPublisher)
            
            # Create plugin with dependencies
            $pluginA = [PSCustomObject]@{
                Name = "PluginA"
                Version = "1.0.0"
                Description = "Plugin A"
                Dependencies = @()
                Initialize = { }
                Execute = { }
            }
            
            $pluginB = [PSCustomObject]@{
                Name = "PluginB"
                Version = "1.0.0"
                Description = "Plugin B"
                Dependencies = @("PluginA")
                Initialize = { }
                Execute = { }
            }
            
            $pluginManager.RegisterPlugin($pluginA)
            $pluginManager.RegisterPlugin($pluginB)
            
            # Should validate dependencies
            $validation = $pluginManager.ValidateDependencies("PluginB")
            $validation.IsValid | Should -Be $true
        }
        
        It "Should detect circular dependencies" {
            $eventPublisher = [EventPublisher]::new()
            $pluginManager = [PluginManager]::new($eventPublisher)
            
            # Create plugins with circular dependencies
            $pluginX = [PSCustomObject]@{
                Name = "PluginX"
                Dependencies = @("PluginY")
                Initialize = { }
                Execute = { }
            }
            
            $pluginY = [PSCustomObject]@{
                Name = "PluginY"
                Dependencies = @("PluginX")
                Initialize = { }
                Execute = { }
            }
            
            $pluginManager.RegisterPlugin($pluginX)
            $pluginManager.RegisterPlugin($pluginY)
            
            { $pluginManager.ValidateDependencies("PluginX") } | Should -Throw
        }
    }
    
    Context "Plugin Security" {
        It "Should sandbox plugin execution" {
            $eventPublisher = [EventPublisher]::new()
            $pluginManager = [PluginManager]::new($eventPublisher)
            
            # Plugin should not be able to access restricted operations
            $maliciousPlugin = [PSCustomObject]@{
                Name = "MaliciousPlugin"
                Initialize = { }
                Execute = {
                    # Attempt restricted operation
                    Remove-Item "C:\Windows\System32" -Recurse -Force
                }
            }
            
            $pluginManager.RegisterPlugin($maliciousPlugin)
            $pluginManager.InitializePlugin("MaliciousPlugin", @{})  # Initialize first
            
            # Should fail safely
            { $pluginManager.ExecutePlugin("MaliciousPlugin", "test", @()) } | Should -Not -Throw
        }
        
        It "Should validate plugin signatures" {
            $eventPublisher = [EventPublisher]::new()
            $pluginManager = [PluginManager]::new($eventPublisher, $true)  # Enable signature validation
            
            # Create unsigned plugin file
            $pluginFile = Join-Path $Global:TestConfigDir "unsigned-plugin.ps1"
            "# Unsigned plugin" | Set-Content $pluginFile
            
            { $pluginManager.LoadPlugin($pluginFile) } | Should -Throw
        }
    }
}

Describe "Keybinding Customization" {
    Context "Keybinding Management" {
        It "Should create keybinding manager instance" {
            $eventPublisher = [EventPublisher]::new()
            $keybindingManager = [KeybindingManager]::new($eventPublisher)
            
            $keybindingManager | Should -Not -BeNullOrEmpty
            $keybindingManager.GetType().Name | Should -Be "KeybindingManager"
        }
        
        It "Should load default keybindings" {
            $eventPublisher = [EventPublisher]::new()
            $keybindingManager = [KeybindingManager]::new($eventPublisher)
            
            # Should have default vim-like keybindings
            $keybindingManager.GetKeybinding("j") | Should -Be "cursor_down"
            $keybindingManager.GetKeybinding("k") | Should -Be "cursor_up"
            $keybindingManager.GetKeybinding("gg") | Should -Be "goto_top"
            $keybindingManager.GetKeybinding("G") | Should -Be "goto_bottom"
        }
        
        It "Should allow custom keybinding assignment" {
            $eventPublisher = [EventPublisher]::new()
            $keybindingManager = [KeybindingManager]::new($eventPublisher)
            
            # Assign custom keybinding
            $keybindingManager.SetKeybinding("Ctrl+n", "new_task")
            $keybindingManager.GetKeybinding("Ctrl+n") | Should -Be "new_task"
            
            # Override existing keybinding
            $keybindingManager.SetKeybinding("j", "custom_action")
            $keybindingManager.GetKeybinding("j") | Should -Be "custom_action"
        }
        
        It "Should support multi-key sequences" {
            $eventPublisher = [EventPublisher]::new()
            $keybindingManager = [KeybindingManager]::new($eventPublisher)
            
            # Set multi-key sequence
            $keybindingManager.SetKeybinding("leader-t", "toggle_mode")
            $keybindingManager.SetKeybinding("leader-q", "quit_app")
            
            $keybindingManager.GetKeybinding("leader-t") | Should -Be "toggle_mode"
            $keybindingManager.GetKeybinding("leader-q") | Should -Be "quit_app"
        }
        
        It "Should validate keybinding conflicts" {
            $eventPublisher = [EventPublisher]::new()
            $keybindingManager = [KeybindingManager]::new($eventPublisher)
            
            # Set initial keybinding
            $keybindingManager.SetKeybinding("Ctrl+s", "save_tasks")
            
            # Try to set conflicting keybinding
            $conflicts = $keybindingManager.CheckConflicts("Ctrl+s", "different_action")
            $conflicts.HasConflicts | Should -Be $true
            $conflicts.ConflictingAction | Should -Be "save_tasks"
        }
        
        It "Should export and import keybinding configurations" {
            $eventPublisher = [EventPublisher]::new()
            $keybindingManager = [KeybindingManager]::new($eventPublisher)
            
            # Set custom keybindings
            $keybindingManager.SetKeybinding("Ctrl+n", "new_task")
            $keybindingManager.SetKeybinding("Ctrl+d", "delete_task")
            
            # Export configuration
            $configFile = Join-Path $Global:TestConfigDir "keybindings.json"
            $keybindingManager.ExportConfiguration($configFile)
            
            Test-Path $configFile | Should -Be $true
            
            # Create new manager and import
            $keybindingManager2 = [KeybindingManager]::new($eventPublisher)
            $keybindingManager2.ImportConfiguration($configFile)
            
            $keybindingManager2.GetKeybinding("Ctrl+n") | Should -Be "new_task"
            $keybindingManager2.GetKeybinding("Ctrl+d") | Should -Be "delete_task"
        }
    }
    
    Context "Context-Sensitive Keybindings" {
        It "Should support mode-specific keybindings" {
            $eventPublisher = [EventPublisher]::new()
            $keybindingManager = [KeybindingManager]::new($eventPublisher)
            
            # Set keybindings for different modes
            $keybindingManager.SetKeybinding("Enter", "complete_task", "Normal")
            $keybindingManager.SetKeybinding("Enter", "execute_command", "Command")
            $keybindingManager.SetKeybinding("Enter", "confirm_search", "Search")
            
            $keybindingManager.GetKeybinding("Enter", "Normal") | Should -Be "complete_task"
            $keybindingManager.GetKeybinding("Enter", "Command") | Should -Be "execute_command"
            $keybindingManager.GetKeybinding("Enter", "Search") | Should -Be "confirm_search"
        }
        
        It "Should fall back to global keybindings" {
            $eventPublisher = [EventPublisher]::new()
            $keybindingManager = [KeybindingManager]::new($eventPublisher)
            
            # Set global keybinding for a key that doesn't have mode-specific overrides
            $keybindingManager.SetKeybinding("F1", "show_help")
            
            # Should work in any mode since it's not overridden
            $keybindingManager.GetKeybinding("F1", "Normal") | Should -Be "show_help"
            $keybindingManager.GetKeybinding("F1", "Command") | Should -Be "show_help"
            $keybindingManager.GetKeybinding("F1", "Search") | Should -Be "show_help"
        }
    }
}

Describe "Configuration Management" {
    Context "Advanced Configuration" {
        It "Should support configuration profiles" {
            $configProvider = [ConfigurationProvider]::new()
            
            # Create different profiles
            $configProvider.CreateProfile("work")
            $configProvider.CreateProfile("personal")
            
            $profiles = $configProvider.GetProfiles()
            $profiles | Should -Contain "work"
            $profiles | Should -Contain "personal"
        }
        
        It "Should switch between configuration profiles" {
            $configProvider = [ConfigurationProvider]::new()
            
            # Create profiles with different settings
            $configProvider.CreateProfile("work")
            $configProvider.SetProfileSetting("work", "taskwarrior.data_location", "~/.task-work")
            
            $configProvider.CreateProfile("personal")
            $configProvider.SetProfileSetting("personal", "taskwarrior.data_location", "~/.task-personal")
            
            # Switch to work profile
            $configProvider.SetActiveProfile("work")
            $config = $configProvider.GetConfiguration()
            $config.taskwarrior.data_location | Should -Be "~/.task-work"
            
            # Switch to personal profile
            $configProvider.SetActiveProfile("personal")
            $config = $configProvider.GetConfiguration()
            $config.taskwarrior.data_location | Should -Be "~/.task-personal"
        }
        
        It "Should validate configuration settings" {
            $configProvider = [ConfigurationProvider]::new()
            
            # Valid setting
            $result1 = $configProvider.ValidateSetting("ui.refresh_rate", 60)
            $result1.IsValid | Should -Be $true
            
            # Invalid setting (negative refresh rate)
            $result2 = $configProvider.ValidateSetting("ui.refresh_rate", -1)
            $result2.IsValid | Should -Be $false
            
            # Invalid setting (non-existent path)
            $result3 = $configProvider.ValidateSetting("taskwarrior.data_location", "/invalid/path/that/does/not/exist")
            $result3.IsValid | Should -Be $false
        }
        
        It "Should backup and restore configurations" {
            $configProvider = [ConfigurationProvider]::new()
            
            # Modify configuration
            $configProvider.SetSetting("ui.theme", "CustomTheme")
            $configProvider.SetSetting("performance.cache_size", 100)
            
            # Create backup
            $backupFile = Join-Path $Global:TestConfigDir "config-backup.json"
            $configProvider.BackupConfiguration($backupFile)
            
            Test-Path $backupFile | Should -Be $true
            
            # Modify configuration further
            $configProvider.SetSetting("ui.theme", "AnotherTheme")
            
            # Restore from backup
            $configProvider.RestoreConfiguration($backupFile)
            $config = $configProvider.GetConfiguration()
            
            $config.ui.theme | Should -Be "CustomTheme"
            $config.performance.cache_size | Should -Be 100
        }
    }
    
    Context "Configuration Migration" {
        It "Should migrate configuration between versions" {
            $configProvider = [ConfigurationProvider]::new()
            
            # Simulate old configuration format
            $oldConfig = @{
                version = "1.0"
                theme = "Dark"
                cache_size = 50
            }
            
            $oldConfigFile = Join-Path $Global:TestConfigDir "old-config.json"
            $oldConfig | ConvertTo-Json | Set-Content $oldConfigFile
            
            # Migrate to new format
            $configProvider.MigrateConfiguration($oldConfigFile, "2.0")
            $newConfig = $configProvider.GetConfiguration()
            
            # Should have migrated settings to new structure
            $newConfig.version | Should -Be "2.0"
            $newConfig.ui.theme | Should -Be "Dark"
            $newConfig.performance.cache_size | Should -Be 50
        }
    }
}

Describe "Performance Requirements" {
    Context "Advanced Feature Performance" {
        It "Should load themes quickly" {
            $eventPublisher = [EventPublisher]::new()
            $themeManager = [ThemeManager]::new($eventPublisher)
            
            $loadTime = Measure-Command {
                for ($i = 0; $i -lt 50; $i++) {
                    $themeManager.SetTheme("Default")
                    $themeManager.SetTheme("Dark")
                    $themeManager.SetTheme("Light")
                }
            }
            
            $loadTime.TotalMilliseconds | Should -BeLessThan 1000  # 150 theme switches in under 1 second
        }
        
        It "Should initialize plugins efficiently" {
            $eventPublisher = [EventPublisher]::new()
            $pluginManager = [PluginManager]::new($eventPublisher)
            
            # Create multiple mock plugins
            for ($i = 1; $i -le 10; $i++) {
                $plugin = [PSCustomObject]@{
                    Name = "Plugin$i"
                    Version = "1.0.0"
                    Initialize = { }
                    Execute = { }
                }
                $pluginManager.RegisterPlugin($plugin)
            }
            
            $initTime = Measure-Command {
                for ($i = 1; $i -le 10; $i++) {
                    $pluginManager.InitializePlugin("Plugin$i", @{})
                }
            }
            
            $initTime.TotalMilliseconds | Should -BeLessThan 500  # 10 plugins in under 500ms
        }
        
        It "Should resolve keybindings quickly" {
            $eventPublisher = [EventPublisher]::new()
            $keybindingManager = [KeybindingManager]::new($eventPublisher)
            
            # Set many keybindings
            for ($i = 0; $i -lt 100; $i++) {
                $keybindingManager.SetKeybinding("Ctrl+F$i", "action$i")
            }
            
            $resolveTime = Measure-Command {
                for ($i = 0; $i -lt 1000; $i++) {
                    $key = "Ctrl+F$(($i % 100))"
                    $null = $keybindingManager.GetKeybinding($key)
                }
            }
            
            $resolveTime.TotalMilliseconds | Should -BeLessThan 200  # 1000 resolutions in under 200ms
        }
    }
}