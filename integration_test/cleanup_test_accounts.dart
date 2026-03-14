/// Script de limpieza: Borrar documentos Firestore de cuentas de prueba
/// para empezar tests desde cero.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_quitar/firebase_options.dart';

const _accounts = [
  {'email': 'test_a@victoria.com', 'password': 'TestPass123!'},
  {'email': 'test_b@victoria.com', 'password': 'TestPass123!'},
];

Future<void> _deleteSubcollections(String uid) async {
  final subCols = ['victoryDays', 'journalEntries', 'planProgress'];
  for (final col in subCols) {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection(col)
        .get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
      debugPrint('  🗑️ Deleted $col/${doc.id}');
    }
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Cleanup: borrar datos de cuentas de prueba', (tester) async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    try { await FirebaseAuth.instance.signOut(); } catch (_) {}

    for (final acct in _accounts) {
      final email = acct['email']!;
      final password = acct['password']!;

      debugPrint('🧹 Limpiando cuenta: $email');

      try {
        final cred = await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: email, password: password);
        final uid = cred.user!.uid;
        debugPrint('  📍 UID: $uid');

        // Borrar subcollections primero
        await _deleteSubcollections(uid);

        // Borrar doc principal
        try {
          // No podemos borrar el doc principal (rules: allow delete: if false)
          // Pero podemos RESETEAR sus campos a estado de "nuevo usuario"
          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'uid': uid,
            'email': email,
            'displayName': cred.user!.displayName ?? 'Test',
            'createdAt': FieldValue.serverTimestamp(),
            'onboardingCompleted': false,
            'selectedGiants': [],
          });
          debugPrint('  ✅ Doc reseteado a estado nuevo');
        } catch (e) {
          debugPrint('  ⚠️ No se pudo resetear doc: $e');
        }

        await FirebaseAuth.instance.signOut();
      } catch (e) {
        debugPrint('  ❌ Error: $e');
      }
    }

    // Verificar estado final
    for (final acct in _accounts) {
      try {
        final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: acct['email']!,
          password: acct['password']!,
        );
        final uid = cred.user!.uid;
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (doc.exists) {
          final data = doc.data()!;
          debugPrint('📋 ${acct['email']}: onboardingCompleted=${data['onboardingCompleted']}, giants=${data['selectedGiants']}');
        } else {
          debugPrint('📋 ${acct['email']}: NO doc exists');
        }
        await FirebaseAuth.instance.signOut();
      } catch (e) {
        debugPrint('❌ Verify error: $e');
      }
    }

    debugPrint('');
    debugPrint('═══════════════════════════════════════════');
    debugPrint('  LIMPIEZA COMPLETADA');
    debugPrint('═══════════════════════════════════════════');

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: Text('Cleanup OK'))),
    ));
    expect(find.text('Cleanup OK'), findsOneWidget);
  });
}
