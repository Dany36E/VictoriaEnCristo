import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/bible/bosquejo_sermon.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../services/bible/bosquejo_sermon_service.dart';
import '../../services/user_scoped_services.dart';
import '../../theme/app_fonts.dart';
import '../../theme/bible_reader_theme.dart';
import 'bosquejo_editor_screen.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// BOSQUEJOS SCREEN — Lista de bosquejos de sermón
///
/// Crear, abrir y eliminar bosquejos. La lista se ve aunque no haya
/// conexión: sale de la copia del teléfono.
/// ═══════════════════════════════════════════════════════════════════════════
class BosquejosScreen extends StatefulWidget {
  const BosquejosScreen({super.key});

  @override
  State<BosquejosScreen> createState() => _BosquejosScreenState();
}

class _BosquejosScreenState extends State<BosquejosScreen> {
  @override
  void initState() {
    super.initState();
    // No se espera: la lista se dibuja con lo que ya hay en el teléfono.
    unawaited(_preparar());
  }

  Future<void> _preparar() async {
    try {
      await UserScopedServices.I.ensureSermonNotes();
    } catch (e) {
      debugPrint('[BOSQUEJOS] No se pudo preparar la sesión: $e');
    }
  }

  Future<void> _abrir([BosquejoSermon? bosquejo]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BosquejoEditorScreen(bosquejoId: bosquejo?.id),
      ),
    );
  }

  Future<bool> _confirmarEliminar(
    BibleReaderThemeData t,
    BosquejoSermon b,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: t.surface,
            title: Text(
              'Eliminar bosquejo',
              style: AppFonts.manrope(
                color: t.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Text(
              '¿Eliminar «${b.tituloVisible}»?',
              style: AppFonts.manrope(color: t.textSecondary, fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'Cancelar',
                  style: AppFonts.manrope(color: t.textSecondary),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  'Eliminar',
                  style: AppFonts.manrope(color: const Color(0xFFC0392B)),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _eliminar(BibleReaderThemeData t, BosquejoSermon b) async {
    if (!await _confirmarEliminar(t, b)) return;
    HapticFeedback.selectionClick();
    await BosquejoSermonService.I.borrar(b.id);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: BibleUserDataService.I.readerThemeNotifier,
      builder: (_, themeId, _) {
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
              children: [
                _encabezado(t),
                Expanded(child: _lista(t)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _encabezado(BibleReaderThemeData t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 12, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Volver',
            onPressed: () => Navigator.maybePop(context),
            icon: Icon(Icons.arrow_back_ios, color: t.textSecondary, size: 18),
          ),
          Icon(Icons.account_tree_outlined, color: t.accent, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Bosquejos de sermón',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.cinzel(
                color: t.textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Nuevo bosquejo',
            onPressed: () => _abrir(),
            icon: Icon(Icons.add_rounded, color: t.accent, size: 26),
          ),
        ],
      ),
    );
  }

  Widget _lista(BibleReaderThemeData t) {
    return ValueListenableBuilder<Map<String, BosquejoSermon>>(
      valueListenable: BosquejoSermonService.I.bosquejosNotifier,
      builder: (context, _, _) {
        final todos = BosquejoSermonService.I.todos;
        if (todos.isEmpty) return _vacio(t);
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          itemCount: todos.length,
          itemBuilder: (_, i) => _fila(t, todos[i]),
        );
      },
    );
  }

  Widget _vacio(BibleReaderThemeData t) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_tree_outlined, color: t.accent, size: 40),
            const SizedBox(height: 14),
            Text(
              'Arma tu predicación por puntos: texto principal, '
              'introducción, puntos con versículos, ilustración y conclusión.',
              textAlign: TextAlign.center,
              style: AppFonts.manrope(
                color: t.textoAtenuado(),
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 20),
            BotonBosquejo(
              theme: t,
              icono: Icons.add_rounded,
              texto: 'Nuevo bosquejo',
              onTap: () => _abrir(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fila(BibleReaderThemeData t, BosquejoSermon b) {
    final puntos = b.puntos.length;
    final detalle = [
      if (b.textoPrincipal.trim().isNotEmpty) b.textoPrincipal.trim(),
      puntos == 1 ? '1 punto' : '$puntos puntos',
      _fecha(b.updatedAt),
    ].join(' · ');
    return Dismissible(
      key: ValueKey('bosquejo_${b.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmarEliminar(t, b),
      onDismissed: (_) => BosquejoSermonService.I.borrar(b.id),
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: const Color(0xFFC0392B).withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          Icons.delete_outline_rounded,
          color: t.textPrimary,
          semanticLabel: 'Eliminar',
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Material(
          color: t.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _abrir(b),
            child: Container(
              constraints: const BoxConstraints(minHeight: 64),
              padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: t.textSecondary.withValues(alpha: 0.14),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.tituloVisible,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.manrope(
                            color: t.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          detalle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.manrope(
                            color: t.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Opciones del bosquejo',
                    color: t.surface,
                    icon: Icon(Icons.more_vert, color: t.textSecondary),
                    onSelected: (accion) {
                      if (accion == 'abrir') _abrir(b);
                      if (accion == 'eliminar') _eliminar(t, b);
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'abrir',
                        child: Text(
                          'Abrir',
                          style: AppFonts.manrope(color: t.textPrimary),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'eliminar',
                        child: Text(
                          'Eliminar',
                          style: AppFonts.manrope(color: t.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _fecha(DateTime d) {
    String dos(int v) => v.toString().padLeft(2, '0');
    return '${dos(d.day)}/${dos(d.month)}/${d.year}';
  }
}

/// Botón principal de los bosquejos: relleno de acento, mínimo 48 de alto.
class BotonBosquejo extends StatelessWidget {
  const BotonBosquejo({
    super.key,
    required this.theme,
    required this.icono,
    required this.texto,
    required this.onTap,
  });

  final BibleReaderThemeData theme;
  final IconData icono;
  final String texto;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: texto,
      excludeSemantics: true,
      child: Material(
        color: t.accent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icono, color: t.sobreAcento, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      texto,
                      style: AppFonts.manrope(
                        color: t.sobreAcento,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
