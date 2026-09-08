import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/privacy_preferences_service.dart';

class PrivacyCenterScreen extends StatefulWidget {
  const PrivacyCenterScreen({super.key});

  @override
  State<PrivacyCenterScreen> createState() => _PrivacyCenterScreenState();
}

class _PrivacyCenterScreenState extends State<PrivacyCenterScreen> {
  final _privacy = PrivacyPreferencesService.I;

  Future<void> _open(String path) async {
    await launchUrl(
      Uri.parse('https://dany36e.github.io/VictoriaEnCristo/$path'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacidad y documentos legales')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Controles opcionales',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Estas opciones están apagadas por defecto. Cambiarlas no afecta '
            'el acceso a las funciones principales.',
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<bool>(
            valueListenable: _privacy.analyticsEnabled,
            builder: (_, value, _) => SwitchListTile(
              value: value,
              onChanged: _privacy.setAnalyticsEnabled,
              secondary: const Icon(Icons.query_stats_outlined),
              title: const Text('Compartir métricas de uso'),
              subtitle: const Text(
                'Envía eventos agregados a Firebase Analytics para mejorar la app.',
              ),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _privacy.crashReportsEnabled,
            builder: (_, value, _) => SwitchListTile(
              value: value,
              onChanged: _privacy.setCrashReportsEnabled,
              secondary: const Icon(Icons.bug_report_outlined),
              title: const Text('Compartir reportes de fallos'),
              subtitle: const Text(
                'Envía diagnósticos técnicos a Firebase Crashlytics.',
              ),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _privacy.youtubeEmbedsEnabled,
            builder: (_, value, _) => SwitchListTile(
              value: value,
              onChanged: _privacy.setYoutubeEmbedsEnabled,
              secondary: const Icon(Icons.smart_display_outlined),
              title: const Text('Permitir reproductor de YouTube'),
              subtitle: const Text(
                'YouTube recibirá datos técnicos, como IP y datos del dispositivo, '
                'al cargar un video integrado.',
              ),
            ),
          ),
          const Divider(height: 32),
          Text(
            'Documentos y derechos',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          _LegalLink(
            icon: Icons.privacy_tip_outlined,
            label: 'Aviso de privacidad',
            onTap: () => _open('privacy_policy.html'),
          ),
          _LegalLink(
            icon: Icons.description_outlined,
            label: 'Términos y condiciones',
            onTap: () => _open('terms.html'),
          ),
          _LegalLink(
            icon: Icons.cookie_outlined,
            label: 'Cookies y tecnologías similares',
            onTap: () => _open('cookie_policy.html'),
          ),
          _LegalLink(
            icon: Icons.currency_exchange_outlined,
            label: 'Pagos y reembolsos',
            onTap: () => _open('refund_policy.html'),
          ),
          _LegalLink(
            icon: Icons.delete_forever_outlined,
            label: 'Eliminar cuenta y datos',
            onTap: () => _open('data_deletion.html'),
          ),
          _LegalLink(
            icon: Icons.copyright_outlined,
            label: 'Avisos de terceros y copyright',
            onTap: () => _open('third_party_notices.html'),
          ),
          const SizedBox(height: 16),
          const Text(
            'Para revocar el consentimiento necesario para la cuenta y la '
            'sincronización, elimina tu cuenta desde Perfil. Puedes usar las '
            'herramientas locales sin volver a crear una cuenta.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: const Icon(Icons.open_in_new, size: 18),
      onTap: onTap,
    );
  }
}
