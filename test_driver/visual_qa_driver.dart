import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final profile = (Platform.environment['QA_DEVICE_PROFILE'] ?? 'default')
      .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  await integrationDriver(
    writeResponseOnFailure: true,
    onScreenshot: (name, bytes, [args]) async {
      final safeName = name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final directory = profile == 'default' ? 'build/qa/native' : 'build/qa/native/$profile';
      final file = File('$directory/$safeName.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
      // Capture transport only; visual quality is assessed from the saved PNG.
      return bytes.isNotEmpty;
    },
  );
}
