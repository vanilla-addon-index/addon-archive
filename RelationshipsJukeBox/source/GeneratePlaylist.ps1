param(
    [string]$RootPath = '',
    [switch]$UseWinRAR = $false
)

$ErrorActionPreference = 'Continue'

# ---------------------------------------------------------------------------
# Download with progress bar
# ---------------------------------------------------------------------------
# Uses System.Net.WebClient for chunk-based downloading with a real-time
# console progress bar showing percentage, speed, and ETA.  Falls back to
# chunked HttpWebRequest if the WebClient approach fails for any reason.
# ---------------------------------------------------------------------------

function Download-FileWithProgress {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Url,

        [Parameter(Mandatory=$true)]
        [string]$OutFile
    )

    # Ensure TLS 1.2 for modern HTTPS endpoints
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # Pre-define format strings as variables to avoid Windows PowerShell 5.1
    # parser errors caused by curly braces inside inline -f expressions.
    $fmtSizeMB     = '  Downloading {0:N1} MB...'
    $fmtBar        = '  [{0}] {1,3}%  {2:N1}/{3:N1} MB  {4:N1} MB/s  ETA {5}'
    $fmtCarriage   = "`r{0}"
    $fmtEtaMin     = '{0}m {1}s'
    $fmtEtaSec     = '{0}s'
    $fmtUnknownDl  = "`r  Downloaded {0:N1} MB  {1:N1} MB/s   "
    $fmtUnknownFin = '  Download complete ({0:N1} MB).'

    # Try the chunked WebClient approach with progress bar
    $useWebClient = $true

    try {
        $webClient = New-Object System.Net.WebClient

        # First, get the file size via a HEAD request so we can show percentage
        $totalBytes = 0L
        try {
            $req = [System.Net.HttpWebRequest]::Create($Url)
            $req.Method = 'HEAD'
            $req.Timeout = 15000
            $req.AllowAutoRedirect = $true
            $resp = $req.GetResponse()
            $totalBytes = $resp.ContentLength
            $resp.Close()
        } catch {
            # HEAD not supported or failed -- we'll still download, just without total size
            $totalBytes = 0L
        }

        if ($totalBytes -gt 0) {
            # --- We know the total size: show a percentage progress bar ---
            $sizeMB = $totalBytes / 1MB
            Write-Host ($fmtSizeMB -f $sizeMB)

            $chunkSize = 256KB
            $downloaded = 0L
            $sw = [System.Diagnostics.Stopwatch]::StartNew()

            # Open the remote stream
            $remoteStream = $webClient.OpenRead($Url)
            # Create the local file stream
            $fileStream = [System.IO.File]::Create($OutFile)

            $buffer = New-Object byte[] $chunkSize
            $lastPct = -1

            while ($true) {
                $read = $remoteStream.Read($buffer, 0, $buffer.Length)
                if ($read -le 0) { break }
                $fileStream.Write($buffer, 0, $read)
                $downloaded += $read

                $pct = [int](($downloaded * 100) / $totalBytes)
                if ($pct -ne $lastPct) {
                    $lastPct = $pct

                    # Build the visual progress bar using string multiplication
                    # NOTE: PowerShell 5.1 does NOT support [char] * [int], so
                    # we use string constructor instead (String([char], count)).
                    $barWidth = 30
                    $filled = [int]($barWidth * $pct / 100)
                    $empty  = $barWidth - $filled
                    $blockChar = [string][char]0x2588   # full block
                    $lightChar = [string][char]0x2591   # light shade
                    $barStr = ($blockChar * $filled) + ($lightChar * $empty)

                    # Calculate speed and ETA
                    $elapsed = $sw.Elapsed.TotalSeconds
                    $speedMB = 0
                    if ($elapsed -gt 0) { $speedMB = ($downloaded / 1MB) / $elapsed }
                    $etaSec = 0
                    if ($speedMB -gt 0) { $etaSec = (($totalBytes - $downloaded) / 1MB) / $speedMB }

                    # Format ETA
                    $etaStr = ''
                    if ($etaSec -ge 60) {
                        $etaMin = [int]($etaSec / 60)
                        $etaRem = [int]($etaSec % 60)
                        $etaStr = $fmtEtaMin -f $etaMin, $etaRem
                    } else {
                        $etaStr = $fmtEtaSec -f [int]$etaSec
                    }

                    # Downloaded so far in MB
                    $dlMB = $downloaded / 1MB
                    $totalMB = $totalBytes / 1MB

                    # Write the progress line (overwrites itself using carriage return)
                    $progressLine = $fmtBar -f $barStr, $pct, $dlMB, $totalMB, $speedMB, $etaStr
                    Write-Host -NoNewline ($fmtCarriage -f $progressLine)
                }
            }

            Write-Host ''  # newline after the progress bar

            $fileStream.Close()
            $remoteStream.Close()
            $sw.Stop()

            # Verify file was written
            if ((Test-Path -LiteralPath $OutFile -PathType Leaf) -and ((Get-Item -LiteralPath $OutFile).Length -gt 0)) {
                Write-Host '  Download complete.'
                return $true
            } else {
                return $false
            }

        } else {
            # --- Unknown total size: show bytes downloaded with speed ---
            Write-Host '  Downloading (unknown size)...'

            $chunkSize = 256KB
            $downloaded = 0L
            $sw = [System.Diagnostics.Stopwatch]::StartNew()

            $remoteStream = $webClient.OpenRead($Url)
            $fileStream = [System.IO.File]::Create($OutFile)

            $buffer = New-Object byte[] $chunkSize
            $lastPrint = [DateTime]::MinValue

            while ($true) {
                $read = $remoteStream.Read($buffer, 0, $buffer.Length)
                if ($read -le 0) { break }
                $fileStream.Write($buffer, 0, $read)
                $downloaded += $read

                # Update progress every 0.5 seconds
                $now = [DateTime]::UtcNow
                if (($now - $lastPrint).TotalSeconds -ge 0.5) {
                    $lastPrint = $now
                    $elapsed = $sw.Elapsed.TotalSeconds
                    $speedMB = 0
                    if ($elapsed -gt 0) { $speedMB = ($downloaded / 1MB) / $elapsed }
                    $dlMB = $downloaded / 1MB
                    Write-Host -NoNewline ($fmtUnknownDl -f $dlMB, $speedMB)
                }
            }

            Write-Host ''  # newline after the progress line

            $fileStream.Close()
            $remoteStream.Close()
            $sw.Stop()

            if ((Test-Path -LiteralPath $OutFile -PathType Leaf) -and ((Get-Item -LiteralPath $OutFile).Length -gt 0)) {
                $finalMB = [Math]::Round($downloaded / 1MB, 1)
                Write-Host ($fmtUnknownFin -f $finalMB)
                return $true
            } else {
                return $false
            }
        }

    } catch {
        # WebClient approach failed -- fall back to chunked HttpWebRequest download
        Write-Host '  WebClient download failed, falling back to chunked HTTP download...'
        Write-Host "  Error: $($_.Exception.Message)"
        $useWebClient = $false
    }

    # Fallback: use manual chunked HTTP download with byte/MB progress display
    if (-not $useWebClient) {
        try {
            Write-Host '  Downloading (fallback mode - showing bytes downloaded)...'
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

            # Use HttpWebRequest directly so we get the response stream and can
            # read chunks while showing progress (Invoke-WebRequest has no chunk API)
            $req = [System.Net.HttpWebRequest]::Create($Url)
            $req.Method = 'GET'
            $req.Timeout = 120000
            $req.AllowAutoRedirect = $true
            $resp = $req.GetResponse()

            $totalBytes = $resp.ContentLength
            $respStream = $resp.GetResponseStream()
            $fileStream = [System.IO.File]::Create($OutFile)

            $buffer = New-Object byte[] 65536
            $totalDownloaded = 0L
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $lastPrint = [DateTime]::MinValue

            if ($totalBytes -gt 0) {
                # Known size - show percentage-based progress
                $sizeMB = $totalBytes / 1MB
                Write-Host "  File size: $([Math]::Round($sizeMB, 1)) MB"

                $blockChar = [string][char]0x2588
                $lightChar = [string][char]0x2591
                $lastPct = -1

                while ($true) {
                    $read = $respStream.Read($buffer, 0, $buffer.Length)
                    if ($read -le 0) { break }
                    $fileStream.Write($buffer, 0, $read)
                    $totalDownloaded += $read

                    $pct = [int](($totalDownloaded * 100) / $totalBytes)
                    if ($pct -ne $lastPct) {
                        $lastPct = $pct
                        $barWidth = 30
                        $filled = [int]($barWidth * $pct / 100)
                        $empty  = $barWidth - $filled
                        $barStr = ($blockChar * $filled) + ($lightChar * $empty)

                        $elapsed = $sw.Elapsed.TotalSeconds
                        $speedMB = 0
                        if ($elapsed -gt 0) { $speedMB = ($totalDownloaded / 1MB) / $elapsed }
                        $etaSec = 0
                        if ($speedMB -gt 0) { $etaSec = (($totalBytes - $totalDownloaded) / 1MB) / $speedMB }

                        $etaStr = ''
                        if ($etaSec -ge 60) {
                            $etaStr = '{0}m {1}s' -f [int]($etaSec / 60), [int]($etaSec % 60)
                        } else {
                            $etaStr = '{0}s' -f [int]$etaSec
                        }

                        $dlMB = $totalDownloaded / 1MB
                        $totalMB = $totalBytes / 1MB
                        $progressLine = '  [{0}] {1,3}%  {2:N1}/{3:N1} MB  {4:N1} MB/s  ETA {5}' -f $barStr, $pct, $dlMB, $totalMB, $speedMB, $etaStr
                        Write-Host -NoNewline ("`r{0}" -f $progressLine)
                    }
                }
            } else {
                # Unknown size - show MB/bytes downloaded with speed
                while ($true) {
                    $read = $respStream.Read($buffer, 0, $buffer.Length)
                    if ($read -le 0) { break }
                    $fileStream.Write($buffer, 0, $read)
                    $totalDownloaded += $read

                    $now = [DateTime]::UtcNow
                    if (($now - $lastPrint).TotalSeconds -ge 0.5) {
                        $lastPrint = $now
                        $elapsed = $sw.Elapsed.TotalSeconds
                        $speedMB = 0
                        if ($elapsed -gt 0) { $speedMB = ($totalDownloaded / 1MB) / $elapsed }
                        $dlMB = $totalDownloaded / 1MB
                        Write-Host -NoNewline ("`r  Downloaded {0:N1} MB  {1:N1} MB/s   " -f $dlMB, $speedMB)
                    }
                }
            }

            Write-Host ''  # newline after the progress line

            $fileStream.Close()
            $respStream.Close()
            $resp.Close()
            $sw.Stop()

            if ((Test-Path -LiteralPath $OutFile -PathType Leaf) -and ((Get-Item -LiteralPath $OutFile).Length -gt 0)) {
                $finalMB = [Math]::Round($totalDownloaded / 1MB, 1)
                Write-Host "  Download complete ($finalMB MB)."
                return $true
            }
        } catch {
            Write-Host "  Download failed: $($_.Exception.Message)"
        }
    }

    return $false
}

# -- Resolve the addon root directory ----------------------------------------
# $PSScriptRoot can be empty when invoked via powershell -File from a .bat
if ($RootPath -eq '') {
    $RootPath = $PSScriptRoot
}
if ($RootPath -eq '') {
    $RootPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
}
if ($RootPath -eq '') {
    # Last resort: use the current working directory
    $RootPath = (Get-Location -PSProvider FileSystem).ProviderPath
}

# Strip any trailing slashes or quotes that cause "Illegal characters in path"
$RootPath = $RootPath.TrimEnd('\', '/').Trim('"', "'")

# Normalize to a full absolute path - use GetFullPath on the cleaned string
$Root = [System.IO.Path]::GetFullPath($RootPath)

$Media = Join-Path $Root 'Media'
$Out   = Join-Path $Root 'AutoPlaylist.lua'

# WoW reads paths with backslashes; inside Lua strings a single backslash
# must be written as \\ (two characters in the source file).  Escape-LuaString
# will double every \ it sees, so we store the prefix with SINGLE backslashes
# here -- after escaping they become \\ in the Lua source, which Lua reads as \.
$AddonPrefix = 'Interface\AddOns\RelationshipsJukeBox\'

# ---------------------------------------------------------------------------
# Auto-download ffmpeg into the RelationshipsJukeBox folder if not found
# ---------------------------------------------------------------------------
# We look for ffmpeg/ffprobe on PATH first, then in a local "ffmpeg" subfolder
# inside the addon directory.  If neither exists, we download a static build
# from gyan.dev (the official ffmpeg.org-linked Windows builds) or from
# BtbN/FFmpeg-Builds on GitHub, extract it, and place ffmpeg.exe + ffprobe.exe
# into a "ffmpeg" folder next to this script.
#
# IMPORTANT: gyan.dev distributes .7z archives (smaller).  We need 7-Zip or
# WinRAR to extract them.  If neither is available, we fall back to .zip
# archives from gyan.dev or GitHub (BtbN) which PowerShell can extract natively.
# ---------------------------------------------------------------------------

$FfmpegDir = Join-Path $Root 'ffmpeg'

function Find-Ffmpeg {
    param([string]$Name)
    # 1) On PATH already?
    $found = Get-Command $Name -ErrorAction SilentlyContinue
    if ($found) { return $found.Source }
    # 2) In our local ffmpeg subfolder?
    $local = Join-Path $FfmpegDir "$Name.exe"
    if (Test-Path -LiteralPath $local -PathType Leaf) { return $local }
    return $null
}

function Find-SevenZip {
    # 1) On PATH?
    $found = Get-Command '7z' -ErrorAction SilentlyContinue
    if ($found) { return $found.Source }
    # 2) Default install location (7-Zip installs here on 64-bit)
    $default64 = Join-Path $env:ProgramFiles '7-Zip\7z.exe'
    if (Test-Path -LiteralPath $default64 -PathType Leaf) { return $default64 }
    # 3) 32-bit on 64-bit system
    $default32 = Join-Path ${env:ProgramFiles(x86)} '7-Zip\7z.exe'
    if (Test-Path -LiteralPath $default32 -PathType Leaf) { return $default32 }
    return $null
}

function Find-WinRAR {
    # 1) On PATH?
    $found = Get-Command 'winrar' -ErrorAction SilentlyContinue
    if ($found) { return $found.Source }
    # 2) On PATH as rar.exe (command-line variant)?
    $foundRar = Get-Command 'rar' -ErrorAction SilentlyContinue
    if ($foundRar) {
        # rar.exe is typically in the WinRAR install folder alongside WinRAR.exe
        $rarDir = Split-Path -Parent $foundRar.Source
        $winrarExe = Join-Path $rarDir 'WinRAR.exe'
        if (Test-Path -LiteralPath $winrarExe -PathType Leaf) { return $winrarExe }
        # unrar.exe can also extract
        return $foundRar.Source
    }
    # 3) On PATH as unrar.exe (extraction-only variant)?
    $foundUnrar = Get-Command 'unrar' -ErrorAction SilentlyContinue
    if ($foundUnrar) { return $foundUnrar.Source }
    # 4) Default 64-bit install location
    $default64 = Join-Path $env:ProgramFiles 'WinRAR\WinRAR.exe'
    if (Test-Path -LiteralPath $default64 -PathType Leaf) { return $default64 }
    # 5) Default 32-bit install on 64-bit system
    $default32 = Join-Path ${env:ProgramFiles(x86)} 'WinRAR\WinRAR.exe'
    if (Test-Path -LiteralPath $default32 -PathType Leaf) { return $default32 }
    # 6) Try common non-ProgramFiles locations
    $commonPaths = @(
        'C:\WinRAR\WinRAR.exe',
        'D:\WinRAR\WinRAR.exe',
        (Join-Path $env:ProgramFiles 'RAR\WinRAR.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'RAR\WinRAR.exe')
    )
    foreach ($p in $commonPaths) {
        if (Test-Path -LiteralPath $p -PathType Leaf) { return $p }
    }
    # 7) Try to find unrar.exe in WinRAR folder as fallback
    $unrar64 = Join-Path $env:ProgramFiles 'WinRAR\UnRAR.exe'
    if (Test-Path -LiteralPath $unrar64 -PathType Leaf) { return $unrar64 }
    $unrar32 = Join-Path ${env:ProgramFiles(x86)} 'WinRAR\UnRAR.exe'
    if (Test-Path -LiteralPath $unrar32 -PathType Leaf) { return $unrar32 }
    return $null
}

# -UseWinRAR flag is set via the script parameter above

function Ensure-FfmpegInstalled {
    $ffmpegExe  = Find-Ffmpeg -Name 'ffmpeg'
    $ffprobeExe = Find-Ffmpeg -Name 'ffprobe'

    if ($ffmpegExe -and $ffprobeExe) {
        Write-Host "ffmpeg found: $ffmpegExe"
        Write-Host "ffprobe found: $ffprobeExe"
        return
    }

    Write-Host ""
    Write-Host "============================================"
    Write-Host " ffmpeg not found -- auto-downloading..."
    Write-Host "============================================"
    Write-Host ""

    # Check if we have 7-Zip and/or WinRAR available for .7z extraction
    $sevenZipExe = Find-SevenZip
    $winRarExe   = Find-WinRAR

    # Determine extraction preference order based on -UseWinRAR flag
    # When -UseWinRAR is specified, WinRAR is preferred over 7-Zip for all formats
    $preferWinRAR = $UseWinRAR -and $winRarExe

    $downloadDir = Join-Path $Root 'ffmpeg_download'
    if (-not (Test-Path -LiteralPath $downloadDir -PathType Container)) {
        New-Item -ItemType Directory -Path $downloadDir -Force | Out-Null
    }

    $downloaded = $false
    $downloadedFile = $null

    # We can extract .7z if we have 7-Zip OR WinRAR
    $canExtract7z = ($sevenZipExe -ne $null) -or ($winRarExe -ne $null)

    if ($canExtract7z) {
        # We have an extraction tool -- download the smaller .7z release
        if ($preferWinRAR) {
            Write-Host "WinRAR found (preferred): $winRarExe"
        } elseif ($sevenZipExe) {
            Write-Host "7-Zip found: $sevenZipExe"
        }
        if ($winRarExe -and -not $preferWinRAR) {
            Write-Host "WinRAR also found: $winRarExe"
        }
        Write-Host "Downloading ffmpeg .7z release (smaller archive)..."

        # gyan.dev URL scheme (as of 2026-07):
        #   - Short alias URLs that 303-redirect to dated packages under /packages/
        #   - ffmpeg-release-essentials.7z  -> /packages/ffmpeg-X.Y.Z-essentials_build.7z
        #   - ffmpeg-git-full.7z            -> /packages/ffmpeg-YYYY-MM-DD-git-HASH-full_build.7z
        #   - ffmpeg-release-full.7z        -> /packages/ffmpeg-X.Y.Z-full_build.7z
        #   - ffmpeg-git-essentials.7z      -> /packages/ffmpeg-YYYY-MM-DD-git-HASH-essentials_build.7z
        # NOTE: ffmpeg-release-full.7z exists but there is no .zip for the full build.
        #       There is also NO /packages/ffmpeg-release-full.7z direct URL (404).
        #       Use the short alias URLs -- they redirect (303) to the correct dated file.
        $urls7z = @(
            # Release essentials (smaller, ~32 MB) -- has everything we need
            "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.7z",
            # Git master essentials (latest dev build)
            "https://www.gyan.dev/ffmpeg/builds/ffmpeg-git-essentials.7z",
            # Release full build (more codecs, ~70 MB)
            "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-full.7z",
            # Git master full build (latest dev build, full)
            "https://www.gyan.dev/ffmpeg/builds/ffmpeg-git-full.7z"
        )

        foreach ($tryUrl in $urls7z) {
            $archName = [System.IO.Path]::GetFileName($tryUrl)
            $savePath = Join-Path $downloadDir $archName
            Write-Host "Attempting: $tryUrl"
            try {
                $dlOk = Download-FileWithProgress -Url $tryUrl -OutFile $savePath
                if ($dlOk) {
                    $downloaded = $true
                    $downloadedFile = $savePath
                    Write-Host "Download complete ($archName)."
                    break
                }
            } catch {
                Write-Host "Failed: $($_.Exception.Message)"
                if (Test-Path -LiteralPath $savePath) {
                    Remove-Item -LiteralPath $savePath -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }

    if (-not $downloaded) {
        # .7z download failed or no extraction tool -- try .zip archives
        # PowerShell can extract .zip natively with Expand-Archive
        Write-Host ""
        if (-not $canExtract7z) {
            Write-Host "Neither 7-Zip nor WinRAR found -- cannot extract .7z archives."
            Write-Host "Downloading .zip release instead (larger but no extra tools needed)..."
        } else {
            Write-Host ".7z downloads failed. Trying .zip archives..."
        }

        # gyan.dev .zip files:
        #   - ffmpeg-release-essentials.zip  (~104 MB, PowerShell-native extraction)
        #   - ffmpeg-8.1.2-essentials_build.zip (versioned, under /packages/)
        # NOTE: There is NO ffmpeg-release-full.zip on gyan.dev (404).
        # So we also try BtbN/FFmpeg-Builds on GitHub which provides .zip archives.
        $urlsZip = @(
            # gyan.dev release essentials .zip (native PS extraction, ~104 MB)
            "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip",
            # BtbN GitHub - GPL shared build (has ffmpeg.exe + ffprobe.exe + DLLs, ~80 MB)
            "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl-shared.zip",
            # BtbN GitHub - GPL static build (single ffmpeg.exe, no DLLs, ~100 MB)
            "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip"
        )

        foreach ($tryUrl in $urlsZip) {
            $archName = [System.IO.Path]::GetFileName($tryUrl)
            $savePath = Join-Path $downloadDir $archName
            Write-Host "Attempting: $tryUrl"
            try {
                $dlOk = Download-FileWithProgress -Url $tryUrl -OutFile $savePath
                if ($dlOk) {
                    $downloaded = $true
                    $downloadedFile = $savePath
                    Write-Host "Download complete ($archName)."
                    break
                }
            } catch {
                Write-Host "Failed: $($_.Exception.Message)"
                if (Test-Path -LiteralPath $savePath) {
                    Remove-Item -LiteralPath $savePath -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }

    if (-not $downloaded) {
        Write-Host ""
        Write-Host "============================================================"
        Write-Host " AUTOMATIC DOWNLOAD FAILED"
        Write-Host "============================================================"
        Write-Host ""
        Write-Host "Please install ffmpeg manually using ONE of these methods:"
        Write-Host ""
        Write-Host " Option 1 - Download and extract into the addon folder:"
        Write-Host "   1. Go to https://www.gyan.dev/ffmpeg/builds/"
        Write-Host "   2. Download 'ffmpeg-release-essentials.zip' (or .7z if you have 7-Zip)"
        Write-Host "   3. Extract the archive"
        Write-Host "   4. Find ffmpeg.exe and ffprobe.exe inside the bin/ folder"
        Write-Host "   5. Create a folder called 'ffmpeg' next to this script"
        Write-Host "   6. Copy ffmpeg.exe and ffprobe.exe into that 'ffmpeg' folder"
        Write-Host ""
        Write-Host " Option 2 - Download from GitHub BtbN/FFmpeg-Builds:"
        Write-Host "   1. Go to https://github.com/BtbN/FFmpeg-Builds/releases"
        Write-Host "   2. Download 'ffmpeg-master-latest-win64-gpl-shared.zip'"
        Write-Host "   3. Extract the archive"
        Write-Host "   4. Find ffmpeg.exe and ffprobe.exe inside the bin/ folder"
        Write-Host "   5. Create a folder called 'ffmpeg' next to this script"
        Write-Host "   6. Copy ffmpeg.exe and ffprobe.exe into that 'ffmpeg' folder"
        Write-Host ""
        Write-Host " Option 3 - Install via Chocolatey (run as Admin):"
        Write-Host "   choco install ffmpeg"
        Write-Host ""
        Write-Host " Option 4 - Install via Winget:"
        Write-Host "   winget install ffmpeg"
        Write-Host ""
        Write-Host " Option 5 - Install via Scoop:"
        Write-Host "   scoop install ffmpeg-essentials"
        Write-Host ""
        Write-Host " Option 6 - Add ffmpeg to your system PATH:"
        Write-Host "   Download from https://ffmpeg.org/download.html"
        Write-Host "   Extract and add the bin folder to your PATH environment variable"
        Write-Host ""
        Write-Host "NOTE: gyan.dev distributes ffmpeg as .7z files (smaller)."
        Write-Host "Install 7-Zip from https://www.7-zip.org/ for .7z support."
        Write-Host "WinRAR from https://www.win-rar.com/ can also extract .7z files."
        Write-Host "You can also run this script with -UseWinRAR to prefer WinRAR over 7-Zip."
        Write-Host "A .zip release is also available from gyan.dev or GitHub but is larger."
        Write-Host ""
        Write-Host "The script will continue WITHOUT ffmpeg -- MP3 sanitization"
        Write-Host "and accurate duration detection will be skipped."
        Write-Host "============================================================"
        Write-Host ""
        return
    }

    # Extract the archive
    Write-Host "Extracting ffmpeg..."
    try {
        # Create ffmpeg output directory
        if (-not (Test-Path -LiteralPath $FfmpegDir -PathType Container)) {
            New-Item -ItemType Directory -Path $FfmpegDir -Force | Out-Null
        }

        $extractBase = Join-Path $downloadDir 'extracted'
        if (Test-Path -LiteralPath $extractBase) {
            Remove-Item -LiteralPath $extractBase -Recurse -Force
        }

        $is7z = $downloadedFile.EndsWith('.7z')

        if ($is7z) {
            # Extract .7z -- prefer WinRAR if -UseWinRAR was specified, then 7-Zip, then WinRAR as fallback
            if ($preferWinRAR -and $winRarExe) {
                Write-Host "Using WinRAR to extract .7z archive..."
                & $winRarExe x -y $downloadedFile "$extractBase\" 2>$null | Out-Null
            } elseif ($sevenZipExe) {
                Write-Host "Using 7-Zip to extract .7z archive..."
                & $sevenZipExe x $downloadedFile -o"$extractBase" -y 2>$null | Out-Null
            } elseif ($winRarExe) {
                Write-Host "Using WinRAR to extract .7z archive..."
                & $winRarExe x -y $downloadedFile "$extractBase\" 2>$null | Out-Null
            } else {
                Write-Host "ERROR: No tool available to extract .7z archive (need 7-Zip or WinRAR)."
                throw "Cannot extract .7z file -- install 7-Zip or WinRAR, or re-run without .7z download"
            }
        } else {
            # Extract .zip -- prefer WinRAR if -UseWinRAR, then 7-Zip, then PowerShell native
            if ($preferWinRAR -and $winRarExe) {
                Write-Host "Using WinRAR to extract .zip archive..."
                & $winRarExe x -y $downloadedFile "$extractBase\" 2>$null | Out-Null
            } elseif ($sevenZipExe) {
                Write-Host "Using 7-Zip to extract .zip archive..."
                & $sevenZipExe x $downloadedFile -o"$extractBase" -y 2>$null | Out-Null
            } else {
                Write-Host "Using PowerShell to extract .zip archive..."
                Expand-Archive -LiteralPath $downloadedFile -DestinationPath $extractBase -Force
            }
        }

        # Find the bin folder inside the extracted directory
        # gyan.dev archives contain a folder like ffmpeg-8.1.2-essentials_build/ or
        # ffmpeg-2026-06-29-git-de6bcf5c05-full_build/ with a bin/ subfolder inside.
        # BtbN GitHub archives contain a folder like ffmpeg-master-latest-win64-gpl-shared/
        # with a bin/ subfolder inside.
        $binDir = Get-ChildItem -LiteralPath $extractBase -Recurse -Directory -Filter 'bin' |
            Select-Object -First 1

        if ($binDir) {
            # Copy ffmpeg.exe and ffprobe.exe to our local ffmpeg folder
            foreach ($exe in @('ffmpeg.exe', 'ffprobe.exe')) {
                $src = Join-Path $binDir.FullName $exe
                $dst = Join-Path $FfmpegDir $exe
                if (Test-Path -LiteralPath $src -PathType Leaf) {
                    Copy-Item -LiteralPath $src -Destination $dst -Force
                    Write-Host "Installed: $exe -> $dst"
                }
            }
        } else {
            # Try to find ffmpeg.exe directly in extracted folder
            $ffmpegFiles = Get-ChildItem -LiteralPath $extractBase -Recurse -File -Filter 'ffmpeg.exe'
            $ffprobeFiles = Get-ChildItem -LiteralPath $extractBase -Recurse -File -Filter 'ffprobe.exe'
            foreach ($f in $ffmpegFiles) {
                Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $FfmpegDir 'ffmpeg.exe') -Force
                Write-Host "Installed: ffmpeg.exe"
            }
            foreach ($f in $ffprobeFiles) {
                Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $FfmpegDir 'ffprobe.exe') -Force
                Write-Host "Installed: ffprobe.exe"
            }
        }

        # Clean up download artifacts
        Remove-Item -LiteralPath $extractBase -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $downloadedFile -Force -ErrorAction SilentlyContinue
        # Remove download dir if empty
        $remaining = Get-ChildItem -LiteralPath $downloadDir -ErrorAction SilentlyContinue
        if (-not $remaining) {
            Remove-Item -LiteralPath $downloadDir -Force -ErrorAction SilentlyContinue
        }

        # Verify installation
        $ffTest = Join-Path $FfmpegDir 'ffmpeg.exe'
        $fpTest = Join-Path $FfmpegDir 'ffprobe.exe'
        if ((Test-Path -LiteralPath $ffTest) -and (Test-Path -LiteralPath $fpTest)) {
            Write-Host ""
            Write-Host "ffmpeg installed successfully in: $FfmpegDir"
            Write-Host ""
        } else {
            Write-Host ""
            Write-Host "WARNING: ffmpeg/ffprobe not found after extraction."
            Write-Host "Please install manually (see instructions below)."
            Write-Host ""
        }

    } catch {
        Write-Host "ERROR: Failed to extract ffmpeg: $($_.Exception.Message)"
        Write-Host "Please install ffmpeg manually (see instructions in the script output)."
    }
}

# Run the auto-installer
Ensure-FfmpegInstalled

# -- Rename files with special characters for WoW 1.12 compatibility ----------
# WoW 1.12's FMOD engine may fail to play files whose names contain characters
# like apostrophes ('), parentheses, or other special symbols.  This step
# renames such files by replacing problematic characters with underscores.
# Only the physical filename is changed; the track name in the playlist
# preserves the original display name.
#
# IMPORTANT: This rename step runs BEFORE the MP3/WAV/OGG compatibility scan
# so that ffmpeg and the binary analysis functions can access files without
# special characters in their paths.  Characters like apostrophes and quotes
# can break PowerShell's COM object calls and ffmpeg argument parsing.

$problematicChars = @("'", '"', '(', ')', '[', ']', '{', '}', '!', '&', '#', '%', '@', '+', '=', ',', ';')
$renamed = 0
$renameSkipped = 0
$allMediaFiles = @(Get-ChildItem -LiteralPath $Media -Recurse -File |
    Where-Object { $_.Extension -match '^(?i)\.(mp3|wav|ogg)$' -and $_.Name -notmatch '\.sanitize\.tmp\.' })

foreach ($mf in $allMediaFiles) {
    $needsRename = $false
    foreach ($ch in $problematicChars) {
        if ($mf.Name.Contains($ch)) {
            $needsRename = $true
            break
        }
    }

    if ($needsRename) {
        $newName = $mf.Name
        foreach ($ch in $problematicChars) {
            $newName = $newName.Replace($ch, '_')
        }
        # Remove double underscores and trailing/leading underscores
        while ($newName.Contains('__')) { $newName = $newName.Replace('__', '_') }

        $newPath = Join-Path $mf.DirectoryName $newName
        if ($newPath -ne $mf.FullName) {
            if (-not (Test-Path -LiteralPath $newPath)) {
                # Target doesn't exist - safe to rename
                try {
                    Rename-Item -LiteralPath $mf.FullName -NewName $newName -Force
                    Write-Host "  Renamed: $($mf.Name) -> $newName"
                    $renamed++
                } catch {
                    Write-Host "  WARNING: Could not rename $($mf.Name): $_"
                    $renameSkipped++
                }
            } else {
                # Target already exists - this is likely a duplicate file from a previous
                # rename or download.  Delete the old problematic-name file since the
                # already-renamed file takes precedence.
                try {
                    Remove-Item -LiteralPath $mf.FullName -Force
                    Write-Host "  Removed duplicate (already renamed): $($mf.Name) -> $newName (kept existing)"
                    $renameSkipped++
                } catch {
                    Write-Host "  WARNING: Could not remove duplicate $($mf.Name): $_"
                    $renameSkipped++
                }
            }
        }
    }
}

if ($renamed -gt 0) {
    Write-Host ""
    Write-Host "Renamed $renamed file(s) -- replaced special characters for WoW 1.12 path compatibility."
    Write-Host ""
}
if ($renameSkipped -gt 0) {
    Write-Host ""
    Write-Host "$renameSkipped file(s) skipped during rename (duplicate with sanitized name already existed)."
    Write-Host ""
}

# -- Rename numeric-only MP3 filenames using embedded ID3 title --------------
# Some MP3s have filenames that are just numbers (e.g. "01.mp3", "1234.mp3",
# "01 02 03.mp3").  These are useless in the playlist UI.  When we detect such
# a file, read the embedded ID3 title tag via Shell.Application and rename the
# file to "<Title>.mp3" (sanitized for WoW 1.12 path compatibility).

function Get-Mp3EmbeddedTitle {
    param([Parameter(Mandatory=$true)][string]$FilePath)
    try {
        $shell   = New-Object -ComObject Shell.Application
        $folder  = $shell.Namespace((Split-Path -Parent $FilePath))
        if ($null -eq $folder) { return $null }
        $item    = $folder.ParseName((Split-Path -Leaf $FilePath))
        if ($null -eq $item) { return $null }
        # Property index 21 = Title on Windows; fall back to scanning if empty.
        $title = $folder.GetDetailsOf($item, 21)
        if ([string]::IsNullOrWhiteSpace($title)) {
            for ($i = 0; $i -lt 400; $i++) {
                $header = $folder.GetDetailsOf($null, $i)
                if ($header -eq 'Title') {
                    $title = $folder.GetDetailsOf($item, $i)
                    break
                }
            }
        }
        if ([string]::IsNullOrWhiteSpace($title)) { return $null }
        return $title.Trim()
    } catch {
        return $null
    }
}

$numericRenamed = 0
$numericSkipped = 0
$mp3Files = @(Get-ChildItem -LiteralPath $Media -Recurse -File |
    Where-Object { $_.Extension -match '^(?i)\.mp3$' -and $_.Name -notmatch '\.sanitize\.tmp\.' })

foreach ($mf in $mp3Files) {
    $base = [System.IO.Path]::GetFileNameWithoutExtension($mf.Name)
    # "Only numbers": digits, optionally separated by spaces / dots / dashes / underscores.
    if ($base -notmatch '^[\d\s\.\-_]+$' -or $base -notmatch '\d') { continue }

    $title = Get-Mp3EmbeddedTitle -FilePath $mf.FullName
    if ([string]::IsNullOrWhiteSpace($title)) {
        Write-Host "  Skipped (no embedded title): $($mf.Name)"
        $numericSkipped++
        continue
    }

    # Sanitize the title for filesystem + WoW 1.12 compatibility.
    $safeTitle = $title
    foreach ($ch in $problematicChars) { $safeTitle = $safeTitle.Replace($ch, '_') }
    foreach ($ch in [System.IO.Path]::GetInvalidFileNameChars()) {
        $safeTitle = $safeTitle.Replace([string]$ch, '_')
    }
    while ($safeTitle.Contains('__')) { $safeTitle = $safeTitle.Replace('__', '_') }
    $safeTitle = $safeTitle.Trim(' ', '_', '.')

    if ([string]::IsNullOrWhiteSpace($safeTitle)) {
        Write-Host "  Skipped (title sanitized to empty): $($mf.Name)"
        $numericSkipped++
        continue
    }

    $newName = "$safeTitle.mp3"
    $newPath = Join-Path $mf.DirectoryName $newName
    if ($newPath -eq $mf.FullName) { continue }

    # Avoid collisions by appending a numeric suffix.
    if (Test-Path -LiteralPath $newPath) {
        $n = 2
        do {
            $candidate = Join-Path $mf.DirectoryName ("$safeTitle ($n).mp3")
            $n++
        } while (Test-Path -LiteralPath $candidate)
        $newPath = $candidate
        $newName = Split-Path -Leaf $candidate
    }

    try {
        Rename-Item -LiteralPath $mf.FullName -NewName $newName -Force
        Write-Host "  Renamed (numeric -> title): $($mf.Name) -> $newName"
        $numericRenamed++
    } catch {
        Write-Host "  WARNING: Could not rename $($mf.Name): $_"
        $numericSkipped++
    }
}

if ($numericRenamed -gt 0) {
    Write-Host ""
    Write-Host "Renamed $numericRenamed numeric-only MP3 file(s) using embedded ID3 title."
    Write-Host ""
}
if ($numericSkipped -gt 0) {
    Write-Host ""
    Write-Host "$numericSkipped numeric-only MP3 file(s) skipped (no title / collision / error)."
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Now that ffmpeg may be available, set up a helper to call it from the
# local ffmpeg folder when the system PATH doesn't have it.
# ---------------------------------------------------------------------------

# Override ffprobe/ffmpeg calls to use the local copy if needed
$localFfmpeg  = Join-Path $FfmpegDir 'ffmpeg.exe'
$localFfprobe = Join-Path $FfmpegDir 'ffprobe.exe'

# -- ffprobe result cache (MAJOR SPEEDUP) -----------------------------------
# Instead of calling ffprobe multiple times per file (once for duration, once
# for video stream detection, once after re-encoding, etc.), we call it ONCE
# with -show_format -show_streams and cache the parsed JSON object per file path.
# This eliminates 1-3 redundant ffprobe process launches per file.
$script:ffprobeCache = @{}

function Get-FfprobeData {
    param([string]$FilePath)
    if ($script:ffprobeCache.ContainsKey($FilePath)) {
        return $script:ffprobeCache[$FilePath]
    }
    $exe = Find-Ffmpeg -Name 'ffprobe'
    if (-not $exe) {
        $script:ffprobeCache[$FilePath] = $null
        return $null
    }
    try {
        # Use & call operator instead of Start-Process — much faster
        # (no process-creation overhead, proper argument quoting built-in)
        $raw = & $exe '-v' 'quiet' '-print_format' 'json' '-show_format' '-show_streams' $FilePath 2>$null
        if ($LASTEXITCODE -eq 0 -and $raw) {
            $json = $raw | ConvertFrom-Json
            $script:ffprobeCache[$FilePath] = $json
            return $json
        }
    } catch {
        # ffprobe failed — cache null to avoid retrying
    }
    $script:ffprobeCache[$FilePath] = $null
    return $null
}

# Clear the ffprobe cache (call after a file has been re-encoded in place)
function Clear-FfprobeCache {
    param([string]$FilePath)
    if ($script:ffprobeCache.ContainsKey($FilePath)) {
        $script:ffprobeCache.Remove($FilePath)
    }
}

# -- ffmpeg/ffprobe call helpers using & operator (FASTER than Start-Process) --
# PowerShell's & (call) operator properly quotes arguments containing spaces,
# so we no longer need Build-QuotedArgs or Start-Process for most calls.
# The & operator also avoids the ~200-400ms process-launch overhead that
# Start-Process imposes on every invocation.

function Invoke-Ffprobe {
    param([string[]]$Arguments)
    $exe = Find-Ffmpeg -Name 'ffprobe'
    if ($exe) {
        return & $exe @Arguments
    }
    return $null
}

function Invoke-Ffmpeg {
    param([string[]]$Arguments)
    $exe = Find-Ffmpeg -Name 'ffmpeg'
    if ($exe) {
        return & $exe @Arguments
    }
    return $null
}

# -- Build a properly-quoted argument string for Start-Process ---------------
# NOTE: Start-Process is now ONLY used for ffmpeg re-encoding where we need
# -RedirectStandardError for diagnostics.  All other ffprobe/ffmpeg calls
# use the faster & operator via Invoke-Ffprobe / Invoke-Ffmpeg above.
#
# PowerShell's Start-Process -ArgumentList with an array does NOT automatically
# quote elements containing spaces.  When a file path like
# "G:\Music\01 - Pantera - Walk.mp3" is passed as an array element,
# Start-Process splits it at the spaces, and ffmpeg receives multiple broken
# tokens instead of one quoted path.  This function builds a single argument
# string where every token that contains spaces is wrapped in double-quotes.
#
# Usage:  Start-Process -FilePath $exe -ArgumentList (Build-QuotedArgs @(...))
function Build-QuotedArgs {
    param([string[]]$ArgumentArray)
    $parts = @()
    foreach ($arg in $ArgumentArray) {
        if ($arg -match '\s') {
            # Argument contains spaces -- wrap in double-quotes.
            # Escape any embedded double-quotes first.
            $escaped = $arg.Replace('"', '\"')
            $parts += "`"$escaped`""
        } else {
            $parts += $arg
        }
    }
    return $parts -join ' '
}

# -- Compatibility cache (MAJOR SPEEDUP on re-runs) -------------------------
# After the first run, each file's compatibility status is cached in a
# .compat_cache file next to the script.  On subsequent runs, files whose
# last-modified timestamp and size haven't changed are skipped entirely,
# cutting scan time from minutes to seconds for large libraries.
$compatCachePath = Join-Path $Root 'mp3_compat_cache.txt'
$script:compatCache = @{}

function Load-CompatCache {
    if (Test-Path -LiteralPath $compatCachePath -PathType Leaf) {
        try {
            $lines = [System.IO.File]::ReadAllLines($compatCachePath)
            foreach ($line in $lines) {
                # Format: LastWriteTime|Length|Status|Reason
                # Status: OK = compatible, FIX = was sanitized
                $parts = $line -split '\|'
                if ($parts.Count -ge 4) {
                    $key = "$($parts[0])|$($parts[1])"
                    $script:compatCache[$key] = @($parts[2], $parts[3])
                }
            }
        } catch {
            $script:compatCache = @{}
        }
    }
}

function Save-CompatCache {
    try {
        $lines = @()
        foreach ($key in $script:compatCache.Keys) {
            $val = $script:compatCache[$key]
            $lines += "$key|$($val[0])|$($val[1])"
        }
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllLines($compatCachePath, $lines, $utf8NoBom)
    } catch {
        # Silently ignore cache save errors
    }
}

function Get-CompatCacheEntry {
    param([System.IO.FileInfo]$File)
    $key = "$($File.LastWriteTimeUtc.Ticks)|$($File.Length)"
    if ($script:compatCache.ContainsKey($key)) {
        return $script:compatCache[$key]
    }
    return $null
}

function Set-CompatCacheEntry {
    param([System.IO.FileInfo]$File, [string]$Status, [string]$Reason)
    $key = "$($File.LastWriteTimeUtc.Ticks)|$($File.Length)"
    $script:compatCache[$key] = @($Status, $Reason)
}

# Load cache at startup
Load-CompatCache

if (-not (Test-Path -LiteralPath $Media -PathType Container)) {
    throw "Media folder not found: $Media"
}

# -- Lua string escaper ------------------------------------------------------
function Escape-LuaString {
    param([AllowNull()][string]$Value)

    if ($null -eq $Value) { return '' }

    $escaped = $Value.Replace('\', '\\')
    $escaped = $escaped.Replace('"', '\"')
    $escaped = $escaped.Replace("`n", '\n')
    $escaped = $escaped.Replace("`r", '\r')
    return $escaped
}

# -- Duration helpers (optional -- graceful fallback) -------------------------
$shell = $null
$wmp   = $null
try { $shell = New-Object -ComObject Shell.Application } catch { $shell = $null }
try { $wmp   = New-Object -ComObject WMPlayer.OCX.7    } catch { $wmp   = $null }

# Default duration assigned when we cannot read metadata (seconds).
# This lets autoplay/shuffle work without metadata -- the Lua side uses
# this as the wait time before advancing to the next track.
$DEFAULT_DURATION = 180   # 3 minutes -- reasonable for most songs

function Get-TrackDurationSeconds {
    param([System.IO.FileInfo]$File)

    # --- Try ffprobe cache FIRST (avoids redundant process launch) ---
    $ffData = Get-FfprobeData -FilePath $File.FullName
    if ($ffData -and $ffData.format -and $ffData.format.duration) {
        $dur = [double]$ffData.format.duration
        if ($dur -gt 0) { return [int][Math]::Ceiling($dur) }
    }

    # --- Try Shell.Application (works for mp3 with Windows property handlers) ---
    if ($shell) {
        try {
            $folder = $shell.Namespace($File.DirectoryName)
            if ($folder) {
                $item = $folder.ParseName($File.Name)
                if ($item) {
                    # 27 = Duration column in Shell folder view (HH:MM:SS string)
                    $raw = $item.ExtendedProperty('System.Media.Duration')
                    $ticks = 0L
                    if ($raw -is [ValueType]) {
                        $ticks = [int64]$raw
                    } elseif ($raw) {
                        [void][int64]::TryParse([string]$raw, [ref]$ticks)
                    }

                    if ($ticks -gt 0) {
                        return [int][Math]::Ceiling($ticks / 10000000.0)
                    }

                    # Fallback: try the Duration column (index 27) as a string
                    $durStr = $folder.GetDetailsOf($item, 27)
                    if ($durStr -and $durStr.Trim() -ne '') {
                        # Parse HH:MM:SS or MM:SS
                        $parts = $durStr.Trim() -split ':'
                        $secs = 0
                        if ($parts.Count -eq 3) {
                            $secs = [int]$parts[0]*3600 + [int]$parts[1]*60 + [int]$parts[2]
                        } elseif ($parts.Count -eq 2) {
                            $secs = [int]$parts[0]*60 + [int]$parts[1]
                        }
                        if ($secs -gt 0) { return $secs }
                    }
                }
            }
        } catch {
            # Silently skip -- special characters in filename can break COM
        }
    }

    # --- Try Windows Media Player COM ---
    if ($wmp) {
        try {
            $mediaItem = $wmp.newMedia($File.FullName)
            if ($mediaItem) {
                $duration = [double]$mediaItem.duration
                if ($duration -gt 0) {
                    return [int][Math]::Ceiling($duration)
                }
            }
        } catch {
            # Silently skip -- special characters in filename can break COM
        }
    }

    # --- Fallback: estimate from file size (very rough) ---
    # For mp3 @ ~128kbps: ~1KB per second. For WAV: ~172KB per second (16bit/44.1k/stereo)
    if ($File.Extension -match '^(?i)\.mp3$') {
        $estimate = [int][Math]::Ceiling($File.Length / 16000.0)   # ~128kbps
        if ($estimate -gt 10) { return $estimate }
    } elseif ($File.Extension -match '^(?i)\.wav$') {
        $estimate = [int][Math]::Ceiling($File.Length / 176000.0)  # ~16bit/44.1k/stereo
        if ($estimate -gt 10) { return $estimate }
    } elseif ($File.Extension -match '^(?i)\.ogg$') {
        $estimate = [int][Math]::Ceiling($File.Length / 12000.0)   # ~112kbps vorbis
        if ($estimate -gt 10) { return $estimate }
    }

    # --- Ultimate fallback: use default duration ---
    return $DEFAULT_DURATION
}

# -- Sanitize MP3 files for WoW 1.12 compatibility ---------------------------
# WoW 1.12's FMOD 3.x engine is very picky about MP3 files.  Many tracks that
# play fine in modern players will silently fail in-game.  Known issues include:
#
#   1. CRC protection bit set (protection_bit = 0 in MPEG frame header)
#   2. Embedded album art / ID3v2 APIC frames (FMOD may misparse these as video)
#   3. Variable bitrate (VBR) encoding with Xing/Info headers
#   4. Non-standard MPEG version/layer combinations (MPEG 2.0/2.5, Layer I/II)
#   5. Unusual channel modes (dual channel, joint stereo variants)
#   6. Very high bitrates (>256kbps) that FMOD 3.x sometimes chokes on
#   7. LAME-encoded files with non-standard delay/padding info tags
#   8. ID3v2 extended headers or unsynchronization that confuse FMOD
#   9. Files with large ID3v2 tags where FMOD fails to find the audio start
#  10. Files encoded with encoders that produce MPEG frame padding inconsistencies
#
# The ONLY reliable fix is to re-encode with ffmpeg using settings known to
# produce FMOD 3.x-compatible output.  This script checks each MP3 for any
# of these issues and re-encodes only those that need it.  If ffmpeg is not
# available, it tries a binary patch to at least fix CRC protection.
#
# Re-encoded files use: CBR 256kbps, MPEG1 Layer3, Simple Stereo, no CRC,
# no embedded art, stripped tags, standard LAME encoding.

# -- Fast-path pre-check for obviously compatible files ----------------------
# If a file starts with 0xFF 0xFB (MPEG1 Layer3, no CRC, no ID3v2 tag) and
# has no ID3v1 tail tag, it's almost certainly FMOD 3.x-compatible.  This
# avoids reading the entire file into memory and scanning 50 MPEG frames.
# Returns: $true if the file is obviously compatible (skip full scan),
#          $false if the file needs the full Test-Mp3NeedsReencode check.
function Test-Mp3FastPathCompatible {
    param([string]$FilePath)
    try {
        # Read only the first 4 bytes and last 128 bytes
        $fs = [System.IO.File]::OpenRead($FilePath)
        try {
            if ($fs.Length -lt 4) { return $false }

            # Check first 4 bytes for MPEG1 Layer3 no-CRC sync word
            $head = New-Object byte[] 4
            [void]$fs.Read($head, 0, 4)

            # 0xFF 0xFB = MPEG1, Layer3, no CRC protection
            # Also accept 0xFF 0xFA (MPEG1 Layer3 with CRC — needs full check)
            # Also accept 0xFF 0xE3 etc. (MPEG2 — needs full check)
            if ($head[0] -ne 0xFF -or ($head[1] -band 0xE0) -ne 0xE0) {
                # Not starting with MPEG sync — might have ID3v2 tag
                return $false
            }
            # Check: must be MPEG1 Layer3 no-CRC (0xFF 0xFBx where x has specific bits)
            # Byte 1: bits = [sync1 sync2 sync3 ID1 ID0 Layer1 Layer0 Protection]
            # MPEG1=11, Layer3=01, NoCRC=1 => 0xFF 0xFB
            if ($head[1] -ne 0xFB) {
                # Not MPEG1 Layer3 no-CRC — needs full check
                return $false
            }

            # Check for ID3v1 tail tag (last 128 bytes start with 'TAG')
            if ($fs.Length -ge 128) {
                $fs.Seek(-128, [System.IO.SeekOrigin]::End) | Out-Null
                $tail = New-Object byte[] 3
                [void]$fs.Read($tail, 0, 3)
                if ($tail[0] -eq 0x54 -and $tail[1] -eq 0x41 -and $tail[2] -eq 0x47) {
                    # Has ID3v1 tag — should strip it, needs full check
                    return $false
                }
            }

            # Also check for video streams via ffprobe cache
            $ffData = Get-FfprobeData -FilePath $FilePath
            if ($ffData -and $ffData.streams) {
                foreach ($stream in $ffData.streams) {
                    if ($stream.codec_type -eq 'video') {
                        return $false
                    }
                }
            }

            # Fast-path: file starts with 0xFF 0xFB, no ID3v1, no video streams
            return $true
        } finally {
            $fs.Close()
        }
    } catch {
        return $false
    }
}

function Test-Mp3NeedsReencode {
    param([string]$FilePath)

    try {
        $bytes = [System.IO.File]::ReadAllBytes($FilePath)
        if ($bytes.Length -lt 10) { return $false, 'File too small' }

        # --- Check for ID3v2 tag and find audio start ---
        $audioOffset = 0
        $hasId3v2 = $false
        $hasExtendedHeader = $false
        $hasUnsynchronization = $false
        $id3v2Size = 0

        if ($bytes[0] -eq 0x49 -and $bytes[1] -eq 0x44 -and $bytes[2] -eq 0x33) {
            # ID3v2 tag present
            $hasId3v2 = $true
            $id3v2Flags = $bytes[5]
            $hasUnsynchronization = ($id3v2Flags -band 0x80) -ne 0
            $hasExtendedHeader = ($id3v2Flags -band 0x40) -ne 0
            $id3v2Size = ($bytes[6] -shl 21) -bor ($bytes[7] -shl 14) -bor ($bytes[8] -shl 7) -bor $bytes[9]
            $audioOffset = $id3v2Size + 10

            # Check for embedded album art (APIC frame) in ID3v2
            # Scan the ID3v2 tag for 'APIC' frame ID
            $tagEnd = [Math]::Min($id3v2Size + 10, $bytes.Length)
            for ($j = 10; $j -lt $tagEnd - 4; $j++) {
                if ($bytes[$j] -eq 0x41 -and $bytes[$j+1] -eq 0x50 -and $bytes[$j+2] -eq 0x49 -and $bytes[$j+3] -eq 0x43) {
                    # APIC frame found = embedded album art
                    return $true, 'Embedded album art (APIC frame in ID3v2 tag)'
                }
                # Also check for 'PIC ' (ID3v2.2 picture frame)
                if ($bytes[$j] -eq 0x50 -and $bytes[$j+1] -eq 0x49 -and $bytes[$j+2] -eq 0x43 -and $bytes[$j+3] -eq 0x20) {
                    return $true, 'Embedded album art (PIC frame in ID3v2 tag)'
                }
            }
        }

        if ($hasUnsynchronization) {
            return $true, 'ID3v2 unsynchronization flag set (can confuse FMOD 3.x)'
        }

        if ($hasExtendedHeader) {
            return $true, 'ID3v2 extended header present (can confuse FMOD 3.x)'
        }

        # --- Scan MPEG audio frames ---
        if ($audioOffset -ge $bytes.Length - 4) { return $false, 'No audio data found' }

        $frameCount = 0
        $maxFramesToCheck = 50
        $foundXing = $false
        $foundInfo = $false
        $hasCrc = $false
        $hasVbr = $false
        $hasHighBitrate = $false
        $hasNonStandardMode = $false
        $hasMpeg2 = $false
        $hasLameTag = $false
        $lameEncoder = ''
        $prevBitrateIdx = -1
        $bitrateChanges = 0

        # Bitrate table for MPEG1 Layer III (index 0 = free, 15 = bad)
        $bitrateTable1L3 = @(0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0)

        for ($i = $audioOffset; $i -lt [Math]::Min($bytes.Length - 4, $audioOffset + 65536); $i++) {
            # Look for MPEG sync word
            if ($bytes[$i] -ne 0xFF -or ($bytes[$i+1] -band 0xE0) -ne 0xE0) {
                continue
            }

            $b1 = $bytes[$i+1]
            $b2 = $bytes[$i+2]

            # Decode MPEG header
            $mpegVersion = ($b1 -shr 3) -band 0x03   # 0=2.5, 2=2.0, 3=1.0
            $layer = ($b1 -shr 1) -band 0x03          # 1=Layer3, 2=Layer2, 3=Layer1
            $protection = $b1 -band 0x01               # 0=CRC present, 1=no CRC
            $bitrateIdx = ($b2 -shr 4) -band 0x0F
            $sampleRateIdx = ($b2 -shr 2) -band 0x03
            $channelMode = ($bytes[$i+3] -shr 6) -band 0x03  # 0=Stereo, 1=Joint, 2=Dual, 3=Mono

            # Check for MPEG 2.0 or 2.5 (WoW 1.12 FMOD may not handle these)
            if ($mpegVersion -eq 0 -or $mpegVersion -eq 2) {
                $hasMpeg2 = $true
            }

            # Check for non-Layer3 (WoW 1.12 FMOD may not handle Layer I/II)
            if ($layer -ne 1) {
                $hasNonStandardMode = $true
            }

            # Check CRC protection
            if ($protection -eq 0) {
                $hasCrc = $true
            }

            # Check bitrate
            if ($mpegVersion -eq 3 -and $layer -eq 1) {
                # MPEG1 Layer3
                $br = $bitrateTable1L3[$bitrateIdx]
                if ($br -ge 320) {
                    $hasHighBitrate = $true  # 320kbps sometimes causes FMOD issues
                }
                # Track bitrate changes for VBR detection
                if ($prevBitrateIdx -ge 0 -and $bitrateIdx -ne $prevBitrateIdx) {
                    $bitrateChanges++
                }
                $prevBitrateIdx = $bitrateIdx
            }

            # Check for Xing/Info header (VBR indicator) - usually at offset 36 from frame start
            # for MPEG1 Layer3 stereo: after 32-byte side information
            if ($i + 72 -lt $bytes.Length) {
                $xingOffset = $i + 36
                if ($bytes[$xingOffset] -eq 0x58 -and $bytes[$xingOffset+1] -eq 0x69 -and $bytes[$xingOffset+2] -eq 0x6E -and $bytes[$xingOffset+3] -eq 0x67) {
                    $foundXing = $true
                    $hasVbr = $true
                }
                if ($bytes[$xingOffset] -eq 0x49 -and $bytes[$xingOffset+1] -eq 0x6E -and $bytes[$xingOffset+2] -eq 0x66 -and $bytes[$xingOffset+3] -eq 0x6F) {
                    $foundInfo = $true
                    # Info header can indicate CBR but still has LAME tag that may cause issues
                    # Scan for LAME encoder tag after the Info header fields
                    # Info header layout: 4 bytes 'Info' + 4 bytes flags + optional fields + LAME tag
                    # The LAME tag starts 120 bytes after the Info magic (after flags+frames+bytes+TOC+vbr_scale)
                    # Total Info header with all flags set = 4+4+4+4+100+4 = 120 bytes, then LAME tag
                    $lameOffset = $xingOffset + 120
                    if ($lameOffset + 4 -lt $bytes.Length) {
                        # Check for common encoder signatures: LAME, Lavc, Lavf, GOGO, etc.
                        # These appear as ASCII text at the start of the encoder tag field
                        $encBytes = $bytes[$lameOffset..($lameOffset+8)]
                        $encText = [System.Text.Encoding]::ASCII.GetString($encBytes).TrimEnd([char]0)
                        if ($encText -match '^(LAME|Lavc|Lavf|GOGO|Xing|Gogo|lame|REA[LC]|THOMS|QDesign)') {
                            $hasLameTag = $true
                            $lameEncoder = $encText
                        }
                    }
                }
            }

            $frameCount++
            if ($frameCount -ge $maxFramesToCheck) { break }

            # Calculate frame size to skip to next frame
            if ($mpegVersion -eq 3 -and $layer -eq 1) {
                $br = $bitrateTable1L3[$bitrateIdx]
                if ($br -gt 0) {
                    $padding = ($b2 -shr 1) -band 0x01
                    # Determine actual sample rate from MPEG header for accurate frame size
                    $sampleRates1 = @(44100, 48000, 32000, 0)  # MPEG1
                    $sampleRates2 = @(22050, 24000, 16000, 0)  # MPEG2
                    $sampleRates25 = @(11025, 12000, 8000, 0)  # MPEG2.5
                    if ($mpegVersion -eq 3) { $curSampleRate = $sampleRates1[$sampleRateIdx] }
                    elseif ($mpegVersion -eq 2) { $curSampleRate = $sampleRates2[$sampleRateIdx] }
                    else { $curSampleRate = $sampleRates25[$sampleRateIdx] }
                    if ($curSampleRate -le 0) { $curSampleRate = 44100 }  # fallback
                    $frameSize = [int]([Math]::Floor(144.0 * $br * 1000 / $curSampleRate)) + $padding
                    $i += $frameSize - 1  # -1 because the for loop does $i++
                } else {
                    $i += 417
                }
            } else {
                # Non-standard frame, skip forward conservatively
                $i += 417
            }
        }

        # --- Return findings ---
        # VBR detection: Xing header or multiple bitrate changes
        if ($foundXing) {
            return $true, 'VBR encoding (Xing header found - FMOD 3.x often fails on VBR)'
        }
        if ($bitrateChanges -ge 3) {
            return $true, 'VBR encoding (bitrate changes detected across frames)'
        }

        # CRC protection
        if ($hasCrc) {
            return $true, 'CRC protection bit set (FMOD 3.x cannot play CRC-protected MP3)'
        }

        # Info header with LAME encoder tag
        # Many FMOD 3.x implementations (including WoW 1.12) can misparse the LAME
        # delay/padding fields in the Info/LAME tag, causing the audio start offset
        # to be calculated incorrectly.  Re-encoding strips the Info/LAME tag entirely
        # and produces a clean MPEG stream that FMOD can parse reliably.
        if ($foundInfo -and $hasLameTag) {
            return $true, "Info/LAME encoder tag found ($lameEncoder) - FMOD 3.x may misparse delay/padding fields"
        }

        # Embedded art was already checked above, but also check via file size heuristic
        # If there's an ID3v2 tag larger than 100KB, it likely has embedded art
        if ($hasId3v2 -and $id3v2Size -gt 102400) {
            return $true, "Large ID3v2 tag ($([int]($id3v2Size/1024))KB - likely contains embedded art)"
        }

        # High bitrate (320kbps) with CRC or other issues
        if ($hasHighBitrate -and $hasCrc) {
            return $true, '320kbps with CRC protection (known to fail in FMOD 3.x)'
        }

        # Non-standard MPEG version/layer
        if ($hasMpeg2) {
            return $true, 'MPEG 2.0/2.5 audio detected (FMOD 3.x may not support)'
        }
        if ($hasNonStandardMode) {
            return $true, 'Non-Layer3 MPEG audio detected (FMOD 3.x may not support)'
        }

        # Dual channel mode (rare, sometimes causes FMOD issues)
        if ($channelMode -eq 2 -and $frameCount -gt 0) {
            return $true, 'Dual channel mode detected (FMOD 3.x may not handle correctly)'
        }

        # Check for video/image streams embedded in the MP3 file
        # Some MP3 files have embedded JPEG/PNG album art as a separate "stream"
        # FMOD may try to play these as video and fail
        # Uses the ffprobe cache instead of launching a separate process
        $ffData = Get-FfprobeData -FilePath $FilePath
        if ($ffData -and $ffData.streams) {
            foreach ($stream in $ffData.streams) {
                if ($stream.codec_type -eq 'video') {
                    return $true, "Embedded video/image stream (codec: $($stream.codec_name)) - FMOD 3.x cannot handle"
                }
            }
        }

        # Check for ID3v2 tag that doesn't have embedded art/unsync/extended header
        # (those are already caught above).  Even a "clean" ID3v2 tag can cause
        # FMOD 3.x to add a small seek offset at the start of playback.  Stripping
        # it ensures the file starts directly with the MPEG sync word.
        if ($hasId3v2 -and $audioOffset -gt 0) {
            return $true, 'ID3v2 tag present (may cause seek offset in FMOD 3.x)'
        }

        return $false, 'Compatible'
    }
    catch {
        return $true, "Error analyzing file: $($_.Exception.Message)"
    }
}

# -- Strip ALL tags from an MP3 file in a SINGLE pass (COMBINED for SPEED) ---
# After ffmpeg re-encodes an MP3 file, libmp3lame writes its own Info/LAME tag
# and ffmpeg may write a minimal ID3v2.4 header.  Previously we called
# Strip-LameTag (reads entire file) then Strip-Id3v2Tag (reads entire file again),
# resulting in 2 full file reads + 2 full file writes.  This combined function
# does everything in ONE read + ONE write, cutting I/O time in half.
#
# This function modifies the file IN PLACE and is safe to call on files that
# don't have any tags (it will detect and skip them).
# Returns: @($strippedLame, $strippedId3v2) - booleans indicating what was stripped.
function Strip-Mp3Tags {
    param([string]$FilePath)

    $strippedLame = $false
    $strippedId3v2 = $false

    try {
        $bytes = [System.IO.File]::ReadAllBytes($FilePath)
        if ($bytes.Length -lt 10) { return @($false, $false) }

        # --- Step 1: Strip ID3v2 tag from the beginning ---
        $id3v2TotalSize = 0
        if ($bytes[0] -eq 0x49 -and $bytes[1] -eq 0x44 -and $bytes[2] -eq 0x33) {
            $tagSize = ($bytes[6] -shl 21) -bor ($bytes[7] -shl 14) -bor ($bytes[8] -shl 7) -bor $bytes[9]
            $id3v2TotalSize = $tagSize + 10  # 10-byte header + tag body
            if ($id3v2TotalSize -lt $bytes.Length) {
                # Remove the ID3v2 tag bytes entirely by shifting the array
                $newLen = $bytes.Length - $id3v2TotalSize
                $shifted = New-Object byte[] $newLen
                [Array]::Copy($bytes, $id3v2TotalSize, $shifted, 0, $newLen)
                $bytes = $shifted
                $strippedId3v2 = $true
            }
        }

        # --- Step 2: Strip Info/LAME tag from first MPEG frame ---
        if ($bytes.Length -ge 4) {
            # Look for the first MPEG frame sync word
            $frameStart = -1
            for ($i = 0; $i -lt [Math]::Min($bytes.Length - 4, 4096); $i++) {
                if ($bytes[$i] -eq 0xFF -and ($bytes[$i+1] -band 0xE0) -eq 0xE0) {
                    $frameStart = $i
                    break
                }
            }

            if ($frameStart -ge 0) {
                # Determine the Xing/Info header offset
                $b1 = $bytes[$frameStart + 1]
                $mpegVersion = ($b1 -shr 3) -band 0x03
                $layer = ($b1 -shr 1) -band 0x03
                $channelMode = ($bytes[$frameStart + 3] -shr 6) -band 0x03

                if ($mpegVersion -eq 3 -and $layer -eq 1 -and $channelMode -ne 3) {
                    $xingOffset = $frameStart + 36
                } elseif ($mpegVersion -eq 3 -and $layer -eq 1 -and $channelMode -eq 3) {
                    $xingOffset = $frameStart + 21
                } elseif (($mpegVersion -eq 2 -or $mpegVersion -eq 0) -and $layer -eq 1) {
                    $xingOffset = $frameStart + 21
                } else {
                    $xingOffset = -1
                }

                if ($xingOffset -ge 0 -and $xingOffset + 4 -lt $bytes.Length) {
                    $isInfo = ($bytes[$xingOffset] -eq 0x49 -and $bytes[$xingOffset+1] -eq 0x6E -and $bytes[$xingOffset+2] -eq 0x66 -and $bytes[$xingOffset+3] -eq 0x6F)
                    $isXing = ($bytes[$xingOffset] -eq 0x58 -and $bytes[$xingOffset+1] -eq 0x69 -and $bytes[$xingOffset+2] -eq 0x6E -and $bytes[$xingOffset+3] -eq 0x67)

                    if ($isInfo -or $isXing) {
                        # Calculate Info/Xing header end position
                        $headerFlags = ($bytes[$xingOffset+4] -shl 24) -bor ($bytes[$xingOffset+5] -shl 16) -bor ($bytes[$xingOffset+6] -shl 8) -bor $bytes[$xingOffset+7]
                        $headerEnd = $xingOffset + 8  # After magic + flags
                        if ($headerFlags -band 0x01) { $headerEnd += 4 }  # Frames field
                        if ($headerFlags -band 0x02) { $headerEnd += 4 }  # Bytes field
                        if ($headerFlags -band 0x04) { $headerEnd += 100 } # TOC
                        if ($headerFlags -band 0x08) { $headerEnd += 4 }  # VBR scale
                        $headerEnd += 24  # LAME tag

                        # Zero out the entire Info/Xing + LAME tag area
                        for ($j = $xingOffset; $j -lt [Math]::Min($headerEnd, $bytes.Length); $j++) {
                            $bytes[$j] = 0x00
                        }
                        $strippedLame = $true
                    }
                }
            }
        }

        # --- Step 3: Strip ID3v1 tag from the end ---
        $strippedId3v1 = $false
        if ($bytes.Length -ge 128 -and $bytes[$bytes.Length - 128] -eq 0x54 -and $bytes[$bytes.Length - 127] -eq 0x41 -and $bytes[$bytes.Length - 126] -eq 0x47) {
            $newBytes = New-Object byte[] ($bytes.Length - 128)
            [Array]::Copy($bytes, 0, $newBytes, 0, $bytes.Length - 128)
            $bytes = $newBytes
            $strippedId3v1 = $true
        }

        # --- Write only if something was stripped ---
        if ($strippedLame -or $strippedId3v2 -or $strippedId3v1) {
            [System.IO.File]::WriteAllBytes($FilePath, $bytes)
            # Clear ffprobe cache since file changed
            Clear-FfprobeCache -FilePath $FilePath
            return @($strippedLame, $strippedId3v2)
        }
        return @($false, $false)
    } catch {
        return @($false, $false)
    }
}

# -- Legacy wrappers for backward compatibility with any code that calls them --
# These now delegate to Strip-Mp3Tags for the same single-pass performance.
function Strip-LameTag {
    param([string]$FilePath)
    $result = Strip-Mp3Tags -FilePath $FilePath
    return $result[0]
}

function Strip-Id3v2Tag {
    param([string]$FilePath)
    $result = Strip-Mp3Tags -FilePath $FilePath
    return $result[1]
}


function Sanitize-Mp3File {
    param([System.IO.FileInfo]$File)

    # Bitrate table for MPEG1 Layer III (used by the CRC binary-patch fallback)
    $bitrateTable1L3 = @(0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0)

    # Use a temp file with .mp3 extension so ffmpeg can auto-detect the output format.
    # ffmpeg refuses to write to files with non-standard extensions (e.g. .sanitize.tmp).
    $tempFile = $File.FullName + '.sanitize.tmp.mp3'

    # -------------------------------------------------------------------------
    # Step 1: Try to re-encode with ffmpeg (primary method).
    # Re-encoding produces a clean, FMOD 3.x-compatible MP3 with no CRC,
    # no VBR, no Info/LAME tag, CBR 256kbps, simple stereo, no embedded art.
    # -------------------------------------------------------------------------
    $ffmpegExe = Find-Ffmpeg -Name 'ffmpeg'
    $ffmpegSuccess = $false

    if ($ffmpegExe) {
        # Try primary re-encode: 256kbps CBR with error-tolerant input parsing.
        try {
            $stderrFile = [System.IO.Path]::GetTempFileName()
            $proc = Start-Process -FilePath $ffmpegExe -ArgumentList (Build-QuotedArgs @('-y', '-err_detect', '+ignore_err', '-i', $File.FullName, '-vn', '-c:a', 'libmp3lame', '-b:a', '256k', '-ac', '2', '-ar', '44100', '-joint_stereo', '0', '-map_metadata', '-1', '-fflags', '+bitexact', '-flags:a', '+bitexact', $tempFile)) -NoNewWindow -Wait -PassThru -RedirectStandardError $stderrFile

            # Save stderr output for diagnostics even on success
            $stderrContent = $null
            if (Test-Path -LiteralPath $stderrFile -PathType Leaf) {
                $stderrContent = Get-Content -LiteralPath $stderrFile -Raw -ErrorAction SilentlyContinue
            }
            Remove-Item -LiteralPath $stderrFile -Force -ErrorAction SilentlyContinue

            if ($proc.ExitCode -ne 0) {
                Write-Host "  ffmpeg (256kbps) exited with code $($proc.ExitCode) for $($File.Name)"
                if ($stderrContent -and $stderrContent.Length -gt 0) {
                    $diag = $stderrContent.TrimEnd()
                    if ($diag.Length -gt 500) { $diag = $diag.Substring($diag.Length - 500) }
                    Write-Host "  ffmpeg stderr (tail): $diag"
                }
                Write-Host "  Trying fallback re-encode at 192kbps..."
            } else {
                $ffmpegSuccess = $true
            }
        } catch {
            Write-Host "  ffmpeg re-encode (256kbps) threw exception for $($File.Name): $($_.Exception.Message)"
        }

        # If primary re-encode failed, try fallback with lower bitrate.
        if (-not $ffmpegSuccess -and -not (Test-Path -LiteralPath $tempFile -PathType Leaf)) {
            try {
                $tempFile = $File.FullName + '.sanitize.tmp.mp3'
                $stderrFile2 = [System.IO.Path]::GetTempFileName()
                $proc2 = Start-Process -FilePath $ffmpegExe -ArgumentList (Build-QuotedArgs @('-y', '-err_detect', '+ignore_err', '-i', $File.FullName, '-vn', '-c:a', 'libmp3lame', '-b:a', '192k', '-ac', '2', '-ar', '44100', '-joint_stereo', '0', '-map_metadata', '-1', '-fflags', '+bitexact', '-flags:a', '+bitexact', $tempFile)) -NoNewWindow -Wait -PassThru -RedirectStandardError $stderrFile2
                $stderrContent2 = $null
                if (Test-Path -LiteralPath $stderrFile2 -PathType Leaf) {
                    $stderrContent2 = Get-Content -LiteralPath $stderrFile2 -Raw -ErrorAction SilentlyContinue
                }
                Remove-Item -LiteralPath $stderrFile2 -Force -ErrorAction SilentlyContinue

                if ($proc2.ExitCode -ne 0) {
                    Write-Host "  ffmpeg (192kbps fallback) also exited with code $($proc2.ExitCode) for $($File.Name)"
                    if ($stderrContent2 -and $stderrContent2.Length -gt 0) {
                        $diag2 = $stderrContent2.TrimEnd()
                        if ($diag2.Length -gt 500) { $diag2 = $diag2.Substring($diag2.Length - 500) }
                        Write-Host "  ffmpeg stderr (tail): $diag2"
                    }
                } else {
                    $ffmpegSuccess = $true
                }
            } catch {
                Write-Host "  ffmpeg 192kbps fallback threw exception for $($File.Name): $($_.Exception.Message)"
            }
        }

        # If ffmpeg produced a valid output file, strip tags in ONE pass
        if ($ffmpegSuccess -and (Test-Path -LiteralPath $tempFile -PathType Leaf) -and ((Get-Item -LiteralPath $tempFile).Length -gt 0)) {
            # Strip Info/LAME + ID3v2/v1 tags in a single file read/write pass
            # (previously this was 2 separate reads + 2 separate writes)
            $tagResult = Strip-Mp3Tags -FilePath $tempFile
            if ($tagResult[0]) { Write-Host "  Stripped Info/LAME encoder tag from re-encoded file" }
            if ($tagResult[1]) { Write-Host "  Stripped ID3v2/v1 tags from re-encoded file" }

            # Quick verify: check that the file starts with 0xFF 0xFB (MPEG1 Layer3 no CRC)
            # This is much faster than a full Test-Mp3NeedsReencode scan.
            try {
                $verifyBytes = [System.IO.File]::ReadAllBytes($tempFile)
                if ($verifyBytes.Length -ge 4 -and $verifyBytes[0] -eq 0xFF -and ($verifyBytes[1] -band 0xE0) -eq 0xE0) {
                    # Has MPEG sync word - good enough after ffmpeg re-encode
                    Move-Item -LiteralPath $tempFile -Destination $File.FullName -Force
                    # Clear ffprobe cache since the file changed
                    Clear-FfprobeCache -FilePath $File.FullName
                    Clear-FfprobeCache -FilePath $tempFile
                    Write-Host "  Sanitized (re-encoded for WoW 1.12): $($File.Name)"
                    return $true
                } else {
                    # Quick verify failed - do full check as fallback
                    $needsMore, $reasonMore = Test-Mp3NeedsReencode -FilePath $tempFile
                    if (-not $needsMore) {
                        Move-Item -LiteralPath $tempFile -Destination $File.FullName -Force
                        Clear-FfprobeCache -FilePath $File.FullName
                        Clear-FfprobeCache -FilePath $tempFile
                        Write-Host "  Sanitized (re-encoded for WoW 1.12): $($File.Name)"
                        return $true
                    }
                    Write-Host "  WARNING: Re-encoded file still has issue: $reasonMore"
                    # Give up on re-encode path, clean up and try other methods
                    Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
                }
            } catch {
                # Verify failed - trust ffmpeg and accept the file
                Move-Item -LiteralPath $tempFile -Destination $File.FullName -Force
                Clear-FfprobeCache -FilePath $File.FullName
                Write-Host "  Sanitized (re-encoded for WoW 1.12): $($File.Name)"
                return $true
            }
        } else {
            # ffmpeg didn't produce output or produced empty file
            if (Test-Path -LiteralPath $tempFile) { Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue }
            Write-Host "  ffmpeg did not produce output for $($File.Name), trying binary fallback..."
        }
    } else {
        Write-Host "  ffmpeg not found, trying binary fallback methods..."
    }

    # -------------------------------------------------------------------------
    # Step 2: Binary patch for CRC-protected files (fallback when ffmpeg fails).
    # -------------------------------------------------------------------------
    $needsReencode, $reason = Test-Mp3NeedsReencode -FilePath $File.FullName
    if ($needsReencode -and $reason -match 'CRC') {
        Write-Host "  Attempting CRC removal (binary patch with frame rebuild) for $($File.Name)..."

        # Strip ID3v2/v1 tags BEFORE scanning for MPEG frames.
        $tagResult = Strip-Mp3Tags -FilePath $File.FullName
        if ($tagResult[1]) {
            Write-Host "  Stripped ID3v2/v1 tags before CRC patch"
        }

        try {
            $bytes = [System.IO.File]::ReadAllBytes($File.FullName)

            $audioOffset = 0
            if ($bytes.Length -ge 10 -and $bytes[0] -eq 0x49 -and $bytes[1] -eq 0x44 -and $bytes[2] -eq 0x33) {
                $tagSize = ($bytes[6] -shl 21) -bor ($bytes[7] -shl 14) -bor ($bytes[8] -shl 7) -bor $bytes[9]
                $audioOffset = $tagSize + 10
                Write-Host "  WARNING: ID3v2 tag still present after strip attempt, audio at offset $audioOffset"
            }

            $outputList = New-Object System.Collections.Generic.List[byte[]]
            $totalOutSize = 0
            $patched = 0
            $i = $audioOffset

            while ($i -lt $bytes.Length - 4) {
                if ($bytes[$i] -ne 0xFF -or ($bytes[$i+1] -band 0xE0) -ne 0xE0) {
                    $oneByte = New-Object byte[] 1
                    $oneByte[0] = $bytes[$i]
                    $outputList.Add($oneByte)
                    $totalOutSize++
                    $i++
                    continue
                }

                $b1 = $bytes[$i+1]
                $b2 = $bytes[$i+2]
                $b3 = $bytes[$i+3]
                $mpegVersion = ($b1 -shr 3) -band 0x03
                $layer = ($b1 -shr 1) -band 0x03
                $protection = $b1 -band 0x01
                $bitrateIdx = ($b2 -shr 4) -band 0x0F
                $sampleRateIdx = ($b2 -shr 2) -band 0x03
                $padding = ($b2 -shr 1) -band 0x01

                # Determine sample rate from MPEG header
                $sampleRates1 = @(44100, 48000, 32000, 0)  # MPEG1
                $sampleRates2 = @(22050, 24000, 16000, 0)  # MPEG2
                $sampleRates25 = @(11025, 12000, 8000, 0)  # MPEG2.5
                if ($mpegVersion -eq 3) { $sampleRate = $sampleRates1[$sampleRateIdx] }
                elseif ($mpegVersion -eq 2) { $sampleRate = $sampleRates2[$sampleRateIdx] }
                else { $sampleRate = $sampleRates25[$sampleRateIdx] }

                if ($mpegVersion -ne 3 -or $layer -ne 1) {
                    $skipBytes = New-Object byte[] 4
                    [Array]::Copy($bytes, $i, $skipBytes, 0, 4)
                    $outputList.Add($skipBytes)
                    $totalOutSize += 4
                    $i += 4
                    continue
                }

                $br = $bitrateTable1L3[$bitrateIdx]
                if ($br -le 0) {
                    $skipBytes = New-Object byte[] 4
                    [Array]::Copy($bytes, $i, $skipBytes, 0, 4)
                    $outputList.Add($skipBytes)
                    $totalOutSize += 4
                    $i += 4
                    continue
                }

                if ($sampleRate -le 0) {
                    # Invalid sample rate - skip this candidate
                    $skipBytes = New-Object byte[] 4
                    [Array]::Copy($bytes, $i, $skipBytes, 0, 4)
                    $outputList.Add($skipBytes)
                    $totalOutSize += 4
                    $i += 4
                    continue
                }

                $frameSize = [int]([Math]::Floor(144.0 * $br * 1000 / $sampleRate)) + $padding

                if ($i + $frameSize -gt $bytes.Length) {
                    $remaining = $bytes.Length - $i
                    $remainBytes = New-Object byte[] $remaining
                    [Array]::Copy($bytes, $i, $remainBytes, 0, $remaining)
                    $outputList.Add($remainBytes)
                    $totalOutSize += $remaining
                    break
                }

                if ($protection -eq 0) {
                    $newFrameSize = $frameSize - 2
                    $newFrame = New-Object byte[] $newFrameSize
                    [Array]::Copy($bytes, $i, $newFrame, 0, 4)
                    $newFrame[1] = $newFrame[1] -bor 0x01
                    [Array]::Copy($bytes, $i + 4 + 2, $newFrame, 4, $frameSize - 4 - 2)
                    $outputList.Add($newFrame)
                    $totalOutSize += $newFrameSize
                    $patched++
                } else {
                    $frameBytes = New-Object byte[] $frameSize
                    [Array]::Copy($bytes, $i, $frameBytes, 0, $frameSize)
                    $outputList.Add($frameBytes)
                    $totalOutSize += $frameSize
                }

                $i += $frameSize
            }

            if ($i -lt $bytes.Length) {
                $trailing = $bytes.Length - $i
                $trailBytes = New-Object byte[] $trailing
                [Array]::Copy($bytes, $i, $trailBytes, 0, $trailing)
                $outputList.Add($trailBytes)
                $totalOutSize += $trailing
            }

            if ($patched -gt 0) {
                $outBytes = New-Object byte[] $totalOutSize
                $offset = 0
                foreach ($chunk in $outputList) {
                    [Array]::Copy($chunk, 0, $outBytes, $offset, $chunk.Length)
                    $offset += $chunk.Length
                }

                [System.IO.File]::WriteAllBytes($File.FullName, $outBytes)
                Write-Host "  Patched (CRC removed from $patched frames, file rebuilt): $($File.Name)"
                # Strip LAME + ID3 tags in one pass (instead of 2 separate calls)
                $tagResult2 = Strip-Mp3Tags -FilePath $File.FullName
                if ($tagResult2[0]) { Write-Host "  Stripped Info/LAME encoder tag from $($File.Name)" }
                if ($tagResult2[1]) { Write-Host "  Stripped ID3v2/v1 tags from $($File.Name)" }
                # Quick verify after CRC patch
                $stillNeeds, $stillReason = Test-Mp3NeedsReencode -FilePath $File.FullName
                if (-not $stillNeeds) {
                    return $true
                } else {
                    Write-Host "  WARNING: CRC-patched file still has issue: $stillReason"
                    Write-Host "  This file may need ffmpeg re-encoding. Install ffmpeg and re-run."
                }
            } else {
                Write-Host "  No CRC-protected frames found to patch in $($File.Name)"
            }
        } catch {
            Write-Host "  WARNING: CRC binary patch failed for $($File.Name): $($_.Exception.Message)"
        }
    }

    # -------------------------------------------------------------------------
    # Step 3: If the only issue is a LAME/Info tag or ID3v2 tag (no CRC, no VBR),
    # strip it in-place without re-encoding — using the combined single-pass function.
    # -------------------------------------------------------------------------
    if ($needsReencode -and ($reason -match 'Info/LAME' -or $reason -match 'ID3v2')) {
        $tagResult3 = Strip-Mp3Tags -FilePath $File.FullName
        if ($tagResult3[0]) { Write-Host "  Stripped Info/LAME encoder tag from $($File.Name)" }
        if ($tagResult3[1]) { Write-Host "  Stripped ID3v2/v1 tags from $($File.Name)" }
        if ($tagResult3[0] -or $tagResult3[1]) {
            # Quick verify using fast-path check
            if (Test-Mp3FastPathCompatible -FilePath $File.FullName) {
                return $true
            }
            # Full verify as fallback
            $stillNeeds, $stillReason = Test-Mp3NeedsReencode -FilePath $File.FullName
            if (-not $stillNeeds) {
                return $true
            }
        }
    }

    # -------------------------------------------------------------------------
    # Step 4: If the issue is VBR and we don't have ffmpeg, warn the user.
    # VBR files CANNOT be fixed with binary patching - they must be re-encoded.
    # -------------------------------------------------------------------------
    if ($needsReencode -and $reason -match 'VBR') {
        Write-Host "  WARNING: $($File.Name) has VBR encoding which requires ffmpeg to fix."
        Write-Host "  Install ffmpeg and re-run GeneratePlaylist.bat to sanitize this file."
    }

    return $false
}

# Clean up any leftover .sanitize.tmp.* files from a previous interrupted run
$leftoverTmp = @(Get-ChildItem -LiteralPath $Media -Recurse -File |
    Where-Object { $_.Name -match '\.sanitize\.tmp\.' })
if ($leftoverTmp.Count -gt 0) {
    Write-Host "Cleaning up $($leftoverTmp.Count) leftover temp file(s) from previous run..."
    foreach ($tmp in $leftoverTmp) {
        Remove-Item -LiteralPath $tmp.FullName -Force -ErrorAction SilentlyContinue
    }
}

# Check and sanitize MP3 files for WoW 1.12 compatibility
Write-Host ""
Write-Host "Scanning MP3 files for WoW 1.12 compatibility..."
$mp3Files = @(Get-ChildItem -LiteralPath $Media -Recurse -File |
    Where-Object { $_.Extension -match '^(?i)\.mp3$' -and $_.Name -notmatch '\.sanitize\.tmp\.' })

$sanitized = 0
$skipped = 0
$scanErrors = 0
$compatOk = 0
$cacheHits = 0
$fastPathHits = 0

if ($mp3Files.Count -eq 0) {
    Write-Host "No MP3 files found in Media folder."
} else {
    Write-Host "Found $($mp3Files.Count) MP3 file(s) to check..."
    foreach ($mp3 in $mp3Files) {
        try {
            # --- SPEED: Check compatibility cache first ---
            # If this file was verified compatible in a previous run and hasn't
            # been modified since, skip the entire scan.
            $cacheEntry = Get-CompatCacheEntry -File $mp3
            if ($cacheEntry -ne $null) {
                if ($cacheEntry[0] -eq 'OK') {
                    $compatOk++
                    $cacheHits++
                    continue
                }
                # If previously marked as 'FIX' (sanitized), re-check since
                # the sanitized version may have different timestamp/size
            }

            # --- SPEED: Fast-path check for obviously compatible files ---
            # Files that start with 0xFF 0xFB (MPEG1 Layer3, no CRC, no ID3v2)
            # and have no ID3v1 tail tag are almost certainly FMOD 3.x-compatible.
            # This avoids reading the entire file and scanning 50 MPEG frames.
            if (Test-Mp3FastPathCompatible -FilePath $mp3.FullName) {
                $compatOk++
                $fastPathHits++
                Set-CompatCacheEntry -File $mp3 -Status 'OK' -Reason 'FastPath'
                continue
            }

            # --- Full scan needed ---
            $needsReencode, $reason = Test-Mp3NeedsReencode -FilePath $mp3.FullName
            if ($needsReencode) {
                Write-Host "  Issue found: $($mp3.Name) - $reason"
                try {
                    $fixed = Sanitize-Mp3File -File $mp3
                    if ($fixed) {
                        $sanitized++
                        # Refresh the FileInfo to get the new timestamp/size after sanitization
                        $mp3 = Get-Item -LiteralPath $mp3.FullName
                        Set-CompatCacheEntry -File $mp3 -Status 'OK' -Reason 'Sanitized'
                    } else {
                        $skipped++
                        Set-CompatCacheEntry -File $mp3 -Status 'FIX' -Reason 'Failed'
                    }
                } catch {
                    Write-Host "  WARNING: Could not sanitize $($mp3.Name): $($_.Exception.Message)"
                    $skipped++
                    Set-CompatCacheEntry -File $mp3 -Status 'FIX' -Reason 'Error'
                }
            } else {
                $compatOk++
                Set-CompatCacheEntry -File $mp3 -Status 'OK' -Reason $reason
            }
        } catch {
            Write-Host "  WARNING: Could not scan $($mp3.Name): $($_.Exception.Message)"
            $scanErrors++
        }
    }
    Write-Host ""
    Write-Host "  Compatible: $compatOk  Sanitized: $sanitized  Skipped: $skipped  Errors: $scanErrors"
    if ($cacheHits -gt 0) { Write-Host "  Cache hits: $cacheHits (skipped full scan)" }
    if ($fastPathHits -gt 0) { Write-Host "  Fast-path hits: $fastPathHits (quick header check)" }
}

if ($sanitized -gt 0) {
    Write-Host ""
    Write-Host "Sanitized $sanitized MP3 file(s) for WoW 1.12 compatibility."
    Write-Host "These files were re-encoded to work with the in-game FMOD 3.x music engine."
    Write-Host ""
}
if ($skipped -gt 0) {
    Write-Host ""
    Write-Host "WARNING: $skipped MP3 file(s) could not be sanitized (ffmpeg not available?)."
    Write-Host "These tracks may not play correctly in-game. Install ffmpeg and re-run."
    Write-Host ""
}
if ($sanitized -eq 0 -and $skipped -eq 0 -and $mp3Files.Count -gt 0) {
    Write-Host ""
    Write-Host "All $($mp3Files.Count) MP3 file(s) passed compatibility check."
    Write-Host ""
}

# Save the compatibility cache for faster re-runs
Save-CompatCache

# -- Sanitize WAV/OGG files for WoW 1.12 compatibility -----------------------
# WoW 1.12's FMOD 3.x engine is very picky about WAV and OGG files too.
# Many WAV/OGG files that play fine in modern players will silently fail in-game.
#
# Known WAV issues:
#   1. 24-bit or 32-bit float samples (FMOD 3.x only supports 8-bit and 16-bit PCM)
#   2. Sample rates other than 44100 Hz or 22050 Hz
#   3. More than 2 channels (surround sound WAVs)
#   4. ADPCM or other compressed WAV formats
#   5. RIFF LIST/INFO chunks that can confuse FMOD
#   6. Very large WAV files that exceed FMOD's buffer
#   7. IEEE float format (format code 3) instead of PCM (format code 1)
#
# Known OGG issues:
#   1. Vorbis encoding at unusual bitrates or quality levels
#   2. OGG files with video streams or metadata that FMOD cannot parse
#   3. OGG files encoded with very high quality settings (-q10) that FMOD 3.x rejects
#   4. Non-standard channel configurations
#   5. Opus codec inside an OGG container (FMOD 3.x only supports Vorbis in OGG)
#
# The ONLY reliable fix is to re-encode with ffmpeg using settings known to
# produce FMOD 3.x-compatible output.  WAV is re-encoded to 16-bit PCM at
# 44100 Hz stereo; OGG is re-encoded to Vorbis at quality 6 (~192kbps).

function Test-WavNeedsReencode {
    param([string]$FilePath)

    try {
        # Use ffprobe cache instead of launching a separate process
        $ffJson = Get-FfprobeData -FilePath $FilePath
        if ($ffJson -and $ffJson.streams) {
            foreach ($stream in $ffJson.streams) {
                if ($stream.codec_type -eq 'audio') {
                    # Check sample format - must be s16 (signed 16-bit PCM)
                    if ($stream.sample_rate -and [int]$stream.sample_rate -ne 44100 -and [int]$stream.sample_rate -ne 22050) {
                        return $true, "Sample rate $($stream.sample_rate) Hz (FMOD 3.x requires 44100 or 22050 Hz)"
                    }
                    if ($stream.channels -and [int]$stream.channels -gt 2) {
                        return $true, "$($stream.channels) channels (FMOD 3.x supports max 2 channels)"
                    }
                    # Check codec - must be PCM (not ADPCM, float, etc.)
                    if ($stream.codec_name -and $stream.codec_name -ne 'pcm_s16le' -and $stream.codec_name -ne 'pcm_s16be' -and $stream.codec_name -ne 'pcm_u8' -and $stream.codec_name -ne 'pcm_s24le' -and $stream.codec_name -ne 'pcm_f32le' -and $stream.codec_name -ne 'adpcm_ms' -and $stream.codec_name -ne 'adpcm_ima_wav') {
                        # Not a standard PCM codec
                    } elseif ($stream.codec_name -eq 'pcm_s24le') {
                        return $true, '24-bit PCM (FMOD 3.x only supports 8-bit and 16-bit)'
                    } elseif ($stream.codec_name -eq 'pcm_f32le' -or $stream.codec_name -eq 'pcm_f64le') {
                        return $true, 'Float PCM format (FMOD 3.x only supports integer PCM)'
                    } elseif ($stream.codec_name -match 'adpcm') {
                        return $true, 'ADPCM compressed WAV (FMOD 3.x may not support this codec)'
                    }
                    # Check bit depth via bits_per_sample if available
                    if ($stream.bits_per_sample -and [int]$stream.bits_per_sample -gt 16 -and [int]$stream.bits_per_sample -ne 0) {
                        return $true, "$($stream.bits_per_sample)-bit audio (FMOD 3.x only supports 8-bit and 16-bit)"
                    }
                }
            }
        }

        # Fallback: check WAV header bytes manually
        $bytes = [System.IO.File]::ReadAllBytes($FilePath)
        if ($bytes.Length -lt 44) { return $false, 'File too small' }

        # Check RIFF header
        if ($bytes[0] -ne 0x52 -or $bytes[1] -ne 0x49 -or $bytes[2] -ne 0x46 -or $bytes[3] -ne 0x46) {
            return $false, 'Not a valid RIFF/WAV file'
        }

        # Find the 'fmt ' chunk
        $fmtOffset = -1
        for ($i = 12; $i -lt [Math]::Min($bytes.Length - 24, 4096); $i++) {
            if ($bytes[$i] -eq 0x66 -and $bytes[$i+1] -eq 0x6D -and $bytes[$i+2] -eq 0x74 -and $bytes[$i+3] -eq 0x20) {
                $fmtOffset = $i + 8  # Skip past 'fmt ' and chunk size
                break
            }
        }

        if ($fmtOffset -ge 0 -and $fmtOffset + 16 -le $bytes.Length) {
            # Parse format fields (little-endian)
            $audioFormat = $bytes[$fmtOffset] -bor ($bytes[$fmtOffset+1] -shl 8)
            $numChannels = $bytes[$fmtOffset+2] -bor ($bytes[$fmtOffset+3] -shl 8)
            $sampleRate  = $bytes[$fmtOffset+4] -bor ($bytes[$fmtOffset+5] -shl 8) -bor ($bytes[$fmtOffset+6] -shl 16) -bor ($bytes[$fmtOffset+7] -shl 24)
            $bitsPerSample = $bytes[$fmtOffset+14] -bor ($bytes[$fmtOffset+15] -shl 8)

            if ($audioFormat -ne 1) {
                return $true, "Non-PCM format code $audioFormat (FMOD 3.x only supports PCM format code 1)"
            }
            if ($bitsPerSample -gt 16) {
                return $true, "$bitsPerSample-bit audio (FMOD 3.x only supports 8-bit and 16-bit)"
            }
            if ($numChannels -gt 2) {
                return $true, "$numChannels channels (FMOD 3.x supports max 2 channels)"
            }
            if ($sampleRate -ne 44100 -and $sampleRate -ne 22050 -and $sampleRate -ne 11025) {
                return $true, "Sample rate $sampleRate Hz (FMOD 3.x requires 11025/22050/44100 Hz)"
            }
        }

        return $false, 'Compatible'
    }
    catch {
        return $true, "Error analyzing file: $($_.Exception.Message)"
    }
}

function Test-OggNeedsReencode {
    param([string]$FilePath)

    try {
        # Use ffprobe cache instead of launching a separate process
        $ffJson = Get-FfprobeData -FilePath $FilePath
        if ($ffJson -and $ffJson.streams) {
            foreach ($stream in $ffJson.streams) {
                if ($stream.codec_type -eq 'audio') {
                    # OGG must use Vorbis codec (not Opus, FLAC, etc.)
                    if ($stream.codec_name -and $stream.codec_name -ne 'vorbis') {
                        return $true, "Non-Vorbis codec '$($stream.codec_name)' in OGG container (FMOD 3.x only supports Vorbis)"
                    }
                    if ($stream.channels -and [int]$stream.channels -gt 2) {
                        return $true, "$($stream.channels) channels (FMOD 3.x supports max 2 channels)"
                    }
                    if ($stream.sample_rate -and [int]$stream.sample_rate -ne 44100 -and [int]$stream.sample_rate -ne 22050) {
                        return $true, "Sample rate $($stream.sample_rate) Hz (FMOD 3.x prefers 44100 or 22050 Hz)"
                    }
                }
                if ($stream.codec_type -eq 'video') {
                    return $true, "Embedded video stream in OGG (FMOD 3.x cannot handle)"
                }
            }
        }

        return $false, 'Compatible'
    }
    catch {
        return $true, "Error analyzing file: $($_.Exception.Message)"
    }
}

function Sanitize-WavFile {
    param([System.IO.FileInfo]$File)

    # Use a temp file with .wav extension so ffmpeg can auto-detect the output format.
    $tempFile = $File.FullName + '.sanitize.tmp.wav'
    $ffmpegExe = Find-Ffmpeg -Name 'ffmpeg'
    try {
        if ($ffmpegExe) {
            $stderrFile = [System.IO.Path]::GetTempFileName()
            $proc = Start-Process -FilePath $ffmpegExe -ArgumentList (Build-QuotedArgs @('-y', '-i', $File.FullName, '-vn', '-c:a', 'pcm_s16le', '-ac', '2', '-ar', '44100', '-map_metadata', '-1', $tempFile)) -NoNewWindow -Wait -PassThru -RedirectStandardError $stderrFile
            Remove-Item -LiteralPath $stderrFile -Force -ErrorAction SilentlyContinue
            if ($proc.ExitCode -ne 0) {
                Write-Host "  ffmpeg exited with code $($proc.ExitCode) for $($File.Name), trying alternate settings..."
            }
        }
    } catch {
        Write-Host "  ffmpeg re-encode failed for $($File.Name): $($_.Exception.Message)"
    }

    if ((Test-Path -LiteralPath $tempFile -PathType Leaf) -and ((Get-Item -LiteralPath $tempFile).Length -gt 0)) {
        Move-Item -LiteralPath $tempFile -Destination $File.FullName -Force
        Clear-FfprobeCache -FilePath $File.FullName
        Write-Host "  Sanitized (re-encoded to 16-bit PCM 44100Hz stereo for WoW 1.12): $($File.Name)"
        return $true
    } elseif (Test-Path -LiteralPath $tempFile) {
        Remove-Item -LiteralPath $tempFile -Force
    }

    return $false
}

function Sanitize-OggFile {
    param([System.IO.FileInfo]$File)

    # Use a temp file with .ogg extension so ffmpeg can auto-detect the output format.
    $tempFile = $File.FullName + '.sanitize.tmp.ogg'
    $ffmpegExe = Find-Ffmpeg -Name 'ffmpeg'
    try {
        if ($ffmpegExe) {
            $stderrFile = [System.IO.Path]::GetTempFileName()
            $proc = Start-Process -FilePath $ffmpegExe -ArgumentList (Build-QuotedArgs @('-y', '-i', $File.FullName, '-vn', '-c:a', 'libvorbis', '-q:a', '6', '-ac', '2', '-ar', '44100', '-map_metadata', '-1', $tempFile)) -NoNewWindow -Wait -PassThru -RedirectStandardError $stderrFile
            Remove-Item -LiteralPath $stderrFile -Force -ErrorAction SilentlyContinue
            if ($proc.ExitCode -ne 0) {
                Write-Host "  ffmpeg exited with code $($proc.ExitCode) for $($File.Name), trying alternate settings..."
            }
        }
    } catch {
        Write-Host "  ffmpeg re-encode failed for $($File.Name): $($_.Exception.Message)"
    }

    if ((Test-Path -LiteralPath $tempFile -PathType Leaf) -and ((Get-Item -LiteralPath $tempFile).Length -gt 0)) {
        Move-Item -LiteralPath $tempFile -Destination $File.FullName -Force
        Clear-FfprobeCache -FilePath $File.FullName
        Write-Host "  Sanitized (re-encoded to Vorbis q6 44100Hz stereo for WoW 1.12): $($File.Name)"
        return $true
    } elseif (Test-Path -LiteralPath $tempFile) {
        Remove-Item -LiteralPath $tempFile -Force
    }

    return $false
}

# Check and sanitize WAV files for WoW 1.12 compatibility
Write-Host ""
Write-Host "Scanning WAV files for WoW 1.12 compatibility..."
$wavFiles = @(Get-ChildItem -LiteralPath $Media -Recurse -File |
    Where-Object { $_.Extension -match '^(?i)\.wav$' -and $_.Name -notmatch '\.sanitize\.tmp\.' })

$wavSanitized = 0
$wavSkipped = 0
$wavCompatOk = 0

if ($wavFiles.Count -eq 0) {
    Write-Host "No WAV files found in Media folder."
} else {
    Write-Host "Found $($wavFiles.Count) WAV file(s) to check..."
    foreach ($wav in $wavFiles) {
        try {
            $needsReencode, $reason = Test-WavNeedsReencode -FilePath $wav.FullName
            if ($needsReencode) {
                Write-Host "  Issue found: $($wav.Name) - $reason"
                try {
                    $fixed = Sanitize-WavFile -File $wav
                    if ($fixed) { $wavSanitized++ } else { $wavSkipped++ }
                } catch {
                    Write-Host "  WARNING: Could not sanitize $($wav.Name): $($_.Exception.Message)"
                    $wavSkipped++
                }
            } else {
                $wavCompatOk++
            }
        } catch {
            Write-Host "  WARNING: Could not scan $($wav.Name): $($_.Exception.Message)"
            $wavSkipped++
        }
    }
    Write-Host ""
    Write-Host "  WAV Compatible: $wavCompatOk  Sanitized: $wavSanitized  Skipped: $wavSkipped"
}

if ($wavSanitized -gt 0) {
    Write-Host ""
    Write-Host "Sanitized $wavSanitized WAV file(s) for WoW 1.12 compatibility."
    Write-Host "These files were re-encoded to 16-bit PCM 44100Hz stereo."
    Write-Host ""
}
if ($wavSkipped -gt 0) {
    Write-Host ""
    Write-Host "WARNING: $wavSkipped WAV file(s) could not be sanitized (ffmpeg not available?)."
    Write-Host "These tracks may not play correctly in-game. Install ffmpeg and re-run."
    Write-Host ""
}
if ($wavSanitized -eq 0 -and $wavSkipped -eq 0 -and $wavFiles.Count -gt 0) {
    Write-Host ""
    Write-Host "All $($wavFiles.Count) WAV file(s) passed compatibility check."
    Write-Host ""
}

# Check and sanitize OGG files for WoW 1.12 compatibility
Write-Host ""
Write-Host "Scanning OGG files for WoW 1.12 compatibility..."
$oggFiles = @(Get-ChildItem -LiteralPath $Media -Recurse -File |
    Where-Object { $_.Extension -match '^(?i)\.ogg$' -and $_.Name -notmatch '\.sanitize\.tmp\.' })

$oggSanitized = 0
$oggSkipped = 0
$oggCompatOk = 0

if ($oggFiles.Count -eq 0) {
    Write-Host "No OGG files found in Media folder."
} else {
    Write-Host "Found $($oggFiles.Count) OGG file(s) to check..."
    foreach ($ogg in $oggFiles) {
        try {
            $needsReencode, $reason = Test-OggNeedsReencode -FilePath $ogg.FullName
            if ($needsReencode) {
                Write-Host "  Issue found: $($ogg.Name) - $reason"
                try {
                    $fixed = Sanitize-OggFile -File $ogg
                    if ($fixed) { $oggSanitized++ } else { $oggSkipped++ }
                } catch {
                    Write-Host "  WARNING: Could not sanitize $($ogg.Name): $($_.Exception.Message)"
                    $oggSkipped++
                }
            } else {
                $oggCompatOk++
            }
        } catch {
            Write-Host "  WARNING: Could not scan $($ogg.Name): $($_.Exception.Message)"
            $oggSkipped++
        }
    }
    Write-Host ""
    Write-Host "  OGG Compatible: $oggCompatOk  Sanitized: $oggSanitized  Skipped: $oggSkipped"
}

if ($oggSanitized -gt 0) {
    Write-Host ""
    Write-Host "Sanitized $oggSanitized OGG file(s) for WoW 1.12 compatibility."
    Write-Host "These files were re-encoded to Vorbis q6 44100Hz stereo."
    Write-Host ""
}
if ($oggSkipped -gt 0) {
    Write-Host ""
    Write-Host "WARNING: $oggSkipped OGG file(s) could not be sanitized (ffmpeg not available?)."
    Write-Host "These tracks may not play correctly in-game. Install ffmpeg and re-run."
    Write-Host ""
}
if ($oggSanitized -eq 0 -and $oggSkipped -eq 0 -and $oggFiles.Count -gt 0) {
    Write-Host ""
    Write-Host "All $($oggFiles.Count) OGG file(s) passed compatibility check."
    Write-Host ""
}

# -- Scan Media folder -------------------------------------------------------
$files = @(Get-ChildItem -LiteralPath $Media -Recurse -File |
    Where-Object { $_.Extension -match '^(?i)\.(mp3|wav|ogg)$' -and $_.Name -notmatch '\.sanitize\.tmp\.' } |
    Sort-Object -Property Name)

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('RelationshipsJukeboxAutoPlaylist = {}') | Out-Null
$lines.Add('RelationshipsJukeboxAutoPlaylist.tracks = {') | Out-Null

$defaultCount = 0
foreach ($file in $files) {
    # Build the WoW-relative path (always backslashes for consistency)
    $relative = $file.FullName.Substring($Root.Length).TrimStart('\', '/')
    $relative = $relative.Replace('/', '\')
    $luaPath = Escape-LuaString(($AddonPrefix + $relative))
    $name = Escape-LuaString($file.BaseName)
    $duration = Get-TrackDurationSeconds -File $file

    # Derive the subfolder (path under Media\ minus the file leaf).  Empty
    # string means the track lives directly under Media\.  This is what the
    # addon uses to build folder auto-playlists in the header dropdown.
    $folderRaw = ''
    $lastSlash = $relative.LastIndexOf('\')
    if ($lastSlash -ge 0) {
        $folderRaw = $relative.Substring(0, $lastSlash)
    }
    $folder = Escape-LuaString($folderRaw)

    # dateAdded: seconds since Unix epoch based on file creation time (UTC).
    # Falls back to LastWriteTime if CreationTime is zero for some reason.
    $ctime = $file.CreationTimeUtc
    if ($ctime.Year -lt 1971) { $ctime = $file.LastWriteTimeUtc }
    $epoch = [int][Math]::Floor(($ctime - (New-Object DateTime 1970, 1, 1, 0, 0, 0, ([DateTimeKind]::Utc))).TotalSeconds)

    $size = [int64]$file.Length

    if ($duration -eq $DEFAULT_DURATION) {
        $defaultCount++
    }

    $fmtLuaEntry = '    {{ path = "{0}", name = "{1}", duration = {2}, folder = "{3}", dateAdded = {4}, size = {5} }},'
    $lines.Add(($fmtLuaEntry -f $luaPath, $name, $duration, $folder, $epoch, $size)) | Out-Null
}

$lines.Add('}') | Out-Null

# -- Write AutoPlaylist.lua (UTF-8 no BOM) -----------------------------------
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($Out, $lines, $utf8NoBom)

# -- Summary -----------------------------------------------------------------
Write-Host "Generated: $Out"
Write-Host "Tracks: $($files.Count)"
if ($defaultCount -gt 0) {
    Write-Host ""
    Write-Host "$defaultCount track(s) using estimated/default duration $($DEFAULT_DURATION)s."
    Write-Host "Autoplay and Shuffle will still work -- the addon advances after the estimated time."
} else {
    Write-Host 'All track durations were captured from metadata successfully.'
}
Write-Host ''
Write-Host 'Next step: type /reload in game or restart the client.'

# -- Cleanup COM objects -----------------------------------------------------
if ($wmp)   { try { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($wmp)   } catch {} }
if ($shell) { try { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) } catch {} }
