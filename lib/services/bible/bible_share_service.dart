import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../../models/bible/bible_verse.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// BIBLE SHARE SERVICE
/// Compartir versículos como texto o imagen.
/// La pantalla TemplatePickerScreen usa ShareCardRenderer para el preview
/// y captura con RepaintBoundary internamente.
/// ═══════════════════════════════════════════════════════════════════════════
class BibleShareService {
  BibleShareService._();

  /// Compartir como texto plano
  static Future<void> shareAsText(BibleVerse verse) async {
    final text = '"${verse.text}"\n— ${verse.reference} (${verse.version})';
    await Share.share(text);
  }

  /// Compartir como imagen usando un GlobalKey del widget renderizado
  static Future<void> shareAsImage(GlobalKey repaintKey) async {
    try {
      final boundary = repaintKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/victoria_verse.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Victoria en Cristo',
      );
    } catch (e) {
      debugPrint('📖 [SHARE] Error sharing image: $e');
    }
  }
}

