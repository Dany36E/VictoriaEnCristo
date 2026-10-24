import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_fonts.dart';
import '../../models/bible/chapter_study_note.dart';
import '../../services/bible/chapter_note_service.dart';
import '../../services/bible/notas_sync.dart';
import '../../theme/bible_reader_theme.dart';
import '../../services/bible/bible_user_data_service.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// CHAPTER NOTE EDITOR — Editor de notas de capítulo
///
/// Pantalla completa con título (Cinzel), contenido (serif multiline),
/// selector de color, tags y formato básico.
///
/// Autoguardado: cada cambio se guarda en el teléfono a los pocos instantes,
/// y también al volver atrás (flecha, gesto o botón del sistema). Nunca se
/// pierde lo escrito, con o sin conexión.
/// ═══════════════════════════════════════════════════════════════════════════
class ChapterNoteEditorScreen extends StatefulWidget {
  final int bookNumber;
  final String bookName;
  final int chapter;
  final String versionId;
  final ChapterStudyNote? existingNote;

  const ChapterNoteEditorScreen({
    super.key,
    required this.bookNumber,
    required this.bookName,
    required this.chapter,
    required this.versionId,
    this.existingNote,
  });

  @override
  State<ChapterNoteEditorScreen> createState() =>
      _ChapterNoteEditorScreenState();
}

class _ChapterNoteEditorScreenState extends State<ChapterNoteEditorScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final TextEditingController _tagController;
  late List<String> _tags;
  late String _selectedColor;
  bool _hasChanges = false;

  /// Id de la nota en esta sesión. Se fija en el primer guardado para que
  /// los autoguardados sigan escribiendo el MISMO documento.
  String? _noteId;
  Timer? _autosave;
  DateTime? _guardadaEn;
  int _otrasNotasDelCapitulo = 0;

  static const _noteColors = [
    'D4A853', // gold
    'FF6B6B', // red
    '4ECDC4', // teal
    '45B7D1', // blue
    'A78BFA', // purple
    'F472B6', // pink
  ];

  @override
  void initState() {
    super.initState();
    final note = widget.existingNote;
    _titleController = TextEditingController(text: note?.title ?? '');
    _contentController = TextEditingController(text: note?.content ?? '');
    _tagController = TextEditingController();
    _tags = List.from(note?.tags ?? []);
    _selectedColor = note?.colorHex ?? 'D4A853';
    _noteId = note?.id;
    _otrasNotasDelCapitulo = ChapterNoteService.I
        .notesForChapter(widget.bookNumber, widget.chapter)
        .where((n) => n.id != note?.id)
        .length;

    _titleController.addListener(_markChanged);
    _contentController.addListener(_markChanged);
  }

  void _markChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
    _programarAutoguardado();
  }

  /// Cambios fuera del texto (color, etiquetas): también se autoguardan.
  void _cambio(VoidCallback fn) {
    setState(() {
      fn();
      _hasChanges = true;
    });
    _programarAutoguardado();
  }

  void _programarAutoguardado() {
    _autosave?.cancel();
    _autosave = Timer(const Duration(milliseconds: 800), () {
      unawaited(_guardar());
    });
  }

  @override
  void dispose() {
    // Última red de seguridad: si algo quedó sin guardar, se guarda ahora.
    _autosave?.cancel();
    if (_hasChanges) unawaited(_guardar(redibujar: false));
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  bool get _vacia =>
      _titleController.text.trim().isEmpty &&
      _contentController.text.trim().isEmpty;

  /// Guarda en el teléfono (la subida a la nube sigue sola). No espera al
  /// servidor, así que sin conexión termina igual.
  Future<bool> _guardar({bool redibujar = true}) async {
    _autosave?.cancel();
    if (_vacia || !_hasChanges) return !_vacia;
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    _noteId ??= ChapterNoteService.I.nuevoId();
    _hasChanges = false;
    try {
      final guardada = await ChapterNoteService.I.saveNote(
        existingId: _noteId,
        versionId: widget.versionId,
        bookNumber: widget.bookNumber,
        bookName: widget.bookName,
        chapter: widget.chapter,
        title: title.isEmpty ? '${widget.bookName} ${widget.chapter}' : title,
        content: content,
        tags: List.of(_tags),
        colorHex: _selectedColor,
      );
      if (guardada == null) {
        _hasChanges = true;
        return false;
      }
      _guardadaEn = guardada.updatedAt;
      if (redibujar && mounted) setState(() {});
      return true;
    } catch (e) {
      debugPrint('📝 [CHAPTER-NOTE-EDITOR] save error: $e');
      _hasChanges = true;
      if (redibujar && mounted) setState(() {});
      return false;
    }
  }

  /// Botón ✓: guarda y cierra, o avisa si no hay nada que guardar.
  Future<void> _save() async {
    if (_vacia) {
      HapticFeedback.selectionClick();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escribe un título o una reflexión para guardar la nota.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final ok = await _guardar();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo guardar la nota. Inténtalo de nuevo.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.pop(context, true);
  }

  String? _estadoGuardado(EstadoNotasNube nube) {
    if (_hasChanges) return 'Cambios sin guardar';
    if (_guardadaEn == null) return null;
    return switch (nube) {
      EstadoNotasNube.esperandoConexion ||
      EstadoNotasNube.error => etiquetaEstadoNotas(nube),
      _ => 'Guardado',
    };
  }

  Future<void> _delete() async {
    final note = widget.existingNote;
    if (note == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final t = BibleReaderThemeData.fromId(
          BibleReaderThemeData.migrateId(
              BibleUserDataService.I.readerThemeNotifier.value),
        );
        return AlertDialog(
          backgroundColor: t.surface,
          title: Text('Eliminar nota',
              style: AppFonts.manrope(color: t.textPrimary, fontSize: 16)),
          content: Text('¿Eliminar esta nota de estudio?',
              style: AppFonts.manrope(
                  color: t.textSecondary, fontSize: 14)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancelar',
                  style: AppFonts.manrope(color: t.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Eliminar',
                  style: AppFonts.manrope(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      _autosave?.cancel();
      _hasChanges = false;
      await ChapterNoteService.I.deleteNote(_noteId ?? note.id);
      if (mounted) Navigator.pop(context, true);
    }
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      _cambio(() => _tags.add(tag));
      _tagController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: BibleUserDataService.I.readerThemeNotifier,
      builder: (context, themeId, _) {
        final t = BibleReaderThemeData.fromId(
          BibleReaderThemeData.migrateId(themeId),
        );

        SystemChrome.setSystemUIOverlayStyle(
          t.oscuro ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        );

        // Al volver atrás (flecha, gesto o botón del sistema) se guarda lo
        // escrito: antes se perdía si no se tocaba ✓.
        return PopScope<Object?>(
          onPopInvokedWithResult: (didPop, _) {
            if (didPop && _hasChanges) unawaited(_guardar(redibujar: false));
          },
          child: Scaffold(
            backgroundColor: t.pageBg,
            body: SafeArea(
              child: Column(
                children: [
                  _buildHeader(t),
                  _buildEstado(t),
                  Expanded(child: _buildEditor(t)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BibleReaderThemeData t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Volver (se guarda solo)',
            icon: Icon(Icons.arrow_back_ios,
                color: t.textSecondary, size: 18),
            onPressed: () => Navigator.maybePop(context),
          ),
          Expanded(
            child: Text(
              '${widget.bookName} ${widget.chapter}',
              style: AppFonts.manrope(
                color: t.textoTenue(0.6),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (widget.existingNote != null)
            IconButton(
              tooltip: 'Eliminar nota',
              icon: Icon(Icons.delete_outline,
                  color: t.textSecondary.withValues(alpha: 0.5), size: 20),
              onPressed: _delete,
            ),
          IconButton(
            tooltip: 'Guardar y cerrar',
            icon: Icon(Icons.check,
                color: _vacia ? t.textoTenue(0.45) : t.accent,
                size: 22),
            onPressed: _save,
          ),
        ],
      ),
    );
  }

  /// Estado del guardado y aviso si el capítulo tiene más notas.
  Widget _buildEstado(BibleReaderThemeData t) {
    return ValueListenableBuilder<EstadoNotasNube>(
      valueListenable: NotasSync.I.estado,
      builder: (context, nube, _) {
        final estado = _estadoGuardado(nube);
        final otras = _otrasNotasDelCapitulo;
        if (estado == null && otras == 0) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (estado != null)
                Semantics(
                  liveRegion: true,
                  child: Row(
                    children: [
                      Icon(
                        nube == EstadoNotasNube.esperandoConexion ||
                                nube == EstadoNotasNube.error
                            ? Icons.phone_android_rounded
                            : Icons.check_circle_outline_rounded,
                        size: 14,
                        color: t.textoAtenuado(),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          estado,
                          style: AppFonts.manrope(
                            color: t.textoAtenuado(),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (otras > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    otras == 1
                        ? 'Este capítulo tiene 1 nota más. Las verás todas en Notas de capítulo.'
                        : 'Este capítulo tiene $otras notas más. Las verás todas en Notas de capítulo.',
                    style: AppFonts.manrope(
                      color: t.textoAtenuado(),
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEditor(BibleReaderThemeData t) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          TextField(
            controller: _titleController,
            style: AppFonts.cinzel(
              color: t.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: 'Título de la nota...',
              hintStyle: AppFonts.cinzel(
                color: t.textSecondary.withValues(alpha: 0.3),
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
          ),

          const SizedBox(height: 20),

          // Color selector
          Row(
            children: _noteColors.map((hex) {
              final color = Color(int.parse('FF$hex', radix: 16));
              final selected = hex == _selectedColor;
              return Semantics(
                button: true,
                selected: selected,
                label: 'Color de la nota',
                child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _cambio(() => _selectedColor = hex),
                child: Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.fromLTRB(0, 10, 18, 10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: selected ? 1.0 : 0.4),
                    shape: BoxShape.circle,
                    border: selected
                        ? Border.all(color: color, width: 2)
                        : null,
                  ),
                  child: selected
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : null,
                ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // Tags
          if (_tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _tags.map((tag) {
                  return GestureDetector(
                    onTap: () => _cambio(() => _tags.remove(tag)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: t.oscuro
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tag,
                            style: AppFonts.manrope(
                              color: t.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.close,
                              color: t.textSecondary.withValues(alpha: 0.4),
                              size: 12),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          // Add tag field
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: t.oscuro
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.tag, color: t.textSecondary.withValues(alpha: 0.3),
                    size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _tagController,
                    style: AppFonts.manrope(
                        color: t.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Agregar etiqueta...',
                      hintStyle: AppFonts.manrope(
                        color: t.textSecondary.withValues(alpha: 0.3),
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onSubmitted: (_) => _addTag(),
                  ),
                ),
                GestureDetector(
                  onTap: _addTag,
                  child: Icon(Icons.add,
                      color: t.accent.withValues(alpha: 0.6), size: 18),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Divider
          Container(
            height: 0.5,
            color: t.textSecondary.withValues(alpha: 0.1),
          ),

          const SizedBox(height: 24),

          // Content
          TextField(
            controller: _contentController,
            style: AppFonts.lora(
              color: t.textPrimary,
              fontSize: 16,
              height: 1.8,
            ),
            decoration: InputDecoration(
              hintText:
                  'Escribe tus reflexiones sobre este capítulo...',
              hintStyle: AppFonts.lora(
                color: t.textSecondary.withValues(alpha: 0.25),
                fontSize: 16,
                height: 1.8,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            maxLines: null,
            minLines: 10,
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.multiline,
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
