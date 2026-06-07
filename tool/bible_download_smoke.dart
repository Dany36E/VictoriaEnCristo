import 'dart:io';

import 'package:app_quitar/models/bible/bible_version.dart';
import 'package:app_quitar/services/bible/bible_download_service.dart';
import 'package:flutter/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final service = BibleDownloadService.I;

  final versionsToCheck = <BibleVersion>[
    BibleVersion.nvi,
    BibleVersion.lbla,
    BibleVersion.ntv,
    BibleVersion.tla,
  ];

  var failures = 0;
  for (final version in versionsToCheck) {
    final ok = await service.downloadVersion(version);
    final localPath = service.getLocalPath(version);
    final exists = localPath != null && await File(localPath).exists();
    final size = exists ? await File(localPath).length() : 0;

    final passed = ok && exists && size > 1024;
    if (!passed) failures++;

    print(
      '[BIBLE-SMOKE] ${version.id}: ok=$ok exists=$exists size=$size path=${localPath ?? "null"}',
    );
  }

  if (failures > 0) {
    print('[BIBLE-SMOKE] FAILURES=$failures');
    exit(1);
  }

  print('[BIBLE-SMOKE] ALL_OK');
  exit(0);
}
