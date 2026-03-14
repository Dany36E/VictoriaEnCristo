import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/prayers.dart';
import '../services/feedback_engine.dart';
import '../services/personalization_engine.dart';
import '../services/content_repository.dart';
import '../models/content_item.dart';
import '../models/content_enums.dart';

class PrayersScreen extends StatelessWidget {
  const PrayersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Obtener oraciones personalizadas
    final engine = PersonalizationEngine.I;
    final recommendedPrayers = ContentRepository.I.isInitialized 
        ? engine.getRecommendedPrayers(limit: 3)
        : <ScoredItem<PrayerItem>>[];
    final hasPersonalization = recommendedPrayers.isNotEmpty;
    final primaryGiant = engine.primaryGiant;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Oraciones'),
      ),
      body: Builder(
        builder: (context) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ═══════════════════════════════════════════════════════════════
              // SECCIÓN PERSONALIZADA (si aplica)
              // ═══════════════════════════════════════════════════════════════
              if (hasPersonalization) ...[
                _buildPersonalizedSection(
                  context,
                  '⭐ Para Ti',
                  primaryGiant != null 
                      ? 'Enfoque: ${primaryGiant.displayName}'
                      : 'Recomendadas para tu batalla',
                  recommendedPrayers,
                  const Color(0xFFD4AF37), // Gold
                ),
                const SizedBox(height: 24),
              ],
              
              // ═══════════════════════════════════════════════════════════════
              // SECCIONES ORIGINALES
              // ═══════════════════════════════════════════════════════════════
              _buildSection(
                context,
                '🆘 Oraciones de Emergencia',
                'Para momentos de tentación',
                Prayers.emergencyPrayers,
                const Color(0xFFE74C3C),
              ),
              const SizedBox(height: 24),
              _buildSection(
                context,
                '🌅 Oraciones de la Mañana',
                'Comienza el día con Dios',
                Prayers.morningPrayers,
                const Color(0xFFF39C12),
              ),
              const SizedBox(height: 24),
              _buildSection(
                context,
                '🌙 Oraciones de la Noche',
                'Termina el día en paz',
                Prayers.nightPrayers,
                const Color(0xFF9B59B6),
              ),
              const SizedBox(height: 24),
              _buildSection(
                context,
                '💪 Oraciones por Fortaleza',
                'Cuando necesitas fuerzas',
                Prayers.strengthPrayers,
                const Color(0xFF27AE60),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // SECCIÓN PERSONALIZADA CON RAZÓN DE RECOMENDACIÓN
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildPersonalizedSection(
    BuildContext context,
    String title,
    String subtitle,
    List<ScoredItem<PrayerItem>> prayers,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        ...prayers.map((scored) => _buildPersonalizedPrayerCard(
          context, 
          scored.item, 
          scored.reason,
          color,
        )),
      ],
    );
  }
  
  Widget _buildPersonalizedPrayerCard(
    BuildContext context, 
    PrayerItem prayer, 
    String reason,
    Color color,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withOpacity(0.3), width: 1),
      ),
      child: InkWell(
        onTap: () {
          FeedbackEngine.I.tap();
          // Convertir a Prayer legacy para el modal
          final legacyPrayer = Prayer(
            title: prayer.title,
            content: prayer.body,
            category: 'personalizado',
            durationMinutes: prayer.durationMinutes ?? 3,
          );
          _openPrayerDetail(context, legacyPrayer, color);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Razón de recomendación
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  reason,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.favorite,
                      color: color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          prayer.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          '${prayer.durationMinutes ?? 3} min de lectura',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: color.withOpacity(0.5),
                    size: 16,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    String subtitle,
    List<Prayer> prayers,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        ...prayers.map((prayer) => _buildPrayerCard(context, prayer, color)),
      ],
    );
  }

  Widget _buildPrayerCard(BuildContext context, Prayer prayer, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          FeedbackEngine.I.tap(); // Tap en oración para abrir
          _openPrayerDetail(context, prayer, color);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.favorite,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prayer.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${prayer.durationMinutes} minutos',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: color,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openPrayerDetail(BuildContext context, Prayer prayer, Color color) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PrayerDetailScreen(prayer: prayer, color: color),
      ),
    );
  }
}

class PrayerDetailScreen extends StatelessWidget {
  final Prayer prayer;
  final Color color;

  const PrayerDetailScreen({
    super.key,
    required this.prayer,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Oración'),
        backgroundColor: color,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.favorite,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    prayer.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '⏱️ ${prayer.durationMinutes} minutos',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Prayer content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text(
                    'Ora con fe y convicción:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      prayer.content,
                      style: const TextStyle(
                        fontSize: 18,
                        height: 1.8,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('¡Oración completada! Que Dios te bendiga 🙏'),
                            backgroundColor: AppTheme.successColor,
                          ),
                        );
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Terminé de Orar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  // Safe Area bottom padding
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
