param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z0-9._:-]+$')]
    [string] $DeviceId
)

$ErrorActionPreference = 'Stop'
$probeRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$probeOutput = Join-Path $probeRoot 'build/android-playback-probe'
$probeAdb = Join-Path $env:LOCALAPPDATA 'Android/sdk/platform-tools/adb.exe'
if (-not (Test-Path -LiteralPath $probeAdb)) {
    throw "Android SDK adb was not found at $probeAdb"
}
New-Item -ItemType Directory -Path $probeOutput -Force | Out-Null
$probeStdout = Join-Path $probeOutput 'test.out.log'
$probeStderr = Join-Path $probeOutput 'test.err.log'
$probeBackgrounded = $false
$probePlayingBackgrounded = $false
$probeLastCycle = 0
$probeExit = 1

function Invoke-ProbeAdb {
    param([string[]] $AdbArguments)
    & $probeAdb -s $DeviceId @AdbArguments
    if ($LASTEXITCODE -ne 0) {
        throw "ADB command failed: $($AdbArguments -join ' ')"
    }
}

Push-Location $probeRoot
try {
    & dart format lib/src/services/resumable_player.dart lib/src/services/stream_resolver.dart `
        lib/src/ui/player_page.dart test/resumable_player_test.dart test/stream_resolver_test.dart `
        integration_test/android_playback_test.dart integration_test/android_stream_probe_test.dart
    if ($LASTEXITCODE -ne 0) { throw 'Dart formatting failed.' }
    & flutter analyze --no-pub
    if ($LASTEXITCODE -ne 0) { throw 'Flutter analysis failed.' }
    # Run the real device test in a hidden child so this process can exercise
    # Android's actual Activity lifecycle while the Dart test is paused.
    $probeProcess = Start-Process -FilePath $env:ComSpec -ArgumentList @(
        '/d', '/c',
        "flutter test integration_test/android_playback_test.dart -d $DeviceId --dart-define=HOST_LIFECYCLE_PROBE=true"
    ) -WorkingDirectory $probeRoot -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput $probeStdout -RedirectStandardError $probeStderr

    while (-not $probeProcess.HasExited) {
        [string] $probeText = if (Test-Path -LiteralPath $probeStdout) {
            Get-Content -LiteralPath $probeStdout -Raw
        } else { '' }

        if (-not $probeBackgrounded -and $probeText -match 'phase=long-pause') {
            $probeBackgrounded = $true
            try {
                Invoke-ProbeAdb @('shell', 'am', 'start', '-a',
                    'android.intent.action.MAIN', '-c', 'android.intent.category.HOME')
                Start-Sleep -Seconds 8
            } finally {
                Invoke-ProbeAdb @('shell', 'am', 'start', '-n',
                    'com.kappa77.expeditus/.MainActivity')
            }
            Write-Output 'MOTOROLA_PROBE realBackgroundSeconds=8'
        }

        if (-not $probePlayingBackgrounded -and $probeText -match 'phase=playing-background') {
            $probePlayingBackgrounded = $true
            try {
                Invoke-ProbeAdb @('shell', 'am', 'start', '-a',
                    'android.intent.action.MAIN', '-c', 'android.intent.category.HOME')
                Start-Sleep -Seconds 8
            } finally {
                Invoke-ProbeAdb @('shell', 'am', 'start', '-n',
                    'com.kappa77.expeditus/.MainActivity')
            }
            Write-Output 'MOTOROLA_PROBE realPlayingBackgroundSeconds=8'
        }

        foreach ($probeMatch in [regex]::Matches(($probeText ?? ''),
                'PLAYBACK_PROBE cycle=(\d+) rssMiB=([\d.]+)')) {
            $probeCycle = [int] $probeMatch.Groups[1].Value
            if ($probeCycle -le $probeLastCycle) { continue }
            $probeLastCycle = $probeCycle
            Invoke-ProbeAdb @('shell', 'dumpsys', 'meminfo',
                'com.kappa77.expeditus') |
                Set-Content -LiteralPath (Join-Path $probeOutput "memory-$probeCycle.txt")
            Write-Output $probeMatch.Value
        }
        Start-Sleep -Milliseconds 500
        $probeProcess.Refresh()
    }
    $probeProcess.WaitForExit()
    $probeExit = $probeProcess.ExitCode
    Get-Content -LiteralPath $probeStdout | Select-String 'PLAYBACK_PROBE|All tests passed|failed|Exception'
    Get-Content -LiteralPath $probeStderr
} finally {
    if ($probeProcess -and -not $probeProcess.HasExited) {
        # A monitoring error must not install another APK over a running test.
        $probeProcess.WaitForExit()
    }
    # Never leave the integration-test entry point installed. Replacing the APK
    # with -r preserves the user's app data; do not uninstall or clear storage.
    # Switching from a test target to release must regenerate the plugin
    # registrant: release excludes dev-only plugins such as integration_test.
    & flutter build apk --release --target=lib/main.dart
    if ($LASTEXITCODE -ne 0) {
        throw 'The regular APK could not be built; restore the app before ending the device session.'
    }
    Invoke-ProbeAdb @('install', '-r', 'build/app/outputs/flutter-apk/app-release.apk')
    Invoke-ProbeAdb @('shell', 'am', 'start', '-n', 'com.kappa77.expeditus/.MainActivity')
    Pop-Location
}
exit $probeExit
