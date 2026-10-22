/// Header del Home: avatar, welcome, favoritos, settings.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../vec/vec_tema.dart';
import '../../vec/vec_widgets.dart';
import '../../services/favorites_service.dart';
import '../../screens/profile_screen.dart';
import '../../screens/favorites_screen.dart';
import '../../screens/settings_screen.dart';
import '../avatar_perfil.dart';

class HomeHeader extends StatelessWidget {
  final VoidCallback? onThemeChanged;

  const HomeHeader({super.key, this.onThemeChanged});

  @override
  Widget build(BuildContext context) {
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (e) {
      user = null;
    }
    return _buildPapel(context, user);
  }

  /// Tema papel: cabecera del kit (avatar, título con palabra clave en
  /// terracota) y botones redondos como las casillas de la barra.
  Widget _buildPapel(BuildContext context, User? user) {
    final isLoggedIn = user != null;
    final nombre = user?.displayName?.split(' ').first ?? 'guerrero';
    return Row(
      children: [
        Semantics(
          button: true,
          label: isLoggedIn ? 'Perfil de usuario' : 'Iniciar sesión',
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              if (isLoggedIn) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              } else {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            child: PopIn(
              child: AvatarPerfilImagen(
                tamano: 56,
                respaldo: CirculoIcono(
                  icono: Icons.person_rounded,
                  color: VecColores.cremaOscuro,
                  colorIcono: VecColores.gris,
                  tamano: 56,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              isLoggedIn
                  ? TituloVec('¡Hola, $nombre!', clave: nombre, tamano: 26)
                  : const TituloVec(
                      'Victoria en Cristo',
                      clave: 'en Cristo',
                      tamano: 26,
                    ),
              Text(
                'Tu camino a la libertad',
                style: TextStyle(
                  fontFamily: VecFuentes.texto,
                  fontSize: 16,
                  color: VecColores.gris,
                ),
              ),
            ],
          ),
        ),
        _BotonRedondoPapel(
          tooltip: 'Favoritos',
          icono: Icons.bookmark_rounded,
          contador: FavoritesService().count,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FavoritesScreen()),
          ),
        ),
        const SizedBox(width: 8),
        _BotonRedondoPapel(
          tooltip: 'Ajustes',
          icono: Icons.tune_rounded,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  SettingsScreen(onThemeChanged: () => onThemeChanged?.call()),
            ),
          ),
        ),
      ],
    );
  }
}

/// Botón redondo de la cabecera en tema papel (casilla apagada de .vec-tab).
class _BotonRedondoPapel extends StatelessWidget {
  final String tooltip;
  final IconData icono;
  final int contador;
  final VoidCallback onTap;

  const _BotonRedondoPapel({
    required this.tooltip,
    required this.icono,
    required this.onTap,
    this.contador = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CirculoIcono(
                icono: icono,
                color: VecColores.cremaOscuro,
                colorIcono: VecColores.tinta,
                tamano: 44,
                sombra: false,
              ),
              if (contador > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: VecColores.terracota,
                      borderRadius: BorderRadius.circular(VecRadios.pildora),
                    ),
                    child: Text(
                      '$contador',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: VecFuentes.titulo,
                        fontSize: 13,
                        color: VecColores.papel,
                      ),
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
