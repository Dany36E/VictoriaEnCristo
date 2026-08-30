import 'package:flutter/material.dart';

import '../../models/battle_partner_data.dart';
import '../../services/battle_partner_service.dart';
import '../../services/remote_guardian_service.dart';
import '../../services/user_scoped_services.dart';
import '../../theme/app_theme_data.dart';

/// Candado del Guardián a distancia. Maneja ambos roles:
///  - Protegido: pide a un compañero que sea su guardián; ve el estado.
///  - Guardián: atiende solicitudes y pone/cambia/quita el PIN a distancia.
class RemoteGuardianScreen extends StatefulWidget {
  const RemoteGuardianScreen({super.key});

  @override
  State<RemoteGuardianScreen> createState() => _RemoteGuardianScreenState();
}

class _RemoteGuardianScreenState extends State<RemoteGuardianScreen> {
  final _guardian = RemoteGuardianService.I;
  final _battle = BattlePartnerService.I;

  @override
  void initState() {
    super.initState();
    // Asegura partners + listeners del candado.
    UserScopedServices.I.ensureBattlePartners();
    _guardian.ensureStarted();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Guardián a distancia')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _intro(t),
          const SizedBox(height: 20),
          _sectionTitle(t, 'Mi escudo'),
          const SizedBox(height: 8),
          _buildProtegeCard(t),
          const SizedBox(height: 24),
          _sectionTitle(t, 'Soy guardián'),
          const SizedBox(height: 8),
          _buildGuardianSide(t),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionTitle(AppThemeData t, String text) => Text(
        text,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: t.textPrimary,
        ),
      );

  Widget _intro(AppThemeData t) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.handshake_outlined, color: t.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tu compañero pone un PIN desde su propio teléfono. Solo él lo '
              'sabe, así que no podrás bajar el escudo sin pedírselo.',
              style: TextStyle(color: t.textSecondary, height: 1.4, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ── Rol protegido ─────────────────────────────────────────────────────────

  Widget _buildProtegeCard(AppThemeData t) {
    return ValueListenableBuilder<GuardianLockStatus?>(
      valueListenable: _guardian.myLock,
      builder: (context, lock, _) {
        if (lock != null && lock.active) {
          return _card(t, [
            Row(
              children: [
                const Icon(Icons.verified_user, color: Colors.green),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Protegido por ${lock.guardianName ?? 'tu compañero'}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: t.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Para bajar el escudo necesitas el PIN que tiene tu compañero.',
              style: TextStyle(color: t.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _removeAsProtege(lock),
                icon: const Icon(Icons.lock_open, size: 18),
                label: const Text('Quitar candado (requiere PIN)'),
              ),
            ),
          ]);
        }
        if (lock != null && lock.pending) {
          return _card(t, [
            Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: t.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Esperando a que ${lock.guardianName ?? 'tu compañero'} '
                    'ponga el PIN…',
                    style: TextStyle(color: t.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _pickGuardian,
                child: const Text('Elegir otro compañero'),
              ),
            ),
          ]);
        }
        // Sin candado
        return _card(t, [
          Text(
            'Pídele a un compañero de batalla que sea tu guardián. Él pondrá '
            'el PIN desde su teléfono, sin que tengan que estar juntos.',
            style: TextStyle(color: t.textSecondary, height: 1.4, fontSize: 13.5),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _pickGuardian,
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              label: const Text('Elegir compañero guardián'),
            ),
          ),
        ]);
      },
    );
  }

  Future<void> _pickGuardian() async {
    final partners = _battle.partnersNotifier.value
        .where((p) => p.status == PartnerStatus.active)
        .toList();
    if (partners.isEmpty) {
      _snack('Primero agrega un Compañero de Batalla.');
      return;
    }
    final t = AppThemeData.of(context);
    final chosen = await showModalBottomSheet<BattlePartnerData>(
      context: context,
      backgroundColor: t.cardBg,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text('Elige tu guardián',
                style: TextStyle(
                    fontWeight: FontWeight.w800, color: t.textPrimary)),
            const SizedBox(height: 8),
            for (final p in partners)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: t.accent.withValues(alpha: 0.15),
                  child: Icon(Icons.person, color: t.accent),
                ),
                title: Text(p.name, style: TextStyle(color: t.textPrimary)),
                onTap: () => Navigator.pop(ctx, p),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (chosen == null) return;
    final ok = await _guardian.requestGuardian(chosen.uid);
    if (!mounted) return;
    _snack(ok
        ? 'Solicitud enviada a ${chosen.name}. Él pondrá el PIN.'
        : 'No se pudo enviar la solicitud.');
  }

  Future<void> _removeAsProtege(GuardianLockStatus lock) async {
    final pin = await _askPin(
      title: 'Quitar candado',
      message: 'Pídele el PIN a tu compañero para quitar el candado.',
    );
    if (pin == null) return;
    final res = await _guardian.remove(
      protegeUid: _guardian.currentUid ?? '',
      pin: pin,
    );
    if (!mounted) return;
    if (res.ok) {
      _snack('Candado retirado.');
    } else if (res.isLockedOut) {
      _snack('Demasiados intentos. Intenta más tarde.');
    } else {
      _snack('PIN incorrecto.');
    }
  }

  // ── Rol guardián ────────────────────────────────────────────────────────

  Widget _buildGuardianSide(AppThemeData t) {
    return Column(
      children: [
        ValueListenableBuilder<List<GuardianRequest>>(
          valueListenable: _guardian.incomingRequests,
          builder: (context, requests, _) {
            if (requests.isEmpty) return const SizedBox.shrink();
            return Column(
              children: [
                for (final r in requests)
                  _card(t, [
                    Row(
                      children: [
                        Icon(Icons.notification_important, color: t.accent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${r.protegeName} te pidió ser su guardián',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: t.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Pon un PIN que solo tú sepas. Se lo pedirán cuando '
                      'quieran bajar el escudo.',
                      style: TextStyle(color: t.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _setPinFor(r.protegeUid, r.protegeName),
                        icon: const Icon(Icons.lock, size: 18),
                        label: const Text('Poner PIN'),
                      ),
                    ),
                  ]),
              ],
            );
          },
        ),
        ValueListenableBuilder<List<GuardianOfEntry>>(
          valueListenable: _guardian.guardianOf,
          builder: (context, list, _) {
            final active = list.where((e) => e.active).toList();
            if (active.isEmpty) {
              return _card(t, [
                Text(
                  'No eres guardián de nadie todavía. Cuando un compañero te lo '
                  'pida, aparecerá aquí.',
                  style: TextStyle(color: t.textSecondary, fontSize: 13),
                ),
              ]);
            }
            return Column(
              children: [
                for (final e in active)
                  _card(t, [
                    Row(
                      children: [
                        const Icon(Icons.shield, color: Colors.green),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Proteges a ${e.protegeName}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: t.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                _setPinFor(e.protegeUid, e.protegeName),
                            child: const Text('Cambiar PIN'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextButton(
                            onPressed: () => _removeAsGuardian(e),
                            child: Text(
                              'Quitar',
                              style: TextStyle(
                                color: t.textSecondary.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ]),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _setPinFor(String protegeUid, String protegeName) async {
    final pin = await _askPin(
      title: 'PIN para $protegeName',
      message: 'Elige un PIN (4 a 8 dígitos) que solo tú sepas. No se lo digas '
          'salvo cuando de verdad deba bajar el escudo.',
      confirm: true,
    );
    if (pin == null) return;
    final ok = await _guardian.setPin(protegeUid: protegeUid, pin: pin);
    if (!mounted) return;
    _snack(ok ? 'PIN establecido para $protegeName.' : 'No se pudo establecer.');
  }

  Future<void> _removeAsGuardian(GuardianOfEntry e) async {
    final res = await _guardian.remove(protegeUid: e.protegeUid);
    if (!mounted) return;
    _snack(res.ok ? 'Candado retirado.' : 'No se pudo quitar.');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _card(AppThemeData t, List<Widget> children) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.cardBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<String?> _askPin({
    required String title,
    required String message,
    bool confirm = false,
  }) async {
    final t = AppThemeData.of(context);
    final c1 = TextEditingController();
    final c2 = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (ctx) {
        String? error;
        return StatefulBuilder(
          builder: (ctx, setSt) {
            return AlertDialog(
              backgroundColor: t.cardBg,
              title: Text(title, style: TextStyle(color: t.textPrimary)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(message,
                      style: TextStyle(color: t.textSecondary, height: 1.4)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: c1,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 8,
                    autofocus: true,
                    decoration: const InputDecoration(
                        labelText: 'PIN', counterText: ''),
                  ),
                  if (confirm)
                    TextField(
                      controller: c2,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 8,
                      decoration: InputDecoration(
                          labelText: 'Repetir PIN',
                          counterText: '',
                          errorText: error),
                    )
                  else if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(error!,
                          style: const TextStyle(color: Colors.red, fontSize: 12)),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () {
                    final p = c1.text.trim();
                    if (!RegExp(r'^\d{4,8}$').hasMatch(p)) {
                      setSt(() => error = 'Usa 4 a 8 dígitos');
                      return;
                    }
                    if (confirm && p != c2.text.trim()) {
                      setSt(() => error = 'Los PIN no coinciden');
                      return;
                    }
                    Navigator.pop(ctx, p);
                  },
                  child: const Text('Aceptar'),
                ),
              ],
            );
          },
        );
      },
    );
    c1.dispose();
    c2.dispose();
    return pin;
  }
}
