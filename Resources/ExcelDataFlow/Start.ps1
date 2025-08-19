# Start.ps1 - ExcelDataFlow Standalone Application Entry Point
# Simple Excel data management application

# Clear screen and hide cursor for better UI
[Console]::Clear()
[Console]::CursorVisible = $false

# Set up error handling
$ErrorActionPreference = 'Stop'

try {
    # Load all required classes in dependency order
    Write-Host "Loading ExcelDataFlow..." -ForegroundColor Cyan
    
    # Core classes first
    . "$PSScriptRoot\Core\VT100.ps1"
    . "$PSScriptRoot\Core\Logger.ps1"
    . "$PSScriptRoot\Core\ServiceContainer.ps1"
    . "$PSScriptRoot\Core\StringCache.ps1"
    . "$PSScriptRoot\Core\BorderStyle.ps1"
    
    # Clear and initialize debug log
    [Logger]::Clear()
    
    # Base classes
    . "$PSScriptRoot\Base\UIElement.ps1"
    . "$PSScriptRoot\Base\Container.ps1"
    . "$PSScriptRoot\Base\Screen.ps1"
    
    # Layout components (needed by BaseDialog)
    . "$PSScriptRoot\Components\VerticalSplit.ps1"
    . "$PSScriptRoot\Components\HorizontalSplit.ps1"
    
    # UI Components  
    . "$PSScriptRoot\Components\MinimalButton.ps1"
    . "$PSScriptRoot\Components\MinimalTextBox.ps1"
    . "$PSScriptRoot\Components\SimpleListBox.ps1"
    . "$PSScriptRoot\Components\MinimalDataGrid.ps1"
    
    # SimpleDialog (TaskPro-based working version)
    . "$PSScriptRoot\Base\SimpleDialog.ps1"
    
    # Services
    . "$PSScriptRoot\Services\ConfigurationService.ps1"
    . "$PSScriptRoot\Services\ExcelService.ps1"
    
    # Load integrated workflow manager and required services
    . "$PSScriptRoot\Services\ExportProfileService.ps1"
    . "$PSScriptRoot\Services\TextExportService.ps1"
    . "$PSScriptRoot\Services\DataProcessingService.ps1"
    
    # Load workflow components - SimpleFileTree temporarily disabled
    # . "$PSScriptRoot\Components\SimpleFileTree.ps1"
    . "$PSScriptRoot\Screens\StartupSelectionDialog.ps1"
    . "$PSScriptRoot\Screens\ProfileSelectionDialog.ps1"
    . "$PSScriptRoot\Screens\PostConfigurationDialog.ps1"
    
    # Load wizard screens (needed by IntegratedWorkflowManager) - Temporarily disabled
    # . "$PSScriptRoot\Screens\Step1InputConfigDialog.ps1"
    # . "$PSScriptRoot\Screens\Step2SourceMappingDialog.ps1"
    # . "$PSScriptRoot\Screens\Step3DestMappingDialog.ps1"
    
    . "$PSScriptRoot\Screens\IntegratedWorkflowManager.ps1"
    
    # Create service container
    $global:ServiceContainer = [ServiceContainer]::new()
    
    # Register services
    $configPath = "$PSScriptRoot\_Config\settings.json"
    $configService = [ConfigurationService]::new($configPath)
    $global:ServiceContainer.RegisterInstance('ConfigurationService', $configService)
    
    # ThemeManager has complex dependencies, skip for basic workflow
    # $themeManager = [ThemeManager]::new()
    # $global:ServiceContainer.RegisterInstance('ThemeManager', $themeManager)
    
    $excelService = [ExcelService]::new()
    $global:ServiceContainer.RegisterInstance('ExcelService', $excelService)
    
    Write-Host "Services initialized successfully" -ForegroundColor Green
    
    # Create and start the integrated workflow manager
    $workflowManager = [IntegratedWorkflowManager]::new($global:ServiceContainer)
    $workflowManager.Start()
    
} catch {
    Write-Error "Failed to start ExcelDataFlow: $_"
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
} finally {
    # Cleanup Excel service
    if ($global:ServiceContainer) {
        $excelService = $global:ServiceContainer.GetService('ExcelService')
        if ($excelService) {
            $excelService.Cleanup()
        }
    }
    
    # Restore cursor and clear screen
    [Console]::CursorVisible = $true
    [Console]::Clear()
    Write-Host "ExcelDataFlow exited." -ForegroundColor Cyan
}