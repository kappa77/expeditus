param(
    [switch]$SkipFlutterBuild,
    [string]$MakensisPath = "",
    [string]$Version = "",
    [string]$Build = ""
)

$ErrorActionPreference = "Stop"

$repo = Split-Path -Parent $PSScriptRoot
Set-Location $repo

# Version from pubspec.yaml, e.g. 1.0.0+1 -> 1.0.0 and 1.
if ([string]::IsNullOrWhiteSpace($Version) -or [string]::IsNullOrWhiteSpace($Build)) {
    $pubspec = Get-Content (Join-Path $repo "pubspec.yaml") -Raw
    $match = [regex]::Match($pubspec, '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)\s*$')
    if (-not $match.Success) {
        throw "Cannot read version from pubspec.yaml"
    }
    if ([string]::IsNullOrWhiteSpace($Version)) { $Version = $match.Groups[1].Value }
    if ([string]::IsNullOrWhiteSpace($Build)) { $Build = $match.Groups[2].Value }
}
$version = $Version
$build = $Build

if (-not $SkipFlutterBuild) {
    Write-Host "[..] flutter build windows --release"
    & flutter build windows --release "--dart-define=APP_VERSION=$version"
    if ($LASTEXITCODE -ne 0) {
        throw "flutter build failed with exit code $LASTEXITCODE"
    }
}

if ([string]::IsNullOrWhiteSpace($MakensisPath)) {
    $candidates = @(
        (Join-Path $env:ProgramFiles "NSIS\makensis.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "NSIS\makensis.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\NSIS\makensis.exe")
    )
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            $MakensisPath = $candidate
            break
        }
    }
    if ([string]::IsNullOrWhiteSpace($MakensisPath)) {
        $command = Get-Command makensis.exe -ErrorAction SilentlyContinue
        if ($command) {
            $MakensisPath = $command.Source
        }
    }
}

if ([string]::IsNullOrWhiteSpace($MakensisPath) -or -not (Test-Path $MakensisPath)) {
    throw "makensis.exe not found. Install NSIS 3 (https://nsis.sourceforge.io/) or pass -MakensisPath."
}

$releaseDir = Join-Path $repo "build\windows\x64\runner\Release"
if (-not (Test-Path $releaseDir)) {
    throw "Release build not found: $releaseDir"
}

# The Flutter Windows runner links the MSVC runtime dynamically. Bundle the
# redistributable DLLs app-local so the installer does not require a separate
# Visual C++ Redistributable installation.
$runtimeDlls = @("msvcp140.dll", "vcruntime140.dll", "vcruntime140_1.dll")
$vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
$vsPath = $null
if (Test-Path $vswhere) {
    $vsPath = (& $vswhere -latest -products * -property installationPath) | Select-Object -First 1
}
foreach ($dll in $runtimeDlls) {
    $target = Join-Path $releaseDir $dll
    if (Test-Path $target) { continue }
    $found = $null
    if (-not [string]::IsNullOrWhiteSpace($vsPath)) {
        $redist = Join-Path $vsPath "VC\Redist\MSVC"
        if (Test-Path $redist) {
            $found = Get-ChildItem -Path $redist -Filter $dll -Recurse -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -match '\\x64\\' } |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1
        }
    }
    if (-not $found) {
        $systemDll = Join-Path $env:WINDIR "System32\$dll"
        if (Test-Path $systemDll) { $found = Get-Item $systemDll }
    }
    if (-not $found) {
        throw "Cannot find $dll. Install the Visual C++ redistributable/build tools, or use a release folder that already contains it."
    }
    Copy-Item $found.FullName $target -Force
    Write-Host "[ok] bundled $dll"
}

$dist = Join-Path $repo "dist"
New-Item -ItemType Directory -Force -Path $dist | Out-Null
$nsi = Join-Path $repo "installer\expeditus.nsi"

Write-Host "[..] makensis $nsi (version $version, build $build)"
& $MakensisPath "/DAPP_VERSION=$version" "/DAPP_BUILD=$build" $nsi
if ($LASTEXITCODE -ne 0) {
    throw "makensis failed with exit code $LASTEXITCODE"
}

$setup = Join-Path $dist "ExpeditusSetup-$version.exe"
if (-not (Test-Path $setup)) {
    throw "Installer not found: $setup"
}

# SHA-256 without relying on Get-FileHash (missing on some PS installs).
$sha = [System.Security.Cryptography.SHA256]::Create()
$stream = [System.IO.File]::OpenRead($setup)
try {
    $bytes = $sha.ComputeHash($stream)
} finally {
    $stream.Dispose()
    $sha.Dispose()
}
$hash = ([System.BitConverter]::ToString($bytes) -replace '-', '').ToLowerInvariant()
$sums = Join-Path $dist "SHA256SUMS.txt"
"$hash  $(Split-Path -Leaf $setup)" | Set-Content -Encoding ascii $sums

Write-Host ""
Write-Host "[ok] $setup"
Write-Host "[ok] $sums"
