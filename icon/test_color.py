"""Vendored from the asset-qa skill with color.py; run by make icon-test."""

import itertools
import unittest

from color import (
    _VISION,
    VISIONS,
    _linear_to_oklab,
    _oklab_to_linear,
    contrast,
    derive,
    from_oklch,
    in_gamut,
    max_chroma,
    readable,
    simulate,
    to_oklch,
)

SAMPLES = ["#000000", "#FFFFFF", "#FF0000", "#00FF00", "#0000FF", "#7EAC55", "#FCF2E7"]


class ColorTest(unittest.TestCase):
    def test_round_trips_through_oklch(self):
        for hex_color in SAMPLES:
            self.assertEqual(from_oklch(*to_oklch(hex_color)), hex_color)

    def test_forward_and_inverse_matrices_agree(self):
        # The published matrices invert to 2.6e-7; a two-digit slip in one
        # coefficient gave 2.3e-6, invisible to byte round-trips.
        for rgb in itertools.product((0.0, 0.2, 0.5, 0.8, 1.0), repeat=3):
            back = _oklab_to_linear(*_linear_to_oklab(*rgb))
            for got, want in zip(back, rgb, strict=True):
                self.assertAlmostEqual(got, want, delta=1e-6)

    def test_matches_published_reference_values(self):
        # Ottosson: sRGB red is L 0.628, C 0.258, h 29.2 degrees.
        lightness, chroma, hue = to_oklch("#FF0000")
        self.assertAlmostEqual(lightness, 0.628, places=3)
        self.assertAlmostEqual(chroma, 0.258, places=3)
        self.assertAlmostEqual(hue, 29.2, places=1)

    def test_gamut_mapping_keeps_hue_and_lightness(self):
        for lightness, hue in itertools.product((0.3, 0.5, 0.7, 0.9), range(0, 360, 30)):
            mapped = to_oklch(from_oklch(lightness, 0.4, hue))
            self.assertAlmostEqual(mapped.lightness, lightness, delta=0.01)
            if mapped.chroma > 0.02:
                self.assertAlmostEqual((mapped.hue - hue + 180) % 360 - 180, 0, delta=2)

    def test_max_chroma_sits_on_the_gamut_edge(self):
        for lightness, hue in itertools.product((0.4, 0.6, 0.8), (30, 140, 260)):
            edge = max_chroma(lightness, hue)
            self.assertTrue(in_gamut(lightness, edge, hue))
            self.assertFalse(in_gamut(lightness, edge + 0.005, hue))

    def test_derive_keeps_hue(self):
        self.assertAlmostEqual(
            to_oklch(derive("#AB8254", lightness=0.75)).hue, to_oklch("#AB8254").hue, delta=1
        )

    def test_readable_moves_only_as_far_as_needed(self):
        self.assertEqual(readable("#4E5647", ["#FCF2E7"]), "#4E5647")
        result = readable("#7EAC55", ["#FCF2E7"])
        self.assertGreaterEqual(contrast(result, "#FCF2E7"), 4.5)
        lighter = derive(result, lightness=to_oklch(result).lightness + 0.006)
        self.assertLess(contrast(lighter, "#FCF2E7"), 4.5)

    def test_vision_matrices_keep_greys_grey(self):
        for vision, rows in _VISION.items():
            for row in rows:
                self.assertAlmostEqual(sum(row), 1, delta=1e-5, msg=vision)
        for vision in VISIONS:
            self.assertEqual(simulate("#808080", vision), "#808080")


if __name__ == "__main__":
    unittest.main()
