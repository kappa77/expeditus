import 'dart:io';

import 'package:expeditus/src/services/dlna/windows_firewall.dart';
import 'package:flutter_test/flutter_test.dart';

const _exe = r'C:\Apps\Expeditus\expeditus.exe';

ProcessResult _result(int exitCode, [String stdout = '']) {
  return ProcessResult(1, exitCode, stdout, '');
}

void main() {
  test('status allowed quando netsh mostra il programma', () async {
    if (!Platform.isWindows) return;
    final service = WindowsFirewallService(
      executablePath: _exe,
      processRunner: (_, _) async => _result(
        0,
        'Rule Name: Expeditus-DLNA\nEnabled: Yes\n'
        'Direction: In\nAction: Allow\nProgram: $_exe\n',
      ),
    );

    expect(await service.status(), FirewallStatus.allowed);
  });

  test('status missing quando la regola non esiste', () async {
    if (!Platform.isWindows) return;
    final service = WindowsFirewallService(
      executablePath: _exe,
      processRunner: (_, _) async => _result(1, 'No rules match'),
    );

    expect(await service.status(), FirewallStatus.missing);
  });

  test('status unavailable quando netsh non è eseguibile', () async {
    if (!Platform.isWindows) return;
    final service = WindowsFirewallService(
      executablePath: _exe,
      processRunner: (_, _) async => throw Exception('netsh assente'),
    );

    expect(await service.status(), FirewallStatus.unavailable);
  });

  test('allowExpeditus aggiunge la regola e la verifica', () async {
    if (!Platform.isWindows) return;
    var allowed = false;
    final calls = <String>[];
    final service = WindowsFirewallService(
      executablePath: _exe,
      processRunner: (executable, arguments) async {
        calls.add(executable);
        if (executable == 'netsh') {
          return allowed
              ? _result(0, 'Program: $_exe')
              : _result(1, 'No rules match');
        }
        expect(executable, 'powershell.exe');
        expect(arguments.join(' '), contains('dir=in'));
        expect(arguments.join(' '), contains('profile=any'));
        expect(arguments.join(' '), contains(_exe));
        allowed = true;
        return _result(0);
      },
    );

    expect(await service.allowExpeditus(), isTrue);
    expect(allowed, isTrue);
    expect(calls.where((call) => call == 'powershell.exe'), hasLength(1));
  });

  test('allowExpeditus fallisce se UAC viene annullato', () async {
    if (!Platform.isWindows) return;
    final service = WindowsFirewallService(
      executablePath: _exe,
      processRunner: (executable, _) async {
        if (executable == 'netsh') return _result(1, 'No rules match');
        return _result(1, 'UAC annullato');
      },
    );

    expect(await service.allowExpeditus(), isFalse);
  });

  test('non fa nulla se la regola è già presente', () async {
    if (!Platform.isWindows) return;
    var powerShellCalls = 0;
    final service = WindowsFirewallService(
      executablePath: _exe,
      processRunner: (executable, _) async {
        if (executable == 'powershell.exe') powerShellCalls++;
        return _result(0, 'Program: $_exe');
      },
    );

    expect(await service.allowExpeditus(), isTrue);
    expect(powerShellCalls, 0);
  });
}
