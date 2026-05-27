#!/usr/bin/env python3
r"""
DontRelease icon generator.

Renders the addon icon at 64, 128, and 256 px:
  - assets/Icon-64.png   - reference / archival
  - assets/Icon-128.png  - documentation embeds
  - assets/Icon-256.png  - CurseForge / Wago listing

Also writes the in-game icon to the repo root:
  - Icon.tga             - 64x64 with descriptor byte patched to top-left
                           origin (otherwise WoW renders it upside-down).
The TOC's `## IconTexture: Interface\AddOns\DontRelease\Icon` directive
picks this up at runtime.

Design: dark crimson radial gradient + red stop-sign octagon with bold
white "WAIT" text. Recognizable at 64x64 and dramatic at 256x256.
"""
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

# Paths are resolved relative to this script so it can be invoked from
# anywhere ("python3 tools/make_icon.py" or "cd tools && python3 ...").
REPO_ROOT  = Path(__file__).resolve().parent.parent
ASSETS_DIR = REPO_ROOT / "assets"
ASSETS_DIR.mkdir(exist_ok=True)

FONT_PATH = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def create_icon(size):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 255))
    draw = ImageDraw.Draw(img)
    cx, cy = size / 2, size / 2

    # Background: crimson radial gradient (brighter center, dark edges)
    steps = max(60, size // 2)
    for i in range(steps, 0, -1):
        r = (i / steps) * size * 0.75
        t = 1.0 - (i / steps)
        red   = int(20 + (95 - 20) * t)
        green = int(4  + (15 - 4)  * t)
        blue  = int(4  + (15 - 4)  * t)
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(red, green, blue, 255))

    # Beveled border (dark rim + 1px highlight on TL, shadow on BR)
    rim = max(2, size // 32)
    for i in range(rim):
        draw.rectangle([i, i, size - 1 - i, size - 1 - i],
                       outline=(8, 2, 2, 255), width=1)
    hl_w = max(1, size // 80)
    for i in range(rim, rim + hl_w):
        draw.line([(i, i), (size - 1 - i, i)], fill=(90, 35, 35, 255), width=1)
        draw.line([(i, i), (i, size - 1 - i)], fill=(90, 35, 35, 255), width=1)
        draw.line([(size - 1 - i, i), (size - 1 - i, size - 1 - i)],
                  fill=(2, 0, 0, 255), width=1)
        draw.line([(i, size - 1 - i), (size - 1 - i, size - 1 - i)],
                  fill=(2, 0, 0, 255), width=1)

    # Soft orange glow halo behind the octagon
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse(
        [cx - size * 0.40, cy - size * 0.40,
         cx + size * 0.40, cy + size * 0.40],
        fill=(255, 80, 50, 130))
    glow = glow.filter(ImageFilter.GaussianBlur(radius=max(2, size // 24)))
    img = Image.alpha_composite(img, glow)
    draw = ImageDraw.Draw(img)

    # Stop-sign octagon (white rim + red body)
    angles = [math.radians(22.5 + 45 * i) for i in range(8)]
    def octagon(radius):
        return [(cx + radius * math.cos(a), cy + radius * math.sin(a)) for a in angles]
    draw.polygon(octagon(size * 0.42), fill=(245, 245, 240, 255))
    draw.polygon(octagon(size * 0.38), fill=(195, 28, 28, 255))

    # Darker red inset edge for depth
    edge = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    pts  = octagon(size * 0.38)
    ImageDraw.Draw(edge).line(pts + [pts[0]],
        fill=(120, 10, 10, 200), width=max(1, size // 80))
    img = Image.alpha_composite(img, edge)
    draw = ImageDraw.Draw(img)

    # "WAIT" text, auto-fit width
    text       = "WAIT"
    target_w   = size * 0.38 * 1.55
    font_size  = int(size * 0.30)
    for _ in range(40):
        f    = ImageFont.truetype(FONT_PATH, font_size)
        bbox = draw.textbbox((0, 0), text, font=f, anchor="lt")
        if (bbox[2] - bbox[0]) <= target_w:
            break
        font_size -= 1
    font = ImageFont.truetype(FONT_PATH, font_size)
    sh   = max(1, size // 80)
    draw.text((cx + sh, cy + sh), text, font=font,
              fill=(20, 0, 0, 220), anchor="mm")
    draw.text((cx, cy), text, font=font,
              fill=(255, 255, 255, 255), anchor="mm")

    return img


def main():
    # Marketing PNGs go in assets/
    for size in (64, 128, 256):
        out = ASSETS_DIR / f"Icon-{size}.png"
        create_icon(size).save(out, optimize=True)
        print(f"Wrote {out.relative_to(REPO_ROOT)} ({size}x{size})")

    # In-game TGA at the repo root.
    # WoW's TGA loader assumes top-left origin regardless of the descriptor
    # byte, so we pre-flip the pixel rows AND set byte 17 to 0x28 (top-left,
    # 8 alpha bits). The file then reads correctly for both WoW and any
    # conformant TGA reader (PIL, ImageMagick, etc.).
    tga_path  = REPO_ROOT / "Icon.tga"
    icon_64   = create_icon(64).transpose(Image.FLIP_TOP_BOTTOM)
    icon_64.save(tga_path, compression=None)
    with open(tga_path, "r+b") as f:
        f.seek(17)
        f.write(bytes([0x28]))

    # Verify the descriptor byte landed correctly
    with open(tga_path, "rb") as f:
        h = f.read(18)
    origin_y = "top" if h[17] & 0x20 else "bottom"
    print(f"Wrote {tga_path.relative_to(REPO_ROOT)} "
          f"(64x64, origin {origin_y}-left, descriptor=0x{h[17]:02x})")

    # And put a 256 copy at the root as Icon.png — CurseForge auto-detects
    # this for the project thumbnail when it's at the repo root.
    create_icon(256).save(REPO_ROOT / "Icon.png", optimize=True)
    print(f"Wrote Icon.png (256x256, marketing)")


if __name__ == "__main__":
    main()
