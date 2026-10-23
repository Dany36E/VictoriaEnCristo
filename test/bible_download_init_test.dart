import 'dart:io';

import 'package:app_quitar/models/bible/bible_version.dart';
import 'package:app_quitar/services/bible/bible_download_service.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('bible_download_init_');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  // main.dart espera a init() antes de programar las notificaciones: si init()
  // no termina (antes esperaba a la copia de RVR1960, que a su vez esperaba a
  // init()), ningún recordatorio llega a programarse.
  test('init termina en la primera ejecución y copia RVR1960 aparte', () async {
    final service = BibleDownloadService.I;
    await service.init().timeout(const Duration(seconds: 10));

    expect(service.isAvailable(BibleVersion.rvr1960), isTrue);
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (!service.isDownloaded(BibleVersion.rvr1960) &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(service.isDownloaded(BibleVersion.rvr1960), isTrue);
  });
}

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getTemporaryPath() async => path;

  @override
  Future<String?> getApplicationSupportPath() async => path;
}
