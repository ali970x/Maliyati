from __future__ import annotations

import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "branding" / "maliyati_app_icon.png"


def save_icon(image: Image.Image, path: Path, size: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    resized = image.resize((size, size), Image.Resampling.LANCZOS)
    resized.save(path, format="PNG", optimize=True)


def generate_android(image: Image.Image) -> None:
    sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    res = ROOT / "android" / "app" / "src" / "main" / "res"
    for folder, size in sizes.items():
        save_icon(image, res / folder / "ic_launcher.png", size)


def generate_ios(image: Image.Image) -> None:
    app_icon = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    contents = json.loads((app_icon / "Contents.json").read_text(encoding="utf-8"))
    for item in contents["images"]:
        filename = item.get("filename")
        if not filename:
            continue
        points = float(item["size"].split("x", 1)[0])
        scale = float(item["scale"].removesuffix("x"))
        save_icon(image, app_icon / filename, round(points * scale))


def generate_web(image: Image.Image) -> None:
    icons = ROOT / "web" / "icons"
    for name, size in {
        "Icon-192.png": 192,
        "Icon-512.png": 512,
        "Icon-maskable-192.png": 192,
        "Icon-maskable-512.png": 512,
    }.items():
        save_icon(image, icons / name, size)
    save_icon(image, ROOT / "web" / "favicon.png", 32)


def main() -> None:
    image = Image.open(SOURCE).convert("RGB")
    generate_android(image)
    generate_ios(image)
    generate_web(image)


if __name__ == "__main__":
    main()
