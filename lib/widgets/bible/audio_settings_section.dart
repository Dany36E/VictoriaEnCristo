import 'package:flutter/material.dart';
import '../../models/bible/bible_version.dart';
import '../../services/bible/bible_audio_settings.dart';
import '../../services/bible/bible_tts_service.dart';
import '../../theme/app_fonts.dart';
import '../../theme/bible_reader_theme.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// AUDIO SETTINGS SECTION — Ajustes del audio bíblico para la pantalla de
/// ajustes de la Biblia: velocidad, avance automático y voz sintética
/// (español e inglés). Todo se guarda en [BibleAudioSettings].
/// ═══════════════════════════════════════════════════════════════════════════
class AudioSettingsSection extends StatelessWidget {
  final BibleReaderThemeData theme;

  /// Muestra el título «AUDIO» con el estilo de las secciones de ajustes.
  final bool showTitle;

  const AudioSettingsSection({
    super.key,
    required this.theme,
    this.showTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final settings = BibleAudioSettings.I;
    settings.ensureLoaded();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTitle)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Semantics(
              header: true,
              child: Text(
                'AUDIO',
                style: AppFonts.manrope(
                  color: t.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                ),
              ),
            ),
          ),
        _Card(
          theme: t,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Title(
                theme: t,
                icon: Icons.speed_rounded,
                title: 'Velocidad de lectura',
                subtitle: 'Para la voz sintética y el audio narrado',
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<double>(
                valueListenable: settings.speed,
                builder: (context, speed, _) {
                  return Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final s in BibleAudioSettings.speeds)
                        ChoiceChip(
                          label: Text(
                            BibleAudioSettings.speedLabel(s),
                            semanticsLabel:
                                'Velocidad ${BibleAudioSettings.speedLabel(s)}',
                          ),
                          selected: s == speed,
                          onSelected: (_) => settings.setSpeed(s),
                          showCheckmark: false,
                          selectedColor: t.accent,
                          backgroundColor: t.textPrimary.withValues(
                            alpha: 0.05,
                          ),
                          side: BorderSide(
                            color: t.accent.withValues(alpha: 0.3),
                          ),
                          labelStyle: AppFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: s == speed ? t.sobreAcento : t.textPrimary,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<bool>(
          valueListenable: settings.autoAdvance,
          builder: (context, on, _) {
            return _Card(
              theme: t,
              child: MergeSemantics(
                child: Row(
                  children: [
                    Expanded(
                      child: _Title(
                        theme: t,
                        icon: Icons.playlist_play_rounded,
                        title: 'Seguir con el siguiente capítulo',
                        subtitle:
                            'Al terminar un capítulo, el audio continúa con el siguiente',
                      ),
                    ),
                    Switch(
                      value: on,
                      activeThumbColor: t.accent,
                      onChanged: settings.setAutoAdvance,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        _VoiceTile(theme: t, language: BibleLanguage.spanish),
        const SizedBox(height: 8),
        _VoiceTile(theme: t, language: BibleLanguage.english),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(
            'Cuando hay audio narrado para la versión que lees se usa esa '
            'grabación; si no, se lee con la voz sintética del dispositivo.',
            style: AppFonts.manrope(color: t.textoTenue(0.7), fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final BibleReaderThemeData theme;
  final Widget child;
  const _Card({required this.theme, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.surface.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.accent.withValues(alpha: 0.1)),
      ),
      child: child,
    );
  }
}

class _Title extends StatelessWidget {
  final BibleReaderThemeData theme;
  final IconData icon;
  final String title;
  final String subtitle;

  const _Title({
    required this.theme,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Row(
      children: [
        Icon(icon, color: t.accent, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppFonts.manrope(
                  color: t.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                subtitle,
                style: AppFonts.manrope(color: t.textoTenue(0.6), fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Fila «Voz en español / inglés» que abre la lista de voces.
class _VoiceTile extends StatelessWidget {
  final BibleReaderThemeData theme;
  final BibleLanguage language;
  const _VoiceTile({required this.theme, required this.language});

  String get _title => language == BibleLanguage.english
      ? 'Voz en inglés (NIV, NLT, NKJV)'
      : 'Voz en español';

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final notifier = BibleAudioSettings.I.voiceNotifierFor(language);
    return ValueListenableBuilder<TtsVoicePreference?>(
      valueListenable: notifier,
      builder: (context, pref, _) {
        final current = pref == null
            ? 'Automática (mejor disponible)'
            : TtsVoice(name: pref.name, locale: pref.locale).displayName;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => showModalBottomSheet<void>(
              context: context,
              backgroundColor: t.surface,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (_) => _VoicePickerSheet(theme: t, language: language),
            ),
            child: Semantics(
              button: true,
              label: '$_title: $current. Cambiar voz',
              excludeSemantics: true,
              child: _Card(
                theme: t,
                child: Row(
                  children: [
                    Expanded(
                      child: _Title(
                        theme: t,
                        icon: Icons.record_voice_over_outlined,
                        title: _title,
                        subtitle: current,
                      ),
                    ),
                    Icon(Icons.chevron_right, color: t.textoTenue(0.6)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VoicePickerSheet extends StatefulWidget {
  final BibleReaderThemeData theme;
  final BibleLanguage language;
  const _VoicePickerSheet({required this.theme, required this.language});

  @override
  State<_VoicePickerSheet> createState() => _VoicePickerSheetState();
}

class _VoicePickerSheetState extends State<_VoicePickerSheet> {
  late final Future<List<TtsVoice>> _voices = BibleTtsService.I.voicesFor(
    widget.language,
  );

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final settings = BibleAudioSettings.I;
    final notifier = settings.voiceNotifierFor(widget.language);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: t.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Semantics(
              header: true,
              child: Text(
                widget.language == BibleLanguage.english
                    ? 'Voz en inglés'
                    : 'Voz en español',
                style: AppFonts.manrope(
                  color: t.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: FutureBuilder<List<TtsVoice>>(
                future: _voices,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: CircularProgressIndicator(color: t.accent),
                    );
                  }
                  final voices = snap.data ?? const <TtsVoice>[];
                  return ValueListenableBuilder<TtsVoicePreference?>(
                    valueListenable: notifier,
                    builder: (context, pref, _) {
                      return ListView(
                        shrinkWrap: true,
                        children: [
                          _option(
                            t,
                            title: 'Automática (mejor disponible)',
                            subtitle: voices.isEmpty
                                ? 'Voz del sistema'
                                : 'Ahora: ${voices.first.displayName}',
                            selected: pref == null,
                            onTap: () =>
                                settings.setVoice(widget.language, null),
                            onPreview: () => BibleTtsService.I.previewVoice(
                              null,
                              widget.language,
                            ),
                          ),
                          if (voices.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'Este dispositivo no permite elegir la voz; '
                                'se usa la del sistema. Puedes instalar voces '
                                'de mejor calidad en los ajustes de texto a '
                                'voz del teléfono.',
                                style: AppFonts.manrope(
                                  color: t.textoTenue(0.7),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          for (final v in voices)
                            _option(
                              t,
                              title: v.displayName,
                              subtitle: _qualityLabel(v),
                              selected: pref != null && v.matches(pref),
                              onTap: () => settings.setVoice(
                                widget.language,
                                v.toPreference(),
                              ),
                              onPreview: () => BibleTtsService.I.previewVoice(
                                v,
                                widget.language,
                              ),
                            ),
                          const SizedBox(height: 12),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _qualityLabel(TtsVoice v) {
    switch (BibleVoicePicker.qualityTier(v)) {
      case 3:
        return 'Calidad premium';
      case 2:
        return v.networkRequired || v.name.toLowerCase().contains('network')
            ? 'Alta calidad · requiere internet'
            : 'Alta calidad';
      default:
        return 'Calidad estándar';
    }
  }

  Widget _option(
    BibleReaderThemeData t, {
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
    required VoidCallback onPreview,
  }) {
    return ListTile(
      minTileHeight: 56,
      selected: selected,
      onTap: onTap,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: selected ? t.accent : t.textoTenue(0.6),
      ),
      title: Text(
        title,
        style: AppFonts.manrope(
          color: t.textPrimary,
          fontSize: 14,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppFonts.manrope(color: t.textoTenue(0.6), fontSize: 12),
      ),
      trailing: IconButton(
        tooltip: 'Escuchar muestra',
        onPressed: onPreview,
        icon: Icon(Icons.volume_up_outlined, color: t.accent),
      ),
    );
  }
}
