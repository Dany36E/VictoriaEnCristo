// Google OAuth loopback flow para Windows desktop.
//
// Firebase Auth en Windows no soporta `signInWithProvider`, por lo tanto
// implementamos manualmente el flujo OAuth 2.0 (PKCE-less authorization code
// + Desktop client) y luego pasamos el `id_token` resultante a
// `FirebaseAuth.signInWithCredential`.
//
// Requisitos previos (1 vez por proyecto en Google Cloud Console):
//   1. Credenciales → Crear credenciales → ID de cliente OAuth
//   2. Tipo: "Aplicación de escritorio"
//   3. Copiar Client ID y Client secret en las constantes de abajo.
//
// El `client_secret` para Desktop apps NO es realmente secreto (Google lo
// documenta así). Es seguro incluirlo en el binario.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class WindowsGoogleOAuth {
  /// Client ID de tipo "Aplicación de escritorio" creado en
  /// https://console.cloud.google.com/apis/credentials?project=victoria-en-cristo
  static const String desktopClientId = String.fromEnvironment(
    'GOOGLE_DESKTOP_CLIENT_ID',
    defaultValue: '',
  );

  static const String desktopClientSecret = String.fromEnvironment(
    'GOOGLE_DESKTOP_CLIENT_SECRET',
    defaultValue: '',
  );

  /// `true` si las credenciales de Desktop están configuradas en compile time.
  static bool get isConfigured =>
      desktopClientId.isNotEmpty && desktopClientSecret.isNotEmpty;

  static const _authEndpoint = 'https://accounts.google.com/o/oauth2/v2/auth';
  static const _tokenEndpoint = 'https://oauth2.googleapis.com/token';
  static const _scopes = 'openid email profile';

  /// Resultado: id_token + access_token de Google. Lanza [WindowsGoogleOAuthError]
  /// en caso de fallo.
  static Future<GoogleOAuthTokens> obtainTokens() async {
    if (!isConfigured) {
      throw const WindowsGoogleOAuthError(
        'Falta configurar GOOGLE_DESKTOP_CLIENT_ID / SECRET. '
        'Recompila con --dart-define=GOOGLE_DESKTOP_CLIENT_ID=... '
        '--dart-define=GOOGLE_DESKTOP_CLIENT_SECRET=...',
      );
    }

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    final redirectUri = 'http://127.0.0.1:$port';
    final state = _randomString(24);

    debugPrint('🪟 [WIN-OAUTH] Loopback listening on $redirectUri');

    final authUrl = Uri.parse(_authEndpoint).replace(queryParameters: {
      'client_id': desktopClientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': _scopes,
      'state': state,
      'access_type': 'offline',
      'prompt': 'select_account',
    });

    debugPrint('🪟 [WIN-OAUTH] Opening browser...');
    final launched = await launchUrl(
      authUrl,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      await server.close(force: true);
      throw const WindowsGoogleOAuthError('No se pudo abrir el navegador.');
    }

    // Esperar callback (timeout 5 min).
    final completer = Completer<HttpRequest>();
    late StreamSubscription sub;
    sub = server.listen((req) {
      if (!completer.isCompleted) completer.complete(req);
    });

    HttpRequest req;
    try {
      req = await completer.future.timeout(const Duration(minutes: 5));
    } on TimeoutException {
      await sub.cancel();
      await server.close(force: true);
      throw const WindowsGoogleOAuthError('Timeout esperando autorización.');
    }
    await sub.cancel();

    final params = req.uri.queryParameters;
    final returnedState = params['state'];
    final code = params['code'];
    final error = params['error'];

    // Responder al navegador con una página bonita.
    final ok = error == null && code != null && returnedState == state;
    req.response
      ..statusCode = 200
      ..headers.contentType = ContentType.html
      ..write(_callbackHtml(ok));
    await req.response.close();
    await server.close(force: true);

    if (error != null) {
      throw WindowsGoogleOAuthError('Google devolvió error: $error');
    }
    if (returnedState != state) {
      throw const WindowsGoogleOAuthError('State mismatch (posible CSRF).');
    }
    if (code == null) {
      throw const WindowsGoogleOAuthError('No se recibió authorization code.');
    }

    debugPrint('🪟 [WIN-OAUTH] Code received, exchanging for tokens...');

    final resp = await http.post(
      Uri.parse(_tokenEndpoint),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'code': code,
        'client_id': desktopClientId,
        'client_secret': desktopClientSecret,
        'redirect_uri': redirectUri,
        'grant_type': 'authorization_code',
      },
    );

    if (resp.statusCode != 200) {
      throw WindowsGoogleOAuthError(
        'Token exchange falló (${resp.statusCode}): ${resp.body}',
      );
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final idToken = json['id_token'] as String?;
    final accessToken = json['access_token'] as String?;
    if (idToken == null || accessToken == null) {
      throw const WindowsGoogleOAuthError(
        'Respuesta de Google sin id_token/access_token.',
      );
    }

    debugPrint('🪟 [WIN-OAUTH] Tokens obtenidos ✓');
    return GoogleOAuthTokens(idToken: idToken, accessToken: accessToken);
  }

  static String _randomString(int len) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final r = Random.secure();
    return List.generate(len, (_) => chars[r.nextInt(chars.length)]).join();
  }

  static String _callbackHtml(bool ok) {
    final title = ok ? '¡Listo!' : 'Hubo un problema';
    final msg = ok
        ? 'Inicio de sesión con Google completado.<br>Ya puedes volver a Victoria en Cristo.'
        : 'No se pudo completar el inicio de sesión.<br>Vuelve a la app e intenta de nuevo.';
    return '''
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8">
<title>Victoria en Cristo</title>
<style>
  body { margin:0; height:100vh; display:flex; align-items:center; justify-content:center;
         font-family:-apple-system,Segoe UI,Roboto,sans-serif;
         background:linear-gradient(135deg,#0D1B2A,#1B2838); color:#fff; }
  .card { text-align:center; padding:48px 56px; border-radius:24px;
          background:rgba(255,255,255,0.06); border:1px solid rgba(212,175,55,0.4);
          box-shadow:0 12px 40px rgba(0,0,0,0.4); max-width:480px; }
  h1 { color:#D4AF37; margin:0 0 12px; font-size:26px; }
  p  { margin:0; line-height:1.5; opacity:0.9; }
</style>
</head>
<body>
  <div class="card">
    <h1>$title</h1>
    <p>$msg</p>
  </div>
  <script>setTimeout(()=>window.close(),1500);</script>
</body>
</html>
''';
  }
}

class GoogleOAuthTokens {
  final String idToken;
  final String accessToken;
  const GoogleOAuthTokens({required this.idToken, required this.accessToken});
}

class WindowsGoogleOAuthError implements Exception {
  final String message;
  const WindowsGoogleOAuthError(this.message);
  @override
  String toString() => message;
}
