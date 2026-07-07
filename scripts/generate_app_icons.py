#!/usr/bin/env python3
"""Generate NOBS AppIcon asset catalog entries from approved brand colors."""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    subprocess.run([sys.executable, "-m", "pip", "install", "--quiet", "pillow"], check=True)
    from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ICON_SET = ROOT / "NOBS" / "Assets.xcassets" / "AppIcon.appiconset"

# Approved brand guide (design/nobs-brand-guide.png)
PROCESS_GREEN = (153, 222, 190)  # #99DEBE
DEEP_OBSIDIAN = (16, 52, 73)  # #103449

SERIF_CANDIDATES = [
    "/System/Library/Fonts/Supplemental/Baskerville-Bold.ttf",
    "/System/Library/Fonts/Supplemental/Georgia Bold.ttf",
    "/System/Library/Fonts/Times.ttc",
    "/Library/Fonts/NewYork.ttf",
]

SIZES = [
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


def load_serif(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for path in SERIF_CANDIDATES:
        if Path(path).exists():
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                continue
    return ImageFont.load_default()


def label_for(px: int) -> str:
    return "NOBS" if px >= 120 else "N"


def main() -> None:
    ICON_SET.mkdir(parents=True, exist_ok=True)
    images: list[dict[str, str]] = []

    for idiom, size_str, pt, scale in SIZES:
        px = int(round(pt * scale))
        if idiom == "ios-marketing":
            filename = "icon-ios-marketing-1024x1024@1x.png"
        else:
            filename = f"icon-{idiom}-{size_str}@{scale}x.png"

        text = label_for(px)
        img = Image.new("RGB", (px, px), PROCESS_GREEN)
        draw = ImageDraw.Draw(img)
        font_size = max(int(px * (0.34 if text == "NOBS" else 0.52)), 10)
        font = load_serif(font_size)

        bbox = draw.textbbox((0, 0), text, font=font)
        tw = bbox[2] - bbox[0]
        th = bbox[3] - bbox[1]
        draw.text(
            ((px - tw) // 2 - bbox[0], (px - th) // 2 - bbox[1]),
            text,
            fill=DEEP_OBSIDIAN,
            font=font,
        )
        img.save(ICON_SET / filename)
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
    print(f"Generated {len(images)} icons in {ICON_SET}")


if __name__ == "__main__":
    main()
