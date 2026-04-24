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

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../services/feedback_engine.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';

class _HeadbanzCard {
  const _HeadbanzCard(this.name, this.asset);
  final String name;
  final String asset;
}

/// Baraja de 24 personajes bíblicos.
const List<_HeadbanzCard> _deck = [
  _HeadbanzCard('Aarón', 'assets/images/headbanz/Headbanz_Aaron.png'),
  _HeadbanzCard('Abraham', 'assets/images/headbanz/Headbanz_Abraham.png'),
  _HeadbanzCard('Benjamín', 'assets/images/headbanz/Headbanz_Benjamin.png'),
  _HeadbanzCard('Dalila', 'assets/images/headbanz/Headbanz_Dalila.png'),
  _HeadbanzCard('Elías', 'assets/images/headbanz/Headbanz_Elias.png'),
  _HeadbanzCard('Goliat', 'assets/images/headbanz/Headbanz_Goliat.png'),
  _HeadbanzCard('Jacob', 'assets/images/headbanz/Headbanz_Jacob.png'),
  _HeadbanzCard('Jesús', 'assets/images/headbanz/Headbanz_Jesus.png'),
  _HeadbanzCard('Jonás', 'assets/images/headbanz/Headbanz_Jonas.png'),
  _HeadbanzCard('José', 'assets/images/headbanz/Headbanz_Jose.png'),
  _HeadbanzCard('José el Soñador',
      'assets/images/headbanz/Headbanz_JoseElSoñador.png'),
  _HeadbanzCard('Josué', 'assets/images/headbanz/Headbanz_Josue.png'),
  _HeadbanzCard('Juan', 'assets/images/headbanz/Headbanz_Juan.png'),
  _HeadbanzCard('Juan el Bautista',
      'assets/images/headbanz/Headbanz_JuanElBautista.png'),
  _HeadbanzCard('Judas Iscariote',
      'assets/images/headbanz/Headbanz_JudasIscariote.png'),
  _HeadbanzCard('Lea', 'assets/images/headbanz/Headbanz_Lea.png'),
  _HeadbanzCard('Marta', 'assets/images/headbanz/Headbanz_Marta.png'),
  _HeadbanzCard('Rebeca', 'assets/images/headbanz/Headbanz_Rebeca.png'),
  _HeadbanzCard('Salomón', 'assets/images/headbanz/Headbanz_Salomon.png'),
  _HeadbanzCard('Sansón', 'assets/images/headbanz/Headbanz_Sanson.png'),
  _HeadbanzCard('Santiago', 'assets/images/headbanz/Headbanz_Santiago.png'),
  _HeadbanzCard('Saúl', 'assets/images/headbanz/Headbanz_Saul.png'),
  _HeadbanzCard('Tomás', 'assets/images/headbanz/Headbanz_Tomás.png'),
  _HeadbanzCard('Zaqueo', 'assets/images/headbanz/Headbanz_Zaqueo.png'),
];

enum _Phase { intro, playing }

class GameHeadbanzScreen extends StatefulWidget {
  const GameHeadbanzScreen({super.key});

  @override
  State<GameHeadbanzScreen> createState() => _GameHeadbanzScreenState();
}

class _GameHeadbanzScreenState extends State<GameHeadbanzScreen> {
  _Phase _phase = _Phase.intro;
  late List<_HeadbanzCard> _shuffled;
  int _index = 0;
  int _seenCount = 0;
  int _countdown = 0; // 0 = carta visible, >0 = cuenta regresiva

  @override
  void initState() {
    super.initState();
    _shuffled = List.of(_deck)..shuffle(Random());
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _start() {
    FeedbackEngine.I.select();
    setState(() {
      _phase = _Phase.playing;
      _index = 0;
      _seenCount = 1;
      _countdown = 3;
    });
    _startCountdown();
  }

  void _next() {
    FeedbackEngine.I.tap();
    setState(() {
      _index = (_index + 1) % _shuffled.length;
      _seenCount += 1;
      _countdown = 3;
      // Re-shuffle cuando se agota la baraja para variedad.
      if (_seenCount % _shuffled.length == 0) {
        _shuffled.shuffle(Random());
      }
    });
    _startCountdown();
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || _countdown <= 0) return;
      setState(() => _countdown -= 1);
      if (_countdown > 0) _startCountdown();
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
                  style: AppDesignSystem.displaySmall(context,
                      color: AppDesignSystem.gold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Personajes bíblicos · Modo fiesta',
                  textAlign: TextAlign.center,
                  style: AppDesignSystem.bodyMedium(context,
                      color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDesignSystem.spacingL),
          _rulesCard(t),
          const SizedBox(height: AppDesignSystem.spacingL),
          SizedBox(
            height: 60,
            child: ElevatedButton.icon(
              onPressed: _start,
              icon: const Icon(Icons.play_arrow_rounded, size: 28),
              label: Text(
                '¡Empezar a jugar!',
                style: AppDesignSystem.labelLarge(context,
                    color: Colors.white),
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
            'Sin ganador · Para pasar el rato · ${_deck.length} cartas',
            textAlign: TextAlign.center,
            style: AppDesignSystem.labelSmall(context, color: t.textSecondary),
          ),
        ],
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
            style: AppDesignSystem.headlineSmall(context,
                color: t.textPrimary),
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
            child: Text(
              txt,
              style: AppDesignSystem.bodyMedium(context,
                  color: t.textSecondary),
            ),
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppDesignSystem.gold.withOpacity(0.15),
                borderRadius:
                    BorderRadius.circular(AppDesignSystem.radiusFull),
                border:
                    Border.all(color: AppDesignSystem.gold.withOpacity(0.5)),
              ),
              child: Text(
                'Carta $_seenCount',
                style: const TextStyle(
                  color: AppDesignSystem.gold,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: AppDesignSystem.spacingM),

            // Carta grande o cuenta regresiva.
            Expanded(
              child: _countdown > 0
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '🙈',
                            style: TextStyle(fontSize: 64),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '¡No mires!',
                            style: AppDesignSystem.headlineMedium(context,
                                color: AppDesignSystem.gold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Pon el celular en tu frente',
                            style: AppDesignSystem.bodyMedium(context,
                                color: t.textSecondary),
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
                          borderRadius:
                              BorderRadius.circular(AppDesignSystem.radiusL),
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
                          borderRadius: BorderRadius.circular(
                              AppDesignSystem.radiusM),
                          child: Image.asset(
                            card.asset,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    )
                      .animate(key: ValueKey(_index))
                      .fadeIn(duration: 300.ms)
                      .slideX(begin: 0.1, end: 0),
            ),

            const SizedBox(height: AppDesignSystem.spacingM),

            // Botón siguiente.
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _countdown > 0 ? null : _next,
                icon: const Icon(Icons.skip_next_rounded, size: 28),
                label: Text(
                  'Siguiente carta',
                  style: AppDesignSystem.labelLarge(context,
                      color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppDesignSystem.gold,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDesignSystem.radiusL),
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
