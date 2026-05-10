import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tutorial de bienvenida que se muestra la primera vez que el usuario
/// abre la sección "La Biblia". Carrusel breve y amigable que cubre las
/// funciones principales (versiones, tipografía, subrayado, paralelo,
/// Modo Estudio, búsqueda).
///
/// Persistencia: SharedPreferences clave [_seenKey].
class BibleHomeOnboardingOverlay extends StatefulWidget {
  const BibleHomeOnboardingOverlay({super.key});

  static const _seenKey = 'bible_home_onboarding_seen_v1';

  /// Marca el tutorial como visto.
  static Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenKey, true);
  }

  /// Indica si el usuario ya vio el tutorial.
  static Future<bool> hasSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_seenKey) ?? false;
  }

  @override
  State<BibleHomeOnboardingOverlay> createState() =>
      _BibleHomeOnboardingOverlayState();
}

class _BibleHomeOnboardingOverlayState
    extends State<BibleHomeOnboardingOverlay> {
  final _controller = PageController();
  int _index = 0;

  static const _slides = <_Slide>[
    _Slide(
      icon: Icons.menu_book_outlined,
      title: 'Bienvenido a La Biblia',
      body:
          'Tu Biblia siempre contigo. Lee, subraya, escribe notas y profundiza '
          'a tu ritmo.',
    ),
    _Slide(
      icon: Icons.translate_outlined,
      title: 'Elige tu versión',
      body:
          'Toca el nombre de la versión arriba para cambiar entre RVR1960, '
          'NVI, LBLA, NTV o TLA al instante.',
    ),
    _Slide(
      icon: Icons.text_fields,
      title: 'Lectura cómoda',
      body:
          'Ajusta el tamaño de letra y elige un tema (papel, sepia, oscuro) '
          'desde la barra superior.',
    ),
    _Slide(
      icon: Icons.format_color_fill_outlined,
      title: 'Subraya y toma notas',
      body:
          'Mantén pulsado un versículo para resaltarlo con color o agregarle '
          'una nota personal. Tus marcas se guardan en la nube.',
    ),
    _Slide(
      icon: Icons.view_column_outlined,
      title: 'Lee dos versiones',
      body:
          'Usa "2 versiones" para comparar el mismo capítulo lado a lado en '
          'distintas traducciones.',
    ),
    _Slide(
      icon: Icons.auto_stories_outlined,
      title: 'Modo Estudio',
      body:
          'Activa el Modo Estudio para responder las 6 preguntas guiadas, '
          'subrayar palabra por palabra y compartir con amigos en tiempo real.',
    ),
    _Slide(
      icon: Icons.search,
      title: 'Buscar y descubrir',
      body:
          'Encuentra cualquier palabra o versículo, descubre tipologías, mapas, '
          'palabras de Cristo y mucho más en el menú principal.',
    ),
  ];

  void _close() {
    BibleHomeOnboardingOverlay.markSeen();
    if (Navigator.canPop(context)) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF161616),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 540),
        child: Column(
          children: [
            const SizedBox(height: 18),
            Text(
              'La Biblia',
              style: GoogleFonts.cinzel(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Conoce cómo aprovecharla en 60 segundos',
              style: GoogleFonts.manrope(
                color: Colors.white60,
                fontSize: 11,
                letterSpacing: 0.4,
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                itemCount: _slides.length,
                itemBuilder: (_, i) => _buildSlide(_slides[i]),
              ),
            ),
            _buildDots(),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _close,
                    child: Text(
                      'Saltar',
                      style: GoogleFonts.manrope(color: Colors.white54),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4A853),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      if (_index < _slides.length - 1) {
                        _controller.nextPage(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOut,
                        );
                      } else {
                        _close();
                      }
                    },
                    child: Text(
                      _index < _slides.length - 1 ? 'Siguiente' : '¡Comenzar!',
                      style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide(_Slide s) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: const Color(0xFFD4A853).withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFD4A853).withOpacity(0.35),
                width: 1,
              ),
            ),
            child: Icon(s.icon, color: const Color(0xFFD4A853), size: 40),
          ),
          const SizedBox(height: 22),
          Text(
            s.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.cinzel(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            s.body,
            textAlign: TextAlign.center,
            style: GoogleFonts.lora(
              color: Colors.white70,
              fontSize: 14,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_slides.length, (i) {
        final active = i == _index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? const Color(0xFFD4A853) : Colors.white24,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

class _Slide {
  final IconData icon;
  final String title;
  final String body;
  const _Slide({required this.icon, required this.title, required this.body});
}
