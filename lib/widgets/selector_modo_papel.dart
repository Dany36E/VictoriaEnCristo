import 'package:flutter/material.dart';

import '../services/theme_service.dart';
import '../theme/app_fonts.dart';
import '../theme/app_theme_data.dart';
import '../vec/vec_tema.dart';

/// Apariencia de la app: claro, oscuro o automático (sigue al teléfono), y
/// cuál papel oscuro usar (kraft o noche). Se usa en Ajustes, en el Perfil y
/// en los ajustes de la Biblia.
class SelectorModoPapel extends StatelessWidget {
  const SelectorModoPapel({super.key, this.onChanged});

  /// Se llama después de cada cambio.
  final VoidCallback? onChanged;

  static const _modos = [
    (ModoTema.claro, 'Claro', Icons.light_mode_rounded),
    (ModoTema.oscuro, 'Oscuro', Icons.dark_mode_rounded),
    (ModoTema.automatico, 'Automático', Icons.brightness_auto_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final ts = ThemeService();
    final t = AppThemeData.of(context);
    // Escucha al servicio y no solo al tema visible: en automático de día,
    // elegir otro papel oscuro no cambia lo que se ve pero sí la marca.
    return ListenableBuilder(
      listenable: ts,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                for (final (modo, nombre, icono) in _modos) ...[
                  if (modo != ModoTema.claro) const SizedBox(width: 8),
                  Expanded(
                    child: _Opcion(
                      t: t,
                      nombre: nombre,
                      icono: icono,
                      elegida: ts.modo == modo,
                      onTap: () async {
                        await ts.setModo(modo);
                        onChanged?.call();
                      },
                    ),
                  ),
                ],
              ],
            ),
            if (ts.modo == ModoTema.automatico) ...[
              const SizedBox(height: 8),
              Text(
                'Sigue el modo claro u oscuro del teléfono.',
                style: AppFonts.manrope(fontSize: 13, color: t.textSecondary),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Papel oscuro',
              style: AppFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: t.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final papel in [
                  AppThemeData.paperKraft,
                  AppThemeData.paperNoche,
                ]) ...[
                  if (papel != AppThemeData.paperKraft)
                    const SizedBox(width: 8),
                  Expanded(
                    child: _MuestraPapel(
                      t: t,
                      papel: papel,
                      elegida: ts.papelOscuro == papel.id,
                      onTap: () async {
                        await ts.setPapelOscuro(papel.id);
                        onChanged?.call();
                      },
                    ),
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Botón de un modo (Claro, Oscuro, Automático).
class _Opcion extends StatelessWidget {
  const _Opcion({
    required this.t,
    required this.nombre,
    required this.icono,
    required this.elegida,
    required this.onTap,
  });

  final AppThemeData t;
  final String nombre;
  final IconData icono;
  final bool elegida;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tinta = elegida ? t.sobreAcento : t.textPrimary;
    return Semantics(
      button: true,
      selected: elegida,
      label: 'Modo $nombre',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            color: elegida ? t.accent : t.cardBg,
            borderRadius: BorderRadius.circular(VecRadios.m),
            border: Border.all(
              color: elegida ? t.accent : t.cardBorder,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, color: tinta, size: 22),
              const SizedBox(height: 4),
              Text(
                nombre,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: tinta,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Muestra de un papel oscuro: la hoja con una tarjeta y su nombre.
class _MuestraPapel extends StatelessWidget {
  const _MuestraPapel({
    required this.t,
    required this.papel,
    required this.elegida,
    required this.onTap,
  });

  final AppThemeData t;
  final AppThemeData papel;
  final bool elegida;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nombre = papel.name.replaceFirst('Papel ', '');
    final etiqueta = '${nombre[0].toUpperCase()}${nombre.substring(1)}';
    return Semantics(
      button: true,
      selected: elegida,
      label: 'Papel oscuro $etiqueta',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            // La muestra siempre en los colores de ese papel.
            color: papel.scaffoldBg,
            borderRadius: BorderRadius.circular(VecRadios.m),
            border: Border.all(
              color: elegida ? t.accent : t.cardBorder,
              width: elegida ? 3 : 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: papel.cardBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: elegida
                    ? Icon(Icons.check_rounded, size: 18, color: papel.accent)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  etiqueta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: papel.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
