import 'package:expeditus/src/util/app_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizza prefisso, build metadata e zeri finali', () {
    expect(AppVersion.tryParse('v1.0.8')?.canonical, '1.0.8');
    expect(AppVersion.tryParse('1.0.8+10')?.canonical, '1.0.8');
    expect(AppVersion.tryParse('1.0')?.canonical, '1.0');
    expect(AppVersion.parse('1.0'), AppVersion.parse('1.0.0'));
    expect(AppVersion.tryParse(''), isNull);
    expect(AppVersion.tryParse('abc'), isNull);
  });

  test('confronta versioni numeriche e prerelease', () {
    expect(
      AppVersion.parse('1.0.10').isNewerThan(AppVersion.parse('1.0.9')),
      isTrue,
    );
    expect(
      AppVersion.parse('1.0.9').isNewerThan(AppVersion.parse('1.0.10')),
      isFalse,
    );
    expect(
      AppVersion.parse('1.0.9').isNewerThan(AppVersion.parse('1.0.9-beta.1')),
      isTrue,
    );
    expect(
      AppVersion.parse('1.0.9-beta.2')
          .isNewerThan(AppVersion.parse('1.0.9-beta.1')),
      isTrue,
    );
    expect(
      AppVersion.parse('1.0.9-2').isNewerThan(AppVersion.parse('1.0.9-1')),
      isTrue,
    );
  });

  test('ignora il build number nel confronto e nell’hash', () {
    final a = AppVersion.parse('1.0.8+9');
    final b = AppVersion.parse('1.0.8+10');
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a.compareTo(b), 0);
  });
}
