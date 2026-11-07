import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Salva gli screenshot catturati dal test di integrazione in `screenshots/`.
Future<void> main() async {
  await integrationDriver(
    onScreenshot: (String name, List<int> image, [Map<String, Object?>? args]) async {
      final file = File('screenshots/$name.png');
      file.createSync(recursive: true);
      file.writeAsBytesSync(image);
      return true;
    },
  );
}
