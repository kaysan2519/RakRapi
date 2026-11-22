import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
      final outDir = Directory('../docs/bukti/v3-pixel8');
      await outDir.create(recursive: true);
      final file = File('${outDir.path}/$name.png');
      await file.writeAsBytes(bytes, flush: true);
      return true;
    },
  );
}
