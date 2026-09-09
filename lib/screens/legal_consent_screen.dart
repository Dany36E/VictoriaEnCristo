import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/legal_urls.dart';
import '../services/auth_service.dart';
import '../services/privacy_preferences_service.dart';

class LegalConsentScreen extends StatefulWidget {
  const LegalConsentScreen({super.key});

  @override
  State<LegalConsentScreen> createState() => _LegalConsentScreenState();
}

class _LegalConsentScreenState extends State<LegalConsentScreen> {
  bool _acceptedTerms = false;
  bool _acceptedSensitiveData = false;
  bool _saving = false;

  Future<void> _open(String path) async {
    await launchUrl(
      legalDocumentUri(path),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _accept() async {
    if (!_acceptedTerms || !_acceptedSensitiveData || _saving) return;
    setState(() => _saving = true);
    await PrivacyPreferencesService.I.acceptRequiredConsent();
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _deleteAccount() async {
    if (_saving) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Eliminar esta cuenta?'),
        content: const Text(
          'Si no deseas aceptar el tratamiento necesario para usar la app, '
          'puedes eliminar la cuenta y sus datos. Esta acción no se puede '
          'deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Conservar cuenta'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar cuenta y datos'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    final result = await AuthService().deleteAccountAndAllData();
    if (!mounted) return;
    setState(() => _saving = false);
    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.requiresReauthentication
                ? 'Por seguridad, vuelve a iniciar sesión e intenta eliminar '
                      'la cuenta de nuevo.'
                : result.errorMessage ??
                      'No se pudo confirmar la eliminación de la cuenta.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = _acceptedTerms && _acceptedSensitiveData && !_saving;
    return Scaffold(
      appBar: AppBar(title: const Text('Privacidad y consentimiento')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Icon(Icons.privacy_tip_outlined, size: 54),
            const SizedBox(height: 16),
            Text(
              'Tú decides sobre tus datos',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const Text(
              'La app puede guardar información de cuenta y, sólo cuando tú '
              'la escribes, datos sobre fe, hábitos, luchas, oraciones o diario. '
              'Se usan para mostrarte y sincronizar las funciones que solicitas. '
              'No se venden ni se usan para publicidad.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            CheckboxListTile(
              value: _acceptedTerms,
              onChanged: (value) =>
                  setState(() => _acceptedTerms = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Acepto los Términos y Condiciones.'),
            ),
            CheckboxListTile(
              value: _acceptedSensitiveData,
              onChanged: (value) =>
                  setState(() => _acceptedSensitiveData = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'Consiento expresamente el tratamiento de los datos sensibles '
                'que decida registrar, conforme al Aviso de Privacidad.',
              ),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => _open('terms.html'),
                  child: const Text('Leer términos'),
                ),
                TextButton(
                  onPressed: () => _open('privacy_policy.html'),
                  child: const Text('Leer aviso de privacidad'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: canContinue ? _accept : null,
              child: Text(_saving ? 'Guardando…' : 'Aceptar y continuar'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _saving ? null : FirebaseAuth.instance.signOut,
              child: const Text('No aceptar y cerrar sesión'),
            ),
            TextButton(
              onPressed: _saving ? null : _deleteAccount,
              child: const Text('No aceptar y eliminar mi cuenta'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Analytics, diagnósticos y videos integrados permanecen '
              'desactivados. Puedes habilitarlos después en Configuración.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
