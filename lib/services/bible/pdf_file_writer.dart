import 'dart:io';

import 'package:path_provider/path_provider.dart';

abstract final class PdfFileWriter {
  static Future<File> write({
    required List<int> bytes,
    required String fileName,
    required String appSubfolder,
    required bool saveToDownloads,
  }) async {
    if (saveToDownloads) {
      final downloads = await _downloadsDirectory();
      if (downloads != null) {
        try {
          return await _writeInDirectory(downloads, fileName, bytes);
        } catch (_) {
          // En algunos celulares Android la carpeta pública existe pero el
          // sistema bloquea la escritura directa; caemos al espacio de la app.
        }
      }
    }
    return _writeInDirectory(
      await _appDocumentsDirectory(appSubfolder),
      fileName,
      bytes,
    );
  }

  static Future<File> _writeInDirectory(
    Directory directory,
    String fileName,
    List<int> bytes,
  ) async {
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final file = File('${directory.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<Directory> _appDocumentsDirectory(String subfolder) async {
    final dir = await getApplicationDocumentsDirectory();
    return Directory('${dir.path}${Platform.pathSeparator}$subfolder');
  }

  static Future<Directory?> _downloadsDirectory() async {
    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) return downloads;
    } catch (_) {}

    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null && userProfile.trim().isNotEmpty) {
        return Directory('$userProfile${Platform.pathSeparator}Downloads');
      }
      final drive = Platform.environment['HOMEDRIVE'];
      final path = Platform.environment['HOMEPATH'];
      if (drive != null && path != null) {
        return Directory('$drive$path${Platform.pathSeparator}Downloads');
      }
    }

    if (Platform.isAndroid) {
      final publicDownloads = Directory('/storage/emulated/0/Download');
      if (await publicDownloads.exists()) return publicDownloads;
      try {
        final external = await getExternalStorageDirectory();
        if (external != null) {
          return Directory(
            '${external.path}${Platform.pathSeparator}Descargas',
          );
        }
      } catch (_) {}
    }

    if (Platform.isIOS) {
      final documents = await getApplicationDocumentsDirectory();
      return Directory('${documents.path}${Platform.pathSeparator}Descargas');
    }

    return null;
  }
}
