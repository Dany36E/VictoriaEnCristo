"""Genera iconos nativos reproducibles desde la marca SVG del proyecto."""

from pathlib import Path

import cairosvg
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SVG = ROOT / "assets" / "branding" / "victoria_mark.svg"
MASTER = ROOT / "assets" / "branding" / "app_icon_master.png"


def render_master() -> None:
    cairosvg.svg2png(
        url=str(SVG),
        write_to=str(MASTER),
        output_width=1024,
        output_height=1024,
    )


def save_png(source: Image.Image, path: Path, pixels: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    source.resize((pixels, pixels), Image.Resampling.LANCZOS).save(
        path,
        format="PNG",
        optimize=True,
    )


def main() -> None:
    render_master()
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

        master.save(
            ROOT / "windows" / "runner" / "resources" / "app_icon.ico",
            format="ICO",
            sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
        )

    print("Iconos Android, iOS, iPadOS y Windows generados desde victoria_mark.svg")


if __name__ == "__main__":
    main()
