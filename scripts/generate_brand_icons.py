"""Genera iconos nativos y el logo web desde el arte maestro del proyecto."""

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
SOURCE = (
    ROOT
    / "assets"
    / "branding"
    / "logo_victoria_en_cristo_source.png"
)
MASTER = ROOT / "assets" / "branding" / "app_icon_master.png"
PLAY_STORE_ICON = ROOT / "assets" / "branding" / "google_play_icon_512.png"
WEB_LOGO = ROOT / "docs" / "logo-primary.webp"

# El archivo entregado incluye un margen blanco alrededor de un rectángulo
# redondeado. Estas medidas aíslan el arte sin alterar la Biblia ni la cruz.
SOURCE_CROP = (47, 47, 1207, 1207)
SOURCE_RADIUS = 262
ICON_BACKGROUND = "#00163C"


def prepare_brand_assets() -> None:
    if not SOURCE.exists():
        raise FileNotFoundError(
            "Falta el arte maestro: "
            f"{SOURCE.relative_to(ROOT)}"
        )

    with Image.open(SOURCE).convert("RGB") as source:
        if source.size != (1254, 1254):
            raise ValueError(
                "El arte maestro debe conservar su tamaño original "
                f"de 1254x1254 px; se recibió {source.size}."
            )

        cropped = source.crop(SOURCE_CROP)
        mask = Image.new("L", cropped.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            (0, 0, cropped.width - 1, cropped.height - 1),
            radius=SOURCE_RADIUS,
            fill=255,
        )

        # Las tiendas aplican sus propias máscaras. El maestro debe ser
        # cuadrado y opaco, así que el exterior se extiende con el azul de
        # marca en lugar de conservar el borde blanco del archivo recibido.
        icon_content = cropped.resize(
            (1024, 1024),
            Image.Resampling.LANCZOS,
        )
        icon_mask = mask.resize(
            (1024, 1024),
            Image.Resampling.LANCZOS,
        )
        master = Image.new("RGB", (1024, 1024), ICON_BACKGROUND)
        master.paste(icon_content, (0, 0), icon_mask)
        master.save(
            MASTER,
            format="PNG",
            optimize=True,
        )

        # En la web sí conviene conservar la silueta redondeada y transparente
        # para que el logo pueda vivir sobre el fondo nocturno.
        web_logo = Image.new("RGBA", cropped.size, (0, 0, 0, 0))
        web_logo.paste(cropped.convert("RGBA"), (0, 0), mask)
        web_logo.thumbnail((920, 920), Image.Resampling.LANCZOS)
        web_logo.save(
            WEB_LOGO,
            format="WEBP",
            quality=92,
            method=6,
        )


def save_png(source: Image.Image, path: Path, pixels: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    source.resize((pixels, pixels), Image.Resampling.LANCZOS).save(
        path,
        format="PNG",
        optimize=True,
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

    print(
        "Logo web e iconos Android, iOS, iPadOS, macOS, web y Windows "
        "generados desde logo_victoria_en_cristo.png"
    )


if __name__ == "__main__":
    main()
