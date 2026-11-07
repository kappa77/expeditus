import 'dart:convert';
import 'dart:io';

import 'package:expeditus/src/data/database.dart';
import 'package:expeditus/src/models/app_update.dart';
import 'package:expeditus/src/services/update_service.dart';
import 'package:expeditus/src/state/app_state.dart';
import 'package:expeditus/src/util/app_version.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

Map<String, Object?> _releaseJson({String tag = 'v1.0.9'}) {
  return {
    'tag_name': tag,
    'name': 'Expeditus $tag',
    'body': 'Note',
    'html_url': 'https://github.com/kappa77/expeditus/releases/tag/$tag',
    'assets': [
      {
        'name': 'ExpeditusSetup-$tag.exe',
        'browser_download_url':
            'https://github.com/kappa77/expeditus/releases/download/$tag/ExpeditusSetup-$tag.exe',
        'size': 1000,
      },
    ],
  };
}

class _FakeUpdateChecker implements UpdateChecker {
  _FakeUpdateChecker(this.result);

  UpdateCheckResult result;
  int calls = 0;
  bool closed = false;

  @override
  Future<UpdateCheckResult> check({
    String? etag,
    String? cachedBody,
    bool bypassCache = false,
  }) async {
    calls++;
    return result;
  }

  @override
  void close() {
    closed = true;
  }
}

UpdateCheckResult _newerResult() {
  final json = _releaseJson();
  final release = AppRelease.fromJson(json);
  return UpdateCheckResult(
    release: release,
    isNewer: true,
    asset: release!.assetForWindows(),
    // checkedAt deve essere recente, altrimenti il test sul rate-limit
    // delle 6 ore diventa dipendente dall'orologio della macchina.
    checkedAt: DateTime.now(),
    etag: '"release-1"',
    rawBody: jsonEncode(json),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  late AppDatabase db;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('expeditus_update_state_');
    db = AppDatabase(pathOverride: p.join(temp.path, 'test.sqlite'));
    await db.open();
  });

  tearDown(() async {
    await db.close();
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  Future<AppState> createState(UpdateChecker checker) async {
    final state = AppState(
      db,
      updateChecker: checker,
      appVersion: AppVersion.parse('1.0.8'),
    );
    await state.init();
    // Let the unawaited initial feed refresh finish before the test (or the
    // next AppState) touches the temporary database.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    addTearDown(state.dispose);
    return state;
  }

  test('salva la release e la considera disponibile', () async {
    final checker = _FakeUpdateChecker(_newerResult());
    final state = await createState(checker);

    await state.checkForUpdates(manual: true);

    expect(state.hasUpdate, isTrue);
    expect(state.latestRelease!.version.canonical, '1.0.9');
    expect(state.updateLastCheck, isNotNull);
    expect(state.updateError, isNull);
    expect(state.updateFromCache, isFalse);
    expect(checker.calls, 1);

    final settings = await db.getSettings();
    expect(settings['updateEtag'], '"release-1"');
    expect(settings['updateCachedRelease'], isNotEmpty);
  });

  test('la versione saltata resta nascosta e viene ripristinata', () async {
    final checker = _FakeUpdateChecker(_newerResult());
    final state = await createState(checker);
    await state.checkForUpdates(manual: true);
    await state.skipUpdateVersion();

    expect(state.hasUpdate, isFalse);
    expect(state.updateSkipped, isTrue);

    await state.clearSkippedUpdateVersion();
    expect(state.hasUpdate, isTrue);
    expect(state.updateSkipped, isFalse);
  });

  test('la release in cache viene mostrata al riavvio', () async {
    final first = await createState(_FakeUpdateChecker(_newerResult()));
    await first.checkForUpdates(manual: true);
    await first.skipUpdateVersion();

    final second = await createState(_FakeUpdateChecker(_newerResult()));
    expect(second.latestRelease!.version.canonical, '1.0.9');
    expect(second.hasUpdate, isFalse);
    expect(second.updateSkipped, isTrue);

    await second.clearSkippedUpdateVersion();
    expect(second.hasUpdate, isTrue);
  });

  test(
    'il controllo automatico è limitato a sei ore, quello manuale no',
    () async {
      final checker = _FakeUpdateChecker(_newerResult());
      final state = await createState(checker);

      await state.checkForUpdates(manual: true);
      expect(checker.calls, 1);

      await state.checkForUpdates();
      expect(checker.calls, 1);

      await state.checkForUpdates(manual: true);
      expect(checker.calls, 2);
    },
  );

  test('un errore non interrompe l’app e viene esposto', () async {
    final checker = _FakeUpdateChecker(
      UpdateCheckResult(checkedAt: DateTime.now(), error: 'offline'),
    );
    final state = await createState(checker);

    await state.checkForUpdates(manual: true);

    expect(state.updateChecking, isFalse);
    expect(state.updateError, 'offline');
    expect(state.hasUpdate, isFalse);
    expect(state.latestRelease, isNull);
  });

  test('una release più vecchia non è un aggiornamento', () async {
    final json = _releaseJson(tag: 'v1.0.7');
    final release = AppRelease.fromJson(json)!;
    final checker = _FakeUpdateChecker(
      UpdateCheckResult(
        release: release,
        isNewer: false,
        checkedAt: DateTime.now(),
        rawBody: jsonEncode(json),
      ),
    );
    final state = await createState(checker);

    await state.checkForUpdates(manual: true);

    expect(state.hasUpdate, isFalse);
    expect(state.latestRelease!.version.canonical, '1.0.7');
  });
}
