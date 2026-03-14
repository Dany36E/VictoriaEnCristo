import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// Conditional import for web
import 'share_utils_stub.dart'
    if (dart.library.html) 'share_utils_web.dart';

/// ═══════════════════════════════════════════════════════════════════════════════
/// SHARE UTILS - Utilidades multiplataforma para compartir
/// ═══════════════════════════════════════════════════════════════════════════════
/// 
/// Maneja la descarga/compartir de imágenes según la plataforma:
/// - Web: Descarga el archivo usando dart:html
/// - Móvil: Usa share_plus para compartir la imagen
/// ═══════════════════════════════════════════════════════════════════════════════

class ShareUtils {
  /// Comparte o descarga una imagen según la plataforma
  static Future<bool> shareImage(Uint8List bytes, String fileName) async {
    if (kIsWeb) {
      return _downloadFileWeb(bytes, fileName);
    } else {
      return _shareFileMobile(bytes, fileName);
    }
  }

  /// Descarga el archivo en Web usando dart:html
  static Future<bool> _downloadFileWeb(Uint8List bytes, String fileName) async {
    try {
      WebDownloaderImpl.download(bytes, fileName);
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('Error descargando en web: $e');
      return false;
    }
  }

  /// Comparte el archivo en móvil usando share_plus
  static Future<bool> _shareFileMobile(Uint8List bytes, String fileName) async {
    try {
      // Obtener directorio temporal
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      
      // Escribir el archivo
      await file.writeAsBytes(bytes);
      
      // Compartir usando share_plus
      final result = await Share.shareXFiles(
        [XFile(file.path)],
        text: '✝️ Victoria en Cristo App',
      );
      
      // Limpiar archivo temporal después de un delay
      Future.delayed(const Duration(seconds: 5), () {
        if (file.existsSync()) {
          file.deleteSync();
        }
      });
      
      return result.status == ShareResultStatus.success || 
             result.status == ShareResultStatus.dismissed;
    } catch (e) {
      // ignore: avoid_print
      print('Error compartiendo en móvil: $e');
      return false;
    }
  }
}
