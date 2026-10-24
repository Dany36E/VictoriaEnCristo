import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/bible/bible_note.dart';
import '../../models/bible/bible_version.dart';
import '../../models/bible/highlight.dart';
import '../../models/bible/saved_verse.dart';
import '../../services/bible/bible_download_service.dart';
import '../../services/bible/bible_library.dart';
import '../../services/bible/bible_parser_service.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../services/user_scoped_services.dart';
import '../../theme/app_fonts.dart';
import '../../theme/bible_reader_theme.dart';
import 'bible_reader_screen.dart';
import 'collections_screen.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// MI BIBLIOTECA
/// Un solo lugar para resaltados (filtro por color), notas de versículo y
/// versículos guardados (+ colecciones). Se puede buscar, ordenar por fecha
/// u orden bíblico, abrir cada elemento en su versículo y exportar la lista
/// como texto o Markdown.
/// ═══════════════════════════════════════════════════════════════════════════
class BibleLibraryScreen extends StatefulWidget {
  final LibraryKind initialKind;

  const BibleLibraryScreen({super.key, this.initialKind = LibraryKind.saved});

  @override
  State<BibleLibraryScreen> createState() => _BibleLibraryScreenState();
}

class _BibleLibraryScreenState extends State<BibleLibraryScreen>
    with SingleTickerProviderStateMixin {
  static const _kinds = [
    LibraryKind.saved,
    LibraryKind.highlight,
    LibraryKind.note,
  ];

  late final TabController _tabs;
  final _searchCtrl = TextEditingController();
  String _search = '';
  LibrarySort _sort = LibrarySort.date;
  String? _color;

  /// Texto de los versículos resaltados (se cargan en segundo plano).
  final Map<String, String> _highlightTexts = {};
  bool _loadingTexts = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: _kinds.length,
      vsync: this,
      initialIndex: _kinds.indexOf(widget.initialKind),
    );
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });
    unawaited(UserScopedServices.I.ensureBible());
    BibleUserDataService.I.highlightsNotifier.addListener(_loadHighlightTexts);
    _loadHighlightTexts();
  }

  @override
  void dispose() {
    BibleUserDataService.I.highlightsNotifier.removeListener(
      _loadHighlightTexts,
    );
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHighlightTexts() async {
    if (_loadingTexts) return;
    _loadingTexts = true;
    try {
      final pending = BibleUserDataService.I.highlightsNotifier.value.values
          .map(LibraryItem.fromHighlight)
          .where((i) => !_highlightTexts.containsKey(i.textKey))
          .toList();
      var sinceRefresh = 0;
      for (final item in pending) {
        if (!mounted) return;
        final version = BibleVersion.fromId(item.versionId ?? 'RVR1960');
        if (!BibleDownloadService.I.isAvailable(version)) continue;
        try {
          final v = await BibleParserService.I.getVerse(
            version: version,
            bookNumber: item.bookNumber,
            chapter: item.chapter,
            verse: item.verse,
          );
          _highlightTexts[item.textKey] = v?.text ?? '';
        } catch (_) {
          _highlightTexts[item.textKey] = '';
        }
        if (++sinceRefresh >= 20 && mounted) {
          sinceRefresh = 0;
          setState(() {});
        }
      }
    } finally {
      _loadingTexts = false;
      if (mounted) setState(() {});
    }
  }

  LibraryKind get _kind => _kinds[_tabs.index];

  List<LibraryItem> _itemsFor(LibraryKind kind) {
    final data = BibleUserDataService.I;
    final Iterable<LibraryItem> raw = switch (kind) {
      LibraryKind.saved => data.savedVersesNotifier.value.map(
        LibraryItem.fromSaved,
      ),
      LibraryKind.highlight => data.highlightsNotifier.value.values.map((h) {
        final item = LibraryItem.fromHighlight(h);
        return item.withVerseText(_highlightTexts[item.textKey]);
      }),
      LibraryKind.note => data.notesNotifier.value.values.map(
        LibraryItem.fromNote,
      ),
    };
    return BibleLibrary.query(
      raw,
      search: _search,
      colorHex: kind == LibraryKind.highlight ? _color : null,
      sort: _sort,
    );
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
        return Scaffold(
          backgroundColor: t.pageBg,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(t),
                _buildSearch(t),
                _buildSortRow(t),
                TabBar(
                  controller: _tabs,
                  labelColor: t.accent,
                  unselectedLabelColor: t.textSecondary,
                  indicatorColor: t.accent,
                  dividerColor: t.textSecondary.withValues(alpha: 0.12),
                  labelStyle: AppFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelStyle: AppFonts.manrope(fontSize: 13),
                  tabs: const [
                    Tab(text: 'Guardados'),
                    Tab(text: 'Resaltados'),
                    Tab(text: 'Notas'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      ValueListenableBuilder<List<SavedVerse>>(
                        valueListenable:
                            BibleUserDataService.I.savedVersesNotifier,
                        builder: (context, _, _) =>
                            _buildList(t, LibraryKind.saved),
                      ),
                      ValueListenableBuilder<Map<String, Highlight>>(
                        valueListenable:
                            BibleUserDataService.I.highlightsNotifier,
                        builder: (context, _, _) =>
                            _buildList(t, LibraryKind.highlight),
                      ),
                      ValueListenableBuilder<Map<String, BibleNote>>(
                        valueListenable: BibleUserDataService.I.notesNotifier,
                        builder: (context, _, _) =>
                            _buildList(t, LibraryKind.note),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BibleReaderThemeData t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Volver',
            icon: Icon(Icons.arrow_back_ios, color: t.textSecondary, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          Icon(Icons.local_library_outlined, color: t.accent, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Mi biblioteca',
              style: AppFonts.cinzel(
                color: t.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: 'Exportar lista',
            icon: Icon(Icons.ios_share, color: t.textSecondary),
            onPressed: () => _export(t),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch(BibleReaderThemeData t) {
    final fondo = t.oscuro
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _search = v),
        cursorColor: t.textPrimary,
        style: AppFonts.manrope(color: t.textPrimary, fontSize: 15),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Buscar por referencia, texto o nota',
          hintStyle: AppFonts.manrope(color: t.textoTenue(0.6), fontSize: 15),
          prefixIcon: Icon(Icons.search, color: t.textSecondary, size: 20),
          suffixIcon: _search.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Borrar búsqueda',
                  icon: Icon(Icons.close, color: t.textSecondary, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _search = '');
                  },
                ),
          filled: true,
          fillColor: fondo,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: t.accent.withValues(alpha: 0.5)),
          ),
        ),
      ),
    );
  }

  Widget _buildSortRow(BibleReaderThemeData t) {
    Widget chip(LibrarySort s, String label) {
      final selected = _sort == s;
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _sort = s),
        showCheckmark: false,
        labelStyle: AppFonts.manrope(
          color: selected ? t.sobreAcento : t.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        selectedColor: t.accent,
        backgroundColor: t.surface,
        side: BorderSide(color: t.accent.withValues(alpha: 0.3)),
        materialTapTargetSize: MaterialTapTargetSize.padded,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Ordenar:',
            style: AppFonts.manrope(color: t.textoTenue(0.7), fontSize: 12),
          ),
          chip(LibrarySort.date, 'Recientes'),
          chip(LibrarySort.bibleOrder, 'Orden bíblico'),
        ],
      ),
    );
  }

  Widget _buildColorFilter(BibleReaderThemeData t) {
    final colors =
        BibleUserDataService.I.highlightsNotifier.value.values
            .map((h) => h.colorHex.toUpperCase())
            .toSet()
            .toList()
          ..sort();
    if (colors.length < 2 && _color == null) return const SizedBox.shrink();
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [_colorDot(t, null), for (final c in colors) _colorDot(t, c)],
      ),
    );
  }

  Widget _colorDot(BibleReaderThemeData t, String? hex) {
    final selected = _color == hex;
    return Semantics(
      button: true,
      selected: selected,
      label: hex == null ? 'Todos los colores' : 'Filtrar por color $hex',
      excludeSemantics: true,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => setState(() => _color = hex),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hex == null ? t.surface : HighlightColors.fromHex(hex),
                border: Border.all(
                  color: selected
                      ? t.accent
                      : t.textSecondary.withValues(alpha: 0.3),
                  width: selected ? 3 : 1,
                ),
              ),
              child: hex == null
                  ? Icon(Icons.palette_outlined, size: 16, color: t.textPrimary)
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList(BibleReaderThemeData t, LibraryKind kind) {
    final items = _itemsFor(kind);
    final header = <Widget>[
      if (kind == LibraryKind.highlight) _buildColorFilter(t),
      if (kind == LibraryKind.saved)
        ListTile(
          leading: Icon(Icons.collections_bookmark_outlined, color: t.accent),
          title: Text(
            'Colecciones',
            style: AppFonts.manrope(
              color: t.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            'Agrupa tus versículos por tema',
            style: AppFonts.manrope(color: t.textoTenue(0.6), fontSize: 12),
          ),
          trailing: Icon(Icons.chevron_right, color: t.textSecondary),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CollectionsScreen()),
          ),
        ),
    ];
    if (items.isEmpty) {
      return ListView(
        children: [
          ...header,
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              _emptyText(kind),
              textAlign: TextAlign.center,
              style: AppFonts.manrope(
                color: t.textoTenue(0.6),
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 32),
      itemCount: header.length + items.length,
      itemBuilder: (context, i) {
        if (i < header.length) return header[i];
        return _buildTile(t, items[i - header.length]);
      },
    );
  }

  String _emptyText(LibraryKind kind) {
    if (_search.isNotEmpty || _color != null) {
      return 'No hay resultados con estos filtros.';
    }
    return switch (kind) {
      LibraryKind.saved =>
        'Aún no tienes versículos guardados.\nEn el lector, toca un versículo y elige «Guardar».',
      LibraryKind.highlight =>
        'Aún no tienes resaltados.\nEn el lector, toca un versículo y elige un color.',
      LibraryKind.note =>
        'Aún no tienes notas de versículos.\nEn el lector, toca un versículo y elige «Nota».',
    };
  }

  Widget _buildTile(BibleReaderThemeData t, LibraryItem item) {
    final body = item.kind == LibraryKind.note ? item.noteText : item.verseText;
    final version = item.versionId == null
        ? ''
        : ' · ${BibleVersion.fromId(item.versionId!).shortName}';
    return Semantics(
      button: true,
      label: 'Abrir ${item.reference}',
      child: InkWell(
        onTap: () => _open(item),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 3, right: 12),
                child: item.colorHex != null
                    ? Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: HighlightColors.fromHex(item.colorHex!),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: t.textSecondary.withValues(alpha: 0.3),
                          ),
                        ),
                      )
                    : Icon(
                        item.kind == LibraryKind.note
                            ? Icons.sticky_note_2_outlined
                            : Icons.bookmark,
                        size: 14,
                        color: t.accent,
                      ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item.reference}$version',
                      style: AppFonts.manrope(
                        color: t.textoTenue(0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (body != null && body.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        body.trim(),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style:
                            (item.kind == LibraryKind.note
                                    ? AppFonts.manrope
                                    : AppFonts.lora)
                                .call(
                                  color: t.textPrimary,
                                  fontSize: 15,
                                  height: 1.5,
                                ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(LibraryItem item) {
    final preferred = BibleUserDataService.I.preferredVersionNotifier.value;
    final v = item.versionId == null
        ? preferred
        : BibleVersion.fromId(item.versionId!);
    final version = BibleDownloadService.I.isAvailable(v) ? v : preferred;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BibleReaderScreen(
          bookNumber: item.bookNumber,
          bookName: item.bookName,
          chapter: item.chapter,
          version: version,
          initialVerse: item.verse,
        ),
      ),
    );
  }

  Future<void> _export(BibleReaderThemeData t) async {
    final kind = _kind;
    final items = _itemsFor(kind);
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay nada que exportar en esta lista.'),
        ),
      );
      return;
    }
    final markdown = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: t.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.text_snippet_outlined, color: t.accent),
              title: Text(
                'Compartir como texto',
                style: AppFonts.manrope(color: t.textPrimary),
              ),
              onTap: () => Navigator.pop(ctx, false),
            ),
            ListTile(
              leading: Icon(Icons.code, color: t.accent),
              title: Text(
                'Compartir como Markdown',
                style: AppFonts.manrope(color: t.textPrimary),
              ),
              onTap: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      ),
    );
    if (markdown == null) return;
    final content = markdown
        ? BibleLibrary.exportMarkdown(items, kind)
        : BibleLibrary.exportText(items, kind);
    await Share.share(content, subject: 'Mi biblioteca · Victoria en Cristo');
  }
}
