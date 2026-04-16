import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/image_urls.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback? onThemeChanged;

  const LoginScreen({super.key, this.onThemeChanged});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  
  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _acceptedTerms = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // CAPA 1: Imagen de fondo épica (cacheada, misma que Home)
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: ImageUrls.heroMountain,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: const Color(0xFF0D1B2A)),
              errorWidget: (context, url, error) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF1B2838), Color(0xFF0D1B2A)],
                  ),
                ),
              ),
            ),
          ),
          
          // CAPA 2: Overlay gradiente oscuro
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.5),
                    Colors.black.withOpacity(0.7),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          
          // CAPA 3: Contenido principal (NUEVO ORDEN JERÁRQUICO)
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 50),
                  
                  // 1. ENCABEZADO: Logo + Título + Subtítulo
                  _buildHeroLogo(),
                  const SizedBox(height: 40),
                  
                  // 2. ACCIÓN PRINCIPAL: Botón Google (estilo dorado principal)
                  _buildGooglePrimaryButton(),
                  const SizedBox(height: 24),
                  
                  // 3. SEPARADOR MEJORADO: "— o usa tu correo —"
                  _buildEnhancedDivider(),
                  const SizedBox(height: 24),
                  
                  // 4. FORMULARIO SECUNDARIO: Email + Password
                  _buildSecondaryForm(),
                  const SizedBox(height: 20),
                  
                  // 5. ACCIÓN SECUNDARIA: Botón Login (estilo borde dorado)
                  _buildOutlineGoldButton(),
                  const SizedBox(height: 28),
                  
                  // 6. PIE DE PÁGINA: Toggle Login/Register (más visible)
                  _buildEnhancedToggle(),
                  const SizedBox(height: 16),
                  
                  // 7. ACCIÓN INVITADO: Botón con borde sutil
                  _buildGuestOutlineButton(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LOGO HEROICO CON GLOW DIVINO
  // ============================================================
  Widget _buildHeroLogo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Escudo con glow dorado divino
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              // Glow dorado exterior difuso
              BoxShadow(
                color: const Color(0xFFFFD700).withOpacity(0.4),
                blurRadius: 40,
                spreadRadius: 10,
              ),
              // Glow dorado medio
              BoxShadow(
                color: const Color(0xFFFFD700).withOpacity(0.3),
                blurRadius: 25,
                spreadRadius: 5,
              ),
              // Glow interno intenso
              BoxShadow(
                color: const Color(0xFFFFA500).withOpacity(0.2),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFFFD700).withOpacity(0.8),
                  const Color(0xFFFFA500).withOpacity(0.6),
                ],
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.6),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.shield_outlined,
                size: 64,
                color: Colors.white,
              ),
            ),
          ),
        )
            .animate()
            .fadeIn(duration: 800.ms, curve: Curves.easeOut)
            .slideY(begin: -0.5, end: 0, duration: 800.ms, curve: Curves.easeOutBack)
            .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), duration: 600.ms),
        
        const SizedBox(height: 28),
        
        // Título "VICTORIA EN CRISTO" - Blanco con GLOW DORADO
        SizedBox(
          width: double.infinity,
          child: Text(
            'VICTORIA EN CRISTO',
            textAlign: TextAlign.center,
            style: GoogleFonts.cinzel(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: 4,
              color: Colors.white,
              shadows: [
                // Sombra base para legibilidad
                Shadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
                // GLOW DORADO principal
                const Shadow(
                  color: Color(0xFFFFD700),
                  blurRadius: 15,
                  offset: Offset(0, 0),
                ),
                // Glow dorado secundario más difuso
                Shadow(
                  color: const Color(0xFFFFD700).withOpacity(0.5),
                  blurRadius: 30,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
          ),
        )
            .animate()
            .fadeIn(delay: 300.ms, duration: 600.ms)
            .slideY(begin: -0.3, end: 0, curve: Curves.easeOut),
        
        const SizedBox(height: 12),
        
        // Subtítulo
        Text(
          _isLogin 
              ? 'Entra al santuario de tu victoria' 
              : 'Comienza tu camino hacia la libertad',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: Colors.white.withOpacity(0.7),
            letterSpacing: 0.5,
          ),
          textAlign: TextAlign.center,
        )
            .animate()
            .fadeIn(delay: 500.ms, duration: 500.ms),
      ],
    );
  }

  // ============================================================
  // 2. BOTÓN GOOGLE - ACCIÓN PRINCIPAL (Estilo Dorado Sólido)
  // ============================================================
  Widget _buildGooglePrimaryButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        // Gradiente dorado metálico (estilo principal)
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFFB8860B),
            Color(0xFFFFD700),
            Color(0xFFDAA520),
            Color(0xFFB8860B),
          ],
          stops: [0.0, 0.4, 0.6, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withOpacity(0.35),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _handleGoogleSignIn,
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.white24,
          highlightColor: Colors.white10,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icono de Google en contenedor blanco
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(4),
                  child: const Icon(
                    Icons.g_mobiledata,
                    size: 18,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  'Continuar con Google',
                  style: GoogleFonts.lato(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: 600.ms, duration: 500.ms)
        .slideY(begin: 0.3, end: 0, curve: Curves.easeOut);
  }

  // ============================================================
  // 3. SEPARADOR MEJORADO - "— o usa tu correo —"
  // ============================================================
  Widget _buildEnhancedDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.white.withOpacity(0.4),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            '— o usa tu correo —',
            style: GoogleFonts.lato(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.4),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(delay: 700.ms, duration: 400.ms);
  }

  // ============================================================
  // 4. FORMULARIO SECUNDARIO (Email + Password + Forgot)
  // ============================================================
  Widget _buildSecondaryForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Mensaje de error
          if (_errorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.redAccent.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: GoogleFonts.lato(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn()
                .shake(duration: 400.ms),
          
          // ============================================================
          // CAMPO NOMBRE (SOLO EN REGISTRO)
          // ============================================================
          if (!_isLogin) ...[
            _buildGlassTextField(
              controller: _nameController,
              hintText: 'Nombre completo',
              icon: Icons.person_outlined,
              keyboardType: TextInputType.name,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Ingresa tu nombre';
                if (value.length < 2) return 'Nombre muy corto';
                return null;
              },
            )
                .animate()
                .fadeIn(delay: 700.ms, duration: 500.ms)
                .slideY(begin: 0.2, end: 0, curve: Curves.easeOut),
            
            const SizedBox(height: 16),
          ],
          
          // Campo Email
          _buildGlassTextField(
            controller: _emailController,
            hintText: 'Correo electrónico',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Ingresa tu correo';
              if (!value.contains('@')) return 'Correo inválido';
              return null;
            },
          )
              .animate()
              .fadeIn(delay: _isLogin ? 750.ms : 800.ms, duration: 500.ms)
              .slideY(begin: 0.2, end: 0, curve: Curves.easeOut),
          
          const SizedBox(height: 16),
          
          // Campo Password
          _buildGlassTextField(
            controller: _passwordController,
            hintText: 'Contraseña',
            icon: Icons.lock_outlined,
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: Colors.white70,
                size: 22,
              ),
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() => _obscurePassword = !_obscurePassword);
              },
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Ingresa tu contraseña';
              if (!_isLogin && value.length < 6) return 'Mínimo 6 caracteres';
              return null;
            },
          )
              .animate()
              .fadeIn(delay: _isLogin ? 800.ms : 850.ms, duration: 500.ms)
              .slideY(begin: 0.2, end: 0, curve: Curves.easeOut),
          
          // ============================================================
          // CHECKBOX TÉRMINOS Y CONDICIONES (SOLO EN REGISTRO)
          // ============================================================
          if (!_isLogin)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _buildTermsCheckbox(),
            )
                .animate()
                .fadeIn(delay: 900.ms, duration: 400.ms),
          
          // ENLACE "¿Olvidaste tu contraseña?" - SOLO EN LOGIN
          if (_isLogin)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextButton(
                  onPressed: _resetPassword,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  ),
                  child: Text(
                    '¿Olvidaste tu contraseña?',
                    style: GoogleFonts.lato(
                      color: const Color(0xFFFFD700),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            )
                .animate()
                .fadeIn(delay: 850.ms, duration: 400.ms),
        ],
      ),
    );
  }

  // ============================================================
  // CHECKBOX TÉRMINOS Y CONDICIONES - ESTILO CONSISTENTE
  // ============================================================
  Widget _buildTermsCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Checkbox personalizado con estilo dorado
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: _acceptedTerms,
            onChanged: (value) {
              HapticFeedback.selectionClick();
              setState(() => _acceptedTerms = value ?? false);
            },
            activeColor: const Color(0xFFD4AF37),
            checkColor: Colors.black,
            side: BorderSide(
              color: _acceptedTerms 
                  ? const Color(0xFFD4AF37) 
                  : Colors.white.withOpacity(0.5),
              width: 1.5,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Texto del label
        Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _acceptedTerms = !_acceptedTerms);
            },
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.lato(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                ),
                children: [
                  const TextSpan(text: 'He leído y acepto los '),
                  TextSpan(
                    text: 'Términos y Condiciones',
                    style: GoogleFonts.lato(
                      color: const Color(0xFFFFD700),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: const Color(0xFFFFD700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // CAMPO DE TEXTO - ESTILO "OBSIDIAN GLASS" (Dark Premium)
  // ============================================================
  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      // Texto del usuario: BLANCO PURO con Google Fonts
      style: GoogleFonts.lato(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      cursorColor: const Color(0xFFD4AF37), // Cursor dorado
      validator: validator,
      decoration: InputDecoration(
        // CRUCIAL: Relleno oscuro, NO blanco
        filled: true,
        fillColor: Colors.black.withOpacity(0.6),
        
        // Label style: BLANCO 90% - MÁXIMA LEGIBILIDAD
        labelText: hintText,
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.9),
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        floatingLabelStyle: const TextStyle(
          color: Color(0xFFD4AF37), // Dorado cuando flota
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        
        // Hint style: Blanco 50%
        hintStyle: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontSize: 15,
        ),
        
        // Iconos BLANCOS 70%
        prefixIcon: Icon(icon, color: Colors.white70, size: 22),
        suffixIcon: suffixIcon,
        
        // Bordes con OutlineInputBorder
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFD4AF37), // Borde DORADO al enfocar
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.redAccent.withOpacity(0.7),
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Colors.redAccent,
            width: 1.5,
          ),
        ),
        
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        errorStyle: const TextStyle(
          color: Colors.redAccent,
          fontSize: 12,
        ),
      ),
    );
  }

  // ============================================================
  // 5. BOTÓN INICIAR SESIÓN - ESTILO SECUNDARIO (Borde Dorado)
  // ============================================================
  Widget _buildOutlineGoldButton() {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        // Fondo oscuro semitransparente
        color: Colors.black.withOpacity(0.3),
        // Borde dorado visible
        border: Border.all(
          color: const Color(0xFFFFD700),
          width: 1.5,
        ),
        // Sutil glow dorado
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withOpacity(0.15),
            blurRadius: 15,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _handleSubmit,
          borderRadius: BorderRadius.circular(16),
          splashColor: const Color(0xFFFFD700).withOpacity(0.2),
          highlightColor: const Color(0xFFFFD700).withOpacity(0.1),
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      color: Color(0xFFFFD700),
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    _isLogin ? 'INICIAR SESIÓN' : 'CREAR CUENTA',
                    style: GoogleFonts.lato(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: const Color(0xFFFFD700), // Texto dorado
                    ),
                  ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: 900.ms, duration: 500.ms)
        .slideY(begin: 0.2, end: 0, curve: Curves.easeOut);
  }

  // ============================================================
  // 6. TOGGLE LOGIN/REGISTER - MÁS VISIBLE
  // ============================================================
  Widget _buildEnhancedToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _isLogin ? '¿No tienes cuenta?' : '¿Ya tienes cuenta?',
          style: GoogleFonts.lato(
            color: Colors.white.withOpacity(0.85),
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
        ),
        TextButton(
          onPressed: () {
            HapticFeedback.selectionClick();
            setState(() {
              _isLogin = !_isLogin;
              _errorMessage = null;
              _acceptedTerms = false;
              // Limpiar campo nombre al cambiar de modo
              if (_isLogin) _nameController.clear();
            });
          },
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
          child: Text(
            _isLogin ? 'Regístrate' : 'Inicia sesión',
            style: GoogleFonts.lato(
              color: const Color(0xFFFFD700),
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(delay: 950.ms, duration: 400.ms);
  }

  // ============================================================
  // 7. BOTÓN INVITADO - CON BORDE SUTIL VISIBLE
  // ============================================================
  Widget _buildGuestOutlineButton() {
    return Container(
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.transparent,
        border: Border.all(
          color: Colors.white.withOpacity(0.35),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _handleGuestSignIn,
          borderRadius: BorderRadius.circular(14),
          splashColor: Colors.white.withOpacity(0.1),
          highlightColor: Colors.white.withOpacity(0.05),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_outline,
                  color: Colors.white.withOpacity(0.7),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  'Continuar sin cuenta',
                  style: GoogleFonts.lato(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: 1000.ms, duration: 400.ms);
  }

  // ============================================================
  // LÓGICA DE AUTENTICACIÓN
  // ============================================================
  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Validar términos solo en registro
    if (!_isLogin && !_acceptedTerms) {
      setState(() => _errorMessage = 'Debes aceptar los Términos y Condiciones');
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

    setState(() => _isLoading = false);

    if (result.isSuccess) {
      HapticFeedback.heavyImpact();
      // NO navegar manualmente - el StreamBuilder en main.dart detectará
      // el cambio de auth y mostrará ProfileGate (que decide Home vs Onboarding)
      setState(() => _isLoading = true); // Mostrar loading mientras ProfileGate carga
    } else {
      HapticFeedback.heavyImpact();
      setState(() => _errorMessage = result.errorMessage);
    }
  }

  Future<void> _handleGoogleSignIn() async {
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
