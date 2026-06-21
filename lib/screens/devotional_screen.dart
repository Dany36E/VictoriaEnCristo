import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/devotional/faith_checkbook_entry.dart';
import '../services/audio_engine.dart';
import '../services/daily_practice_service.dart';
import '../services/devotional/faith_checkbook_repository.dart';
import '../services/feedback_engine.dart';
import '../services/notification_service.dart';
import '../services/user_pref_cloud_sync_service.dart';
import '../services/bible/bible_user_data_service.dart';
import '../theme/bible_reader_theme.dart';
import '../utils/bible_navigation_helper.dart';
import '../widgets/bible/reader/reader_typography_panel.dart';
import '../widgets/devotional/devotional_reminder_sheet.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// DEVOTIONAL SCREEN — "La Chequera del Banco de la Fe" (Charles H. Spurgeon)
///
/// Único devocional de la app. Lectura diaria por fecha del calendario, con la
/// misma experiencia de lectura de "La Biblia": 9 temas de color y tamaño de
/// letra ajustable (compartidos vía BibleUserDataService).
///
/// Contenido reproducido verbatim desde Gospel Translations (Traducciones
/// Evangelio), traducción al español por Allan Aviles, Dominio Público.
/// ═══════════════════════════════════════════════════════════════════════════
class DevotionalScreen extends StatefulWidget {
  const DevotionalScreen({super.key});

  @override
  State<DevotionalScreen> createState() => _DevotionalScreenState();
}

class _DevotionalScreenState extends State<DevotionalScreen> {
  static const String _notePrefix = 'devotional_reflection_';

  FaithCheckbookEntry? _entry;
  bool _loading = true;
  bool _showTypography = false;
  bool _completed = false;

  SharedPreferences? _prefs;
  final TextEditingController _noteCtrl = TextEditingController();
  String _savedNote = '';

  final ScrollController _scrollCtl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AudioEngine.I.switchBgmContext(BgmContext.prayer);
      _bootstrap();
    });
  }

  @override
  void dispose() {
    _persistNoteIfChanged();
    _noteCtrl.dispose();
    _scrollCtl.dispose();
    AudioEngine.I.switchBgmContext(BgmContext.home);
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await FaithCheckbookRepository.I.load();
    _prefs = await SharedPreferences.getInstance();
    final entry = FaithCheckbookRepository.I.entryForToday();
    if (!mounted) return;
    setState(() {
      _entry = entry;
      _loading = false;
    });
    if (entry != null) _loadNoteFor(entry);
  }

  void _loadNoteFor(FaithCheckbookEntry entry) {
    final note = _prefs?.getString('$_notePrefix${entry.id}') ?? '';
    _savedNote = note;
    _noteCtrl.text = note;
  }

  /// Guarda la nota del devocional actual si cambió (local + sync a la nube).
  void _persistNoteIfChanged() {
    final entry = _entry;
    if (entry == null || _prefs == null) return;
    final text = _noteCtrl.text.trim();
    if (text == _savedNote) return;
    final key = '$_notePrefix${entry.id}';
    if (text.isEmpty) {
      _prefs!.remove(key);
    } else {
      _prefs!.setString(key, text);
    }
    _savedNote = text;
    UserPrefCloudSyncService.I.markDirty();
  }

  Future<void> _saveNote() async {
    FocusScope.of(context).unfocus();
    _persistNoteIfChanged();
    FeedbackEngine.I.confirm();
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reflexión guardada'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _openPassage(FaithCheckbookEntry entry) {
    FeedbackEngine.I.tap();
    // El parser de la app usa "Salmos" (plural); La Chequera cita "Salmo".
    final ref = entry.verseReference.replaceFirst(
      RegExp(r'^Salmo\b'),
      'Salmos',
    );
    BibleNavigationHelper.navigateToSpanishRef(context, ref);
  }

  void _shareEntry(FaithCheckbookEntry entry) {
    FeedbackEngine.I.tap();
    final text =
        '«${entry.verse}»\n— ${entry.verseReference}\n\n'
        'La Chequera del Banco de la Fe · Charles H. Spurgeon';
    Share.share(text);
  }

  void _goToEntry(FaithCheckbookEntry? entry) {
    if (entry == null) return;
    FeedbackEngine.I.tap();
    _persistNoteIfChanged();
    setState(() => _entry = entry);
    _loadNoteFor(entry);
    if (_scrollCtl.hasClients) {
      _scrollCtl.jumpTo(0);
    }
  }

  void _goToday() {
    final today = FaithCheckbookRepository.I.entryForToday();
    _goToEntry(today);
  }

  Future<void> _markDone() async {
    if (_completed) return;
    await DailyPracticeService.I.mark(DailyPractice.devotional);
    FeedbackEngine.I.confirm();
    if (mounted) setState(() => _completed = true);
    await _maybeOfferReminder();
  }

  /// Tras leer el primer devocional, sugiere activar un recordatorio diario a
  /// la hora actual. Se muestra una sola vez (y nunca si ya hay recordatorio).
  Future<void> _maybeOfferReminder() async {
    final svc = NotificationService();
    if (svc.devotionalReminderPromptSeen || svc.devotionalReminderEnabled) {
      return;
    }
    await svc.markDevotionalReminderPromptSeen();
    if (!mounted) return;
    final now = TimeOfDay.now();
    await showDevotionalReminderSuggestion(
      context,
      palette: _sheetPalette(_currentTheme()),
      suggestedTime: now,
    );
  }

  BibleReaderThemeData _currentTheme() {
    final themeId = BibleReaderThemeData.migrateId(
      BibleUserDataService.I.readerThemeNotifier.value,
    );
    return BibleReaderThemeData.fromId(themeId);
  }

  DevotionalSheetPalette _sheetPalette(BibleReaderThemeData t) {
    return DevotionalSheetPalette(
      background: t.background,
      surface: t.surface,
      border: t.textSecondary.withValues(alpha: 0.2),
      accent: t.accent,
      textPrimary: t.textPrimary,
      textSecondary: t.textSecondary,
      isDark: t.isDark,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        BibleUserDataService.I.readerThemeNotifier,
        BibleUserDataService.I.fontSizeNotifier,
      ]),
      builder: (context, _) {
        final themeId = BibleReaderThemeData.migrateId(
          BibleUserDataService.I.readerThemeNotifier.value,
        );
        final t = BibleReaderThemeData.fromId(themeId);
        final fontSize = BibleUserDataService.I.fontSizeNotifier.value;

        return Scaffold(
          backgroundColor: t.background,
          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    _toolbar(t),
                    Expanded(
                      child: _loading || _entry == null
                          ? Center(
                              child: CircularProgressIndicator(color: t.accent),
                            )
                          : _content(t, fontSize),
                    ),
                  ],
                ),
                if (_showTypography)
                  ReaderTypographyPanel(
                    theme: t,
                    onClose: () => setState(() => _showTypography = false),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────── TOOLBAR ───────────────────────────

  Widget _toolbar(BibleReaderThemeData t) {
    final entry = _entry;
    final isToday = entry != null && FaithCheckbookRepository.I.isToday(entry);
    return Container(
      height: BibleReaderThemeData.toolbarHeight,
      color: t.toolbarBg,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: t.textPrimary, size: 18),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Volver',
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Devocional',
                  style: GoogleFonts.cinzel(
                    color: t.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  entry?.dateLabel ?? '',
                  style: GoogleFonts.manrope(
                    color: t.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (!isToday && entry != null)
            IconButton(
              icon: Icon(Icons.today_rounded, color: t.textSecondary, size: 20),
              tooltip: 'Ir a hoy',
              onPressed: _goToday,
            ),
          IconButton(
            icon: Icon(Icons.text_fields_rounded, color: t.textPrimary, size: 20),
            tooltip: 'Tipografía y tema',
            onPressed: () => setState(() => _showTypography = !_showTypography),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── CONTENIDO ───────────────────────────

  Widget _content(BibleReaderThemeData t, double fontSize) {
    final entry = _entry!;
    final isToday = FaithCheckbookRepository.I.isToday(entry);
    return ListView(
      controller: _scrollCtl,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      children: [
        // ── Encabezado de fecha ──
        Row(
          children: [
            Text(
              entry.dateLabel,
              style: GoogleFonts.cinzel(
                color: t.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 10),
            if (isToday)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: t.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: t.accent.withValues(alpha: 0.4)),
                ),
                child: Text(
                  'HOY',
                  style: GoogleFonts.manrope(
                    color: t.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),

        // ── Versículo-promesa ──
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(BibleReaderThemeData.radiusL),
            border: Border.all(color: t.accent.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.format_quote_rounded, color: t.accent, size: 22),
              const SizedBox(height: 8),
              SelectableText(
                entry.verse,
                style: GoogleFonts.lora(
                  color: t.textPrimary,
                  fontSize: fontSize + 1,
                  fontStyle: FontStyle.italic,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '— ${entry.verseReference}',
                style: GoogleFonts.manrope(
                  color: t.accent,
                  fontSize: fontSize - 5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Divider(color: t.textSecondary.withValues(alpha: 0.15), height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _verseAction(
                      t,
                      icon: Icons.menu_book_rounded,
                      label: 'Leer el pasaje',
                      onTap: () => _openPassage(entry),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 22,
                    color: t.textSecondary.withValues(alpha: 0.15),
                  ),
                  Expanded(
                    child: _verseAction(
                      t,
                      icon: Icons.ios_share_rounded,
                      label: 'Compartir',
                      onTap: () => _shareEntry(entry),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // ── Meditación ──
        ...entry.meditationParagraphs.map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SelectableText(
              p,
              style: GoogleFonts.lora(
                color: t.textPrimary,
                fontSize: fontSize,
                height: 1.75,
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ── Mi reflexión ──
        _reflectionSection(t, fontSize),

        const SizedBox(height: 12),

        // ── Botón "Terminé" (solo para la lectura de hoy) ──
        if (isToday) ...[
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _completed ? null : _markDone,
              icon: Icon(
                _completed
                    ? Icons.check_circle_rounded
                    : Icons.task_alt_rounded,
              ),
              label: Text(
                _completed ? 'Devocional completado' : 'Terminé',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _completed ? const Color(0xFF2E7D32) : t.accent,
                foregroundColor: t.isDark ? Colors.black : Colors.white,
                disabledBackgroundColor: const Color(0xFF2E7D32),
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(BibleReaderThemeData.radiusM),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // ── Navegación día anterior / siguiente ──
        Row(
          children: [
            Expanded(
              child: _navButton(
                t,
                icon: Icons.chevron_left_rounded,
                label: 'Día anterior',
                onTap: () =>
                    _goToEntry(FaithCheckbookRepository.I.previous(entry)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _navButton(
                t,
                icon: Icons.chevron_right_rounded,
                label: 'Día siguiente',
                trailing: true,
                onTap: () =>
                    _goToEntry(FaithCheckbookRepository.I.next(entry)),
              ),
            ),
          ],
        ),

        const SizedBox(height: 28),
        Divider(color: t.textSecondary.withValues(alpha: 0.2)),
        const SizedBox(height: 12),

        // ── Atribución (requerida por la licencia de Gospel Translations) ──
        Text(
          '«La Chequera del Banco de la Fe», por Charles H. Spurgeon.\n'
          'Traducción: Allan Aviles · Gospel Translations (Dominio Público).\n'
          'Texto bíblico: Reina-Valera.',
          style: GoogleFonts.manrope(
            color: t.textSecondary,
            fontSize: 11,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _navButton(
    BibleReaderThemeData t, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool trailing = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(BibleReaderThemeData.radiusM),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(BibleReaderThemeData.radiusM),
          border: Border.all(color: t.textSecondary.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!trailing) Icon(icon, color: t.accent, size: 20),
            if (!trailing) const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.manrope(
                color: t.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (trailing) const SizedBox(width: 4),
            if (trailing) Icon(icon, color: t.accent, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _verseAction(
    BibleReaderThemeData t, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(BibleReaderThemeData.radiusS),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: t.accent, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.manrope(
                color: t.accent,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reflectionSection(BibleReaderThemeData t, double fontSize) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(BibleReaderThemeData.radiusL),
        border: Border.all(color: t.textSecondary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_note_rounded, color: t.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                'Mi reflexión',
                style: GoogleFonts.cinzel(
                  color: t.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _noteCtrl,
            minLines: 3,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.lora(
              color: t.textPrimary,
              fontSize: fontSize - 1,
              height: 1.6,
            ),
            decoration: InputDecoration(
              hintText: '¿Qué te habló Dios hoy? Escribe tu reflexión o una '
                  'oración…',
              hintStyle: GoogleFonts.lora(
                color: t.textSecondary,
                fontSize: fontSize - 2,
                height: 1.5,
              ),
              filled: true,
              fillColor: t.background.withValues(alpha: 0.5),
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(BibleReaderThemeData.radiusM),
                borderSide: BorderSide(
                  color: t.textSecondary.withValues(alpha: 0.2),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(BibleReaderThemeData.radiusM),
                borderSide: BorderSide(
                  color: t.textSecondary.withValues(alpha: 0.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(BibleReaderThemeData.radiusM),
                borderSide: BorderSide(color: t.accent),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed:
                  _noteCtrl.text.trim() == _savedNote ? null : _saveNote,
              icon: Icon(
                _noteCtrl.text.trim() == _savedNote
                    ? Icons.check_circle_rounded
                    : Icons.save_outlined,
                size: 18,
              ),
              label: Text(
                _noteCtrl.text.trim() == _savedNote ? 'Guardada' : 'Guardar',
              ),
              style: TextButton.styleFrom(foregroundColor: t.accent),
            ),
          ),
        ],
      ),
    );
  }
}
