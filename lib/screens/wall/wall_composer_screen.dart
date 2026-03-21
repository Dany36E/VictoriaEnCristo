/// ═══════════════════════════════════════════════════════════════════════════
/// WALL COMPOSER SCREEN - Crear nuevo post en el Muro de Batalla
/// Selector de gigante, campo de texto (max 500), aviso de privacidad,
/// botón de publicar.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../models/content_enums.dart';
import '../../models/bible/bible_verse.dart';
import '../../services/wall_service.dart';
import '../../services/feedback_engine.dart';

const int _kMaxPostLength = 500;

class WallComposerScreen extends StatefulWidget {
  final BibleVerse? preloadedVerse;
  const WallComposerScreen({super.key, this.preloadedVerse});

  @override
  State<WallComposerScreen> createState() => _WallComposerScreenState();
}

class _WallComposerScreenState extends State<WallComposerScreen> {
  final _textController = TextEditingController();
  GiantId? _selectedGiant;
  bool _sending = false;
  int _charCount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.preloadedVerse != null) {
      final v = widget.preloadedVerse!;
      _textController.text =
          '📖 ${v.reference} (${v.version})\n«${v.text}»\n\n';
      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: _textController.text.length),
      );
    }
    _textController.addListener(() {
      setState(() => _charCount = _textController.text.trim().length);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  bool get _canPublish =>
      _selectedGiant != null &&
      _charCount >= 10 &&
      _charCount <= _kMaxPostLength &&
      !_sending;

  Future<void> _publish() async {
    if (!_canPublish) return;
    FeedbackEngine.I.confirm();
    setState(() => _sending = true);

    final result = await WallService.I.submitPost(
      giantId: _selectedGiant!.id,
      body: _textController.text.trim(),
    );

    if (!mounted) return;

    if (result.success) {
      Navigator.pop(context, true);
    } else {
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.message,
            style: const TextStyle(color: AppDesignSystem.pureWhite),
          ),
          backgroundColor: AppDesignSystem.struggle,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.midnight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Compartir en el Muro',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppDesignSystem.pureWhite,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppDesignSystem.pureWhite),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _canPublish ? _publish : null,
              child: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppDesignSystem.gold,
                      ),
                    )
                  : Text(
                      'Publicar',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _canPublish
                            ? AppDesignSystem.gold
                            : AppDesignSystem.coolGray.withValues(alpha: 0.4),
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDesignSystem.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Privacy notice ──
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppDesignSystem.gold.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppDesignSystem.gold.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.security_rounded,
                      size: 18,
                      color: AppDesignSystem.gold.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tu identidad es 100% anónima. Se te asignará un alias aleatorio.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: AppDesignSystem.gold.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms),
              const SizedBox(height: 20),

              // ── Giant selector ──
              const Text(
                '¿Sobre qué lucha quieres hablar?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppDesignSystem.pureWhite,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: GiantId.values.map((g) {
                  final selected = _selectedGiant == g;
                  return GestureDetector(
                    onTap: () {
                      FeedbackEngine.I.select();
                      setState(() => _selectedGiant = g);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppDesignSystem.gold.withValues(alpha: 0.2)
                            : AppDesignSystem.midnightLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? AppDesignSystem.gold.withValues(alpha: 0.5)
                              : AppDesignSystem.gold.withValues(alpha: 0.1),
                          width: selected ? 1.5 : 0.5,
                        ),
                      ),
                      child: Text(
                        g.displayName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected
                              ? AppDesignSystem.gold
                              : AppDesignSystem.coolGray,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // ── Text field ──
              const Text(
                'Tu mensaje',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppDesignSystem.pureWhite,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _textController,
                maxLength: _kMaxPostLength,
                maxLines: 8,
                minLines: 5,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: AppDesignSystem.pureWhite,
                ),
                decoration: InputDecoration(
                  hintText:
                      'Comparte tu lucha, tu victoria o una palabra de aliento...',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: AppDesignSystem.coolGray.withValues(alpha: 0.4),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF1A1A2E),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
                    borderSide: BorderSide(
                      color: AppDesignSystem.gold.withValues(alpha: 0.15),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
                    borderSide: const BorderSide(
                      color: Color(0xFFD4AF37),
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.all(AppDesignSystem.spacingM),
                  counterStyle: TextStyle(
                    fontSize: 11,
                    color: _charCount > _kMaxPostLength * 0.9
                        ? AppDesignSystem.struggle
                        : AppDesignSystem.coolGray.withValues(alpha: 0.5),
                  ),
                ),
                cursorColor: AppDesignSystem.gold,
              ),
              const SizedBox(height: 8),
              // Min chars hint
              if (_charCount > 0 && _charCount < 10)
                Text(
                  'Mínimo 10 caracteres (${10 - _charCount} más)',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppDesignSystem.coolGray.withValues(alpha: 0.5),
                  ),
                ),
              const SizedBox(height: 24),

              // ── Moderation notice ──
              Row(
                children: [
                  Icon(
                    Icons.visibility_outlined,
                    size: 14,
                    color: AppDesignSystem.coolGray.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Tu mensaje será revisado antes de ser publicado.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppDesignSystem.coolGray.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
