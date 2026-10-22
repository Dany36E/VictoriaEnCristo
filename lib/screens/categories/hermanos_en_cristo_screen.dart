import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../vec/vec_tema.dart';
import '../../vec/vec_widgets.dart';
import '../../widgets/home/category_hub_scaffold.dart';
import '../../widgets/home/glassmorphic_menu_button.dart';
import '../../repositories/profile_repository.dart';
import '../../services/battle_partner_service.dart';
import '../../services/user_scoped_services.dart';
import '../battle_partner/battle_partner_screen.dart';
import '../wall/wall_screen.dart';
import '../admin/admin_wall_screen.dart';

/// Sub-hub "Hermanos en Cristo": antes era "COMUNIDAD" en el Home.
///
/// Compañero de Batalla (con badge de invitaciones pendientes),
/// Muro de Batalla y, sólo si el usuario es admin, Moderación.
class HermanosEnCristoScreen extends StatefulWidget {
  const HermanosEnCristoScreen({super.key});

  @override
  State<HermanosEnCristoScreen> createState() => _HermanosEnCristoScreenState();
}

class _HermanosEnCristoScreenState extends State<HermanosEnCristoScreen> {

  @override
  void initState() {
    super.initState();
    UserScopedServices.I.ensureBattlePartners(syncPublicProgress: true);
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ProfileRepository.I.currentProfile?.isAdmin == true;
    return CategoryHubScaffold(
      title: 'Hermanos en Cristo',
      children: [
        _buildIntro(context),
        const SizedBox(height: AppDesignSystem.spacingL),
        Row(
          children: [
            Expanded(
              child: ValueListenableBuilder<List<dynamic>>(
                valueListenable: BattlePartnerService.I.pendingInvitesNotifier,
                builder: (context, invites, _) {
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GlassmorphicMenuButton(
                        icon: Icons.shield,
                        title: 'Compañero',
                        subtitle: 'De Batalla',
                        index: 0,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BattlePartnerScreen(),
                          ),
                        ),
                      ),
                      if (invites.isNotEmpty)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(
                              color: AppDesignSystem.struggle,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${invites.length}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(width: AppDesignSystem.spacingM),
            Expanded(
              child: GlassmorphicMenuButton(
                icon: Icons.forum_rounded,
                title: 'Muro de',
                subtitle: 'Batalla',
                index: 1,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WallScreen()),
                ),
              ),
            ),
          ],
        ),
        if (isAdmin) ...[
          const SizedBox(height: AppDesignSystem.spacingM),
          Row(
            children: [
              Expanded(
                child: GlassmorphicMenuButton(
                  icon: Icons.admin_panel_settings_rounded,
                  title: 'Moderación',
                  subtitle: 'Admin',
                  index: 2,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminWallScreen()),
                  ),
                ),
              ),
              const SizedBox(width: AppDesignSystem.spacingM),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildIntro(BuildContext context) {
    return PopIn(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Sticker(
            'assets/vec/personajes/victoria_saludo.png',
            alto: 120,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Subtitulo(
              quien: 'Victoria',
              texto:
                  'No caminamos solos. Apóyate en tu compañero y en la comunidad.',
              clave: 'solos',
              color: VecColores.terracota,
            ),
          ),
        ],
      ),
    );
  }
}
