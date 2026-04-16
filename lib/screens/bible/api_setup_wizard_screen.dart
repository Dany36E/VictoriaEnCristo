import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/bible/iq_bible_service.dart';

/// Wizard paso-a-paso para configurar la API key de IQ Bible (RapidAPI).
class ApiSetupWizardScreen extends StatefulWidget {
  const ApiSetupWizardScreen({super.key});

  @override
  State<ApiSetupWizardScreen> createState() => _ApiSetupWizardScreenState();
}

class _ApiSetupWizardScreenState extends State<ApiSetupWizardScreen> {
  final _pageController = PageController();
  final _keyController = TextEditingController();
  int _currentPage = 0;
  bool _verifying = false;
  bool? _verified;

  static const _rapidApiUrl =
      'https://rapidapi.com/Wilford/api/iq-bible';

  @override
  void dispose() {
    _pageController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _launchRapidApi() async {
    await Clipboard.setData(const ClipboardData(text: _rapidApiUrl));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('URL copiada al portapapeles. Pégala en tu navegador.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _verifyAndSave() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) return;

    // Validar formato básico de API key
    if (key.length < 10 || !RegExp(r'^[a-zA-Z0-9\-_]+$').hasMatch(key)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La API key no parece válida. Revisa que la hayas copiado bien.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() {
      _verifying = true;
      _verified = null;
    });

    final svc = IqBibleService.instance;

    // Intentar una llamada de prueba
    final result = await svc.getRandomVerse(versionId: 'rvr1960');

    final isOk = result.status == IqStatus.success;

    if (mounted) {
      setState(() {
        _verifying = false;
        _verified = isOk;
      });
      if (isOk) {
        _nextPage();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121729),
        elevation: 0,
        title: Text(
          'CONFIGURAR API',
          style: GoogleFonts.cinzel(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.0,
            color: const Color(0xFFD4AF37),
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Indicador de progreso
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            child: Row(
              children: List.generate(3, (i) {
                return Expanded(
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: i <= _currentPage
                          ? const Color(0xFFD4AF37)
                          : Colors.white12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),
          // Páginas
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (p) => setState(() => _currentPage = p),
              children: [
                _buildStep1(),
                _buildStep2(),
                _buildStep3(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Paso 1: explicación + link a RapidAPI ──────────────────
  Widget _buildStep1() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.api, color: Color(0xFFD4AF37), size: 48),
          const SizedBox(height: 20),
          Text(
            'IQ Bible API',
            style: GoogleFonts.cinzel(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Para acceder a herramientas avanzadas de estudio bíblico '
            '(interlineal, Strong\'s, referencias cruzadas, audio), '
            'necesitas una API key gratuita de RapidAPI.',
            style: GoogleFonts.manrope(
              color: Colors.white70,
              fontSize: 14,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
          _stepTile('1', 'Crea una cuenta gratuita en RapidAPI'),
          _stepTile('2', 'Suscríbete al plan FREE de IQ Bible'),
          _stepTile('3', 'Copia tu API Key y pégala aquí'),
          const Spacer(),
          // Botón ir a RapidAPI
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                _launchRapidApi();
                _nextPage();
              },
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(
                'Ir a RapidAPI',
                style: GoogleFonts.manrope(
                    fontSize: 14, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: const Color(0xFF0A0E1A),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _nextPage,
              child: Text('Ya tengo mi API Key',
                  style: GoogleFonts.manrope(
                      color: const Color(0xFFD4AF37), fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Paso 2: pegar y verificar key ──────────────────────────
  Widget _buildStep2() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.key, color: Color(0xFFD4AF37), size: 48),
          const SizedBox(height: 20),
          Text(
            'Pega tu API Key',
            style: GoogleFonts.cinzel(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Copia la key de tu dashboard de RapidAPI '
            '(sección "X-RapidAPI-Key").',
            style: GoogleFonts.manrope(
              color: Colors.white54,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _keyController,
            style: GoogleFonts.sourceCodePro(
              color: Colors.white,
              fontSize: 13,
            ),
            decoration: InputDecoration(
              hintText: 'xxxxxxxxxxxxxxxxxxxxxxxx',
              hintStyle: GoogleFonts.sourceCodePro(
                color: Colors.white24,
                fontSize: 13,
              ),
              filled: true,
              fillColor: const Color(0xFF121729),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: const Color(0xFFD4AF37).withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFD4AF37)),
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.paste, color: Colors.white38, size: 20),
                onPressed: () async {
                  final data = await Clipboard.getData('text/plain');
                  if (data?.text != null) {
                    _keyController.text = data!.text!;
                  }
                },
              ),
            ),
          ),
          if (_verified == false) ...[
            const SizedBox(height: 8),
            Text(
              'La API key no es válida. Verifica que la copiaste correctamente.',
              style: GoogleFonts.manrope(
                  color: const Color(0xFFE57373), fontSize: 12),
            ),
          ],
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _verifying ? null : _verifyAndSave,
              icon: _verifying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF0A0E1A)),
                    )
                  : const Icon(Icons.verified_outlined, size: 18),
              label: Text(
                _verifying ? 'Verificando...' : 'Verificar y guardar',
                style: GoogleFonts.manrope(
                    fontSize: 14, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: const Color(0xFF0A0E1A),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: _prevPage,
              child: Text('Atrás',
                  style: GoogleFonts.manrope(
                      color: Colors.white54, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Paso 3: confirmación ──────────────────────────────────
  Widget _buildStep3() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF4CAF50).withOpacity(0.15),
            ),
            child: const Icon(Icons.check_circle,
                color: Color(0xFF4CAF50), size: 64),
          ),
          const SizedBox(height: 24),
          Text(
            '¡Configuración exitosa!',
            style: GoogleFonts.cinzel(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Tu API key ha sido verificada y guardada de forma segura. '
            'Ya puedes acceder a:\n\n'
            '• Interlineal hebreo/griego\n'
            '• Números Strong\'s\n'
            '• Referencias cruzadas\n'
            '• Audio de capítulos\n',
            style: GoogleFonts.manrope(
              color: Colors.white70,
              fontSize: 14,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: const Color(0xFF0A0E1A),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Comenzar a estudiar',
                style: GoogleFonts.manrope(
                    fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepTile(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: GoogleFonts.manrope(
                  color: const Color(0xFFD4AF37),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.manrope(
                color: Colors.white70,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
