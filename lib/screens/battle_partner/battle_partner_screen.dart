/// ═══════════════════════════════════════════════════════════════════════════
/// BATTLE PARTNER SCREEN - Compañero de Batalla
/// 3 secciones: invitaciones pendientes, compañeros activos, mi código
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/battle_partner_data.dart';
import '../../services/battle_partner_service.dart';
import '../../services/audio_engine.dart';
import '../../services/feedback_engine.dart';
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
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          const Text('🛡️', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          const Text(
            'Ningún compañero aún',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Comparte tu código o ingresa el de un amigo\npara comenzar a acompañarse en la batalla.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.5),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _navigateToAddPartner,
            icon: const Icon(Icons.person_add_alt_1, size: 18),
            label: const Text('Agregar compañero'),
            style: FilledButton.styleFrom(
              backgroundColor: AppDesignSystem.gold.withOpacity(0.2),
              foregroundColor: AppDesignSystem.gold,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
        title: const Text(
          '¿Desvincular compañero?',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Text(
          'Se dejará de compartir progreso con ${partner.name}. Esta acción no se puede deshacer.',
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Desvincular',
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
}
