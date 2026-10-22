/// ═══════════════════════════════════════════════════════════════════════════
/// ADD PARTNER SCREEN - Agregar compañero por código
/// Input de 8 chars (auto-uppercase), preview, confirmar
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/battle_partner_data.dart';
import '../../services/battle_partner_service.dart';
import '../../services/feedback_engine.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';
import '../../vec/vec_tema.dart';
import '../../vec/vec_widgets.dart';

class AddPartnerScreen extends StatefulWidget {
  const AddPartnerScreen({super.key});

  @override
  State<AddPartnerScreen> createState() => _AddPartnerScreenState();
}

class _AddPartnerScreenState extends State<AddPartnerScreen> {
  final _codeController = TextEditingController();
  final _service = BattlePartnerService.I;

  InviteResult? _lookupResult;
  bool _searching = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _codeController.addListener(_onCodeChanged);
  }

  void _onCodeChanged() {
    // Rebuild so the search button enabling/disabling updates in real time
    setState(() {});
  }

  @override
  void dispose() {
    _codeController.removeListener(_onCodeChanged);
    _codeController.dispose();
    super.dispose();
  }

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
          'Agregar compañero',
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
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icono
              const Center(
                child: Text('🤝', style: TextStyle(fontSize: 48)),
              ),
              const SizedBox(height: 16),

              // Título
              const Text(
                'Ingresa el código de tu compañero',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pide a tu amigo que te comparta su código\nde 8 caracteres desde su pantalla.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.5),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              // Input de código
              _buildCodeInput(),
              const SizedBox(height: 14),

              // Botón buscar
              _buildSearchButton(),
              const SizedBox(height: 20),

              // Preview / Error
              if (_lookupResult != null) _buildResultSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCodeInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: TextField(
        controller: _codeController,
        maxLength: 8,
        textCapitalization: TextCapitalization.characters,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 4,
          fontFamily: 'monospace',
        ),
        decoration: InputDecoration(
          hintText: 'XXXXXXXX',
          hintStyle: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w300,
            color: Colors.white.withValues(alpha: 0.15),
            letterSpacing: 4,
          ),
          counterText: '',
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
          UpperCaseTextFormatter(),
        ],
        onChanged: (_) {
          if (_lookupResult != null) {
            setState(() => _lookupResult = null);
          }
        },
      ),
    );
  }

  Widget _buildSearchButton() {
    final codeReady = _codeController.text.trim().length == 8;
    return FilledButton(
      onPressed: codeReady && !_searching ? _lookup : null,
      style: FilledButton.styleFrom(
        backgroundColor: AppDesignSystem.gold.withValues(alpha: codeReady ? 0.25 : 0.08),
        foregroundColor: codeReady ? AppDesignSystem.gold : Colors.white.withValues(alpha: 0.3),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: _searching
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppDesignSystem.gold),
            )
          : const Text('Buscar compañero', style: TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildResultSection() {
    final result = _lookupResult!;

    switch (result.type) {
      case InviteResultType.success:
        return _buildPreviewCard(result);
      case InviteResultType.selfInvite:
        return _errorCard('🤔', 'Ese es tu propio código', 'No puedes invitarte a ti mismo.');
      case InviteResultType.alreadyLinked:
        return _errorCard('🔗', 'Ya están vinculados', 'Este compañero ya está en tu lista o tiene una invitación pendiente.');
      case InviteResultType.limitReached:
        return _errorCard('⚠️', 'Límite alcanzado', 'Solo puedes tener $kMaxBattlePartners compañeros. Desvincula uno para agregar otro.');
      case InviteResultType.notFound:
        return _errorCard('❓', 'Código no encontrado', 'Verifica que el código sea correcto e intenta de nuevo.');
      case InviteResultType.targetPaused:
        return _errorCard(
          '⏸️',
          'Invitaciones pausadas',
          'Esta persona ha pausado las nuevas invitaciones por ahora. Inténtalo más adelante.',
        );
      case InviteResultType.error:
        return _errorCard('⚠️', 'Error', result.errorMessage ?? 'Intenta de nuevo más tarde.');
    }
  }

  Widget _buildPreviewCard(InviteResult result) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppDesignSystem.victory.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppDesignSystem.victory.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          // Avatar + nombre
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppDesignSystem.gold.withValues(alpha: 0.15),
              border: Border.all(color: AppDesignSystem.gold.withValues(alpha: 0.4)),
            ),
            child: Center(
              child: Text(
                result.targetName != null && result.targetName!.isNotEmpty
                    ? result.targetName![0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppDesignSystem.gold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            result.targetName ?? 'Usuario',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '¿Enviar solicitud de compañero?',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _sending ? null : _sendInvite,
            icon: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.handshake, size: 18),
            label: Text(_sending ? 'Enviando...' : 'Enviar solicitud'),
            style: FilledButton.styleFrom(
              backgroundColor: AppDesignSystem.gold.withValues(alpha: 0.3),
              foregroundColor: AppDesignSystem.gold,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorCard(String emoji, String title, String description) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.5),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TEMA PAPEL
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPapel() {
    final codeReady = _codeController.text.trim().length == 8;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Agregar compañero')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PopIn(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Sticker(
                      'assets/vec/personajes/victoria_explica.png',
                      alto: 130,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Subtitulo(
                        quien: 'Victoria',
                        texto: 'Ingresa el código de tu compañero',
                        clave: 'código',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Pide a tu amigo que te comparta su código de 8 caracteres desde su pantalla.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: VecFuentes.texto,
                  fontSize: 17,
                  height: 1.25,
                  color: VecColores.gris,
                ),
              ),
              const SizedBox(height: 22),
              TextField(
                controller: _codeController,
                maxLength: 8,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: VecFuentes.titulo,
                  fontSize: 30,
                  letterSpacing: 4,
                  color: VecColores.tinta,
                ),
                decoration: const InputDecoration(
                  hintText: 'XXXXXXXX',
                  counterText: '',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                  UpperCaseTextFormatter(),
                ],
                onChanged: (_) {
                  if (_lookupResult != null) {
                    setState(() => _lookupResult = null);
                  }
                },
              ),
              const SizedBox(height: 20),
              BotonVec(
                texto: 'Buscar compañero',
                icono: Icons.search_rounded,
                expandido: true,
                cargando: _searching,
                onPressed: codeReady ? _lookup : null,
              ),
              const SizedBox(height: 30),
              if (_lookupResult != null) _buildResultPapel(_lookupResult!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultPapel(InviteResult result) {
    if (result.type == InviteResultType.success) {
      final nombre = result.targetName ?? 'Usuario';
      return PopIn(
        child: TarjetaPapel(
          child: Column(
            children: [
              Container(
                width: 60,
                height: 60,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: VecColores.azul,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Color(0x402B2622), offset: Offset(0, 5)),
                  ],
                ),
                child: Text(
                  nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontFamily: VecFuentes.titulo,
                    fontSize: 28,
                    color: VecColores.papel,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TituloVec(nombre, tamano: 24, alineacion: TextAlign.center),
              const SizedBox(height: 4),
              const Text(
                '¿Enviar solicitud de compañero?',
                style: TextStyle(
                  fontFamily: VecFuentes.texto,
                  fontSize: 17,
                  color: VecColores.gris,
                ),
              ),
              const SizedBox(height: 16),
              BotonVec(
                texto: _sending ? 'Enviando...' : 'Enviar solicitud',
                iconoWidget: const IconoVec('manos'),
                color: VecColores.verde,
                cargando: _sending,
                onPressed: _sendInvite,
              ),
            ],
          ),
        ),
      );
    }
    final (icono, titulo, descripcion) = switch (result.type) {
      InviteResultType.selfInvite => (
        'idea',
        'Ese es tu propio código',
        'No puedes invitarte a ti mismo.',
      ),
      InviteResultType.alreadyLinked => (
        'enlace',
        'Ya están vinculados',
        'Este compañero ya está en tu lista o tiene una invitación pendiente.',
      ),
      InviteResultType.limitReached => (
        'personas',
        'Límite alcanzado',
        'Solo puedes tener $kMaxBattlePartners compañeros. Desvincula uno para agregar otro.',
      ),
      InviteResultType.notFound => (
        'ojo',
        'Código no encontrado',
        'Verifica que el código sea correcto e intenta de nuevo.',
      ),
      InviteResultType.targetPaused => (
        'reloj',
        'Invitaciones pausadas',
        'Esta persona ha pausado las nuevas invitaciones por ahora. Inténtalo más adelante.',
      ),
      _ => (
        'mano_alto',
        'Error',
        result.errorMessage ?? 'Intenta de nuevo más tarde.',
      ),
    };
    return PopIn(
      child: Column(
        children: [
          const Sticker(
            'assets/vec/personajes/timoteo_preocupado.png',
            alto: 140,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppThemeData.of(context).cardDecoration,
            child: Row(
              children: [
                CirculoIcono(
                  iconoVec: icono,
                  color: VecColores.mostaza,
                  tamano: 44,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(
                          fontFamily: VecFuentes.titulo,
                          fontSize: 18,
                          color: VecColores.tinta,
                        ),
                      ),
                      Text(
                        descripcion,
                        style: const TextStyle(
                          fontFamily: VecFuentes.texto,
                          fontSize: 16,
                          height: 1.2,
                          color: VecColores.gris,
                        ),
                      ),
                    ],
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
  // ACTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _lookup() async {
    FeedbackEngine.I.tap();
    setState(() { _searching = true; _lookupResult = null; });

    final result = await _service.lookupCode(_codeController.text.trim());

    if (mounted) {
      setState(() { _lookupResult = result; _searching = false; });
    }
  }

  Future<void> _sendInvite() async {
    FeedbackEngine.I.confirm();
    setState(() => _sending = true);

    final result = await _service.sendInviteByCode(_codeController.text.trim());

    if (mounted) {
      setState(() => _sending = false);
      if (result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_papel ? '' : '✅ '}Solicitud enviada a ${result.targetName}',
            ),
            backgroundColor: _papel ? null : AppDesignSystem.midnightLight,
            behavior: SnackBarBehavior.floating,
            shape: _papel
                ? null
                : RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context);
      } else {
        setState(() => _lookupResult = result);
      }
    }
  }
}

/// Formatter para auto-uppercase
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
