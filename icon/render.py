#!/usr/bin/env python3
"""Writes Foci's icons from one drawing: two discs, the current profile in front.

AppIcon.icon is the app icon, an Icon Composer document. Glyphs.xcassets holds the menu
bar glyph, a template image shown before any profile is current.

Usage: render.py [out-dir], defaulting to icon/. Never edit the outputs in Icon Composer
or Xcode; the next run overwrites them.
"""

import json
import math
import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
MODES = ["light", "dark"]
PALETTE = json.loads((HERE / "palette.json").read_text())

# A 1000-unit square: keep every coordinate exact in binary (multiples of 0.125) so the
# output is identical on every run.
R = 260
FRONT = (390, 560)
BACK = (610, 440)
GAP = 40
# Wider in the menu bar, where the template's single colour leaves the gap to separate the
# discs: 64 units is 1.6 pt at 16 pt tall.
GLYPH_GAP = 64
# The discs' bounding box, so the glyph has no margin of its own.
GLYPH_BOX = (130, 180, 740, 640)
GLYPH_HEIGHT = 16


def snap(v):
    return round(v * 8) / 8


def circle(cx, cy, r):
    return (f"M{cx - r} {cy} A{r} {r} 0 1 0 {cx + r} {cy}"
            f" A{r} {r} 0 1 0 {cx - r} {cy} Z")


def crescent(disc, cutter, r, cut_r):
    """The disc minus the cutter. Cut out rather than drawn under, so the gap between the
    discs stays crisp under Liquid Glass and shows the ground in every appearance."""
    (ax, ay), (bx, by) = disc, cutter
    d = math.dist(disc, cutter)
    along = (d * d + r * r - cut_r * cut_r) / (2 * d)
    half = math.sqrt(r * r - along * along)
    ux, uy = (bx - ax) / d, (by - ay) / d
    mx, my = ax + along * ux, ay + along * uy
    p1 = (snap(mx - half * uy), snap(my + half * ux))
    p2 = (snap(mx + half * uy), snap(my - half * ux))
    return (f"M{p1[0]} {p1[1]} A{r} {r} 0 1 1 {p2[0]} {p2[1]}"
            f" A{cut_r} {cut_r} 0 0 0 {p1[0]} {p1[1]} Z")


def svg(fill, path):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1000 1000">'
            f'<path fill="{fill}" d="{path}"/></svg>\n')


def front(mode):
    return svg(PALETTE["front"][mode], circle(*FRONT, R))


def back(mode):
    return svg(PALETTE["back"][mode], crescent(BACK, FRONT, R, R + GAP))


def glyph():
    x, y, w, h = GLYPH_BOX
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w * GLYPH_HEIGHT / h}"'
            f' height="{GLYPH_HEIGHT}" viewBox="{x} {y} {w} {h}">'
            f'<path fill="#000" d="{circle(*FRONT, R)}"/>'
            f'<path fill="#000" fill-opacity="0.5" d="{crescent(BACK, FRONT, R, R + GLYPH_GAP)}"/>'
            '</svg>\n')


def solid(hex_colour):
    r, g, b = (int(hex_colour[i:i + 2], 16) / 255 for i in (1, 3, 5))
    return {"solid": f"srgb:{r:.5f},{g:.5f},{b:.5f},1.00000"}


# Icon Composer's own form: the unspecialised entry is the light value.
def by_appearance(value):
    return [{"value": value("light")}, {"appearance": "dark", "value": value("dark")}]


def group(layers):
    return {
        "layers": [{"name": name, "image-name-specializations": by_appearance(lambda m, n=name: f"{n}-{m}.svg"),
                    "glass": True} for name in layers],
        "shadow": {"kind": "neutral", "opacity": 0.5},
        "specular": True,
        "translucency": {"enabled": False, "value": 0.5},
    }


DRAWINGS = {"front": front, "back": back}
ICON = {
    "fill-specializations": by_appearance(lambda mode: solid(PALETTE["ground"][mode])),
    "groups": [group(["front"]), group(["back"])],
    "supported-platforms": {"squares": ["macOS"]},
}


CATALOG_INFO = {"info": {"author": "xcode", "version": 1}}
GLYPH_SET = {
    "images": [{"filename": "MenuBarIcon.svg", "idiom": "universal"}],
    **CATALOG_INFO,
    "properties": {"preserves-vector-representation": True, "template-rendering-intent": "template"},
}


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n")


def write_app_icon(out):
    shutil.rmtree(out, ignore_errors=True)
    (out / "Assets").mkdir(parents=True)
    for name, draw in DRAWINGS.items():
        for mode in MODES:
            (out / "Assets" / f"{name}-{mode}.svg").write_text(draw(mode))
    write_json(out / "icon.json", ICON)


def write_glyphs(out):
    shutil.rmtree(out, ignore_errors=True)
    glyph_set = out / "MenuBarIcon.imageset"
    glyph_set.mkdir(parents=True)
    write_json(out / "Contents.json", CATALOG_INFO)
    write_json(glyph_set / "Contents.json", GLYPH_SET)
    (glyph_set / "MenuBarIcon.svg").write_text(glyph())


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else HERE
    write_app_icon(out / "AppIcon.icon")
    write_glyphs(out / "Glyphs.xcassets")


if __name__ == "__main__":
    main()
