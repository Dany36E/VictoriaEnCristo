/// ═══════════════════════════════════════════════════════════════════════════
/// BATTLE MESSAGES - Stickers espirituales predefinidos
/// Solo estos mensajes pueden enviarse entre compañeros.
/// Sin texto libre. Sin imágenes personalizadas.
/// ═══════════════════════════════════════════════════════════════════════════
library;

class BattleMessage {
  final String key;
  final String text;
  final String icon;

  const BattleMessage({
    required this.key,
    required this.text,
    required this.icon,
  });
}

const List<BattleMessage> kBattleMessages = [
  BattleMessage(key: 'praying_for_you',   text: 'Orando por ti 🙏',                              icon: '🙏'),
  BattleMessage(key: 'well_done_soldier',  text: '¡Bien hecho, soldado! ⚔️',                      icon: '⚔️'),
  BattleMessage(key: 'not_alone',          text: 'No estás solo. Aquí estoy 🛡️',                   icon: '🛡️'),
  BattleMessage(key: 'keep_going',         text: '¡Sigue adelante! Él ya ganó la batalla 🏆',     icon: '🏆'),
  BattleMessage(key: 'god_with_you',       text: 'Dios está contigo en esta batalla ✝️',           icon: '✝️'),
  BattleMessage(key: 'im_here',            text: 'Aquí cuando me necesites 💪',                    icon: '💪'),
  BattleMessage(key: 'proud_of_you',       text: 'Me siento orgulloso de tu racha 🌟',            icon: '🌟'),
  BattleMessage(key: 'stand_firm',         text: 'Mantente firme. ¡Tú puedes! 🔥',                icon: '🔥'),
];

/// Lookup rápido por key
final Map<String, BattleMessage> kBattleMessageMap = {
  for (final msg in kBattleMessages) msg.key: msg,
};

/// Validar que un key es un mensaje válido
bool isValidMessageKey(String key) => kBattleMessageMap.containsKey(key);
