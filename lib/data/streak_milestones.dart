/// ═══════════════════════════════════════════════════════════════════════════
/// StreakMilestones — Hitos psicológicos de la racha
///
/// Define hitos significativos (3, 7, 14, 30, 60, 90, 180, 365) y mensajes
/// de gracia/normalización para los valores intermedios. Evita que la app se
/// sienta vacía entre hitos.
/// ═══════════════════════════════════════════════════════════════════════════
library;

class StreakMilestone {
  final int day;
  final String title;
  final String message;
  final String verse;
  final String reference;
  final String emoji;

  const StreakMilestone({
    required this.day,
    required this.title,
    required this.message,
    required this.verse,
    required this.reference,
    required this.emoji,
  });
}

class StreakMilestones {
  StreakMilestones._();

  static const List<int> milestoneDays = [3, 7, 14, 30, 60, 90, 180, 365];

  static const List<StreakMilestone> _milestones = [
    StreakMilestone(
      day: 3,
      title: '3 días',
      emoji: '🌱',
      message:
          'Tres días. La semilla echó raíz. Lo que parecía imposible ya tiene forma.',
      verse: '"El que comenzó en vosotros la buena obra, la perfeccionará."',
      reference: 'Filipenses 1:6',
    ),
    StreakMilestone(
      day: 7,
      title: 'Una semana',
      emoji: '🌿',
      message:
          'Siete días. Tu cuerpo y tu mente empiezan a recordar la libertad.',
      verse: '"Mas a Dios gracias, que nos lleva siempre en triunfo en Cristo Jesús."',
      reference: '2 Corintios 2:14',
    ),
    StreakMilestone(
      day: 14,
      title: 'Dos semanas',
      emoji: '🌾',
      message:
          'Dos semanas. Estás escribiendo una historia nueva, día por día.',
      verse: '"Todo lo puedo en Cristo que me fortalece."',
      reference: 'Filipenses 4:13',
    ),
    StreakMilestone(
      day: 30,
      title: 'Un mes',
      emoji: '🌳',
      message:
          'Un mes entero. No es un milagro — es constancia. Y eso también es santo.',
      verse: '"Nuestro hombre interior no obstante se renueva de día en día."',
      reference: '2 Corintios 4:16',
    ),
    StreakMilestone(
      day: 60,
      title: '60 días',
      emoji: '⚓',
      message:
          'Dos meses. El ancla echó raíz. El viento ya no te mueve tan fácil.',
      verse: '"La cual tenemos como segura y firme ancla del alma."',
      reference: 'Hebreos 6:19',
    ),
    StreakMilestone(
      day: 90,
      title: '90 días',
      emoji: '🏔️',
      message:
          '90 días. Ya no eres el mismo que empezó. La montaña se mueve.',
      verse: '"Si alguno está en Cristo, nueva criatura es."',
      reference: '2 Corintios 5:17',
    ),
    StreakMilestone(
      day: 180,
      title: '6 meses',
      emoji: '🔥',
      message:
          'Medio año. Lo que antes te consumía, hoy tú lo miras desde arriba.',
      verse: '"Mayor es el que está en vosotros, que el que está en el mundo."',
      reference: '1 Juan 4:4',
    ),
    StreakMilestone(
      day: 365,
      title: '1 año',
      emoji: '👑',
      message:
          'Un año. No es solo un número — es un testimonio. Dios escribe con los días.',
      verse:
          '"Y sabemos que a los que aman a Dios, todas las cosas les ayudan a bien."',
      reference: 'Romanos 8:28',
    ),
  ];

  /// Devuelve el hito exacto para [streakDay] si [streakDay] es un día-hito.
  static StreakMilestone? milestoneFor(int streakDay) {
    for (final m in _milestones) {
      if (m.day == streakDay) return m;
    }
    return null;
  }

  /// Próximo hito después de [current]. Null si ya pasó el último.
  static StreakMilestone? nextMilestone(int current) {
    for (final m in _milestones) {
      if (m.day > current) return m;
    }
    return null;
  }

  /// Hito previo alcanzado (para mostrar "has superado X").
  static StreakMilestone? previousMilestone(int current) {
    StreakMilestone? prev;
    for (final m in _milestones) {
      if (m.day <= current) prev = m;
    }
    return prev;
  }

  /// Mensaje para días intermedios (normaliza "no pasa nada si no es hito").
  static String encouragementFor(int streakDay) {
    if (streakDay <= 0) {
      return 'Formar un hábito nuevo toma 21+ intentos. Estás aprendiendo, no fallando.';
    }
    if (streakDay == 1) {
      return 'Día uno. Respira. Esto ya es un acto de valentía.';
    }
    if (streakDay == 2) {
      return 'Dos días. Menos fácil de lo que parece, más posible de lo que creías.';
    }
    if (streakDay < 7) {
      return 'Sigues de pie. Eso ya es bastante para hoy.';
    }
    if (streakDay < 14) {
      return 'Una semana cumplida. Tu cerebro está reescribiendo caminos.';
    }
    if (streakDay < 30) {
      return 'Cada día es un voto a favor de quien quieres ser.';
    }
    if (streakDay < 90) {
      return 'Lo extraordinario nació de lo cotidiano repetido. Sigue.';
    }
    return 'Vas más lejos de lo que la mayoría imagina. Gracia sobre gracia.';
  }
}
