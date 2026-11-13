"""sRGB hex to and from OKLCH, so icon colours can be derived from the palette by lightness
and chroma while keeping its hues. OKLCH rather than HSL because its lightness is perceptual:
two tones at the same L look equally light whatever their hue."""

import math


def _linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _gamma(c):
    c = min(max(c, 0.0), 1.0)
    return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


def to_oklch(hex_colour):
    r, g, b = (_linear(int(hex_colour[i:i + 2], 16) / 255) for i in (1, 3, 5))
    l, m, s = (math.cbrt(x) for x in (
        0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b,
        0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b,
        0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b))
    lightness = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
    a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
    b_ = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
    return lightness, math.hypot(a, b_), math.atan2(b_, a)


def from_oklch(lightness, chroma, hue):
    a, b = chroma * math.cos(hue), chroma * math.sin(hue)
    l, m, s = (x ** 3 for x in (
        lightness + 0.3963377774 * a + 0.2158037573 * b,
        lightness - 0.1055613458 * a - 0.0638541728 * b,
        lightness - 0.0894841775 * a - 1.2914855480 * b))
    rgb = (4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
           -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
           -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)
    return "#" + "".join(f"{round(_gamma(c) * 255):02X}" for c in rgb)


def derive(hex_colour, lightness=None, chroma=None):
    """The colour with its hue kept and its lightness or chroma replaced."""
    l, c, h = to_oklch(hex_colour)
    return from_oklch(l if lightness is None else lightness, c if chroma is None else chroma, h)


def luminance(hex_colour):
    r, g, b = (_linear(int(hex_colour[i:i + 2], 16) / 255) for i in (1, 3, 5))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    """WCAG contrast ratio, 1 to 21."""
    dark, light = sorted((luminance(a), luminance(b)))
    return (light + 0.05) / (dark + 0.05)
