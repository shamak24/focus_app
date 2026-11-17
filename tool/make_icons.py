"""Draws the app icon in the app's clay style and writes every size Android
and the web build need.

    python -I tool/make_icons.py            # write all icons
    python -I tool/make_icons.py preview    # only write build/icon_preview.png

The icon: a peach tile holding a raised clay disc with the focus ring (a
pressed-in track and a rounded progress arc, as on the timer screen) and a
bolt in the middle. Colours come from the Peach theme in clay_theme.dart.
"""

import math
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SS = 4  # supersampling for smooth edges

PEACH_TOP = (255, 196, 168)
PEACH_BOTTOM = (255, 146, 110)
SURFACE = (255, 248, 242)
TRACK = (255, 232, 218)
PRIMARY = (255, 138, 101)
PRIMARY_DEEP = (238, 104, 66)
SHADOW = (176, 92, 56)


def vgradient(size, top, bottom):
    w, h = size
    col = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / max(1, h - 1)
        col.putpixel((0, y), tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))
    return col.resize((w, h))


def blurred(mask, radius):
    return mask.filter(ImageFilter.GaussianBlur(radius))


def disc_mask(size, cx, cy, r):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).ellipse((cx - r, cy - r, cx + r, cy + r), fill=255)
    return m


def paste_color(canvas, color, mask, alpha=1.0):
    layer = Image.new("RGBA", canvas.size, color + (0,))
    layer.putalpha(mask.point(lambda v: round(v * alpha)))
    canvas.alpha_composite(layer)


def bolt_points(cx, cy, s):
    pts = [(0.10, -0.62), (-0.40, 0.08), (-0.04, 0.08), (-0.12, 0.62), (0.40, -0.08), (0.04, -0.08)]
    return [(cx + x * s, cy + y * s) for x, y in pts]


def draw_emblem(canvas, cx, cy, r):
    """The raised disc, ring and bolt, centred on (cx, cy) with radius r."""
    size = canvas.size

    # Soft drop shadow below-right, then a tighter contact shadow.
    paste_color(canvas, SHADOW, blurred(disc_mask(size, cx + r * 0.06, cy + r * 0.12, r), r * 0.16), 0.55)
    paste_color(canvas, SHADOW, blurred(disc_mask(size, cx + r * 0.02, cy + r * 0.04, r), r * 0.05), 0.35)

    # The disc, with light from the top-left and shade at the bottom-right.
    disc = disc_mask(size, cx, cy, r)
    paste_color(canvas, SURFACE, disc)
    sheen = blurred(disc_mask(size, cx - r * 0.35, cy - r * 0.4, r * 0.75), r * 0.35)
    paste_color(canvas, (255, 255, 255), ImageChops.multiply(sheen, disc), 0.7)
    shade = ImageChops.subtract(disc, blurred(disc_mask(size, cx - r * 0.1, cy - r * 0.14, r * 0.98), r * 0.12))
    paste_color(canvas, SHADOW, shade, 0.22)

    # Pressed-in track: a ring with shade along its top inside edge.
    ring_r, ring_w = r * 0.70, r * 0.20
    outer = disc_mask(size, cx, cy, ring_r + ring_w / 2)
    inner = disc_mask(size, cx, cy, ring_r - ring_w / 2)
    track = ImageChops.subtract(outer, inner)
    paste_color(canvas, TRACK, track)
    lip = ImageChops.subtract(track, ImageChops.offset(track, 0, round(ring_w * 0.22)))
    paste_color(canvas, SHADOW, blurred(lip, ring_w * 0.12), 0.35)

    # Progress arc (three quarters, from 12 o'clock) with round caps.
    arc = Image.new("L", size, 0)
    d = ImageDraw.Draw(arc)
    # PIL grows a thick arc inwards from its box, so pad the box by half the
    # width to keep the stroke centred on the ring (where the caps go).
    arc_w = round(ring_w * 0.78)
    box_r = ring_r + arc_w / 2
    box = (cx - box_r, cy - box_r, cx + box_r, cy + box_r)
    start, end = -90, 180
    d.arc(box, start, end, fill=255, width=arc_w)
    cap = ring_w * 0.39
    for ang in (start, end):
        a = math.radians(ang)
        px, py = cx + ring_r * math.cos(a), cy + ring_r * math.sin(a)
        d.ellipse((px - cap, py - cap, px + cap, py + cap), fill=255)
    arc_shadow = ImageChops.offset(arc, round(ring_w * 0.05), round(ring_w * 0.14))
    paste_color(canvas, SHADOW, blurred(arc_shadow, ring_w * 0.12), 0.45)
    paste_color(canvas, PRIMARY, arc)
    arc_shine = ImageChops.multiply(arc, ImageChops.offset(ImageChops.invert(arc), 0, round(ring_w * 0.16)))
    paste_color(canvas, (255, 255, 255), blurred(arc_shine, ring_w * 0.05), 0.45)

    # Bolt, raised a little off the disc.
    bolt = Image.new("L", size, 0)
    ImageDraw.Draw(bolt).polygon(bolt_points(cx, cy, r * 0.48), fill=255)
    paste_color(canvas, SHADOW, blurred(ImageChops.offset(bolt, round(r * 0.015), round(r * 0.035)), r * 0.025), 0.3)
    paste_color(canvas, PRIMARY_DEEP, bolt)
    top_light = ImageChops.multiply(bolt, vgradient(size, (150,) * 3, (0,) * 3).convert("L"))
    paste_color(canvas, (255, 214, 190), top_light, 0.5)


def tile_background(px):
    return vgradient((px, px), PEACH_TOP, PEACH_BOTTOM).convert("RGBA")


def full_icon(px, rounded=True):
    """Legacy / web icon: rounded peach tile with the emblem."""
    s = px * SS
    canvas = tile_background(s)
    draw_emblem(canvas, s * 0.5, s * 0.49, s * 0.33)
    if rounded:
        mask = Image.new("L", (s, s), 0)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, s - 1, s - 1), radius=s * 0.23, fill=255)
        canvas.putalpha(mask)
    return canvas.resize((px, px), Image.LANCZOS)


def adaptive_foreground(px):
    """Adaptive icon foreground: emblem inside the 66/108 safe zone."""
    s = px * SS
    canvas = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    draw_emblem(canvas, s * 0.5, s * 0.49, s * 0.255)
    return canvas.resize((px, px), Image.LANCZOS)


def adaptive_background(px):
    return tile_background(px * SS).resize((px, px), Image.LANCZOS)


def save(img, *parts):
    path = os.path.join(ROOT, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=True)
    print("wrote", os.path.relpath(path, ROOT))


def main():
    if sys.argv[1:] == ["preview"]:
        preview = Image.new("RGBA", (1100, 560), (245, 240, 236, 255))
        preview.alpha_composite(full_icon(512), (20, 24))
        fg = adaptive_background(432)
        fg.alpha_composite(adaptive_foreground(432))
        circle = Image.new("L", (432, 432), 0)
        ImageDraw.Draw(circle).ellipse((0, 0, 431, 431), fill=255)
        fg.putalpha(circle)
        preview.alpha_composite(fg, (600, 64))
        for i, px in enumerate((48, 96)):
            preview.alpha_composite(full_icon(px), (600 + i * 120, 500 - px))
        save(preview, "build", "icon_preview.png")
        return

    densities = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
    res = ("android", "app", "src", "main", "res")
    for name, k in densities.items():
        save(full_icon(round(48 * k)), *res, f"mipmap-{name}", "ic_launcher.png")
        save(adaptive_foreground(round(108 * k)), *res, f"mipmap-{name}", "ic_launcher_foreground.png")
        save(adaptive_background(round(108 * k)), *res, f"mipmap-{name}", "ic_launcher_background.png")

    save(full_icon(192), "web", "icons", "Icon-192.png")
    save(full_icon(512), "web", "icons", "Icon-512.png")
    save(full_icon(192, rounded=False), "web", "icons", "Icon-maskable-192.png")
    save(full_icon(512, rounded=False), "web", "icons", "Icon-maskable-512.png")
    save(full_icon(32), "web", "favicon.png")


if __name__ == "__main__":
    main()
