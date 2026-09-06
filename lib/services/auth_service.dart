import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'data_bootstrapper.dart';
import '../utils/safe_log.dart';
import 'account_session_manager.dart';
import 'auth/windows_google_oauth.dart';
import '../utils/platform_capabilities.dart';

/// Región donde está desplegada la Cloud Function
/// IMPORTANTE: Debe coincidir con firebase deploy --only functions
const String kCloudFunctionRegion = 'us-central1';

/// Modelo de usuario de la app
class AppUser {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final DateTime createdAt;
  final int victoryDays;
  final DateTime? lastVictoryDate;

  AppUser({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    required this.createdAt,
    this.victoryDays = 0,
    this.lastVictoryDate,
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'],
      photoUrl: data['photoUrl'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      victoryDays: data['victoryDays'] ?? 0,
      lastVictoryDate: (data['lastVictoryDate'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'victoryDays': victoryDays,
      'lastVictoryDate': lastVictoryDate != null
          ? Timestamp.fromDate(lastVictoryDate!)
          : null,
    };
  }
}

/// Servicio de autenticación con Firebase
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Rate limit local de password reset (5 minutos por email).
  // Defensa en profundidad sobre el rate limit de Firebase backend
  // para evitar que un atacante use al usuario para spamear emails.
  static final Map<String, DateTime> _passwordResetThrottle = {};
  static const Duration _passwordResetCooldown = Duration(minutes: 5);

  // Lazy initialization para GoogleSignIn (evita error en web sin clientId)
  GoogleSignIn? _googleSignIn;
  GoogleSignIn get googleSignIn {
    _googleSignIn ??= GoogleSignIn();
    return _googleSignIn!;
  }

  GoogleAuthProvider _buildGoogleProvider() {
    return GoogleAuthProvider()
      ..addScope('email')
      ..addScope('profile')
      ..setCustomParameters({'prompt': 'select_account'});
  }

  // Usuario actual
  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  // Stream de cambios de autenticación
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Iniciar sesión con email y contraseña
  Future<AuthResult> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return AuthResult.success(credential.user!);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getErrorMessage(e.code));
    } catch (e) {
      return AuthResult.error('Error al iniciar sesión: $e');
    }
  }

  /// Registrar nuevo usuario con email
  Future<AuthResult> registerWithEmail(
    String email,
    String password,
    String name,
  ) async {
    // Política de contraseñas: mínimo 8 caracteres con al menos una letra y
    // un número. Bloqueamos contraseñas comunes obviamente débiles.
    final passwordError = _validatePassword(password);
    if (passwordError != null) {
      return AuthResult.error(passwordError);
    }
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Actualizar nombre
      await credential.user!.updateDisplayName(name);

      // Crear documento en Firestore
      await _createUserDocument(credential.user!, name);

      return AuthResult.success(credential.user!);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getErrorMessage(e.code));
    } catch (e) {
      return AuthResult.error('Error al registrarse: $e');
    }
  }

  /// Devuelve un mensaje si la contraseña no cumple la política, o null si es válida.
  String? _validatePassword(String password) {
    if (password.length < 8) {
      return 'La contraseña debe tener al menos 8 caracteres.';
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(password)) {
      return 'La contraseña debe incluir al menos una letra.';
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'La contraseña debe incluir al menos un número.';
    }
    const weak = {'12345678', 'password', '123456789', 'qwerty12', 'abc12345'};
    if (weak.contains(password.toLowerCase())) {
      return 'Esa contraseña es demasiado común. Usa una más segura.';
    }
    return null;
  }

  /// Iniciar sesión con Google
  Future<AuthResult> signInWithGoogle() async {
    try {
      if (!PlatformCapabilities.supportsGoogleSignIn) {
        return AuthResult.error(
          'Google no está disponible en ${PlatformCapabilities.currentLabel}. Usa correo y contraseña.',
        );
      }

      if (kIsWeb) {
        // Para web
        final googleProvider = _buildGoogleProvider();
        final credential = await _auth.signInWithPopup(googleProvider);
        await _createUserDocumentIfNotExists(credential.user!);
        return AuthResult.success(credential.user!);
      } else if (PlatformCapabilities.supportsFirebaseAuthProviderSignIn) {
        // Windows: Firebase Auth C++ NO soporta signInWithProvider
        // ("Operation is not supported on non-mobile systems"). Hacemos el
        // flujo OAuth manual con loopback HTTP y luego signInWithCredential.
        final tokens = await WindowsGoogleOAuth.obtainTokens();
        final credential = GoogleAuthProvider.credential(
          idToken: tokens.idToken,
          accessToken: tokens.accessToken,
        );
        final userCredential = await _auth.signInWithCredential(credential);
        final user = userCredential.user;
        if (user == null) {
          return AuthResult.error('Google no devolvió un usuario válido');
        }
        await _createUserDocumentIfNotExists(user);
        return AuthResult.success(user);
      } else {
        // Para móvil
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          return AuthResult.error('Inicio de sesión cancelado');
        }

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final userCredential = await _auth.signInWithCredential(credential);
        await _createUserDocumentIfNotExists(userCredential.user!);
        return AuthResult.success(userCredential.user!);
      }
    } catch (e) {
      return AuthResult.error('Error con Google: $e');
    }
  }

  /// Iniciar sesión con Apple en iPhone/iPad.
  ///
  /// Usa nonce SHA-256 para impedir la reutilización de credenciales y sólo
  /// conserva en Firebase los datos de perfil que Apple autoriza.
  Future<AuthResult> signInWithApple() async {
    if (!PlatformCapabilities.supportsAppleSignIn) {
      return AuthResult.error('Apple no está disponible en esta plataforma.');
    }

    try {
      final rawNonce = generateNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
      final identityToken = appleCredential.identityToken;
      if (identityToken == null || identityToken.isEmpty) {
        return AuthResult.error('Apple no devolvió una credencial válida.');
      }

      final oauthCredential = OAuthProvider(
        'apple.com',
      ).credential(idToken: identityToken, rawNonce: rawNonce);
      final userCredential = await _auth.signInWithCredential(oauthCredential);
      final user = userCredential.user;
      if (user == null) {
        return AuthResult.error('Apple no devolvió un usuario válido.');
      }

      final suppliedName =
          [appleCredential.givenName, appleCredential.familyName]
              .whereType<String>()
              .map((part) => part.trim())
              .where((part) => part.isNotEmpty)
              .join(' ');
      if ((user.displayName == null || user.displayName!.trim().isEmpty) &&
          suppliedName.isNotEmpty) {
        await user.updateDisplayName(suppliedName);
      }
      await _createUserDocumentIfNotExists(user);
      return AuthResult.success(user);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return AuthResult.error('Inicio de sesión cancelado');
      }
      return AuthResult.error('Apple no pudo completar el inicio de sesión.');
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getErrorMessage(e.code));
    } catch (e) {
      return AuthResult.error('Error con Apple: $e');
    }
  }

  /// Iniciar sesión como invitado (anónimo)
  Future<AuthResult> signInAnonymously() async {
    try {
      final credential = await _auth.signInAnonymously();

      // Crear documento básico en Firestore para usuario anónimo
      await _createUserDocument(credential.user!, 'Invitado');

      return AuthResult.success(credential.user!);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getErrorMessage(e.code));
    } catch (e) {
      return AuthResult.error('Error al iniciar como invitado: $e');
    }
  }

  /// Cerrar sesión
  /// ⚠️ IMPORTANTE: NO borra datos del usuario - solo termina la sesión
  /// Los datos se mantienen en la nube y en cache local
  Future<void> signOut() async {
    safeLog('AUTH', 'Signing out (data preserved)...');

    if (PlatformCapabilities.supportsGoogleSignInPlugin) {
      try {
        await googleSignIn.signOut();
      } catch (e) {
        safeWarn('AUTH', 'Google sign-out error (non-critical): $e');
      }
    }

    // El DataBootstrapper escucha authStateChanges y desconectará
    // los repositorios SIN borrar datos
    await _auth.signOut();

    safeLog('AUTH', 'Signed out (data preserved for next login)');
  }

  /// Cerrar sesión en TODOS los dispositivos del usuario actual.
  ///
  /// Llama a la Cloud Function `signOutAllDevices` que:
  ///  - Revoca todos los refresh tokens del uid (FirebaseAuth backend).
  ///  - Borra los documentos en `users/{uid}/fcmTokens` (max 100).
  ///
  /// Después cierra sesión local. Útil para "Cerrar sesión en todos los
  /// dispositivos" en el flujo de cuenta comprometida.
  Future<bool> signOutAllDevices() async {
    if (currentUser == null) return false;
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: kCloudFunctionRegion,
      ).httpsCallable('signOutAllDevices');
      await callable.call();
    } on FirebaseFunctionsException catch (e) {
      safeError('AUTH', 'signOutAllDevices error: ${e.code} ${e.message}');
      // Continuamos cerrando sesión local aunque la revocación remota falle.
    } catch (e) {
      safeError('AUTH', 'signOutAllDevices exception', e);
    }
    await signOut();
    return true;
  }

  /// Borrar solo cache local del dispositivo
  /// Los datos en la nube se mantienen intactos
  Future<void> clearLocalCache() async {
    safeWarn('AUTH', 'Clearing local cache only...');
    await DataBootstrapper.I.clearLocalCacheOnly();
    safeLog('AUTH', 'Local cache cleared');
  }

  /// Eliminar cuenta y TODOS los datos del usuario
  /// ⚠️ IRREVERSIBLE - Borra datos de nube y local usando Cloud Function
  ///
  /// Flujo ESTRICTO (no se miente al usuario):
  /// 1. Re-autenticar si necesario (Firebase requiere recent login)
  /// 2. Detener TODOS los listeners de Firestore (evita spam de realtime updates)
  /// 3. Hard reset memoria y widget (ANTES de intentar borrar, para no mostrar datos)
  /// 4. Llamar Cloud Function deleteUserData (borra Firestore + Auth)
  ///    - Si falla NOT_FOUND: ERROR, no afirmar éxito
  ///    - Si falla otro error: ERROR, no afirmar éxito
  /// 5. Si Cloud Function OK: limpiar cache local
  /// 6. SignOut defensivo
  /// 7. Retornar resultado REAL
  Future<DeleteAccountResult> deleteAccountAndAllData({
    String? passwordForReauth,
    bool forceGoogleReauth = false,
    bool forceAppleReauth = false,
  }) async {
    final user = currentUser;
    if (user == null) {
      return DeleteAccountResult.error('No hay sesión activa');
    }

    final uid = user.uid;
    safeWarn('AUTH', 'DELETING ACCOUNT AND ALL DATA');
    safeLog('AUTH', 'User: $uid');

    try {
      // ═══════════════════════════════════════════════════════════════════════
      // PASO 1: Re-autenticar si se proporcionaron credenciales
      // ═══════════════════════════════════════════════════════════════════════
      if (passwordForReauth != null && user.email != null) {
        safeLog('AUTH', 'Re-authenticating with email/password...');
        try {
          final credential = EmailAuthProvider.credential(
            email: user.email!,
            password: passwordForReauth,
          );
          await user.reauthenticateWithCredential(credential);
          safeLog('AUTH', 'Re-authenticated with password');
        } on FirebaseAuthException catch (e) {
          return DeleteAccountResult.error(_getErrorMessage(e.code));
        }
      }

      if (forceGoogleReauth) {
        safeLog('AUTH', 'Re-authenticating with Google...');
        try {
          final reauthResult = await _reauthenticateWithGoogle();
          if (!reauthResult.isSuccess) {
            return DeleteAccountResult.error(
              reauthResult.errorMessage ?? 'Error al re-autenticar con Google',
            );
          }
          safeLog('AUTH', 'Re-authenticated with Google');
        } catch (e) {
          return DeleteAccountResult.error(
            'Error al re-autenticar con Google: $e',
          );
        }
      }

      if (forceAppleReauth) {
        safeLog('AUTH', 'Re-authenticating with Apple...');
        final reauthResult = await _reauthenticateWithApple();
        if (!reauthResult.isSuccess) {
          return DeleteAccountResult.error(
            reauthResult.errorMessage ?? 'Error al re-autenticar con Apple',
          );
        }
        safeLog('AUTH', 'Re-authenticated with Apple');
      }

      // ═══════════════════════════════════════════════════════════════════════
      // PASO 2: Detener TODOS los listeners (evita spam de realtime updates)
      // ═══════════════════════════════════════════════════════════════════════
      safeLog('AUTH', 'Stopping all Firestore listeners...');
      await AccountSessionManager.I.stopAllSubscriptions();
      safeLog('AUTH', 'All listeners stopped');

      // ═══════════════════════════════════════════════════════════════════════
      // PASO 3: Hard reset inmediato de UI/memoria/widget
      // Esto SIEMPRE se hace para que la UI no muestre datos del usuario
      // incluso si el delete falla después
      // ═══════════════════════════════════════════════════════════════════════
      safeLog('AUTH', 'Hard resetting memory and widget...');
      await AccountSessionManager.I.hardResetForAccountDeletion();
      safeLog('AUTH', 'Memory and widget reset');

      // ═══════════════════════════════════════════════════════════════════════
      // PASO 4: Llamar Cloud Function para borrar datos
      // CRÍTICO: Especificar región correcta para evitar NOT_FOUND
      // ═══════════════════════════════════════════════════════════════════════
      safeLog(
        'AUTH',
        'Calling Cloud Function deleteUserData (region: $kCloudFunctionRegion)...',
      );

      bool cloudFunctionSuccess = false;
      String? cloudFunctionError;

      try {
        // IMPORTANTE: Usar instanceFor con región explícita
        final callable =
            FirebaseFunctions.instanceFor(
              region: kCloudFunctionRegion,
            ).httpsCallable(
              'deleteUserData',
              options: HttpsCallableOptions(
                timeout: const Duration(seconds: 60),
              ),
            );

        final result = await callable.call<Map<String, dynamic>>();
        final data = result.data;

        if (data['success'] == true) {
          safeLog('AUTH', 'Cloud Function success: ${data['message']}');
          safeLog(
            'AUTH',
            'Deleted subcollections: ${data['deletedSubcollections']}',
          );
          cloudFunctionSuccess = true;
        } else if (data['partialSuccess'] == true) {
          // Datos de Firestore eliminados; auth.deleteUser falló por error de servidor.
          // Los datos sensibles ya no existen. El usuario podría re-autenticarse pero
          // vería la app como nueva instalación (sin perfil). Tratamos como éxito del
          // flujo principal y lo registramos para monitoreo.
          safeWarn(
            'AUTH',
            'Cloud Function partial success: ${data['message']}',
          );
          safeLog(
            'AUTH',
            'Deleted subcollections: ${data['deletedSubcollections']}',
          );
          cloudFunctionSuccess = true;
        } else {
          safeWarn('AUTH', 'Cloud Function returned unexpected: $data');
          cloudFunctionError =
              data['error']?.toString() ?? 'Respuesta inesperada del servidor';
        }
      } on FirebaseFunctionsException catch (e) {
        safeError('AUTH', 'Cloud Function error: ${e.code} - ${e.message}');

        // NOT_FOUND significa que la función no existe o región incorrecta
        if (e.code == 'not-found') {
          cloudFunctionError =
              'Servicio de eliminación no disponible. '
              'Contacta soporte o intenta más tarde.';
        }
        // UNAUTHENTICATED: necesita re-login reciente
        else if (e.code == 'unauthenticated') {
          final providers = user.providerData.map((p) => p.providerId).toList();
          return DeleteAccountResult.requiresReauth(
            isGoogleAuth: providers.contains('google.com'),
            isPasswordAuth: providers.contains('password'),
            isAppleAuth: providers.contains('apple.com'),
          );
        }
        // INTERNAL: error del servidor
        else if (e.code == 'internal') {
          cloudFunctionError =
              'Error del servidor al eliminar datos: ${e.message}';
        }
        // Otros errores
        else {
          cloudFunctionError =
              'Error al eliminar datos: ${e.message ?? e.code}';
        }
      } catch (e) {
        safeError('AUTH', 'Unexpected error calling Cloud Function', e);
        cloudFunctionError = 'Error de conexión. Verifica tu internet.';
      }

      // ═══════════════════════════════════════════════════════════════════════
      // PASO 5: Si Cloud Function falló, NO afirmar éxito
      // ═══════════════════════════════════════════════════════════════════════
      if (!cloudFunctionSuccess) {
        safeError('AUTH', 'Cloud Function failed - NOT showing success');

        // SignOut para dejar la app en estado limpio
        // pero el usuario sigue existiendo en Firebase Auth
        if (PlatformCapabilities.supportsGoogleSignInPlugin) {
          try {
            await googleSignIn.signOut();
          } catch (e) {
            safeWarn('AUTH', 'Google sign-out error (non-critical): $e');
          }
        }
        await _auth.signOut();

        return DeleteAccountResult.cloudFunctionFailed(
          cloudFunctionError ?? 'No se pudo eliminar la cuenta en el servidor',
        );
      }

      // ═══════════════════════════════════════════════════════════════════════
      // PASO 6: Cloud Function OK - limpiar cache local
      // ═══════════════════════════════════════════════════════════════════════
      safeLog('AUTH', 'Cloud Function succeeded, clearing local cache...');
      await DataBootstrapper.I.clearLocalCacheOnly();

      // ═══════════════════════════════════════════════════════════════════════
      // PASO 7: SignOut defensivo (usuario ya fue eliminado por Cloud Function)
      // ═══════════════════════════════════════════════════════════════════════
      if (PlatformCapabilities.supportsGoogleSignInPlugin) {
        try {
          await googleSignIn.signOut();
        } catch (e) {
          safeWarn('AUTH', 'Google sign-out error (non-critical): $e');
        }
      }

      // El usuario ya no existe en Auth (eliminado por Cloud Function)
      // pero hacemos signOut por si acaso para forzar el authStateChange
      try {
        await _auth.signOut();
      } catch (e) {
        safeWarn('AUTH', 'Sign-out error (user may not exist): $e');
      }

      safeLog('AUTH', 'Account deletion TRULY complete');
      return DeleteAccountResult.success();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        final providers = user.providerData.map((p) => p.providerId).toList();
        return DeleteAccountResult.requiresReauth(
          isGoogleAuth: providers.contains('google.com'),
          isPasswordAuth: providers.contains('password'),
          isAppleAuth: providers.contains('apple.com'),
        );
      }
      return DeleteAccountResult.error(_getErrorMessage(e.code));
    } catch (e) {
      safeError('AUTH', 'Unexpected error', e);
      return DeleteAccountResult.error('Error al eliminar cuenta: $e');
    }
  }

  /// Re-autenticar con Google (interno)
  Future<AuthResult> _reauthenticateWithGoogle() async {
    try {
      if (!PlatformCapabilities.supportsGoogleSignIn) {
        return AuthResult.error(
          'Google no está disponible en ${PlatformCapabilities.currentLabel}.',
        );
      }

      if (PlatformCapabilities.supportsFirebaseAuthProviderSignIn) {
        await currentUser!.reauthenticateWithProvider(_buildGoogleProvider());
        return AuthResult.success(currentUser);
      }

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        return AuthResult.error('Re-autenticación cancelada');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await currentUser!.reauthenticateWithCredential(credential);
      return AuthResult.success(currentUser);
    } catch (e) {
      return AuthResult.error('Error al re-autenticar con Google: $e');
    }
  }

  /// Re-autenticar con Apple antes de una operación sensible.
  Future<AuthResult> _reauthenticateWithApple() async {
    if (!PlatformCapabilities.supportsAppleSignIn) {
      return AuthResult.error('Apple no está disponible en esta plataforma.');
    }
    try {
      final rawNonce = generateNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: const [AppleIDAuthorizationScopes.email],
        nonce: hashedNonce,
      );
      final identityToken = appleCredential.identityToken;
      if (identityToken == null || identityToken.isEmpty) {
        return AuthResult.error('Apple no devolvió una credencial válida.');
      }
      final credential = OAuthProvider(
        'apple.com',
      ).credential(idToken: identityToken, rawNonce: rawNonce);
      await currentUser!.reauthenticateWithCredential(credential);
      return AuthResult.success(currentUser);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return AuthResult.error('Re-autenticación cancelada');
      }
      return AuthResult.error('Apple no pudo verificar tu identidad.');
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getErrorMessage(e.code));
    } catch (e) {
      return AuthResult.error('Error al re-autenticar con Apple: $e');
    }
  }

  /// Restablecer contraseña
  Future<AuthResult> resetPassword(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) {
      return AuthResult.error('Ingresa un email válido.');
    }
    final last = _passwordResetThrottle[normalized];
    if (last != null) {
      final elapsed = DateTime.now().difference(last);
      if (elapsed < _passwordResetCooldown) {
        final remaining = _passwordResetCooldown - elapsed;
        final minutes = remaining.inMinutes + 1;
        return AuthResult.error(
          'Espera $minutes minuto${minutes == 1 ? '' : 's'} antes de '
          'volver a solicitar un email de recuperación.',
        );
      }
    }
    try {
      await _auth.sendPasswordResetEmail(email: normalized);
      _passwordResetThrottle[normalized] = DateTime.now();
      return AuthResult.success(null);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getErrorMessage(e.code));
    } catch (e) {
      return AuthResult.error('Error al enviar email: $e');
    }
  }

  /// Obtener datos del usuario desde Firestore
  Future<AppUser?> getUserData() async {
    if (currentUser == null) return null;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .get();
      if (doc.exists) {
        return AppUser.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Actualizar progreso del usuario
  Future<void> updateProgress({
    required int victoryDays,
    DateTime? lastVictoryDate,
  }) async {
    if (currentUser == null) return;

    await _firestore.collection('users').doc(currentUser!.uid).update({
      'victoryDays': victoryDays,
      'lastVictoryDate': lastVictoryDate != null
          ? Timestamp.fromDate(lastVictoryDate)
          : null,
    });
  }

  /// Guardar entrada de diario en la nube
  Future<void> saveJournalEntry(Map<String, dynamic> entry) async {
    if (currentUser == null) return;

    await _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('journal')
        .add(entry);
  }

  /// Obtener entradas de diario
  Future<List<Map<String, dynamic>>> getJournalEntries() async {
    if (currentUser == null) return [];

    final snapshot = await _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('journal')
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  /// Crear documento de usuario en Firestore
  /// NOTA: Las reglas de Firestore solo permiten: uid, email, displayName, photoURL, createdAt
  /// El ProfileGate se encarga de agregar onboardingCompleted y selectedGiants después
  Future<void> _createUserDocument(User user, String name) async {
    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': user.email,
      'displayName': name,
      'photoURL': user.photoURL,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Crear documento solo si no existe
  /// NOTA: Las reglas de Firestore solo permiten: uid, email, displayName, photoURL, createdAt
  Future<void> _createUserDocumentIfNotExists(User user) async {
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) {
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? 'Usuario',
        'photoURL': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Mensajes de error en español
  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No existe una cuenta con este correo';
      case 'wrong-password':
        return 'Contraseña incorrecta';
      case 'email-already-in-use':
        return 'Este correo ya está registrado';
      case 'weak-password':
        return 'La contraseña es muy débil (mínimo 6 caracteres)';
      case 'invalid-email':
        return 'El correo no es válido';
      case 'too-many-requests':
        return 'Demasiados intentos. Intenta más tarde';
      case 'network-request-failed':
        return 'Error de conexión. Verifica tu internet';
      default:
        return 'Error: $code';
    }
  }
}

/// Resultado de operación de autenticación
class AuthResult {
  final bool isSuccess;
  final User? user;
  final String? errorMessage;

  /// Indica si se necesita re-autenticación antes de continuar
  final bool requiresReauthentication;

  /// Tipo de autenticación del usuario (para saber cómo re-autenticar)
  final bool isGoogleAuth;
  final bool isPasswordAuth;

  AuthResult._({
    required this.isSuccess,
    this.user,
    this.errorMessage,
    this.requiresReauthentication = false,
    this.isGoogleAuth = false,
    this.isPasswordAuth = false,
  });

  factory AuthResult.success(User? user) {
    return AuthResult._(isSuccess: true, user: user);
  }

  factory AuthResult.error(String message) {
    return AuthResult._(isSuccess: false, errorMessage: message);
  }

  /// Indica que se necesita re-autenticación
  factory AuthResult.requiresReauth({
    required bool isGoogleAuth,
    required bool isPasswordAuth,
  }) {
    return AuthResult._(
      isSuccess: false,
      requiresReauthentication: true,
      isGoogleAuth: isGoogleAuth,
      isPasswordAuth: isPasswordAuth,
      errorMessage: 'Se requiere re-autenticación',
    );
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
/// RESULTADO DE ELIMINACIÓN DE CUENTA
/// Separado de AuthResult para tener estados más específicos
/// ═══════════════════════════════════════════════════════════════════════════
enum DeleteAccountStatus {
  /// Cuenta eliminada exitosamente (Cloud Function OK, Auth eliminado)
  success,

  /// Error genérico
  error,

  /// Cloud Function falló (NOT_FOUND, INTERNAL, etc.)
  /// El usuario sigue existiendo en Firebase Auth
  cloudFunctionFailed,

  /// Necesita re-autenticación antes de poder eliminar
  requiresReauth,
}

class DeleteAccountResult {
  final DeleteAccountStatus status;
  final String? errorMessage;
  final bool isGoogleAuth;
  final bool isPasswordAuth;
  final bool isAppleAuth;

  const DeleteAccountResult._({
    required this.status,
    this.errorMessage,
    this.isGoogleAuth = false,
    this.isPasswordAuth = false,
    this.isAppleAuth = false,
  });

  /// ✅ Eliminación exitosa (Cloud Function OK + Auth eliminado)
  factory DeleteAccountResult.success() {
    return const DeleteAccountResult._(status: DeleteAccountStatus.success);
  }

  /// ❌ Error genérico
  factory DeleteAccountResult.error(String message) {
    return DeleteAccountResult._(
      status: DeleteAccountStatus.error,
      errorMessage: message,
    );
  }

  /// ❌ Cloud Function falló - NO mostrar "eliminado correctamente"
  /// El usuario puede seguir en Firebase Auth
  factory DeleteAccountResult.cloudFunctionFailed(String message) {
    return DeleteAccountResult._(
      status: DeleteAccountStatus.cloudFunctionFailed,
      errorMessage: message,
    );
  }

  /// 🔐 Necesita re-autenticación
  factory DeleteAccountResult.requiresReauth({
    required bool isGoogleAuth,
    required bool isPasswordAuth,
    required bool isAppleAuth,
  }) {
    return DeleteAccountResult._(
      status: DeleteAccountStatus.requiresReauth,
      errorMessage: 'Se requiere re-autenticación',
      isGoogleAuth: isGoogleAuth,
      isPasswordAuth: isPasswordAuth,
      isAppleAuth: isAppleAuth,
    );
  }

  // Helpers
  bool get isSuccess => status == DeleteAccountStatus.success;
  bool get isError => status == DeleteAccountStatus.error;
  bool get isCloudFunctionFailed =>
      status == DeleteAccountStatus.cloudFunctionFailed;
  bool get requiresReauthentication =>
      status == DeleteAccountStatus.requiresReauth;
}
