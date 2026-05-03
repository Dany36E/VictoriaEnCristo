import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/bible/bible_version.dart';
import '../../../models/bible/study_room.dart';

enum StudyRoomDialogAction { create, join }

/// Dialog inicial: crear o unirse.
class StudyRoomChoiceDialog extends StatelessWidget {
  const StudyRoomChoiceDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Estudiar con amigos',
          style: GoogleFonts.cinzel(fontWeight: FontWeight.w700)),
      content: const Text(
        'Reúnete con hasta 4 amigos. Cada uno verá una traducción '
        'distinta y rotarán cada cierto tiempo para enriquecer la lectura.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.pop(context, StudyRoomDialogAction.join),
          child: const Text('Unirme con código'),
        ),
        ElevatedButton(
          onPressed: () =>
              Navigator.pop(context, StudyRoomDialogAction.create),
          child: const Text('Crear sala'),
        ),
      ],
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
    _versionId = widget.currentVersionId;
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
            value: _versionId,
            decoration: const InputDecoration(labelText: 'Tu traducción'),
            items: BibleVersion.values
                .map((v) => DropdownMenuItem(
                      value: v.id,
                      child: Text(v.displayName),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _versionId = v ?? _versionId),
          ),
          const SizedBox(height: 6),
          Text(
            'Recuerda: cada miembro debe usar una traducción distinta.',
            style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
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
            Navigator.pop(
                context, JoinRoomFormResult(code, _versionId));
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
                letterSpacing: 6),
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
            'Rotación cada ${room.swapIntervalMinutes} min.',
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
