# ExcelMappingWizard.ps1 - 3-Step Wizard Controller for Excel Field Mapping

class ExcelMappingWizard {
    [int]$CurrentStep = 1
    [object]$CurrentScreen = $null
    [object]$ServiceContainer = $null
    
    # Data passed between steps
    [hashtable]$InputConfig = @{}
    [hashtable]$SourceMappings = @{}
    [hashtable]$DestMappings = @{}
    
    ExcelMappingWizard([object]$serviceContainer) {
        $this.ServiceContainer = $serviceContainer
    }
    
    [void] Start() {
        Write-Host "Starting Excel Field Mapping Wizard..." -ForegroundColor Cyan
        $this.ShowStep1()
    }
    
    [void] ShowStep1() {
        $this.CurrentStep = 1
        Write-Host "Loading Step 1: Input Configuration..." -ForegroundColor Yellow
        
        $this.CurrentScreen = [Step1InputConfigDialog]::new()
        $this.CurrentScreen.Initialize($this.ServiceContainer)
        
        # Set up navigation
        $wizard = $this
        $this.CurrentScreen.OnNext = {
            param($inputConfig)
            $wizard.InputConfig = $inputConfig
            $wizard.ShowStep2()
        }.GetNewClosure()
        
        $this.RunScreen()
    }
    
    [void] ShowStep2() {
        $this.CurrentStep = 2
        Write-Host "Loading Step 2: Source Field Mapping..." -ForegroundColor Yellow
        
        $this.CurrentScreen = [Step2SourceMappingDialog]::new($this.InputConfig)
        $this.CurrentScreen.Initialize($this.ServiceContainer)
        
        # Set up navigation
        $wizard = $this
        $this.CurrentScreen.OnNext = {
            param($inputConfig, $sourceMappings)
            $wizard.InputConfig = $inputConfig
            $wizard.SourceMappings = $sourceMappings
            $wizard.ShowStep3()
        }.GetNewClosure()
        
        $this.CurrentScreen.OnPrevious = {
            $wizard.ShowStep1()
        }.GetNewClosure()
        
        $this.RunScreen()
    }
    
    [void] ShowStep3() {
        $this.CurrentStep = 3
        Write-Host "Loading Step 3: Destination Field Mapping..." -ForegroundColor Yellow
        
        $this.CurrentScreen = [Step3DestMappingDialog]::new($this.InputConfig, $this.SourceMappings)
        $this.CurrentScreen.Initialize($this.ServiceContainer)
        
        # Set up navigation
        $wizard = $this
        $this.CurrentScreen.OnSave = {
            param($inputConfig, $sourceMappings, $destMappings)
            $wizard.InputConfig = $inputConfig
            $wizard.SourceMappings = $sourceMappings
            $wizard.DestMappings = $destMappings
            $wizard.Complete()
        }.GetNewClosure()
        
        $this.CurrentScreen.OnPrevious = {
            $wizard.ShowStep2()
        }.GetNewClosure()
        
        $this.RunScreen()
    }
    
    [void] RunScreen() {
        # Set screen bounds
        $this.CurrentScreen.SetBounds(0, 0, [Console]::WindowWidth, [Console]::WindowHeight)
        $this.CurrentScreen.OnActivated()
        
        # Simple render loop for the current screen
        $running = $true
        
        function Show-CurrentScreen {
            param($screen)
            $output = $screen.Render()
            [Console]::SetCursorPosition(0, 0)
            Write-Host $output -NoNewline
        }
        
        # Initial render
        Show-CurrentScreen $this.CurrentScreen
        
        Write-Host ""
        Write-Host "ExcelDataFlow Wizard - Step $($this.CurrentStep) of 3" -ForegroundColor Green
        Write-Host "Use Tab to navigate, Enter to edit, Arrow keys to move, F10 to exit" -ForegroundColor Yellow
        Write-Host ""
        
        # Input loop for current screen
        while ($running) {
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                
                # Global exit key
                if ($key.Key -eq [System.ConsoleKey]::F10) {
                    Write-Host "Exiting ExcelDataFlow Wizard..." -ForegroundColor Red
                    [Environment]::Exit(0)
                }
                
                # Route input to current screen
                $handled = $this.CurrentScreen.HandleInput($key)
                
                if ($handled) {
                    Show-CurrentScreen $this.CurrentScreen
                }
            }
            
            Start-Sleep -Milliseconds 50
        }
    }
    
    [void] Complete() {
        Write-Host ""
        Write-Host "🎉 Excel Field Mapping Wizard Complete!" -ForegroundColor Green
        Write-Host "Configuration saved with $($this.SourceMappings.Count) field mappings" -ForegroundColor Cyan
        Write-Host "Ready for Excel data operations" -ForegroundColor Cyan
    }
}