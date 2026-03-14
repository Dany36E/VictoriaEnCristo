"""
Generador de SVG placeholders únicos para covers de planes
Crea SVGs con diseño profesional único por plan
"""

import os
from pathlib import Path

OUTPUT_DIR = Path("assets/images/plan_covers")
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

def create_svg_cover(plan_id, title, colors, icon_path, pattern="circles"):
    """Genera un SVG único para el plan"""
    
    bg_color = colors[0]
    accent_color = colors[1]
    text_color = colors[2]
    
    # Patrones de fondo únicos
    patterns = {
        "circles": f'''
            <circle cx="50" cy="50" r="100" fill="{accent_color}" opacity="0.1"/>
            <circle cx="350" cy="200" r="120" fill="{accent_color}" opacity="0.08"/>
            <circle cx="150" cy="400" r="80" fill="{accent_color}" opacity="0.12"/>
        ''',
        "waves": f'''
            <path d="M0,200 Q150,150 300,200 T600,200" stroke="{accent_color}" stroke-width="2" fill="none" opacity="0.2"/>
            <path d="M0,250 Q150,200 300,250 T600,250" stroke="{accent_color}" stroke-width="2" fill="none" opacity="0.15"/>
            <path d="M0,300 Q150,250 300,300 T600,300" stroke="{accent_color}" stroke-width="2" fill="none" opacity="0.1"/>
        ''',
        "rays": f'''
            <line x1="300" y1="0" x2="300" y2="900" stroke="{accent_color}" stroke-width="80" opacity="0.05"/>
            <line x1="150" y1="0" x2="150" y2="900" stroke="{accent_color}" stroke-width="40" opacity="0.08"/>
            <line x1="450" y1="0" x2="450" y2="900" stroke="{accent_color}" stroke-width="40" opacity="0.08"/>
        ''',
        "grid": f'''
            <rect x="0" y="0" width="200" height="300" fill="{accent_color}" opacity="0.03"/>
            <rect x="200" y="300" width="200" height="300" fill="{accent_color}" opacity="0.05"/>
            <rect x="400" y="0" width="200" height="300" fill="{accent_color}" opacity="0.04"/>
        '''
    }
    
    svg_content = f'''<?xml version="1.0" encoding="UTF-8"?>
<svg width="600" height="900" viewBox="0 0 600 900" xmlns="http://www.w3.org/2000/svg">
    <!-- Background -->
    <rect width="600" height="900" fill="{bg_color}"/>
    
    <!-- Pattern -->
    {patterns.get(pattern, patterns["circles"])}
    
    <!-- Gradient overlay -->
    <defs>
        <linearGradient id="grad_{plan_id}" x1="0%" y1="0%" x2="0%" y2="100%">
            <stop offset="0%" style="stop-color:{bg_color};stop-opacity:0.3" />
            <stop offset="100%" style="stop-color:{bg_color};stop-opacity:0.95" />
        </linearGradient>
    </defs>
    <rect width="600" height="900" fill="url(#grad_{plan_id})"/>
    
    <!-- Icon -->
    <g transform="translate(300, 350)">
        {icon_path}
    </g>
    
    <!-- Title -->
    <text x="300" y="650" font-family="Arial, sans-serif" font-size="32" font-weight="bold" 
          fill="{text_color}" text-anchor="middle" opacity="0.9">
        {title[:20]}
    </text>
    {f'<text x="300" y="690" font-family="Arial, sans-serif" font-size="32" font-weight="bold" fill="{text_color}" text-anchor="middle" opacity="0.9">{title[20:]}</text>' if len(title) > 20 else ''}
</svg>'''
    
    return svg_content

# Definición de todos los planes con diseño único
PLANS = [
    {
        "id": "calma-en-la-tormenta",
        "title": "Calma en la Tormenta",
        "colors": ["#2C3E50", "#3498DB", "#ECF0F1"],
        "pattern": "waves",
        "icon": '<circle cx="0" cy="0" r="60" fill="#3498DB" opacity="0.6"/><path d="M-30,-10 Q0,-30 30,-10" stroke="#ECF0F1" stroke-width="3" fill="none"/><path d="M-20,10 Q0,-5 20,10" stroke="#ECF0F1" stroke-width="3" fill="none"/>'
    },
    {
        "id": "cortar-el-impulso",
        "title": "Cortar el Impulso",
        "colors": ["#8E44AD", "#E74C3C", "#F1C40F"],
        "pattern": "rays",
        "icon": '<rect x="-40" y="-10" width="80" height="20" fill="#F1C40F" opacity="0.8"/><rect x="-50" y="-5" width="30" height="10" fill="#E74C3C" transform="rotate(-20)"/><rect x="20" y="-5" width="30" height="10" fill="#E74C3C" transform="rotate(20)"/>'
    },
    {
        "id": "noche-segura",
        "title": "Noche Segura",
        "colors": ["#34495E", "#F39C12", "#ECF0F1"],
        "pattern": "circles",
        "icon": '<circle cx="20" cy="-20" r="30" fill="#F39C12" opacity="0.7"/><path d="M-15,-35 Q-5,-25 5,-35" stroke="#ECF0F1" stroke-width="2" fill="none"/><rect x="-25" y="10" width="50" height="30" rx="5" fill="#ECF0F1" opacity="0.3"/>'
    },
    {
        "id": "restauracion-sin-culpa",
        "title": "Restauración Sin Culpa",
        "colors": ["#E67E22", "#3498DB", "#ECF0F1"],
        "pattern": "rays",
        "icon": '<path d="M0,-50 L0,50" stroke="#F39C12" stroke-width="4"/><path d="M-30,-30 L0,0 L30,-30" stroke="#ECF0F1" stroke-width="3" fill="none"/><circle cx="0" cy="0" r="15" fill="#3498DB" opacity="0.7"/>'
    },
    {
        "id": "mente-en-tierra-firme",
        "title": "Mente en Tierra Firme",
        "colors": ["#16A085", "#2C3E50", "#ECF0F1"],
        "pattern": "waves",
        "icon": '<rect x="-40" y="-5" width="80" height="50" rx="5" fill="#16A085" opacity="0.6"/><rect x="-30" y="-20" width="60" height="15" rx="3" fill="#ECF0F1" opacity="0.8"/><circle cx="0" cy="-12" r="3" fill="#2C3E50"/>'
    },
    {
        "id": "rescate-digital",
        "title": "Rescate Digital",
        "colors": ["#3498DB", "#27AE60", "#95A5A6"],
        "pattern": "grid",
        "icon": '<rect x="-35" y="-50" width="70" height="100" rx="8" fill="#95A5A6" opacity="0.7"/><rect x="-30" y="-45" width="60" height="70" fill="#3498DB" opacity="0.5"/><path d="M-10,30 L0,50 L10,30" stroke="#27AE60" stroke-width="4" fill="none"/>'
    },
    {
        "id": "mente-blindada",
        "title": "Mente Blindada",
        "colors": ["#F39C12", "#34495E", "#ECF0F1"],
        "pattern": "circles",
        "icon": '<circle cx="0" cy="0" r="50" fill="#34495E" opacity="0.7"/><path d="M-20,-20 Q0,-35 20,-20 L20,20 Q0,35 -20,20 Z" fill="#F39C12" opacity="0.8"/><circle cx="0" cy="-5" r="15" fill="#ECF0F1" opacity="0.9"/>'
    },
    {
        "id": "pureza-con-proposito",
        "title": "Pureza con Propósito",
        "colors": ["#ECF0F1", "#3498DB", "#27AE60"],
        "pattern": "rays",
        "icon": '<path d="M0,-40 Q-20,-20 -10,10 Q0,0 10,10 Q20,-20 0,-40 Z" fill="#3498DB" opacity="0.7"/><circle cx="0" cy="-10" r="8" fill="#ECF0F1"/><path d="M-5,20 Q0,35 5,20" stroke="#27AE60" stroke-width="2" fill="none"/>'
    },
    {
        "id": "ansiedad-bajo-gobierno",
        "title": "Ansiedad Bajo Gobierno",
        "colors": ["#3498DB", "#2C3E50", "#F39C12"],
        "pattern": "grid",
        "icon": '<rect x="-40" y="-40" width="80" height="80" fill="#2C3E50" opacity="0.3"/><rect x="-30" y="-30" width="20" height="20" fill="#F39C12" opacity="0.7"/><rect x="10" y="-30" width="20" height="20" fill="#F39C12" opacity="0.7"/><rect x="-30" y="10" width="20" height="20" fill="#F39C12" opacity="0.7"/><rect x="10" y="10" width="20" height="20" fill="#F39C12" opacity="0.7"/>'
    },
    {
        "id": "dominio-propio-primeros-7",
        "title": "Dominio Propio: Primeros 7",
        "colors": ["#F39C12", "#34495E", "#27AE60"],
        "pattern": "rays",
        "icon": '<rect x="-50" y="20" width="100" height="15" fill="#34495E" opacity="0.5"/><rect x="-50" y="0" width="100" height="15" fill="#34495E" opacity="0.3"/><rect x="-50" y="-20" width="100" height="15" fill="#34495E" opacity="0.2"/><circle cx="-30" cy="27" r="12" fill="#F39C12"/>'
    },
    {
        "id": "silencio-interior",
        "title": "Silencio Interior",
        "colors": ["#3498DB", "#ECF0F1", "#95A5A6"],
        "pattern": "circles",
        "icon": '<circle cx="0" cy="0" r="50" fill="#ECF0F1" opacity="0.3"/><circle cx="0" cy="0" r="35" fill="#3498DB" opacity="0.4"/><circle cx="0" cy="0" r="20" fill="#ECF0F1" opacity="0.6"/><circle cx="0" cy="0" r="5" fill="#3498DB"/>'
    },
    {
        "id": "romper-la-rutina",
        "title": "Romper la Rutina",
        "colors": ["#E74C3C", "#F39C12", "#27AE60"],
        "pattern": "waves",
        "icon": '<circle cx="0" cy="0" r="45" stroke="#E74C3C" stroke-width="3" fill="none" opacity="0.7" stroke-dasharray="10,5"/><path d="M30,0 L50,0 L60,10" stroke="#27AE60" stroke-width="4" fill="none"/><circle cx="60" cy="10" r="5" fill="#F39C12"/>'
    },
    {
        "id": "identidad-antes-de-impulso",
        "title": "Identidad Antes de Impulso",
        "colors": ["#F39C12", "#3498DB", "#ECF0F1"],
        "pattern": "rays",
        "icon": '<rect x="-30" y="-45" width="60" height="90" rx="5" fill="#3498DB" opacity="0.3"/><path d="M-15,-20 Q0,-35 15,-20 L15,20 L0,30 L-15,20 Z" fill="#F39C12" opacity="0.8"/><circle cx="0" cy="-10" r="8" fill="#ECF0F1"/>'
    },
    {
        "id": "fortaleza-en-la-debilidad",
        "title": "Fortaleza en la Debilidad",
        "colors": ["#F39C12", "#34495E", "#ECF0F1"],
        "pattern": "rays",
        "icon": '<path d="M-30,-20 L-30,30 L30,30 L30,-20 Z" fill="#34495E" opacity="0.6"/><line x1="-20" y1="-10" x2="-20" y2="20" stroke="#F39C12" stroke-width="3"/><line x1="0" y1="-10" x2="0" y2="20" stroke="#F39C12" stroke-width="3"/><line x1="20" y1="-10" x2="20" y2="20" stroke="#F39C12" stroke-width="3"/>'
    },
    {
        "id": "dia-a-dia-habitos-pequenos",
        "title": "Día a Día: Hábitos Pequeños",
        "colors": ["#3498DB", "#27AE60", "#F39C12"],
        "pattern": "waves",
        "icon": '<circle cx="-30" cy="-20" r="5" fill="#3498DB" opacity="0.5"/><circle cx="-20" cy="-10" r="6" fill="#3498DB" opacity="0.6"/><circle cx="-10" cy="0" r="7" fill="#3498DB" opacity="0.7"/><circle cx="0" cy="10" r="8" fill="#27AE60" opacity="0.8"/><circle cx="10" cy="20" r="10" fill="#27AE60" opacity="0.9"/>'
    },
    {
        "id": "guardianes-del-corazon",
        "title": "Guardianes del Corazón",
        "colors": ["#E74C3C", "#F39C12", "#34495E"],
        "pattern": "circles",
        "icon": '<path d="M0,-25 Q-30,-25 -30,5 Q-30,35 0,55 Q30,35 30,5 Q30,-25 0,-25 Z" fill="#E74C3C" opacity="0.7"/><rect x="-45" y="-10" width="15" height="40" fill="#F39C12" opacity="0.6"/><rect x="30" y="-10" width="15" height="40" fill="#F39C12" opacity="0.6"/>'
    },
    {
        "id": "reprograma-el-deseo",
        "title": "Reprograma el Deseo",
        "colors": ["#8E44AD", "#3498DB", "#F39C12"],
        "pattern": "grid",
        "icon": '<circle cx="0" cy="0" r="40" fill="#8E44AD" opacity="0.5"/><path d="M-20,0 Q-10,-15 0,0 T20,0" stroke="#3498DB" stroke-width="2" fill="none"/><path d="M-20,0 Q-10,15 0,0 T20,0" stroke="#F39C12" stroke-width="2" fill="none"/>'
    },
    {
        "id": "disciplina-del-ojo",
        "title": "Disciplina del Ojo",
        "colors": ["#34495E", "#F39C12", "#3498DB"],
        "pattern": "rays",
        "icon": '<ellipse cx="0" cy="0" rx="45" ry="30" fill="#ECF0F1" opacity="0.8"/><circle cx="0" cy="0" r="18" fill="#3498DB" opacity="0.9"/><circle cx="0" cy="0" r="8" fill="#34495E"/><path d="M-50,-5 L-45,0 L-50,5" stroke="#F39C12" stroke-width="2" fill="none"/>'
    },
    {
        "id": "reemplazo-de-habitos",
        "title": "Reemplazo de Hábitos",
        "colors": ["#95A5A6", "#F39C12", "#27AE60"],
        "pattern": "grid",
        "icon": '<circle cx="-15" cy="0" r="25" fill="#95A5A6" opacity="0.5"/><circle cx="15" cy="0" r="25" fill="#F39C12" opacity="0.7"/><path d="M-15,0 L15,0" stroke="#27AE60" stroke-width="3"/><circle cx="0" cy="0" r="8" fill="#27AE60"/>'
    },
    {
        "id": "ansiedad-reencuadre-diario",
        "title": "Ansiedad: Reencuadre Diario",
        "colors": ["#3498DB", "#F39C12", "#2C3E50"],
        "pattern": "circles",
        "icon": '<rect x="-40" y="-30" width="80" height="60" rx="5" fill="#2C3E50" opacity="0.3"/><rect x="-35" y="-25" width="70" height="50" fill="#3498DB" opacity="0.5"/><rect x="-45" y="-35" width="90" height="70" stroke="#F39C12" stroke-width="3" fill="none"/>'
    },
    {
        "id": "pureza-reordenando-afectos",
        "title": "Pureza: Reordenando Afectos",
        "colors": ["#E74C3C", "#F39C12", "#3498DB"],
        "pattern": "rays",
        "icon": '<path d="M0,-30 Q-25,-30 -25,0 Q-25,25 0,45 Q25,25 25,0 Q25,-30 0,-30 Z" fill="#E74C3C" opacity="0.8"/><path d="M0,10 L0,-50" stroke="#F39C12" stroke-width="3"/><path d="M-5,-45 L0,-50 L5,-45" stroke="#F39C12" stroke-width="2" fill="none"/>'
    },
    {
        "id": "mundo-digital-regla-de-vida",
        "title": "Mundo Digital: Regla de Vida",
        "colors": ["#3498DB", "#27AE60", "#F39C12"],
        "pattern": "waves",
        "icon": '<rect x="-35" y="-40" width="70" height="80" rx="8" fill="#3498DB" opacity="0.4"/><path d="M-20,10 Q-10,0 0,10 T20,10" stroke="#27AE60" stroke-width="3" fill="none"/><circle cx="0" cy="-15" r="5" fill="#F39C12"/>'
    },
    {
        "id": "soledad-y-comunidad",
        "title": "Soledad y Comunidad",
        "colors": ["#3498DB", "#F39C12", "#27AE60"],
        "pattern": "circles",
        "icon": '<circle cx="0" cy="0" r="12" fill="#3498DB" opacity="0.7"/><circle cx="-30" cy="-20" r="10" fill="#F39C12" opacity="0.5"/><circle cx="30" cy="-20" r="10" fill="#F39C12" opacity="0.5"/><circle cx="-30" cy="20" r="10" fill="#F39C12" opacity="0.5"/><circle cx="30" cy="20" r="10" fill="#F39C12" opacity="0.5"/>'
    },
    {
        "id": "sueno-santo",
        "title": "Sueño Santo",
        "colors": ["#34495E", "#F39C12", "#3498DB"],
        "pattern": "circles",
        "icon": '<circle cx="15" cy="-15" r="25" fill="#F39C12" opacity="0.6"/><path d="M-15,-30 Q-5,-20 5,-30" stroke="#ECF0F1" stroke-width="2" fill="none"/><rect x="-25" y="5" width="50" height="25" rx="3" fill="#34495E" opacity="0.5"/>'
    },
    {
        "id": "palabra-en-la-boca",
        "title": "Palabra en la Boca",
        "colors": ["#F39C12", "#3498DB", "#ECF0F1"],
        "pattern": "rays",
        "icon": '<circle cx="0" cy="0" r="30" fill="#ECF0F1" opacity="0.7"/><path d="M-15,5 Q0,-5 15,5" stroke="#3498DB" stroke-width="3" fill="none"/><text x="0" y="-10" font-size="20" fill="#F39C12" text-anchor="middle" font-weight="bold">"</text>'
    },
    {
        "id": "armadura-de-dios-racha-21",
        "title": "Armadura de Dios: Racha de 21",
        "colors": ["#F39C12", "#34495E", "#E74C3C"],
        "pattern": "rays",
        "icon": '<rect x="-35" y="-20" width="70" height="50" fill="#34495E" opacity="0.6"/><circle cx="0" cy="5" r="25" fill="#F39C12" opacity="0.7"/><path d="M0,-40 L-15,-25 L0,-30 L15,-25 Z" fill="#E74C3C" opacity="0.8"/>'
    },
    {
        "id": "confesion-y-rendicion",
        "title": "Confesión y Rendición",
        "colors": ["#F39C12", "#3498DB", "#ECF0F1"],
        "pattern": "rays",
        "icon": '<circle cx="0" cy="-30" r="50" fill="#F39C12" opacity="0.2"/><circle cx="0" cy="0" r="20" fill="#3498DB" opacity="0.6"/><rect x="-5" y="15" width="10" height="30" fill="#ECF0F1" opacity="0.7"/>'
    },
    {
        "id": "plan-prevencion-recaidas",
        "title": "Plan de Prevención de Recaídas",
        "colors": ["#E74C3C", "#F39C12", "#27AE60"],
        "pattern": "grid",
        "icon": '<rect x="-40" y="-30" width="80" height="60" stroke="#E74C3C" stroke-width="2" fill="none" opacity="0.6"/><path d="M-30,0 L-10,-20 L10,0 L30,-20" stroke="#27AE60" stroke-width="3" fill="none"/><circle cx="-30" cy="0" r="4" fill="#F39C12"/><circle cx="30" cy="-20" r="4" fill="#F39C12"/>'
    },
    {
        "id": "fundamentos-de-la-fe",
        "title": "Fundamentos de la Fe",
        "colors": ["#34495E", "#F39C12", "#3498DB"],
        "pattern": "circles",
        "icon": '<rect x="-40" y="0" width="80" height="40" fill="#34495E" opacity="0.6"/><path d="M-30,-35 L0,-5 L30,-35 Z" fill="#F39C12" opacity="0.7"/><rect x="-25" y="-30" width="50" height="30" fill="#3498DB" opacity="0.4"/>'
    },
    {
        "id": "evangelio-y-habitos",
        "title": "Evangelio y Hábitos",
        "colors": ["#F39C12", "#27AE60", "#3498DB"],
        "pattern": "rays",
        "icon": '<rect x="-3" y="-40" width="6" height="80" fill="#F39C12" opacity="0.8"/><rect x="-40" y="-3" width="80" height="6" fill="#F39C12" opacity="0.8"/><path d="M-20,-25 Q-10,-15 -20,-5" stroke="#27AE60" stroke-width="2" fill="none"/><path d="M20,-25 Q10,-15 20,-5" stroke="#27AE60" stroke-width="2" fill="none"/>'
    },
    {
        "id": "sanidad-del-corazon",
        "title": "Sanidad del Corazón",
        "colors": ["#E74C3C", "#F39C12", "#3498DB"],
        "pattern": "rays",
        "icon": '<path d="M0,-30 Q-25,-30 -25,0 Q-25,25 0,45 Q25,25 25,0 Q25,-30 0,-30 Z" fill="#E74C3C" opacity="0.7"/><line x1="-15" y1="-10" x2="15" y2="20" stroke="#F39C12" stroke-width="3"/><circle cx="0" cy="5" r="8" fill="#F39C12" opacity="0.9"/>'
    },
    {
        "id": "vida-ordenada",
        "title": "Vida Ordenada",
        "colors": ["#3498DB", "#F39C12", "#27AE60"],
        "pattern": "grid",
        "icon": '<rect x="-40" y="-35" width="35" height="25" fill="#3498DB" opacity="0.5"/><rect x="-40" y="-5" width="35" height="25" fill="#F39C12" opacity="0.5"/><rect x="-40" y="25" width="35" height="25" fill="#27AE60" opacity="0.5"/><rect x="5" y="-35" width="35" height="25" fill="#3498DB" opacity="0.5"/><rect x="5" y="-5" width="35" height="25" fill="#F39C12" opacity="0.5"/>'
    }
]

def generate_all_covers():
    """Genera todos los SVGs"""
    print("=" * 60)
    print("🎨 GENERANDO SVG PLACEHOLDERS ÚNICOS")
    print("=" * 60)
    print(f"📁 Carpeta: {OUTPUT_DIR.absolute()}")
    print(f"📊 Total: {len(PLANS)} planes")
    print("=" * 60)
    print()
    
    for i, plan in enumerate(PLANS, 1):
        svg_content = create_svg_cover(
            plan['id'],
            plan['title'],
            plan['colors'],
            plan['icon'],
            plan['pattern']
        )
        
        output_path = OUTPUT_DIR / f"{plan['id']}.svg"
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(svg_content)
        
        print(f"[{i:2d}/{len(PLANS)}] ✅ {plan['id']}.svg")
    
    print("\n" + "=" * 60)
    print("🎉 TODOS LOS SVGs GENERADOS")
    print("=" * 60)
    print("\n📱 Próximos pasos:")
    print("   1. Los SVGs se cargarán automáticamente en Flutter")
    print("   2. Hot reload: presiona 'r' en la terminal")
    print("   3. Cada plan tiene diseño único con su paleta de colores")
    print("\n💡 Para reemplazar con imágenes reales:")
    print("   - Renombra <plan-id>.svg a <plan-id>.svg.bak")
    print("   - Coloca <plan-id>.jpg en la misma carpeta")
    print("=" * 60)

if __name__ == "__main__":
    generate_all_covers()
