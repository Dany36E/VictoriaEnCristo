/// Header del Home: avatar, welcome, favoritos, settings.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';
import '../../services/favorites_service.dart';
import '../../screens/profile_screen.dart';
import '../../screens/favorites_screen.dart';
import '../../screens/settings_screen.dart';

class HomeHeader extends StatelessWidget {
  final VoidCallback? onThemeChanged;

  const HomeHeader({super.key, this.onThemeChanged});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    // Header sits on top of the dark hero image, but for light themes
    // the gradient may encroach; use theme-adaptive colors.
    final fg = t.isDark ? Colors.white : t.textPrimary;
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (e) {
      user = null;
    }
    final isLoggedIn = user != null;

    return Row(
      children: [
        // Avatar
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
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: fg.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fg.withOpacity(0.1),
              ),
              child: Icon(
                isLoggedIn ? Icons.person : Icons.shield_outlined,
                color: fg,
                size: 24,
              ),
            ),
          ),
        ),
        )
            .animate()
            .fadeIn(duration: 400.ms)
            .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),

        const SizedBox(width: AppDesignSystem.spacingM),

        // Welcome text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isLoggedIn ? '¡Bienvenido!' : 'Victoria en Cristo',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: fg.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isLoggedIn
                    ? (user.displayName?.split(' ').first ?? 'Guerrero')
                    : 'Tu camino a la libertad',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          )
              .animate()
              .fadeIn(delay: 100.ms, duration: 400.ms)
              .slideX(begin: 0.1, end: 0),
        ),

        // Favorites button
        IconButton(
          tooltip: 'Favoritos',
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FavoritesScreen()),
            );
          },
          icon: Stack(
            children: [
              Icon(
                Icons.bookmark_rounded,
                color: fg.withOpacity(0.7),
              ),
              if (FavoritesService().count > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFD4A853),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${FavoritesService().count}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Settings button
        IconButton(
          tooltip: 'Ajustes',
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SettingsScreen(
                  onThemeChanged: () => onThemeChanged?.call(),
                ),
              ),
            );
          },
          icon: Icon(
            Icons.tune_rounded,
            color: fg.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}
