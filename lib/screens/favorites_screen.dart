import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../data/bible_verses.dart';
import '../services/favorites_service.dart';
import '../widgets/share_verse_modal.dart';

/// ═══════════════════════════════════════════════════════════════════════════════
/// FAVORITES SCREEN - Pantalla de Versículos Favoritos
/// ═══════════════════════════════════════════════════════════════════════════════
/// 
/// Muestra la lista de versículos guardados por el usuario con diseño premium.
/// Permite eliminar, copiar y compartir cada versículo.
/// ═══════════════════════════════════════════════════════════════════════════════

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final FavoritesService _favoritesService = FavoritesService();

  // Colores del Design System
  static const Color _darkBg = Color(0xFF0A0E14);
  static const Color _goldAccent = Color(0xFFD4A853);
  static const Color _creamBg = Color(0xFFFAF8F5);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _creamBg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ═══════════════════════════════════════════════════════════════════
          // APP BAR PREMIUM
          // ═══════════════════════════════════════════════════════════════════
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            backgroundColor: _darkBg,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _darkBg,
                      const Color(0xFF1A2D42),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // Decoración de fondo
                    Positioned(
                      top: -30,
                      right: -30,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              _goldAccent.withOpacity(0.15),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Contenido
                    Positioned(
                      left: 24,
                      bottom: 24,
                      right: 24,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _goldAccent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.bookmark_rounded,
                              color: _goldAccent,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Mis Favoritos',
                            style: GoogleFonts.cinzel(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${_favoritesService.count} versículos guardados',
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              color: Colors.white60,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ═══════════════════════════════════════════════════════════════════
          // CONTENIDO
          // ═══════════════════════════════════════════════════════════════════
          if (_favoritesService.favorites.isEmpty)
            SliverFillRemaining(
              child: _buildEmptyState(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final verse = _favoritesService.favorites[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _FavoriteVerseCard(
                        verse: verse,
                        index: index,
                        onRemove: () => _removeFavorite(verse),
                        onCopy: () => _copyVerse(verse),
                        onShare: () => _shareVerse(verse),
                      ),
                    );
                  },
                  childCount: _favoritesService.favorites.length,
                ),
              ),
            ),
          
          // Espacio inferior con Safe Area
          SliverPadding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 40)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _goldAccent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bookmark_outline_rounded,
                size: 64,
                color: _goldAccent.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Sin favoritos aún',
              style: GoogleFonts.cinzel(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: _darkBg,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Los versículos que guardes aparecerán aquí.\nToca el ícono de marcador en cualquier versículo para guardarlo.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: Colors.black54,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_goldAccent, Color(0xFFE8C97A)],
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
                child: Text(
                  'Explorar Versículos',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .scale(begin: const Offset(0.95, 0.95));
  }

  void _removeFavorite(BibleVerse verse) async {
    HapticFeedback.mediumImpact();
    await _favoritesService.removeFavorite(verse);
    _showSnackBar('Eliminado de favoritos', Icons.bookmark_remove_rounded);
  }

  void _copyVerse(BibleVerse verse) {
    HapticFeedback.mediumImpact();
    final text = '"${verse.verse}" — ${verse.reference}';
    Clipboard.setData(ClipboardData(text: text));
    _showSnackBar('Versículo copiado', Icons.check_circle_rounded);
  }

  void _shareVerse(BibleVerse verse) {
    HapticFeedback.mediumImpact();
    ShareVerseModal.show(context, verse);
  }

  void _showSnackBar(String message, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(
              message,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: _darkBg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TARJETA DE VERSÍCULO FAVORITO
// ═══════════════════════════════════════════════════════════════════════════════
class _FavoriteVerseCard extends StatelessWidget {
  final BibleVerse verse;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  const _FavoriteVerseCard({
    required this.verse,
    required this.index,
    required this.onRemove,
    required this.onCopy,
    required this.onShare,
  });

  static const Color _goldAccent = Color(0xFFD4A853);
  static const Color _textDark = Color(0xFF1A1A1A);

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('${verse.reference}_${verse.verse.hashCode}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(
          Icons.delete_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0D1B2A).withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Categoría
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _goldAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  verse.category.toUpperCase(),
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _goldAccent,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Versículo
              Text(
                '"${verse.verse}"',
                style: GoogleFonts.crimsonPro(
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  fontStyle: FontStyle.italic,
                  color: _textDark,
                  height: 1.6,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Referencia y acciones
              Row(
                children: [
                  Text(
                    verse.reference,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _goldAccent,
                    ),
                  ),
                  const Spacer(),
                  _MiniActionButton(
                    icon: Icons.copy_rounded,
                    onTap: onCopy,
                  ),
                  const SizedBox(width: 8),
                  _MiniActionButton(
                    icon: Icons.share_rounded,
                    onTap: onShare,
                  ),
                  const SizedBox(width: 8),
                  _MiniActionButton(
                    icon: Icons.bookmark_remove_rounded,
                    onTap: onRemove,
                    isDestructive: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: 50 * index),
          duration: const Duration(milliseconds: 400),
        )
        .slideX(
          begin: 0.1,
          end: 0,
          delay: Duration(milliseconds: 50 * index),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
  }
}

class _MiniActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;

  const _MiniActionButton({
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDestructive 
              ? Colors.red.shade50 
              : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isDestructive 
              ? Colors.red.shade400 
              : const Color(0xFF8A8A8A),
        ),
      ),
    );
  }
}
