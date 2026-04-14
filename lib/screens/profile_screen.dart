import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/badge_service.dart';
import '../services/victory_scoring_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_data.dart';
import '../widgets/badge_grid_section.dart';
import '../widgets/theme_selector.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onLogout;
  
  const ProfileScreen({super.key, this.onLogout});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  AppUser? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    await BadgeService.I.init();
    final data = await _authService.getUserData();
    setState(() {
      _userData = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final t = AppThemeData.of(context);

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: t.accent))
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ─── Header con gradient suave ───
                SliverToBoxAdapter(
                  child: Container(
                    padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 16, 24, 28),
                    decoration: BoxDecoration(
                      gradient: t.headerGradient,
                    ),
                    child: Column(
                      children: [
                        // Back + title row
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Navigator.maybePop(context);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: t.textPrimary.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: t.textPrimary.withOpacity(0.7)),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Text(
                              'Mi Perfil',
                              style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w800, color: t.textPrimary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),

                        // Avatar
                        _buildAvatar(user?.photoURL),
                        const SizedBox(height: 14),

                        // Nombre
                        Text(
                          user?.displayName ?? _userData?.displayName ?? 'Usuario',
                          style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w800, color: t.textPrimary),
                        ),
                        const SizedBox(height: 2),

                        // Email
                        Text(
                          user?.email ?? '',
                          style: GoogleFonts.manrope(fontSize: 13, color: t.textSecondary),
                        ),
                        const SizedBox(height: 20),

                        // Stats row
                        _buildStatsRow(),
                      ],
                    ),
                  ),
                ),

                // ─── Insignias ───
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                    child: const BadgeGridSection(),
                  ),
                ),

                // ─── Tema de la app ───
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: t.cardDecoration,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.palette_outlined, size: 18, color: t.accent),
                              const SizedBox(width: 8),
                              Text(
                                'Tema de la app',
                                style: GoogleFonts.manrope(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: t.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const ThemeSelectorWidget(swatchSize: 36),
                        ],
                      ),
                    ),
                  ),
                ),

                // ─── Opciones ───
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: _buildOptionsSection(),
                  ),
                ),

                // ─── Cerrar sesión ───
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: _buildLogoutButton(),
                  ),
                ),

                SliverToBoxAdapter(
                  child: SizedBox(height: MediaQuery.of(context).padding.bottom + 30),
                ),
              ],
            ),
    );
  }

  Widget _buildAvatar(String? photoUrl) {
    final t = AppThemeData.of(context);
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.accent.withOpacity(0.3), t.accent.withOpacity(0.1)],
        ),
        border: Border.all(color: t.accent.withOpacity(0.4), width: 3),
        boxShadow: [
          BoxShadow(color: t.accent.withOpacity(0.15), blurRadius: 16, spreadRadius: 2),
        ],
      ),
      child: ClipOval(
        child: photoUrl != null
            ? Image.network(photoUrl, fit: BoxFit.cover,
                errorBuilder: (c, e, s) => _buildDefaultAvatar())
            : _buildDefaultAvatar(),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Center(
      child: Text('😊', style: const TextStyle(fontSize: 38)),
    );
  }

  Widget _buildStatsRow() {
    final streak = VictoryScoringService.I.getCurrentStreak();
    final victories = _userData?.victoryDays ?? 0;
    final memberDate = _formatDate(_userData?.createdAt);

    return Row(
      children: [
        _buildStatChip('🔥', '$streak', 'Racha'),
        const SizedBox(width: 10),
        _buildStatChip('🏆', '$victories', 'Victorias'),
        const SizedBox(width: 10),
        _buildStatChip('📅', memberDate, 'Miembro'),
      ],
    );
  }

  Widget _buildStatChip(String emoji, String value, String label) {
    final t = AppThemeData.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.cardBorder, width: 1),
          boxShadow: t.cardShadow,
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(value, style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800, color: t.textPrimary)),
            Text(label, style: GoogleFonts.manrope(fontSize: 11, color: t.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsSection() {
    final t = AppThemeData.of(context);
    return Container(
      decoration: t.cardDecoration,
      child: Column(
        children: [
          _buildOptionTile(
            icon: Icons.cloud_upload_rounded,
            title: 'Sincronizar datos',
            subtitle: 'Respaldar en la nube',
            onTap: _syncData,
          ),
          Divider(height: 1, indent: 60, endIndent: 16, color: t.divider),
          _buildOptionTile(
            icon: Icons.download_rounded,
            title: 'Exportar mi progreso',
            subtitle: 'Descargar mis datos',
            onTap: () {},
          ),
          Divider(height: 1, indent: 60, endIndent: 16, color: t.divider),
          _buildOptionTile(
            icon: Icons.delete_outline_rounded,
            title: 'Eliminar cuenta',
            subtitle: 'Esta acción es irreversible',
            onTap: _confirmDeleteAccount,
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final t = AppThemeData.of(context);
    const danger = AppDesignSystem.struggle;
    final color = isDestructive ? danger : t.accent;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDestructive ? danger : t.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.manrope(fontSize: 12, color: t.textSecondary),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: t.textSecondary.withOpacity(0.5), size: 20),
      onTap: onTap,
    );
  }

  Widget _buildLogoutButton() {
    final t = AppThemeData.of(context);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _handleLogout,
        icon: Icon(Icons.logout_rounded, size: 18, color: t.textSecondary),
        label: Text(
          'Cerrar Sesión',
          style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: t.textSecondary,
          side: BorderSide(color: t.textSecondary.withOpacity(0.25)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Future<void> _syncData() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Datos sincronizados ✓'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  Future<void> _handleLogout() async {
    await _authService.signOut();
    
    // Notificar callback si existe
    if (widget.onLogout != null) {
      widget.onLogout!();
    }
    
    // IMPORTANTE: Solo volver a la raíz. El StreamBuilder en main.dart
    // detectará que el usuario ya no está autenticado y mostrará LoginScreen.
    // NO hacer pushAndRemoveUntil a LoginScreen porque eso destruye la raíz
    // (StreamBuilder + ProfileGate) y las siguientes sesiones no verifican perfil.
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Eliminar cuenta?'),
        content: const Text(
          'Se eliminarán todos tus datos de forma permanente. '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext); // Cerrar el diálogo primero
              await _deleteAccount();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.emergencyColor,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    // Mostrar indicador de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Usar el nuevo método robusto de AuthService
      final result = await _authService.deleteAccountAndAllData();
      
      if (mounted) {
        Navigator.pop(context); // Cerrar indicador de carga
      }
      
      _handleDeleteResult(result);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Cerrar indicador de carga
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.emergencyColor,
          ),
        );
      }
    }
  }
  
  /// Mostrar diálogo de re-autenticación
  void _showReauthDialog({
    required bool isGoogleAuth,
    required bool isPasswordAuth,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final passwordController = TextEditingController();
        bool isLoading = false;
        // Dispose controller when dialog closes
        void disposeController() => passwordController.dispose();
        
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Verificación de Seguridad'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Por seguridad, necesitas verificar tu identidad antes de eliminar tu cuenta.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  
                  // Si es usuario de contraseña, mostrar campo
                  if (isPasswordAuth) ...[
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Tu contraseña',
                        hintText: 'Ingresa tu contraseña actual',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.lock_outline),
                      ),
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 8),
                  ],
                  
                  // Si es usuario de Google
                  if (isGoogleAuth && !isPasswordAuth) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.blue.shade900.withOpacity(0.3) : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Se abrirá Google para verificar tu identidad.',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  // Usuario puede tener ambos métodos
                  if (isGoogleAuth && isPasswordAuth) ...[
                    const SizedBox(height: 12),
                    Text(
                      'O usa tu cuenta de Google:',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () {
                    disposeController();
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancelar'),
                ),
                
                // Botón de Google si aplica
                if (isGoogleAuth)
                  TextButton.icon(
                    onPressed: isLoading 
                        ? null 
                        : () async {
                            setState(() => isLoading = true);
                            disposeController();
                            Navigator.pop(dialogContext);
                            await _deleteWithGoogleReauth();
                          },
                    icon: isLoading 
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.g_mobiledata, size: 20),
                    label: const Text('Con Google'),
                  ),
                
                // Botón de contraseña si aplica
                if (isPasswordAuth)
                  ElevatedButton(
                    onPressed: isLoading 
                        ? null 
                        : () async {
                            final password = passwordController.text.trim();
                            if (password.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Ingresa tu contraseña'),
                                  backgroundColor: AppTheme.emergencyColor,
                                ),
                              );
                              return;
                            }
                            setState(() => isLoading = true);
                            disposeController();
                            Navigator.pop(dialogContext);
                            await _deleteWithPasswordReauth(password);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.emergencyColor,
                    ),
                    child: isLoading 
                        ? const SizedBox(
                            width: 16, 
                            height: 16, 
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Eliminar'),
                  ),
              ],
            );
          },
        );
      },
    );
  }
  
  /// Eliminar con re-autenticación de contraseña
  Future<void> _deleteWithPasswordReauth(String password) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    try {
      final result = await _authService.deleteAccountAndAllData(
        passwordForReauth: password,
      );
      
      if (mounted) {
        Navigator.pop(context); // Cerrar loading
      }
      
      _handleDeleteResult(result);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.emergencyColor,
          ),
        );
      }
    }
  }
  
  /// Eliminar con re-autenticación de Google
  Future<void> _deleteWithGoogleReauth() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    try {
      final result = await _authService.deleteAccountAndAllData(
        forceGoogleReauth: true,
      );
      
      if (mounted) {
        Navigator.pop(context); // Cerrar loading
      }
      
      _handleDeleteResult(result);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.emergencyColor,
          ),
        );
      }
    }
  }
  
  /// Manejar resultado de eliminación
  /// CORREGIDO: Usa DeleteAccountResult en lugar de AuthResult
  /// CORREGIDO: NO muestra "éxito" si Cloud Function falló
  /// CORREGIDO: Navega con removeUntil para evitar "back" a Home
  void _handleDeleteResult(DeleteAccountResult result) {
    if (!mounted) return;
    
    switch (result.status) {
      case DeleteAccountStatus.success:
        // ✅ SOLO mostrar éxito si Cloud Function realmente funcionó
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cuenta y todos los datos eliminados correctamente'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        
        // Navegar a Login Y LIMPIAR STACK (evita "back" a Home)
        _navigateToLoginAndClearStack();
        break;
        
      case DeleteAccountStatus.cloudFunctionFailed:
        // ❌ Cloud Function falló - NO mostrar "éxito"
        // La memoria ya fue limpiada, pero el usuario puede seguir en Auth
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'No se pudo eliminar la cuenta en el servidor'),
            backgroundColor: AppTheme.emergencyColor,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Soporte',
              textColor: Colors.white,
              onPressed: () {
                launchUrl(
                  Uri.parse('mailto:soporte@victoriaencristo.app?subject=Problema%20al%20eliminar%20cuenta'),
                  mode: LaunchMode.externalApplication,
                );
              },
            ),
          ),
        );
        
        // Igual navegar a login porque la sesión quedó cerrada
        _navigateToLoginAndClearStack();
        break;
        
      case DeleteAccountStatus.requiresReauth:
        // 🔐 Necesita re-autenticación
        _showReauthDialog(
          isGoogleAuth: result.isGoogleAuth,
          isPasswordAuth: result.isPasswordAuth,
        );
        break;
        
      case DeleteAccountStatus.error:
        // ❌ Error genérico
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Error al eliminar cuenta'),
            backgroundColor: AppTheme.emergencyColor,
            duration: const Duration(seconds: 4),
          ),
        );
        break;
    }
  }
  
  /// Navegar a la raíz y dejar que StreamBuilder maneje la navegación
  /// Después de eliminar cuenta, el signOut causa que el StreamBuilder
  /// muestre LoginScreen automáticamente
  void _navigateToLoginAndClearStack() {
    if (!mounted) return;
    
    // Llamar callback de logout si existe (para notificar a widgets padre)
    if (widget.onLogout != null) {
      widget.onLogout!();
    }
    
    // Volver a la raíz - el StreamBuilder detectará signOut y mostrará Login
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    final months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return '${months[date.month - 1]} ${date.year}';
  }
}
