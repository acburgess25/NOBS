#!/usr/bin/env python3
"""Generate the NOBS monogram AppIcon and website favicons."""

from __future__ import annotations

import json
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    import subprocess
    import sys

    subprocess.run([sys.executable, "-m", "pip", "install", "--quiet", "pillow"], check=True)
    from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
TOKENS = json.loads((ROOT / "design" / "tokens.json").read_text(encoding="utf-8"))
ICON_SET = ROOT / "NOBS" / "Assets.xcassets" / "AppIcon.appiconset"
WEB_PUBLIC = ROOT / "website" / "public"

SERIF_CANDIDATES = [
    "/System/Library/Fonts/Supplemental/Baskerville-Bold.ttf",
    "/System/Library/Fonts/Supplemental/Georgia Bold.ttf",
    "/System/Library/Fonts/Times.ttc",
]

IOS_SIZES = [
    ("iphone", "20x20", 20, 2),
    ("iphone", "20x20", 20, 3),
    ("iphone", "29x29", 29, 2),
    ("iphone", "29x29", 29, 3),
    ("iphone", "40x40", 40, 2),
    ("iphone", "40x40", 40, 3),
    ("iphone", "60x60", 60, 2),
    ("iphone", "60x60", 60, 3),
    ("ipad", "20x20", 20, 1),
    ("ipad", "20x20", 20, 2),
    ("ipad", "29x29", 29, 1),
    ("ipad", "29x29", 29, 2),
    ("ipad", "40x40", 40, 1),
    ("ipad", "40x40", 40, 2),
    ("ipad", "76x76", 76, 1),
    ("ipad", "76x76", 76, 2),
    ("ipad", "83.5x83.5", 83.5, 2),
    ("ios-marketing", "1024x1024", 1024, 1),
]


def hex_rgb(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4))


def load_serif(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for path in SERIF_CANDIDATES:
        if Path(path).exists():
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                continue
    return ImageFont.load_default()


def render_icon(px: int) -> Image.Image:
    scale = 4
    canvas = px * scale
    field = hex_rgb(TOKENS["color"]["cream"])
    monogram = hex_rgb(TOKENS["icon"]["foreground"])
    circle = hex_rgb(TOKENS["icon"]["background"])
    image = Image.new("RGB", (canvas, canvas), field)
    draw = ImageDraw.Draw(image)

    inset = int(canvas * 0.105)
    draw.ellipse((inset, inset, canvas - inset, canvas - inset), fill=circle)

    font = load_serif(int(canvas * 0.62))
    bbox = draw.textbbox((0, 0), "N", font=font)
    width = bbox[2] - bbox[0]
    height = bbox[3] - bbox[1]
    draw.text(
        ((canvas - width) / 2 - bbox[0], (canvas - height) / 2 - bbox[1] - canvas * 0.018),
        "N",
        fill=monogram,
        font=font,
    )
    return image.resize((px, px), Image.Resampling.LANCZOS)


def generate_ios_icons() -> None:
    ICON_SET.mkdir(parents=True, exist_ok=True)
    images: list[dict[str, str]] = []

    for idiom, size_str, pt, scale in IOS_SIZES:
        px = round(pt * scale)
        filename = (
            "icon-ios-marketing-1024x1024@1x.png"
            if idiom == "ios-marketing"
            else f"icon-{idiom}-{size_str}@{scale}x.png"
        )
        render_icon(px).save(ICON_SET / filename, optimize=True)
        images.append(
            {
                "filename": filename,
                "idiom": idiom,
                "scale": f"{scale}x",
                "size": size_str,
            }
        )

    contents = {"images": images, "info": {"author": "xcode", "version": 1}}
    (ICON_SET / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n", encoding="utf-8")
    print(f"Generated {len(images)} iOS icons in {ICON_SET}")


def generate_web_favicons() -> None:
    WEB_PUBLIC.mkdir(parents=True, exist_ok=True)
    for name, px in [
        ("favicon-32.png", 32),
        ("apple-touch-icon.png", 180),
        ("favicon-192.png", 192),
    ]:
        render_icon(px).save(WEB_PUBLIC / name, optimize=True)
    render_icon(32).save(WEB_PUBLIC / "favicon.ico")
    print(f"Generated website favicons in {WEB_PUBLIC}")


def main() -> None:
    generate_ios_icons()
    generate_web_favicons()


if __name__ == "__main__":
    main()
