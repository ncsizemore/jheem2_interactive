# PowerShell script to migrate simulation files from network drive to local project structure
# Renames files to match expected patterns for the JHEEM2 interactive application

# Check if running in dry run mode
param(
    [switch]$DryRun = $false
)

if ($DryRun) {
    Write-Host "Running in DRY RUN mode - no files will be copied" -ForegroundColor Yellow
    Write-Host "Use without the -DryRun parameter to perform actual file copying" -ForegroundColor Yellow
    Write-Host ""
}

# Configuration (adjust these values as needed)
$sourceRootPath = "Q:\simulations\rw-w\final.ehe-80"
$destinationRootPath = "$PSScriptRoot\..\..\simulations\ryan-white"

# Ensure destination directories exist
function EnsureDirectoryExists($path) {
    if (-not (Test-Path -Path $path)) {
        if ($DryRun) {
            Write-Host "Would create directory: $path" -ForegroundColor Cyan
        } else {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
            Write-Host "Created directory: $path" -ForegroundColor Green
        }
    }
}

# Initialize destination structure
EnsureDirectoryExists "$destinationRootPath\base"
EnsureDirectoryExists "$destinationRootPath\prerun"

# Mapping of original file suffix to new scenario name
$scenarioMapping = @{
    "noint"     = "base";  # Base scenario for custom page
    "rw.b.intr" = "brief_interruption";  # Brief interruption scenario
    "rw.end"    = "cessation";  # Cessation scenario
    "rw.p.intr" = "prolonged_interruption";  # Prolonged interruption scenario
}

# Get all location folders
try {
    $locationFolders = Get-ChildItem -Path $sourceRootPath -Directory -ErrorAction Stop
    Write-Host "Found $(($locationFolders | Measure-Object).Count) location folders in source directory" -ForegroundColor Cyan
} 
catch {
    Write-Host "Error accessing source path: $sourceRootPath" -ForegroundColor Red
    Write-Host "Error details: $_" -ForegroundColor Red
    exit 1
}

# Initialize counters for reporting
$totalFiles = 0
$copiedFiles = 0
$errorFiles = 0
$locationCount = 0

# Process each location folder
foreach ($locationFolder in $locationFolders) {
    $locationName = $locationFolder.Name
    $locationCount++
    
    Write-Host "`nProcessing location ($locationCount/$($locationFolders.Count)): $locationName" -ForegroundColor Yellow
    
    # Ensure prerun directory exists for this location
    EnsureDirectoryExists "$destinationRootPath\prerun\$locationName"
    
    # Get all simulation files for this location
    $simulationFiles = Get-ChildItem -Path $locationFolder.FullName -Filter "*.Rdata"
    
    Write-Host "  Found $($simulationFiles.Count) simulation files" -ForegroundColor White
    
    # Process each simulation file
    foreach ($file in $simulationFiles) {
        $totalFiles++
        
        # Extract the scenario type from filename
        $scenarioType = $null
        
        foreach ($suffix in $scenarioMapping.Keys) {
            if ($file.Name -match "_$suffix\.Rdata$") {
                $scenarioType = $suffix
                break
            }
        }
        
        if ($null -eq $scenarioType) {
            Write-Host "  Unable to determine scenario type for file: $($file.Name)" -ForegroundColor Red
            $errorFiles++
            continue
        }
        
        # Get the mapped scenario name
        $scenarioName = $scenarioMapping[$scenarioType]
        
        # Determine destination path based on scenario
        $destinationPath = ""
        if ($scenarioName -eq "base") {
            # Base scenario goes to base folder with _base suffix
            $destinationPath = "$destinationRootPath\base\${locationName}_base.Rdata"
        } else {
            # Pre-run scenarios go to prerun/location folders
            $destinationPath = "$destinationRootPath\prerun\$locationName\$scenarioName.Rdata"
        }
        
        if ($DryRun) {
            # In dry run mode, just show what would be copied
            Write-Host "  Would copy: $($file.Name) -> $destinationPath" -ForegroundColor Cyan
            $copiedFiles++
        } else {
            try {
                # Copy file to destination with new name
                Copy-Item -Path $file.FullName -Destination $destinationPath -Force -ErrorAction Stop
                Write-Host "  Copied: $($file.Name) -> $destinationPath" -ForegroundColor Green
                $copiedFiles++
            } 
            catch {
                Write-Host "  Error copying file $($file.Name): $_" -ForegroundColor Red
                $errorFiles++
            }
        }
    }
}

# Summary
Write-Host "`n==================== SUMMARY ====================" -ForegroundColor Cyan
Write-Host "Total locations processed: $locationCount" -ForegroundColor White
Write-Host "Total files processed: $totalFiles" -ForegroundColor White
if ($DryRun) {
    Write-Host "Files that would be copied: $copiedFiles" -ForegroundColor Cyan
} else {
    Write-Host "Successfully copied files: $copiedFiles" -ForegroundColor Green
}
if ($errorFiles -gt 0) {
    Write-Host "Files with errors: $errorFiles" -ForegroundColor Red
}
Write-Host "=================================================" -ForegroundColor Cyan

# Next steps
Write-Host "`nNext steps:" -ForegroundColor Yellow
if ($DryRun) {
    Write-Host "1. Run the script without the -DryRun parameter to perform the actual file copying:" -ForegroundColor White
    Write-Host "   .\migration_script.ps1" -ForegroundColor DarkGray
} else {
    Write-Host "1. Review the copied files to ensure they're correct" -ForegroundColor White
}
Write-Host "2. Update the prerun.yaml configuration to match your scenarios" -ForegroundColor White
Write-Host "3. Run the OneDrive upload script to generate sharing links:" -ForegroundColor White
Write-Host "   cd src/data/providers/onedrive_resources" -ForegroundColor DarkGray
Write-Host "   python generate_sharing_links.py --base-dir simulations/ryan-white --onedrive-dir jheem/ryan-white --model-version ryan-white" -ForegroundColor DarkGray
Write-Host ""
