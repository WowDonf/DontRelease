#!/usr/bin/env python3
"""
GitHub social-preview banner generator.

Renders the social banner at the recommended Open Graph size:
  - assets/Banner-1280.png  - 1280x640 (upload to GitHub Settings -> Social Preview)
  - assets/Banner-640.png   -  640x320 (fallback minimum size)

Layout: stop-sign icon on the left (sourced from assets/Icon-256.png),
addon name + tagline on the right, same crimson palette as the icon for
visual continuity.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

REPO_ROOT   = Path(__file__).resolve().parent.parent
ASSETS_DIR  = REPO_ROOT / "assets"
ICON_SOURCE = ASSETS_DIR / "Icon-256.png"   # produced by make_icon.py

FONT_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
FONT_OBLQ = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Oblique.ttf"

W, H = 1280, 640


def main():
    if not ICON_SOURCE.exists():
        raise SystemExit(
            f"Missing {ICON_SOURCE.relative_to(REPO_ROOT)}. "
            f"Run `python3 tools/make_icon.py` first."
        )

    img  = Image.new("RGBA", (W, H), (15, 5, 5, 255))
    draw = ImageDraw.Draw(img)
    bg_cx, bg_cy = W * 0.32, H * 0.50
    for i in range(220, 0, -1):
        r = (i / 220) * max(W, H) * 0.95
        t = 1.0 - (i / 220)
        red   = int(15 + (100 - 15) * t)
        green = int(3  + (20  - 3)  * t)
        blue  = int(3  + (20  - 3)  * t)
        draw.ellipse([bg_cx - r, bg_cy - r, bg_cx + r, bg_cy + r],
                     fill=(red, green, blue))

    # Vignette
    vmask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(vmask).ellipse(
        [int(-W * 0.10), int(-H * 0.10), int(W * 1.10), int(H * 1.10)], fill=210)
    vmask = vmask.filter(ImageFilter.GaussianBlur(radius=70))
    dark = Image.new("RGBA", (W, H), (0, 0, 0, 140))
    img = Image.alpha_composite(img,
        Image.composite(Image.new("RGBA", (W, H), (0, 0, 0, 0)), dark, vmask))

    # Icon left, with soft orange halo
    icon = Image.open(ICON_SOURCE).convert("RGBA")
    icon = icon.resize((380, 380), Image.LANCZOS)
    icon_x = 130
    icon_y = (H - 380) // 2

    halo = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    hcx, hcy = icon_x + 190, H // 2
    hr = int(380 * 0.62)
    ImageDraw.Draw(halo).ellipse(
        [hcx - hr, hcy - hr, hcx + hr, hcy + hr], fill=(255, 90, 50, 175))
    halo = halo.filter(ImageFilter.GaussianBlur(radius=75))
    img = Image.alpha_composite(img, halo)

    img.paste(icon, (icon_x, icon_y), icon)

    draw = ImageDraw.Draw(img)
    text_x      = icon_x + 380 + 60
    text_right  = W - 50
    text_avail  = text_right - text_x

    # Auto-fit title to column width
    title      = "DontRelease"
    title_size = 96
    while title_size > 40:
        f = ImageFont.truetype(FONT_BOLD, title_size)
        bbox = draw.textbbox((0, 0), title, font=f, anchor="lt")
        if (bbox[2] - bbox[0]) <= text_avail:
            break
        title_size -= 2
    title_font = ImageFont.truetype(FONT_BOLD, title_size)
    title_bbox = draw.textbbox((0, 0), title, font=title_font, anchor="lt")
    title_h    = title_bbox[3] - title_bbox[1]

    sep_pad   = 22
    sep_h     = 3
    tag_pad   = 22
    tag_lh    = 42
    tag_lines = ["A movable warning over the death dialog,",
                 "so you don't release on a raid wipe."]
    small_pad = 30

    tag_font   = ImageFont.truetype(FONT_BOLD, 30)
    small_font = ImageFont.truetype(FONT_OBLQ, 22)
    small_bbox = draw.textbbox((0, 0),
        "World of Warcraft Midnight  ·  Patch 12.x",
        font=small_font, anchor="lt")
    small_h = small_bbox[3] - small_bbox[1]

    block_h = (title_h + sep_pad + sep_h + tag_pad
               + tag_lh * len(tag_lines) + small_pad + small_h)
    y = (H - block_h) // 2

    sh_off = max(2, title_size // 28)
    draw.text((text_x + sh_off, y + sh_off), title,
              font=title_font, fill=(15, 0, 0, 220), anchor="lt")
    draw.text((text_x, y), title,
              font=title_font, fill=(255, 255, 255, 255), anchor="lt")
    y += title_h + sep_pad
    draw.rectangle([text_x, y, text_x + 380, y + sep_h],
                   fill=(255, 200, 60, 230))
    y += sep_h + tag_pad
    for line in tag_lines:
        draw.text((text_x, y), line, font=tag_font,
                  fill=(240, 220, 200, 255), anchor="lt")
        y += tag_lh
    y += small_pad - tag_lh + tag_lh
    draw.text((text_x, y),
              "World of Warcraft Midnight  ·  Patch 12.x",
              font=small_font, fill=(200, 140, 130, 230), anchor="lt")

    # Border frame
    draw.rectangle([0, 0, W - 1, H - 1], outline=(10, 2, 2, 255), width=3)
    draw.rectangle([3, 3, W - 4, H - 4], outline=(45, 15, 15, 255), width=1)

    out_full = ASSETS_DIR / "Banner-1280.png"
    out_half = ASSETS_DIR / "Banner-640.png"
    img.convert("RGB").save(out_full, optimize=True, quality=92)
    img.resize((W // 2, H // 2), Image.LANCZOS).convert("RGB").save(
        out_half, optimize=True, quality=92)

    print(f"Wrote {out_full.relative_to(REPO_ROOT)}  ({W}x{H})")
    print(f"Wrote {out_half.relative_to(REPO_ROOT)}  ({W//2}x{H//2})")


if __name__ == "__main__":
    main()
