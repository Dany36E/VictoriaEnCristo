import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/bible/bible_note.dart';
import '../../models/bible/bible_version.dart';
import '../../models/bible/bosquejo_sermon.dart';
import '../../models/bible/chapter_study_note.dart';
import '../../models/bible/sermon_note.dart';
import '../../models/bible/study_chapter_answers.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../services/bible/bosquejo_sermon_service.dart';
import '../../services/bible/buscador_notas.dart';
import '../../services/bible/chapter_note_service.dart';
import '../../services/bible/sermon_note_service.dart';
import '../../services/bible/study_mode_service.dart';
import '../../services/user_scoped_services.dart';
import '../../theme/app_fonts.dart';
import '../../theme/bible_reader_theme.dart';
import 'bible_reader_screen.dart';
import 'bosquejo_editor_screen.dart';
import 'chapter_note_editor_screen.dart';
import 'sermon_notes_mode_screen.dart';
import 'study_mode_screen.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// BUSCAR EN MIS NOTAS — una sola búsqueda para todo lo escrito: notas de
/// capítulo, apuntes de predicación, respuestas del Modo Estudio, notas de
/// versículo y bosquejos. Muestra el tipo, la referencia y el trozo con la
/// coincidencia resaltada; tocar un resultado lo abre.
/// ═══════════════════════════════════════════════════════════════════════════
class BuscarNotasScreen extends StatefulWidget {
  const BuscarNotasScreen({super.key, this.consultaInicial = ''});

  final String consultaInicial;

  @override
  State<BuscarNotasScreen> createState() => _BuscarNotasScreenState();
}

class _BuscarNotasScreenState extends State<BuscarNotasScreen> {
  late final TextEditingController _controller;
  final _foco = FocusNode();
  Timer? _espera;
  String _consulta = '';
  String? _etiqueta;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.consultaInicial);
    _consulta = widget.consultaInicial;
    unawaited(_cargarServicios());
  }

  /// Arranca los servicios de notas (si hay sesión). La búsqueda usa lo que
  /// ya está en el teléfono, así que no espera a la nube.
  Future<void> _cargarServicios() async {
    try {
      await UserScopedServices.I.ensureSermonNotes();
    } catch (e) {
      debugPrint('[BUSCAR-NOTAS] servicios: $e');
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _espera?.cancel();
    _controller.dispose();
    _foco.dispose();
    super.dispose();
  }

  void _alEscribir(String valor) {
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 220), () {
      if (mounted) setState(() => _consulta = valor);
    });
  }

  Listenable get _fuentes => Listenable.merge([
    ChapterNoteService.I.notasPorIdNotifier,
    SermonNoteService.I.notesNotifier,
    StudyModeService.I.answersNotifier,
    BibleUserDataService.I.notesNotifier,
    BosquejoSermonService.I.bosquejosNotifier,
  ]);

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
            child: AnimatedBuilder(
              animation: _fuentes,
              builder: (context, _) {
                final etiquetas = BuscadorNotas.todasLasEtiquetas(
                  notasCapitulo: ChapterNoteService.I.allNotes,
                  apuntes: SermonNoteService.I.allNotes,
                  notasVersiculo: BibleUserDataService.I.notesNotifier.value.values,
                );
                final resultados = BuscadorNotas.buscar(
                  _consulta,
                  etiqueta: _etiqueta,
                  notasCapitulo: ChapterNoteService.I.allNotes,
                  apuntes: SermonNoteService.I.allNotes,
                  estudios: StudyModeService.I.answersNotifier.value.values,
                  notasVersiculo: BibleUserDataService.I.notesNotifier.value.values,
                  bosquejos: BosquejoSermonService.I.todos,
                );
                return Column(
                  children: [
                    _encabezado(t),
                    if (etiquetas.isNotEmpty) _filaEtiquetas(t, etiquetas),
                    Expanded(child: _cuerpo(t, resultados)),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _encabezado(BibleReaderThemeData t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Volver',
            icon: Icon(Icons.arrow_back_ios, color: t.textSecondary, size: 18),
            onPressed: () => Navigator.maybePop(context),
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _foco,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _alEscribir,
              onSubmitted: (v) => setState(() => _consulta = v),
              style: AppFonts.manrope(color: t.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Buscar en todas mis notas',
                hintStyle: AppFonts.manrope(
                  color: t.textoAtenuado(),
                  fontSize: 14,
                ),
                prefixIcon: Icon(Icons.search, color: t.textSecondary, size: 20),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Borrar búsqueda',
                        icon: Icon(Icons.close, color: t.textSecondary, size: 18),
                        onPressed: () {
                          _controller.clear();
                          setState(() => _consulta = '');
                        },
                      ),
                isDense: true,
                filled: true,
                fillColor: t.textSecondary.withValues(alpha: 0.08),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filaEtiquetas(BibleReaderThemeData t, List<String> etiquetas) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final e in etiquetas)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Semantics(
                button: true,
                selected: _etiqueta == e,
                label: 'Filtrar por la etiqueta $e',
                excludeSemantics: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => setState(
                    () => _etiqueta = _etiqueta == e ? null : e,
                  ),
                  child: Center(child: _Chip(theme: t, texto: '#$e', activo: _etiqueta == e)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _cuerpo(BibleReaderThemeData t, List<ResultadoNota> resultados) {
    final sinConsulta = _consulta.trim().isEmpty && _etiqueta == null;
    if (sinConsulta || resultados.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                sinConsulta ? Icons.manage_search_rounded : Icons.search_off_rounded,
                color: t.accent,
                size: 40,
              ),
              const SizedBox(height: 14),
              Text(
                sinConsulta
                    ? 'Escribe una palabra, una cita o una #etiqueta.\n'
                          'Se busca en notas de capítulo, apuntes, '
                          'Modo Estudio, notas de versículo y bosquejos.'
                    : 'No hay notas con «${_consulta.trim()}».',
                textAlign: TextAlign.center,
                style: AppFonts.manrope(
                  color: t.textoAtenuado(),
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      itemCount: resultados.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
            child: Semantics(
              liveRegion: true,
              child: Text(
                resultados.length == 1
                    ? '1 resultado'
                    : '${resultados.length} resultados',
                style: AppFonts.manrope(
                  color: t.textoAtenuado(),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        }
        final r = resultados[i - 1];
        return _TarjetaResultado(theme: t, resultado: r, onTap: () => _abrir(r));
      },
    );
  }

  void _abrir(ResultadoNota r) {
    final version = BibleUserDataService.I.preferredVersionNotifier.value;
    final Widget destino = switch (r.origen) {
      final ChapterStudyNote n => ChapterNoteEditorScreen(
        bookNumber: n.bookNumber,
        bookName: n.bookName,
        chapter: n.chapter,
        versionId: n.versionId,
        existingNote: n,
      ),
      final SermonNote a => SermonNotesModeScreen(noteId: a.id),
      final StudyChapterAnswers e => StudyModeScreen(
        bookNumber: e.bookNumber,
        bookName: e.bookName,
        chapter: e.chapter,
        version: BibleVersion.fromId(e.versionId),
        studyId: e.studyId,
      ),
      final BibleNote v => BibleReaderScreen(
        bookNumber: v.bookNumber,
        bookName: v.bookName,
        chapter: v.chapter,
        version: version,
        initialVerse: v.verse,
      ),
      final BosquejoSermon b => BosquejoEditorScreen(bosquejoId: b.id),
      _ => const SizedBox.shrink(),
    };
    Navigator.push(context, MaterialPageRoute(builder: (_) => destino));
  }
}

class _TarjetaResultado extends StatelessWidget {
  const _TarjetaResultado({
    required this.theme,
    required this.resultado,
    required this.onTap,
  });

  final BibleReaderThemeData theme;
  final ResultadoNota resultado;
  final VoidCallback onTap;

  IconData get _icono => switch (resultado.tipo) {
    TipoNotaBuscada.capitulo => Icons.description_outlined,
    TipoNotaBuscada.apunte => Icons.edit_note_rounded,
    TipoNotaBuscada.estudio => Icons.school_outlined,
    TipoNotaBuscada.versiculo => Icons.sticky_note_2_outlined,
    TipoNotaBuscada.bosquejo => Icons.account_tree_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final r = resultado;
    final base = AppFonts.lora(color: t.textPrimary, fontSize: 14, height: 1.5);
    final fragmento = r.fragmento;
    final texto = r.tieneResaltado && r.fin <= fragmento.length
        ? TextSpan(
            style: base,
            children: [
              TextSpan(text: fragmento.substring(0, r.inicio)),
              TextSpan(
                text: fragmento.substring(r.inicio, r.fin),
                style: base.copyWith(
                  fontWeight: FontWeight.w800,
                  backgroundColor: t.accent.withValues(alpha: 0.22),
                ),
              ),
              TextSpan(text: fragmento.substring(r.fin)),
            ],
          )
        : TextSpan(text: fragmento, style: base);
    return Semantics(
      button: true,
      label: '${r.tipo.etiqueta}. ${r.titulo}. '
          '${r.referencia.isEmpty ? '' : '${r.referencia}. '}$fragmento',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: t.textSecondary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: t.textSecondary.withValues(alpha: 0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_icono, size: 15, color: t.accent),
                      const SizedBox(width: 5),
                      Text(
                        r.tipo.etiqueta.toUpperCase(),
                        style: AppFonts.manrope(
                          color: t.textoAtenuado(),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  if (r.referencia.isNotEmpty && r.referencia != r.titulo)
                    Text(
                      r.referencia,
                      style: AppFonts.manrope(
                        color: t.textoAtenuado(),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                r.titulo,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.manrope(
                  color: t.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (fragmento.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text.rich(texto, maxLines: 4, overflow: TextOverflow.ellipsis),
              ],
              if (r.etiquetas.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final e in r.etiquetas.take(5))
                      _Chip(theme: t, texto: '#$e', activo: false),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.theme, required this.texto, required this.activo});

  final BibleReaderThemeData theme;
  final String texto;
  final bool activo;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: activo
            ? t.accent.withValues(alpha: 0.14)
            : t.textSecondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: activo
              ? t.accent.withValues(alpha: 0.55)
              : t.textSecondary.withValues(alpha: 0.15),
        ),
      ),
      child: Text(
        texto,
        style: AppFonts.manrope(
          color: activo ? t.textPrimary : t.textPrimary.withValues(alpha: 0.82),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
