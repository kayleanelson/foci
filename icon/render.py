#!/usr/bin/env python3
"""Writes Foci's app icon as an Icon Composer document: an ellipse with one lit focus.

Usage: render.py [out.icon], defaulting to icon/AppIcon.icon. Never edit the document
in Icon Composer; the next run overwrites it.
"""

import json
import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "AppIcon.icon"
MODES = ["light", "dark"]
PALETTE = json.loads((HERE / "palette.json").read_text())

# A 1000-unit square: keep every coordinate exact in binary (multiples of 0.125) so the
# output is identical on every run.
CX, CY = 500, 500
RX, RY, RING = 400, 290, 52
FOCUS = 215
LIT_R = 80
UNLIT_R, UNLIT_HOLE = 68, 36


def ellipse(cx, cy, rx, ry):
    return (f"M{cx - rx} {cy} A{rx} {ry} 0 1 0 {cx + rx} {cy}"
            f" A{rx} {ry} 0 1 0 {cx - rx} {cy} Z")


def circle(cx, cy, r):
    return ellipse(cx, cy, r, r)


def svg(fill, *paths):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1000 1000">'
            f'<path fill-rule="evenodd" fill="{fill}" d="{" ".join(paths)}"/></svg>\n')


def orbit(mode):
    return svg(PALETTE["orbit"][mode],
               ellipse(CX, CY, RX, RY), ellipse(CX, CY, RX - RING, RY - RING))


def lit(mode):
    return svg(PALETTE["lit"][mode], circle(CX - FOCUS, CY, LIT_R))


def unlit(mode):
    return svg(PALETTE["unlit"][mode],
               circle(CX + FOCUS, CY, UNLIT_R), circle(CX + FOCUS, CY, UNLIT_HOLE))


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


DRAWINGS = {"orbit": orbit, "lit": lit, "unlit": unlit}
ICON = {
    "fill-specializations": by_appearance(lambda mode: solid(PALETTE["ground"][mode])),
    "groups": [group(["lit", "unlit"]), group(["orbit"])],
    "supported-platforms": {"squares": ["macOS"]},
}


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else OUT
    shutil.rmtree(out, ignore_errors=True)
    (out / "Assets").mkdir(parents=True)
    for name, draw in DRAWINGS.items():
        for mode in MODES:
            (out / "Assets" / f"{name}-{mode}.svg").write_text(draw(mode))
    (out / "icon.json").write_text(json.dumps(ICON, indent=2) + "\n")


if __name__ == "__main__":
    main()
