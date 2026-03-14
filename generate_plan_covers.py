"""
Generador de especificaciones para imágenes de planes espirituales
Crea un documento con las especificaciones visuales para cada plan
"""

plans_specs = [
    # PLANES DE CRISIS (3 días)
    {
        "id": "calma-en-la-tormenta",
        "title": "Calma en la Tormenta",
        "concept": "Persona respirando profundo en medio de tormenta que se calma, rayos de luz atravesando nubes",
        "colors": ["#2C3E50", "#3498DB", "#ECF0F1", "#F39C12"],
        "elements": ["Nubes tormentosas difuminándose", "Respiración visible (aire brillante)", "Manos abiertas receptivas"],
        "mood": "Transición de caos a calma",
        "prompt_ai": "A person breathing deeply, dark storm clouds parting above, golden light rays breaking through, hands open in surrender, cinematic lighting, hope emerging from chaos, blue and gold tones, spiritual art style"
    },
    {
        "id": "cortar-el-impulso",
        "title": "Cortar el Impulso",
        "concept": "Cadenas rompiéndose, reloj de arena con tiempo detenido, puerta de salida iluminada",
        "colors": ["#8E44AD", "#E74C3C", "#F1C40F", "#34495E"],
        "elements": ["Cadenas fragmentándose", "Temporizador visible", "Luz de escape al fondo"],
        "mood": "Interrupción de patrón destructivo",
        "prompt_ai": "Breaking chains, hourglass frozen in time, glowing exit door in background, purple and red dramatic tones, powerful liberation moment, digital art, spiritual warfare aesthetic"
    },
    {
        "id": "noche-segura",
        "title": "Noche Segura",
        "concept": "Dormitorio sereno con luz cálida, teléfono apagado fuera de alcance, ventana con luna",
        "colors": ["#34495E", "#F39C12", "#ECF0F1", "#2980B9"],
        "elements": ["Luz cálida de lámpara", "Dispositivo fuera del cuarto", "Luna tranquila"],
        "mood": "Paz nocturna protegida",
        "prompt_ai": "Peaceful bedroom at night, warm orange lamp light, phone outside the room, crescent moon through window, cozy and safe atmosphere, minimalist illustration, calming blue and orange palette"
    },
    {
        "id": "restauracion-sin-culpa",
        "title": "Restauración Sin Culpa",
        "concept": "Persona levantándose del suelo, mano extendida desde arriba ofreciendo ayuda, amanecer",
        "colors": ["#E67E22", "#3498DB", "#ECF0F1", "#27AE60"],
        "elements": ["Mano divina ayudando", "Amanecer nuevo", "Expresión de aceptación"],
        "mood": "Gracia levantando, no culpa hundiendo",
        "prompt_ai": "Person rising from ground, divine hand reaching down to help, sunrise in background, warm orange and blue tones, grace and restoration theme, hope emerging, compassionate spiritual art"
    },
    {
        "id": "mente-en-tierra-firme",
        "title": "Mente en Tierra Firme",
        "concept": "Mente representada como isla firme en océano agitado, raíces profundas",
        "colors": ["#16A085", "#2C3E50", "#ECF0F1", "#E74C3C"],
        "elements": ["Isla con árbol arraigado", "Olas alrededor sin afectar", "Cielo despejado arriba"],
        "mood": "Estabilidad mental en medio del caos",
        "prompt_ai": "Mind represented as firm island with deep-rooted tree, turbulent ocean around but not affecting, clear sky above, teal and dark blue tones, grounding and stability concept, symbolic art"
    },
    {
        "id": "rescate-digital",
        "title": "Rescate Digital",
        "concept": "Persona saliendo de pantalla gigante hacia naturaleza verde, scroll infinito cortándose",
        "colors": ["#3498DB", "#27AE60", "#95A5A6", "#F39C12"],
        "elements": ["Pantalla rota/disolviéndose", "Naturaleza vibrante", "Movimiento hacia libertad"],
        "mood": "Escape de doomscrolling a realidad",
        "prompt_ai": "Person walking out of giant cracked smartphone screen into vibrant green nature, endless social feed cutting off, blue and green contrast, digital detox concept, liberation theme, modern illustration"
    },

    # PLANES DE 7 DÍAS
    {
        "id": "mente-blindada",
        "title": "Mente Blindada",
        "concept": "Cerebro protegido por escudo de luz dorada, pensamientos negativos rebotando",
        "colors": ["#F39C12", "#34495E", "#ECF0F1", "#E74C3C"],
        "elements": ["Escudo brillante", "Pensamientos oscuros rebotando", "Versículos bíblicos integrados"],
        "mood": "Protección mental activa",
        "prompt_ai": "Brain protected by golden shield of light, dark thoughts bouncing off, biblical verses integrated into shield, gold and dark blue tones, spiritual armor concept, powerful defense imagery"
    },
    {
        "id": "pureza-con-proposito",
        "title": "Pureza con Propósito",
        "concept": "Corazón limpio brillante con raíces hacia arriba, jardín floreciendo alrededor",
        "colors": ["#ECF0F1", "#3498DB", "#27AE60", "#F39C12"],
        "elements": ["Corazón cristalino", "Raíces ascendentes", "Flores puras emergiendo"],
        "mood": "Pureza intencional y floreciente",
        "prompt_ai": "Pure glowing white heart with roots reaching upward, blooming garden around, clean and vibrant aesthetic, light blue and green tones, purity and purpose theme, hopeful spiritual art"
    },
    {
        "id": "ansiedad-bajo-gobierno",
        "title": "Ansiedad Bajo Gobierno",
        "concept": "Mente como ciudad ordenada con calles rectas, vs caos anterior en esquina",
        "colors": ["#3498DB", "#2C3E50", "#F39C12", "#ECF0F1"],
        "elements": ["Ciudad ordenada", "Contraste caos/orden", "Luz organizadora"],
        "mood": "Ansiedad domesticada y estructurada",
        "prompt_ai": "Mind as organized city with straight streets and order, contrast with chaotic corner fading away, blue and gold light organizing everything, anxiety under control concept, architectural spiritual metaphor"
    },
    {
        "id": "dominio-propio-primeros-7",
        "title": "Dominio Propio: Primeros 7",
        "concept": "Primer paso de escalera iluminado, resto en sombra pero visible, pie avanzando",
        "colors": ["#F39C12", "#34495E", "#27AE60", "#ECF0F1"],
        "elements": ["Primer escalón brillante", "Escalera ascendente", "Pie decidido"],
        "mood": "Inicio decidido de jornada",
        "prompt_ai": "First step of staircase brightly lit, rest visible in shadow climbing upward, foot stepping forward with determination, gold and dark blue tones, journey beginning concept, hope and commitment"
    },
    {
        "id": "silencio-interior",
        "title": "Silencio Interior",
        "concept": "Persona en postura meditativa, ondas sonoras caóticas disolviéndose en círculo de paz",
        "colors": ["#3498DB", "#ECF0F1", "#95A5A6", "#16A085"],
        "elements": ["Figura en silencio", "Ondas caóticas afuera", "Círculo de calma"],
        "mood": "Quietud en medio del ruido",
        "prompt_ai": "Person in meditative posture, chaotic sound waves dissolving into circle of peace around them, teal and white soft tones, inner silence concept, tranquil spiritual atmosphere, minimalist zen aesthetic"
    },
    {
        "id": "romper-la-rutina",
        "title": "Romper la Rutina",
        "concept": "Loop circular rompiéndose, persona saliendo hacia camino nuevo iluminado",
        "colors": ["#E74C3C", "#F39C12", "#27AE60", "#34495E"],
        "elements": ["Círculo vicioso fragmentándose", "Camino nuevo abierto", "Movimiento decisivo"],
        "mood": "Ruptura de patrón destructivo",
        "prompt_ai": "Circular loop breaking apart, person stepping out toward new illuminated path, red and gold breaking chains, green path forward, pattern interrupt concept, decisive transformation moment"
    },
    {
        "id": "identidad-antes-de-impulso",
        "title": "Identidad Antes de Impulso",
        "concept": "Espejo mostrando identidad verdadera (corona, hijo) vs impulso tentador al lado",
        "colors": ["#F39C12", "#3498DB", "#ECF0F1", "#8E44AD"],
        "elements": ["Espejo con identidad real", "Corona o sello divino", "Tentación en sombra"],
        "mood": "Identidad como ancla pre-decisión",
        "prompt_ai": "Mirror reflecting true identity with crown and 'beloved child' inscription, impulse/temptation fading in shadow beside, gold and blue tones, identity anchor concept, spiritual reality vs temptation"
    },
    {
        "id": "fortaleza-en-la-debilidad",
        "title": "Fortaleza en la Debilidad",
        "concept": "Vasija agrietada con luz brillante saliendo de grietas, más fuerte que vasija intacta",
        "colors": ["#F39C12", "#34495E", "#ECF0F1", "#3498DB"],
        "elements": ["Vasija con grietas luminosas", "Luz poderosa emanando", "Contraste fragilidad/poder"],
        "mood": "Poder perfeccionado en debilidad",
        "prompt_ai": "Cracked clay vessel with brilliant golden light shining through cracks, more powerful than intact vessel beside, dark blue background, light and shadow contrast, 2 Corinthians 12:9 concept, strength in weakness"
    },
    {
        "id": "dia-a-dia-habitos-pequenos",
        "title": "Día a Día: Hábitos Pequeños",
        "concept": "Gotas de agua formando río, pequeñas acciones creando corriente poderosa",
        "colors": ["#3498DB", "#27AE60", "#F39C12", "#ECF0F1"],
        "elements": ["Gotas individuales", "Río formándose", "Movimiento acumulativo"],
        "mood": "Micro acciones sumando a transformación",
        "prompt_ai": "Water drops forming into powerful river, small actions creating mighty current, blue and green gradient, micro habits concept, compound effect visualization, inspiring momentum illustration"
    },
    {
        "id": "guardianes-del-corazon",
        "title": "Guardianes del Corazón",
        "concept": "Corazón rodeado de puertas con guardias, filtros visuales protegiendo",
        "colors": ["#E74C3C", "#F39C12", "#34495E", "#ECF0F1"],
        "elements": ["Corazón central", "Puertas de entrada", "Filtros luminosos"],
        "mood": "Protección intencional de entradas",
        "prompt_ai": "Heart surrounded by guarded doors, visual filters protecting entrances, red and gold guardian theme, Proverbs 4:23 concept, protective spiritual warfare, intentional boundaries illustration"
    },

    # PLANES DE 21 DÍAS
    {
        "id": "reprograma-el-deseo",
        "title": "Reprograma el Deseo",
        "concept": "Cerebro con conexiones neuronales reescribiéndose, deseo redirigido hacia luz",
        "colors": ["#8E44AD", "#3498DB", "#F39C12", "#ECF0F1"],
        "elements": ["Conexiones neuronales", "Redirección visible", "Luz como objetivo nuevo"],
        "mood": "Reentrenamiento del deseo",
        "prompt_ai": "Brain with neural pathways rewiring, desire redirecting toward light source, purple and blue electrical connections, transformation of appetite concept, neuroplasticity meets spirituality, hopeful reprogramming"
    },
    {
        "id": "disciplina-del-ojo",
        "title": "Disciplina del Ojo",
        "concept": "Ojo entrenado con escudo selectivo, rechazando lo vano, enfocando lo glorioso",
        "colors": ["#34495E", "#F39C12", "#3498DB", "#ECF0F1"],
        "elements": ["Ojo con visión selectiva", "Escudo protector", "Enfoque en gloria"],
        "mood": "Visión disciplinada e intencional",
        "prompt_ai": "Eye with selective shield, rejecting vanity, focusing on glory, Job 31:1 visual, gold and dark blue tones, intentional vision concept, spiritual discipline of sight, powerful covenant imagery"
    },
    {
        "id": "reemplazo-de-habitos",
        "title": "Reemplazo de Hábitos (Arsenal)",
        "concept": "Engranajes viejos siendo reemplazados por nuevos dorados en máquina funcionando",
        "colors": ["#95A5A6", "#F39C12", "#27AE60", "#34495E"],
        "elements": ["Engranajes en transición", "Mecanismo funcionando", "Reemplazo en acción"],
        "mood": "Sustitución conductual sistemática",
        "prompt_ai": "Old gears being replaced by new golden gears in functioning machine, mechanical habit replacement, gray to gold transformation, systematic behavior change concept, arsenal of tools theme, empowering mechanics"
    },
    {
        "id": "ansiedad-reencuadre-diario",
        "title": "Ansiedad: Reencuadre Diario",
        "concept": "Cuadro mental siendo reenmarcado con marco dorado de verdad, imagen distorsionada corrigiéndose",
        "colors": ["#3498DB", "#F39C12", "#2C3E50", "#ECF0F1"],
        "elements": ["Marco dorado de verdad", "Imagen mental corrigiéndose", "Perspectiva cambiando"],
        "mood": "Pensamiento reencuadrado diariamente",
        "prompt_ai": "Mental picture being reframed with golden truth frame, distorted image correcting, cognitive reframe concept, blue and gold tones, CBT meets Scripture, daily perspective shift, transforming thoughts"
    },
    {
        "id": "pureza-reordenando-afectos",
        "title": "Pureza: Reordenando Afectos",
        "concept": "Corazón con flechas de amor reorientándose hacia arriba (Dios), no horizontalmente",
        "colors": ["#E74C3C", "#F39C12", "#3498DB", "#ECF0F1"],
        "elements": ["Corazón rojo vibrante", "Flechas reorientándose", "Dirección hacia arriba clara"],
        "mood": "Amor correctamente ordenado",
        "prompt_ai": "Heart with love arrows reorienting upward toward God instead of horizontally, red and gold tones, ordered affections concept, Colossians 3:2 theme, proper love hierarchy, passionate reorientation"
    },
    {
        "id": "mundo-digital-regla-de-vida",
        "title": "Mundo Digital: Regla de Vida",
        "concept": "Pantallas contenidas en jardín con reglas claras, sabbath digital visible",
        "colors": ["#3498DB", "#27AE60", "#F39C12", "#95A5A6"],
        "elements": ["Dispositivos en balance", "Naturaleza predominante", "Límites visibles"],
        "mood": "Tecnología bajo gobierno espiritual",
        "prompt_ai": "Digital devices contained within garden with clear boundaries, digital sabbath visible, blue screens balanced with green nature, rule of life concept, intentional tech limits, harmonious integration"
    },
    {
        "id": "soledad-y-comunidad",
        "title": "Soledad y Comunidad",
        "concept": "Persona sola conectándose a círculo de personas, aislamiento rompiendo",
        "colors": ["#3498DB", "#F39C12", "#27AE60", "#ECF0F1"],
        "elements": ["Transición aislamiento a conexión", "Círculo de comunidad", "Puentes formándose"],
        "mood": "Del aislamiento a pertenencia",
        "prompt_ai": "Lonely person connecting to circle of community, isolation breaking, bridges forming between people, warm gold and blue tones, belonging concept, Psalm 68:6 theme, family of God illustration"
    },
    {
        "id": "sueno-santo",
        "title": "Sueño Santo (Rutina nocturna)",
        "concept": "Luna con ritual de cierre nocturno, elementos de descanso sagrado visible",
        "colors": ["#34495E", "#F39C12", "#3498DB", "#ECF0F1"],
        "elements": ["Luna serena", "Ritual nocturno visible", "Paz envolvente"],
        "mood": "Descanso como acto de fe",
        "prompt_ai": "Serene moon with nighttime closing ritual, sacred rest elements visible, dark blue and warm gold tones, Psalm 4:8 concept, sleep as trust, peaceful bedtime routine, holy rest atmosphere"
    },
    {
        "id": "palabra-en-la-boca",
        "title": "Palabra en la Boca",
        "concept": "Persona con Escritura visible saliendo de boca como luz declarativa",
        "colors": ["#F39C12", "#3498DB", "#ECF0F1", "#27AE60"],
        "elements": ["Palabras bíblicas brillantes", "Boca declarando", "Luz emanando"],
        "mood": "Declaración poderosa de verdad",
        "prompt_ai": "Person with glowing Scripture coming from mouth as declarative light, gold and blue illuminated words, Romans 10:17 concept, faith by hearing, powerful spoken Word, memorization theme"
    },
    {
        "id": "armadura-de-dios-racha-21",
        "title": "Armadura de Dios: Racha de 21",
        "concept": "Persona vistiéndose con piezas de armadura brillante, Efesios 6 visible",
        "colors": ["#F39C12", "#34495E", "#E74C3C", "#ECF0F1"],
        "elements": ["Piezas de armadura dorada", "Vestuario progresivo", "Luz protectora"],
        "mood": "Equipamiento espiritual diario",
        "prompt_ai": "Person putting on pieces of shining spiritual armor, Ephesians 6 concept, gold and dark blue warrior theme, daily equipping, belt shield sword visible, spiritual warfare readiness, powerful protection"
    },
    {
        "id": "confesion-y-rendicion",
        "title": "Confesión y Rendición",
        "concept": "Persona arrodillada en luz, sombras cayendo, transparencia completa visible",
        "colors": ["#F39C12", "#3498DB", "#ECF0F1", "#34495E"],
        "elements": ["Postura de rendición", "Luz de transparencia", "Sombras desapareciendo"],
        "mood": "Vulnerabilidad sanadora ante Dios",
        "prompt_ai": "Person kneeling in light, shadows falling away, complete transparency, 1 John 1:7 walk in light concept, gold and blue confession theme, healing vulnerability, darkness fleeing, surrendered posture"
    },
    {
        "id": "plan-prevencion-recaidas",
        "title": "Plan de Prevención de Recaídas",
        "concept": "Mapa con rutas de escape marcadas, señales de alerta temprana visibles",
        "colors": ["#E74C3C", "#F39C12", "#27AE60", "#34495E"],
        "elements": ["Mapa estratégico", "Rutas de escape", "Sistema de alerta"],
        "mood": "Preparación estratégica preventiva",
        "prompt_ai": "Strategic map with escape routes marked, early warning signals visible, red alerts and green safe paths, relapse prevention concept, 1 Peter 5:8 vigilance theme, prepared warrior mindset"
    },

    # PLANES DE 30 DÍAS
    {
        "id": "fundamentos-de-la-fe",
        "title": "Fundamentos de la Fe",
        "concept": "Casa edificada sobre roca con cimientos profundos visibles, tormenta no afecta",
        "colors": ["#34495E", "#F39C12", "#3498DB", "#27AE60"],
        "elements": ["Fundamento de roca visible", "Casa estable", "Tormenta impotente"],
        "mood": "Bases sólidas inquebrantables",
        "prompt_ai": "House built on rock with deep visible foundations, storm unable to affect, Matthew 7:24 concept, dark blue and gold strong architecture, new believer essentials, unshakeable faith base"
    },
    {
        "id": "evangelio-y-habitos",
        "title": "Evangelio y Hábitos",
        "concept": "Cruz brillante con hábitos floreciendo como ramas, gracia formando práctica",
        "colors": ["#F39C12", "#27AE60", "#3498DB", "#ECF0F1"],
        "elements": ["Cruz central luminosa", "Ramas de hábitos", "Gracia visible"],
        "mood": "Evangelio formando vida práctica",
        "prompt_ai": "Glowing cross with habits flowering as branches, grace forming practice, gold and green growth, Titus 2:11-12 training concept, gospel-shaped habits, beautiful integration of truth and action"
    },
    {
        "id": "sanidad-del-corazon",
        "title": "Sanidad del Corazón",
        "concept": "Corazón agrietado siendo sanado con luz dorada, heridas cerrando progresivamente",
        "colors": ["#E74C3C", "#F39C12", "#3498DB", "#ECF0F1"],
        "elements": ["Corazón en proceso de sanidad", "Luz sanadora", "Heridas cerrándose"],
        "mood": "Restauración interna progresiva",
        "prompt_ai": "Cracked heart being healed with golden light, wounds closing progressively, red and gold healing theme, Psalm 34:18 nearness, inner restoration process, gentle compassionate healing, hope emerging"
    },
    {
        "id": "vida-ordenada",
        "title": "Vida Ordenada",
        "concept": "Calendario con prácticas espirituales integradas como bloques luminosos",
        "colors": ["#3498DB", "#F39C12", "#27AE60", "#ECF0F1"],
        "elements": ["Estructura de día visible", "Prácticas como bloques", "Orden armonioso"],
        "mood": "Ritmo espiritual sostenible",
        "prompt_ai": "Calendar with spiritual practices integrated as glowing blocks, daily rhythm visible, blue and gold ordered structure, rule of life concept, Psalm 5:3 morning priority, sustainable spiritual routine"
    }
]

# Generar documento markdown con especificaciones
def generate_specs_document():
    md_content = "# Especificaciones de Imágenes para Planes Espirituales\n\n"
    md_content += f"Total de planes: {len(plans_specs)}\n\n"
    md_content += "---\n\n"
    
    for i, plan in enumerate(plans_specs, 1):
        md_content += f"## {i}. {plan['title']}\n\n"
        md_content += f"**ID del archivo:** `{plan['id']}.jpg`\n\n"
        md_content += f"**Concepto Visual:**\n{plan['concept']}\n\n"
        md_content += f"**Paleta de Colores:**\n"
        for color in plan['colors']:
            md_content += f"- {color}\n"
        md_content += "\n"
        md_content += f"**Elementos Clave:**\n"
        for element in plan['elements']:
            md_content += f"- {element}\n"
        md_content += "\n"
        md_content += f"**Mood/Atmósfera:** {plan['mood']}\n\n"
        md_content += f"**Prompt para AI (DALL-E/Midjourney):**\n```\n{plan['prompt_ai']}\n```\n\n"
        md_content += "---\n\n"
    
    return md_content

# Guardar documento
specs_doc = generate_specs_document()
with open("PLAN_COVERS_SPECS.md", "w", encoding="utf-8") as f:
    f.write(specs_doc)

print(f"✅ Documento de especificaciones generado: PLAN_COVERS_SPECS.md")
print(f"📊 Total de planes: {len(plans_specs)}")
print("\n🎨 Próximos pasos:")
print("1. Usar los prompts en DALL-E, Midjourney, o Leonardo.AI")
print("2. Ajustar colores según paleta especificada")
print("3. Guardar como <plan-id>.jpg en assets/images/plan_covers/")
print("4. Dimensiones recomendadas: 600x900px (ratio 2:3)")
