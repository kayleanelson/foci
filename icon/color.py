"""Color measurement for design QA: OKLCH, WCAG contrast, OKLab distance, color-vision
simulation, gamut limits.

OKLCH rather than HSL because its lightness is perceptual: two tones at the same L look
equally light whatever their hue. Hue is in degrees everywhere.

    python3 color.py <hex> <hex> ...

prints each color's OKLCH and saturation share, then every pair's contrast and
distance under normal and simulated color-vision deficiencies.
"""

import itertools
import math
from typing import NamedTuple


class Lch(NamedTuple):
    lightness: float
    chroma: float
    hue: float  # degrees


def _linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _gamma(c):
    return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


def hex_to_rgb(hex_color):
    h = hex_color.lstrip("#")
    if len(h) != 6:
        raise ValueError(f"not a 6-digit hex color: {hex_color!r}")
    return tuple(int(h[i : i + 2], 16) / 255 for i in (0, 2, 4))


def rgb_to_hex(rgb):
    return "#" + "".join(f"{round(min(1, max(0, c)) * 255):02X}" for c in rgb)


# Matrices from Björn Ottosson's OKLab post. A mistyped digit survives byte round-trips;
# test_color.py composes the two directions to catch one.
def _linear_to_oklab(r, g, b):
    long, medium, short = (
        math.cbrt(x)
        for x in (
            0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b,
            0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b,
            0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b,
        )
    )
    return (
        0.2104542553 * long + 0.7936177850 * medium - 0.0040720468 * short,
        1.9779984951 * long - 2.4285922050 * medium + 0.4505937099 * short,
        0.0259040371 * long + 0.7827717662 * medium - 0.8086757660 * short,
    )


def _oklab_to_linear(lightness, a, b):
    long, medium, short = (
        x**3
        for x in (
            lightness + 0.3963377774 * a + 0.2158037573 * b,
            lightness - 0.1055613458 * a - 0.0638541728 * b,
            lightness - 0.0894841775 * a - 1.2914855480 * b,
        )
    )
    return (
        4.0767416621 * long - 3.3077115913 * medium + 0.2309699292 * short,
        -1.2684380046 * long + 2.6097574011 * medium - 0.3413193965 * short,
        -0.0041960863 * long - 0.7034186147 * medium + 1.7076147010 * short,
    )


def oklab(hex_color):
    return _linear_to_oklab(*(_linear(c) for c in hex_to_rgb(hex_color)))


def to_oklch(hex_color):
    lightness, a, b = oklab(hex_color)
    return Lch(lightness, math.hypot(a, b), math.degrees(math.atan2(b, a)) % 360)


def _lch_to_linear(lightness, chroma, hue):
    h = math.radians(hue)
    return _oklab_to_linear(lightness, chroma * math.cos(h), chroma * math.sin(h))


def in_gamut(lightness, chroma, hue):
    return all(-1e-4 <= c <= 1 + 1e-4 for c in _lch_to_linear(lightness, chroma, hue))


def max_chroma(lightness, hue):
    """The most chroma sRGB can show at this lightness and hue. Compare saturation as
    chroma / max_chroma: raw chroma misleads across hues."""
    lo, hi = 0.0, 0.4
    for _ in range(40):
        mid = (lo + hi) / 2
        lo, hi = (mid, hi) if in_gamut(lightness, mid, hue) else (lo, mid)
    return lo


def from_oklch(lightness, chroma, hue):
    """The sRGB hex for an OKLCH color, reducing chroma (never hue) to fit the gamut.
    Clamping channels instead would shift the hue silently."""
    # Only search when out of gamut: near pure blue a channel dips below zero and
    # recovers as chroma grows, so the search's edge can sit below a valid color.
    if not in_gamut(lightness, chroma, hue):
        chroma = min(chroma, max_chroma(lightness, hue))
    return rgb_to_hex(_gamma(c) for c in _lch_to_linear(lightness, chroma, hue))


def derive(hex_color, lightness=None, chroma=None):
    """The color with its hue kept and its lightness or chroma replaced."""
    lch = to_oklch(hex_color)
    return from_oklch(
        lch.lightness if lightness is None else lightness,
        lch.chroma if chroma is None else chroma,
        lch.hue,
    )


def luminance(hex_color):
    r, g, b = (_linear(c) for c in hex_to_rgb(hex_color))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    """WCAG contrast ratio, 1 to 21."""
    hi, lo = sorted((luminance(a), luminance(b)), reverse=True)
    return (hi + 0.05) / (lo + 0.05)


def readable(hex_color, surfaces, minimum=4.5, direction="darker", step=0.005):
    """The color with only its lightness moved, in `step` increments, until it reaches
    `minimum` contrast on every surface. Unchanged if it already does."""
    lch = to_oklch(hex_color)
    delta = -step if direction == "darker" else step
    lightness, candidate = lch.lightness, hex_color
    while min(contrast(candidate, s) for s in surfaces) < minimum:
        lightness += delta
        if not 0 <= lightness <= 1:
            raise ValueError(f"{hex_color} cannot reach {minimum}:1 going {direction}")
        candidate = from_oklch(lightness, lch.chroma, lch.hue)
    return candidate


def distance(a, b):
    """OKLab distance x 100. Below about 10, two colors are easy to confuse."""
    return 100 * math.dist(oklab(a), oklab(b))


# Machado, Oliveira & Fernandes (2009), full severity, applied in linear sRGB.
# Every row sums to 1, which is what keeps greys grey; test_color.py checks it.
_VISION = {
    "deuteranopia": (
        (0.367322, 0.860646, -0.227968),
        (0.280085, 0.672501, 0.047413),
        (-0.011820, 0.042940, 0.968881),
    ),
    "protanopia": (
        (0.152286, 1.052583, -0.204868),
        (0.114503, 0.786281, 0.099216),
        (-0.003882, -0.048116, 1.051998),
    ),
    "tritanopia": (
        (1.255528, -0.076749, -0.178779),
        (-0.078411, 0.930809, 0.147602),
        (0.004733, 0.691367, 0.303900),
    ),
}
VISIONS = ("normal", *_VISION)


def simulate(hex_color, vision):
    if vision == "normal":
        return hex_color
    rgb = [_linear(c) for c in hex_to_rgb(hex_color)]
    out = (sum(w * c for w, c in zip(row, rgb, strict=True)) for row in _VISION[vision])
    return rgb_to_hex(_gamma(min(1, max(0, c))) for c in out)


def grayscale(hex_color):
    return from_oklch(to_oklch(hex_color).lightness, 0, 0)


def _report(colors):
    print(f"{'color':9} {'L':>6} {'C':>6} {'h':>5}  {'C/max':>5}")
    for c in colors:
        lch = to_oklch(c)
        share = lch.chroma / max(max_chroma(lch.lightness, lch.hue), 1e-9)
        print(f"{c:9} {lch.lightness:6.3f} {lch.chroma:6.3f} {lch.hue:5.0f}  {share:5.0%}")
    print(f"\n{'pair':17} {'WCAG':>6}  " + "  ".join(f"{v[:6]:>6}" for v in VISIONS))
    for a, b in itertools.combinations(colors, 2):
        gaps = [distance(simulate(a, v), simulate(b, v)) for v in VISIONS]
        flag = "  < 10" if min(gaps) < 10 else ""
        cells = "  ".join(f"{g:6.1f}" for g in gaps)
        print(f"{a} {b} {contrast(a, b):5.2f}:1  {cells}{flag}")


if __name__ == "__main__":
    import sys

    _report([c if c.startswith("#") else f"#{c}" for c in sys.argv[1:]])
