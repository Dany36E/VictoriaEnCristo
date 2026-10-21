import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/plan.dart';
import '../models/content_enums.dart';
import 'plan_cover.dart';
import '../services/theme_service.dart';
import '../vec/vec_tema.dart';
import '../vec/vec_widgets.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// PLAN LIST TILE - Estilo YouVersion/Portada real
/// Thumbnail izquierda + título/metadata derecha + botón iniciar
/// ═══════════════════════════════════════════════════════════════════════════

class PlanListTile extends StatelessWidget {
  final Plan plan;
  final PlanProgress? progress;
  final VoidCallback onTap;
  final VoidCallback? onStartPressed;

  const PlanListTile({
    super.key,
    required this.plan,
    this.progress,
    required this.onTap,
    this.onStartPressed,
  });

  bool get _isStarted => progress != null && progress!.completedDays.isNotEmpty;
  bool get _isCompleted => progress != null && 
      progress!.progressPercentage(plan.durationDays) >= 1.0;
  
  double get _progressPercent => 
      progress?.progressPercentage(plan.durationDays) ?? 0.0;

  // Tema «papel recortado»: tarjeta de papel con colores del kit.
  static bool get _papel => ThemeService().currentTheme.isPaper;
  static Color get _oro => _papel ? VecColores.terracota : AppDesignSystem.gold;
  static Color get _texto => _papel ? VecColores.tinta : AppDesignSystem.pureWhite;
  static Color get _gris => _papel ? VecColores.gris : AppDesignSystem.coolGray;
  static Color get _sobreOro => _papel ? VecColores.papel : AppDesignSystem.midnight;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _papel ? VecColores.papel : AppDesignSystem.midnightLight,
      elevation: _papel ? 0 : 2,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: _papel ? 10 : 6),
      shape: _papel ? BordeConSombraVec.tarjeta() : RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _isCompleted 
              ? AppDesignSystem.gold.withValues(alpha: 0.3) 
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // ═══════════════════════════════════════════════════════════
              // THUMBNAIL (cover real)
              // ═══════════════════════════════════════════════════════════
              _buildThumbnail(),
              
              const SizedBox(width: 14),
              
              // ═══════════════════════════════════════════════════════════
              // TEXTOS (título + metadata)
              // ═══════════════════════════════════════════════════════════
              Expanded(
                child: _buildTextContent(context),
              ),
              
              const SizedBox(width: 8),
              
              // ═══════════════════════════════════════════════════════════
              // BOTÓN O INDICADOR
              // ═══════════════════════════════════════════════════════════
              _buildActionButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    return Stack(
      children: [
        // Cover image
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 80,
            height: 80,
            child: _buildCoverImage(),
          ),
        ),
        
        // Completed badge
        if (_isCompleted)
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: AppDesignSystem.gold,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                size: 12,
                color: AppDesignSystem.midnight,
              ),
            ),
          ),
        
        // Progress indicator (overlay en bottom)
        if (_isStarted && !_isCompleted)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 4,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(10),
                ),
                color: Colors.black54,
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _progressPercent,
                child: Container(
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(10),
                    ),
                    color: AppDesignSystem.gold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCoverImage() {
    // Usar el widget PlanCover premium
    return PlanCover.thumbnail(
      plan: plan,
      size: 80,
      borderRadius: BorderRadius.circular(10),
    );
  }

  Widget _buildTextContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Duración + categoría
        Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 12,
              color: _oro,
            ),
            const SizedBox(width: 4),
            Text(
              '${plan.durationDays} días',
              style: AppDesignSystem.labelSmall(context, color: _oro),
            ),
            const SizedBox(width: 8),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: _gris.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                plan.metadata.stage.displayName,
                style: AppDesignSystem.labelSmall(context, color: _gris),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 6),
        
        // Título
        Text(
          plan.title,
          style: AppDesignSystem.labelLarge(context, color: _texto).copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        
        const SizedBox(height: 4),
        
        // Subtítulo
        Text(
          plan.subtitle,
          style: AppDesignSystem.labelSmall(context, color: _gris),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        
        // Progress text si está iniciado
        if (_isStarted && !_isCompleted) ...[
          const SizedBox(height: 4),
          Text(
            '${(_progressPercent * 100).toInt()}% completado',
            style: AppDesignSystem.labelSmall(context, color: _oro).copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButton(BuildContext context) {
    if (_isCompleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _oro.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'Listo',
          style: AppDesignSystem.labelSmall(context, color: _oro),
        ),
      );
    }
    
    if (_isStarted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _oro,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'Continuar',
          style: AppDesignSystem.labelSmall(context, color: _sobreOro).copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    
    // Not started
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: _oro.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        'Iniciar',
        style: AppDesignSystem.labelSmall(context, color: _oro),
      ),
    );
  }
}
