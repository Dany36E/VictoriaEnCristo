import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/bible/blb_api_service.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../theme/bible_reader_theme.dart';

/// Pantalla con instrucciones de configuración y campo rápido
/// para pegar la API key de Blue Letter Bible.
class BlbSetupScreen extends StatefulWidget {
  const BlbSetupScreen({super.key});

  @override
  State<BlbSetupScreen> createState() => _BlbSetupScreenState();
}

class _BlbSetupScreenState extends State<BlbSetupScreen> {
  final _keyController = TextEditingController();
  final _blb = BlbApiService.instance;
  bool _verifying = false;
  bool? _verified; // null = no verificado, true = válido, false = inválido

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _saveAndVerify() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) return;

    setState(() {
      _verifying = true;
      _verified = null;
    });

    try {
      // Guardar la key temporalmente para verificar
      await _blb.setApiKey(key);

      // Verificar con una petición de prueba real a la API
      final isValid = await _blb.verifyApiKey();

      if (!mounted) return;

      if (!isValid) {
        // Revertir la key inválida
        await _blb.setApiKey('');
      }

      if (!mounted) return;

      setState(() {
        _verifying = false;
        _verified = isValid;
      });

      if (isValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ API key válida y guardada',
                style: GoogleFonts.manrope()),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✗ API key inválida — verifica tu clave',
                style: GoogleFonts.manrope()),
            backgroundColor: const Color(0xFFE57373),
          ),
        );
      }
    } catch (e) {
      // Revertir en caso de error de red
      await _blb.setApiKey('');
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _verified = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error verificando key: $e',
              style: GoogleFonts.manrope()),
          backgroundColor: const Color(0xFFE57373),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = BibleReaderThemeData.fromId(BibleReaderThemeData.migrateId(BibleUserDataService.I.readerThemeNotifier.value));
    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.surface,
        title: Text(
          'Blue Letter Bible',
          style: GoogleFonts.cinzel(
            color: t.accent,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: IconThemeData(color: t.accent),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  t.accent.withValues(alpha: 0.15),
                  t.surface.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: t.accent.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Icon(Icons.school_outlined,
                    size: 48, color: t.accent),
                const SizedBox(height: 12),
                Text(
                  'Herramientas de Estudio',
                  style: GoogleFonts.cinzel(
                    color: t.accent,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Accede a Strong\'s Numbers, Lexicón Griego/Hebreo '
                  'y Referencias Cruzadas directamente desde tu Biblia.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    color: t.textPrimary.withValues(alpha: 0.7),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Pasos
          _buildStep(
            t: t,
            number: 1,
            title: 'Solicita tu API Key',
            description: 'Visita Blue Letter Bible y completa el formulario '
                'de solicitud. Es gratuito.',
            actionLabel: 'Solicitar en blueletterbible.org',
            icon: Icons.open_in_new,
          ),
          _buildStep(
            t: t,
            number: 2,
            title: 'Espera el correo',
            description: 'Recibirás tu API key por email. '
                'Puede tardar de 1 a 3 días hábiles.',
            icon: Icons.email_outlined,
          ),
          _buildStep(
            t: t,
            number: 3,
            title: 'Pega tu API Key aquí',
            description: 'Copia la key del correo y pégala en el campo '
                'de abajo para activar las herramientas.',
            icon: Icons.content_paste,
          ),
          const SizedBox(height: 8),

          // Campo de API key
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: t.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: t.accent.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'API KEY',
                  style: GoogleFonts.cinzel(
                    color: t.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _keyController,
                  obscureText: true,
                  style: GoogleFonts.manrope(
                    color: t.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Pega tu API key aquí...',
                    hintStyle: GoogleFonts.manrope(
                      color:
                          t.textPrimary.withValues(alpha: 0.3),
                    ),
                    filled: true,
                    fillColor: t.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color:
                              t.accent.withValues(alpha: 0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color:
                              t.accent.withValues(alpha: 0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: t.accent, width: 1.5),
                    ),
                    suffixIcon: _verified == true
                        ? const Icon(Icons.check_circle,
                            color: Color(0xFF4CAF50))
                        : _verified == false
                            ? const Icon(Icons.error,
                                color: Color(0xFFE57373))
                            : null,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _verifying ? null : _saveAndVerify,
                    icon: _verifying
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: t.background,
                            ),
                          )
                        : const Icon(Icons.verified_outlined, size: 18),
                    label: Text(
                      _verifying ? 'Verificando...' : 'Guardar y verificar',
                      style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: t.accent,
                      foregroundColor: t.background,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                if (_verified == false) ...[
                  const SizedBox(height: 12),
                  Text(
                    'La API key no es válida. Verifica que la copiaste '
                    'correctamente.',
                    style: GoogleFonts.manrope(
                      color: const Color(0xFFE57373),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Info del plan
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.surface.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16,
                        color: t.accent.withValues(alpha: 0.6)),
                    const SizedBox(width: 8),
                    Text(
                      'Plan Gratuito',
                      style: GoogleFonts.manrope(
                        color: t.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• ~500 peticiones por día\n'
                  '• Datos cacheados automáticamente\n'
                  '• Lexicón se guarda permanentemente\n'
                  '• Referencias cruzadas se guardan 30 días',
                  style: GoogleFonts.manrope(
                    color: t.textPrimary.withValues(alpha: 0.5),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildStep({
    required BibleReaderThemeData t,
    required int number,
    required String title,
    required String description,
    required IconData icon,
    String? actionLabel,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: t.accent.withValues(alpha: 0.15),
              border: Border.all(
                  color: t.accent.withValues(alpha: 0.4)),
            ),
            alignment: Alignment.center,
            child: Text(
              '$number',
              style: GoogleFonts.cinzel(
                color: t.accent,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    color: t.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.manrope(
                    color: t.textPrimary.withValues(alpha: 0.5),
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
}
