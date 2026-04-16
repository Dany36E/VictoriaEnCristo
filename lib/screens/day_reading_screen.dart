import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../data/dummy_plans.dart';
import '../services/audio_service.dart';

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

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB), // Crema muy claro
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ═══════════════════════════════════════════════════════════════════
          // APP BAR MINIMALISTA
          // ═══════════════════════════════════════════════════════════════════
          SliverAppBar(
            pinned: true,
            backgroundColor: const Color(0xFFFBFBFB),
            elevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle.dark,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppDesignSystem.midnight),
              onPressed: () {
                _audioService.stop();
                Navigator.pop(context);
              },
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.plan.title,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppDesignSystem.coolGray,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Día ${day.dayNumber} de ${widget.plan.days}',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppDesignSystem.midnight,
                  ),
                ),
              ],
            ),
            actions: [
              // Botón de audio con estados: play, pause, resume
              IconButton(
                icon: Icon(
                  _isPlaying 
                      ? Icons.pause_circle_filled 
                      : (_isPaused ? Icons.play_circle_filled : Icons.play_circle_outline),
                  color: (_isPlaying || _isPaused) ? AppDesignSystem.gold : AppDesignSystem.midnight,
                  size: 28,
                ),
                onPressed: _toggleAudio,
              ),
              const SizedBox(width: 8),
            ],
          ),

          // ═══════════════════════════════════════════════════════════════════
          // CONTENIDO DE LECTURA
          // ═══════════════════════════════════════════════════════════════════
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  
                  // ═══════════════════════════════════════════════════════════
                  // TÍTULO DEL DÍA
                  // ═══════════════════════════════════════════════════════════
                  Text(
                    day.title,
                    style: GoogleFonts.cinzel(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: AppDesignSystem.midnight,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ═══════════════════════════════════════════════════════════
                  // VERSÍCULO DESTACADO
                  // ═══════════════════════════════════════════════════════════
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppDesignSystem.midnight,
                          AppDesignSystem.midnightLight,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppDesignSystem.midnight.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Icono decorativo
                        Icon(
                          Icons.format_quote,
                          color: AppDesignSystem.gold.withOpacity(0.5),
                          size: 32,
                        ),
                        const SizedBox(height: 16),
                        // Versículo
                        Text(
                          day.scripture,
                          style: GoogleFonts.crimsonPro(
                            fontSize: 20,
                            fontWeight: FontWeight.w400,
                            fontStyle: FontStyle.italic,
                            color: AppDesignSystem.pureWhite,
                            height: 1.6,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        // Referencia
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppDesignSystem.gold.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            day.scriptureReference,
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppDesignSystem.gold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Línea divisoria dorada
                  Center(
                    child: Container(
                      width: 80,
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppDesignSystem.gold.withOpacity(0.2),
                            AppDesignSystem.gold,
                            AppDesignSystem.gold.withOpacity(0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ═══════════════════════════════════════════════════════════
                  // CONTENIDO DEL DEVOCIONAL
                  // ═══════════════════════════════════════════════════════════
                  ..._buildContentSections(day.content),
                  
                  const SizedBox(height: 40),

                  // ═══════════════════════════════════════════════════════════
                  // BOTÓN COMPLETAR
                  // ═══════════════════════════════════════════════════════════
                  if (!isCompleted)
                    _buildCompleteButton()
                  else
                    _buildCompletedBadge(),

                  SizedBox(height: 40 + MediaQuery.of(context).padding.bottom),
                ],
              ),
            ),
          ),
        ],
      ),
      // FAB alternativo (visible al scrollear)
      floatingActionButton: (_showFab && !isCompleted)
          ? FloatingActionButton.extended(
              onPressed: _completeDay,
              backgroundColor: AppDesignSystem.gold,
              icon: const Icon(Icons.check, color: AppDesignSystem.midnight),
              label: Text(
                'COMPLETAR',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700,
                  color: AppDesignSystem.midnight,
                ),
              ),
            )
          : null,
    );
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
        style: GoogleFonts.manrope(
          fontSize: 17,
          fontWeight: FontWeight.w400,
          color: AppDesignSystem.midnight.withOpacity(0.85),
          height: 1.7,
          letterSpacing: 0.2,
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
          Icon(
            icon,
            color: AppDesignSystem.gold,
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: GoogleFonts.cinzel(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppDesignSystem.midnight,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Sección de REFLEXIÓN con estilo destacado
  Widget _buildReflexionSection(String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FC), // Gris muy claro azulado
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppDesignSystem.midnight.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado con icono
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppDesignSystem.gold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.lightbulb_outline,
                  color: AppDesignSystem.gold,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'REFLEXIÓN',
                style: GoogleFonts.cinzel(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppDesignSystem.midnight,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Línea decorativa dorada
          Container(
            height: 2,
            width: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppDesignSystem.gold,
                  AppDesignSystem.gold.withOpacity(0.3),
                ],
              ),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(height: 16),
          // Contenido
          Text(
            content,
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: AppDesignSystem.midnight.withOpacity(0.8),
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }

  /// Sección de ORACIÓN con estilo especial (card diferenciada)
  Widget _buildOracionSection(String content) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF5), // Crema cálido muy suave
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppDesignSystem.gold.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: AppDesignSystem.gold.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Borde izquierdo grueso dorado
            Container(
              width: 5,
              decoration: const BoxDecoration(
                color: AppDesignSystem.gold,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            // Contenido
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Encabezado con icono
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppDesignSystem.gold.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            '🙏',
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'ORACIÓN',
                          style: GoogleFonts.cinzel(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppDesignSystem.midnight,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Línea decorativa
                    Container(
                      height: 2,
                      width: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppDesignSystem.gold,
                            AppDesignSystem.gold.withOpacity(0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Texto de la oración en itálica
                    Text(
                      content,
                      style: GoogleFonts.crimsonPro(
                        fontSize: 17,
                        fontWeight: FontWeight.w400,
                        fontStyle: FontStyle.italic,
                        color: AppDesignSystem.midnight.withOpacity(0.85),
                        height: 1.7,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompleteButton() {
    return Container(
      width: double.infinity,
      height: 64,
      decoration: BoxDecoration(
        gradient: AppDesignSystem.goldShimmer,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppDesignSystem.gold.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _completeDay,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: AppDesignSystem.midnight,
                  size: 26,
                ),
                const SizedBox(width: 12),
                Text(
                  'COMPLETAR DEVOCIONAL',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppDesignSystem.midnight,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompletedBadge() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppDesignSystem.victory.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppDesignSystem.victory.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle,
            color: AppDesignSystem.victory,
            size: 28,
          ),
          const SizedBox(width: 12),
          Text(
            'DEVOCIONAL COMPLETADO',
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppDesignSystem.victory,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
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
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppDesignSystem.midnight,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppDesignSystem.gold.withOpacity(0.2),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icono de celebración
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                gradient: AppDesignSystem.goldShimmer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isLastDay ? Icons.emoji_events : Icons.check,
                color: AppDesignSystem.midnight,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            
            // Título
            Text(
              isLastDay ? '¡PLAN COMPLETADO!' : '¡DÍA $dayNumber COMPLETADO!',
              style: GoogleFonts.cinzel(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppDesignSystem.gold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            
            // Mensaje
            Text(
              isLastDay 
                  ? '¡Felicidades! Has terminado "$planTitle". Tu dedicación espiritual es inspiradora.'
                  : 'Excelente progreso. El día ${dayNumber + 1} ya está desbloqueado.',
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: AppDesignSystem.coolGray,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // Botón confirmar
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: onConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppDesignSystem.gold,
                  foregroundColor: AppDesignSystem.midnight,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  isLastDay ? '¡CELEBRAR!' : 'CONTINUAR',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
