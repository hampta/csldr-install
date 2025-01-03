$asciiArt = @"


             __    __           _            __        ____
  __________/ /___/ /____      (_)___  _____/ /_______/ / /
 / ___/ ___/ / __  / ___/_____/ / __ \/ ___/ __/ __  `/ / / 
/ /__(__  ) / /_/ / /  /_____/ / / / (__  ) /_/ /_/ / / /  
\___/____/_/\__,_/_/        /_/_/ /_/____/\__/\__,_/_/_/   
                                                           
                                                  
"@

Write-Host $asciiArt

function Get-SteamCS {
    # Define the path to the Steam libraryfolders.vdf file
    $steamPath = "C:\Program Files (x86)\Steam\steamapps\libraryfolders.vdf"

    # Check if the file exists
    if (-Not (Test-Path -Path $steamPath)) {
        Write-Host "Error: The libraryfolders.vdf file was not found at $steamPath"
        return
    }

    # Read the content of the libraryfolders.vdf file
    $libraryContent = Get-Content -Path $steamPath

    # Initialize a variable to store the Counter-Strike installation path
    $csPath = $null

    # Iterate through each line in the libraryfolders.vdf file
    foreach ($line in $libraryContent) {
        # Check if the line contains a path to a Steam library
        if ($line -match '"path"\s+"(.+)"') {
            $libraryFolder = $matches[1]

            # Check if Counter-Strike is installed in this library folder
            $csFolder = Join-Path -Path $libraryFolder -ChildPath "steamapps\common\Half-Life\"
            if (Test-Path -Path $csFolder) {
                $csPath = $csFolder
                break
            }
        }
    }
    return $csPath
}

function Get-NonSteamCS {
    $csPath = Read-Host "Please enter the path to your Counter-Strike 1.6 installation directory"
    # Check if the path is valid
    if (-Not (Test-Path -Path $csPath)) {
        Write-Host "Error: The path $csPath does not exist"
        return
    }
    # Check if the path contains hl.exe and cstrike folder
    if (-Not (Test-Path -Path "$csPath\hl.exe") -or -Not (Test-Path -Path "$csPath\cstrike")) {
        Write-Host "Error: The path $csPath does not contain hl.exe or cstrike folder"
        return
    }

    return $csPath
}
function Prompt-ToOpenCSFolder {
    $openFolder = Read-Host "Open Counter-Strike installation directory? (Y/N)"
    if ($openFolder -eq "Y" -or $openFolder -eq "y") {
        Invoke-Item $csPath
    }
}
# Ask the user to choose between Steam and non-Steam installation
$installType = Read-Host "Install csldr for Steam CS? (Y/N)"

# Check the user's input and call the appropriate function
if ($installType -eq "Y" -or $installType -eq "y") {
    $csPath = Get-SteamCS
} else {
    $csPath = Get-NonSteamCS
}

Write-Host "Counter-Strike installation path: $csPath"

# set working directory to Counter-Strike installation path
Set-Location $csPath
$version_file = "./.csldr_version"

# if not exist, create the version file
if (-not (Test-Path $version_file)) {
    New-Item $version_file -ItemType File
    Set-Content $version_file ""
}

# Get the current version
$version = Get-Content $version_file

# Check if client.dll is Valve's original client.dll
$signature = Get-AuthenticodeSignature -FilePath "./cstrike/cl_dlls/client.dll"

# If the CN is Valve Corp., the client.dll is the original client.dll
if ($signature.Status -eq "Valid") {
    Write-Host "Original client.dll found, reinstallaing csldr..."
    $version = ""
}

# Download the latest release information
$latest = Invoke-WebRequest -Uri "https://api.github.com/repos/mikkokko/csldr/releases/latest" | ConvertFrom-Json
if ($latest.tag_name -eq $version) {
    Write-Host "Already up to date"
    Prompt-ToOpenCSFolder
    return
}

# Get the tag name and change log
$tag_name = $latest.tag_name
$change_log = $latest.body

Write-Host "Updating csldr.dll to version $tag_name"
Write-Host $change_log

# Get the download URL
$downloadURL = $latest.assets[0].browser_download_url

# Write the new version to the version file
Set-Content $version_file $latest.tag_name

# Download the latest release
Invoke-WebRequest -Uri $downloadURL -OutFile "./cstrike/cl_dlls/client_temp.dll"

# if client_orig.dll exists, replace it with client.dll
if (Test-Path "./cstrike/cl_dlls/client_orig.dll") {
    Remove-Item "./cstrike/cl_dlls/client.dll"
    Rename-Item "./cstrike/cl_dlls/client_temp.dll" "client.dll"
}
# if client_orig.dll does not exist, rename client.dll to client_orig.dll
else {
    Rename-Item "./cstrike/cl_dlls/client.dll" "client_orig.dll"
    Rename-Item "./cstrike/cl_dlls/client_temp.dll" "client.dll"
}

Prompt-ToOpenCSFolder
