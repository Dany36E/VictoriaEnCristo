import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../data/bible_verses.dart';
import '../widgets/share_verse_modal.dart';
import '../services/favorites_service.dart';
import '../services/audio_service.dart';
import '../services/feedback_engine.dart';
import '../services/personalization_engine.dart';
import '../services/content_repository.dart';
import '../models/content_item.dart';
import 'emotional_verse_jar_screen.dart';

class VersesScreen extends StatefulWidget {
  const VersesScreen({super.key});

  @override
  State<VersesScreen> createState() => _VersesScreenState();
}

class _VersesScreenState extends State<VersesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Categorías dinámicas (se construyen en initState)
  List<String> _categories = [];
  
  // Versículos personalizados
  List<ScoredItem<VerseItem>> _recommendedVerses = [];
  bool _hasPersonalization = false;

  // Colores del Design System
  static const Color _creamBackground = Color(0xFFFAF7F2); // Fondo crema cálido
  static const Color _goldAccent = Color(0xFFD4A853);
  static const Color _goldLight = Color(0xFFE8C97A);
  static const Color _textDark = Color(0xFF1A1A1A); // Casi negro para versículos
  static const Color _textMedium = Color(0xFF4A4A4A); // Gris medio oscuro

  @override
  void initState() {
    super.initState();
    _initializeCategories();
  }
  
  void _initializeCategories() {
    // Verificar si hay contenido personalizado
    final engine = PersonalizationEngine.I;
    final userGiants = engine.userGiants;
    
    if (userGiants.isNotEmpty && ContentRepository.I.isInitialized) {
      // Intentar obtener versículos personalizados
      _recommendedVerses = engine.getRecommendedVerses(limit: 10);
      _hasPersonalization = _recommendedVerses.isNotEmpty;
    }
    
    // Construir lista de categorías - "Para Ti" primero si hay personalización
    if (_hasPersonalization) {
      _categories = ['⭐ Para Ti', 'Todos', 'Tentación', 'Pureza', 'Fortaleza', 'Victoria', 'Espíritu'];
    } else {
      _categories = ['Todos', 'Tentación', 'Pureza', 'Fortaleza', 'Victoria', 'Espíritu'];
    }
    
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<BibleVerse> _getVersesForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'tentación':
        return BibleVerses.temptationVerses;
      case 'pureza':
        return BibleVerses.purityVerses;
      case 'fortaleza':
        return BibleVerses.strengthVerses;
      case 'victoria':
        return BibleVerses.victoryVerses;
      case 'espíritu':
        return BibleVerses.holySpiriteVerses;
      default:
        return BibleVerses.allVerses;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _creamBackground,
      body: Column(
        children: [
          // ═══════════════════════════════════════════════════════════════
          // ENCABEZADO PREMIUM - Fondo crema cálido
          // ═══════════════════════════════════════════════════════════════
          _buildPremiumHeader(),
          
          // ═══════════════════════════════════════════════════════════════
          // LISTA DE VERSÍCULOS
          // ═══════════════════════════════════════════════════════════════
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _categories.map((category) {
                // Check if it's the personalized tab
                if (category.contains('Para Ti') && _hasPersonalization) {
                  return _buildPersonalizedVerseList();
                }
                final verses = _getVersesForCategory(category);
                return _buildVerseList(verses);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // LISTA DE VERSÍCULOS PERSONALIZADOS (con razón de recomendación)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildPersonalizedVerseList() {
    if (_recommendedVerses.isEmpty) {
      return Center(
        child: Text(
          'Completa tu onboarding para ver recomendaciones',
          style: TextStyle(color: _textMedium),
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _recommendedVerses.length,
      itemBuilder: (context, index) {
        final scored = _recommendedVerses[index];
        final verse = scored.item;
        
        // Convertir VerseItem a BibleVerse para reutilizar widgets existentes
        final bibleVerse = BibleVerse(
          verse: verse.title,
          reference: verse.reference,
          category: 'personalizado',
        );
        
        return _buildPersonalizedVerseCard(bibleVerse, scored.reason, index);
      },
    );
  }
  
  Widget _buildPersonalizedVerseCard(BibleVerse verse, String reason, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: _goldAccent.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            FeedbackEngine.I.tap();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(verse.reference),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Razón de recomendación (badge)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _goldAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _goldAccent.withOpacity(0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 12,
                        color: _goldAccent,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          reason,
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _goldAccent,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Versículo
                Text(
                  '"${verse.verse}"',
                  style: GoogleFonts.lora(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: _textDark,
                    height: 1.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Referencia
                Text(
                  verse.reference,
                  style: GoogleFonts.cinzel(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _goldAccent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: 50 * index), duration: 300.ms);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ENCABEZADO PREMIUM CON HERO BANNER
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildPremiumHeader() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0E8), // Crema más cálido para header
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ═══════════════════════════════════════════════════════════════
            // Barra superior con botón atrás y título (SIN botón pequeño)
            // ═══════════════════════════════════════════════════════════════
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                children: [
                  // Botón atrás
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: _textDark,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Título
                  Text(
                    'Versículos Bíblicos',
                    style: GoogleFonts.cinzel(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: _textDark,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            
            // ═══════════════════════════════════════════════════════════════
            // HERO BANNER - CTA Card Emocional (La estrella de la pantalla)
            // ═══════════════════════════════════════════════════════════════
            _buildEmotionalHeroBanner(),
            
            const SizedBox(height: 16),
            
            // ═══════════════════════════════════════════════════════════════
            // Tabs de filtro (ahora secundarias)
            // ═══════════════════════════════════════════════════════════════
            SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final isActive = _tabController.index == index;
                  return GestureDetector(
                    onTap: () {
                      FeedbackEngine.I.tabChange();  // Haptic + SFX whoosh
                      _tabController.animateTo(index);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Text(
                              _categories[index],
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                color: isActive ? _goldAccent : _textMedium,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          // Línea indicadora dorada
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 2,
                            width: isActive ? 40 : 0,
                            decoration: BoxDecoration(
                              color: _goldAccent,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HERO BANNER - Tarjeta CTA Emocional Destacada
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildEmotionalHeroBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () {
          FeedbackEngine.I.confirm();  // Haptic + SFX confirm (CTA principal)
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const EmotionalVerseJarScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
              transitionDuration: const Duration(milliseconds: 400),
            ),
          );
        },
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            // Fondo oscuro premium de marca
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0D1B2A), // Azul muy oscuro
                Color(0xFF1A2D42), // Azul medianoche
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            // Borde dorado sutil
            border: Border.all(
              color: _goldAccent.withOpacity(0.3),
              width: 1.5,
            ),
            // Sombra dramática
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D1B2A).withOpacity(0.4),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: _goldAccent.withOpacity(0.1),
                blurRadius: 32,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                // ═══════════════════════════════════════════════════════════
                // Patrón decorativo de fondo (círculos sutiles)
                // ═══════════════════════════════════════════════════════════
                Positioned(
                  right: -30,
                  top: -30,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _goldAccent.withOpacity(0.15),
                          _goldAccent.withOpacity(0),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: -20,
                  bottom: -20,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _goldAccent.withOpacity(0.1),
                          _goldAccent.withOpacity(0),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // ═══════════════════════════════════════════════════════════
                // Contenido principal del Hero Banner
                // ═══════════════════════════════════════════════════════════
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      // Contenido de texto (lado izquierdo)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Icono de emoción animado
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _goldAccent.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.auto_awesome_rounded,
                                    color: _goldAccent,
                                    size: 20,
                                  ),
                                ).animate(onPlay: (c) => c.repeat(reverse: true))
                                  .shimmer(duration: 2000.ms, color: _goldLight.withOpacity(0.3)),
                                const SizedBox(width: 10),
                                Text(
                                  'NUEVO',
                                  style: GoogleFonts.manrope(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: _goldAccent,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Título principal
                            Text(
                              '¿Cómo te sientes hoy?',
                              style: GoogleFonts.cinzel(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.3,
                                height: 1.2,
                              ),
                            ),
                            
                            const SizedBox(height: 10),
                            
                            // Subtítulo descriptivo
                            Text(
                              'Descubre una promesa de Dios específica para tu estado de ánimo.',
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withOpacity(0.7),
                                height: 1.5,
                              ),
                            ),
                            
                            const SizedBox(height: 20),
                            
                            // Botón CTA
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFD4A853),
                                    Color(0xFFE8C97A),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: _goldAccent.withOpacity(0.4),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.spa_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Buscar Consuelo',
                                    style: GoogleFonts.manrope(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Ilustración decorativa (lado derecho)
                      const SizedBox(width: 16),
                      _buildEmotionIcons(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms, delay: 100.ms)
        .slideY(begin: 0.1, end: 0, duration: 500.ms, curve: Curves.easeOutCubic);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ICONOS DE EMOCIONES DECORATIVOS (lado derecho del banner)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildEmotionIcons() {
    final emotions = [
      (Icons.sentiment_very_satisfied_rounded, const Color(0xFFFFD700)),
      (Icons.spa_rounded, const Color(0xFF98FF98)),
      (Icons.favorite_rounded, const Color(0xFFFF7F50)),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(emotions.length, (index) {
        return Padding(
          padding: EdgeInsets.only(bottom: index < emotions.length - 1 ? 8 : 0),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: emotions[index].$2.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: emotions[index].$2.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Icon(
              emotions[index].$1,
              color: emotions[index].$2,
              size: 22,
            ),
          )
              .animate(delay: Duration(milliseconds: 200 + (index * 100)))
              .fadeIn(duration: 400.ms)
              .scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),
        );
      }),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LISTA DE VERSÍCULOS CON ANIMACIÓN STAGGER
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildVerseList(List<BibleVerse> verses) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      itemCount: verses.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: _PremiumVerseCard(
            verse: verses[index],
            index: index,
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TARJETA DE VERSÍCULO PREMIUM
// ═══════════════════════════════════════════════════════════════════════════════
class _PremiumVerseCard extends StatelessWidget {
  final BibleVerse verse;
  final int index;

  const _PremiumVerseCard({
    required this.verse,
    required this.index,
  });

  // Colores
  static const Color _goldAccent = Color(0xFFD4A853);
  static const Color _goldSubtle = Color(0x15D4A853); // 8% opacity
  static const Color _textDark = Color(0xFF1A1A1A);
  static const Color _cardBg = Colors.white;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20), // Border radius aumentado
        // Sombra suave y difusa (soft shadow)
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D1B2A).withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: const Color(0xFF0D1B2A).withOpacity(0.02),
            blurRadius: 32,
            offset: const Offset(0, 12),
            spreadRadius: -8,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ═══════════════════════════════════════════════════════════════
            // ETIQUETA DE CATEGORÍA (Premium Pill Style)
            // ═══════════════════════════════════════════════════════════════
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _goldSubtle,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                verse.category.toUpperCase(),
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _goldAccent,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // ═══════════════════════════════════════════════════════════════
            // TEXTO DEL VERSÍCULO (Héroe - Protagonista)
            // ═══════════════════════════════════════════════════════════════
            Text(
              '"${verse.verse}"',
              style: GoogleFonts.crimsonPro(
                fontSize: 19, // Aumentado significativamente
                fontWeight: FontWeight.w400,
                fontStyle: FontStyle.italic,
                color: _textDark, // Casi negro para máximo contraste
                height: 1.7, // Interlineado generoso
                letterSpacing: 0.2,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // ═══════════════════════════════════════════════════════════════
            // FILA INFERIOR: Referencia + Iconos de Acción
            // ═══════════════════════════════════════════════════════════════
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Referencia Bíblica (con espacio flexible limitado)
                Expanded(
                  flex: 2,
                  child: Text(
                    verse.reference,
                    textAlign: TextAlign.right,
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: _goldAccent,
                      letterSpacing: 0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                
                const SizedBox(width: 6),
                
                // Iconos de Acción (compactos, sin flex)
                _AudioIcon(verse: verse),
                _ActionIcon(
                  icon: Icons.copy_rounded,
                  tooltip: 'Copiar',
                  onTap: () => _copyToClipboard(context),
                ),
                _ActionIcon(
                  icon: Icons.share_rounded,
                  tooltip: 'Compartir',
                  onTap: () => _shareVerse(context),
                ),
                _FavoriteIcon(verse: verse),
              ],
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: 50 * index),
          duration: const Duration(milliseconds: 400),
        )
        .slideY(
          begin: 0.1,
          end: 0,
          delay: Duration(milliseconds: 50 * index),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
  }

  void _copyToClipboard(BuildContext context) {
    HapticFeedback.mediumImpact();
    final text = '"${verse.verse}" — ${verse.reference}';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(
              'Versículo copiado',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0D1B2A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareVerse(BuildContext context) {
    HapticFeedback.mediumImpact();
    // Abrir modal de compartir con previsualización de imagen
    ShareVerseModal.show(context, verse);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ICONO DE ACCIÓN CON FEEDBACK TÁCTIL
// ═══════════════════════════════════════════════════════════════════════════════
class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 18,
            color: const Color(0xFF8A8A8A),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ICONO DE FAVORITO CON ESTADO REACTIVO
// ═══════════════════════════════════════════════════════════════════════════════
class _FavoriteIcon extends StatefulWidget {
  final BibleVerse verse;

  const _FavoriteIcon({required this.verse});

  @override
  State<_FavoriteIcon> createState() => _FavoriteIconState();
}

class _FavoriteIconState extends State<_FavoriteIcon> {
  final FavoritesService _favoritesService = FavoritesService();

  @override
  void initState() {
    super.initState();
    _favoritesService.addListener(_onFavoritesChanged);
  }

  @override
  void dispose() {
    _favoritesService.removeListener(_onFavoritesChanged);
    super.dispose();
  }

  void _onFavoritesChanged() {
    if (mounted) setState(() {});
  }

  void _toggleFavorite() async {
    HapticFeedback.mediumImpact();
    final isFavorite = _favoritesService.isFavorite(widget.verse);
    
    await _favoritesService.toggleFavorite(widget.verse);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isFavorite ? Icons.bookmark_remove_rounded : Icons.bookmark_added_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                isFavorite ? 'Eliminado de favoritos' : '¡Guardado en favoritos!',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0D1B2A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFavorite = _favoritesService.isFavorite(widget.verse);
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _toggleFavorite,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(
            isFavorite ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
            size: 18,
            color: isFavorite ? const Color(0xFFD4A853) : const Color(0xFF8A8A8A),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ICONO DE AUDIO TTS CON ESTADO REACTIVO
// ═══════════════════════════════════════════════════════════════════════════════
class _AudioIcon extends StatefulWidget {
  final BibleVerse verse;

  const _AudioIcon({required this.verse});

  @override
  State<_AudioIcon> createState() => _AudioIconState();
}

class _AudioIconState extends State<_AudioIcon> {
  final AudioService _audioService = AudioService();
  StreamSubscription<TtsState>? _stateSubscription;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _audioService.initialize();
    _stateSubscription = _audioService.stateStream.listen((state) {
      if (mounted) {
        final isThisVersePlaying = state == TtsState.playing && 
            _audioService.currentlyPlaying == widget.verse.reference;
        setState(() => _isPlaying = isThisVersePlaying);
      }
    });
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    super.dispose();
  }

  void _toggleAudio() async {
    HapticFeedback.mediumImpact();
    
    if (_isPlaying) {
      await _audioService.stop();
    } else {
      await _audioService.playVerse(
        widget.verse.reference,
        widget.verse.verse,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_audioService.audioEnabled) {
      return const SizedBox.shrink();
    }
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _toggleAudio,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(
            _isPlaying ? Icons.stop_rounded : Icons.volume_up_rounded,
            size: 18,
            color: _isPlaying ? const Color(0xFFD4A853) : const Color(0xFF8A8A8A),
          ),
        ),
      ),
    );
  }
}
