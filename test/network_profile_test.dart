import 'dart:io';

import 'package:expeditus/src/services/dlna/network_profile.dart';
import 'package:flutter_test/flutter_test.dart';

ProcessResult _result(int exitCode, [String stdout = '']) {
  return ProcessResult(1, exitCode, stdout, '');
}

void main() {
  test('status private quando nessuna rete è pubblica', () async {
    if (!Platform.isWindows) return;
    final service = WindowsNetworkProfileService(
      processRunner: (_, _) async => _result(0, 'private'),
    );

    expect(await service.status(), NetworkProfileStatus.private);
  });

  test('status public quando una rete è pubblica', () async {
    if (!Platform.isWindows) return;
    final service = WindowsNetworkProfileService(
      processRunner: (_, _) async => _result(0, 'public'),
    );

    expect(await service.status(), NetworkProfileStatus.public);
  });

  test('status private senza reti collegate', () async {
    if (!Platform.isWindows) return;
    final service = WindowsNetworkProfileService(
      processRunner: (_, _) async => _result(0, 'none'),
    );

    expect(await service.status(), NetworkProfileStatus.private);
  });

  test('status unavailable quando powershell fallisce', () async {
    if (!Platform.isWindows) return;
    final service = WindowsNetworkProfileService(
      processRunner: (_, _) async => _result(1, 'errore'),
    );

    expect(await service.status(), NetworkProfileStatus.unavailable);
  });

  test('status unavailable quando powershell non è eseguibile', () async {
    if (!Platform.isWindows) return;
    final service = WindowsNetworkProfileService(
      processRunner: (_, _) async => throw Exception('powershell assente'),
    );

    expect(await service.status(), NetworkProfileStatus.unavailable);
  });

  test('makePrivate esegue il comando elevato e verifica', () async {
    if (!Platform.isWindows) return;
    var privatized = false;
    var elevatedCalls = 0;
    final service = WindowsNetworkProfileService(
      processRunner: (executable, arguments) async {
        if (executable != 'powershell.exe') {
          return _result(1, 'eseguibile inatteso');
        }
        final script = arguments.join(' ');
        if (script.contains('-EncodedCommand')) {
          elevatedCalls++;
          expect(script, contains('Set-NetConnectionProfile'));
          privatized = true;
          return _result(0);
        }
        // status() call.
        return _result(0, privatized ? 'private' : 'public');
      },
    );

    expect(await service.makePrivate(), isTrue);
    expect(elevatedCalls, 1);
    expect(privatized, isTrue);
  });

  test('makePrivate non fa nulla se la rete è già privata', () async {
    if (!Platform.isWindows) return;
    var elevatedCalls = 0;
    final service = WindowsNetworkProfileService(
      processRunner: (executable, arguments) async {
        if (arguments.join(' ').contains('-EncodedCommand')) elevatedCalls++;
        return _result(0, 'private');
      },
    );

    expect(await service.makePrivate(), isTrue);
    expect(elevatedCalls, 0);
  });

  test('makePrivate fallisce se UAC viene annullato', () async {
    if (!Platform.isWindows) return;
    final service = WindowsNetworkProfileService(
      processRunner: (executable, arguments) async {
        if (arguments.join(' ').contains('-EncodedCommand')) {
          return _result(1, 'UAC annullato');
        }
        return _result(0, 'public');
      },
    );

    expect(await service.makePrivate(), isFalse);
  });
}
