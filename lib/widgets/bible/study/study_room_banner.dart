import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/bible/study_room.dart';
import '../../../theme/bible_reader_theme.dart';

/// Banner superior que aparece cuando el usuario está en una sala de estudio.
/// Muestra:
///   - Código de la sala (compartible).
///   - Versión asignada al usuario.
///   - Lista compacta de miembros.
///   - Cuenta atrás hasta el próximo swap.
///   - Acciones: rotar ahora / salir.
class StudyRoomBanner extends StatefulWidget {
  final StudyRoom room;
  final BibleReaderThemeData theme;
  final VoidCallback onLeave;
  final VoidCallback onRotate;
  final ValueChanged<String> onVersionAssigned;

  const StudyRoomBanner({
    super.key,
    required this.room,
    required this.theme,
    required this.onLeave,
    required this.onRotate,
    required this.onVersionAssigned,
  });

  @override
  State<StudyRoomBanner> createState() => _StudyRoomBannerState();
}

class _StudyRoomBannerState extends State<StudyRoomBanner> {
  Timer? _ticker;
  String? _lastNotifiedVersion;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _maybeNotifyVersion();
  }

  @override
  void didUpdateWidget(covariant StudyRoomBanner old) {
    super.didUpdateWidget(old);
    _maybeNotifyVersion();
  }

  void _maybeNotifyVersion() {
    final uid = _myUid();
    if (uid == null) return;
    final v = widget.room.versionForUid(uid);
    if (v == null) return;
    if (v == _lastNotifiedVersion) return;
    _lastNotifiedVersion = v;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onVersionAssigned(v);
    });
  }

  String? _myUid() => FirebaseAuth.instance.currentUser?.uid;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final r = widget.room;
    final secs = r.secondsUntilSwap(DateTime.now());
    final mm = (secs ~/ 60).toString().padLeft(2, '0');
    final ss = (secs % 60).toString().padLeft(2, '0');

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: t.accent.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.accent.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.groups, size: 18, color: t.accent),
              const SizedBox(width: 8),
              Text(
                'Sala ${r.code}',
                style: GoogleFonts.cinzel(
                  color: t.accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Icon(Icons.timer_outlined,
                  size: 14, color: t.textSecondary),
              const SizedBox(width: 4),
              Text(
                'Swap en $mm:$ss',
                style: GoogleFonts.manrope(
                  color: t.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                tooltip: 'Rotar ahora',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.swap_horiz, color: t.accent, size: 18),
                onPressed: widget.onRotate,
              ),
              IconButton(
                tooltip: 'Salir',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.logout,
                    color: t.textSecondary, size: 18),
                onPressed: widget.onLeave,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: r.memberOrder.map((uid) {
              final m = r.members[uid];
              if (m == null) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: t.background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: t.textSecondary.withOpacity(0.15)),
                ),
                child: Text(
                  '${m.displayName} · ${m.versionId}',
                  style: GoogleFonts.manrope(
                    color: t.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
