import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/purity_guard_service.dart';
import '../../theme/app_theme_data.dart';

/// Pantalla "Protección / Pureza": activa el bloqueador de contenido adulto.
///
/// Android: toggle que enciende la VPN local de filtrado.
/// iOS: guía para activar el filtro nativo (Tiempo en Pantalla).
class PurityGuardScreen extends StatefulWidget {
  const PurityGuardScreen({super.key});

  @override
  State<PurityGuardScreen> createState() => _PurityGuardScreenState();
}

class _PurityGuardScreenState extends State<PurityGuardScreen> {
  final _service = PurityGuardService.I;
  bool _busy = false;
  int _blocklistCount = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _service.refresh();
    final count = await _service.blocklistCount();
    if (mounted) setState(() => _blocklistCount = count);
  }

  Future<void> _toggle(bool value) async {
    if (_busy) return;
    setState(() => _busy = true);
    if (value) {
      final ok = await _service.enable();
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo activar. Concede el permiso de VPN cuando Android lo pida.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      await _service.disable();
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Protección · Pureza')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHero(t),
          const SizedBox(height: 20),
          if (_service.isEngineSupported)
            _buildAndroidControl(t)
          else if (_service.isIOS)
            _buildIOSGuide(t)
          else
            _buildUnsupported(t),
          const SizedBox(height: 20),
          _buildHowItWorks(t),
          const SizedBox(height: 20),
          _buildDisclaimer(t),
        ],
      ),
    );
  }

  Widget _buildHero(AppThemeData t) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            t.accent.withValues(alpha: 0.18),
            t.accent.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_moon_rounded, color: t.accent, size: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Escudo de Pureza',
                  style: TextStyle(
                    color: t.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bloquea páginas de contenido adulto y te trae de vuelta '
                  'a un lugar seguro.',
                  style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAndroidControl(AppThemeData t) {
    return Container(
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.cardBorder),
      ),
      child: Column(
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: _service.active,
            builder: (context, active, _) {
              return SwitchListTile(
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (active ? Colors.green : t.accent)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    active ? Icons.verified_user : Icons.security,
                    color: active ? Colors.green : t.accent,
                  ),
                ),
                title: Text(
                  active ? 'Protección activa' : 'Activar protección',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
                subtitle: Text(
                  active
                      ? 'Filtrando en todos los navegadores'
                      : 'Enciende el filtro de contenido adulto',
                  style: TextStyle(color: t.textSecondary),
                ),
                value: active,
                activeThumbColor: Colors.green,
                onChanged: _busy ? null : _toggle,
              );
            },
          ),
          if (_blocklistCount > 0) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.list_alt, color: t.textSecondary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$_blocklistCount sitios en la lista de bloqueo',
                      style: TextStyle(color: t.textSecondary, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIOSGuide(AppThemeData t) {
    final steps = <String>[
      'Abre Ajustes → Tiempo en pantalla.',
      'Toca "Restricciones de contenido y privacidad" y actívalas.',
      'Entra a "Restricciones de contenido" → "Contenido web".',
      'Elige "Limitar sitios web para adultos".',
      'Opcional: pon un código de Tiempo en Pantalla para que no se pueda '
          'desactivar fácilmente.',
    ];
    return Container(
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.cardBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.phone_iphone, color: t.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'En iPhone/iPad se usa el filtro integrado de iOS',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: t.accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: t.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      steps[i],
                      style: TextStyle(
                        color: t.textSecondary,
                        fontSize: 13.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openIOSSettings,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Abrir Ajustes'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnsupported(AppThemeData t) {
    return Container(
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.cardBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: t.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'El bloqueador está disponible en Android. En esta plataforma '
              'usa las restricciones de contenido del sistema.',
              style: TextStyle(color: t.textSecondary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorks(AppThemeData t) {
    final items = _service.isIOS
        ? const [
            'iOS filtra los sitios adultos a nivel del sistema.',
            'Funciona en Safari y apps que usan el navegador de iOS.',
            'Con un código de Tiempo en Pantalla queda protegido.',
          ]
        : const [
            'Se activa una VPN local en tu propio teléfono (no envía tu '
                'tráfico a ningún servidor externo).',
            'Cuando intentas abrir una web de la lista, se bloquea en '
                'cualquier navegador.',
            'Además te trae de vuelta a la app, a "Necesito Ayuda".',
          ];
    return Container(
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.cardBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cómo funciona',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: t.textPrimary,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle, color: t.accent, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        color: t.textSecondary,
                        height: 1.4,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer(AppThemeData t) {
    return Text(
      'Ninguna herramienta es infalible. Este escudo es una ayuda, no un '
      'sustituto de la rendición de cuentas y la oración. "Todo lo puedo en '
      'Cristo que me fortalece." — Filipenses 4:13',
      style: TextStyle(
        color: t.textSecondary.withValues(alpha: 0.7),
        fontSize: 12,
        height: 1.5,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  Future<void> _openIOSSettings() async {
    final uri = Uri.parse('app-settings:');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // no-op: si no se puede abrir, el usuario sigue los pasos manuales.
    }
  }
}
