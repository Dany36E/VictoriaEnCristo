// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

/// Implementación web para descargar archivos
class WebDownloaderImpl {
  static void download(Uint8List bytes, String fileName) {
    // Crear Blob con los bytes de la imagen
    final blob = html.Blob([bytes], 'image/png');
    final url = html.Url.createObjectUrlFromBlob(blob);
    
    // Crear elemento <a> invisible para la descarga
    final anchor = html.AnchorElement()
      ..href = url
      ..download = fileName;
    
    // Ejecutar la descarga
    anchor.click();
    
    // Limpiar la URL después
    html.Url.revokeObjectUrl(url);
  }
}
