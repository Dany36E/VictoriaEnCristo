import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/bible/bible_version.dart';
import '../../../models/bible/study_room.dart';
import '../../../services/bible/bible_download_service.dart';

enum StudyRoomDialogAction { create, join }

/// Dialog inicial: crear o unirse.
class StudyRoomChoiceDialog extends StatelessWidget {
  const StudyRoomChoiceDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Estudiar con amigos',
        style: GoogleFonts.cinzel(fontWeight: FontWeight.w700),
      ),
      content: const Text(
        'Reúnete con hasta 4 amigos. Cada uno lee una traducción distinta '
        'y, con el "swap", todos van rotando de versión cada cierto tiempo '
        'para descubrir matices nuevos del mismo pasaje.\n\n'
        'Crea la sala (eliges pasaje, tu versión y el tiempo de rotación) '
        'o únete con un código.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, StudyRoomDialogAction.join),
          child: const Text('Unirme con código'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, StudyRoomDialogAction.create),
          child: const Text('Crear sala'),
        ),
      ],
    );
  }
}

/// Resultado del sheet de creación de sala.
///
/// Si [changePassage] es true, la pantalla debe abrir el selector de
/// pasaje/rango y volver a mostrar el sheet con el pasaje actualizado.
class CreateRoomFormResult {
  final bool changePassage;
  final String versionId;
  final int swapIntervalMinutes;

  const CreateRoomFormResult.changePassage()
      : changePassage = true,
        versionId = '',
        swapIntervalMinutes = 15;

  const CreateRoomFormResult.create({
    required this.versionId,
    required this.swapIntervalMinutes,
  }) : changePassage = false;
}

/// Sheet de configuración para crear una sala: pasaje + versión + intervalo
/// de swap, con explicación del swap y recomendación de 15 min.
class CreateRoomSheet extends StatefulWidget {
  final String passageLabel;
  final String currentVersionId;

  const CreateRoomSheet({
    super.key,
    required this.passageLabel,
    required this.currentVersionId,
  });

  @override
  State<CreateRoomSheet> createState() => _CreateRoomSheetState();
}

class _CreateRoomSheetState extends State<CreateRoomSheet> {
  static const List<int> _intervalOptions = [10, 15, 20, 30];

  late String _versionId;
  int _swapInterval = 15;

  @override
  void initState() {
    super.initState();
    _versionId = BibleDownloadService.I
        .bestAvailableVersion(BibleVersion.fromId(widget.currentVersionId))
        .id;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Crear sala de estudio',
                style: GoogleFonts.cinzel(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),
              // Pasaje
              Text(
                'Pasaje',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => Navigator.pop(
                  context,
                  const CreateRoomFormResult.changePassage(),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.menu_book_outlined, size: 18, color: cs.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.passageLabel,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        'Cambiar',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Versión
              Text(
                'Tu traducción',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _versionId,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: BibleDownloadService.I.availableVersions
                    .map(
                      (v) => DropdownMenuItem(
                        value: v.id,
                        child: Text(v.displayName),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _versionId = v ?? _versionId),
              ),
              const SizedBox(height: 6),
              Text(
                'Se recomienda que cada miembro use una traducción distinta.',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              // Intervalo de swap
              Text(
                'Tiempo de rotación (swap)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _intervalOptions.map((min) {
                  final selected = _swapInterval == min;
                  return ChoiceChip(
                    label: Text('$min min'),
                    selected: selected,
                    onSelected: (_) => setState(() => _swapInterval = min),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'El swap rota las versiones entre todos cada $_swapInterval '
                  'min. Recomendamos 15 min para pasajes cortos o sencillos; '
                  'sube el tiempo si el texto es largo o más profundo.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: cs.onSurface.withValues(alpha: 0.85),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(
                        context,
                        CreateRoomFormResult.create(
                          versionId: _versionId,
                          swapIntervalMinutes: _swapInterval,
                        ),
                      ),
                      icon: const Icon(Icons.group_add, size: 18),
                      label: const Text('Crear sala'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class JoinRoomFormResult {
  final String code;
  final String versionId;
  const JoinRoomFormResult(this.code, this.versionId);
}

class JoinRoomDialog extends StatefulWidget {
  final String currentVersionId;
  const JoinRoomDialog({super.key, required this.currentVersionId});

  @override
  State<JoinRoomDialog> createState() => _JoinRoomDialogState();
}

class _JoinRoomDialogState extends State<JoinRoomDialog> {
  final _codeCtrl = TextEditingController();
  late String _versionId;

  @override
  void initState() {
    super.initState();
    _versionId = BibleDownloadService.I
        .bestAvailableVersion(BibleVersion.fromId(widget.currentVersionId))
        .id;
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Unirme a una sala'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _codeCtrl,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: const InputDecoration(
              labelText: 'Código de 6 caracteres',
              hintText: 'ABC123',
            ),
            style: const TextStyle(letterSpacing: 4, fontSize: 18),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _versionId,
            decoration: const InputDecoration(labelText: 'Tu traducción'),
            items: BibleDownloadService.I.availableVersions
                .map(
                  (v) =>
                      DropdownMenuItem(value: v.id, child: Text(v.displayName)),
                )
                .toList(),
            onChanged: (v) => setState(() => _versionId = v ?? _versionId),
          ),
          const SizedBox(height: 6),
          Text(
            'Recuerda: cada miembro debe usar una traducción distinta.',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            final code = _codeCtrl.text.trim().toUpperCase();
            if (code.length != 6) return;
            Navigator.pop(context, JoinRoomFormResult(code, _versionId));
          },
          child: const Text('Unirme'),
        ),
      ],
    );
  }
}

/// Dialog mostrado cuando ya estás en una sala — datos + salir.
class StudyRoomActiveDialog extends StatelessWidget {
  final StudyRoom room;
  final VoidCallback onLeave;

  const StudyRoomActiveDialog({
    super.key,
    required this.room,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Sala ${room.code}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Comparte este código para que otros se unan:'),
          const SizedBox(height: 8),
          SelectableText(
            room.code,
            style: GoogleFonts.cinzel(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: 6,
            ),
          ),
          const SizedBox(height: 16),
          Text('Miembros (${room.memberOrder.length}/5):'),
          const SizedBox(height: 4),
          ...room.memberOrder.map((uid) {
            final m = room.members[uid];
            if (m == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text('• ${m.displayName} — ${m.versionId}'),
            );
          }),
          const SizedBox(height: 12),
          Text(
            room.swapTimerActive
                ? 'Rotación cada ${room.swapIntervalMinutes} min.'
                : 'Timer de swap pendiente. El host lo iniciará cuando estén listos.',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            onLeave();
          },
          child: const Text('Salir de la sala'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
