import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../data/bible_verses.dart';
import '../models/bible/bible_version.dart';
import '../services/bible/bible_download_service.dart';
import '../services/bible/bible_user_data_service.dart';
import '../services/favorites_service.dart';
import '../services/user_scoped_services.dart';
import 'bible/bible_home_screen.dart';
import 'bible/bible_reader_screen.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_data.dart';
import '../theme/contraste.dart';
import '../vec/vec_widgets.dart';
import '../widgets/share_verse_modal.dart';

/// ═══════════════════════════════════════════════════════════════════════════════
/// FAVORITES SCREEN - Pantalla de Versículos Favoritos
/// ═══════════════════════════════════════════════════════════════════════════════
/// 
/// Muestra los versículos guardados del usuario: es la misma lista que
/// «Guardados» de la Biblia (FavoritesService la unifica y migra los
/// favoritos antiguos). Tocar uno abre la Biblia en ese versículo; también se
/// puede quitar, copiar y compartir.
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
    // Carga los guardados de la Biblia (y migra los favoritos antiguos).
    UserScopedServices.I.ensureBible().then((_) {
      if (mounted) setState(() {});
    });
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
    final entries = _favoritesService.entries;
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
                // La barra fija también es hoja con textura.
                const FondoPapel(child: SizedBox.expand()),
                FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
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
                            entries.length == 1
                                ? '1 versículo guardado'
                                : '${entries.length} versículos guardados',
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
          if (entries.isEmpty)
            SliverFillRemaining(
              child: _buildEmptyState(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final entry = entries[index];
                    final verse = entry.verse;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _FavoriteVerseCard(
                        entry: entry,
                        index: index,
                        onOpen: entry.saved == null
                            ? null
                            : () => _openInBible(entry),
                        onRemove: () => _removeFavorite(verse),
                        onCopy: () => _copyVerse(verse),
                        onShare: () => _shareVerse(verse),
                      ),
                    );
                  },
                  childCount: entries.length,
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
              'Aquí verás los versículos que guardes.\nEn la Biblia, toca un versículo y elige «Guardar»; también puedes guardarlos desde Versículos y el Frasco de versículos.',
              textAlign: TextAlign.center,
              style: AppFonts.manrope(
                fontSize: 14,
                color: t.textSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const BibleHomeScreen()),
              ),
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
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
                  'Abrir la Biblia',
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

  void _openInBible(FavoriteEntry entry) {
    final s = entry.saved!;
    final preferred = BibleUserDataService.I.preferredVersionNotifier.value;
    final v = BibleVersion.fromId(s.version);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BibleReaderScreen(
          bookNumber: s.bookNumber,
          bookName: s.bookName,
          chapter: s.chapter,
          version: BibleDownloadService.I.isAvailable(v) ? v : preferred,
          initialVerse: s.verse,
        ),
      ),
    );
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
  final FavoriteEntry entry;
  final int index;
  final VoidCallback? onOpen;
  final VoidCallback onRemove;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  const _FavoriteVerseCard({
    required this.entry,
    required this.index,
    required this.onOpen,
    required this.onRemove,
    required this.onCopy,
    required this.onShare,
  });

  BibleVerse get verse => entry.verse;

  /// Etiqueta superior: la versión (RVR1960, NVI…) o la categoría antigua.
  String get _label {
    final saved = entry.saved;
    if (saved != null) {
      return BibleVersion.fromId(saved.version).shareAbbreviation;
    }
    return verse.category.toUpperCase();
  }

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
      child: Semantics(
        button: onOpen != null,
        hint: onOpen != null ? 'Abrir en la Biblia' : null,
        child: GestureDetector(
        onTap: onOpen,
        behavior: HitTestBehavior.opaque,
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
                  _label,
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
                  Expanded(
                    child: Text(
                      verse.reference,
                      style: AppFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: t.accent,
                      ),
                    ),
                  ),
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
