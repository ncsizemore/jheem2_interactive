# PowerShell script to test generating sharing links for existing files
# This is more focused on your actual use case with the 96 simulation files

# Install required modules if not already installed
# Comment these out if already installed
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
    Write-Host "Installing Microsoft.Graph.Authentication module..." -ForegroundColor Yellow
    Install-Module Microsoft.Graph.Authentication -Scope CurrentUser -Force
}

if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Files)) {
    Write-Host "Installing Microsoft.Graph.Files module..." -ForegroundColor Yellow
    Install-Module Microsoft.Graph.Files -Scope CurrentUser -Force
}

# Configuration
$outputJsonPath = "./onedrive_sharing_links.json"

# Only test 2 file paths for now
$filePaths = @(
    "prerun/C.12580/permanent_loss.Rdata", 
    "prerun/C.12580/current_efforts.Rdata"
)

# Function to find a file by path
function Find-OneDriveItem {
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    
    try {
        # Get the user's drive
        $drive = Get-MgDrive -UserId "me" | Select-Object -First 1
        
        # Get the file using its path
        # First, format the path correctly for the API (with leading slash)
        $formattedPath = "/" + $FilePath
        
        # Try to find the item using Get-MgDriveRootChild with path parameter
        $item = Get-MgDriveRootChild -DriveId $drive.Id -Path $formattedPath -ErrorAction Stop
        return $item
    }
    catch {
        Write-Host "Error finding file '$FilePath': $_" -ForegroundColor Red
        
        # Try a different approach - navigate the path components
        try {
            $drive = Get-MgDrive -UserId "me" | Select-Object -First 1
            $pathParts = $FilePath -split "/"
            $currentItem = Get-MgDriveRoot -DriveId $drive.Id
            
            foreach ($part in $pathParts) {
                if ([string]::IsNullOrEmpty($part)) { continue }
                
                # List children of current item
                $children = Get-MgDriveItemChild -DriveId $drive.Id -DriveItemId $currentItem.Id
                $nextItem = $children | Where-Object { $_.Name -eq $part } | Select-Object -First 1
                
                if (-not $nextItem) {
                    Write-Host "Could not find item: $part" -ForegroundColor Red
                    return $null
                }
                
                $currentItem = $nextItem
            }
            
            return $currentItem
        }
        catch {
            Write-Host "Error navigating path: $_" -ForegroundColor Red
            return $null
        }
    }
}

# Function to create sharing link
function New-SharingLink {
    param (
        [Parameter(Mandatory = $true)]
        [string]$DriveId,
        
        [Parameter(Mandatory = $true)]
        [string]$ItemId
    )
    
    try {
        Write-Host "Creating sharing link..." -ForegroundColor Blue
        
        $params = @{
            type = "view"
            scope = "anonymous"
        }
        
        $sharingLink = New-MgDriveItemPermissionLink -DriveId $DriveId -DriveItemId $ItemId -BodyParameter $params
        
        # Add &download=1 parameter to make it a direct download link
        $downloadLink = $sharingLink.Link.WebUrl + "&download=1"
        
        Write-Host "Sharing link created: $($sharingLink.Link.WebUrl)" -ForegroundColor Green
        Write-Host "Download link: $downloadLink" -ForegroundColor Green
        
        return $downloadLink
    } catch {
        Write-Host "Error creating sharing link: $_" -ForegroundColor Red
        return $null
    }
}

# Main function to test sharing links generation
function Test-SharingLinksGeneration {
    # Initialize results object
    $results = @{
        format_version = "1.0"
        generated_at = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        model_version = "ryan-white"
        simulations = @{}
    }
    
    # Connect to Microsoft Graph
    Write-Host "Please sign in with your Johns Hopkins account..." -ForegroundColor Green
    Connect-MgGraph -Scopes "Files.ReadWrite.All", "Sites.ReadWrite.All"
    
    # Get user information to confirm successful authentication
    $user = Get-MgUser -UserId "me"
    Write-Host "Successfully authenticated as: $($user.DisplayName) <$($user.UserPrincipalName)>" -ForegroundColor Green
    
    # Get user's drive
    $drive = Get-MgDrive -UserId "me" | Select-Object -First 1
    
    if (-not $drive) {
        Write-Host "Could not get user's OneDrive! Aborting." -ForegroundColor Red
        return
    }
    
    Write-Host "OneDrive ID: $($drive.Id)" -ForegroundColor Blue
    
    # Process each file path
    foreach ($filePath in $filePaths) {
        Write-Host "Processing: $filePath" -ForegroundColor Blue
        
        # Parse the file path to extract location and scenario
        $pathParts = $filePath -split "/"
        $location = $pathParts[1]
        $scenario = ($pathParts[2] -split "\.")[0]
        
        # Find the file
        $item = Find-OneDriveItem -FilePath $filePath
        
        if ($item) {
            Write-Host "Found file: $($item.Name), ID: $($item.Id)" -ForegroundColor Green
            
            # Create sharing link
            $sharingLink = New-SharingLink -DriveId $drive.Id -ItemId $item.Id
            
            if ($sharingLink) {
                # Add to results
                $key = "$location`_$scenario"
                $results.simulations[$key] = @{
                    location = $location
                    scenario = $scenario
                    filename = $filePath
                    sharing_link = $sharingLink
                }
                
                Write-Host "Successfully added sharing link for: $filePath" -ForegroundColor Green
            }
        } else {
            Write-Host "Could not find file: $filePath" -ForegroundColor Red
        }
    }
    
    # Save results to JSON file if we have any sharing links
    if ($results.simulations.Count -gt 0) {
        $jsonOutput = $results | ConvertTo-Json -Depth 10
        Set-Content -Path $outputJsonPath -Value $jsonOutput
        
        Write-Host "Sharing links saved to: $outputJsonPath" -ForegroundColor Green
        Write-Host "Total links generated: $($results.simulations.Count)" -ForegroundColor Yellow
    } else {
        Write-Host "No sharing links were generated!" -ForegroundColor Red
    }
    
    # Disconnect when finished
    Disconnect-MgGraph
    Write-Host "Disconnected from Microsoft Graph." -ForegroundColor Blue
}

# Run the test
Test-SharingLinksGeneration
