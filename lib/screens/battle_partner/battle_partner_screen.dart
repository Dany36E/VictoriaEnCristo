/// ═══════════════════════════════════════════════════════════════════════════
/// BATTLE PARTNER SCREEN - Compañero de Batalla
/// 3 secciones: invitaciones pendientes, compañeros activos, mi código
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/battle_partner_data.dart';
import '../../services/battle_partner_service.dart';
import '../../services/audio_engine.dart';
import '../../services/feedback_engine.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../constants/battle_messages.dart';
import '../../widgets/battle_partner_card.dart';
import 'add_partner_screen.dart';

class BattlePartnerScreen extends StatefulWidget {
  const BattlePartnerScreen({super.key});

  @override
  State<BattlePartnerScreen> createState() => _BattlePartnerScreenState();
}

class _BattlePartnerScreenState extends State<BattlePartnerScreen> {
  final _service = BattlePartnerService.I;
  String? _myInviteCode;
  bool _loadingCode = true;

  @override
  void initState() {
    super.initState();
    AudioEngine.I.muteForScreen();
    _loadInviteCode();
    // Marcar todos los mensajes como leídos al entrar
    _service.markAllMessagesRead();
    // Suprimir notificaciones locales de invitaciones/mensajes mientras la
    // pantalla esté visible (la UI ya muestra todo reactivamente).
    NotificationService.isViewingBattlePartner.value = true;
  }

  @override
  void dispose() {
    NotificationService.isViewingBattlePartner.value = false;
    super.dispose();
  }

  Future<void> _loadInviteCode() async {
    final code = await _service.getMyInviteCode();
    if (mounted) setState(() { _myInviteCode = code; _loadingCode = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Compañero de Batalla',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Toggle de pausa de invitaciones (#12).
          ValueListenableBuilder<bool>(
            valueListenable: _service.acceptingInvitesNotifier,
            builder: (_, accepting, _) {
              return IconButton(
                icon: Icon(
                  accepting ? Icons.notifications_active : Icons.notifications_off,
                  color: accepting ? AppDesignSystem.gold : Colors.orange,
                  size: 22,
                ),
                tooltip: accepting
                    ? 'Pausar nuevas invitaciones'
                    : 'Reanudar invitaciones',
                onPressed: _togglePauseInvites,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_add_alt_1, color: AppDesignSystem.gold, size: 22),
            tooltip: 'Agregar compañero',
            onPressed: _navigateToAddPartner,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            // Banner de pausa (#12)
            _buildPauseBanner(),
            // ═════════════════════════════════════
            // INVITACIONES PENDIENTES
            // ═════════════════════════════════════
            _buildPendingInvitesSection(),

            // ═════════════════════════════════════
            // MENSAJES NO LEÍDOS
            // ═════════════════════════════════════
            _buildUnreadMessagesSection(),

            // ═════════════════════════════════════
            // COMPAÑEROS ACTIVOS
            // ═════════════════════════════════════
            _buildPartnersSection(),

            // ═════════════════════════════════════
            // SOS "Oren por mí ahora" (#16)
            // ═════════════════════════════════════
            _buildSosSection(),

            const SizedBox(height: 16),

            // ═════════════════════════════════════
            // MI CÓDIGO DE INVITACIÓN
            // ═════════════════════════════════════
            _buildMyCodeSection(),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INVITACIONES PENDIENTES
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPendingInvitesSection() {
    return ValueListenableBuilder<List<PartnerInvite>>(
      valueListenable: _service.pendingInvitesNotifier,
      builder: (_, invites, _) {
        if (invites.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('📬 Invitaciones pendientes', badge: invites.length),
            const SizedBox(height: 8),
            ...invites.map((invite) => _buildInviteCard(invite)),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildInviteCard(PartnerInvite invite) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppDesignSystem.gold.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppDesignSystem.gold.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppDesignSystem.gold.withOpacity(0.15),
            ),
            child: Center(
              child: Text(
                invite.fromName.isNotEmpty ? invite.fromName[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppDesignSystem.gold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invite.fromName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Quiere ser tu compañero de batalla',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),

          // Botones
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _actionButton(
                Icons.check_circle,
                AppDesignSystem.victory,
                () => _acceptInvite(invite),
              ),
              const SizedBox(width: 8),
              _actionButton(
                Icons.cancel,
                AppDesignSystem.struggle,
                () => _rejectInvite(invite),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.15),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }

  Future<void> _acceptInvite(PartnerInvite invite) async {
    FeedbackEngine.I.confirm();
    final ok = await _service.acceptInvite(invite);
    if (mounted && ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡${invite.fromName} ya es tu compañero! ⚔️'),
          backgroundColor: AppDesignSystem.midnightLight,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _rejectInvite(PartnerInvite invite) async {
    FeedbackEngine.I.tap();
    await _service.rejectInvite(invite);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MENSAJES NO LEÍDOS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildUnreadMessagesSection() {
    return ValueListenableBuilder<List<BattleMessageData>>(
      valueListenable: _service.unreadMessagesNotifier,
      builder: (_, messages, _) {
        if (messages.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('💌 Mensajes recientes', badge: messages.length),
            const SizedBox(height: 8),
            ...messages.take(5).map((msg) => _buildMessageCard(msg)),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildMessageCard(BattleMessageData msg) {
    final sticker = kBattleMessageMap[msg.messageKey];
    // Buscar nombre del remitente en los partners
    final partners = _service.partnersNotifier.value;
    final sender = partners.where((p) => p.uid == msg.fromUid).firstOrNull;
    final senderName = sender?.name ?? 'Compañero';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Text(sticker?.icon ?? '💬', style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  senderName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppDesignSystem.gold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sticker?.text ?? msg.messageKey,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COMPAÑEROS ACTIVOS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPartnersSection() {
    return ValueListenableBuilder<List<BattlePartnerData>>(
      valueListenable: _service.partnersNotifier,
      builder: (_, partners, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(
              '⚔️ Compañeros de batalla',
              trailing: Text(
                '${partners.length}/$kMaxBattlePartners',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.4),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (partners.isEmpty)
              _buildEmptyPartnersState()
            else
              ...partners.map((p) => BattlePartnerCard(
                partner: p,
                onRemove: () => _confirmRemovePartner(p),
              )),
          ],
        );
      },
    );
  }

  Widget _buildEmptyPartnersState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppDesignSystem.gold.withOpacity(0.08),
            Colors.white.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppDesignSystem.gold.withOpacity(0.18)),
      ),
      child: Column(
        children: [
          const Text('🛡️', style: TextStyle(fontSize: 42)),
          const SizedBox(height: 10),
          const Text(
            'No estás solo en esta batalla',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          // Versículo bíblico motivacional (Eclesiastés 4:9-10).
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppDesignSystem.gold.withOpacity(0.15)),
            ),
            child: Column(
              children: [
                Text(
                  '"Mejores son dos que uno… porque si cayeren, el uno levantará a su compañero."',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontStyle: FontStyle.italic,
                    color: Colors.white.withOpacity(0.82),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Eclesiastés 4:9-10',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppDesignSystem.gold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Invita a un hermano de confianza que ore por ti y te acompañe. La privacidad está garantizada: nunca verá tu diario ni tus luchas específicas.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.55),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _navigateToAddPartner,
            icon: const Icon(Icons.person_add_alt_1, size: 18),
            label: const Text('Conecta tu primer compañero'),
            style: FilledButton.styleFrom(
              backgroundColor: AppDesignSystem.gold,
              foregroundColor: AppDesignSystem.midnightDeep,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemovePartner(BattlePartnerData partner) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppDesignSystem.midnightLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '¿Liberar a ${partner.name}?',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Text(
          'Dejarás de compartir tu progreso con ${partner.name}. '
          'No recibirás notificaciones. Podrás reconectar en cualquier '
          'momento volviendo a intercambiar códigos.',
          style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13.5, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Sí, liberar',
              style: TextStyle(color: AppDesignSystem.struggle),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      FeedbackEngine.I.tap();
      await _service.removePartner(partner.uid);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MI CÓDIGO DE INVITACIÓN
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMyCodeSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppDesignSystem.gold.withOpacity(0.08),
            AppDesignSystem.goldDark.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppDesignSystem.gold.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          const Text(
            'Tu código de invitación',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppDesignSystem.gold,
            ),
          ),
          const SizedBox(height: 10),
          if (_loadingCode)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppDesignSystem.gold),
            )
          else if (_myInviteCode != null) ...[
            GestureDetector(
              onTap: _copyCode,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppDesignSystem.gold.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _myInviteCode!,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 3,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.copy, color: AppDesignSystem.gold.withOpacity(0.6), size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Toca para copiar • Comparte solo con personas de confianza',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _showQrSheet,
              icon: const Icon(Icons.qr_code_2, size: 20, color: AppDesignSystem.gold),
              label: const Text(
                'Mostrar QR',
                style: TextStyle(color: AppDesignSystem.gold, fontSize: 13),
              ),
            ),
          ] else
            Text(
              'Error generando código',
              style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.5)),
            ),
        ],
      ),
    );
  }

  void _copyCode() {
    if (_myInviteCode == null) return;
    Clipboard.setData(ClipboardData(text: _myInviteCode!));
    FeedbackEngine.I.confirm();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('📋 Código copiado al portapapeles'),
        backgroundColor: AppDesignSystem.midnightLight,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showQrSheet() {
    final code = _myInviteCode;
    if (code == null) return;
    FeedbackEngine.I.tap();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppDesignSystem.midnightLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Tu código QR',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Que tu compañero lo escanee con otra app escáner',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 20),
              // QR con padding blanco para máxima lectura incluso en OLED oscuro.
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(
                  data: 'victoria://battle/invite?code=$code',
                  size: 220,
                  version: QrVersions.auto,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                code,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 4,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS UI
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _sectionHeader(String title, {int? badge, Widget? trailing}) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
        if (badge != null && badge > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppDesignSystem.gold.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$badge',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppDesignSystem.gold,
              ),
            ),
          ),
        ],
        const Spacer(),
        ?trailing,
      ],
    );
  }

  void _navigateToAddPartner() {
    FeedbackEngine.I.tap();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddPartnerScreen()),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PAUSA DE INVITACIONES (#12)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _togglePauseInvites() async {
    FeedbackEngine.I.tap();
    final next = !_service.acceptingInvitesNotifier.value;
    await _service.setAcceptingInvites(next);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(next
            ? '✅ Aceptando nuevas invitaciones'
            : '⏸️ Invitaciones pausadas. Nadie podrá agregarte por ahora.'),
        backgroundColor: AppDesignSystem.midnightLight,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildPauseBanner() {
    return ValueListenableBuilder<bool>(
      valueListenable: _service.acceptingInvitesNotifier,
      builder: (_, accepting, _) {
        if (accepting) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.pause_circle, color: Colors.orange, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Invitaciones pausadas. Tus compañeros actuales siguen activos.',
                  style: TextStyle(fontSize: 12, color: Colors.orange),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SOS "Oren por mí ahora" (#16)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSosSection() {
    return ValueListenableBuilder<List<BattlePartnerData>>(
      valueListenable: _service.partnersNotifier,
      builder: (_, partners, _) {
        if (partners.isEmpty) return const SizedBox.shrink();
        final remaining = _service.remainingSosToday();
        return Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 4),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppDesignSystem.struggle.withOpacity(0.15),
                  AppDesignSystem.struggle.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppDesignSystem.struggle.withOpacity(0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('🆘', style: TextStyle(fontSize: 22)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Oren por mí ahora',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Envía una alerta urgente a todos tus compañeros de batalla para que oren por ti en este momento.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: remaining > 0 ? _triggerSos : null,
                        icon: const Icon(Icons.notifications_active, size: 18),
                        label: Text(remaining > 0
                            ? 'Pedir oración urgente'
                            : 'Disponible mañana'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppDesignSystem.struggle,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  remaining > 0
                      ? 'Disponible 1 vez al día'
                      : 'Vuelve a usarlo mañana',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.4),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _triggerSos() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppDesignSystem.midnightLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '¿Pedir oración urgente?',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Text(
          'Se notificará a todos tus compañeros de batalla que necesitas oración ahora. Solo puedes hacerlo 1 vez al día.',
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppDesignSystem.struggle),
            child: const Text('Enviar SOS'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    FeedbackEngine.I.confirm();
    final sent = await _service.sendSos();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(sent > 0
            ? '🆘 Se notificó a $sent compañero${sent == 1 ? '' : 's'}. Están orando contigo.'
            : 'No se pudo enviar la alerta (rate-limit o sin compañeros).'),
        backgroundColor: AppDesignSystem.midnightLight,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
    setState(() {}); // refrescar el botón (remaining)
  }
}
