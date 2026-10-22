import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/dummy_plans.dart';
import '../services/audio_service.dart';
import '../vec/vec_tema.dart';
import '../vec/vec_widgets.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// DAY READING SCREEN
/// Pantalla de lectura minimalista para los devocionales
/// ═══════════════════════════════════════════════════════════════════════════

class DayReadingScreen extends StatefulWidget {
  final SpiritualPlan plan;
  final int dayIndex;
  final VoidCallback onCompleted;

  const DayReadingScreen({
    super.key,
    required this.plan,
    required this.dayIndex,
    required this.onCompleted,
  });

  @override
  State<DayReadingScreen> createState() => _DayReadingScreenState();
}

class _DayReadingScreenState extends State<DayReadingScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showFab = false;
  bool _isPlaying = false;
  bool _isPaused = false;
  final AudioService _audioService = AudioService();
  StreamSubscription<TtsState>? _ttsSubscription;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    
    // Escuchar cambios de estado del TTS
    _ttsSubscription = _audioService.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == TtsState.playing;
          _isPaused = state == TtsState.paused;
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _ttsSubscription?.cancel();
    _audioService.stop();
    super.dispose();
  }

  void _onScroll() {
    // Mostrar FAB cuando el usuario ha scrolleado más del 50%
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    final shouldShow = currentScroll > maxScroll * 0.3;
    
    if (shouldShow != _showFab) {
      setState(() => _showFab = shouldShow);
    }
  }

  void _toggleAudio() async {
    final day = widget.plan.daysList[widget.dayIndex];
    
    if (_audioService.isPlaying) {
      // Pausar en lugar de detener
      await _audioService.pause();
      setState(() => _isPlaying = false);
    } else if (_audioService.isPaused) {
      // Reanudar desde donde se quedó
      await _audioService.resume();
      setState(() => _isPlaying = true);
    } else {
      // Iniciar nueva reproducción
      final textToSpeak = '${day.title}. ${day.scripture}. ${day.content}';
      await _audioService.speak(textToSpeak);
      setState(() => _isPlaying = true);
    }
  }

  void _completeDay() {
    HapticFeedback.heavyImpact();
    
    // Mostrar diálogo de confirmación con animación
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CompletionDialog(
        dayNumber: widget.plan.daysList[widget.dayIndex].dayNumber,
        planTitle: widget.plan.title,
        isLastDay: widget.dayIndex == widget.plan.daysList.length - 1,
        onConfirm: () {
          widget.onCompleted();
          Navigator.pop(context); // Cerrar dialog
          Navigator.pop(context); // Volver a la lista de días
        },
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final day = widget.plan.daysList[widget.dayIndex];
    final isCompleted = day.isCompleted;
    return _buildPapel(day, isCompleted);
  }

  List<Widget> _buildContentSections(String content) {
    final widgets = <Widget>[];
    
    // Detectar y separar secciones principales
    final hasReflexion = content.contains('REFLEXIÓN:') || content.contains('MEDITACIÓN');
    final hasOracion = content.contains('ORACIÓN:');
    
    if (hasReflexion || hasOracion) {
      // Parsear el contenido estructurado
      widgets.addAll(_parseStructuredContent(content));
    } else {
      // Contenido simple sin secciones marcadas
      widgets.addAll(_parseSimpleContent(content));
    }
    
    return widgets;
  }

  /// Parsea contenido estructurado con REFLEXIÓN y ORACIÓN
  List<Widget> _parseStructuredContent(String content) {
    final widgets = <Widget>[];
    
    // Dividir en párrafos
    final paragraphs = content.split('\n\n');
    
    bool inReflexion = false;
    bool inOracion = false;
    final reflexionContent = <String>[];
    final oracionContent = <String>[];
    final mainContent = <String>[];
    
    for (final paragraph in paragraphs) {
      final trimmed = paragraph.trim();
      if (trimmed.isEmpty) continue;
      
      // Detectar inicio de secciones
      if (trimmed.startsWith('REFLEXIÓN:') || trimmed.startsWith('MEDITACIÓN')) {
        inReflexion = true;
        inOracion = false;
        // Agregar el contenido después del título
        final afterTitle = trimmed.replaceFirst(RegExp(r'^(REFLEXIÓN:|MEDITACIÓN[^:]*:?)'), '').trim();
        if (afterTitle.isNotEmpty) reflexionContent.add(afterTitle);
        continue;
      }
      
      if (trimmed.startsWith('ORACIÓN:')) {
        inOracion = true;
        inReflexion = false;
        final afterTitle = trimmed.replaceFirst('ORACIÓN:', '').trim();
        if (afterTitle.isNotEmpty) oracionContent.add(afterTitle);
        continue;
      }
      
      // Agregar contenido a la sección correspondiente
      if (inOracion) {
        oracionContent.add(trimmed);
      } else if (inReflexion) {
        reflexionContent.add(trimmed);
      } else {
        mainContent.add(trimmed);
      }
    }
    
    // Construir widgets
    
    // 1. Contenido principal (introducción)
    for (final text in mainContent) {
      widgets.add(_buildParagraph(text));
    }
    
    // 2. Sección REFLEXIÓN (si existe)
    if (reflexionContent.isNotEmpty) {
      widgets.add(const SizedBox(height: 24));
      widgets.add(_buildReflexionSection(reflexionContent.join('\n\n')));
    }
    
    // 3. Sección ORACIÓN (si existe)
    if (oracionContent.isNotEmpty) {
      widgets.add(const SizedBox(height: 24));
      widgets.add(_buildOracionSection(oracionContent.join('\n\n')));
    }
    
    return widgets;
  }

  /// Parsea contenido simple sin secciones marcadas
  List<Widget> _parseSimpleContent(String content) {
    final paragraphs = content.split('\n\n');
    
    return paragraphs.map((paragraph) {
      final trimmed = paragraph.trim();
      if (trimmed.isEmpty) return const SizedBox.shrink();
      
      // Detectar encabezados genéricos
      final isHeader = trimmed.endsWith(':') && 
                       trimmed.split(':')[0] == trimmed.split(':')[0].toUpperCase() &&
                       trimmed.length < 40;
      
      if (isHeader) {
        return _buildSectionHeader(
          trimmed.replaceAll(':', ''),
          Icons.auto_awesome,
        );
      }
      
      return _buildParagraph(trimmed);
    }).toList();
  }

  /// Construye un párrafo normal
  Widget _buildParagraph(String text) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: VecFuentes.texto,
            fontSize: 20,
            height: 1.4,
            color: VecColores.tinta,
          ),
        ),
      );
  }

  /// Construye un encabezado de sección con icono
  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 12),
        child: Row(
          children: [
            CirculoIcono(
              iconoVec: 'idea',
              color: VecColores.mostaza,
              tamano: 36,
              giro: -4,
            ),
            const SizedBox(width: 10),
            Expanded(child: TituloVec(title, tamano: 22)),
          ],
        ),
      );
  }

  /// Sección de REFLEXIÓN con estilo destacado
  Widget _buildReflexionSection(String content) {
    return TarjetaPapel(
        giro: 1,
        cintaDerecha: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CirculoIcono(
                  iconoVec: 'idea',
                  color: VecColores.mostaza,
                  tamano: 40,
                  giro: -4,
                ),
                const SizedBox(width: 12),
                const TituloVec('Reflexión', tamano: 24),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              content,
              style: TextStyle(
                fontFamily: VecFuentes.texto,
                fontSize: 19,
                height: 1.4,
                color: VecColores.tinta,
              ),
            ),
          ],
        ),
      );
  }

  /// Sección de ORACIÓN con estilo especial (card diferenciada)
  Widget _buildOracionSection(String content) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CirculoIcono(
                iconoVec: 'orar',
                color: VecColores.noche,
                tamano: 40,
                giro: -4,
              ),
              const SizedBox(width: 12),
              const TituloVec('Oración', tamano: 24),
            ],
          ),
          const SizedBox(height: 22),
          HojaRayada(child: Text(content)),
        ],
      );
  }


  // ═══════════════════════════════════════════════════════════════════════════
  // TEMA PAPEL
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPapel(DayPlan day, bool isCompleted) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.transparent,
            // Barra fija con la misma hoja de papel (no un fondo plano).
            flexibleSpace: const FondoPapel(child: SizedBox.expand()),
            systemOverlayStyle: SystemUiOverlayStyle.dark,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Volver',
              onPressed: () {
                _audioService.stop();
                Navigator.pop(context);
              },
            ),
            centerTitle: false,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.plan.title,
                  style: TextStyle(
                    fontFamily: VecFuentes.texto,
                    fontSize: 15,
                    color: VecColores.gris,
                  ),
                ),
                Text(
                  'Día ${day.dayNumber} de ${widget.plan.days}',
                  style: TextStyle(
                    fontFamily: VecFuentes.titulo,
                    fontSize: 19,
                    color: VecColores.tinta,
                  ),
                ),
              ],
            ),
            actions: [
              Semantics(
                button: true,
                label: _isPlaying ? 'Pausar lectura' : 'Escuchar lectura',
                child: GestureDetector(
                  onTap: _toggleAudio,
                  child: CirculoIcono(
                    icono: _isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: (_isPlaying || _isPaused)
                        ? VecColores.terracota
                        : VecColores.azul,
                    tamano: 44,
                    giro: -4,
                  ),
                ),
              ),
              const SizedBox(width: 14),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 18),
                  PopIn(child: TituloVec(day.title, tamano: 32)),
                  const SizedBox(height: 30),
                  PopIn(
                    retraso: const Duration(milliseconds: 100),
                    child: TarjetaVersiculo(
                      referencia: day.scriptureReference,
                      texto: day.scripture,
                      version: '',
                    ),
                  ),
                  const SizedBox(height: 30),
                  ..._buildContentSections(day.content),
                  const SizedBox(height: 40),
                  if (!isCompleted)
                    BotonVec(
                      texto: 'Completar devocional',
                      iconoWidget: const IconoVec('palomita'),
                      color: VecColores.verde,
                      expandido: true,
                      onPressed: _completeDay,
                    )
                  else
                    Center(
                      child: Column(
                        children: [
                          const Sticker(
                            'assets/vec/personajes/victoria_corazon.png',
                            alto: 150,
                          ),
                          const SizedBox(height: 10),
                          ChipVec(
                            texto: 'Devocional completado',
                            color: VecColores.verde,
                            iconoWidget: IconoVec(
                              'palomita',
                              color: VecColores.papel,
                            ),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(height: 40 + MediaQuery.of(context).padding.bottom),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: (_showFab && !isCompleted)
          ? FloatingActionButton.extended(
              onPressed: _completeDay,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Completar'),
            )
          : null,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DIÁLOGO DE COMPLETACIÓN
// ═══════════════════════════════════════════════════════════════════════════

class _CompletionDialog extends StatelessWidget {
  final int dayNumber;
  final String planTitle;
  final bool isLastDay;
  final VoidCallback onConfirm;

  const _CompletionDialog({
    required this.dayNumber,
    required this.planTitle,
    required this.isLastDay,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PopIn(
                child: Sticker(
                  isLastDay
                      ? 'assets/vec/personajes/victoria_saludo.png'
                      : 'assets/vec/personajes/victoria_corazon.png',
                  alto: 150,
                ),
              ),
              const SizedBox(height: 12),
              TituloVec(
                isLastDay
                    ? '¡Plan completado!'
                    : '¡Día $dayNumber completado!',
                clave: 'completado',
                tamano: 26,
                alineacion: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                isLastDay
                    ? '¡Felicidades! Has terminado "$planTitle". Tu dedicación espiritual es inspiradora.'
                    : 'Excelente progreso. El día ${dayNumber + 1} ya está desbloqueado.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: VecFuentes.texto,
                  fontSize: 18,
                  height: 1.3,
                  color: VecColores.tinta,
                ),
              ),
              const SizedBox(height: 22),
              BotonVec(
                texto: isLastDay ? '¡Celebrar!' : 'Continuar',
                color: VecColores.verde,
                expandido: true,
                onPressed: onConfirm,
              ),
            ],
          ),
        ),
      );
  }
}
