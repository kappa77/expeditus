import 'dart:convert';
import 'dart:io';

enum FirewallStatus { allowed, missing, unavailable }

typedef FirewallProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

/// Manages the inbound Windows Firewall rule that lets a DLNA renderer reach
/// the local media server.
abstract class FirewallService {
  Future<FirewallStatus> status();

  /// Adds the rule through an elevated `netsh` process. Returns true when the
  /// rule is present afterwards (the user may cancel the UAC prompt).
  Future<bool> allowExpeditus();
}

class WindowsFirewallService implements FirewallService {
  WindowsFirewallService({
    String? ruleName,
    this.executablePath,
    FirewallProcessRunner? processRunner,
  }) : ruleName =
           ruleName ??
           _ruleNameFor(executablePath ?? Platform.resolvedExecutable),
       _processRunner = processRunner ?? _runProcess;

  final String ruleName;
  final String? executablePath;
  final FirewallProcessRunner _processRunner;

  static const _timeout = Duration(seconds: 30);

  /// A separate rule per executable path avoids conflicts between debug,
  /// release and installed builds.
  static String _ruleNameFor(String path) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(path.toLowerCase())) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return 'Expeditus-DLNA-${hash.toRadixString(16).padLeft(8, '0')}';
  }

  String get _executable => executablePath ?? Platform.resolvedExecutable;

  @override
  Future<FirewallStatus> status() async {
    if (!Platform.isWindows) return FirewallStatus.allowed;
    try {
      final result = await _processRunner('netsh', [
        'advfirewall',
        'firewall',
        'show',
        'rule',
        'name=$ruleName',
      ]).timeout(_timeout);
      if (result.exitCode != 0) return FirewallStatus.missing;
      final output = '${result.stdout}'.toLowerCase().replaceAll('/', '\\');
      final program = _executable.toLowerCase().replaceAll('/', '\\');
      return output.contains(program)
          ? FirewallStatus.allowed
          : FirewallStatus.missing;
    } on Object {
      return FirewallStatus.unavailable;
    }
  }

  @override
  Future<bool> allowExpeditus() async {
    if (!Platform.isWindows) return true;
    final current = await status();
    if (current == FirewallStatus.allowed) return true;
    if (current == FirewallStatus.unavailable) return false;

    try {
      final script = _elevatedAddScript();
      final result = await _processRunner('powershell.exe', [
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        script,
      ]).timeout(const Duration(minutes: 2));
      if (result.exitCode != 0) return false;
    } on Object {
      return false;
    }
    return await status() == FirewallStatus.allowed;
  }

  static Future<ProcessResult> _runProcess(
    String executable,
    List<String> arguments,
  ) {
    return Process.run(executable, arguments, runInShell: false);
  }

  String _elevatedAddScript() {
    final exe = _executable.replaceAll("'", "''");
    // The rule allows inbound connections to this executable on every port
    // and profile. It is scoped to Expeditus and only added after an explicit
    // user action and the Windows UAC confirmation.
    return '''
\$arguments = @(
  'advfirewall',
  'firewall',
  'add',
  'rule',
  'name=$ruleName',
  'dir=in',
  'action=allow',
  'program="$exe"',
  'enable=yes',
  'profile=any',
  'protocol=any'
)
\$process = Start-Process -FilePath "\$env:SystemRoot\\System32\\netsh.exe" -Verb RunAs -WindowStyle Hidden -Wait -PassThru -ArgumentList \$arguments
exit \$process.ExitCode
''';
  }
}
