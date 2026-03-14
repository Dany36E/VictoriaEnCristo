import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

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
    final data = await _authService.getUserData();
    setState(() {
      _userData = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = _authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Avatar
                  _buildAvatar(isDark, user?.photoURL),
                  const SizedBox(height: 16),
                  
                  // Nombre
                  Text(
                    user?.displayName ?? _userData?.displayName ?? 'Usuario',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  
                  // Email
                  Text(
                    user?.email ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Stats Card
                  _buildStatsCard(isDark),
                  const SizedBox(height: 24),
                  
                  // Opciones
                  _buildOptionsSection(isDark),
                  const SizedBox(height: 32),
                  
                  // Cerrar sesión
                  _buildLogoutButton(isDark),
                  
                  // Safe Area bottom padding
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
                ],
              ),
            ),
    );
  }

  Widget _buildAvatar(bool isDark, String? photoUrl) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: (isDark ? AppTheme.darkPrimary : AppTheme.primaryColor).withOpacity(0.1),
        border: Border.all(
          color: isDark ? AppTheme.darkAccent : AppTheme.accentColor,
          width: 3,
        ),
      ),
      child: ClipOval(
        child: photoUrl != null
            ? Image.network(
                photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(isDark),
              )
            : _buildDefaultAvatar(isDark),
      ),
    );
  }

  Widget _buildDefaultAvatar(bool isDark) {
    return Icon(
      Icons.person,
      size: 50,
      color: isDark ? AppTheme.darkPrimary : AppTheme.primaryColor,
    );
  }

  Widget _buildStatsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              '🏆',
              '${_userData?.victoryDays ?? 0}',
              'Días de Victoria',
              isDark,
            ),
          ),
          Container(
            width: 1,
            height: 50,
            color: isDark ? AppTheme.darkTextSecondary.withOpacity(0.3) : Colors.grey.shade200,
          ),
          Expanded(
            child: _buildStatItem(
              '📅',
              _formatDate(_userData?.createdAt),
              'Miembro desde',
              isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String emoji, String value, String label, bool isDark) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildOptionsSection(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          _buildOptionTile(
            icon: Icons.cloud_upload,
            title: 'Sincronizar datos',
            subtitle: 'Última sync: ahora',
            onTap: _syncData,
            isDark: isDark,
          ),
          Divider(height: 1, color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
          _buildOptionTile(
            icon: Icons.download,
            title: 'Exportar mi progreso',
            subtitle: 'Descargar datos',
            onTap: () {},
            isDark: isDark,
          ),
          Divider(height: 1, color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
          _buildOptionTile(
            icon: Icons.delete_outline,
            title: 'Eliminar cuenta',
            subtitle: 'Esta acción es irreversible',
            onTap: _confirmDeleteAccount,
            isDark: isDark,
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
    required bool isDark,
    bool isDestructive = false,
  }) {
    final color = isDestructive
        ? AppTheme.emergencyColor
        : (isDark ? AppTheme.darkPrimary : AppTheme.primaryColor);

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDestructive
              ? AppTheme.emergencyColor
              : (isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
      ),
      onTap: onTap,
    );
  }

  Widget _buildLogoutButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _handleLogout,
        icon: const Icon(Icons.logout),
        label: const Text('Cerrar Sesión'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.emergencyColor,
          side: const BorderSide(color: AppTheme.emergencyColor),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
                  onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                
                // Botón de Google si aplica
                if (isGoogleAuth)
                  TextButton.icon(
                    onPressed: isLoading 
                        ? null 
                        : () async {
                            setState(() => isLoading = true);
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
                            final password = passwordController.text;
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
                // TODO: Abrir link de soporte
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
