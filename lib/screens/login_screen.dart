import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../theme/app_fonts.dart';
import '../constants/legal_urls.dart';
import '../services/auth_service.dart';
import '../services/privacy_preferences_service.dart';
import '../utils/platform_capabilities.dart';
import '../vec/vec_tema.dart';
import '../vec/vec_widgets.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback? onThemeChanged;

  const LoginScreen({super.key, this.onThemeChanged});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const bool _autoLaunchGoogleSignIn = bool.fromEnvironment(
    'WINDOWS_AUTOLAUNCH_GOOGLE_SIGNIN',
  );
  static const bool _appleSignInEnabled = bool.fromEnvironment(
    'APPLE_SIGN_IN_ENABLED',
  );

  AuthService? _authServiceInstance;
  AuthService get _authService => _authServiceInstance ??= AuthService();
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _acceptedTerms = false;
  bool _acceptedSensitiveData = false;
  String? _errorMessage;

  bool get _supportsGoogleSignIn => PlatformCapabilities.supportsGoogleSignIn;
  bool get _supportsAppleSignIn =>
      _appleSignInEnabled && PlatformCapabilities.supportsAppleSignIn;

  @override
  void initState() {
    super.initState();

    if (_autoLaunchGoogleSignIn &&
        PlatformCapabilities.supportsFirebaseAuthProviderSignIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _isLoading || !_supportsGoogleSignIn) return;
        _handleGoogleSignIn();
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _buildPapel(context);
  }

  // ============================================================
  // LOGO HEROICO CON GLOW DIVINO
  // ============================================================

  // ============================================================
  // 2. BOTÓN GOOGLE - ACCIÓN PRINCIPAL (Estilo Dorado Sólido)
  // ============================================================

  Widget _buildAppleButton() {
    return SizedBox(
      width: double.infinity,
      child: SignInWithAppleButton(
        onPressed: _isLoading ? null : _handleAppleSignIn,
        text: 'Continuar con Apple',
        height: 56,
        style: SignInWithAppleButtonStyle.whiteOutlined,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
      ),
    ).animate().fadeIn(delay: 650.ms, duration: 450.ms);
  }

  // ============================================================
  // 3. SEPARADOR MEJORADO - "— o usa tu correo —"
  // ============================================================

  // ============================================================
  // 4. FORMULARIO SECUNDARIO (Email + Password + Forgot)
  // ============================================================

  // ============================================================
  // CHECKBOX TÉRMINOS Y CONDICIONES - ESTILO CONSISTENTE
  // ============================================================

  // ============================================================
  // CAMPO DE TEXTO - ESTILO "OBSIDIAN GLASS" (Dark Premium)
  // ============================================================

  // ============================================================
  // 5. BOTÓN INICIAR SESIÓN - ESTILO SECUNDARIO (Borde Dorado)
  // ============================================================

  // ============================================================
  // 6. TOGGLE LOGIN/REGISTER - MÁS VISIBLE
  // ============================================================

  // ============================================================
  // 7. BOTÓN INVITADO - CON BORDE SUTIL VISIBLE
  // ============================================================

  // ============================================================
  // PAPEL RECORTADO — portada con letrero y personajes, formulario en
  // tarjeta de papel (kit victoria-en-cristo-estilo)
  // ============================================================
  Widget _buildPapel(BuildContext context) {
    final isDesktop = PlatformCapabilities.isDesktop;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: isDesktop
              ? const ClampingScrollPhysics()
              : const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 20),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isDesktop ? 440 : double.infinity,
              ),
              child: Column(
                children: [
                  const SizedBox(height: 28),
                  const PopIn(
                    child: Letrero(
                      'VICTORIA EN CRISTO',
                      clave: 'CRISTO',
                      tamano: 40,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // La pareja de los videos, como en la portada del kit.
                  const PopIn(
                    retraso: Duration(milliseconds: 120),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Sticker(
                          'assets/vec/personajes/timoteo_saludo.png',
                          alto: 190,
                          giro: -2,
                        ),
                        Sticker(
                          'assets/vec/personajes/victoria_saludo.png',
                          alto: 190,
                          giro: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  PopIn(
                    retraso: const Duration(milliseconds: 200),
                    child: Subtitulo(
                      quien: _isLogin ? 'Victoria' : 'Timoteo',
                      color: _isLogin ? VecColores.terracota : VecColores.azul,
                      texto: _isLogin
                          ? 'Entra al santuario de tu victoria'
                          : 'Comienza tu camino hacia la libertad',
                      clave: _isLogin ? 'victoria' : 'libertad',
                    ),
                  ),
                  const SizedBox(height: 30),
                  if (_supportsGoogleSignIn || _supportsAppleSignIn) ...[
                    if (_supportsGoogleSignIn)
                      BotonVec(
                        texto: 'Continuar con Google',
                        icono: Icons.g_mobiledata,
                        color: VecColores.papel,
                        colorTexto: VecColores.tinta,
                        expandido: true,
                        onPressed: _isLoading ? null : _handleGoogleSignIn,
                      ),
                    if (_supportsGoogleSignIn && _supportsAppleSignIn)
                      const SizedBox(height: 16),
                    if (_supportsAppleSignIn) _buildAppleButton(),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: Divider(color: VecColores.cremaOscuro),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'o usa tu correo',
                            style: AppFonts.manrope(
                              fontSize: 15,
                              color: VecColores.gris,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(color: VecColores.cremaOscuro),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                  ],
                  PopIn(
                    retraso: const Duration(milliseconds: 260),
                    child: TarjetaPapel(
                      padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_errorMessage != null) _buildErrorPapel(),
                            if (!_isLogin) ...[
                              _buildCampoPapel(
                                controller: _nameController,
                                label: 'Nombre completo',
                                icon: Icons.person_rounded,
                                keyboardType: TextInputType.name,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.name],
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Ingresa tu nombre';
                                  }
                                  if (value.length < 2) {
                                    return 'Nombre muy corto';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                            ],
                            _buildCampoPapel(
                              controller: _emailController,
                              label: 'Correo electrónico',
                              icon: Icons.email_rounded,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Ingresa tu correo';
                                }
                                if (!value.contains('@')) {
                                  return 'Correo inválido';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildCampoPapel(
                              controller: _passwordController,
                              label: 'Contraseña',
                              icon: Icons.lock_rounded,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              autofillHints: _isLogin
                                  ? const [AutofillHints.password]
                                  : const [AutofillHints.newPassword],
                              onFieldSubmitted: (_) => _handleSubmit(),
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? 'Mostrar contraseña'
                                    : 'Ocultar contraseña',
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                ),
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  );
                                },
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Ingresa tu contraseña';
                                }
                                if (!_isLogin && value.length < 8) {
                                  return 'Mínimo 8 caracteres';
                                }
                                return null;
                              },
                            ),
                            if (!_isLogin) ...[
                              const SizedBox(height: 12),
                              _buildTerminosPapel(),
                            ],
                            if (_isLogin)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _resetPassword,
                                  child: const Text('¿Olvidaste tu contraseña?'),
                                ),
                              ),
                            const SizedBox(height: 14),
                            Center(
                              child: BotonVec(
                                texto: _isLogin
                                    ? 'Iniciar sesión'
                                    : 'Crear cuenta',
                                iconoWidget: const IconoVec('escudo'),
                                cargando: _isLoading,
                                expandido: true,
                                onPressed: _handleSubmit,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        _isLogin ? '¿No tienes cuenta?' : '¿Ya tienes cuenta?',
                        style: AppFonts.manrope(
                          fontSize: 16,
                          color: VecColores.tinta,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _isLogin = !_isLogin;
                            _errorMessage = null;
                            _acceptedTerms = false;
                            _acceptedSensitiveData = false;
                            if (_isLogin) _nameController.clear();
                          });
                        },
                        child: Text(_isLogin ? 'Regístrate' : 'Inicia sesión'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  BotonVec(
                    texto: 'Continuar sin cuenta',
                    iconoWidget: const IconoVec('personas'),
                    color: VecColores.papel,
                    colorTexto: VecColores.tinta,
                    onPressed: _isLoading ? null : _handleGuestSignIn,
                  ),
                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Campo del kit (.vec-campo): borde de tinta de 4 px, texto Patrick Hand.
  Widget _buildCampoPapel({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    TextInputAction? textInputAction,
    Iterable<String>? autofillHints,
    ValueChanged<String>? onFieldSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      cursorColor: VecColores.terracota,
      style: TextStyle(
        fontFamily: VecFuentes.texto,
        fontSize: 20,
        color: VecColores.azulClaro,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
      ),
    );
  }

  /// Aviso de error en papel: casilla terracota clara con ícono relleno.
  Widget _buildErrorPapel() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      decoration: BoxDecoration(
        color: VecColores.terracota.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(VecRadios.s),
      ),
      child: Row(
        children: [
          const CirculoIcono(
            icono: Icons.priority_high_rounded,
            tamano: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                fontFamily: VecFuentes.texto,
                fontSize: 17,
                height: 1.25,
                color: VecColores.tinta,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerminosPapel() {
    final etiqueta = TextStyle(
      fontFamily: VecFuentes.texto,
      fontSize: 16,
      height: 1.25,
      color: VecColores.tinta,
    );
    return Column(
      children: [
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _acceptedTerms,
          onChanged: (value) {
            HapticFeedback.selectionClick();
            setState(() => _acceptedTerms = value ?? false);
          },
          title: Text(
            'He leído y acepto los Términos y Condiciones.',
            style: etiqueta,
          ),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _acceptedSensitiveData,
          onChanged: (value) {
            HapticFeedback.selectionClick();
            setState(() => _acceptedSensitiveData = value ?? false);
          },
          title: Text(
            'Consiento expresamente el tratamiento de los datos sensibles '
            'que decida registrar, según el Aviso de Privacidad.',
            style: etiqueta,
          ),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 4,
          children: [
            TextButton(
              onPressed: () => launchUrl(
                legalDocumentUri('terms.html'),
                mode: LaunchMode.externalApplication,
              ),
              child: const Text('Leer términos'),
            ),
            TextButton(
              onPressed: () => launchUrl(
                legalDocumentUri('privacy_policy.html'),
                mode: LaunchMode.externalApplication,
              ),
              child: const Text('Leer aviso de privacidad'),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // LÓGICA DE AUTENTICACIÓN
  // ============================================================
  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    // Validar términos solo en registro
    if (!_isLogin && !_acceptedTerms) {
      setState(
        () => _errorMessage = 'Debes aceptar los Términos y Condiciones',
      );
      return;
    }
    if (!_isLogin && !_acceptedSensitiveData) {
      setState(
        () => _errorMessage =
            'Debes decidir si consientes el tratamiento de datos sensibles',
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    AuthResult result;
    if (_isLogin) {
      result = await _authService.signInWithEmail(
        _emailController.text,
        _passwordController.text,
      );
    } else {
      // Usar el nombre ingresado en lugar de extraer del email
      result = await _authService.registerWithEmail(
        _emailController.text,
        _passwordController.text,
        _nameController.text.trim(),
      );
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.isSuccess) {
      if (!_isLogin) {
        await PrivacyPreferencesService.I.acceptRequiredConsent();
      }
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      // NO navegar manualmente - el StreamBuilder en main.dart detectará
      // el cambio de auth y mostrará ProfileGate (que decide Home vs Onboarding)
      if (mounted) setState(() => _isLoading = true);
    } else {
      HapticFeedback.heavyImpact();
      if (mounted) setState(() => _errorMessage = result.errorMessage);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (!_supportsGoogleSignIn) {
      setState(
        () => _errorMessage =
            'Google no está disponible en ${PlatformCapabilities.currentLabel}. Usa correo y contraseña.',
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _authService.signInWithGoogle();

    // Verificar si el widget sigue montado después de la operación async
    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result.isSuccess) {
      HapticFeedback.heavyImpact();
      // NO navegar manualmente - el StreamBuilder en main.dart detectará
      // el cambio de auth y mostrará ProfileGate (que decide Home vs Onboarding)
      if (mounted) setState(() => _isLoading = true);
    } else {
      if (mounted) {
        setState(() => _errorMessage = result.errorMessage);
      }
    }
  }

  Future<void> _handleAppleSignIn() async {
    if (!_supportsAppleSignIn) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _authService.signInWithApple();
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.isSuccess) {
      HapticFeedback.heavyImpact();
      setState(() => _isLoading = true);
    } else {
      setState(() => _errorMessage = result.errorMessage);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Ingresa tu correo para restablecer');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);
    final result = await _authService.resetPassword(email);
    setState(() => _isLoading = false);

    if (result.isSuccess) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Se envió un correo para restablecer tu contraseña',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } else {
      setState(() => _errorMessage = result.errorMessage);
    }
  }

  Future<void> _handleGuestSignIn() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _authService.signInAnonymously();

    // Verificar si el widget sigue montado después de la operación async
    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result.isSuccess) {
      // El StreamBuilder en main.dart detectará el cambio de auth
      // y navegará automáticamente al onboarding o home
    } else {
      if (mounted) {
        setState(() => _errorMessage = result.errorMessage);
      }
    }
  }

  // _navigateToHome ELIMINADO: La navegación post-login es 100% manejada
  // por el StreamBuilder + ProfileGate en main.dart.
  // Cuando Firebase Auth detecta el cambio, StreamBuilder rebuilds y
  // ProfileGate verifica el perfil en cloud para decidir Home vs Onboarding.
}
