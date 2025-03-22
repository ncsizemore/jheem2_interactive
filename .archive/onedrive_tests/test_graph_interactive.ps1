# PowerShell script to test OneDrive access and generate sharing links using interactive login
# This script uses the Microsoft Graph PowerShell modules

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

if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Sites)) {
    Write-Host "Installing Microsoft.Graph.Sites module..." -ForegroundColor Yellow
    Install-Module Microsoft.Graph.Sites -Scope CurrentUser -Force
}

# Configuration
$testFolderPath = "Documents/test" # Folder to test in your OneDrive
$testFileName = "test-file.txt" # A test file to create and share
$outputJsonPath = "./test_sharing_links.json"

# Connect to Microsoft Graph (interactive login using your credentials)
Write-Host "Please sign in with your Johns Hopkins account..." -ForegroundColor Green
Connect-MgGraph -Scopes "Files.ReadWrite.All", "Sites.ReadWrite.All"

# Get user information to confirm successful authentication
$user = Get-MgUser -UserId "me"
Write-Host "Successfully authenticated as: $($user.DisplayName) <$($user.UserPrincipalName)>" -ForegroundColor Green

# Create a test file if it doesn't exist
function Create-TestFile {
    try {
        Write-Host "Getting user's default drive..." -ForegroundColor Blue
        $drive = Get-MgDrive -UserId "me" | Select-Object -First 1
        
        # Check if the test folder exists, create if it doesn't
        Write-Host "Checking for test folder: $testFolderPath" -ForegroundColor Blue
        try {
            $folder = Get-MgDriveRootChild -DriveId $drive.Id -Path $testFolderPath -ErrorAction Stop
            Write-Host "Test folder exists." -ForegroundColor Green
        } catch {
            Write-Host "Creating test folder: $testFolderPath" -ForegroundColor Blue
            $folderParts = $testFolderPath -split "/"
            $currentPath = ""
            
            foreach ($part in $folderParts) {
                if ($currentPath -eq "") {
                    $currentPath = $part
                } else {
                    $currentPath = "$currentPath/$part"
                }
                
                try {
                    $folder = Get-MgDriveRootChild -DriveId $drive.Id -Path $currentPath -ErrorAction Stop
                } catch {
                    $parentRef = @{
                        path = if ($currentPath -eq $part) { "/" } else { "/" + ($currentPath -replace "$part$", "").TrimEnd("/") }
                    }
                    
                    $folder = New-MgDriveItem -DriveId $drive.Id -ParentReference $parentRef -Name $part -Folder @{}
                }
            }
            
            Write-Host "Test folder created." -ForegroundColor Green
        }
        
        # Check if the test file exists, create if it doesn't
        try {
            $filePath = "$testFolderPath/$testFileName"
            $file = Get-MgDriveRootChild -DriveId $drive.Id -Path $filePath -ErrorAction Stop
            Write-Host "Test file exists." -ForegroundColor Green
            return $file
        } catch {
            Write-Host "Creating test file: $filePath" -ForegroundColor Blue
            
            # Create temporary file
            $tempFile = [System.IO.Path]::GetTempFileName()
            Set-Content -Path $tempFile -Value "This is a test file for OneDrive sharing links testing."
            
            # Upload to OneDrive
            $file = New-MgDriveItemContent -DriveId $drive.Id -ParentPath "/$testFolderPath" -FileName $testFileName -FilePath $tempFile
            
            # Clean up temp file
            Remove-Item -Path $tempFile -Force
            
            Write-Host "Test file created." -ForegroundColor Green
            return $file
        }
    } catch {
        Write-Host "Error creating test file: $_" -ForegroundColor Red
        return $null
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

# Function to verify the sharing link works
function Test-SharingLink {
    param (
        [Parameter(Mandatory = $true)]
        [string]$SharingLink
    )
    
    try {
        Write-Host "Testing sharing link..." -ForegroundColor Blue
        
        # Use Invoke-WebRequest to download the file
        $tempFile = [System.IO.Path]::GetTempFileName()
        Invoke-WebRequest -Uri $SharingLink -OutFile $tempFile
        
        # Check if the file was downloaded successfully
        $fileSize = (Get-Item -Path $tempFile).Length
        
        if ($fileSize -gt 0) {
            $fileContent = Get-Content -Path $tempFile -Raw
            Write-Host "Successfully downloaded file with size: $fileSize bytes" -ForegroundColor Green
            Write-Host "File content: $fileContent" -ForegroundColor Gray
            
            # Clean up temp file
            Remove-Item -Path $tempFile -Force
            
            return $true
        } else {
            Write-Host "Downloaded file is empty!" -ForegroundColor Red
            
            # Clean up temp file
            Remove-Item -Path $tempFile -Force
            
            return $false
        }
    } catch {
        Write-Host "Error testing sharing link: $_" -ForegroundColor Red
        return $false
    }
}

# Main test procedure
function Test-OneDriveSharing {
    # Get user's drive
    $drive = Get-MgDrive -UserId "me" | Select-Object -First 1
    
    if (-not $drive) {
        Write-Host "Could not get user's OneDrive! Aborting." -ForegroundColor Red
        return
    }
    
    Write-Host "OneDrive ID: $($drive.Id)" -ForegroundColor Blue
    
    # Create a test file
    $testFile = Create-TestFile
    
    if (-not $testFile) {
        Write-Host "Failed to create or find test file. Aborting." -ForegroundColor Red
        return
    }
    
    # Create a sharing link
    $sharingLink = New-SharingLink -DriveId $drive.Id -ItemId $testFile.Id
    
    if (-not $sharingLink) {
        Write-Host "Failed to create sharing link. Aborting." -ForegroundColor Red
        return
    }
    
    # Test the sharing link
    $linkWorks = Test-SharingLink -SharingLink $sharingLink
    
    if ($linkWorks) {
        Write-Host "✅ SUCCESS: Sharing link works correctly!" -ForegroundColor Green
        
        # Create test JSON output
        $results = @{
            format_version = "1.0"
            generated_at = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            model_version = "test"
            simulations = @{
                "test_key" = @{
                    location = "test-location"
                    scenario = "test-scenario"
                    filename = "$testFolderPath/$testFileName"
                    sharing_link = $sharingLink
                }
            }
        }
        
        # Save to JSON file
        $jsonOutput = $results | ConvertTo-Json -Depth 10
        Set-Content -Path $outputJsonPath -Value $jsonOutput
        
        Write-Host "Test sharing link information saved to: $outputJsonPath" -ForegroundColor Yellow
    } else {
        Write-Host "❌ FAILURE: Sharing link does not work correctly!" -ForegroundColor Red
    }
}

# Run the test
try {
    Test-OneDriveSharing
} finally {
    # Disconnect when finished
    Disconnect-MgGraph
    Write-Host "Disconnected from Microsoft Graph." -ForegroundColor Blue
}
