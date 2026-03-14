/// Script de setup: Crear cuentas de prueba en Firebase Auth.
/// Ejecutar UNA VEZ antes de la suite principal.
///
///   flutter test integration_test/setup_test_accounts.dart -d R5CY21QJ7RN
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app_quitar/firebase_options.dart';

const _accounts = [
  {'email': 'test_a@victoria.com', 'password': 'TestPass123!', 'name': 'Test A'},
  {'email': 'test_b@victoria.com', 'password': 'TestPass123!', 'name': 'Test B'},
];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Setup: crear cuentas de prueba', (tester) async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    // Cerrar sesión previa
    try { await FirebaseAuth.instance.signOut(); } catch (_) {}

    for (final acct in _accounts) {
      final email = acct['email']!;
      final password = acct['password']!;
      final name = acct['name']!;

      debugPrint('🔧 Procesando cuenta: $email');

      try {
        // Intentar login (¿ya existe?)
        final cred = await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: email, password: password);
        debugPrint('✅ Cuenta $email ya existe (uid: ${cred.user?.uid})');
        await FirebaseAuth.instance.signOut();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' ||
            e.code == 'invalid-credential' ||
            e.code == 'INVALID_LOGIN_CREDENTIALS') {
          // Crear la cuenta en Auth (el Firestore doc lo creará la app al hacer login)
          try {
            final cred = await FirebaseAuth.instance
                .createUserWithEmailAndPassword(email: email, password: password);
            await cred.user!.updateDisplayName(name);
            debugPrint('✅ Cuenta CREADA en Auth: $email (uid: ${cred.user!.uid})');
            await FirebaseAuth.instance.signOut();
          } catch (createError) {
            debugPrint('❌ Error creando $email: $createError');
          }
        } else {
          debugPrint('❌ Error con $email: ${e.code} - ${e.message}');
        }
      } catch (e) {
        debugPrint('❌ Error inesperado con $email: $e');
      }
    }

    // Verificar login con ambas cuentas
    for (final acct in _accounts) {
      try {
        final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: acct['email']!,
          password: acct['password']!,
        );
        debugPrint('🔑 Login verificado: ${acct['email']} → uid: ${cred.user?.uid}');
        await FirebaseAuth.instance.signOut();
      } catch (e) {
        debugPrint('❌ Login FALLÓ: ${acct['email']} → $e');
      }
    }

    debugPrint('');
    debugPrint('═══════════════════════════════════════════');
    debugPrint('  SETUP COMPLETADO');
    debugPrint('═══════════════════════════════════════════');

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: Text('Setup OK'))),
    ));
    expect(find.text('Setup OK'), findsOneWidget);
  });
}
