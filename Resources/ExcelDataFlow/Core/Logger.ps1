# Logger.ps1 - Simple file logging for ExcelDataFlow debugging

class Logger {
    static [string]$LogPath = "./debug.log"
    static [bool]$Enabled = $true
    
    static [void] Log([string]$message, [string]$level = "INFO") {
        if (-not [Logger]::Enabled) { return }
        
        try {
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
            $logEntry = "[$timestamp] [$level] $message"
            
            # Write to file
            $logEntry | Out-File -FilePath ([Logger]::LogPath) -Append -Encoding UTF8
            
            # Also write to console for immediate feedback
            switch ($level.ToUpper()) {
                "ERROR" { Write-Host $logEntry -ForegroundColor Red }
                "WARN" { Write-Host $logEntry -ForegroundColor Yellow }
                "INFO" { Write-Host $logEntry -ForegroundColor White }
                "DEBUG" { Write-Host $logEntry -ForegroundColor Gray }
                "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
                default { Write-Host $logEntry }
            }
        } catch {
            Write-Host "Logger failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    static [void] Error([string]$message) {
        [Logger]::Log($message, "ERROR")
    }
    
    static [void] Warn([string]$message) {
        [Logger]::Log($message, "WARN")
    }
    
    static [void] Info([string]$message) {
        [Logger]::Log($message, "INFO")
    }
    
    static [void] Debug([string]$message) {
        [Logger]::Log($message, "DEBUG")
    }
    
    static [void] Success([string]$message) {
        [Logger]::Log($message, "SUCCESS")
    }
    
    static [void] Clear() {
        try {
            if (Test-Path ([Logger]::LogPath)) {
                Remove-Item ([Logger]::LogPath) -Force
            }
            [Logger]::Log("=== ExcelDataFlow Debug Log Started ===", "INFO")
        } catch {
            Write-Host "Failed to clear log: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}