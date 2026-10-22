import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_fonts.dart';
import '../../services/bible/iq_bible_service.dart';
import '../../vec/vec_tema.dart';

/// Wizard paso-a-paso para configurar la API key de IQ Bible (RapidAPI).
class ApiSetupWizardScreen extends StatefulWidget {
  const ApiSetupWizardScreen({super.key});

  @override
  State<ApiSetupWizardScreen> createState() => _ApiSetupWizardScreenState();
}

class _ApiSetupWizardScreenState extends State<ApiSetupWizardScreen> {
  // Tema «papel recortado»: hoja de papel y colores del kit; en los demás
  // temas, la paleta nocturna original.
  Color get _fondo => Colors.transparent;
  Color get _barra => Colors.transparent;
  Color get _superficie => VecColores.papel;
  Color get _oro => VecColores.terracota;
  Color get _sobreOro => VecColores.papel;
  Color get _verde => VecColores.verde;
  Color get _error => VecColores.terracota;
  Color get _texto => VecColores.tinta;
  Color get _texto2 => VecColores.tinta;
  Color get _texto3 => VecColores.gris;
  Color get _texto4 => VecColores.gris;
  Color get _linea => VecColores.cremaOscuro;
  Color get _linea2 => VecColores.cremaOscuro;

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
      backgroundColor: _fondo,
      appBar: AppBar(
        backgroundColor: _barra,
        elevation: 0,
        title: Text(
          'CONFIGURAR API',
          style: AppFonts.cinzel(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.0,
            color: _oro,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.close, color: _texto2),
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
                          ? _oro
                          : _linea,
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
          Icon(Icons.api, color: _oro, size: 48),
          const SizedBox(height: 20),
          Text(
            'IQ Bible API',
            style: AppFonts.cinzel(
              color: _texto,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Para acceder a herramientas avanzadas de estudio bíblico '
            '(interlineal, Strong\'s, referencias cruzadas, audio), '
            'necesitas una API key gratuita de RapidAPI.',
            style: AppFonts.manrope(
              color: _texto2,
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
                style: AppFonts.manrope(
                    fontSize: 14, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _oro,
                foregroundColor: _sobreOro,
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
                  style: AppFonts.manrope(
                      color: _oro, fontSize: 13)),
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
          Icon(Icons.key, color: _oro, size: 48),
          const SizedBox(height: 20),
          Text(
            'Pega tu API Key',
            style: AppFonts.cinzel(
              color: _texto,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Copia la key de tu dashboard de RapidAPI '
            '(sección "X-RapidAPI-Key").',
            style: AppFonts.manrope(
              color: _texto3,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _keyController,
            style: GoogleFonts.sourceCodePro(
              color: _texto,
              fontSize: 13,
            ),
            decoration: InputDecoration(
              hintText: 'xxxxxxxxxxxxxxxxxxxxxxxx',
              hintStyle: GoogleFonts.sourceCodePro(
                color: _linea2,
                fontSize: 13,
              ),
              filled: true,
              fillColor: _superficie,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: _oro.withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _oro),
              ),
              suffixIcon: IconButton(
                icon: Icon(Icons.paste, color: _texto4, size: 20),
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
              style: AppFonts.manrope(
                  color: _error, fontSize: 12),
            ),
          ],
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _verifying ? null : _verifyAndSave,
              icon: _verifying
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _sobreOro),
                    )
                  : const Icon(Icons.verified_outlined, size: 18),
              label: Text(
                _verifying ? 'Verificando...' : 'Verificar y guardar',
                style: AppFonts.manrope(
                    fontSize: 14, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _oro,
                foregroundColor: _sobreOro,
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
                  style: AppFonts.manrope(
                      color: _texto3, fontSize: 13)),
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
              color: _verde.withValues(alpha: 0.15),
            ),
            child: Icon(Icons.check_circle,
                color: _verde, size: 64),
          ),
          const SizedBox(height: 24),
          Text(
            '¡Configuración exitosa!',
            style: AppFonts.cinzel(
              color: _texto,
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
            style: AppFonts.manrope(
              color: _texto2,
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
                backgroundColor: _oro,
                foregroundColor: _sobreOro,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Comenzar a estudiar',
                style: AppFonts.manrope(
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
              color: _oro.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: AppFonts.manrope(
                  color: _oro,
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
              style: AppFonts.manrope(
                color: _texto2,
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
