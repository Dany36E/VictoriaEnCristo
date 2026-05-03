/// ═══════════════════════════════════════════════════════════════════════════
/// BibleOrderQuizScreen — Quiz para aprender el orden de los libros
///
/// Muestra N libros desordenados. El usuario los toca en orden canónico.
/// Feedback visual inmediato: verde si correcto, rojo si error.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/learning/book_models.dart';
import '../../services/audio_engine.dart';
import '../../services/feedback_engine.dart';
import '../../services/learning/bible_order_progress_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';

class BibleOrderQuizScreen extends StatefulWidget {
  final String categoryKey;
  final String title;
  final List<BibleBook> books;

  const BibleOrderQuizScreen({
    super.key,
    required this.categoryKey,
    required this.title,
    required this.books,
  });

  @override
  State<BibleOrderQuizScreen> createState() => _BibleOrderQuizScreenState();
}

class _BibleOrderQuizScreenState extends State<BibleOrderQuizScreen> {
  /// Books in canonical order
  late List<BibleBook> _canonical;

  /// Shuffled indices into _canonical
  late List<int> _shuffled;

  /// User's sequential picks (indices into _canonical)
  final List<int> _picked = [];

  /// Indices where user made an error
  final Set<int> _errors = {};

  bool _done = false;
  int _stars = 0;
  int _awardedXp = 0;

  @override
  void initState() {
    super.initState();
    _canonical = [...widget.books]..sort((a, b) => a.order.compareTo(b.order));
    _shuffled = List.generate(_canonical.length, (i) => i)..shuffle(Random());
    // Avoid trivially already-sorted
    if (_canonical.length > 2 && _listEq(_shuffled, List.generate(_canonical.length, (i) => i))) {
      _shuffled = _shuffled.reversed.toList();
    }
    // Música tranquila para estudio de orden bíblico
    AudioEngine.I.switchBgmContext(BgmContext.learningBibleOrder);
  }

  @override
  void dispose() {
    AudioEngine.I.switchBgmContext(BgmContext.learningBibleOrder);
    super.dispose();
  }

  bool _listEq(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _onTap(int canonicalIdx) {
    if (_done) return;
    if (_picked.contains(canonicalIdx)) return; // already picked

    final expected = _picked.length; // next expected canonical index
    final correct = canonicalIdx == expected;

    setState(() {
      _picked.add(canonicalIdx);
      if (!correct) _errors.add(canonicalIdx);
    });

    if (correct) {
      FeedbackEngine.I.confirm();
    } else {
      FeedbackEngine.I.tap();
    }

    if (_picked.length == _canonical.length) {
      _finish();
    }
  }

  Future<void> _finish() async {
    final total = _canonical.length;
    final errCount = _errors.length;
    int stars;
    if (errCount == 0) {
      stars = 3;
    } else if (errCount <= (total * 0.2).ceil()) {
      stars = 2;
    } else {
      stars = 1;
    }
    final xp = await BibleOrderProgressService.I.recordRound(
      categoryKey: widget.categoryKey,
      stars: stars,
    );
    if (!mounted) return;
    setState(() {
      _done = true;
      _stars = stars;
      _awardedXp = xp;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: t.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: t.textPrimary),
        title: Text(
          widget.title,
          style: AppDesignSystem.headlineMedium(context, color: t.textPrimary),
        ),
      ),
      body: Column(
        children: [
          // Progress bar
          _progressBar(t),
          // Instructions
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDesignSystem.spacingM,
              vertical: AppDesignSystem.spacingS,
            ),
            child: Text(
              _done ? '¡Resultado!' : 'Toca los libros en su orden correcto:',
              style: AppDesignSystem.bodyLarge(context, color: t.textSecondary),
            ),
          ),
          // Book chips grid
          Expanded(child: _buildGrid(t)),
          // Result / action
          if (_done) _resultFooter(t),
        ],
      ),
    );
  }

  Widget _progressBar(AppThemeData t) {
    final pct = _canonical.isEmpty ? 0.0 : _picked.length / _canonical.length;
    return LinearProgressIndicator(
      value: pct,
      minHeight: 4,
      backgroundColor: t.surface,
      valueColor: AlwaysStoppedAnimation(
        _errors.isEmpty ? AppDesignSystem.victory : AppDesignSystem.gold,
      ),
    );
  }

  Widget _buildGrid(AppThemeData t) {
    final isHuge = _canonical.length > 20;
    return GridView.builder(
      padding: const EdgeInsets.all(AppDesignSystem.spacingM),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isHuge ? 4 : 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: isHuge ? 1.7 : 1.6,
      ),
      itemCount: _canonical.length,
      itemBuilder: (context, gridIdx) {
        final canonicalIdx = _shuffled[gridIdx];
        final book = _canonical[canonicalIdx];
        final pickedPos = _picked.indexOf(canonicalIdx);
        final isPicked = pickedPos >= 0;
        final isError = _errors.contains(canonicalIdx);

        Color borderColor = t.divider;
        Color bgColor = t.cardBg;
        Color textColor = t.textPrimary;

        if (_done) {
          if (isError) {
            borderColor = AppDesignSystem.struggle;
            bgColor = AppDesignSystem.struggle.withOpacity(0.10);
          } else if (isPicked) {
            borderColor = AppDesignSystem.victory;
            bgColor = AppDesignSystem.victory.withOpacity(0.10);
          }
        } else if (isPicked) {
          if (isError) {
            borderColor = AppDesignSystem.struggle;
            bgColor = AppDesignSystem.struggle.withOpacity(0.08);
          } else {
            borderColor = AppDesignSystem.gold;
            bgColor = AppDesignSystem.gold.withOpacity(0.08);
          }
        }

        return InkWell(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
          onTap: (isPicked || _done) ? null : () => _onTap(canonicalIdx),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
              border: Border.all(color: borderColor, width: isPicked ? 2 : 1),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Nombre centrado ocupando toda la celda (auto-fit)
                Positioned.fill(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          book.name,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          style: TextStyle(
                            color: isPicked ? textColor.withOpacity(0.85) : textColor,
                            fontWeight: isPicked ? FontWeight.w500 : FontWeight.w600,
                            fontSize: isHuge ? 12 : 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Badge con el orden en que el usuario lo tocó (esquina sup. izq.)
                if (isPicked)
                  Positioned(
                    top: -2,
                    left: -2,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: isError ? AppDesignSystem.struggle : AppDesignSystem.gold,
                        shape: BoxShape.circle,
                        border: Border.all(color: t.cardBg, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${pickedPos + 1}',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                // Posición canónica correcta (sólo en resultado, esquina sup. der.)
                if (_done && isPicked)
                  Positioned(
                    top: 0,
                    right: 2,
                    child: Text(
                      '#${canonicalIdx + 1}',
                      style: TextStyle(
                        fontSize: 9,
                        color: t.textSecondary.withOpacity(0.8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ).animate().fadeIn(duration: 200.ms, delay: (20 * gridIdx).ms);
      },
    );
  }

  Widget _resultFooter(AppThemeData t) {
    final correct = _canonical.length - _errors.length;
    final total = _canonical.length;
    final perfect = _errors.isEmpty;
    return Container(
      padding: const EdgeInsets.all(AppDesignSystem.spacingL),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppDesignSystem.radiusL)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                return Icon(
                  i < _stars ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 32,
                  color: i < _stars ? AppDesignSystem.gold : AppDesignSystem.gold.withOpacity(0.3),
                );
              }),
            ),
            const SizedBox(height: 8),
            Text(
              perfect ? '¡Orden perfecto!' : '$correct/$total en orden correcto',
              style: AppDesignSystem.headlineSmall(context, color: t.textPrimary),
            ),
            if (_awardedXp > 0) ...[
              const SizedBox(height: 4),
              Text(
                '+$_awardedXp XP',
                style: AppDesignSystem.labelLarge(context, color: AppDesignSystem.gold),
              ),
            ],
            const SizedBox(height: AppDesignSystem.spacingM),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: t.cardBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
                      ),
                    ),
                    child: Text('Volver', style: TextStyle(color: t.textSecondary)),
                  ),
                ),
                const SizedBox(width: AppDesignSystem.spacingM),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      FeedbackEngine.I.tap();
                      setState(() {
                        _picked.clear();
                        _errors.clear();
                        _done = false;
                        _stars = 0;
                        _awardedXp = 0;
                        _shuffled.shuffle(Random());
                        if (_canonical.length > 2 &&
                            _listEq(_shuffled, List.generate(_canonical.length, (i) => i))) {
                          _shuffled = _shuffled.reversed.toList();
                        }
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppDesignSystem.gold,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
                      ),
                    ),
                    child: const Text('Reintentar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
