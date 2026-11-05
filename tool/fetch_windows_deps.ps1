# Fetches the prebuilt libmpv/ANGLE archives required by media_kit on Windows.
# The media_kit CMake step checks these files' MD5 and extracts them into
# build/windows/x64. Running this before `flutter build windows` / `flutter test`
# avoids a flaky direct download from GitHub releases.

$ErrorActionPreference = "Stop"

$repo = Split-Path -Parent $PSScriptRoot
$dest = Join-Path $repo "build\windows\x64"
New-Item -ItemType Directory -Force -Path $dest | Out-Null

function Get-Md5 {
    param([Parameter(Mandatory = $true)][string]$Path)

    # Get-FileHash is missing on some constrained PowerShell installs.
    $algorithm = [System.Security.Cryptography.MD5]::Create()
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $bytes = $algorithm.ComputeHash($stream)
    } finally {
        $stream.Dispose()
        $algorithm.Dispose()
    }
    return ([System.BitConverter]::ToString($bytes) -replace '-', '').ToLowerInvariant()
}

function Get-VerifiedAsset {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$DirectUrl,
        [Parameter(Mandatory = $true)][string]$FallbackUrl,
        [Parameter(Mandatory = $true)][string]$Md5
    )

    $out = Join-Path $dest $Name
    if (Test-Path $out) {
        $current = Get-Md5 $out
        if ($current -eq $Md5.ToLowerInvariant()) {
            Write-Host "[ok] $Name already present"
            return
        }
        Remove-Item $out -Force
    }

    Write-Host "[..] $Name"
    try {
        Invoke-WebRequest -Uri $DirectUrl -OutFile $out -UseBasicParsing
    } catch {
        Write-Host "[..] direct download failed, trying mirror"
        Invoke-WebRequest -Uri $FallbackUrl -OutFile $out -UseBasicParsing
    }

    $hash = Get-Md5 $out
    if ($hash -ne $Md5.ToLowerInvariant()) {
        Remove-Item $out -Force
        throw "MD5 mismatch for $Name (got $hash, expected $Md5)"
    }
    Write-Host "[ok] $Name"
}

Get-VerifiedAsset `
    -Name "mpv-dev-x86_64-20230924-git-652a1dd.7z" `
    -DirectUrl "https://github.com/media-kit/libmpv-win32-video-build/releases/download/2023-09-24/mpv-dev-x86_64-20230924-git-652a1dd.7z" `
    -FallbackUrl "https://gh-proxy.com/https://github.com/media-kit/libmpv-win32-video-build/releases/download/2023-09-24/mpv-dev-x86_64-20230924-git-652a1dd.7z" `
    -Md5 "a832ef24b3a6ff97cd2560b5b9d04cd8"

Get-VerifiedAsset `
    -Name "ANGLE.7z" `
    -DirectUrl "https://github.com/alexmercerind/flutter-windows-ANGLE-OpenGL-ES/releases/download/v1.0.1/ANGLE.7z" `
    -FallbackUrl "https://github.com/alexmercerind/flutter-windows-ANGLE-OpenGL-ES/releases/download/v1.0.1/ANGLE.7z" `
    -Md5 "e866f13e8d552348058afaafe869b1ed"

Write-Host ""
Write-Host "Dependencies ready in $dest"
