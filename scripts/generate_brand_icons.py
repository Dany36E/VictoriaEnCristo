"""Genera iconos nativos y recursos web desde el emblema RGBA oficial."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "branding" / "logo_victoria_en_cristo_source.png"
MASTER = ROOT / "assets" / "branding" / "app_icon_master.png"
PLAY_STORE_ICON = ROOT / "assets" / "branding" / "google_play_icon_512.png"
WEB_LOGO = ROOT / "docs" / "logo-primary.webp"
OG_IMAGE = ROOT / "docs" / "og-victoria-en-cristo.png"

ICON_BACKGROUND = "#00163C"
PATH_BLUE = "#164D8C"
GOLD = "#F2C94C"


def contain(image: Image.Image, box: tuple[int, int]) -> Image.Image:
    result = image.copy()
    result.thumbnail(box, Image.Resampling.LANCZOS)
    return result


def color_tuple(value: str) -> tuple[int, int, int]:
    return Image.new("RGB", (1, 1), value).getpixel((0, 0))


def blue_background(size: tuple[int, int]) -> Image.Image:
    """Crea el fondo nocturno de marca sin recursos externos."""
    width, height = size
    base = Image.new("RGBA", size, (*color_tuple(ICON_BACKGROUND), 255))

    blue_glow = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(blue_glow)
    radius = int(max(width, height) * 0.58)
    center_x = width // 2
    center_y = int(height * 0.34)
    draw.ellipse(
        (center_x - radius, center_y - radius, center_x + radius, center_y + radius),
        fill=(*color_tuple(PATH_BLUE), 210),
    )
    blue_glow = blue_glow.filter(ImageFilter.GaussianBlur(max(24, radius // 2)))
    base = Image.alpha_composite(base, blue_glow)

    gold_glow = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(gold_glow)
    gold_radius = int(min(width, height) * 0.24)
    gold_y = int(height * 0.31)
    draw.ellipse(
        (center_x - gold_radius, gold_y - gold_radius, center_x + gold_radius, gold_y + gold_radius),
        fill=(*color_tuple(GOLD), 64),
    )
    gold_glow = gold_glow.filter(ImageFilter.GaussianBlur(max(18, gold_radius)))
    return Image.alpha_composite(base, gold_glow)


def compose(source: Image.Image, size: tuple[int, int], occupancy: float) -> Image.Image:
    canvas = blue_background(size)
    emblem = contain(source, (int(size[0] * occupancy), int(size[1] * occupancy)))
    position = ((size[0] - emblem.width) // 2, (size[1] - emblem.height) // 2)
    canvas.alpha_composite(emblem, position)
    return canvas.convert("RGB")


def prepare_brand_assets() -> None:
    if not SOURCE.exists():
        raise FileNotFoundError(f"Falta el arte maestro: {SOURCE.relative_to(ROOT)}")

    with Image.open(SOURCE).convert("RGBA") as source:
        if source.getchannel("A").getextrema() == (255, 255):
            raise ValueError("El arte maestro debe conservar un fondo transparente real.")

        # La web conserva exactamente el emblema y su transparencia.
        web_logo = contain(source, (900, 900))
        web_logo.save(WEB_LOGO, format="WEBP", quality=90, method=6)

        # Las tiendas exigen icono cuadrado opaco. Sólo se añade el fondo azul
        # de marca y una zona segura alrededor del emblema.
        master = compose(source, (1024, 1024), 0.82)
        master.save(MASTER, format="PNG", optimize=True)

        og = compose(source, (1200, 630), 0.78)
        og.save(OG_IMAGE, format="PNG", optimize=True)


def save_png(source: Image.Image, path: Path, pixels: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    source.resize((pixels, pixels), Image.Resampling.LANCZOS).save(
        path, format="PNG", optimize=True
    )


def main() -> None:
    prepare_brand_assets()
    with Image.open(MASTER).convert("RGB") as master:
        android = {
            "mipmap-mdpi": 48,
            "mipmap-hdpi": 72,
            "mipmap-xhdpi": 96,
            "mipmap-xxhdpi": 144,
            "mipmap-xxxhdpi": 192,
        }
        for folder, pixels in android.items():
            save_png(
                master,
                ROOT / "android" / "app" / "src" / "main" / "res" / folder / "ic_launcher.png",
                pixels,
            )

        ios = {
            "Icon-App-20x20@1x.png": 20,
            "Icon-App-20x20@2x.png": 40,
            "Icon-App-20x20@3x.png": 60,
            "Icon-App-29x29@1x.png": 29,
            "Icon-App-29x29@2x.png": 58,
            "Icon-App-29x29@3x.png": 87,
            "Icon-App-40x40@1x.png": 40,
            "Icon-App-40x40@2x.png": 80,
            "Icon-App-40x40@3x.png": 120,
            "Icon-App-60x60@2x.png": 120,
            "Icon-App-60x60@3x.png": 180,
            "Icon-App-76x76@1x.png": 76,
            "Icon-App-76x76@2x.png": 152,
            "Icon-App-83.5x83.5@2x.png": 167,
            "Icon-App-1024x1024@1x.png": 1024,
        }
        ios_dir = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
        for filename, pixels in ios.items():
            save_png(master, ios_dir / filename, pixels)

        macos = {
            "app_icon_16.png": 16,
            "app_icon_32.png": 32,
            "app_icon_64.png": 64,
            "app_icon_128.png": 128,
            "app_icon_256.png": 256,
            "app_icon_512.png": 512,
            "app_icon_1024.png": 1024,
        }
        macos_dir = ROOT / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
        for filename, pixels in macos.items():
            save_png(master, macos_dir / filename, pixels)

        web = {
            "favicon.png": 16,
            "icons/Icon-192.png": 192,
            "icons/Icon-512.png": 512,
            "icons/Icon-maskable-192.png": 192,
            "icons/Icon-maskable-512.png": 512,
        }
        for filename, pixels in web.items():
            save_png(master, ROOT / "web" / filename, pixels)

        save_png(master, PLAY_STORE_ICON, 512)
        master.save(
            ROOT / "windows" / "runner" / "resources" / "app_icon.ico",
            format="ICO",
            sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
        )

    print("Logo web, vista social e iconos Android, iOS/iPadOS, macOS, web y Windows generados.")


if __name__ == "__main__":
    main()
