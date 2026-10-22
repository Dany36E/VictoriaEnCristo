/// ═══════════════════════════════════════════════════════════════════════════
/// BATTLE PARTNER SCREEN - Compañero de Batalla
/// 3 secciones: invitaciones pendientes, compañeros activos, mi código
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/battle_partner_data.dart';
import '../../services/battle_partner_service.dart';
import '../../services/remote_guardian_service.dart';
import '../../services/user_scoped_services.dart';
import '../purity/remote_guardian_screen.dart';
import '../../services/audio_engine.dart';
import '../../utils/clipboard_utils.dart';
import '../../services/feedback_engine.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';
import '../../constants/battle_messages.dart';
import '../../vec/vec_tema.dart';
import '../../vec/vec_widgets.dart';
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
    _bootstrap();
    // Suprimir notificaciones locales de invitaciones/mensajes mientras la
    // pantalla esté visible (la UI ya muestra todo reactivamente).
    NotificationService.isViewingBattlePartner.value = true;
  }

  Future<void> _bootstrap() async {
    await UserScopedServices.I.ensureBattlePartners(syncPublicProgress: true);
    if (!mounted) return;
    await _loadInviteCode();
    await _service.markAllMessagesRead();
  }

  @override
  void dispose() {
    NotificationService.isViewingBattlePartner.value = false;
    super.dispose();
  }

  Future<void> _loadInviteCode() async {
    final code = await _service.getMyInviteCode();
    if (mounted) {
      setState(() {
        _myInviteCode = code;
        _loadingCode = false;
      });
    }
  }

  /// Tema «papel recortado» activo.
  bool get _papel => AppThemeData.of(context).isPaper;

  @override
  Widget build(BuildContext context) {
    if (_papel) return _buildPapel();
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
                  accepting
                      ? Icons.notifications_active
                      : Icons.notifications_off,
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
            icon: const Icon(
              Icons.person_add_alt_1,
              color: AppDesignSystem.gold,
              size: 22,
            ),
            tooltip: 'Agregar compañero',
            onPressed: _navigateToAddPartner,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _service.forceRefresh(),
          color: AppDesignSystem.gold,
          backgroundColor: AppTheme.darkBackground,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              // Banner de pausa (#12)
              _buildPauseBanner(),
              // Solicitudes de "guardián de pureza" entrantes
              _buildGuardianRequestsBanner(),
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
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INVITACIONES PENDIENTES
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildGuardianRequestsBanner() {
    return ValueListenableBuilder<List<GuardianRequest>>(
      valueListenable: RemoteGuardianService.I.incomingRequests,
      builder: (_, requests, _) {
        if (requests.isEmpty) return const SizedBox.shrink();
        final label = requests.length == 1
            ? '${requests.first.protegeName} te pidió ser su guardián de pureza'
            : 'Tienes ${requests.length} solicitudes de guardián de pureza';
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppDesignSystem.gold.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppDesignSystem.gold.withValues(alpha: 0.3),
            ),
          ),
          child: ListTile(
            leading: const Icon(
              Icons.shield_moon_rounded,
              color: AppDesignSystem.gold,
            ),
            title: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            subtitle: const Text(
              'Toca para poner un PIN',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RemoteGuardianScreen()),
            ),
          ),
        );
      },
    );
  }

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
        color: AppDesignSystem.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppDesignSystem.gold.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppDesignSystem.gold.withValues(alpha: 0.15),
            ),
            child: Center(
              child: Text(
                invite.fromName.isNotEmpty
                    ? invite.fromName[0].toUpperCase()
                    : '?',
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
                    color: Colors.white.withValues(alpha: 0.5),
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
            color: color.withValues(alpha: 0.15),
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
          backgroundColor: _papel ? null : AppDesignSystem.midnightLight,
          behavior: SnackBarBehavior.floating,
          shape: _papel
              ? null
              : RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
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
                    color: Colors.white.withValues(alpha: 0.8),
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
    return ValueListenableBuilder<bool>(
      valueListenable: _service.isLoadingNotifier,
      builder: (_, isLoading, _) {
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
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (isLoading && partners.isEmpty)
                  _buildLoadingPartnersState()
                else if (partners.isEmpty)
                  _buildEmptyPartnersState()
                else
                  ...partners.map(
                    (p) => BattlePartnerCard(
                      partner: p,
                      onRemove: () => _confirmRemovePartner(p),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildLoadingPartnersState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      alignment: Alignment.center,
      child: Column(
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppDesignSystem.gold),
            strokeWidth: 2,
          ),
          const SizedBox(height: 14),
          Text(
            'Cargando compañeros…',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
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
            AppDesignSystem.gold.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppDesignSystem.gold.withValues(alpha: 0.18)),
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
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppDesignSystem.gold.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              children: [
                Text(
                  '"Mejores son dos que uno… porque si cayeren, el uno levantará a su compañero."',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontStyle: FontStyle.italic,
                    color: Colors.white.withValues(alpha: 0.82),
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
            'Invita a un hermano de confianza que ore por ti y te acompañe. La app no comparte con él tu diario ni el detalle de tus luchas; sólo verá lo que tú envíes mediante esta función.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.55),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
        backgroundColor: _papel ? null : AppDesignSystem.midnightLight,
        shape: _papel
            ? null
            : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '¿Liberar a ${partner.name}?',
          style: _papel
              ? null
              : const TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Text(
          'Dejarás de compartir tu progreso con ${partner.name}. '
          'No recibirás notificaciones. Podrás reconectar en cualquier '
          'momento volviendo a intercambiar códigos.',
          style: _papel
              ? null
              : TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 13.5,
                  height: 1.45,
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Sí, liberar',
              style: TextStyle(
                color: _papel
                    ? VecColores.terracota
                    : AppDesignSystem.struggle,
              ),
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
            AppDesignSystem.gold.withValues(alpha: 0.08),
            AppDesignSystem.goldDark.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppDesignSystem.gold.withValues(alpha: 0.2)),
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
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppDesignSystem.gold,
              ),
            )
          else if (_myInviteCode != null) ...[
            GestureDetector(
              onTap: _copyCode,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppDesignSystem.gold.withValues(alpha: 0.3),
                  ),
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
                    Icon(
                      Icons.copy,
                      color: AppDesignSystem.gold.withValues(alpha: 0.6),
                      size: 18,
                    ),
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
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _showQrSheet,
              icon: const Icon(
                Icons.qr_code_2,
                size: 20,
                color: AppDesignSystem.gold,
              ),
              label: const Text(
                'Mostrar QR',
                style: TextStyle(color: AppDesignSystem.gold, fontSize: 13),
              ),
            ),
          ] else
            Text(
              'Error generando código',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
        ],
      ),
    );
  }

  void _copyCode() {
    if (_myInviteCode == null) return;
    // Auto-clear: el código de invitación es sensible. Lo borramos del
    // portapapeles tras 60s para reducir la ventana de exposición ante
    // apps maliciosas que monitorean el clipboard.
    copyToClipboardWithAutoClear(_myInviteCode!);
    FeedbackEngine.I.confirm();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _papel
              ? 'Código copiado al portapapeles'
              : '📋 Código copiado al portapapeles',
        ),
        backgroundColor: _papel ? null : AppDesignSystem.midnightLight,
        behavior: SnackBarBehavior.floating,
        shape: _papel
            ? null
            : RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showQrSheet() {
    final code = _myInviteCode;
    if (code == null) return;
    FeedbackEngine.I.tap();
    if (_papel) {
      _showQrSheetPapel(code);
      return;
    }
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
                  color: Colors.white.withValues(alpha: 0.5),
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
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
        if (badge != null && badge > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppDesignSystem.gold.withValues(alpha: 0.2),
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
        content: Text(
          _papel
              ? (next
                    ? 'Aceptando nuevas invitaciones'
                    : 'Invitaciones pausadas. Nadie podrá agregarte por ahora.')
              : (next
                    ? '✅ Aceptando nuevas invitaciones'
                    : '⏸️ Invitaciones pausadas. Nadie podrá agregarte por ahora.'),
        ),
        backgroundColor: _papel ? null : AppDesignSystem.midnightLight,
        behavior: SnackBarBehavior.floating,
        shape: _papel
            ? null
            : RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
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
                  AppDesignSystem.struggle.withValues(alpha: 0.15),
                  AppDesignSystem.struggle.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppDesignSystem.struggle.withValues(alpha: 0.35),
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
                    color: Colors.white.withValues(alpha: 0.7),
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
                        label: Text(
                          remaining > 0
                              ? 'Pedir oración urgente'
                              : 'Disponible mañana',
                        ),
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
                    color: Colors.white.withValues(alpha: 0.4),
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
        backgroundColor: _papel ? null : AppDesignSystem.midnightLight,
        shape: _papel
            ? null
            : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '¿Pedir oración urgente?',
          style: _papel
              ? null
              : const TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Text(
          'Se notificará a todos tus compañeros de batalla que necesitas oración ahora. Solo puedes hacerlo 1 vez al día.',
          style: _papel
              ? null
              : TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                  height: 1.4,
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: _papel
                ? null
                : FilledButton.styleFrom(
                    backgroundColor: AppDesignSystem.struggle,
                  ),
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
        content: Text(
          sent > 0
              ? '${_papel ? '' : '🆘 '}Se notificó a $sent compañero${sent == 1 ? '' : 's'}. Están orando contigo.'
              : 'No se pudo enviar la alerta (rate-limit o sin compañeros).',
        ),
        backgroundColor: _papel ? null : AppDesignSystem.midnightLight,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
    setState(() {}); // refrescar el botón (remaining)
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TEMA PAPEL — «papel recortado» (kit victoria-en-cristo-estilo)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPapel() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Compañero de batalla'),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: _service.acceptingInvitesNotifier,
            builder: (_, accepting, _) {
              return IconButton(
                icon: Icon(
                  accepting
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_off_rounded,
                  color: accepting ? VecColores.tinta : VecColores.mostaza,
                ),
                tooltip: accepting
                    ? 'Pausar nuevas invitaciones'
                    : 'Reanudar invitaciones',
                onPressed: _togglePauseInvites,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded),
            tooltip: 'Agregar compañero',
            onPressed: _navigateToAddPartner,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _service.forceRefresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
            children: [
              const PopIn(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Sticker(
                      'assets/vec/personajes/timoteo_corazon.png',
                      alto: 120,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Subtitulo(
                        quien: 'Timoteo',
                        color: VecColores.azul,
                        texto: 'No caminamos solos en esta batalla.',
                        clave: 'solos',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              _buildPauseBannerPapel(),
              _buildGuardianBannerPapel(),
              _buildInvitesPapel(),
              _buildMessagesPapel(),
              _buildPartnersPapel(),
              _buildSosPapel(),
              const SizedBox(height: 30),
              _buildMyCodePapel(),
            ],
          ),
        ),
      ),
    );
  }

  /// Casilla de aviso en papel con ícono en círculo.
  Widget _avisoPapel({
    required Widget icono,
    required String texto,
    String? subtitulo,
    Color color = VecColores.mostaza,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(VecRadios.m),
          ),
          child: Row(
            children: [
              icono,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      texto,
                      style: const TextStyle(
                        fontFamily: VecFuentes.titulo,
                        fontSize: 16,
                        color: VecColores.tinta,
                      ),
                    ),
                    if (subtitulo != null)
                      Text(
                        subtitulo,
                        style: const TextStyle(
                          fontFamily: VecFuentes.texto,
                          fontSize: 16,
                          color: VecColores.gris,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPauseBannerPapel() {
    return ValueListenableBuilder<bool>(
      valueListenable: _service.acceptingInvitesNotifier,
      builder: (_, accepting, _) {
        if (accepting) return const SizedBox.shrink();
        return _avisoPapel(
          icono: const CirculoIcono(
            icono: Icons.pause_rounded,
            color: VecColores.mostaza,
            tamano: 36,
          ),
          texto: 'Invitaciones pausadas',
          subtitulo: 'Tus compañeros actuales siguen activos.',
        );
      },
    );
  }

  Widget _buildGuardianBannerPapel() {
    return ValueListenableBuilder<List<GuardianRequest>>(
      valueListenable: RemoteGuardianService.I.incomingRequests,
      builder: (_, requests, _) {
        if (requests.isEmpty) return const SizedBox.shrink();
        return _avisoPapel(
          icono: const CirculoIcono(
            iconoVec: 'escudo',
            color: VecColores.azul,
            tamano: 40,
          ),
          color: VecColores.azulClaro,
          texto: requests.length == 1
              ? '${requests.first.protegeName} te pidió ser su guardián de pureza'
              : 'Tienes ${requests.length} solicitudes de guardián de pureza',
          subtitulo: 'Toca para poner un PIN',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RemoteGuardianScreen()),
          ),
        );
      },
    );
  }

  Widget _encabezadoPapel(String titulo, {int? cuenta, String? extra}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(child: EtiquetaSeccion(titulo)),
          if (cuenta != null && cuenta > 0)
            ChipVec(texto: '$cuenta', color: VecColores.terracota, giro: 2),
          if (extra != null)
            Text(
              extra,
              style: const TextStyle(
                fontFamily: VecFuentes.titulo,
                fontSize: 16,
                color: VecColores.gris,
              ),
            ),
        ],
      ),
    );
  }

  /// Inicial del compañero en círculo de color (avatar de papel).
  Widget _inicialPapel(String nombre, {Color color = VecColores.terracota}) {
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(color: Color(0x402B2622), offset: Offset(0, 5)),
        ],
      ),
      child: Text(
        nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
        style: const TextStyle(
          fontFamily: VecFuentes.titulo,
          fontSize: 22,
          color: VecColores.papel,
        ),
      ),
    );
  }

  Widget _buildInvitesPapel() {
    return ValueListenableBuilder<List<PartnerInvite>>(
      valueListenable: _service.pendingInvitesNotifier,
      builder: (_, invites, _) {
        if (invites.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _encabezadoPapel('Invitaciones pendientes', cuenta: invites.length),
            for (final invite in invites)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: AppThemeData.of(context).cardDecoration,
                child: Row(
                  children: [
                    _inicialPapel(invite.fromName),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            invite.fromName,
                            style: const TextStyle(
                              fontFamily: VecFuentes.titulo,
                              fontSize: 18,
                              color: VecColores.tinta,
                            ),
                          ),
                          const Text(
                            'Quiere ser tu compañero de batalla',
                            style: TextStyle(
                              fontFamily: VecFuentes.texto,
                              fontSize: 16,
                              color: VecColores.gris,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: 'Aceptar invitación',
                      child: GestureDetector(
                        onTap: () => _acceptInvite(invite),
                        child: const CirculoIcono(
                          iconoVec: 'palomita',
                          color: VecColores.verde,
                          tamano: 42,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Semantics(
                      button: true,
                      label: 'Rechazar invitación',
                      child: GestureDetector(
                        onTap: () => _rejectInvite(invite),
                        child: const CirculoIcono(
                          icono: Icons.close_rounded,
                          color: VecColores.terracota,
                          tamano: 42,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  Widget _buildMessagesPapel() {
    return ValueListenableBuilder<List<BattleMessageData>>(
      valueListenable: _service.unreadMessagesNotifier,
      builder: (_, messages, _) {
        if (messages.isEmpty) return const SizedBox.shrink();
        final partners = _service.partnersNotifier.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _encabezadoPapel('Mensajes recientes', cuenta: messages.length),
            for (final msg in messages.take(5))
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: AppThemeData.of(context).cardDecoration,
                child: Row(
                  children: [
                    const CirculoIcono(
                      iconoVec: 'mensaje',
                      color: VecColores.azulClaro,
                      tamano: 40,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            partners
                                    .where((p) => p.uid == msg.fromUid)
                                    .firstOrNull
                                    ?.name ??
                                'Compañero',
                            style: const TextStyle(
                              fontFamily: VecFuentes.titulo,
                              fontSize: 16,
                              color: VecColores.terracota,
                            ),
                          ),
                          Text(
                            kBattleMessageMap[msg.messageKey]?.textoSinEmoji ??
                                msg.messageKey,
                            style: const TextStyle(
                              fontFamily: VecFuentes.texto,
                              fontSize: 17,
                              height: 1.2,
                              color: VecColores.tinta,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  Widget _buildPartnersPapel() {
    return ValueListenableBuilder<bool>(
      valueListenable: _service.isLoadingNotifier,
      builder: (_, isLoading, _) {
        return ValueListenableBuilder<List<BattlePartnerData>>(
          valueListenable: _service.partnersNotifier,
          builder: (_, partners, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _encabezadoPapel(
                  'Compañeros de batalla',
                  extra: '${partners.length}/$kMaxBattlePartners',
                ),
                if (isLoading && partners.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (partners.isEmpty)
                  _buildEmptyPartnersPapel()
                else
                  ...partners.map(
                    (p) => BattlePartnerCard(
                      partner: p,
                      onRemove: () => _confirmRemovePartner(p),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  /// Pantalla vacía: Timoteo y Victoria acompañan, con el versículo.
  Widget _buildEmptyPartnersPapel() {
    return Column(
      children: [
        const PopIn(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Sticker('assets/vec/personajes/timoteo_saludo.png', alto: 150),
              Sticker('assets/vec/personajes/victoria_saludo.png', alto: 150),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const TituloVec(
          'No estás solo en esta batalla',
          clave: 'solo',
          tamano: 24,
          alineacion: TextAlign.center,
        ),
        const SizedBox(height: 22),
        const PopIn(
          retraso: Duration(milliseconds: 120),
          child: TarjetaVersiculo(
            referencia: 'Eclesiastés 4:9-10',
            texto:
                'Mejores son dos que uno… porque si cayeren, el uno levantará a su compañero.',
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Invita a un hermano de confianza que ore por ti y te acompañe. La app no comparte con él tu diario ni el detalle de tus luchas; sólo verá lo que tú envíes mediante esta función.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: VecFuentes.texto,
            fontSize: 16,
            height: 1.25,
            color: VecColores.gris,
          ),
        ),
        const SizedBox(height: 18),
        BotonVec(
          texto: 'Conecta tu primer compañero',
          icono: Icons.person_add_alt_1_rounded,
          onPressed: _navigateToAddPartner,
        ),
      ],
    );
  }

  Widget _buildSosPapel() {
    return ValueListenableBuilder<List<BattlePartnerData>>(
      valueListenable: _service.partnersNotifier,
      builder: (_, partners, _) {
        if (partners.isEmpty) return const SizedBox.shrink();
        final remaining = _service.remainingSosToday();
        return Padding(
          padding: const EdgeInsets.only(top: 26),
          child: TarjetaPapel(
            giro: 1,
            cintaDerecha: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    CirculoIcono(
                      iconoVec: 'mano_alto',
                      color: VecColores.terracota,
                      tamano: 44,
                      giro: -4,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: TituloVec(
                        'Oren por mí ahora',
                        clave: 'ahora',
                        tamano: 22,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Envía una alerta urgente a todos tus compañeros de batalla para que oren por ti en este momento.',
                  style: TextStyle(
                    fontFamily: VecFuentes.texto,
                    fontSize: 17,
                    height: 1.25,
                    color: VecColores.tinta,
                  ),
                ),
                const SizedBox(height: 16),
                BotonVec(
                  texto: remaining > 0
                      ? 'Pedir oración urgente'
                      : 'Disponible mañana',
                  iconoWidget: const IconoVec('orar'),
                  expandido: true,
                  onPressed: remaining > 0 ? _triggerSos : null,
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    remaining > 0
                        ? 'Disponible 1 vez al día'
                        : 'Vuelve a usarlo mañana',
                    style: const TextStyle(
                      fontFamily: VecFuentes.texto,
                      fontSize: 15,
                      color: VecColores.gris,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMyCodePapel() {
    return TarjetaPapel(
      child: Column(
        children: [
          const TituloVec(
            'Tu código de invitación',
            clave: 'código',
            tamano: 22,
            alineacion: TextAlign.center,
          ),
          const SizedBox(height: 14),
          if (_loadingCode)
            const CircularProgressIndicator()
          else if (_myInviteCode != null) ...[
            Semantics(
              button: true,
              label: 'Copiar código $_myInviteCode',
              child: GestureDetector(
                onTap: _copyCode,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(22, 10, 16, 8),
                  decoration: BoxDecoration(
                    color: VecColores.cremaOscuro,
                    borderRadius: BorderRadius.circular(VecRadios.pildora),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _myInviteCode!,
                        style: const TextStyle(
                          fontFamily: VecFuentes.titulo,
                          fontSize: 28,
                          letterSpacing: 3,
                          color: VecColores.tinta,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.copy_rounded,
                        color: VecColores.gris,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Toca para copiar • Comparte solo con personas de confianza',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: VecFuentes.texto,
                fontSize: 15,
                color: VecColores.gris,
              ),
            ),
            const SizedBox(height: 16),
            BotonVec(
              texto: 'Mostrar QR',
              icono: Icons.qr_code_2_rounded,
              color: VecColores.papel,
              colorTexto: VecColores.tinta,
              onPressed: _showQrSheet,
            ),
          ] else
            const Text(
              'Error generando código',
              style: TextStyle(
                fontFamily: VecFuentes.texto,
                fontSize: 16,
                color: VecColores.gris,
              ),
            ),
        ],
      ),
    );
  }

  void _showQrSheetPapel(String code) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const TituloVec('Tu código QR', clave: 'QR', tamano: 24),
              const SizedBox(height: 4),
              const Text(
                'Que tu compañero lo escanee con otra app escáner',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: VecFuentes.texto,
                  fontSize: 16,
                  color: VecColores.gris,
                ),
              ),
              const SizedBox(height: 20),
              // Tinta sobre papel: contraste suficiente para escanear.
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: VecColores.papel,
                  borderRadius: BorderRadius.circular(VecRadios.m),
                  boxShadow: VecSombras.papel,
                ),
                child: QrImageView(
                  data: 'victoria://battle/invite?code=$code',
                  size: 220,
                  version: QrVersions.auto,
                  backgroundColor: VecColores.papel,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: VecColores.tinta,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: VecColores.tinta,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                code,
                style: const TextStyle(
                  fontFamily: VecFuentes.titulo,
                  fontSize: 26,
                  letterSpacing: 4,
                  color: VecColores.tinta,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
