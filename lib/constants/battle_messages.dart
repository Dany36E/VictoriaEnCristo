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
  // ── Guerreros ──────────────────────────────────────
  BattleMessage(key: 'praying_for_you',   text: 'Orando por ti 🙏',                              icon: '🙏'),
  BattleMessage(key: 'well_done_soldier',  text: '¡Bien hecho, soldado! ⚔️',                      icon: '⚔️'),
  BattleMessage(key: 'not_alone',          text: 'No estás solo. Aquí estoy 🛡️',                   icon: '🛡️'),
  BattleMessage(key: 'keep_going',         text: '¡Sigue adelante! Él ya ganó la batalla 🏆',     icon: '🏆'),
  BattleMessage(key: 'god_with_you',       text: 'Dios está contigo en esta batalla ✝️',           icon: '✝️'),
  BattleMessage(key: 'im_here',            text: 'Aquí cuando me necesites 💪',                    icon: '💪'),
  BattleMessage(key: 'proud_of_you',       text: 'Me siento orgulloso de tu racha 🌟',            icon: '🌟'),
  BattleMessage(key: 'stand_firm',         text: 'Mantente firme. ¡Tú puedes! 🔥',                icon: '🔥'),
  // ── Tiernos / consoladores ─────────────────────────
  BattleMessage(key: 'with_you',           text: 'Estoy contigo 🫂',                                icon: '🫂'),
  BattleMessage(key: 'loved_as_you_are',   text: 'Dios te ama tal como estás 💙',                  icon: '💙'),
  BattleMessage(key: 'rest_in_him',        text: 'Descansa en Él esta noche 🌙',                   icon: '🌙'),
  BattleMessage(key: 'thinking_of_you',    text: 'Pensando en ti hoy 🙏',                          icon: '🕊️'),
  // ── SOS / oración urgente (gatillado por botón dedicado) ──
  BattleMessage(key: 'sos_prayer',         text: 'Necesito oración ahora 🆘',                      icon: '🆘'),
];

/// Lookup rápido por key
final Map<String, BattleMessage> kBattleMessageMap = {
  for (final msg in kBattleMessages) msg.key: msg,
};

/// Validar que un key es un mensaje válido
bool isValidMessageKey(String key) => kBattleMessageMap.containsKey(key);

/// Key reservada para el botón "Oren por mí ahora" (broadcast SOS).
/// Se envía a TODOS los compañeros activos con un rate-limit especial (1/día).
const String kBattleSosKey = 'sos_prayer';

/// Stickers seleccionables desde el picker normal (excluye el SOS, que
/// se envía por botón dedicado para reforzar el peso emocional).
List<BattleMessage> get kBattleMessagesSelectable =>
    kBattleMessages.where((m) => m.key != kBattleSosKey).toList();
