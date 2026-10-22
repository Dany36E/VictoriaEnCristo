/// Panel «Aa» de formato para las Notas de Apuntes: estilos de párrafo,
/// negrita/cursiva/subrayado/tachado, listas, resaltado, color y tamaño.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/bible/colores_nota.dart';
import '../../../models/bible/listas_nota.dart';
import '../../../models/bible/rich_note_document.dart';
import '../../../theme/bible_reader_theme.dart';
import 'sermon_rich_text_controller.dart';

/// Acciones del panel. Las aplica la pantalla para guardar y redibujar.
class AccionesFormatoNota {
  const AccionesFormatoNota({
    required this.formato,
    required this.parrafo,
    required this.lista,
    required this.tamano,
  });

  final void Function(RichNoteFormat formato, {String? valor}) formato;
  final ValueChanged<RichNoteParagraphStyle> parrafo;
  final ValueChanged<TipoLista> lista;
  final ValueChanged<double> tamano;
}

Future<void> mostrarHojaFormatoNota(
  BuildContext context, {
  required BibleReaderThemeData theme,
  required SermonRichTextController controller,
  required AccionesFormatoNota acciones,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _HojaFormato(
      theme: theme,
      controller: controller,
      acciones: acciones,
    ),
  );
}

class _HojaFormato extends StatelessWidget {
  const _HojaFormato({
    required this.theme,
    required this.controller,
    required this.acciones,
  });

  final BibleReaderThemeData theme;
  final SermonRichTextController controller;
  final AccionesFormatoNota acciones;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final sel = controller.selection;
        final hayTexto = sel.isValid && !sel.isCollapsed;
        final estado = controller.document.formatIn(
          sel.isValid ? sel.start : 0,
          sel.isValid ? sel.end : 0,
        );
        final lineaActual = sel.isValid
            ? listaEn(controller.text, inicioDeLinea(controller.text, sel.start))
            : null;
        return Container(
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: t.textSecondary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Formato',
                          style: TextStyle(
                            color: t.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cerrar',
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close_rounded, color: t.textSecondary),
                      ),
                    ],
                  ),
                  if (!hayTexto)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Selecciona texto para darle negrita, color o '
                        'resaltado. Los estilos y las listas se aplican a la '
                        'línea del cursor.',
                        style: TextStyle(
                          color: t.textSecondary,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ),
                  _Fila(
                    children: [
                      _Estilo(t, 'Título', 22, () => acciones.parrafo(RichNoteParagraphStyle.title)),
                      _Estilo(t, 'Encabezado', 18, () => acciones.parrafo(RichNoteParagraphStyle.heading)),
                      _Estilo(t, 'Subencabezado', 15.5, () => acciones.parrafo(RichNoteParagraphStyle.subheading)),
                      _Estilo(t, 'Cuerpo', 14, () => acciones.parrafo(RichNoteParagraphStyle.body), negrita: false),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (final (formato, icono, nombre) in const [
                        (RichNoteFormat.bold, Icons.format_bold_rounded, 'Negrita'),
                        (RichNoteFormat.italic, Icons.format_italic_rounded, 'Cursiva'),
                        (RichNoteFormat.underline, Icons.format_underlined_rounded, 'Subrayado'),
                        (RichNoteFormat.strike, Icons.format_strikethrough_rounded, 'Tachado'),
                      ])
                        Expanded(
                          child: _Boton(
                            theme: t,
                            icono: icono,
                            nombre: nombre,
                            activo: estado.has(formato),
                            habilitado: hayTexto,
                            onTap: () => acciones.formato(formato),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final (tipo, icono, nombre) in const [
                        (TipoLista.tareas, Icons.checklist_rounded, 'Lista de tareas'),
                        (TipoLista.vinetas, Icons.format_list_bulleted_rounded, 'Viñetas'),
                        (TipoLista.numerada, Icons.format_list_numbered_rounded, 'Lista numerada'),
                      ])
                        Expanded(
                          child: _Boton(
                            theme: t,
                            icono: icono,
                            nombre: nombre,
                            activo: lineaActual?.tipo == tipo,
                            onTap: () => acciones.lista(tipo),
                          ),
                        ),
                      Expanded(
                        child: _Boton(
                          theme: t,
                          icono: Icons.text_decrease_rounded,
                          nombre: 'Letra más chica',
                          habilitado: hayTexto,
                          onTap: () => acciones.tamano(-2),
                        ),
                      ),
                      Expanded(
                        child: _Boton(
                          theme: t,
                          icono: Icons.text_increase_rounded,
                          nombre: 'Letra más grande',
                          habilitado: hayTexto,
                          onTap: () => acciones.tamano(2),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _Etiqueta(t, 'Resaltar'),
                  _Colores(
                    theme: t,
                    nombres: richNoteHighlightColors,
                    colores: coloresResaltado,
                    elegido: estado.highlight,
                    habilitado: hayTexto,
                    onElegir: (c) => acciones.formato(RichNoteFormat.highlight, valor: c),
                  ),
                  const SizedBox(height: 10),
                  _Etiqueta(t, 'Color del texto'),
                  _Colores(
                    theme: t,
                    nombres: richNoteTextColors,
                    colores: t.isDark ? coloresTextoOscuro : coloresTextoClaro,
                    elegido: estado.color,
                    habilitado: hayTexto,
                    onElegir: (c) => acciones.formato(RichNoteFormat.color, valor: c),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // En pantallas angostas los estilos bajan a otra línea en vez de
    // esconderse fuera de la vista.
    return Wrap(spacing: 8, runSpacing: 8, children: children);
  }
}

class _Estilo extends StatelessWidget {
  const _Estilo(this.t, this.texto, this.tamano, this.onTap, {this.negrita = true});

  final BibleReaderThemeData t;
  final String texto;
  final double tamano;
  final VoidCallback onTap;
  final bool negrita;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: t.textSecondary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text(
            texto,
            style: TextStyle(
              color: t.textPrimary,
              fontSize: tamano,
              fontWeight: negrita ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _Boton extends StatelessWidget {
  const _Boton({
    required this.theme,
    required this.icono,
    required this.nombre,
    required this.onTap,
    this.activo = false,
    this.habilitado = true,
  });

  final BibleReaderThemeData theme;
  final IconData icono;
  final String nombre;
  final VoidCallback onTap;
  final bool activo;
  final bool habilitado;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Tooltip(
        message: nombre,
        child: Semantics(
          button: true,
          selected: activo,
          enabled: habilitado,
          label: nombre,
          child: Material(
            color: activo
                ? t.accent.withValues(alpha: 0.18)
                : t.textSecondary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: habilitado
                  ? () {
                      HapticFeedback.selectionClick();
                      onTap();
                    }
                  : null,
              child: SizedBox(
                height: 46,
                child: Icon(
                  icono,
                  color: !habilitado
                      ? t.textSecondary.withValues(alpha: 0.35)
                      : activo
                      ? t.accent
                      : t.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.t, this.texto);

  final BibleReaderThemeData t;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        texto.toUpperCase(),
        style: TextStyle(
          color: t.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _Colores extends StatelessWidget {
  const _Colores({
    required this.theme,
    required this.nombres,
    required this.colores,
    required this.elegido,
    required this.habilitado,
    required this.onElegir,
  });

  final BibleReaderThemeData theme;
  final List<String> nombres;
  final Map<String, int> colores;
  final String? elegido;
  final bool habilitado;
  final ValueChanged<String?> onElegir;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    Widget muestra(String? nombre) {
      final activo = elegido == nombre;
      final color = nombre == null ? null : Color(colores[nombre]!);
      return Semantics(
        button: true,
        selected: activo,
        enabled: habilitado,
        label: nombre == null ? 'Sin color' : nombresColoresNota[nombre],
        child: GestureDetector(
          onTap: habilitado ? () => onElegir(nombre) : null,
          child: Opacity(
            opacity: habilitado ? 1 : 0.4,
            child: Container(
              width: 34,
              height: 34,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: color?.withValues(alpha: 1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: activo ? t.textPrimary : t.textSecondary.withValues(alpha: 0.3),
                  width: activo ? 3 : 1.2,
                ),
              ),
              child: nombre == null
                  ? Icon(Icons.format_color_reset_rounded, size: 18, color: t.textSecondary)
                  : null,
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [muestra(null), for (final n in nombres) muestra(n)],
      ),
    );
  }
}
