/// ═══════════════════════════════════════════════════════════════════════════
/// GameHeadbanzScreen — "¿Quién soy? Bíblico" (tipo Headbanz)
///
/// Modo casual para pasar el rato. No hay ganador.
///   1. El jugador pone el celular en su frente sin mirar la pantalla.
///   2. La app muestra una carta bíblica al resto del grupo.
///   3. Los demás dan pistas y el jugador adivina.
///   4. Inclina/toca para pasar a la siguiente carta.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../services/audio_engine.dart';
import '../../services/feedback_engine.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';

class _HeadbanzCard {
  const _HeadbanzCard(this.name, this.asset, this.difficulty);
  final String name;
  final String asset;
  final _HeadbanzDifficulty difficulty;
}

enum _HeadbanzDifficulty { easy, medium, hard }

extension _HeadbanzDifficultyInfo on _HeadbanzDifficulty {
  String get label {
    switch (this) {
      case _HeadbanzDifficulty.easy:
        return 'Fácil';
      case _HeadbanzDifficulty.medium:
        return 'Medio';
      case _HeadbanzDifficulty.hard:
        return 'Difícil';
    }
  }

  String get description {
    switch (this) {
      case _HeadbanzDifficulty.easy:
        return 'Más conocidos';
      case _HeadbanzDifficulty.medium:
        return 'Familiares';
      case _HeadbanzDifficulty.hard:
        return 'Más específicos';
    }
  }

  IconData get icon {
    switch (this) {
      case _HeadbanzDifficulty.easy:
        return Icons.sentiment_satisfied_alt_rounded;
      case _HeadbanzDifficulty.medium:
        return Icons.psychology_alt_rounded;
      case _HeadbanzDifficulty.hard:
        return Icons.local_fire_department_rounded;
    }
  }

  Color get color {
    switch (this) {
      case _HeadbanzDifficulty.easy:
        return AppDesignSystem.victory;
      case _HeadbanzDifficulty.medium:
        return AppDesignSystem.gold;
      case _HeadbanzDifficulty.hard:
        return AppDesignSystem.struggle;
    }
  }
}

/// Baraja de 24 personajes bíblicos.
const List<_HeadbanzCard> _deck = [
  _HeadbanzCard('Aarón', 'assets/images/headbanz/Headbanz_Aaron.png', _HeadbanzDifficulty.medium),
  _HeadbanzCard('Abraham', 'assets/images/headbanz/Headbanz_Abraham.png', _HeadbanzDifficulty.easy),
  _HeadbanzCard(
    'Benjamín',
    'assets/images/headbanz/Headbanz_Benjamin.png',
    _HeadbanzDifficulty.hard,
  ),
  _HeadbanzCard('Dalila', 'assets/images/headbanz/Headbanz_Dalila.png', _HeadbanzDifficulty.medium),
  _HeadbanzCard('Elías', 'assets/images/headbanz/Headbanz_Elias.png', _HeadbanzDifficulty.medium),
  _HeadbanzCard('Goliat', 'assets/images/headbanz/Headbanz_Goliat.png', _HeadbanzDifficulty.easy),
  _HeadbanzCard('Jacob', 'assets/images/headbanz/Headbanz_Jacob.png', _HeadbanzDifficulty.medium),
  _HeadbanzCard('Jesús', 'assets/images/headbanz/Headbanz_Jesus.png', _HeadbanzDifficulty.easy),
  _HeadbanzCard('Jonás', 'assets/images/headbanz/Headbanz_Jonas.png', _HeadbanzDifficulty.easy),
  _HeadbanzCard('José', 'assets/images/headbanz/Headbanz_Jose.png', _HeadbanzDifficulty.hard),
  _HeadbanzCard(
    'José el Soñador',
    'assets/images/headbanz/Headbanz_JoseElSoñador.png',
    _HeadbanzDifficulty.easy,
  ),
  _HeadbanzCard('Josué', 'assets/images/headbanz/Headbanz_Josue.png', _HeadbanzDifficulty.medium),
  _HeadbanzCard('Juan', 'assets/images/headbanz/Headbanz_Juan.png', _HeadbanzDifficulty.hard),
  _HeadbanzCard(
    'Juan el Bautista',
    'assets/images/headbanz/Headbanz_JuanElBautista.png',
    _HeadbanzDifficulty.medium,
  ),
  _HeadbanzCard(
    'Judas Iscariote',
    'assets/images/headbanz/Headbanz_JudasIscariote.png',
    _HeadbanzDifficulty.easy,
  ),
  _HeadbanzCard('Lea', 'assets/images/headbanz/Headbanz_Lea.png', _HeadbanzDifficulty.hard),
  _HeadbanzCard('Marta', 'assets/images/headbanz/Headbanz_Marta.png', _HeadbanzDifficulty.hard),
  _HeadbanzCard('Rebeca', 'assets/images/headbanz/Headbanz_Rebeca.png', _HeadbanzDifficulty.hard),
  _HeadbanzCard(
    'Salomón',
    'assets/images/headbanz/Headbanz_Salomon.png',
    _HeadbanzDifficulty.medium,
  ),
  _HeadbanzCard('Sansón', 'assets/images/headbanz/Headbanz_Sanson.png', _HeadbanzDifficulty.easy),
  _HeadbanzCard(
    'Santiago',
    'assets/images/headbanz/Headbanz_Santiago.png',
    _HeadbanzDifficulty.hard,
  ),
  _HeadbanzCard('Saúl', 'assets/images/headbanz/Headbanz_Saul.png', _HeadbanzDifficulty.medium),
  _HeadbanzCard('Tomás', 'assets/images/headbanz/Headbanz_Tomás.png', _HeadbanzDifficulty.hard),
  _HeadbanzCard('Zaqueo', 'assets/images/headbanz/Headbanz_Zaqueo.png', _HeadbanzDifficulty.easy),
];

enum _Phase { intro, playing }

class GameHeadbanzScreen extends StatefulWidget {
  const GameHeadbanzScreen({super.key});

  @override
  State<GameHeadbanzScreen> createState() => _GameHeadbanzScreenState();
}

class _GameHeadbanzScreenState extends State<GameHeadbanzScreen> {
  static const int _secondsPerCard = 60;

  _Phase _phase = _Phase.intro;
  _HeadbanzDifficulty _difficulty = _HeadbanzDifficulty.easy;
  late List<_HeadbanzCard> _shuffled;
  int _index = 0;
  int _seenCount = 0;
  int _countdown = 0; // 0 = carta visible, >0 = cuenta regresiva
  int _cardSecondsLeft = _secondsPerCard;
  bool _cardTimedOut = false;
  Timer? _countdownTimer;
  Timer? _cardTimer;

  @override
  void initState() {
    super.initState();
    _prepareDeck();
    // Música de tensión para adivina quién
    AudioEngine.I.switchBgmContext(BgmContext.learningHeadbanz);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _cardTimer?.cancel();
    // Restaurar música al salir
    AudioEngine.I.switchBgmContext(BgmContext.learningHeadbanz);
    super.dispose();
  }

  List<_HeadbanzCard> get _currentDeck =>
      _deck.where((card) => card.difficulty == _difficulty).toList(growable: false);

  void _prepareDeck() {
    _shuffled = List.of(_currentDeck)..shuffle(Random());
  }

  void _selectDifficulty(_HeadbanzDifficulty difficulty) {
    if (_difficulty == difficulty) return;
    FeedbackEngine.I.select();
    setState(() {
      _difficulty = difficulty;
      _prepareDeck();
      _index = 0;
      _seenCount = 0;
    });
  }

  void _start() {
    FeedbackEngine.I.select();
    setState(() {
      _prepareDeck();
      _phase = _Phase.playing;
      _index = 0;
      _seenCount = 1;
      _countdown = 3;
      _cardSecondsLeft = _secondsPerCard;
      _cardTimedOut = false;
    });
    _startCountdown();
  }

  void _next() {
    FeedbackEngine.I.tap();
    _countdownTimer?.cancel();
    _cardTimer?.cancel();
    setState(() {
      final nextIndex = _index + 1;
      if (nextIndex >= _shuffled.length) {
        _prepareDeck();
        _index = 0;
      } else {
        _index = nextIndex;
      }
      _seenCount += 1;
      _countdown = 3;
      _cardSecondsLeft = _secondsPerCard;
      _cardTimedOut = false;
    });
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _cardTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdown <= 1) {
        timer.cancel();
        setState(() => _countdown = 0);
        _startCardTimer();
        return;
      }
      setState(() => _countdown -= 1);
    });
  }

  void _startCardTimer() {
    _cardTimer?.cancel();
    _cardTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cardSecondsLeft <= 1) {
        timer.cancel();
        FeedbackEngine.I.tap();
        setState(() {
          _cardSecondsLeft = 0;
          _cardTimedOut = true;
        });
        return;
      }
      setState(() => _cardSecondsLeft -= 1);
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
          '¿Quién soy?',
          style: AppDesignSystem.headlineMedium(context, color: t.textPrimary),
        ),
      ),
      body: _phase == _Phase.intro ? _intro(t) : _playing(t),
    );
  }

  // ─────────────────────────── INTRO ───────────────────────────

  Widget _intro(AppThemeData t) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppDesignSystem.spacingL),
        children: [
          Container(
            padding: const EdgeInsets.all(AppDesignSystem.spacingL),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2D1B4E), Color(0xFF1A1A2E)],
              ),
              border: Border.all(color: AppDesignSystem.gold.withOpacity(0.35)),
            ),
            child: Column(
              children: [
                const Text('🎭', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 12),
                Text(
                  '¿QUIÉN SOY?',
                  textAlign: TextAlign.center,
                  style: AppDesignSystem.displaySmall(context, color: AppDesignSystem.gold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Personajes bíblicos · Modo fiesta',
                  textAlign: TextAlign.center,
                  style: AppDesignSystem.bodyMedium(context, color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDesignSystem.spacingL),
          _rulesCard(t),
          const SizedBox(height: AppDesignSystem.spacingL),
          _difficultySelector(t),
          const SizedBox(height: AppDesignSystem.spacingL),
          SizedBox(
            height: 60,
            child: ElevatedButton.icon(
              onPressed: _start,
              icon: const Icon(Icons.play_arrow_rounded, size: 28),
              label: Text(
                '¡Empezar a jugar!',
                style: AppDesignSystem.labelLarge(context, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppDesignSystem.gold,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppDesignSystem.spacingM),
          Text(
            'Sin ganador · Para pasar el rato · ${_currentDeck.length} cartas',
            textAlign: TextAlign.center,
            style: AppDesignSystem.labelSmall(context, color: t.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _difficultySelector(AppThemeData t) {
    return Container(
      padding: const EdgeInsets.all(AppDesignSystem.spacingM),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
        border: Border.all(color: t.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dificultad', style: AppDesignSystem.headlineSmall(context, color: t.textPrimary)),
          const SizedBox(height: AppDesignSystem.spacingM),
          for (final difficulty in _HeadbanzDifficulty.values) ...[
            _difficultyOption(t, difficulty),
            if (difficulty != _HeadbanzDifficulty.values.last)
              const SizedBox(height: AppDesignSystem.spacingS),
          ],
        ],
      ),
    );
  }

  Widget _difficultyOption(AppThemeData t, _HeadbanzDifficulty difficulty) {
    final selected = _difficulty == difficulty;
    final count = _deck.where((card) => card.difficulty == difficulty).length;
    return InkWell(
      onTap: () => _selectDifficulty(difficulty),
      borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
      child: AnimatedContainer(
        duration: 180.ms,
        padding: const EdgeInsets.all(AppDesignSystem.spacingM),
        decoration: BoxDecoration(
          color: selected ? difficulty.color.withOpacity(0.14) : t.inputBg,
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
          border: Border.all(
            color: selected ? difficulty.color.withOpacity(0.72) : t.cardBorder,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(difficulty.icon, color: difficulty.color),
            const SizedBox(width: AppDesignSystem.spacingS),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    difficulty.label,
                    style: AppDesignSystem.labelLarge(context, color: t.textPrimary),
                  ),
                  Text(
                    '${difficulty.description} · $count cartas',
                    style: AppDesignSystem.bodyMedium(context, color: t.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: selected ? difficulty.color : t.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _rulesCard(AppThemeData t) {
    return Container(
      padding: const EdgeInsets.all(AppDesignSystem.spacingM),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
        border: Border.all(color: t.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📜 Cómo se juega',
            style: AppDesignSystem.headlineSmall(context, color: t.textPrimary),
          ),
          const SizedBox(height: AppDesignSystem.spacingM),
          _rule(t, '1', 'Un jugador sostiene el celular en su frente sin mirar la pantalla.'),
          _rule(t, '2', 'Los demás ven la carta y le dan pistas (sin decir el nombre).'),
          _rule(t, '3', 'El jugador adivina. ¿Acertó o se rinde? Pasen a la siguiente.'),
          _rule(t, '4', 'Turnos libres. No hay puntaje, es sólo para reír y aprender.'),
        ],
      ),
    );
  }

  Widget _rule(AppThemeData t, String num, String txt) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppDesignSystem.gold.withOpacity(0.18),
              shape: BoxShape.circle,
              border: Border.all(color: AppDesignSystem.gold.withOpacity(0.6)),
            ),
            child: Text(
              num,
              style: const TextStyle(
                color: AppDesignSystem.gold,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(txt, style: AppDesignSystem.bodyMedium(context, color: t.textSecondary)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── PLAYING ───────────────────────────

  Widget _playing(AppThemeData t) {
    final card = _shuffled[_index];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.spacingM),
        child: Column(
          children: [
            // Contador superior.
            Wrap(
              alignment: WrapAlignment.center,
              runAlignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _statusPill(
                  label: 'Carta $_seenCount',
                  icon: Icons.style_rounded,
                  color: AppDesignSystem.gold,
                ),
                _statusPill(
                  label: _difficulty.label,
                  icon: _difficulty.icon,
                  color: _difficulty.color,
                ),
                if (_countdown == 0)
                  _statusPill(
                    label: _formatTime(_cardSecondsLeft),
                    icon: Icons.timer_rounded,
                    color: _cardTimedOut ? AppDesignSystem.struggle : AppDesignSystem.gold,
                  ),
              ],
            ),
            const SizedBox(height: AppDesignSystem.spacingM),

            // Carta grande o cuenta regresiva.
            Expanded(
              child: _countdown > 0
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🙈', style: TextStyle(fontSize: 64)),
                          const SizedBox(height: 16),
                          Text(
                            '¡No mires!',
                            style: AppDesignSystem.headlineMedium(
                              context,
                              color: AppDesignSystem.gold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Pon el celular en tu frente',
                            style: AppDesignSystem.bodyMedium(context, color: t.textSecondary),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            '$_countdown',
                            style: const TextStyle(
                              fontSize: 72,
                              fontWeight: FontWeight.w900,
                              color: AppDesignSystem.gold,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Center(
                          child: AnimatedContainer(
                            duration: 250.ms,
                            padding: const EdgeInsets.all(AppDesignSystem.spacingM),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
                              border: Border.all(
                                color: AppDesignSystem.gold.withOpacity(0.6),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppDesignSystem.gold.withOpacity(0.25),
                                  blurRadius: 24,
                                  spreadRadius: 2,
                                ),
                              ],
                              color: t.cardBg,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
                              child: Image.asset(card.asset, fit: BoxFit.contain),
                            ),
                          ),
                        )
                        .animate(key: ValueKey(_index))
                        .fadeIn(duration: 300.ms)
                        .slideX(begin: 0.1, end: 0),
            ),

            const SizedBox(height: AppDesignSystem.spacingM),

            AnimatedSwitcher(
              duration: 180.ms,
              child: _cardTimedOut
                  ? Padding(
                      key: const ValueKey('timeout'),
                      padding: const EdgeInsets.only(bottom: AppDesignSystem.spacingS),
                      child: Text(
                        'Tiempo agotado para esta carta',
                        textAlign: TextAlign.center,
                        style: AppDesignSystem.labelMedium(
                          context,
                          color: AppDesignSystem.struggle,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('no-timeout')),
            ),

            // Botón siguiente.
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _countdown > 0 ? null : _next,
                icon: const Icon(Icons.skip_next_rounded, size: 28),
                label: Text(
                  'Siguiente carta',
                  style: AppDesignSystem.labelLarge(context, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppDesignSystem.gold,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  Widget _statusPill({required String label, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
