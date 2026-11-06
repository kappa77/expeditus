// The 0.5.x compatible window API is still the least surprising way to set up
// a single desktop window. It is isolated here and can be replaced later.
// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/legacy.dart';

import 'src/app.dart';
import 'src/data/database.dart';
import 'src/state/app_state.dart';
import 'src/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await initializeDateFormatting('it_IT');

  try {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(1120, 760),
      minimumSize: Size(880, 560),
      center: true,
      title: 'Expeditus',
      backgroundColor: ExpeditusColors.background,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  } catch (_) {
    // A window manager failure should not prevent the app from starting.
  }

  final db = AppDatabase();
  try {
    await db.open();
    final state = AppState(db);
    await state.init();
    runApp(ExpeditusApp(state: state));
    unawaited(state.checkForUpdates());
  } catch (error, stack) {
    runApp(_FatalErrorApp(error: error, stack: stack));
  }
}

class _FatalErrorApp extends StatelessWidget {
  const _FatalErrorApp({required this.error, required this.stack});

  final Object error;
  final StackTrace stack;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: expeditusTheme(),
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Expeditus non è riuscito ad avviarsi',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$error',
                    style: const TextStyle(color: ExpeditusColors.red),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Dettagli:',
                    style: TextStyle(color: ExpeditusColors.muted),
                  ),
                  const SizedBox(height: 4),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Text(
                        '$stack',
                        style: const TextStyle(
                          color: ExpeditusColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
