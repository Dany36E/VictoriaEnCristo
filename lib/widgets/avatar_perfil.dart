/// Avatar de perfil dibujado («papel recortado») y la hoja para elegirlo.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/avatar_perfil_service.dart';
import '../theme/app_fonts.dart';
import '../theme/app_theme_data.dart';
import '../vec/vec_tema.dart';
import '../vec/vec_widgets.dart';

/// Muestra el avatar que eligió el usuario; si no ha elegido ninguno, muestra
/// [respaldo] (foto de la cuenta o ícono).
class AvatarPerfilImagen extends StatelessWidget {
  const AvatarPerfilImagen({
    super.key,
    required this.tamano,
    required this.respaldo,
  });

  final double tamano;
  final Widget respaldo;

  @override
  Widget build(BuildContext context) {
    final papel = AppThemeData.of(context).isPaper;
    return ValueListenableBuilder<String?>(
      valueListenable: AvatarPerfilService.I.avatarId,
      builder: (context, id, _) {
        if (id == null) return respaldo;
        final ruta = AvatarPerfilService.rutaDe(id);
        return Semantics(
          image: true,
          label: 'Avatar de perfil',
          child: papel
              ? AvatarVec(ruta: ruta, tamano: tamano)
              : SizedBox(
                  width: tamano,
                  height: tamano,
                  child: ClipOval(
                    child: Image.asset(
                      ruta,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                ),
        );
      },
    );
  }
}

/// Abre la hoja con los 20 avatares (10 de hombre y 10 de mujer).
Future<void> mostrarSelectorAvatar(BuildContext context) {
  HapticFeedback.lightImpact();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppThemeData.of(context).isPaper
        ? null
        : AppThemeData.of(context).surface,
    builder: (_) => const _SelectorAvatar(),
  );
}

class _SelectorAvatar extends StatelessWidget {
  const _SelectorAvatar();

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final alto = MediaQuery.of(context).size.height * 0.85;

    Widget seccion(String titulo) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: t.isPaper
          ? EtiquetaSeccion(titulo)
          : Text(
              titulo.toUpperCase(),
              style: AppFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: t.textSecondary,
              ),
            ),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: alto),
      child: ValueListenableBuilder<String?>(
        valueListenable: AvatarPerfilService.I.avatarId,
        builder: (context, elegido, _) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            MediaQuery.of(context).padding.bottom + 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (t.isPaper)
                const TituloVec('Elige tu avatar', clave: 'avatar', tamano: 28)
              else
                Text(
                  'Elige tu avatar',
                  style: AppFonts.manrope(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: t.textPrimary,
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                'Así te verás en tu perfil y en Inicio.',
                style: t.isPaper
                    ? TextStyle(
                        fontFamily: VecFuentes.texto,
                        fontSize: 18,
                        color: VecColores.lapiz,
                      )
                    : AppFonts.manrope(fontSize: 14, color: t.textSecondary),
              ),
              seccion('Hombres'),
              _Rejilla(avatares: AvatarPerfilService.hombres, elegido: elegido),
              seccion('Mujeres'),
              _Rejilla(avatares: AvatarPerfilService.mujeres, elegido: elegido),
              if (elegido != null) ...[
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () {
                      AvatarPerfilService.I.elegir(null);
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'Quitar avatar',
                      style: t.isPaper
                          ? TextStyle(
                              fontFamily: VecFuentes.titulo,
                              fontSize: 17,
                              color: VecColores.terracota,
                            )
                          : AppFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: t.accent,
                            ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Rejilla extends StatelessWidget {
  const _Rejilla({required this.avatares, required this.elegido});

  final List<AvatarPerfil> avatares;
  final String? elegido;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 5,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 10,
      children: [
        for (final a in avatares)
          _OpcionAvatar(avatar: a, seleccionado: a.id == elegido),
      ],
    );
  }
}

class _OpcionAvatar extends StatelessWidget {
  const _OpcionAvatar({required this.avatar, required this.seleccionado});

  final AvatarPerfil avatar;
  final bool seleccionado;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final colorMarca = t.isPaper ? VecColores.terracota : t.accent;
    return Semantics(
      button: true,
      selected: seleccionado,
      label: avatar.nombre,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          AvatarPerfilService.I.elegir(avatar.id);
          Navigator.of(context).pop();
        },
        child: AnimatedScale(
          scale: seleccionado ? 1.08 : 1,
          duration: MediaQuery.of(context).disableAnimations
              ? Duration.zero
              : VecMovimiento.duracion,
          curve: VecMovimiento.rebote,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: seleccionado
                        ? Border.all(color: colorMarca, width: 3)
                        : null,
                    boxShadow: t.isPaper
                        ? const [
                            BoxShadow(
                              color: Color(0x402B2622),
                              offset: Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(seleccionado ? 3 : 0),
                    child: ClipOval(
                      child: Image.asset(
                        avatar.ruta,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                ),
              ),
              if (seleccionado)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: t.isPaper
                      ? CirculoIcono(
                          iconoVec: 'palomita',
                          color: VecColores.papel,
                          tamano: 24,
                        )
                      : Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: colorMarca,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            size: 15,
                            color: t.isDark ? Colors.black : Colors.white,
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
