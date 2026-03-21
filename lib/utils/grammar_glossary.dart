/// Glosario de términos gramaticales bíblicos en español.
/// Proporciona explicaciones concisas para mostrar en tooltips.
class GrammarGlossary {
  GrammarGlossary._();

  static String? explain(String term) => _glossary[term.toLowerCase()];

  static const _glossary = <String, String>{
    // Partes del discurso
    'sustantivo': 'Palabra que nombra personas, lugares, cosas o ideas.',
    'verbo': 'Palabra que expresa acción o estado.',
    'adjetivo': 'Modifica o describe un sustantivo.',
    'adverbio': 'Modifica un verbo, adjetivo u otro adverbio.',
    'preposición': 'Relaciona un sustantivo con otra parte de la oración.',
    'pronombre': 'Sustituye o hace referencia a un sustantivo.',
    'conjunción': 'Conecta palabras, frases u oraciones.',
    'artículo': 'Determina o especifica un sustantivo.',
    'interjección': 'Expresión exclamativa independiente.',
    'partícula': 'Palabra corta con función gramatical o enfática.',

    // Casos griegos
    'nominativo': 'Caso del sujeto de la oración.',
    'genitivo': 'Caso de posesión, origen o separación.',
    'dativo': 'Caso del objeto indirecto o instrumento.',
    'acusativo': 'Caso del objeto directo o destino.',
    'vocativo': 'Caso usado para dirigirse a alguien directamente.',

    // Tiempos griegos
    'presente': 'Acción continua o habitual, generalmente en el ahora.',
    'imperfecto': 'Acción continua en el pasado.',
    'futuro': 'Acción que ocurrirá en el futuro.',
    'aoristo': 'Acción puntual, generalmente en el pasado.',
    'perfecto': 'Acción completada con resultados presentes.',
    'pluscuamperfecto': 'Acción completada antes de otro evento pasado.',

    // Voces
    'activa': 'El sujeto realiza la acción.',
    'media': 'El sujeto actúa sobre sí mismo o en su propio interés.',
    'pasiva': 'El sujeto recibe la acción.',

    // Modos
    'indicativo': 'Afirma un hecho real o una pregunta directa.',
    'subjuntivo': 'Expresa probabilidad, deseo o propósito.',
    'optativo': 'Expresa un deseo o posibilidad remota.',
    'imperativo': 'Expresa un mandato o petición.',
    'infinitivo': 'Forma verbal sin sujeto definido (equivale a terminación -ar, -er, -ir).',
    'participio': 'Forma verbal que funciona como adjetivo o adverbio.',
    'participio activo': 'Quien realiza la acción (equivale a -ando, -iendo).',
    'participio pasivo': 'Quien recibe la acción.',

    // Género
    'masculino': 'Género gramatical masculino.',
    'femenino': 'Género gramatical femenino.',
    'neutro': 'Género gramatical neutro (solo en griego).',
    'común': 'Puede ser masculino o femenino.',
    'ambos': 'Aplica a ambos géneros.',

    // Número
    'singular': 'Refiere a una sola entidad.',
    'plural': 'Refiere a más de una entidad.',
    'dual': 'Refiere a exactamente dos entidades (hebreo).',

    // Persona
    '1ra persona': 'Quien habla (yo, nosotros).',
    '2da persona': 'A quien se habla (tú, ustedes).',
    '3ra persona': 'De quien se habla (él, ella, ellos).',

    // Tallos hebreos
    'qal': 'Forma verbal simple activa (hebreo).',
    'nifal': 'Forma verbal simple pasiva o reflexiva (hebreo).',
    'piel': 'Forma verbal intensiva activa (hebreo).',
    'pual': 'Forma verbal intensiva pasiva (hebreo).',
    'hifil': 'Forma verbal causativa activa (hebreo).',
    'hofal': 'Forma verbal causativa pasiva (hebreo).',
    'hitpael': 'Forma verbal intensiva reflexiva (hebreo).',

    // Estados hebreos
    'absoluto': 'Estado independiente del sustantivo.',
    'constructo': 'Estado de relación con otro sustantivo (ej: "rey de Israel").',
    'determinado': 'Con artículo definido (el, la).',

    // Tipos
    'pronombre personal': 'Sustituye a un nombre propio o sustantivo.',
    'pronombre demostrativo': 'Señala algo específico (este, ese, aquel).',
    'pronombre relativo': 'Introduce una cláusula (que, quien, cual).',
    'pronombre interrogativo': 'Introduce una pregunta (quién, qué, cuál).',

    // Conceptos adicionales
    'constructo infinitivo': 'Infinitivo hebreo en estado constructo (con preposición).',
    'absoluto infinitivo': 'Infinitivo hebreo independiente, usado para énfasis.',
    'consecutivo': 'Forma verbal con waw consecutivo (hebreo narrativo).',
    'sufijo': 'Elemento añadido al final de una palabra.',
  };

  /// Todos los términos disponibles.
  static List<String> get terms => _glossary.keys.toList();
}
