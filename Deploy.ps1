# Deploy.ps1 - Zip, Base64 encode/decode deployment utility
# Usage: 
#   Encode: .\Deploy.ps1 Encode
#   Decode: .\Deploy.ps1 Decode

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("Encode", "Decode")]
    [string]$Mode
)

function Encode-Deployment {
    Write-Host "Encoding deployment..." -ForegroundColor Green
    
    $SourcePath = ".\bin\Release\net8.0-windows\win-x64\publish"
    $OutputFile = "deployment.txt"
    
    if (!(Test-Path $SourcePath)) {
        Write-Error "Publish folder not found: $SourcePath"
        Write-Host "Run: dotnet publish -c Release -r win-x64 --self-contained false" -ForegroundColor Yellow
        exit 1
    }
    
    # Create temp zip file
    $tempZip = [System.IO.Path]::GetTempFileName() + ".zip"
    
    try {
        # Compress folder to zip
        Write-Host "Compressing $SourcePath to zip..."
        Compress-Archive -Path "$SourcePath\*" -DestinationPath $tempZip -Force
        
        # Read zip as bytes
        $bytes = [System.IO.File]::ReadAllBytes($tempZip)
        Write-Host "Zip size: $($bytes.Length) bytes"
        
        # Convert to Base64
        $base64 = [Convert]::ToBase64String($bytes)
        
        # Write to text file
        $base64 | Out-File -FilePath $OutputFile -Encoding UTF8
        
        Write-Host "Encoded deployment saved to: $OutputFile" -ForegroundColor Green
        Write-Host "Base64 length: $($base64.Length) characters"
    }
    finally {
        # Clean up temp zip
        if (Test-Path $tempZip) {
            Remove-Item $tempZip
        }
    }
}

function Decode-Deployment {
    Write-Host "Decoding deployment..." -ForegroundColor Green
    
    $InputFile = "deployment.txt"
    $OutputPath = "PraxisWpf"
    
    if (!(Test-Path $InputFile)) {
        Write-Error "Deployment file not found: $InputFile"
        exit 1
    }
    
    # Read Base64 from file
    $base64 = Get-Content -Path $InputFile -Raw
    Write-Host "Base64 length: $($base64.Length) characters"
    
    # Convert from Base64 to bytes
    $bytes = [Convert]::FromBase64String($base64.Trim())
    Write-Host "Decoded size: $($bytes.Length) bytes"
    
    # Create temp zip file
    $tempZip = [System.IO.Path]::GetTempFileName() + ".zip"
    
    try {
        # Write bytes to zip file
        [System.IO.File]::WriteAllBytes($tempZip, $bytes)
        
        # Create output directory if it doesn't exist
        if (!(Test-Path $OutputPath)) {
            New-Item -ItemType Directory -Path $OutputPath -Force
        }
        
        # Extract zip to output path
        Write-Host "Extracting to $OutputPath..."
        Expand-Archive -Path $tempZip -DestinationPath $OutputPath -Force
        
        Write-Host "Deployment extracted to: $OutputPath" -ForegroundColor Green
        Write-Host "Files extracted:" -ForegroundColor Yellow
        Get-ChildItem -Path $OutputPath | ForEach-Object { Write-Host "  $_" }
        Write-Host ""
        Write-Host "Run the app: .\$OutputPath\PraxisWpf.exe" -ForegroundColor Cyan
    }
    finally {
        # Clean up temp zip
        if (Test-Path $tempZip) {
            Remove-Item $tempZip
        }
    }
}

# Main execution
switch ($Mode) {
    "Encode" {
        Encode-Deployment
    }
    
    "Decode" {
        Decode-Deployment
    }
}