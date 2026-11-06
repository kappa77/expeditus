import 'dart:io';

enum NetworkProfileStatus { private, public, unavailable }

typedef NetworkProfileProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

/// Detects and repairs the Windows network category (Public vs Private).
///
/// SSDP discovery and the inbound media-server connections are blocked by
/// Windows Firewall when the active network is categorised as "Public":
/// the built-in *Network Discovery* rules only apply to Private networks.
/// Expeditus therefore needs the network to be "Private" so that DLNA
/// discovery can reach the TV.
abstract class NetworkProfileService {
  Future<NetworkProfileStatus> status();

  /// Switches every Public network to Private through an elevated PowerShell
  /// process (the user may cancel the UAC prompt). Returns true when no
  /// Public network remains afterwards.
  Future<bool> makePrivate();
}

class WindowsNetworkProfileService implements NetworkProfileService {
  WindowsNetworkProfileService({NetworkProfileProcessRunner? processRunner})
    : _processRunner = processRunner ?? _runProcess;

  final NetworkProfileProcessRunner _processRunner;

  static const _timeout = Duration(seconds: 30);

  @override
  Future<NetworkProfileStatus> status() async {
    if (!Platform.isWindows) return NetworkProfileStatus.private;
    try {
      final result = await _processRunner('powershell.exe', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        _statusScript,
      ]).timeout(_timeout);
      if (result.exitCode != 0) return NetworkProfileStatus.unavailable;
      final output = '${result.stdout}'.trim().toLowerCase();
      if (output.contains('public')) return NetworkProfileStatus.public;
      // "private" or "none" (no connected network): nothing to repair.
      return NetworkProfileStatus.private;
    } on Object {
      return NetworkProfileStatus.unavailable;
    }
  }

  @override
  Future<bool> makePrivate() async {
    if (!Platform.isWindows) return true;
    final current = await status();
    if (current == NetworkProfileStatus.private) return true;
    if (current == NetworkProfileStatus.unavailable) return false;

    try {
      final result = await _processRunner('powershell.exe', [
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        _makePrivateScript,
      ]).timeout(const Duration(minutes: 2));
      if (result.exitCode != 0) return false;
    } on Object {
      return false;
    }
    return await status() == NetworkProfileStatus.private;
  }

  /// Reports "public" when at least one connected network is Public. A
  /// Domain network is trusted like a Private one.
  static const _statusScript = r'''
$profiles = @(Get-NetConnectionProfile -ErrorAction SilentlyContinue)
if ($profiles.Count -eq 0) { Write-Output 'none'; exit 0 }
$categories = @($profiles | ForEach-Object { $_.NetworkCategory })
if ($categories -contains 'Public') { Write-Output 'public' } else { Write-Output 'private' }
''';

  /// The elevated command is base64-encoded inside the outer script to avoid
  /// nested quoting issues, then executed through a UAC prompt.
  static const _makePrivateScript = r'''
$command = @'
Get-NetConnectionProfile -ErrorAction SilentlyContinue |
  Where-Object { $_.NetworkCategory -eq 'Public' } |
  ForEach-Object { Set-NetConnectionProfile -InterfaceIndex $_.InterfaceIndex -NetworkCategory Private -ErrorAction SilentlyContinue }
'@
$encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
$process = Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Verb RunAs -WindowStyle Hidden -Wait -PassThru -ArgumentList @('-NoProfile','-NonInteractive','-EncodedCommand',$encoded)
exit $process.ExitCode
''';

  static Future<ProcessResult> _runProcess(
    String executable,
    List<String> arguments,
  ) {
    return Process.run(executable, arguments, runInShell: false);
  }
}
