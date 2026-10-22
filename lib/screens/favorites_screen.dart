import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../data/bible_verses.dart';
import '../services/favorites_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_data.dart';
import '../theme/contraste.dart';
import '../vec/vec_widgets.dart';
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
    final t = AppThemeData.of(context);
    return Scaffold(
      backgroundColor: t.pageBg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ═══════════════════════════════════════════════════════════════════
          // APP BAR PREMIUM
          // ═══════════════════════════════════════════════════════════════════
          SliverAppBar(
            // Alto suficiente para que el ícono no quede bajo la flecha de
            // regreso de la barra (56 px).
            expandedHeight: 220,
            floating: false,
            pinned: true,
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_rounded, color: t.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: Stack(
              fit: StackFit.expand,
              children: [
                // Tema papel: la barra fija también es hoja con textura.
                const FondoPapel(child: SizedBox.expand()),
                FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: null,
                ),
                child: Stack(
                  children: [
                    // Decoración de fondo
                    
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
                              color: t.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.bookmark_rounded,
                              color: t.accent,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Mis Favoritos',
                            style: AppFonts.cinzel(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: t.textPrimary,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _favoritesService.count == 1
                                ? '1 versículo guardado'
                                : '${_favoritesService.count} versículos guardados',
                            style: AppFonts.manrope(
                              fontSize: 14,
                              color: t.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
              ],
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
    final t = AppThemeData.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: t.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bookmark_outline_rounded,
                size: 64,
                color: t.accent.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Sin favoritos aún',
              style: AppFonts.cinzel(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: t.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Los versículos que guardes aparecerán aquí.\nToca el ícono de marcador en cualquier versículo para guardarlo.',
              textAlign: TextAlign.center,
              style: AppFonts.manrope(
                fontSize: 14,
                color: t.textSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  // Fondo sólido: con el degradado a accentSoft (casi
                  // transparente) el texto se perdía en la mitad derecha.
                  color: t.accent,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: t.accent.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Text(
                  'Explorar Versículos',
                  style: AppFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color:
                        contrasteWcag(Colors.white, t.accent) >=
                            contrasteWcag(AppDesignSystem.midnightDeep, t.accent)
                        ? Colors.white
                        : AppDesignSystem.midnightDeep,
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
              style: AppFonts.manrope(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: null,
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

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
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
          color: t.cardBg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0D1B2A).withValues(alpha: 0.04),
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
                  color: t.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  verse.category.toUpperCase(),
                  style: AppFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: t.accent,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Versículo
              Text(
                '"${verse.verse}"',
                style: AppFonts.crimsonPro(
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  fontStyle: FontStyle.italic,
                  color: t.textPrimary,
                  height: 1.6,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Referencia y acciones
              Row(
                children: [
                  Text(
                    verse.reference,
                    style: AppFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: t.accent,
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
    final t = AppThemeData.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDestructive 
              ? Colors.red.shade50 
              : t.inputBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isDestructive 
              ? Colors.red.shade400 
              : t.textSecondary,
        ),
      ),
    );
  }
}
