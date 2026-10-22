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


  @override
  Widget build(BuildContext context) {
    return _buildPapel();
  }


  // ═══════════════════════════════════════════════════════════════════════════
  // PAPEL RECORTADO
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
              Text(
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
                style: TextStyle(
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
                decoration: BoxDecoration(
                  color: VecColores.azul,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(color: Color(0x402B2622), offset: Offset(0, 5)),
                  ],
                ),
                child: Text(
                  nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontFamily: VecFuentes.titulo,
                    fontSize: 28,
                    color: VecColores.papel,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TituloVec(nombre, tamano: 24, alineacion: TextAlign.center),
              const SizedBox(height: 4),
              Text(
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
                        style: TextStyle(
                          fontFamily: VecFuentes.titulo,
                          fontSize: 18,
                          color: VecColores.tinta,
                        ),
                      ),
                      Text(
                        descripcion,
                        style: TextStyle(
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
              '${''}Solicitud enviada a ${result.targetName}',
            ),
            behavior: SnackBarBehavior.floating,
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
