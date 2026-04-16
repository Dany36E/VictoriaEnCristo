/// ═══════════════════════════════════════════════════════════════════════════
/// WIDGET SETTINGS SCREEN - Configuración del Widget de Pantalla de Inicio
/// Permite personalizar plantilla, privacidad, contenido y estilo
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import '../models/widget_config.dart';
import '../services/widget_sync_service.dart';
import '../services/victory_scoring_service.dart';
import '../services/daily_verse_service.dart';
import '../services/feedback_engine.dart';
import '../theme/app_theme.dart';

class WidgetSettingsScreen extends StatefulWidget {
  const WidgetSettingsScreen({super.key});

  @override
  State<WidgetSettingsScreen> createState() => _WidgetSettingsScreenState();
}

class _WidgetSettingsScreenState extends State<WidgetSettingsScreen> {
  late WidgetConfig _config;
  late TextEditingController _titleController;
  bool _isLoading = true;
  bool _hasChanges = false;
  int _streak = 0;
  String _verseText = '';
  String _verseRef = '';

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    await WidgetSyncService.I.init();
    
    _streak = VictoryScoringService.I.getCurrentStreak();
    
    try {
      if (DailyVerseService.I.isInitialized) {
        final verse = await DailyVerseService.I.getForToday();
        _verseText = verse.verse;
        _verseRef = verse.reference;
      }
    } catch (e) {
      debugPrint('📱 [WIDGET_SETTINGS] Verse load error: $e');
    }
    if (_verseText.isEmpty) {
      _verseText = 'Todo lo puedo en Cristo que me fortalece.';
      _verseRef = 'Filipenses 4:13';
    }
    
    setState(() {
      _config = WidgetSyncService.I.currentConfig;
      _titleController = TextEditingController(text: _config.titleText);
      _isLoading = false;
    });
  }

  void _updateConfig(WidgetConfig newConfig) {
    setState(() {
      _config = newConfig;
      _hasChanges = true;
    });
  }

  Future<void> _saveConfig() async {
    FeedbackEngine.I.confirm();
    
    await WidgetSyncService.I.saveConfig(_config);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Widget actualizado'),
            ],
          ),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      setState(() => _hasChanges = false);
    }
  }

  Future<void> _addWidgetToHomeScreen() async {
    FeedbackEngine.I.tap();
    
    // Llamar con validación - retorna false si hay error de configuración
    final success = await WidgetSyncService.I.requestWidgetPin();
    
    if (!success && mounted) {
      // Mostrar mensaje de error si la solicitud falló
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text('No se pudo añadir el widget. Intenta reiniciar la app.'),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Widget')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Widget de Inicio'),
        actions: [
          if (_hasChanges)
            TextButton.icon(
              onPressed: _saveConfig,
              icon: const Icon(Icons.save),
              label: const Text('Guardar'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Preview del widget
          _buildPreviewSection(isDark),
          
          const SizedBox(height: 24),
          
          // Plantilla
          _buildSectionHeader('📐 Plantilla', isDark),
          _buildTemplateSelector(isDark),
          
          const SizedBox(height: 24),
          
          // Privacidad
          _buildSectionHeader('🔒 Privacidad', isDark),
          _buildPrivacyCard(isDark),
          
          const SizedBox(height: 24),
          
          // Título
          _buildSectionHeader('📝 Título', isDark),
          _buildTitleCard(isDark),
          
          const SizedBox(height: 24),
          
          // Estilo
          _buildSectionHeader('🎨 Estilo', isDark),
          _buildStyleSelector(isDark),
          
          const SizedBox(height: 24),
          
          // Acciones
          _buildActionsSection(isDark),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PREVIEW
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPreviewSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('👁️ Vista Previa', isDark),
        const SizedBox(height: 8),
        // Widget 2×2 (Recordatorio)
        Center(
          child: Column(
            children: [
              Text(
                'RECORDATORIO · 2×2',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white38 : Colors.black38,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              _buildWidget2x2Preview(),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Widget 4×2 (Versículo del día)
        Center(
          child: Column(
            children: [
              Text(
                'VERSÍCULO DEL DÍA · 4×2',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white38 : Colors.black38,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              _buildVerseWidgetPreview(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWidget2x2Preview() {
    final isLight = _config.theme == WidgetTheme.lightCard;
    final isDiscreet = _config.privacyMode == WidgetPrivacyMode.discreet;
    
    final bgColor = isLight ? Colors.white : const Color(0xFF1E1E2E);
    final borderColor = isLight ? const Color(0xFFE0E0E0) : const Color(0xFF3D3D5C);
    final textColor = isLight ? const Color(0xFF212121) : Colors.white;
    final subtitleColor = isLight ? const Color(0xFF757575) : const Color(0xFFB0B0B0);
    // Colores de ícono idénticos al tint de Android
    final iconColor = isDiscreet
        ? const Color(0xFF6B4EE6)  // ic_widget_discreet tint
        : const Color(0xFFFFD54F); // ic_widget_trophy tint

    final title = _config.effectiveTitle;
    String line1;
    switch (_config.template) {
      case WidgetTemplate.discreet:
        line1 = isDiscreet ? 'Respira. Sigue hoy.' : 'Tu victoria diaria te espera.';
        break;
      case WidgetTemplate.verse:
        line1 = _truncateForPreview(_verseText, 50);
        break;
      case WidgetTemplate.streak:
        line1 = _config.getStreakText(_streak);
        break;
      case WidgetTemplate.combo:
        line1 = '${_config.getStreakText(_streak)}\n${_truncateForPreview(_verseText, 35)}';
        break;
    }

    return Container(
      width: 140,
      height: 140,
      padding: const EdgeInsets.all(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isDiscreet ? Icons.today_outlined : Icons.emoji_events_outlined,
              size: 32,
              color: iconColor,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              line1,
              style: TextStyle(
                fontSize: 11,
                color: subtitleColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerseWidgetPreview() {
    final isLight = _config.theme == WidgetTheme.lightCard;
    final bgColor = isLight ? Colors.white : const Color(0xFF1E1E2E);
    final borderColor = isLight ? const Color(0xFFE0E0E0) : const Color(0xFF3D3D5C);
    final textColor = isLight ? const Color(0xFF212121) : Colors.white;
    final labelColor = isLight ? const Color(0xFF757575) : const Color(0xFFB0B0B0);
    const accentColor = Color(0xFFD4AF37);

    return Container(
      width: 280,
      padding: const EdgeInsets.all(8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'VERSÍCULO DEL DÍA',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: labelColor,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _verseText,
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'serif',
                color: textColor,
                height: 1.3,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              _verseRef,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: accentColor,
              ),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  String _truncateForPreview(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    final truncated = text.substring(0, maxLength);
    final lastSpace = truncated.lastIndexOf(' ');
    if (lastSpace > maxLength * 0.7) {
      return '${truncated.substring(0, lastSpace)}...';
    }
    return '$truncated...';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PLANTILLA
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTemplateSelector(bool isDark) {
    return _buildCard(
      isDark: isDark,
      child: Column(
        children: WidgetTemplate.values.map((template) {
          final isSelected = _config.template == template;
          return _buildRadioTile(
            title: _getTemplateName(template),
            subtitle: _getTemplateDescription(template),
            icon: _getTemplateIcon(template),
            isSelected: isSelected,
            onTap: () {
              FeedbackEngine.I.tap();
              _updateConfig(_config.copyWith(template: template));
            },
            isDark: isDark,
            isFirst: template == WidgetTemplate.values.first,
            isLast: template == WidgetTemplate.values.last,
          );
        }).toList(),
      ),
    );
  }

  String _getTemplateName(WidgetTemplate template) {
    switch (template) {
      case WidgetTemplate.discreet:
        return 'Discreto';
      case WidgetTemplate.verse:
        return 'Versículo';
      case WidgetTemplate.streak:
        return 'Racha';
      case WidgetTemplate.combo:
        return 'Combinado';
    }
  }

  String _getTemplateDescription(WidgetTemplate template) {
    switch (template) {
      case WidgetTemplate.discreet:
        return 'Solo título e ícono (máxima privacidad)';
      case WidgetTemplate.verse:
        return 'Muestra el versículo del día';
      case WidgetTemplate.streak:
        return 'Enfocado en tu progreso';
      case WidgetTemplate.combo:
        return 'Versículo + racha compacto';
    }
  }

  IconData _getTemplateIcon(WidgetTemplate template) {
    switch (template) {
      case WidgetTemplate.discreet:
        return Icons.visibility_off;
      case WidgetTemplate.verse:
        return Icons.menu_book;
      case WidgetTemplate.streak:
        return Icons.trending_up;
      case WidgetTemplate.combo:
        return Icons.dashboard;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIVACIDAD
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPrivacyCard(bool isDark) {
    final isDiscreet = _config.privacyMode == WidgetPrivacyMode.discreet;
    
    return _buildCard(
      isDark: isDark,
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Modo discreto'),
            subtitle: Text(
              isDiscreet 
                  ? 'Sin términos religiosos ni sensibles'
                  : 'Contenido cristiano visible',
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.black54,
                fontSize: 13,
              ),
            ),
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isDiscreet ? Colors.green : AppTheme.primaryColor)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isDiscreet ? Icons.shield : Icons.visibility,
                color: isDiscreet ? Colors.green : AppTheme.primaryColor,
              ),
            ),
            value: isDiscreet,
            onChanged: (value) {
              FeedbackEngine.I.tap();
              _updateConfig(_config.copyWith(
                privacyMode: value 
                    ? WidgetPrivacyMode.discreet 
                    : WidgetPrivacyMode.normal,
                titleText: value 
                    ? WidgetTitlePresets.defaultDiscreet
                    : WidgetTitlePresets.defaultNormal,
              ));
              _titleController.text = value 
                  ? WidgetTitlePresets.defaultDiscreet
                  : WidgetTitlePresets.defaultNormal;
            },
            activeColor: Colors.green,
          ),
          
          if (isDiscreet)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Nadie sabrá el propósito real de la app',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TÍTULO
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTitleCard(bool isDark) {
    final isDiscreet = _config.privacyMode == WidgetPrivacyMode.discreet;
    final titlePresets = isDiscreet 
        ? WidgetTitlePresets.discreet 
        : WidgetTitlePresets.normal;

    return _buildCard(
      isDark: isDark,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Título del widget',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'Ej: ${titlePresets.first}',
                filled: true,
                fillColor: isDark 
                    ? Colors.white.withOpacity(0.05) 
                    : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, 
                  vertical: 12,
                ),
              ),
              onChanged: (value) {
                _updateConfig(_config.copyWith(titleText: value));
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: titlePresets.map((title) {
                final isSelected = _titleController.text == title;
                return ActionChip(
                  label: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected 
                          ? Colors.white 
                          : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                  backgroundColor: isSelected 
                      ? AppTheme.primaryColor 
                      : (isDark 
                          ? Colors.white.withOpacity(0.1) 
                          : Colors.grey.shade200),
                  onPressed: () {
                    FeedbackEngine.I.tap();
                    _titleController.text = title;
                    _updateConfig(_config.copyWith(titleText: title));
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ESTILO
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStyleSelector(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildThemeOption(
            title: 'Claro',
            icon: Icons.light_mode,
            isSelected: _config.theme == WidgetTheme.lightCard,
            onTap: () {
              FeedbackEngine.I.tap();
              _updateConfig(_config.copyWith(theme: WidgetTheme.lightCard));
            },
            isDark: isDark,
            isLight: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildThemeOption(
            title: 'Oscuro',
            icon: Icons.dark_mode,
            isSelected: _config.theme == WidgetTheme.darkCard,
            onTap: () {
              FeedbackEngine.I.tap();
              _updateConfig(_config.copyWith(theme: WidgetTheme.darkCard));
            },
            isDark: isDark,
            isLight: false,
          ),
        ),
      ],
    );
  }

  Widget _buildThemeOption({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    required bool isLight,
  }) {
    final bgColor = isLight ? Colors.white : const Color(0xFF1E1E2E);
    final textColor = isLight ? Colors.black87 : Colors.white;
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected 
                ? AppTheme.primaryColor 
                : (isDark ? Colors.white24 : Colors.grey.shade300),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(icon, color: textColor, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 4),
              const Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 18),
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ACCIONES
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildActionsSection(bool isDark) {
    return Column(
      children: [
        // Botón principal: Guardar
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _hasChanges ? _saveConfig : null,
            icon: const Icon(Icons.save),
            label: const Text('Guardar Configuración'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              disabledBackgroundColor: isDark 
                  ? Colors.grey.shade800 
                  : Colors.grey.shade300,
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Botón secundario: Añadir a inicio
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _addWidgetToHomeScreen,
            icon: const Icon(Icons.add_to_home_screen),
            label: const Text('Añadir Widget a Inicio'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: BorderSide(
                color: isDark ? Colors.white24 : Colors.grey.shade400,
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Instrucciones
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark 
                ? Colors.white.withOpacity(0.05) 
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'También puedes añadir el widget desde la pantalla de inicio de tu teléfono.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildCard({required bool isDark, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark 
            ? const Color(0xFF1E1E2E) 
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
    );
  }

  Widget _buildRadioTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    required bool isFirst,
    required bool isLast,
  }) {
    return Column(
      children: [
        if (!isFirst) const Divider(height: 1),
        ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isSelected ? AppTheme.primaryColor : Colors.grey)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: isSelected ? AppTheme.primaryColor : Colors.grey,
            ),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          trailing: isSelected
              ? const Icon(Icons.check_circle, color: AppTheme.primaryColor)
              : Icon(Icons.circle_outlined, color: Colors.grey.shade400),
          onTap: onTap,
        ),
      ],
    );
  }
}
