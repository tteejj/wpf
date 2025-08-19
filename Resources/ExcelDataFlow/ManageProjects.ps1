# ManageProjects.ps1 - Simple project management for ExcelDataFlow

param(
    [switch]$List,                     # List all projects
    [switch]$Create,                   # Create new project
    [string]$Name = "",                # Project name for creation
    [switch]$Help                      # Show help
)

$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectPath = $PSScriptRoot

# Import required classes
. "$projectPath\Services\TextExportService.ps1"
. "$projectPath\Services\ConfigurationService.ps1"

function Show-Help {
    Write-Host "=== ExcelDataFlow Project Management ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  List all projects:" -ForegroundColor Gray
    Write-Host "    pwsh -File ManageProjects.ps1 -List" -ForegroundColor White
    Write-Host "  Create new project:" -ForegroundColor Gray
    Write-Host "    pwsh -File ManageProjects.ps1 -Create -Name 'My-New-Project-2025'" -ForegroundColor White
    Write-Host "  Interactive create:" -ForegroundColor Gray
    Write-Host "    pwsh -File ManageProjects.ps1 -Create" -ForegroundColor White
    Write-Host ""
}

function Show-Projects {
    $projectsDir = Join-Path $projectPath "Projects"
    
    if (-not (Test-Path $projectsDir)) {
        Write-Host "No projects directory found. Projects will be created automatically on first export." -ForegroundColor Yellow
        return
    }
    
    $projects = Get-ChildItem -Path $projectsDir -Directory
    
    if ($projects.Count -eq 0) {
        Write-Host "No projects found. Projects will be created automatically on first export." -ForegroundColor Yellow
        return
    }
    
    Write-Host "=== ExcelDataFlow Projects ===" -ForegroundColor Cyan
    Write-Host ""
    
    foreach ($project in $projects) {
        $exportCount = (Get-ChildItem -Path $project.FullName -Filter "ExcelDataExport_*" -File).Count
        $lastExport = Get-ChildItem -Path $project.FullName -Filter "ExcelDataExport_*" -File | 
                     Sort-Object LastWriteTime -Descending | 
                     Select-Object -First 1
        
        Write-Host "📁 $($project.Name)" -ForegroundColor Green
        Write-Host "   Exports: $exportCount" -ForegroundColor Gray
        if ($lastExport) {
            Write-Host "   Last export: $($lastExport.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
            Write-Host "   Latest file: $($lastExport.Name)" -ForegroundColor Gray
        }
        Write-Host ""
    }
}

function Create-Project {
    param([string]$projectName)
    
    if (-not $projectName) {
        do {
            Write-Host "Enter project name: " -NoNewline -ForegroundColor Yellow
            $projectName = Read-Host
            
            if ($projectName.Trim() -eq "") {
                Write-Host "Project name cannot be empty. Please try again." -ForegroundColor Red
            }
        } while ($projectName.Trim() -eq "")
    }
    
    # Clean the project name
    $cleanName = $projectName -replace '[^\w\-\s]', '' -replace '\s+', '-'
    if ($cleanName -ne $projectName) {
        Write-Host "Project name cleaned to: $cleanName" -ForegroundColor Gray
    }
    
    $projectsDir = Join-Path $projectPath "Projects"
    $newProjectDir = Join-Path $projectsDir $cleanName
    
    if (Test-Path $newProjectDir) {
        Write-Host "Project '$cleanName' already exists at: $newProjectDir" -ForegroundColor Yellow
        return
    }
    
    try {
        New-Item -ItemType Directory -Path $newProjectDir -Force | Out-Null
        Write-Host "✅ Created project: $cleanName" -ForegroundColor Green
        Write-Host "   Directory: $newProjectDir" -ForegroundColor Gray
        Write-Host ""
        Write-Host "To use this project:" -ForegroundColor Yellow
        Write-Host "  pwsh -File RunTextExport.ps1 -Format CSV -Project '$cleanName'" -ForegroundColor White
    } catch {
        Write-Host "❌ Failed to create project: $_" -ForegroundColor Red
    }
}

# Main execution
try {
    if ($Help) {
        Show-Help
    } elseif ($List) {
        Show-Projects
    } elseif ($Create) {
        Create-Project $Name
    } else {
        Show-Help
    }
} catch {
    Write-Host "❌ Error: $_" -ForegroundColor Red
    exit 1
}