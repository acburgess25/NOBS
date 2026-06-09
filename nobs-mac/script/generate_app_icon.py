#!/usr/bin/env python3
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
ICONSET = ROOT / "Resources" / "NOBS.iconset"


def rounded_rect(draw, xy, radius, fill):
    draw.rounded_rectangle(xy, radius=radius, fill=fill)


def shield_points(x, y, w, h):
    return [
        (x + w * 0.50, y),
        (x + w * 0.95, y + h * 0.18),
        (x + w * 0.95, y + h * 0.52),
        (x + w * 0.80, y + h * 0.78),
        (x + w * 0.50, y + h),
        (x + w * 0.20, y + h * 0.78),
        (x + w * 0.05, y + h * 0.52),
        (x + w * 0.05, y + h * 0.18),
    ]


def font(size):
    candidates = [
        "/System/Library/Fonts/SFNSRounded.ttf",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/System/Library/Fonts/Supplemental/Arial.ttf",
    ]
    for path in candidates:
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def make_icon(size):
    scale = size / 1024
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    # Friendly outer tile.
    rounded_rect(draw, (64 * scale, 64 * scale, 960 * scale, 960 * scale), 220 * scale, (247, 248, 251, 255))

    # Main secure shield.
    outer = shield_points(238 * scale, 150 * scale, 548 * scale, 720 * scale)
    draw.polygon(outer, fill=(17, 24, 39, 255))

    # Simple three-band gradient approximation that survives small icon sizes.
    inner = shield_points(302 * scale, 236 * scale, 420 * scale, 520 * scale)
    draw.polygon(inner, fill=(52, 120, 246, 255))
    draw.polygon(
        [
            (302 * scale, 486 * scale),
            (722 * scale, 360 * scale),
            (722 * scale, 756 * scale),
            (512 * scale, 820 * scale),
            (302 * scale, 756 * scale),
        ],
        fill=(48, 164, 108, 230),
    )
    draw.polygon(
        [
            (302 * scale, 630 * scale),
            (722 * scale, 496 * scale),
            (722 * scale, 756 * scale),
            (512 * scale, 820 * scale),
        ],
        fill=(217, 138, 24, 210),
    )

    # N monogram.
    fnt = font(int(300 * scale))
    text = "N"
    bbox = draw.textbbox((0, 0), text, font=fnt)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    draw.text(((size - tw) / 2, 420 * scale - th / 2), text, fill=(255, 255, 255, 255), font=fnt)

    # Small trust curve.
    draw.arc(
        (400 * scale, 628 * scale, 624 * scale, 760 * scale),
        start=18,
        end=162,
        fill=(255, 255, 255, 190),
        width=max(2, int(42 * scale)),
    )

    return image


def main():
    ICONSET.mkdir(parents=True, exist_ok=True)
    specs = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024),
    ]
    for name, size in specs:
        make_icon(size).save(ICONSET / name)


if __name__ == "__main__":
    main()
