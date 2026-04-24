/// ═══════════════════════════════════════════════════════════════════════════
/// VerseStudyScreen — práctica real de memorización con auto-calificación
///
/// Flujo:
///   1. PREVIEW: muestra el versículo completo + botón "Practicar".
///   2. PRACTICE: palabras desordenadas en un banco abajo. El usuario debe
///      tocarlas EN ORDEN para reconstruir el versículo arriba.
///      - Acierto → palabra salta al destino (flash dorado).
///      - Error  → palabra se tiñe de rojo, +1 a contador de fallos.
///   3. RESULT: la app calcula la calidad SRS automáticamente:
///      - 0 fallos           → quality 2 (Bien)
///      - ≤25% fallos/words  → quality 1 (Difícil)
///      - >25% fallos/words  → quality 0 (Fallé)
///      Se registra en VerseMemoryService y avanza el nivel.
///
/// Soporta cualquier versión Biblia (RVR60/NVI/LBLA/NTV/TLA) vía parser.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/bible/bible_version.dart';
import '../../models/learning/learning_models.dart';
import '../../services/bible/bible_parser_service.dart';
import '../../services/daily_practice_service.dart';
import '../../services/feedback_engine.dart';
import '../../services/learning/verse_memory_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';

enum _Phase { preview, practice }

class _Token {
  final int idx;
  final String display; // con puntuación original
  final String norm; // normalizado para comparar
  const _Token(this.idx, this.display, this.norm);
}

class VerseStudyScreen extends StatefulWidget {
  final MemoryVerse verse;

  const VerseStudyScreen({super.key, required this.verse});

  @override
  State<VerseStudyScreen> createState() => _VerseStudyScreenState();
}

class _VerseStudyScreenState extends State<VerseStudyScreen> {
  String? _text;
  bool _loading = true;
  BibleVersion? _loadedVersion;

  _Phase _phase = _Phase.preview;
  List<_Token> _tokens = [];
  List<_Token> _bank = [];
  final List<_Token> _placed = [];
  int _mistakes = 0;
  int? _wrongFlashIdx;
  int? _correctFlashIdx;

  @override
  void initState() {
    super.initState();
    VerseMemoryService.I.ensureStarted(widget.verse.id);
    _loadText();
  }

  Future<void> _loadText() async {
    final v = VerseMemoryService.I.preferredVersionNotifier.value;
    setState(() {
      _loading = true;
      _loadedVersion = v;
    });
    try {
      await BibleParserService.I.init();
      final buffer = StringBuffer();
      for (int n = widget.verse.verse; n <= widget.verse.verseEnd; n++) {
        final bv = await BibleParserService.I.getVerse(
          version: v,
          bookNumber: widget.verse.bookNumber,
          chapter: widget.verse.chapter,
          verse: n,
        );
        if (bv != null) {
          if (buffer.isNotEmpty) buffer.write(' ');
          buffer.write(bv.text.trim());
        }
      }
      if (!mounted) return;
      setState(() {
        _text = buffer.isEmpty ? null : buffer.toString();
        _loading = false;
        _phase = _Phase.preview;
        _placed.clear();
        _mistakes = 0;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _text = null;
        _loading = false;
      });
    }
  }

  String _normalize(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'''[.,;:!?"'«»¡¿\-—()\[\]]+'''), '')
        .trim();
  }

  void _startPractice() {
    final raw = _text!;
    final words = raw
        .split(RegExp(r'\s+'))
        .where((w) => w.trim().isNotEmpty)
        .toList();
    final toks = <_Token>[];
    for (int i = 0; i < words.length; i++) {
      toks.add(_Token(i, words[i], _normalize(words[i])));
    }
    setState(() {
      _tokens = toks;
      _bank = List.of(toks)..shuffle();
      _placed.clear();
      _mistakes = 0;
      _phase = _Phase.practice;
    });
    FeedbackEngine.I.tap();
  }

  void _tapBankWord(_Token token) {
    if (_placed.length >= _tokens.length) return;
    final expected = _tokens[_placed.length];
    if (token.norm == expected.norm && token.norm.isNotEmpty) {
      setState(() {
        _bank.remove(token);
        _placed.add(token);
        _correctFlashIdx = token.idx;
      });
      FeedbackEngine.I.tap();
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _correctFlashIdx = null);
      });
      if (_placed.length == _tokens.length) {
        Future.delayed(const Duration(milliseconds: 350), _finishPractice);
      }
    } else {
      FeedbackEngine.I.tap();
      setState(() {
        _mistakes++;
        _wrongFlashIdx = token.idx;
      });
      Future.delayed(const Duration(milliseconds: 450), () {
        if (mounted) setState(() => _wrongFlashIdx = null);
      });
    }
  }

  Future<void> _finishPractice() async {
    final total = _tokens.length;
    final ratio = total == 0 ? 0.0 : _mistakes / total;
    int quality;
    if (_mistakes == 0) {
      quality = 2;
    } else if (ratio <= 0.25) {
      quality = 1;
    } else {
      quality = 0;
    }
    final newState = await VerseMemoryService.I.recordReview(
      verseId: widget.verse.id,
      quality: quality,
    );
    await DailyPracticeService.I.mark(DailyPractice.study);
    if (!mounted) return;
    final mastered = newState.level >= 5;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) =>
          _buildResultDialog(ctx, quality, newState.level, mastered),
    );
    if (mounted) Navigator.pop(context);
  }

  Widget _buildResultDialog(
      BuildContext ctx, int quality, int level, bool mastered) {
    final t = AppThemeData.of(ctx);
    final color = quality == 2
        ? AppDesignSystem.victory
        : quality == 1
            ? AppDesignSystem.hope
            : AppDesignSystem.struggle;
    final icon = quality == 2
        ? Icons.emoji_events_rounded
        : quality == 1
            ? Icons.trending_up_rounded
            : Icons.refresh_rounded;
    final title = mastered
        ? '¡Versículo dominado!'
        : quality == 2
            ? '¡Perfecto!'
            : quality == 1
                ? '¡Bien hecho!'
                : 'Sigue practicando';
    final body = mastered
        ? 'Ahora es parte permanente de tu armadura espiritual.'
        : quality == 2
            ? 'Sin errores. Avanzaste al nivel $level/5.'
            : quality == 1
                ? 'Errores: $_mistakes/${_tokens.length}. Nivel $level/5.'
                : 'Errores: $_mistakes/${_tokens.length}. Repásalo más a menudo.';
    return AlertDialog(
      backgroundColor: t.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
      ),
      title: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: AppDesignSystem.headlineSmall(ctx, color: t.textPrimary),
            ),
          ),
        ],
      ),
      content: Text(
        body,
        style: AppDesignSystem.bodyMedium(ctx, color: t.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(
            'Continuar',
            style: AppDesignSystem.labelLarge(
              ctx,
              color: AppDesignSystem.gold,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _changeVersion() async {
    final t = AppThemeData.of(context);
    final picked = await showModalBottomSheet<BibleVersion>(
      context: context,
      backgroundColor: t.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: t.textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppDesignSystem.spacingM),
                child: Text(
                  'Versión para este versículo',
                  style: AppDesignSystem.headlineSmall(
                    context,
                    color: t.textPrimary,
                  ),
                ),
              ),
              ...BibleVersion.values.map((v) {
                final selected = v == _loadedVersion;
                return ListTile(
                  leading: Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: selected ? AppDesignSystem.gold : t.textSecondary,
                  ),
                  title: Text(
                    v.displayName,
                    style: AppDesignSystem.bodyLarge(
                        context, color: t.textPrimary),
                  ),
                  subtitle: Text(v.shortName,
                      style: AppDesignSystem.labelSmall(context,
                          color: t.textSecondary)),
                  onTap: () => Navigator.pop(ctx, v),
                );
              }),
              const SizedBox(height: AppDesignSystem.spacingM),
            ],
          ),
          ),
        );
      },
    );
    if (picked != null) {
      await VerseMemoryService.I.setPreferredVersion(picked);
      await _loadText();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final state = VerseMemoryService.I.stateFor(widget.verse.id);
    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: t.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: t.textPrimary),
        title: Text(
          widget.verse.reference,
          style: AppDesignSystem.headlineMedium(context, color: t.textPrimary),
        ),
        actions: [
          ValueListenableBuilder<BibleVersion>(
            valueListenable: VerseMemoryService.I.preferredVersionNotifier,
            builder: (context, v, _) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: _changeVersion,
                icon: const Icon(Icons.menu_book_rounded, size: 18),
                label: Text(v.shortName),
                style: TextButton.styleFrom(
                  foregroundColor: AppDesignSystem.gold,
                  textStyle: AppDesignSystem.labelLarge(context),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDesignSystem.spacingL),
          child: Column(
            children: [
              _buildLevelHeader(context, t, state.level),
              const SizedBox(height: AppDesignSystem.spacingM),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _text == null
                        ? _buildNoTextFallback(context, t)
                        : _phase == _Phase.preview
                            ? _buildPreview(context, t)
                            : _buildPractice(context, t),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoTextFallback(BuildContext context, AppThemeData t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.spacingL),
        child: Text(
          'No se encontró el texto en la versión elegida. Prueba otra versión desde el botón superior.',
          textAlign: TextAlign.center,
          style: AppDesignSystem.bodyLarge(context, color: t.textSecondary),
        ),
      ),
    );
  }

  Widget _buildLevelHeader(BuildContext context, AppThemeData t, int level) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDesignSystem.spacingM),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
        border: Border.all(color: t.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_moon_rounded,
                  color: AppDesignSystem.gold, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Nivel $level/5 · ${_levelName(level)}',
                  style: AppDesignSystem.labelLarge(
                    context,
                    color: t.textPrimary,
                  ),
                ),
              ),
              if (_phase == _Phase.practice && _tokens.isNotEmpty)
                Text(
                  '${_placed.length}/${_tokens.length}',
                  style: AppDesignSystem.labelMedium(
                    context,
                    color: t.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: List.generate(5, (i) {
              final filled = i < level;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < 4 ? 4 : 0),
                  height: 4,
                  decoration: BoxDecoration(
                    color: filled
                        ? AppDesignSystem.gold
                        : t.textSecondary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  String _levelName(int level) {
    switch (level) {
      case 0:
        return 'Nuevo';
      case 1:
        return 'Reconoce';
      case 2:
        return 'Construye';
      case 3:
        return 'Recita';
      case 4:
        return 'Aplica';
      case 5:
        return 'Dominado';
      default:
        return '';
    }
  }

  // ─────────────────────────── PREVIEW ──────────────────────────────

  Widget _buildPreview(BuildContext context, AppThemeData t) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.verse.topic,
            style: AppDesignSystem.labelMedium(
              context,
              color: AppDesignSystem.gold,
            ),
          ),
          const SizedBox(height: AppDesignSystem.spacingS),
          Text(
            _text!,
            style: AppDesignSystem.scripture(context, color: t.textPrimary),
          ),
          const SizedBox(height: AppDesignSystem.spacingS),
          Text(
            '— ${widget.verse.reference} (${_loadedVersion?.shortName ?? ''})',
            style: AppDesignSystem.scriptureReference(context),
          ),
          const SizedBox(height: AppDesignSystem.spacingXL),
          Container(
            padding: const EdgeInsets.all(AppDesignSystem.spacingM),
            decoration: BoxDecoration(
              color: AppDesignSystem.gold.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
              border: Border.all(
                color: AppDesignSystem.gold.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline_rounded,
                    color: AppDesignSystem.gold, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Cuando estés listo, toca "Practicar": reordenarás las palabras para memorizarlo.',
                    style: AppDesignSystem.bodyMedium(
                      context,
                      color: t.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDesignSystem.spacingL),
          SizedBox(
            width: double.infinity,
            child: PremiumButton(
              onPressed: _startPractice,
              gradient: const LinearGradient(
                colors: [AppDesignSystem.gold, AppDesignSystem.goldLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              child: Text(
                'Practicar',
                style: AppDesignSystem.labelLarge(
                  context,
                  color: AppDesignSystem.midnightDeep,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── PRACTICE ─────────────────────────────

  Widget _buildPractice(BuildContext context, AppThemeData t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Zona de destino (arriba): palabras colocadas
        Container(
          constraints: const BoxConstraints(minHeight: 120),
          width: double.infinity,
          padding: const EdgeInsets.all(AppDesignSystem.spacingM),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
            border: Border.all(color: t.cardBorder),
          ),
          child: _placed.isEmpty
              ? Center(
                  child: Text(
                    'Toca las palabras en el orden correcto',
                    style: AppDesignSystem.labelMedium(
                      context,
                      color: t.textSecondary,
                    ),
                  ),
                )
              : Wrap(
                  spacing: 6,
                  runSpacing: 8,
                  children: _placed.map((tok) {
                    final isFlash = _correctFlashIdx == tok.idx;
                    return _PlacedChip(
                      label: tok.display,
                      highlight: isFlash,
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: AppDesignSystem.spacingS),
        Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 16, color: AppDesignSystem.struggle),
            const SizedBox(width: 4),
            Text(
              'Errores: $_mistakes',
              style: AppDesignSystem.labelMedium(
                context,
                color: t.textSecondary,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _resetPractice,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Reiniciar'),
              style: TextButton.styleFrom(
                foregroundColor: t.textSecondary,
                textStyle: AppDesignSystem.labelMedium(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDesignSystem.spacingS),
        // Banco (abajo)
        Expanded(
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 10,
              children: _bank.map((tok) {
                final isWrong = _wrongFlashIdx == tok.idx;
                return _BankChip(
                  label: tok.display,
                  wrong: isWrong,
                  onTap: () => _tapBankWord(tok),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  void _resetPractice() {
    if (_tokens.isEmpty) return;
    FeedbackEngine.I.tap();
    setState(() {
      _bank = List.of(_tokens)..shuffle();
      _placed.clear();
      // No reiniciamos _mistakes: penaliza reintento.
    });
  }
}

class _PlacedChip extends StatelessWidget {
  final String label;
  final bool highlight;
  const _PlacedChip({required this.label, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: highlight
            ? AppDesignSystem.gold.withOpacity(0.25)
            : AppDesignSystem.gold.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
        border: Border.all(
          color: AppDesignSystem.gold.withOpacity(highlight ? 0.8 : 0.4),
        ),
      ),
      child: Text(
        label,
        style: AppDesignSystem.bodyLarge(context, color: t.textPrimary)
            .copyWith(fontWeight: FontWeight.w600),
      ),
    ).animate(target: highlight ? 1 : 0).scale(
          duration: 160.ms,
          begin: const Offset(1, 1),
          end: const Offset(1.08, 1.08),
        );
  }
}

class _BankChip extends StatelessWidget {
  final String label;
  final bool wrong;
  final VoidCallback onTap;

  const _BankChip({
    required this.label,
    required this.wrong,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: wrong ? AppDesignSystem.struggle.withOpacity(0.15) : t.cardBg,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
        border: Border.all(
          color: wrong ? AppDesignSystem.struggle : t.cardBorder,
          width: wrong ? 1.5 : 1,
        ),
        boxShadow: t.cardShadow,
      ),
      child: Text(
        label,
        style: AppDesignSystem.bodyLarge(
          context,
          color: wrong ? AppDesignSystem.struggle : t.textPrimary,
        ),
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
        onTap: onTap,
        child: wrong
            ? chip
                .animate()
                .shake(hz: 6, offset: const Offset(2, 0), duration: 300.ms)
            : chip,
      ),
    );
  }
}
