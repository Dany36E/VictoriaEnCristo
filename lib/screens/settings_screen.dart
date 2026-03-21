import 'package:flutter/material.dart';
import '../services/audio_engine.dart';
import '../services/theme_service.dart';
import '../services/notification_service.dart';
import '../services/audio_service.dart';
import '../services/feedback_engine.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onThemeChanged;
  
  const SettingsScreen({super.key, required this.onThemeChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ThemeService _themeService = ThemeService();
  final NotificationService _notificationService = NotificationService();
  final AudioService _audioService = AudioService();

  @override
  void initState() {
    super.initState();
    AudioEngine.I.muteForScreen();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _themeService.initialize();
    await _notificationService.initialize();
    await _audioService.initialize();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Sección de Apariencia
          _buildSectionHeader('🎨 Apariencia', isDark),
          _buildSettingCard(
            isDark: isDark,
            children: [
              _buildSwitchTile(
                title: 'Modo Oscuro',
                subtitle: 'Tema oscuro para uso nocturno',
                icon: Icons.dark_mode,
                value: _themeService.isDarkMode,
                onChanged: (value) async {
                  await _themeService.toggleTheme();
                  widget.onThemeChanged();
                  setState(() {});
                },
                isDark: isDark,
              ),
              const Divider(height: 1),
              _buildSwitchTile(
                title: 'Tema Automático',
                subtitle: 'Cambiar según la hora del día',
                icon: Icons.brightness_auto,
                value: _themeService.autoTheme,
                onChanged: (value) async {
                  await _themeService.setAutoTheme(value);
                  widget.onThemeChanged();
                  setState(() {});
                },
                isDark: isDark,
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Sección de Notificaciones
          _buildSectionHeader('🔔 Notificaciones', isDark),
          _buildSettingCard(
            isDark: isDark,
            children: [
              _buildSwitchTile(
                title: 'Recordatorio Matutino',
                subtitle: 'Versículo del día cada mañana',
                icon: Icons.wb_sunny,
                value: _notificationService.morningEnabled,
                onChanged: (value) async {
                  await _notificationService.setMorningEnabled(value);
                  setState(() {});
                },
                isDark: isDark,
              ),
              if (_notificationService.morningEnabled)
                _buildTimePicker(
                  title: 'Hora de recordatorio matutino',
                  time: _notificationService.morningTime,
                  onChanged: (time) async {
                    await _notificationService.setMorningTime(time);
                    setState(() {});
                  },
                  isDark: isDark,
                ),
              const Divider(height: 1),
              _buildSwitchTile(
                title: 'Recordatorio Nocturno',
                subtitle: 'Registrar tu día de victoria',
                icon: Icons.nightlight_round,
                value: _notificationService.nightEnabled,
                onChanged: (value) async {
                  await _notificationService.setNightEnabled(value);
                  setState(() {});
                },
                isDark: isDark,
              ),
              if (_notificationService.nightEnabled)
                _buildTimePicker(
                  title: 'Hora de recordatorio nocturno',
                  time: _notificationService.nightTime,
                  onChanged: (time) async {
                    await _notificationService.setNightTime(time);
                    setState(() {});
                  },
                  isDark: isDark,
                ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Sección de Audio
          _buildSectionHeader('🎵 Audio', isDark),
          _buildSettingCard(
            isDark: isDark,
            children: [
              // ═══════════════════════════════════════════════════════════════
              // CONTROL DE BGM - Toggle ON/OFF
              // ═══════════════════════════════════════════════════════════════
              ValueListenableBuilder<bool>(
                valueListenable: AudioEngine.I.bgmEnabled,
                builder: (context, isBgmEnabled, _) {
                  return _buildSwitchTile(
                    title: 'Música de Fondo (BGM)',
                    subtitle: 'Worship Pads ambientales',
                    icon: Icons.music_note,
                    value: isBgmEnabled,
                    onChanged: (value) async {
                      final success = await AudioEngine.I.setBgmEnabled(value);
                      if (value && !success && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No se pudo cargar la música'),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    isDark: isDark,
                  );
                },
              ),
              
              // ═══════════════════════════════════════════════════════════════
              // BOTÓN PAUSAR/CONTINUAR - REACTIVO AL ESTADO REAL
              // ═══════════════════════════════════════════════════════════════
              ValueListenableBuilder<BgmPlaybackState>(
                valueListenable: AudioEngine.I.bgmState,
                builder: (context, state, _) {
                  return _buildPlayPauseControl(state, isDark);
                },
              ),
              
              // ═══════════════════════════════════════════════════════════════
              // SLIDER VOLUMEN BGM
              // ═══════════════════════════════════════════════════════════════
              ValueListenableBuilder<double>(
                valueListenable: AudioEngine.I.bgmVolume,
                builder: (context, volume, _) {
                  return _buildVolumeSlider(
                    label: 'Volumen BGM',
                    value: volume,
                    onChanged: (v) => AudioEngine.I.setBgmVolume(v),
                    isDark: isDark,
                  );
                },
              ),
              
              const Divider(height: 1),
              
              // ═══════════════════════════════════════════════════════════════
              // CONTROL DE VIBRACIÓN (Haptics) - FeedbackEngine
              // ═══════════════════════════════════════════════════════════════
              ValueListenableBuilder<bool>(
                valueListenable: FeedbackEngine.I.hapticsEnabled,
                builder: (context, isHapticsEnabled, _) {
                  return _buildSwitchTile(
                    title: 'Vibración (Haptics)',
                    subtitle: 'Feedback táctil sutil en botones',
                    icon: Icons.vibration,
                    value: isHapticsEnabled,
                    onChanged: (value) async {
                      await FeedbackEngine.I.setHapticsEnabled(value);
                      if (value) {
                        FeedbackEngine.I.tap();
                      }
                    },
                    isDark: isDark,
                  );
                },
              ),
              
              const Divider(height: 1),
              
              // ═══════════════════════════════════════════════════════════════
              // CONTROL DE SFX UI - FeedbackEngine
              // ═══════════════════════════════════════════════════════════════
              ValueListenableBuilder<bool>(
                valueListenable: FeedbackEngine.I.sfxEnabled,
                builder: (context, isSfxEnabled, _) {
                  return _buildSwitchTile(
                    title: 'Efectos de Sonido (SFX)',
                    subtitle: 'Clicks y selecciones sutiles',
                    icon: Icons.touch_app,
                    value: isSfxEnabled,
                    onChanged: (value) async {
                      await FeedbackEngine.I.setSfxEnabled(value);
                      if (value) {
                        FeedbackEngine.I.confirm();
                      }
                    },
                    isDark: isDark,
                  );
                },
              ),
              
              // ═══════════════════════════════════════════════════════════════
              // SLIDER VOLUMEN SFX - FeedbackEngine
              // ═══════════════════════════════════════════════════════════════
              ValueListenableBuilder<double>(
                valueListenable: FeedbackEngine.I.sfxVolume,
                builder: (context, volume, _) {
                  return _buildVolumeSlider(
                    label: 'Volumen SFX',
                    value: volume,
                    onChanged: (v) => FeedbackEngine.I.setSfxVolume(v),
                    isDark: isDark,
                  );
                },
              ),
              
              const Divider(height: 1),
              _buildSwitchTile(
                title: 'Lectura en Voz Alta',
                subtitle: 'Reproducción de oraciones y versículos',
                icon: Icons.volume_up,
                value: _audioService.audioEnabled,
                onChanged: (value) async {
                  await _audioService.setAudioEnabled(value);
                  setState(() {});
                },
                isDark: isDark,
              ),
              if (_audioService.audioEnabled) ...[
                const Divider(height: 1),
                _buildSpeedSelector(isDark),
              ],
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Panel de Diagnóstico de Audio
          _buildSectionHeader('🔧 Diagnóstico de Audio', isDark),
          _buildAudioDiagnosticPanel(isDark),
          
          const SizedBox(height: 24),
          
          // Sección Widget de Inicio
          _buildSectionHeader('📱 Widget de Inicio', isDark),
          _buildSettingCard(
            isDark: isDark,
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.widgets, color: AppTheme.primaryColor),
                ),
                title: Text(
                  'Configurar Widget',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                  ),
                ),
                subtitle: Text(
                  'Personaliza el widget de tu pantalla de inicio',
                  style: TextStyle(
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                ),
                onTap: () {
                  Navigator.pushNamed(context, '/widget-settings');
                },
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Sección Acerca de
          _buildSectionHeader('ℹ️ Acerca de', isDark),
          _buildSettingCard(
            isDark: isDark,
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.shield, color: AppTheme.accentColor),
                ),
                title: Text(
                  'Victoria en Cristo',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                  ),
                ),
                subtitle: Text(
                  'Versión 1.0.0',
                  style: TextStyle(
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.favorite, color: Colors.red),
                ),
                title: Text(
                  'Hecho con amor',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                  ),
                ),
                subtitle: Text(
                  'Para la gloria de Dios',
                  style: TextStyle(
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
        ),
      ),
    );
  }

  Widget _buildSettingCard({required List<Widget> children, required bool isDark}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (isDark ? AppTheme.darkPrimary : AppTheme.primaryColor).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isDark ? AppTheme.darkPrimary : AppTheme.primaryColor,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: isDark ? AppTheme.darkAccent : AppTheme.accentColor,
      ),
    );
  }

  Widget _buildTimePicker({
    required String title,
    required TimeOfDay time,
    required ValueChanged<TimeOfDay> onChanged,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: 48),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: time,
              );
              if (picked != null) {
                onChanged(picked);
              }
            },
            child: Text(
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.darkAccent : AppTheme.accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedSelector(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Velocidad de reproducción',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildSpeedChip(0.75, isDark),
              const SizedBox(width: 8),
              _buildSpeedChip(1.0, isDark),
              const SizedBox(width: 8),
              _buildSpeedChip(1.25, isDark),
              const SizedBox(width: 8),
              _buildSpeedChip(1.5, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedChip(double speed, bool isDark) {
    final isSelected = _audioService.audioSpeed == speed;
    return GestureDetector(
      onTap: () async {
        await _audioService.setAudioSpeed(speed);
        setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppTheme.darkAccent : AppTheme.accentColor)
              : (isDark ? AppTheme.darkSurface : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '${speed}x',
          style: TextStyle(
            color: isSelected
                ? (isDark ? Colors.black87 : Colors.white)
                : (isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// BOTÓN PAUSAR/CONTINUAR/REPRODUCIR
  /// Reacciona al estado REAL del player
  /// ═══════════════════════════════════════════════════════════════════════════
  Widget _buildPlayPauseControl(BgmPlaybackState state, bool isDark) {
    // Determinar texto e icono según estado
    String buttonText;
    IconData buttonIcon;
    VoidCallback? onPressed;
    Color buttonColor;
    
    switch (state) {
      case BgmPlaybackState.playing:
        buttonText = 'Pausar';
        buttonIcon = Icons.pause;
        buttonColor = Colors.orange;
        onPressed = () => AudioEngine.I.pauseBgm();
        break;
      case BgmPlaybackState.paused:
        buttonText = 'Continuar';
        buttonIcon = Icons.play_arrow;
        buttonColor = Colors.green;
        onPressed = () => AudioEngine.I.resumeBgm();
        break;
      case BgmPlaybackState.stopped:
        buttonText = 'Reproducir';
        buttonIcon = Icons.play_arrow;
        buttonColor = Colors.blue;
        onPressed = () => AudioEngine.I.startBgm();
        break;
      case BgmPlaybackState.loading:
        buttonText = 'Cargando...';
        buttonIcon = Icons.hourglass_empty;
        buttonColor = Colors.grey;
        onPressed = null;
        break;
      case BgmPlaybackState.error:
        buttonText = 'Reintentar';
        buttonIcon = Icons.refresh;
        buttonColor = Colors.red;
        onPressed = () => AudioEngine.I.startBgm();
        break;
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: 48),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: AudioEngine.I.bgmEnabled.value ? onPressed : null,
              icon: Icon(buttonIcon, size: 18),
              label: Text(buttonText),
              style: ElevatedButton.styleFrom(
                backgroundColor: AudioEngine.I.bgmEnabled.value ? buttonColor : Colors.grey,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          // Botón MUTE
          const SizedBox(width: 8),
          ValueListenableBuilder<bool>(
            valueListenable: AudioEngine.I.bgmMuted,
            builder: (context, isMuted, _) {
              return IconButton(
                onPressed: AudioEngine.I.bgmEnabled.value
                    ? () => AudioEngine.I.toggleMuteBgm()
                    : null,
                icon: Icon(
                  isMuted ? Icons.volume_off : Icons.volume_up,
                  color: isMuted ? Colors.red : Colors.green,
                  size: 24,
                ),
                tooltip: isMuted ? 'Unmute' : 'Mute',
              );
            },
          ),
        ],
      ),
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// SLIDER DE VOLUMEN
  /// ═══════════════════════════════════════════════════════════════════════════
  Widget _buildVolumeSlider({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: isDark ? AppTheme.darkAccent : AppTheme.accentColor,
                thumbColor: isDark ? AppTheme.darkAccent : AppTheme.accentColor,
                overlayColor: (isDark ? AppTheme.darkAccent : AppTheme.accentColor).withOpacity(0.2),
              ),
              child: Slider(
                value: value,
                min: 0.0,
                max: 1.0,
                divisions: 10,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '${(value * 100).toInt()}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Panel de Diagnóstico de Audio para debug
  Widget _buildAudioDiagnosticPanel(bool isDark) {
    final audioEngine = AudioEngine.I;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.orange.withOpacity(0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.bug_report, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Text(
                'DEBUG PANEL v2.0',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Estado - REACTIVO con ValueListenableBuilder
          ValueListenableBuilder<BgmPlaybackState>(
            valueListenable: audioEngine.bgmState,
            builder: (context, state, _) {
              return Column(
                children: [
                  _buildDiagnosticRow('Inicializado', audioEngine.isInitialized ? '✅ Sí' : '❌ No', isDark),
                  _buildDiagnosticRow('BGM State', state.toString().split('.').last.toUpperCase(), isDark),
                  _buildDiagnosticRow('BGM Enabled', audioEngine.bgmEnabled.value ? '✅ Sí' : '❌ No', isDark),
                  _buildDiagnosticRow('BGM Muted', audioEngine.bgmMuted.value ? '🔇 Sí' : '🔊 No', isDark),
                  _buildDiagnosticRow('Position', '${audioEngine.bgmPosition.inSeconds}s', isDark),
                  _buildDiagnosticRow('Duration', '${audioEngine.bgmDuration.inSeconds}s', isDark),
                  _buildDiagnosticRow('Volume', '${(audioEngine.bgmVolume.value * 100).toInt()}%', isDark),
                  _buildDiagnosticRow('Current Asset', audioEngine.currentBgmAsset ?? 'ninguno', isDark),
                  _buildDiagnosticRow('BGM Player #', '${audioEngine.bgmPlayerHash}', isDark),
                  _buildDiagnosticRow('SFX Player #', '${audioEngine.sfxPlayerHash}', isDark),
                  if (audioEngine.lastError != null)
                    _buildDiagnosticRow('Last Error', audioEngine.lastError!, isDark, isError: true),
                ],
              );
            },
          ),
          
          const SizedBox(height: 16),
          
          // Slider de volumen BGM - REACTIVO
          ValueListenableBuilder<double>(
            valueListenable: audioEngine.bgmVolume,
            builder: (context, volume, _) {
              return Row(
                children: [
                  Text('BGM Vol:', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
                  Expanded(
                    child: Slider(
                      value: volume,
                      min: 0.0,
                      max: 1.0,
                      divisions: 10,
                      label: '${(volume * 100).toInt()}%',
                      onChanged: (value) async {
                        await audioEngine.setBgmVolume(value);
                      },
                    ),
                  ),
                ],
              );
            },
          ),
          
          const SizedBox(height: 16),
          
          // Botones de test
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    debugPrint('🧪 [SETTINGS] Test SFX button pressed');
                    final success = await audioEngine.testSfx();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success ? '✅ SFX OK' : '❌ SFX FAILED'),
                          backgroundColor: success ? Colors.green : Colors.red,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.volume_up, size: 16),
                  label: const Text('Test SFX'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    debugPrint('🧪 [SETTINGS] Test BGM button pressed');
                    final success = await audioEngine.testBgm();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success ? '✅ BGM OK' : '❌ BGM FAILED'),
                          backgroundColor: success ? Colors.green : Colors.red,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.music_note, size: 16),
                  label: const Text('Test BGM'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Botón para refrescar estado y mostrar reporte
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {});
                debugPrint(audioEngine.getDiagnosticReport());
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Refrescar Estado'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange,
                side: const BorderSide(color: Colors.orange),
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Botón DUMP STATUS (imprime estado completo en consola)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                audioEngine.dumpAudioStatus();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('📋 Status dumped to console'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.bug_report, size: 16),
              label: const Text('Dump Audio Status'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.cyan,
                side: const BorderSide(color: Colors.cyan),
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // 🎯 BOTÓN TEST FEEDBACK ENGINE
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                debugPrint('🧪 [SETTINGS] Test ALL Feedback button pressed');
                await FeedbackEngine.I.testAll();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🎯 Feedback test: tap→select→tab→confirm→paper'),
                      backgroundColor: Colors.teal,
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.touch_app, size: 20),
              label: const Text('🎯 TEST ALL FEEDBACK'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 🛑 BOTÓN KILL SWITCH
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await audioEngine.hardStopAllAudio();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🛑 AUDIO KILLED - All players destroyed'),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 3),
                    ),
                  );
                  setState(() {});
                }
              },
              icon: const Icon(Icons.dangerous, size: 20),
              label: const Text('🛑 KILL ALL AUDIO'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDiagnosticRow(String label, String value, bool isDark, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: isError 
                    ? Colors.red 
                    : (isDark ? Colors.white : Colors.black87),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
