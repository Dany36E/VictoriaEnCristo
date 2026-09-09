/// Stable HTTPS location for the public legal documents used by the app and
/// both store listings. Firebase Hosting keeps these pages independent from
/// the visibility of the source-code repository.
library;

const String kLegalBaseUrl = 'https://victoria-en-cristo.web.app';

Uri legalDocumentUri(String path) {
  final safePath = path.startsWith('/') ? path.substring(1) : path;
  return Uri.parse('$kLegalBaseUrl/$safePath');
}

String legalDocumentUrl(String path) => legalDocumentUri(path).toString();
