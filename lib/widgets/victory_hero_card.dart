/// ═══════════════════════════════════════════════════════════════════════════
/// VICTORY HERO CARD - Elemento Hero de Victorias
/// Card premium de impacto visual para contador de días de victoria
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class VictoryHeroCard extends StatefulWidget {
  final int streakDays;
  final bool loggedToday;
  final bool isLoading;
  final VoidCallback onRegisterVictory;
  final VoidCallback? onTapCard; // Tap en el contador para navegar a Mi Progreso
  
  const VictoryHeroCard({
    super.key,
    required this.streakDays,
    required this.loggedToday,
    this.isLoading = false,
    required this.onRegisterVictory,
    this.onTapCard,
  });

  @override
  State<VictoryHeroCard> createState() => _VictoryHeroCardState();
}

class _VictoryHeroCardState extends State<VictoryHeroCard> with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  
  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }
  
  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }
  
  int get _nextMilestone {
    if (widget.streakDays < 7) return 7;
    if (widget.streakDays < 21) return 21;
    if (widget.streakDays < 30) return 30;
    if (widget.streakDays < 60) return 60;
    if (widget.streakDays < 90) return 90;
    return ((widget.streakDays ~/ 100) + 1) * 100;
  }
  
  double get _milestoneProgress {
    if (widget.streakDays < 7) return widget.streakDays / 7;
    if (widget.streakDays < 21) return (widget.streakDays - 7) / 14;
    if (widget.streakDays < 30) return (widget.streakDays - 21) / 9;
    if (widget.streakDays < 60) return (widget.streakDays - 30) / 30;
    if (widget.streakDays < 90) return (widget.streakDays - 60) / 30;
    final prevMilestone = (widget.streakDays ~/ 100) * 100;
    return (widget.streakDays - prevMilestone) / 100;
  }

  /// ¿Mostrar estado empático (nuevo amanecer)?
  bool get _isGraceState => widget.streakDays == 0 && !widget.loggedToday;

  // Colores condicionales
  Color get _accentColor => _isGraceState
      ? const Color(0xFFF4845F) // dawn coral
      : const Color(0xFFD4AF37); // gold

  Color get _accentLight => _isGraceState
      ? const Color(0xFFFFD6C0) // soft peach
      : const Color(0xFFFFE57F); // gold light

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        final glowValue = Curves.easeInOut.transform(_glowController.value);
        
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              // Glow exterior dorado sutil
              BoxShadow(
                color: _accentColor.withOpacity(0.15 + (glowValue * 0.1)),
                blurRadius: 30,
                spreadRadius: 0,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF0A0A12).withOpacity(0.85),
                      const Color(0xFF121225).withOpacity(0.80),
                      const Color(0xFF0A0A12).withOpacity(0.85),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                  border: Border.all(
                    color: _accentColor.withOpacity(0.3),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Stack(
                  children: [
                    // Efecto de brillo interior (muy sutil)
                    Positioned(
                      top: -50,
                      right: -50,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              _accentColor.withOpacity(0.08),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Contenido principal
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Área clickeable del contador (sin incluir el botón)
                          InkWell(
                            onTap: widget.onTapCard,
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Fila: Copa + Número + Labels
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Copa con glow
                                      _buildTrophyIcon(glowValue),
                                      
                                      const SizedBox(width: 20),
                                      
                                      // Contador y labels
                                      Expanded(
                                        child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Número grande
                                    if (widget.isLoading)
                                      SizedBox(
                                        width: 40,
                                        height: 40,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 3,
                                          valueColor: AlwaysStoppedAnimation(_accentColor),
                                        ),
                                      )
                                    else
                                      ShaderMask(
                                        shaderCallback: (bounds) => LinearGradient(
                                          colors: [
                                            _accentColor,
                                            _accentLight,
                                            _accentColor,
                                          ],
                                        ).createShader(bounds),
                                        child: Text(
                                          _isGraceState ? '\u{1F305}' : '${widget.streakDays}',
                                          style: const TextStyle(
                                            fontSize: 64,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                            height: 1,
                                            letterSpacing: -2,
                                          ),
                                        ),
                                      )
                                          .animate()
                                          .fadeIn(duration: 400.ms)
                                          .scale(
                                            begin: const Offset(0.95, 0.95),
                                            end: const Offset(1, 1),
                                            duration: 300.ms,
                                            curve: Curves.easeOutBack,
                                          ),
                                    
                                    const SizedBox(height: 8),
                                    
                                    // Título
                                    Text(
                                      _isGraceState ? 'NUEVO AMANECER' : 'DÍAS DE VICTORIA',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.5,
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                    ),
                                    
                                    const SizedBox(height: 4),
                                    
                                    // Racha actual + Estado hoy
                                    Row(
                                      children: [
                                        Text(
                                          _isGraceState
                                              ? 'Su gracia es suficiente'
                                              : 'Racha actual',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: _accentColor.withOpacity(0.8),
                                          ),
                                        ),
                                        if (widget.loggedToday) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF4CAF50).withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: const Color(0xFF4CAF50).withOpacity(0.4),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.check_circle,
                                                  size: 10,
                                                  color: Color(0xFF4CAF50),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Hoy',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w600,
                                                    color: const Color(0xFF4CAF50).withOpacity(0.9),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                                      ),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 16),
                                  
                                  // Barra de progreso al siguiente hito
                                  _buildMilestoneProgress(),
                                ],
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Botón registrar (fuera del InkWell del contador)
                          _buildRegisterButton(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildTrophyIcon(double glowValue) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            _accentColor.withOpacity(0.2),
            _accentColor.withOpacity(0.05),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: _accentColor.withOpacity(0.3 + (glowValue * 0.2)),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Icon(
          _isGraceState ? Icons.wb_sunny_rounded : Icons.emoji_events,
          color: _accentColor,
          size: 36,
          shadows: [
            Shadow(
              color: _accentColor.withOpacity(0.5),
              blurRadius: 10,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMilestoneProgress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Siguiente hito',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
            Text(
              '${widget.streakDays} / $_nextMilestone días',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _accentColor.withOpacity(0.8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 6,
            child: Stack(
              children: [
                // Fondo
                Container(
                  color: Colors.white.withOpacity(0.1),
                ),
                // Progreso
                FractionallySizedBox(
                  widthFactor: _milestoneProgress,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _accentColor,
                          _accentLight,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _accentColor.withOpacity(0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildRegisterButton() {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.loggedToday ? null : widget.onRegisterVictory,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: widget.loggedToday
                  ? null
                  : LinearGradient(
                      colors: [_accentColor, _accentColor.withOpacity(0.8)],
                    ),
              color: widget.loggedToday 
                  ? Colors.white.withOpacity(0.08) 
                  : null,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.loggedToday 
                    ? const Color(0xFF4CAF50).withOpacity(0.4)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.loggedToday 
                      ? Icons.check_circle 
                      : Icons.add_circle_outline,
                  color: widget.loggedToday 
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFF0A0A12),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  widget.loggedToday 
                      ? 'Victoria registrada' 
                      : _isGraceState
                          ? 'Comenzar de nuevo hoy'
                          : 'Registrar victoria de hoy',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: widget.loggedToday 
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFF0A0A12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
