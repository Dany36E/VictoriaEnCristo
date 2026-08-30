import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/guardian_lock_service.dart';
import '../../services/purity_guard_service.dart';
import '../../services/remote_guardian_service.dart';
import '../../theme/app_theme_data.dart';
import 'remote_guardian_screen.dart';

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
  int _blockedTotal = 0;
  int _blockedToday = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    RemoteGuardianService.I.ensureStarted();
    await _service.refresh();
    await GuardianLockService.I.refresh();
    final count = await _service.blocklistCount();
    final stats = await _service.blockStats();
    if (mounted) {
      setState(() {
        _blocklistCount = count;
        _blockedTotal = stats.total;
        _blockedToday = stats.today;
      });
    }
  }

  Future<void> _toggle(bool value) async {
    if (_busy) return;
    if (!value) {
      final remote = RemoteGuardianService.I.myLock.value;
      if (remote != null && remote.active) {
        // Candado remoto: verificación server-side del PIN del compañero.
        final ok = await _promptRemotePin();
        if (ok != true) return;
      } else if (GuardianLockService.I.enabled.value) {
        // Candado del guardián: requiere el PIN que tiene el compañero.
        final ok = await _promptGuardianPin(
          title: 'PIN del guardián',
          message: 'Pídele a tu compañero el PIN para desactivar el escudo.',
        );
        if (ok != true) return;
      } else {
        // Fricción intencional: un momento de pausa antes de bajar el escudo.
        final confirmed = await _confirmDisable();
        if (confirmed != true) return;
      }
    }
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

  Future<bool?> _confirmDisable() {
    final t = AppThemeData.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.cardBg,
        icon: Icon(Icons.shield_moon_rounded, color: t.accent, size: 40),
        title: Text(
          '¿Bajar el escudo?',
          textAlign: TextAlign.center,
          style: TextStyle(color: t.textPrimary),
        ),
        content: Text(
          'Recuerda por qué empezaste. La tentación es más fuerte cuando '
          'bajamos la guardia.\n\n"Velad y orad, para que no entréis en '
          'tentación." — Mateo 26:41',
          textAlign: TextAlign.center,
          style: TextStyle(color: t.textSecondary, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Mantener activo'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Desactivar',
              style: TextStyle(color: t.textSecondary.withValues(alpha: 0.7)),
            ),
          ),
        ],
      ),
    );
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
          if (_service.isEngineSupported) ...[
            const SizedBox(height: 12),
            _buildGuardianCard(t),
          ],
          const SizedBox(height: 12),
          _buildRemoteGuardianCard(t),
          const SizedBox(height: 20),
          _buildHowItWorks(t),
          const SizedBox(height: 20),
          _buildDisclaimer(t),
        ],
      ),
    );
  }

  // ── Candado del guardián a distancia (remoto) ────────────────────────────

  Widget _buildRemoteGuardianCard(AppThemeData t) {
    return ValueListenableBuilder<GuardianLockStatus?>(
      valueListenable: RemoteGuardianService.I.myLock,
      builder: (context, lock, _) {
        final active = lock != null && lock.active;
        final pending = lock != null && lock.pending && !active;
        return Container(
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.cardBorder),
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (active ? Colors.green : t.accent).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                active ? Icons.lock_person : Icons.groups_2_outlined,
                color: active ? Colors.green : t.accent,
              ),
            ),
            title: Text(
              'Candado del guardián a distancia',
              style: TextStyle(fontWeight: FontWeight.w700, color: t.textPrimary),
            ),
            subtitle: Text(
              active
                  ? 'Protegido por ${lock.guardianName ?? 'tu compañero'}'
                  : pending
                      ? 'Esperando el PIN de ${lock.guardianName ?? 'tu compañero'}…'
                      : 'Tu compañero pone el PIN desde su teléfono',
              style: TextStyle(color: t.textSecondary),
            ),
            trailing: Icon(Icons.chevron_right, color: t.textSecondary),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RemoteGuardianScreen()),
            ),
          ),
        );
      },
    );
  }

  Future<bool> _promptRemotePin() async {
    final t = AppThemeData.of(context);
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        String? error;
        bool busy = false;
        return StatefulBuilder(
          builder: (ctx, setSt) {
            return AlertDialog(
              backgroundColor: t.cardBg,
              title: Text('PIN del guardián',
                  style: TextStyle(color: t.textPrimary)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Pídele a tu compañero el PIN para bajar el escudo.',
                    style: TextStyle(color: t.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 8,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'PIN',
                      counterText: '',
                      errorText: error,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: busy ? null : () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () async {
                          setSt(() => busy = true);
                          final res = await RemoteGuardianService.I
                              .verify(controller.text.trim());
                          if (res.ok) {
                            if (ctx.mounted) Navigator.pop(ctx, true);
                            return;
                          }
                          setSt(() {
                            error = res.isLockedOut
                                ? 'Demasiados intentos. Intenta más tarde.'
                                : 'PIN incorrecto';
                            busy = false;
                          });
                        },
                  child: const Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    return result ?? false;
  }

  // ── Candado del guardián ────────────────────────────────────────────────

  Widget _buildGuardianCard(AppThemeData t) {
    return ValueListenableBuilder<bool>(
      valueListenable: GuardianLockService.I.enabled,
      builder: (context, locked, _) {
        return Container(
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.cardBorder),
          ),
          child: Column(
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (locked ? Colors.green : t.textSecondary)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    locked ? Icons.lock : Icons.lock_open,
                    color: locked ? Colors.green : t.textSecondary,
                  ),
                ),
                title: Text(
                  'Candado del guardián',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
                subtitle: Text(
                  locked
                      ? 'Activo · solo tu compañero puede desactivar el escudo'
                      : 'Opcional · un PIN que tiene tu compañero',
                  style: TextStyle(color: t.textSecondary),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: locked
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _removeGuardian,
                          icon: const Icon(Icons.lock_open, size: 18),
                          label: const Text('Quitar candado (requiere PIN)'),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Actívalo solo si tienes un compañero de confianza. '
                            'Él pondrá un PIN que tú no verás; así no podrás '
                            'apagar el escudo por impulso.',
                            style: TextStyle(
                              color: t.textSecondary,
                              fontSize: 12.5,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _setupGuardian,
                              icon: const Icon(Icons.person_add_alt_1, size: 18),
                              label: const Text('Activar candado del guardián'),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _setupGuardian() async {
    final t = AppThemeData.of(context);
    final pinC = TextEditingController();
    final pin2C = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        String? error;
        return StatefulBuilder(
          builder: (ctx, setSt) {
            return AlertDialog(
              backgroundColor: t.cardBg,
              title: Text(
                'Candado del guardián',
                style: TextStyle(color: t.textPrimary),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Pásale el teléfono a tu compañero para que escriba un PIN '
                    '(4 a 8 dígitos) que solo él/ella sepa. No lo veas.',
                    style: TextStyle(color: t.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pinC,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 8,
                    decoration: const InputDecoration(
                      labelText: 'PIN',
                      counterText: '',
                    ),
                  ),
                  TextField(
                    controller: pin2C,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 8,
                    decoration: InputDecoration(
                      labelText: 'Repetir PIN',
                      counterText: '',
                      errorText: error,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () async {
                    final p = pinC.text.trim();
                    final p2 = pin2C.text.trim();
                    if (!RegExp(r'^\d{4,8}$').hasMatch(p)) {
                      setSt(() => error = 'Usa 4 a 8 dígitos');
                      return;
                    }
                    if (p != p2) {
                      setSt(() => error = 'Los PIN no coinciden');
                      return;
                    }
                    final done = await GuardianLockService.I.setPin(p);
                    if (ctx.mounted) Navigator.pop(ctx, done);
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
    pinC.dispose();
    pin2C.dispose();
    if (ok == true && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Candado del guardián activado.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _removeGuardian() async {
    final ok = await _promptGuardianPin(
      title: 'Quitar candado',
      message: 'Introduce el PIN del guardián para quitar el candado.',
    );
    if (ok == true) {
      await GuardianLockService.I.clear();
      if (mounted) setState(() {});
    }
  }

  Future<bool> _promptGuardianPin({
    required String title,
    required String message,
  }) async {
    final t = AppThemeData.of(context);
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        String? error;
        bool busy = false;
        return StatefulBuilder(
          builder: (ctx, setSt) {
            return AlertDialog(
              backgroundColor: t.cardBg,
              title: Text(title, style: TextStyle(color: t.textPrimary)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message,
                    style: TextStyle(color: t.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 8,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'PIN',
                      counterText: '',
                      errorText: error,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: busy ? null : () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () async {
                          setSt(() => busy = true);
                          final r = await GuardianLockService.I
                              .verify(controller.text.trim());
                          if (r == GuardianVerifyResult.ok) {
                            if (ctx.mounted) Navigator.pop(ctx, true);
                            return;
                          }
                          if (r == GuardianVerifyResult.lockedOut) {
                            final rem =
                                await GuardianLockService.I.lockoutRemaining();
                            final mins = ((rem?.inMinutes) ?? 15) + 1;
                            setSt(() {
                              error =
                                  'Demasiados intentos. Espera ~$mins min.';
                              busy = false;
                            });
                          } else {
                            setSt(() {
                              error = 'PIN incorrecto';
                              busy = false;
                            });
                          }
                        },
                  child: const Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    return result ?? false;
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
                      '$_blocklistCount sitios en la lista de bloqueo · '
                      'SafeSearch forzado · anti DNS-over-HTTPS',
                      style: TextStyle(color: t.textSecondary, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_blockedTotal > 0) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.verified, color: Colors.green, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$_blockedTotal tentaciones bloqueadas'
                      '${_blockedToday > 0 ? '  ·  hoy: $_blockedToday' : ''}',
                      style: TextStyle(
                        color: t.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
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
                'cualquier navegador y te trae de vuelta a "Necesito Ayuda".',
            'Fuerza SafeSearch en Google, YouTube, Bing y DuckDuckGo.',
            'Bloquea el DNS-over-HTTPS que usan algunos navegadores para '
                'saltarse los filtros.',
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
