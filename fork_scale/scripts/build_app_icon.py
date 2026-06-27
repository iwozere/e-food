"""
Generate the ForkScale app icon (fork + knife flanking a plate) in the brand
palette, then write the masters consumed by flutter_launcher_icons:

  assets/icon/app_icon.png            full-bleed 1024 master (iOS + legacy Android)
  assets/icon/app_icon_foreground.png transparent motif in the Android adaptive safe zone

Run:  python scripts/build_app_icon.py   (requires Pillow)
Then: dart run flutter_launcher_icons
"""

import os
from PIL import Image, ImageDraw

# ── Brand palette (matches lib/core/theme/app_theme.dart) ──────────────────
GREEN = (27, 67, 50)     # #1B4332  primary  → background field
AMBER = (244, 165, 35)   # #F4A523  accent   → utensils
CREAM = (255, 248, 240)  # #FFF8F0  background→ plate
RING = (226, 202, 165)   # soft tan → plate inner ring

SIZE = 1024
SS = 4                    # supersample factor for smooth edges
S = SIZE * SS

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "icon")


def rrect(d, x0, y0, x1, y1, r, fill):
    d.rounded_rectangle([x0 * SS, y0 * SS, x1 * SS, y1 * SS], radius=r * SS, fill=fill)


def draw_motif(d):
    """Draws the plate + utensils onto a transparent supersampled canvas."""
    cx, cy = 512, 540

    # Plate: cream disc with a subtle inner ring.
    pr = 232
    d.ellipse([(cx - pr) * SS, (cy - pr) * SS, (cx + pr) * SS, (cy + pr) * SS], fill=CREAM)
    ir = 166
    d.ellipse(
        [(cx - ir) * SS, (cy - ir) * SS, (cx + ir) * SS, (cy + ir) * SS],
        outline=RING, width=9 * SS,
    )

    # Fork (left): four tines, a head bar merging them, and a handle.
    fx = 195
    tine_w, gap = 16, 12
    cluster_w = 4 * tine_w + 3 * gap          # 100
    left = fx - cluster_w // 2
    for i in range(4):
        x = left + i * (tine_w + gap)
        rrect(d, x, 298, x + tine_w, 440, tine_w // 2, AMBER)
    rrect(d, fx - cluster_w // 2, 412, fx + cluster_w // 2, 486, 22, AMBER)  # head
    rrect(d, fx - 20, 470, fx + 20, 766, 20, AMBER)                          # handle

    # Knife (right): rounded-tip blade over a handle.
    kx = 829
    rrect(d, kx - 30, 300, kx + 30, 498, 30, AMBER)   # blade (rounded top)
    rrect(d, kx - 20, 478, kx + 20, 766, 20, AMBER)   # handle


def build():
    os.makedirs(OUT_DIR, exist_ok=True)

    # Hi-res motif on its own transparent layer, rendered once and reused at two
    # scales so both masters stay crisp.
    motif_hi = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    draw_motif(ImageDraw.Draw(motif_hi))

    # 1) Full-bleed master: green field + motif (flattened, no alpha).
    motif = motif_hi.resize((SIZE, SIZE), Image.LANCZOS)
    base = Image.new("RGBA", (SIZE, SIZE), GREEN + (255,))
    base.alpha_composite(motif)
    base.convert("RGB").save(os.path.join(OUT_DIR, "app_icon.png"))

    # 2) Adaptive foreground: the motif must fill most of the canvas because the
    # generated adaptive-icon XML adds its own 16% inset for the safe zone.
    # Scaling up by 1.3 lands the content at ~90% width here → ~0.6 after inset,
    # matching the iOS master's presence. Overflow is only transparent padding.
    fg = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    big = int(SIZE * 1.3)
    sm = motif_hi.resize((big, big), Image.LANCZOS)
    off = (SIZE - big) // 2  # negative → centred with edges cropped
    fg.alpha_composite(sm, (off, off))
    fg.save(os.path.join(OUT_DIR, "app_icon_foreground.png"))

    print("Wrote app_icon.png and app_icon_foreground.png ->", os.path.normpath(OUT_DIR))


if __name__ == "__main__":
    build()
