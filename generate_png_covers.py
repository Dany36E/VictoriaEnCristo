"""
Generador de PNG placeholders únicos para covers de planes
Crea PNGs con diseño profesional único por plan usando Pillow
"""

import os
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

OUTPUT_DIR = Path("assets/images/plan_covers")
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# Tamaño de las imágenes (vertical)
WIDTH = 1024
HEIGHT = 1536

def hex_to_rgb(hex_color):
    """Convierte color hex a tupla RGB"""
    hex_color = hex_color.lstrip('#')
    return tuple(int(hex_color[i:i+2], 16) for i in (0, 2, 4))

def create_gradient(draw, width, height, colors, angle=90):
    """Crea un gradiente vertical"""
    color1 = hex_to_rgb(colors[0])
    color2 = hex_to_rgb(colors[1])
    
    for y in range(height):
        r = int(color1[0] + (color2[0] - color1[0]) * y / height)
        g = int(color1[1] + (color2[1] - color1[1]) * y / height)
        b = int(color1[2] + (color2[2] - color1[2]) * y / height)
        draw.line([(0, y), (width, y)], fill=(r, g, b))

def create_cover(plan_id, title, colors):
    """Genera un PNG único para el plan"""
    
    # Crear imagen
    img = Image.new('RGB', (WIDTH, HEIGHT), color=hex_to_rgb(colors[0]))
    draw = ImageDraw.Draw(img)
    
    # Fondo con gradiente
    create_gradient(draw, WIDTH, HEIGHT, colors)
    
    # Semi-transparencia superior
    overlay = Image.new('RGBA', (WIDTH, HEIGHT), (0, 0, 0, 0))
    overlay_draw = ImageDraw.Draw(overlay)
    
    # Patrón decorativo (círculos sutiles)
    accent = hex_to_rgb(colors[1])
    overlay_draw.ellipse([50, 50, 350, 350], fill=(*accent, 20))
    overlay_draw.ellipse([600, 400, 900, 700], fill=(*accent, 15))
    overlay_draw.ellipse([100, 1000, 400, 1300], fill=(*accent, 25))
    
    # Combinar con el fondo
    img = Image.alpha_composite(img.convert('RGBA'), overlay).convert('RGB')
    draw = ImageDraw.Draw(img)
    
    # Gradiente oscuro en la parte inferior para el texto
    for y in range(HEIGHT - 400, HEIGHT):
        alpha = int(255 * (y - (HEIGHT - 400)) / 400)
        draw.line([(0, y), (WIDTH, y)], fill=(0, 0, 0, alpha))
    
    # Texto del título
    try:
        # Intentar usar una fuente del sistema
        font_title = ImageFont.truetype("C:\\Windows\\Fonts\\ariblk.ttf", 64)
        font_days = ImageFont.truetype("C:\\Windows\\Fonts\\arial.ttf", 40)
    except:
        font_title = ImageFont.load_default()
        font_days = ImageFont.load_default()
    
    # Título en la parte inferior
    text_color = hex_to_rgb(colors[2])
    
    # Dividir título si es muy largo
    words = title.split()
    lines = []
    current_line = []
    
    for word in words:
        test_line = ' '.join(current_line + [word])
        bbox = draw.textbbox((0, 0), test_line, font=font_title)
        if bbox[2] - bbox[0] < WIDTH - 100:
            current_line.append(word)
        else:
            if current_line:
                lines.append(' '.join(current_line))
            current_line = [word]
    if current_line:
        lines.append(' '.join(current_line))
    
    # Dibujar título centrado
    y_position = HEIGHT - 250
    for line in lines:
        bbox = draw.textbbox((0, 0), line, font=font_title)
        text_width = bbox[2] - bbox[0]
        x_position = (WIDTH - text_width) // 2
        
        # Sombra
        draw.text((x_position + 3, y_position + 3), line, fill=(0, 0, 0, 200), font=font_title)
        # Texto
        draw.text((x_position, y_position), line, fill=text_color, font=font_title)
        y_position += 80
    
    return img

# Definición de todos los planes con diseño único
PLANS = [
    {"id": "calma-en-la-tormenta", "title": "Calma en la\nTormenta", "colors": ["#2C3E50", "#3498DB", "#ECF0F1"]},
    {"id": "cortar-el-impulso", "title": "Cortar el\nImpulso", "colors": ["#8E44AD", "#E74C3C", "#F1C40F"]},
    {"id": "noche-segura", "title": "Noche\nSegura", "colors": ["#34495E", "#F39C12", "#ECF0F1"]},
    {"id": "restauracion-sin-culpa", "title": "Restauración\nSin Culpa", "colors": ["#E67E22", "#3498DB", "#ECF0F1"]},
    {"id": "mente-en-tierra-firme", "title": "Mente en\nTierra Firme", "colors": ["#16A085", "#2C3E50", "#ECF0F1"]},
    {"id": "rescate-digital", "title": "Rescate\nDigital", "colors": ["#3498DB", "#27AE60", "#95A5A6"]},
    {"id": "mente-blindada", "title": "Mente\nBlindada", "colors": ["#F39C12", "#34495E", "#ECF0F1"]},
    {"id": "pureza-con-proposito", "title": "Pureza con\nPropósito", "colors": ["#ECF0F1", "#3498DB", "#27AE60"]},
    {"id": "ansiedad-bajo-gobierno", "title": "Ansiedad Bajo\nGobierno", "colors": ["#3498DB", "#2C3E50", "#F39C12"]},
    {"id": "dominio-propio-primeros-7", "title": "Dominio Propio\nPrimeros 7", "colors": ["#F39C12", "#34495E", "#27AE60"]},
    {"id": "silencio-interior", "title": "Silencio\nInterior", "colors": ["#3498DB", "#ECF0F1", "#95A5A6"]},
    {"id": "romper-la-rutina", "title": "Romper la\nRutina", "colors": ["#E74C3C", "#F39C12", "#27AE60"]},
    {"id": "identidad-antes-de-impulso", "title": "Identidad Antes\nde Impulso", "colors": ["#F39C12", "#3498DB", "#ECF0F1"]},
    {"id": "fortaleza-en-la-debilidad", "title": "Fortaleza en\nla Debilidad", "colors": ["#F39C12", "#34495E", "#ECF0F1"]},
    {"id": "dia-a-dia-habitos-pequenos", "title": "Día a Día\nHábitos Pequeños", "colors": ["#3498DB", "#27AE60", "#F39C12"]},
    {"id": "guardianes-del-corazon", "title": "Guardianes\ndel Corazón", "colors": ["#E74C3C", "#F39C12", "#34495E"]},
    {"id": "reprograma-el-deseo", "title": "Reprograma\nel Deseo", "colors": ["#8E44AD", "#3498DB", "#F39C12"]},
    {"id": "disciplina-del-ojo", "title": "Disciplina\ndel Ojo", "colors": ["#34495E", "#F39C12", "#3498DB"]},
    {"id": "reemplazo-de-habitos", "title": "Reemplazo de\nHábitos", "colors": ["#95A5A6", "#F39C12", "#27AE60"]},
    {"id": "ansiedad-reencuadre-diario", "title": "Ansiedad\nReencuadre Diario", "colors": ["#3498DB", "#F39C12", "#2C3E50"]},
    {"id": "pureza-reordenando-afectos", "title": "Pureza\nReordenando Afectos", "colors": ["#E74C3C", "#F39C12", "#3498DB"]},
    {"id": "mundo-digital-regla-de-vida", "title": "Mundo Digital\nRegla de Vida", "colors": ["#3498DB", "#27AE60", "#F39C12"]},
    {"id": "soledad-y-comunidad", "title": "Soledad y\nComunidad", "colors": ["#3498DB", "#F39C12", "#27AE60"]},
    {"id": "sueno-santo", "title": "Sueño\nSanto", "colors": ["#34495E", "#F39C12", "#3498DB"]},
    {"id": "palabra-en-la-boca", "title": "Palabra en\nla Boca", "colors": ["#F39C12", "#3498DB", "#ECF0F1"]},
    {"id": "armadura-de-dios-racha-21", "title": "Armadura de Dios\nRacha de 21", "colors": ["#F39C12", "#34495E", "#E74C3C"]},
    {"id": "confesion-y-rendicion", "title": "Confesión y\nRendición", "colors": ["#F39C12", "#3498DB", "#ECF0F1"]},
    {"id": "plan-prevencion-recaidas", "title": "Prevención de\nRecaídas", "colors": ["#E74C3C", "#F39C12", "#27AE60"]},
    {"id": "fundamentos-de-la-fe", "title": "Fundamentos\nde la Fe", "colors": ["#34495E", "#F39C12", "#3498DB"]},
    {"id": "evangelio-y-habitos", "title": "Evangelio y\nHábitos", "colors": ["#F39C12", "#27AE60", "#3498DB"]},
    {"id": "sanidad-del-corazon", "title": "Sanidad del\nCorazón", "colors": ["#E74C3C", "#F39C12", "#3498DB"]},
    {"id": "vida-ordenada", "title": "Vida\nOrdenada", "colors": ["#3498DB", "#F39C12", "#27AE60"]},
]

def generate_all_covers():
    """Genera todos los PNGs"""
    print("=" * 60)
    print("🎨 GENERANDO PNG PLACEHOLDERS ÚNICOS")
    print("=" * 60)
    print(f"📁 Carpeta: {OUTPUT_DIR.absolute()}")
    print(f"📊 Total: {len(PLANS)} planes")
    print(f"📐 Tamaño: {WIDTH}x{HEIGHT}px")
    print("=" * 60)
    print()
    
    for i, plan in enumerate(PLANS, 1):
        img = create_cover(
            plan['id'],
            plan['title'],
            plan['colors']
        )
        
        output_path = OUTPUT_DIR / f"{plan['id']}.png"
        img.save(output_path, 'PNG', optimize=True)
        
        print(f"[{i:2d}/{len(PLANS)}] ✅ {plan['id']}.png")
    
    print("\n" + "=" * 60)
    print("🎉 TODOS LOS PNGs GENERADOS")
    print("=" * 60)
    print("\n📱 Próximos pasos:")
    print("   1. Los PNGs se cargarán automáticamente en Flutter")
    print("   2. Hot reload: presiona 'r' en la terminal")
    print("   3. Cada plan tiene diseño único con su paleta de colores")
    print("=" * 60)

if __name__ == "__main__":
    generate_all_covers()
