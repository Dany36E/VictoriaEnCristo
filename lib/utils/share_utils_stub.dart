import 'dart:typed_data';

/// Stub para plataformas no-web
class WebDownloaderImpl {
  static void download(Uint8List bytes, String fileName) {
    throw UnsupportedError('Web download is not supported on this platform');
  }
}
