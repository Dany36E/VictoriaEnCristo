"""
Script automatizado para generar covers de planes usando DALL-E 3
Requiere: pip install openai pillow requests
Uso: python generate_covers_dalle.py YOUR_OPENAI_API_KEY
"""

import os
import sys
import requests
from pathlib import Path
from time import sleep

# Configuración
OUTPUT_DIR = Path("assets/images/plan_covers")
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

PLANS = [
    {
        "id": "calma-en-la-tormenta",
        "prompt": "A cinematic spiritual illustration showing a person breathing deeply with closed eyes, dark storm clouds dramatically parting above them, brilliant golden light rays breaking through the darkness, hands open in peaceful surrender, transition from chaos to calm, blue and gold color palette, hope emerging from turmoil, professional digital art style, high quality, uplifting atmosphere"
    },
    {
        "id": "cortar-el-impulso",
        "prompt": "Powerful spiritual artwork of breaking chains shattering into golden light particles, an hourglass frozen in time floating nearby, glowing exit door visible in the background, dramatic purple and red tones, sense of liberation and escape, divine intervention moment, high quality digital art, cinematic lighting, hope and freedom theme"
    },
    {
        "id": "noche-segura",
        "prompt": "Peaceful bedroom scene at night, warm orange lamp casting soft glow, smartphone placed outside on a small table, crescent moon visible through window, serene atmosphere, cozy safe environment, blue and orange warm color palette, minimalist calming illustration, protection and rest theme, high quality digital art"
    },
    {
        "id": "restauracion-sin-culpa",
        "prompt": "Emotional spiritual scene of person rising from ground, divine radiant hand reaching down from heaven to help, beautiful sunrise with orange and blue sky in background, grace and restoration atmosphere, compassionate healing moment, warm golden light, hope emerging from darkness, high quality inspirational art"
    },
    {
        "id": "mente-en-tierra-firme",
        "prompt": "Symbolic spiritual artwork of mind as firm island with strong deep-rooted tree, turbulent ocean waves surrounding but not affecting the island, clear peaceful sky above, teal and dark blue color scheme, grounding and stability concept, serene yet powerful, high quality metaphorical illustration"
    },
    {
        "id": "rescate-digital",
        "prompt": "Modern digital detox illustration showing person walking confidently out of giant cracked smartphone screen into vibrant green nature, endless social media feed visibly cutting off behind them, blue technology vs green nature contrast, liberation and freedom theme, contemporary digital art style, inspiring and hopeful"
    },
    {
        "id": "mente-blindada",
        "prompt": "Powerful spiritual illustration of brain protected by radiant golden shield of light, dark negative thoughts bouncing off the shield, biblical scripture verses integrated into the protective barrier, gold and deep blue color palette, mental armor concept, divine protection theme, high quality symbolic art"
    },
    {
        "id": "pureza-con-proposito",
        "prompt": "Beautiful spiritual scene of pure glowing white crystalline heart with elegant roots reaching upward toward heaven, blooming pristine garden surrounding it, clean vibrant aesthetic, light blue and green natural tones, purity and divine purpose theme, hopeful inspirational artwork, high quality illustration"
    },
    {
        "id": "ansiedad-bajo-gobierno",
        "prompt": "Metaphorical illustration of mind as organized beautiful city with orderly streets bathed in golden light, small fading chaotic corner in shadow showing transformation, blue and gold illumination organizing everything, anxiety management concept, architectural spiritual metaphor, professional high quality art"
    },
    {
        "id": "dominio-propio-primeros-7",
        "prompt": "Inspiring scene of grand staircase with first step brightly illuminated in golden light, remaining steps visible ascending into hopeful distance, determined foot stepping forward onto lit step, gold and dark blue tones, journey beginning concept, commitment and hope theme, cinematic spiritual artwork"
    },
    {
        "id": "silencio-interior",
        "prompt": "Serene spiritual illustration of person in peaceful meditative posture, chaotic colorful sound waves dissolving into calm circle of tranquility around them, teal and soft white tones, inner silence and peace concept, zen-like atmosphere, minimalist aesthetic, high quality contemplative art"
    },
    {
        "id": "romper-la-rutina",
        "prompt": "Dynamic spiritual artwork of destructive circular loop dramatically breaking apart with golden cracks, person stepping decisively out toward new illuminated green path, red chains breaking combined with golden liberation light, pattern interrupt concept, transformative decisive moment, high quality inspirational illustration"
    },
    {
        "id": "identidad-antes-de-impulso",
        "prompt": "Profound spiritual scene of ornate mirror reflecting true identity with divine crown and 'beloved child' inscription glowing in gold, temptation fading into shadow beside mirror, gold and royal blue tones, identity as anchor concept, spiritual reality vs temptation theme, high quality symbolic art"
    },
    {
        "id": "fortaleza-en-la-debilidad",
        "prompt": "Powerful spiritual metaphor of cracked clay vessel with brilliant golden divine light shining intensely through cracks, more radiant than perfect vessel nearby, dark blue background, dramatic light and shadow contrast, 2 Corinthians 12:9 concept, strength perfected in weakness theme, high quality inspirational art"
    },
    {
        "id": "dia-a-dia-habitos-pequenos",
        "prompt": "Inspiring illustration of individual water drops forming into powerful flowing river, small consistent actions creating mighty current, blue and green natural gradient, micro habits compound effect visualization, momentum and growth theme, encouraging hopeful artwork, high quality motivational illustration"
    },
    {
        "id": "guardianes-del-corazon",
        "prompt": "Spiritual warfare illustration of vibrant red heart surrounded by guarded golden doors with protective luminous filters, Proverbs 4:23 theme, red and gold guardian aesthetic, intentional boundaries and protection concept, spiritual defense, high quality symbolic artwork with biblical foundation"
    },
    {
        "id": "reprograma-el-deseo",
        "prompt": "Neuroscience meets spirituality illustration of brain with glowing neural pathways visibly rewiring, desire redirecting from darkness toward divine light source, purple and blue electrical connections, transformation of appetite concept, hope in rewiring, high quality futuristic spiritual art"
    },
    {
        "id": "disciplina-del-ojo",
        "prompt": "Powerful covenant illustration of focused eye with golden selective shield, actively rejecting vanity while focusing on divine glory, Job 31:1 visual concept, gold and dark blue tones, intentional disciplined vision, spiritual discipline of sight theme, high quality symbolic biblical art"
    },
    {
        "id": "reemplazo-de-habitos",
        "prompt": "Mechanical spiritual metaphor of old gray gears being systematically replaced by new shining golden gears in functioning machine, transformation from gray to gold, systematic behavior change concept, arsenal of transformation tools, empowering mechanics theme, high quality industrial-spiritual illustration"
    },
    {
        "id": "ansiedad-reencuadre-diario",
        "prompt": "Cognitive transformation illustration of distorted mental picture being reframed with golden truth frame, image visibly correcting from distortion to clarity, blue and gold tones, CBT meets Scripture concept, daily perspective shift, transforming thoughts theme, high quality therapeutic spiritual art"
    },
    {
        "id": "pureza-reordenando-afectos",
        "prompt": "Beautiful spiritual illustration of vibrant red heart with multiple love arrows reorienting upward toward divine light instead of horizontal directions, red and gold passionate tones, Colossians 3:2 ordered affections concept, proper love hierarchy, passionate spiritual reorientation theme, high quality inspirational artwork"
    },
    {
        "id": "mundo-digital-regla-de-vida",
        "prompt": "Harmonious illustration of digital devices contained within beautiful garden with clear visible boundaries, digital sabbath visible, blue screens balanced with vibrant green nature, rule of life concept, intentional technology limits, peaceful integration theme, high quality balanced lifestyle art"
    },
    {
        "id": "soledad-y-comunidad",
        "prompt": "Emotional spiritual scene of lonely isolated person connecting to warm circle of community, isolation breaking apart, bridges of light forming between people, warm gold and welcoming blue tones, belonging concept, Psalm 68:6 family of God theme, high quality community illustration"
    },
    {
        "id": "sueno-santo",
        "prompt": "Peaceful spiritual nighttime scene with serene crescent moon, visible bedtime closing ritual elements, sacred rest atmosphere, dark blue and warm gold gentle tones, Psalm 4:8 sleep as trust concept, holy peaceful rest, bedtime routine as worship theme, high quality calming devotional art"
    },
    {
        "id": "palabra-en-la-boca",
        "prompt": "Powerful spiritual scene of person with glowing golden Scripture verses visibly coming from mouth as declarative light, illuminated biblical words floating in air, gold and blue radiant colors, Romans 10:17 faith by hearing concept, spoken Word power, memorization and declaration theme, high quality inspirational artwork"
    },
    {
        "id": "armadura-de-dios-racha-21",
        "prompt": "Epic spiritual warfare scene of warrior putting on pieces of shining golden spiritual armor, Ephesians 6 concept clearly visible, gold and dark blue warrior aesthetic, belt shield sword identifiable, daily spiritual equipping, powerful divine protection, high quality biblical warrior illustration"
    },
    {
        "id": "confesion-y-rendicion",
        "prompt": "Intimate spiritual scene of person kneeling in brilliant divine light, shadows and darkness falling away, complete transparency and vulnerability, 1 John 1:7 walk in light concept, gold and blue confession atmosphere, healing vulnerability, surrendered worship posture, high quality devotional art"
    },
    {
        "id": "plan-prevencion-recaidas",
        "prompt": "Strategic spiritual warfare map with clearly marked escape routes, early warning red alert signals visible, combination of red alerts and green safe paths, relapse prevention tactical concept, 1 Peter 5:8 vigilance theme, prepared warrior mindset, high quality strategic planning illustration"
    },
    {
        "id": "fundamentos-de-la-fe",
        "prompt": "Solid spiritual illustration of house built on massive rock foundation with deep visible roots, powerful storm unable to affect the structure, Matthew 7:24 parable concept, dark blue and gold strong architecture, unshakeable faith foundation for new believers, high quality biblical teaching art"
    },
    {
        "id": "evangelio-y-habitos",
        "prompt": "Beautiful spiritual scene of glowing golden cross with healthy habit branches flowering and blooming from it, grace forming practical life, gold and vibrant green growth, Titus 2:11-12 grace training concept, gospel-shaped daily habits, high quality integration of theology and practice illustration"
    },
    {
        "id": "sanidad-del-corazon",
        "prompt": "Tender spiritual healing scene of cracked heart progressively being healed with warm golden divine light, wounds visibly closing, red heart and gold healing glow, Psalm 34:18 God's nearness to brokenhearted, inner restoration process, gentle compassionate healing atmosphere, high quality emotional spiritual art"
    },
    {
        "id": "vida-ordenada",
        "prompt": "Organized spiritual life illustration of structured calendar with glowing spiritual practice blocks beautifully integrated, daily rhythm visible, blue and gold ordered harmonious structure, rule of life concept, Psalm 5:3 morning priority theme, sustainable balanced spiritual routine, high quality lifestyle planning art"
    }
]

def generate_with_dalle(api_key, plan_id, prompt):
    """Genera imagen usando DALL-E 3 y la guarda"""
    
    try:
        print(f"🎨 Generando: {plan_id}...")
        
        # API de OpenAI para DALL-E 3
        headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json"
        }
        
        data = {
            "model": "dall-e-3",
            "prompt": prompt,
            "n": 1,
            "size": "1024x1792",  # Formato vertical para covers
            "quality": "hd",
            "style": "vivid"
        }
        
        response = requests.post(
            "https://api.openai.com/v1/images/generations",
            headers=headers,
            json=data,
            timeout=120
        )
        
        if response.status_code != 200:
            print(f"❌ Error API: {response.status_code} - {response.text}")
            return False
        
        result = response.json()
        image_url = result['data'][0]['url']
        
        # Descargar imagen
        img_response = requests.get(image_url, timeout=60)
        if img_response.status_code == 200:
            output_path = OUTPUT_DIR / f"{plan_id}.jpg"
            with open(output_path, 'wb') as f:
                f.write(img_response.content)
            print(f"✅ Guardada: {output_path}")
            return True
        else:
            print(f"❌ Error descargando imagen")
            return False
            
    except Exception as e:
        print(f"❌ Error generando {plan_id}: {str(e)}")
        return False

def main():
    if len(sys.argv) < 2:
        print("❌ Uso: python generate_covers_dalle.py YOUR_OPENAI_API_KEY")
        print("\n📝 Obtén tu API key en: https://platform.openai.com/api-keys")
        sys.exit(1)
    
    api_key = sys.argv[1]
    
    print("=" * 60)
    print("🎨 GENERADOR DE COVERS PARA PLANES ESPIRITUALES")
    print("=" * 60)
    print(f"📁 Carpeta destino: {OUTPUT_DIR.absolute()}")
    print(f"📊 Total de planes: {len(PLANS)}")
    print("=" * 60)
    print()
    
    success_count = 0
    failed = []
    
    for i, plan in enumerate(PLANS, 1):
        print(f"\n[{i}/{len(PLANS)}] Procesando: {plan['id']}")
        
        if generate_with_dalle(api_key, plan['id'], plan['prompt']):
            success_count += 1
        else:
            failed.append(plan['id'])
        
        # Esperar entre llamadas para no exceder rate limits
        if i < len(PLANS):
            print("⏳ Esperando 3 segundos...")
            sleep(3)
    
    print("\n" + "=" * 60)
    print("📊 RESUMEN")
    print("=" * 60)
    print(f"✅ Exitosas: {success_count}/{len(PLANS)}")
    print(f"❌ Fallidas: {len(failed)}/{len(PLANS)}")
    
    if failed:
        print("\n❌ Planes que fallaron:")
        for plan_id in failed:
            print(f"   - {plan_id}")
        print("\n💡 Puedes reejecutar el script para reintentar solo los fallidos")
    else:
        print("\n🎉 ¡TODAS LAS IMÁGENES GENERADAS EXITOSAMENTE!")
        print("\n📱 Próximo paso:")
        print("   1. Verifica las imágenes en: assets/images/plan_covers/")
        print("   2. En tu app Flutter, presiona 'r' (hot reload)")
        print("   3. Las covers se cargarán automáticamente")
    
    print("=" * 60)

if __name__ == "__main__":
    main()
