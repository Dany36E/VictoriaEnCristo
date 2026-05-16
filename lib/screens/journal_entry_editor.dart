import 'package:flutter/material.dart';
import '../data/prayer_verses.dart';
import '../models/prayer_map.dart';
import '../services/journal_service.dart';
import '../services/feedback_engine.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_data.dart';

/// Editor del "Mapa de Oración" (antes `JournalEntryEditor`).
///
/// Guía al usuario por una plantilla de oración con secciones fijas inspirada
/// en el diario de oración impreso aportado por el usuario. El contenido se
/// serializa como JSON (con un marcador) dentro del campo `content` de
/// `JournalEntry`, manteniendo el modelo del servicio existente.
class JournalEntryEditor extends StatefulWidget {
  final Function(JournalEntry) onSave;
  final JournalEntry? existingEntry;

  /// Compat: el editor antiguo aceptaba un prompt inicial. Se ignora porque
  /// el flujo nuevo usa secciones guiadas. Se mantiene la firma para no
  /// romper los llamadores existentes (`journal_screen.dart`).
  final String? initialPrompt;

  const JournalEntryEditor({
    super.key,
    required this.onSave,
    this.existingEntry,
    this.initialPrompt,
  });

  @override
  State<JournalEntryEditor> createState() => _JournalEntryEditorState();
}

class _JournalEntryEditorState extends State<JournalEntryEditor> {
  final Map<String, TextEditingController> _controllers = {
    for (final s in PrayerMapData.sections) s.key: TextEditingController(),
  };
  late final PrayerVerse _verse;

  @override
  void initState() {
    super.initState();
    _verse = PrayerVerses.forToday();

    // Si estamos editando, intentar decodificar PrayerMapData del content.
    final existing = widget.existingEntry;
    if (existing != null) {
      final decoded = PrayerMapData.tryDecode(existing.content);
      if (decoded != null) {
        for (final s in PrayerMapData.sections) {
          _controllers[s.key]!.text = decoded.getField(s.key);
        }
      } else {
        // Entrada antigua: vuelca todo el texto en "situacion".
        _controllers['situacion']!.text = existing.content;
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final date = widget.existingEntry?.date ?? DateTime.now();

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        title: Text(
          widget.existingEntry != null
              ? 'Editar oración'
              : 'Nueva oración',
        ),
        actions: [
          TextButton.icon(
            onPressed: _saveEntry,
            icon: Icon(Icons.check,
                color: Theme.of(context).appBarTheme.foregroundColor),
            label: Text(
              'Guardar',
              style: TextStyle(
                color: Theme.of(context).appBarTheme.foregroundColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(t, date),
              const SizedBox(height: 20),
              ...PrayerMapData.sections.map(
                (s) => Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: _buildSectionField(t, s),
                ),
              ),
              _buildClosing(t),
              const SizedBox(height: 20),
              _buildVerseCard(t),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppThemeData t, DateTime date) {
    final months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    final formatted = '${date.day} de ${months[date.month - 1]} de ${date.year}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            t.accent.withOpacity(0.18),
            t.accent.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.accent.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today_outlined, color: t.accent, size: 20),
          const SizedBox(width: 10),
          Text(
            'Hoy, $formatted',
            style: TextStyle(
              color: t.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionField(AppThemeData t, PrayerMapSection s) {
    final controller = _controllers[s.key]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: t.textPrimary,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.accent.withOpacity(0.12)),
          ),
          child: TextField(
            controller: controller,
            minLines: s.minLines,
            maxLines: s.minLines + 4,
            decoration: InputDecoration(
              hintText: s.hint,
              hintStyle: TextStyle(
                color: t.textSecondary.withOpacity(0.6),
                fontSize: 13,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(14),
            ),
            style: TextStyle(
              color: t.textPrimary,
              fontSize: 14,
              height: 1.5,
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
        ),
      ],
    );
  }

  Widget _buildClosing(AppThemeData t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.accent.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.volunteer_activism, color: t.accent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Amén. Gracias, Padre, por oír mis oraciones.',
              style: TextStyle(
                color: t.textPrimary,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerseCard(AppThemeData t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppDesignSystem.gold.withOpacity(0.16),
            AppDesignSystem.gold.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppDesignSystem.gold.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.format_quote_rounded,
                color: AppDesignSystem.gold,
                size: 20,
              ),
              SizedBox(width: 6),
              Text(
                'Versículo de hoy',
                style: TextStyle(
                  color: AppDesignSystem.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _verse.text,
            style: TextStyle(
              color: t.textPrimary,
              fontSize: 14,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '— ${_verse.reference}',
            style: TextStyle(
              color: t.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _saveEntry() {
    final data = PrayerMapData(
      saludo: _controllers['saludo']!.text.trim(),
      gracias: _controllers['gracias']!.text.trim(),
      personas: _controllers['personas']!.text.trim(),
      preocupaciones: _controllers['preocupaciones']!.text.trim(),
      situacion: _controllers['situacion']!.text.trim(),
      necesidades: _controllers['necesidades']!.text.trim(),
      corazon: _controllers['corazon']!.text.trim(),
      verseReference: _verse.reference,
    );

    if (data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escribe en al menos una sección antes de guardar'),
        ),
      );
      return;
    }

    FeedbackEngine.I.confirm();

    final existing = widget.existingEntry;
    final entry = JournalEntry(
      id: existing?.id ?? JournalService().generateId(),
      date: existing?.date ?? DateTime.now(),
      content: data.encode(),
      // Una oración bien hecha siempre es gratitud frente a Dios: por defecto
      // marcamos el ánimo como "grateful" para que las stats sigan siendo
      // útiles. Si la entrada ya existía, preservamos su mood.
      mood: existing?.mood ?? 'grateful',
      triggers: existing?.triggers ?? const [],
      hadVictory: existing?.hadVictory ?? true,
      verseOfDay: _verse.reference,
    );

    widget.onSave(entry);
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Oración guardada ✓'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }
}
