# PowerShell script to create a release zip file of ConsoleExperienceClassic addon
# Excludes development files and folders

param(
    [string]$OutputPath = ""
)

# Get the script directory and addon root
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$AddonRoot = Split-Path -Parent $ScriptDir
$AddonName = Split-Path -Leaf $AddonRoot

# Read version from version.txt or TOC file
$Version = "unknown"
if (Test-Path "$AddonRoot\version.txt") {
    $Version = (Get-Content "$AddonRoot\version.txt" -First 1).Trim()
} elseif (Test-Path "$AddonRoot\$AddonName.toc") {
    $TocContent = Get-Content "$AddonRoot\$AddonName.toc"
    $VersionLine = $TocContent | Select-String -Pattern "## Version:\s*(\S+)" | Select-Object -First 1
    if ($VersionLine) {
        $Version = $VersionLine.Matches.Groups[1].Value
    }
}

# Set output path
if ([string]::IsNullOrEmpty($OutputPath)) {
    $ParentDir = Split-Path -Parent $AddonRoot
    $OutputPath = Join-Path $ParentDir "$AddonName-v$Version.zip"
}

# Remove existing zip if it exists
if (Test-Path $OutputPath) {
    Write-Host "Removing existing zip file: $OutputPath" -ForegroundColor Yellow
    Remove-Item $OutputPath -Force
}

Write-Host "Creating release zip for $AddonName v$Version..." -ForegroundColor Green
Write-Host "Output: $OutputPath" -ForegroundColor Cyan

# Define exclusion patterns
$ExcludePatterns = @(
    "scripts\*",                    # Scripts folder
    "resources\*",                  # Resources folder
    ".github\*",                    # GitHub Actions folder
    ".git\*",                       # Git folder
    ".gitignore",                   # Git ignore file
    "release-please-*.json",        # Release-please config files
    "*.ps1",                        # PowerShell scripts (in root)
    "*.md",                         # Markdown files (README, CHANGELOG, etc.)
    "docs\*",                       # Documentation folder
    "version.txt"                    # Version file
)

# Create temporary directory for files to include
$TempDir = Join-Path $env:TEMP "addon-release-$(Get-Random)"
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
$TempAddonDir = Join-Path $TempDir $AddonName
New-Item -ItemType Directory -Path $TempAddonDir -Force | Out-Null

try {
    # Copy files, excluding specified patterns
    Get-ChildItem -Path $AddonRoot -Recurse -File | ForEach-Object {
        $RelativePath = $_.FullName.Substring($AddonRoot.Length + 1)
        $ShouldExclude = $false
        
        # Check if file is in excluded directories
        $PathParts = $RelativePath.Split([IO.Path]::DirectorySeparatorChar, [StringSplitOptions]::RemoveEmptyEntries)
        foreach ($Part in $PathParts) {
            if ($Part -eq "scripts" -or $Part -eq "resources" -or $Part -eq ".github" -or $Part -eq ".git" -or $Part -eq "docs") {
                $ShouldExclude = $true
                break
            }
        }
        
        # Check exclusion patterns
        if (-not $ShouldExclude) {
            foreach ($Pattern in $ExcludePatterns) {
                if ($RelativePath -like $Pattern) {
                    $ShouldExclude = $true
                    break
                }
            }
        }
        
        # Check for specific excluded files
        if (-not $ShouldExclude) {
            $FileName = Split-Path -Leaf $RelativePath
            if ($FileName -eq ".gitignore" -or $FileName -eq "version.txt" -or $FileName -like "release-please-*.json" -or $FileName -like "*.md") {
                $ShouldExclude = $true
            }
        }
        
        if (-not $ShouldExclude) {
            $DestPath = Join-Path $TempAddonDir $RelativePath
            $DestDir = Split-Path -Parent $DestPath
            
            if (-not (Test-Path $DestDir)) {
                New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
            }
            
            Copy-Item $_.FullName -Destination $DestPath -Force
        }
    }
    
    # Create zip file
    Write-Host "Compressing files..." -ForegroundColor Yellow
    Compress-Archive -Path "$TempAddonDir\*" -DestinationPath $OutputPath -Force
    
    # Get zip file size
    $ZipSize = (Get-Item $OutputPath).Length / 1MB
    Write-Host "`nRelease zip created successfully!" -ForegroundColor Green
    Write-Host "File: $OutputPath" -ForegroundColor Cyan
    Write-Host "Size: $([math]::Round($ZipSize, 2)) MB" -ForegroundColor Cyan
    
} finally {
    # Clean up temporary directory
    if (Test-Path $TempDir) {
        Remove-Item -Path $TempDir -Recurse -Force
    }
}
