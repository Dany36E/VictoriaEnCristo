import 'package:flutter/material.dart';
import '../../../theme/app_fonts.dart';
import '../../../vec/vec_tema.dart';
import '../../../vec/vec_widgets.dart';

import '../../../models/bible/study_word_highlight.dart';

/// Overlay de bienvenida (3 pasos) que explica el método del Modo Estudio.
class StudyOnboardingOverlay extends StatefulWidget {
  const StudyOnboardingOverlay({super.key});

  @override
  State<StudyOnboardingOverlay> createState() => _StudyOnboardingOverlayState();
}

class _StudyOnboardingOverlayState extends State<StudyOnboardingOverlay> {
  final _controller = PageController();
  int _index = 0;

  static const _slides = <_Slide>[
    _Slide(
      icon: Icons.touch_app_outlined,
      title: 'Selección palabra por palabra',
      body:
          'En el panel de lectura puedes tocar palabras para seleccionar desde una sola hasta una frase o el versículo completo. Pulsa de nuevo para deseleccionar.',
    ),
    _Slide(
      icon: Icons.palette_outlined,
      title: 'Código de colores',
      body:
          'Rojo: palabras clave o repetidas.\nVerde: sinónimos y antónimos.\nAzul: lugares y geografía.\nAmarillo: marcatextos general.',
    ),
    _Slide(
      icon: Icons.quiz_outlined,
      title: 'Preguntas y esperanza',
      body:
          'En el panel derecho responde las 6 preguntas guiadas, escribe el mensaje de esperanza y marca el Verso Principal. Todo se autoguarda en tus Notas.',
    ),
  ];

  // Tema «papel recortado»: hoja de papel con letras y colores del kit.
  Color get _texto => VecColores.tinta;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 520),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text(
              'Modo Estudio',
              style: AppFonts.cinzel(
                color: _texto,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
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
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Saltar',
                      style: AppFonts.manrope(
                        color: VecColores.gris,
                      ),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () {
                      if (_index < _slides.length - 1) {
                        _controller.nextPage(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOut,
                        );
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    child: Text(
                      _index < _slides.length - 1 ? 'Siguiente' : 'Empezar',
                      style: AppFonts.manrope(fontWeight: FontWeight.w600),
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CirculoIcono(icono: s.icon, tamano: 72, giro: -4),
          const SizedBox(height: 18),
          Text(
            s.title,
            textAlign: TextAlign.center,
            style: AppFonts.cinzel(
              color: _texto,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            s.body,
            textAlign: TextAlign.center,
            style: AppFonts.lora(
              color: VecColores.tinta,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          if (s.title.contains('colores')) _buildColorRow(),
        ],
      ),
    );
  }

  Widget _buildColorRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: StudyHighlightCode.values
          .map(
            (c) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: c.color.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: c.color, width: 1),
              ),
              child: Text(
                c.label,
                style: AppFonts.manrope(
                  color: _texto,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
          .toList(),
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
            color: active
                ? (VecColores.terracota)
                : (VecColores.cremaOscuro),
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
