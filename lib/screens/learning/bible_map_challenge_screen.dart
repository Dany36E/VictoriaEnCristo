/// ═══════════════════════════════════════════════════════════════════════════
/// BibleMapChallengeScreen — pantalla de reto drag-and-drop de mapa
///
/// Muestra un mapa estilizado con landmarks y zonas target.
/// El usuario arrastra las etiquetas de nombre desde un banco inferior
/// hasta la posición correcta en el mapa.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/learning/bible_map_models.dart';
import '../../services/feedback_engine.dart';
import '../../services/learning/bible_map_progress_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';

class BibleMapChallengeScreen extends StatefulWidget {
  final BibleMap bibleMap;

  const BibleMapChallengeScreen({super.key, required this.bibleMap});

  @override
  State<BibleMapChallengeScreen> createState() =>
      _BibleMapChallengeScreenState();
}

class _BibleMapChallengeScreenState extends State<BibleMapChallengeScreen>
    with TickerProviderStateMixin {
  /// Lugares que ya fueron colocados correctamente: placeId → true
  final Map<String, bool> _placed = {};

  /// Errores acumulados
  int _errors = 0;

  /// Si ya se completó el mapa
  bool _completed = false;

  /// Estrellas obtenidas
  int _stars = 0;

  /// XP ganado
  int _xpEarned = 0;

  /// Controlador para animaciones
  late AnimationController _pulseController;

  /// Lugar actualmente seleccionado (para tap-to-place en lugar de drag)
  String? _selectedPlaceId;

  /// Orden aleatorio de las etiquetas
  late List<MapPlace> _shuffledPlaces;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _shuffledPlaces = List.of(widget.bibleMap.places)..shuffle(Random());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _onPlaceDropped(String placeId) {
    if (_placed.containsKey(placeId)) return;
    setState(() {
      _placed[placeId] = true;
      _selectedPlaceId = null;
    });
    FeedbackEngine.I.confirm();
    _checkCompletion();
  }

  void _onWrongDrop() {
    setState(() {
      _errors++;
    });
    FeedbackEngine.I.tap();
  }

  void _checkCompletion() {
    if (_placed.length >= widget.bibleMap.places.length) {
      _stars = _errors == 0
          ? 3
          : _errors <= 2
              ? 2
              : 1;
      _completeMap();
    }
  }

  Future<void> _completeMap() async {
    final xp = await BibleMapProgressService.I
        .markCompleted(widget.bibleMap.id, _stars, widget.bibleMap.xpReward);
    setState(() {
      _completed = true;
      _xpEarned = xp;
    });
    FeedbackEngine.I.confirm();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: t.surface,
        elevation: 0,
        title: Text(
          widget.bibleMap.title,
          style: AppDesignSystem.headlineMedium(context, color: t.textPrimary),
        ),
        iconTheme: IconThemeData(color: t.textPrimary),
        actions: [
          if (!_completed)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.close_rounded,
                      size: 16, color: Colors.redAccent.shade100),
                  const SizedBox(width: 4),
                  Text(
                    '$_errors',
                    style: AppDesignSystem.labelLarge(context,
                        color: Colors.redAccent.shade100),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '${_placed.length}/${widget.bibleMap.places.length}',
                    style: AppDesignSystem.labelLarge(context,
                        color: AppDesignSystem.gold),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: _completed ? _buildCompletionView(t) : _buildGameView(t),
    );
  }

  Widget _buildGameView(AppThemeData t) {
    return Column(
      children: [
        // Mapa interactivo
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.all(AppDesignSystem.spacingM),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return _MapArea(
                  bibleMap: widget.bibleMap,
                  placed: _placed,
                  selectedPlaceId: _selectedPlaceId,
                  mapWidth: constraints.maxWidth,
                  mapHeight: constraints.maxHeight,
                  pulseController: _pulseController,
                  onCorrectDrop: _onPlaceDropped,
                  onWrongDrop: _onWrongDrop,
                  onTargetTap: (placeId) {
                    if (_selectedPlaceId != null) {
                      if (_selectedPlaceId == placeId) {
                        _onPlaceDropped(placeId);
                      } else {
                        _onWrongDrop();
                        setState(() => _selectedPlaceId = null);
                      }
                    }
                  },
                );
              },
            ),
          ),
        ),

        // Divider
        Container(
          height: 1,
          color: t.cardBorder,
        ),

        // Banco de etiquetas arrastrables
        Expanded(
          flex: 1,
          child: Container(
            color: t.surface.withOpacity(0.5),
            child: _buildLabelBank(t),
          ),
        ),
      ],
    );
  }

  Widget _buildLabelBank(AppThemeData t) {
    final remainingPlaces =
        _shuffledPlaces.where((p) => !_placed.containsKey(p.id)).toList();

    if (remainingPlaces.isEmpty) {
      return Center(
        child: Text(
          '¡Todos colocados!',
          style: AppDesignSystem.headlineSmall(
            context,
            color: AppDesignSystem.gold,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesignSystem.spacingM,
        vertical: AppDesignSystem.spacingS,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Arrastra o toca un nombre y luego el mapa:',
              style: AppDesignSystem.labelSmall(
                context,
                color: t.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: remainingPlaces.map((place) {
                final isSelected = _selectedPlaceId == place.id;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedPlaceId =
                          isSelected ? null : place.id;
                    });
                    FeedbackEngine.I.tap();
                  },
                  child: Draggable<String>(
                    data: place.id,
                    feedback: Material(
                      color: Colors.transparent,
                      child: _PlaceLabel(
                        name: place.name,
                        isDragging: true,
                        isSelected: false,
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.3,
                      child: _PlaceLabel(
                        name: place.name,
                        isDragging: false,
                        isSelected: false,
                      ),
                    ),
                    child: _PlaceLabel(
                      name: place.name,
                      isDragging: false,
                      isSelected: isSelected,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionView(AppThemeData t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.spacingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Estrellas
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final filled = i < _stars;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 52,
                    color: filled
                        ? AppDesignSystem.gold
                        : t.textSecondary.withOpacity(0.3),
                  ),
                );
              }),
            )
                .animate()
                .fadeIn(duration: 500.ms)
                .scale(begin: const Offset(0.5, 0.5)),
            const SizedBox(height: AppDesignSystem.spacingL),

            Text(
              '¡Mapa completado!',
              style: AppDesignSystem.headlineLarge(
                context,
                color: t.textPrimary,
              ),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: AppDesignSystem.spacingS),

            Text(
              _errors == 0
                  ? '¡Perfecto! Sin errores.'
                  : '$_errors error${_errors == 1 ? '' : 'es'}',
              style: AppDesignSystem.bodyLarge(
                context,
                color: t.textSecondary,
              ),
            ).animate().fadeIn(delay: 400.ms),
            const SizedBox(height: AppDesignSystem.spacingL),

            if (_xpEarned > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: AppDesignSystem.gold.withOpacity(0.15),
                  borderRadius:
                      BorderRadius.circular(AppDesignSystem.radiusFull),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt_rounded,
                        color: AppDesignSystem.gold, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      '+$_xpEarned XP',
                      style: AppDesignSystem.headlineSmall(
                        context,
                        color: AppDesignSystem.gold,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 600.ms).scale(
                    begin: const Offset(0.8, 0.8),
                    duration: 400.ms,
                    curve: Curves.elasticOut,
                  ),

            const SizedBox(height: AppDesignSystem.spacingXL),

            SizedBox(
              width: double.infinity,
              child: PremiumButton(
                child: const Text('Volver al mapa'),
                onPressed: () => Navigator.pop(context, true),
              ),
            ).animate().fadeIn(delay: 800.ms),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// MAPA INTERACTIVO
// ══════════════════════════════════════════════════════════════════════════

class _MapArea extends StatelessWidget {
  final BibleMap bibleMap;
  final Map<String, bool> placed;
  final String? selectedPlaceId;
  final double mapWidth;
  final double mapHeight;
  final AnimationController pulseController;
  final void Function(String placeId) onCorrectDrop;
  final VoidCallback onWrongDrop;
  final void Function(String placeId) onTargetTap;

  const _MapArea({
    required this.bibleMap,
    required this.placed,
    required this.selectedPlaceId,
    required this.mapWidth,
    required this.mapHeight,
    required this.pulseController,
    required this.onCorrectDrop,
    required this.onWrongDrop,
    required this.onTargetTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
        color: const Color(0xFF0A1628),
        border: Border.all(color: t.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Fondo con CustomPaint para landmarks
          Positioned.fill(
            child: CustomPaint(
              painter: _MapPainter(
                landmarks: bibleMap.landmarks,
                width: mapWidth,
                height: mapHeight,
              ),
            ),
          ),

          // Zonas target (no colocados)
          ...bibleMap.places.where((p) => !placed.containsKey(p.id)).map(
                (place) => _buildTarget(context, t, place),
              ),

          // Etiquetas ya colocadas
          ...bibleMap.places.where((p) => placed.containsKey(p.id)).map(
                (place) => _buildPlaced(context, t, place),
              ),
        ],
      ),
    );
  }

  Widget _buildTarget(BuildContext context, AppThemeData t, MapPlace place) {
    final left = place.x * mapWidth - 40;
    final top = place.y * mapHeight - 16;

    return Positioned(
      left: left.clamp(0.0, mapWidth - 80),
      top: top.clamp(0.0, mapHeight - 32),
      child: DragTarget<String>(
        onWillAcceptWithDetails: (_) => true,
        onAcceptWithDetails: (details) {
          if (details.data == place.id) {
            onCorrectDrop(place.id);
          } else {
            onWrongDrop();
          }
        },
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;
          return GestureDetector(
            onTap: () => onTargetTap(place.id),
            child: AnimatedBuilder(
              animation: pulseController,
              builder: (context, child) {
                final scale =
                    1.0 + (pulseController.value * 0.08);
                return Transform.scale(
                  scale: selectedPlaceId != null ? scale : 1.0,
                  child: child,
                );
              },
              child: Container(
                width: 80,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(AppDesignSystem.radiusS),
                  border: Border.all(
                    color: isHovering
                        ? AppDesignSystem.gold
                        : selectedPlaceId != null
                            ? AppDesignSystem.gold.withOpacity(0.6)
                            : Colors.white.withOpacity(0.35),
                    width: isHovering ? 2.0 : 1.5,
                    strokeAlign: BorderSide.strokeAlignCenter,
                  ),
                  color: isHovering
                      ? AppDesignSystem.gold.withOpacity(0.15)
                      : Colors.white.withOpacity(0.06),
                ),
                child: Center(
                  child: Text(
                    '?',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlaced(BuildContext context, AppThemeData t, MapPlace place) {
    final left = place.x * mapWidth - 40;
    final top = place.y * mapHeight - 16;

    return Positioned(
      left: left.clamp(0.0, mapWidth - 80),
      top: top.clamp(0.0, mapHeight - 32),
      child: Container(
        width: 80,
        height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusS),
          color: AppDesignSystem.gold.withOpacity(0.2),
          border: Border.all(
            color: AppDesignSystem.gold,
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            place.name,
            style: const TextStyle(
              color: AppDesignSystem.gold,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      )
          .animate()
          .fadeIn(duration: 300.ms)
          .scale(begin: const Offset(0.8, 0.8)),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// MAP PAINTER — dibuja los landmarks decorativos
// ══════════════════════════════════════════════════════════════════════════

class _MapPainter extends CustomPainter {
  final List<MapLandmark> landmarks;
  final double width;
  final double height;

  _MapPainter({
    required this.landmarks,
    required this.width,
    required this.height,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final lm in landmarks) {
      final cx = lm.x * size.width;
      final cy = lm.y * size.height;

      switch (lm.type) {
        case 'sea':
          _paintSea(canvas, lm, size);
          break;
        case 'river':
          _paintRiver(canvas, lm, size);
          break;
        case 'mountain':
          _paintMountain(canvas, cx, cy);
          break;
        case 'desert':
          _paintDesert(canvas, cx, cy, lm.label, size);
          break;
        case 'label':
          _paintLabel(canvas, cx, cy, lm.label, size);
          break;
      }
    }
  }

  void _paintSea(Canvas canvas, MapLandmark lm, Size size) {
    final seaPaint = Paint()
      ..color = const Color(0xFF0E2A4A)
      ..style = PaintingStyle.fill;
    final w = (lm.width ?? 0.15) * size.width;
    final h = (lm.height ?? 0.15) * size.height;
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(lm.x * size.width, lm.y * size.height),
        width: w,
        height: h,
      ),
      const Radius.circular(20),
    );
    canvas.drawRRect(rect, seaPaint);

    // Label
    _drawText(canvas, lm.label, lm.x * size.width, lm.y * size.height,
        const Color(0xFF3A6B99), 9);
  }

  void _paintRiver(Canvas canvas, MapLandmark lm, Size size) {
    final riverPaint = Paint()
      ..color = const Color(0xFF1A4A7A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final startX = lm.x * size.width;
    final startY = lm.y * size.height;
    final endY = startY + (lm.height ?? 0.3) * size.height;

    final path = Path()..moveTo(startX, startY);
    // Draw wavy river
    const segments = 6;
    final segH = (endY - startY) / segments;
    for (int i = 0; i < segments; i++) {
      final wobble = (i.isEven ? 8.0 : -8.0);
      path.quadraticBezierTo(
        startX + wobble,
        startY + segH * i + segH / 2,
        startX + (i.isEven ? 3 : -3),
        startY + segH * (i + 1),
      );
    }
    canvas.drawPath(path, riverPaint);
    _drawText(canvas, lm.label, startX + 12, startY + 10,
        const Color(0xFF3A6B99), 8);
  }

  void _paintMountain(Canvas canvas, double cx, double cy) {
    final paint = Paint()
      ..color = const Color(0xFF2A3A4A)
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(cx - 14, cy + 10)
      ..lineTo(cx, cy - 10)
      ..lineTo(cx + 14, cy + 10)
      ..close();
    canvas.drawPath(path, paint);
    // Snow cap
    final snowPaint = Paint()
      ..color = const Color(0xFF5A6A7A)
      ..style = PaintingStyle.fill;
    final snowPath = Path()
      ..moveTo(cx - 4, cy - 2)
      ..lineTo(cx, cy - 10)
      ..lineTo(cx + 4, cy - 2)
      ..close();
    canvas.drawPath(snowPath, snowPaint);
  }

  void _paintDesert(
      Canvas canvas, double cx, double cy, String label, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1A1A10).withOpacity(0.4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), 20, paint);
    // Dots for sand
    final dotPaint = Paint()
      ..color = const Color(0xFF3A3020)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < 5; i++) {
      canvas.drawCircle(
        Offset(cx - 8 + i * 4.0, cy + (i.isEven ? -3 : 3)),
        1.5,
        dotPaint,
      );
    }
    _drawText(canvas, label, cx, cy + 20, const Color(0xFF6A5A40), 8);
  }

  void _paintLabel(
      Canvas canvas, double cx, double cy, String label, Size size) {
    _drawText(canvas, label, cx, cy, const Color(0xFF5A6A8A), 10);
  }

  void _drawText(Canvas canvas, String text, double x, double y, Color color,
      double fontSize) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          fontStyle: FontStyle.italic,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(x - textPainter.width / 2, y - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) => false;
}

// ══════════════════════════════════════════════════════════════════════════
// PLACE LABEL WIDGET
// ══════════════════════════════════════════════════════════════════════════

class _PlaceLabel extends StatelessWidget {
  final String name;
  final bool isDragging;
  final bool isSelected;

  const _PlaceLabel({
    required this.name,
    required this.isDragging,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? AppDesignSystem.gold.withOpacity(0.25)
            : isDragging
                ? AppDesignSystem.gold.withOpacity(0.3)
                : const Color(0xFF1A2A3A),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusS),
        border: Border.all(
          color: isSelected
              ? AppDesignSystem.gold
              : isDragging
                  ? AppDesignSystem.gold
                  : const Color(0xFF2A3A5A),
          width: isSelected || isDragging ? 2 : 1,
        ),
        boxShadow: isDragging
            ? [
                BoxShadow(
                  color: AppDesignSystem.gold.withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                )
              ]
            : null,
      ),
      child: Text(
        name,
        style: TextStyle(
          color: isSelected || isDragging
              ? AppDesignSystem.gold
              : Colors.white.withOpacity(0.9),
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}
