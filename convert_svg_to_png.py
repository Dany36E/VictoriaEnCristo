"""
Convierte todos los SVGs de plan covers a PNG para Flutter
"""

import os
from pathlib import Path

try:
    from PIL import Image
    import cairosvg
except ImportError:
    print("❌ Instalando dependencias necesarias...")
    os.system("pip install pillow cairosvg")
    from PIL import Image
    import cairosvg

INPUT_DIR = Path("assets/images/plan_covers")
OUTPUT_DIR = INPUT_DIR

def convert_svg_to_png(svg_path: Path) -> bool:
    """Convierte un SVG a PNG de alta calidad"""
    try:
        png_path = svg_path.with_suffix('.png')
        
        # Convertir SVG a PNG con alta resolución (1024x1536)
        cairosvg.svg2png(
            url=str(svg_path),
            write_to=str(png_path),
            output_width=1024,
            output_height=1536,
        )
        
        return True
    except Exception as e:
        print(f"   ⚠️  Error: {e}")
        return False

def main():
    print("=" * 60)
    print("🎨 CONVIRTIENDO SVGs A PNGs")
    print("=" * 60)
    print(f"📁 Carpeta: {INPUT_DIR.absolute()}")
    print("=" * 60)
    print()
    
    svg_files = list(INPUT_DIR.glob("*.svg"))
    
    if not svg_files:
        print("❌ No se encontraron archivos SVG")
        return
    
    success_count = 0
    fail_count = 0
    
    for i, svg_file in enumerate(svg_files, 1):
        print(f"[{i:2d}/{len(svg_files)}] {svg_file.stem}.svg → .png ... ", end="")
        
        if convert_svg_to_png(svg_file):
            print("✅")
            success_count += 1
        else:
            print("❌")
            fail_count += 1
    
    print("\n" + "=" * 60)
    print(f"✅ Exitosos: {success_count}")
    if fail_count > 0:
        print(f"❌ Fallidos: {fail_count}")
    print("=" * 60)
    print("\n📱 Próximos pasos:")
    print("   1. Los PNGs están listos en assets/images/plan_covers/")
    print("   2. Hot reload: presiona 'r' en la terminal de Flutter")
    print("=" * 60)

if __name__ == "__main__":
    main()
