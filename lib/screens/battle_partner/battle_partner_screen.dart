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


  @override
  Widget build(BuildContext context) {
    return _buildPapel();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INVITACIONES PENDIENTES
  // ═══════════════════════════════════════════════════════════════════════════


  Future<void> _acceptInvite(PartnerInvite invite) async {
    FeedbackEngine.I.confirm();
    final ok = await _service.acceptInvite(invite);
    if (mounted && ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡${invite.fromName} ya es tu compañero! ⚔️'),
          behavior: SnackBarBehavior.floating,
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


  // ═══════════════════════════════════════════════════════════════════════════
  // COMPAÑEROS ACTIVOS
  // ═══════════════════════════════════════════════════════════════════════════


  Future<void> _confirmRemovePartner(BattlePartnerData partner) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '¿Liberar a ${partner.name}?',
        ),
        content: Text(
          'Dejarás de compartir tu progreso con ${partner.name}. '
          'No recibirás notificaciones. Podrás reconectar en cualquier '
          'momento volviendo a intercambiar códigos.',
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
                color: VecColores.terracota,
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


  void _copyCode() {
    if (_myInviteCode == null) return;
    // Auto-clear: el código de invitación es sensible. Lo borramos del
    // portapapeles tras 60s para reducir la ventana de exposición ante
    // apps maliciosas que monitorean el clipboard.
    copyToClipboardWithAutoClear(_myInviteCode!);
    FeedbackEngine.I.confirm();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Código copiado al portapapeles',
        ),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showQrSheet() {
    final code = _myInviteCode;
    if (code == null) return;
    FeedbackEngine.I.tap();
    _showQrSheetPapel(code);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS UI
  // ═══════════════════════════════════════════════════════════════════════════


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
          (next
                    ? 'Aceptando nuevas invitaciones'
                    : 'Invitaciones pausadas. Nadie podrá agregarte por ahora.'),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }


  // ═══════════════════════════════════════════════════════════════════════════
  // SOS "Oren por mí ahora" (#16)
  // ═══════════════════════════════════════════════════════════════════════════


  Future<void> _triggerSos() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          '¿Pedir oración urgente?',
        ),
        content: const Text(
          'Se notificará a todos tus compañeros de batalla que necesitas oración ahora. Solo puedes hacerlo 1 vez al día.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
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
              ? '${''}Se notificó a $sent compañero${sent == 1 ? '' : 's'}. Están orando contigo.'
              : 'No se pudo enviar la alerta (rate-limit o sin compañeros).',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
    setState(() {}); // refrescar el botón (remaining)
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PAPEL RECORTADO — «papel recortado» (kit victoria-en-cristo-estilo)
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
              PopIn(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Sticker(
                      'assets/vec/personajes/timoteo_corazon.png',
                      alto: 120,
                    ),
                    const SizedBox(width: 8),
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
    Color? color,
    VoidCallback? onTap,
  }) {
    color ??= VecColores.mostaza;
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
                      style: TextStyle(
                        fontFamily: VecFuentes.titulo,
                        fontSize: 16,
                        color: VecColores.tinta,
                      ),
                    ),
                    if (subtitulo != null)
                      Text(
                        subtitulo,
                        style: TextStyle(
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
          icono: CirculoIcono(
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
          icono: CirculoIcono(
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
              style: TextStyle(
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
  Widget _inicialPapel(String nombre, {Color? color}) {
    color ??= VecColores.terracota;
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
        style: TextStyle(
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
                            style: TextStyle(
                              fontFamily: VecFuentes.titulo,
                              fontSize: 18,
                              color: VecColores.tinta,
                            ),
                          ),
                          Text(
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
                        child: CirculoIcono(
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
                        child: CirculoIcono(
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
                    CirculoIcono(
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
                            style: TextStyle(
                              fontFamily: VecFuentes.titulo,
                              fontSize: 16,
                              color: VecColores.terracota,
                            ),
                          ),
                          Text(
                            kBattleMessageMap[msg.messageKey]?.textoSinEmoji ??
                                msg.messageKey,
                            style: TextStyle(
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
        Text(
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
                Row(
                  children: [
                    CirculoIcono(
                      iconoVec: 'mano_alto',
                      color: VecColores.terracota,
                      tamano: 44,
                      giro: -4,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: TituloVec(
                        'Oren por mí ahora',
                        clave: 'ahora',
                        tamano: 22,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
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
                    style: TextStyle(
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
                        style: TextStyle(
                          fontFamily: VecFuentes.titulo,
                          fontSize: 28,
                          letterSpacing: 3,
                          color: VecColores.tinta,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        Icons.copy_rounded,
                        color: VecColores.gris,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
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
            Text(
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
              Text(
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
                  eyeStyle: QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: VecColores.tinta,
                  ),
                  dataModuleStyle: QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: VecColores.tinta,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                code,
                style: TextStyle(
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
