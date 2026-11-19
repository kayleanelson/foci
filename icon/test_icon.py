import itertools
import math
import unittest

import render
from color import VISIONS, contrast, derive, distance, simulate


class Color(unittest.TestCase):
    def test_brand_colors_round_trip_through_oklch(self):
        for values in render.TOKENS.values():
            for hex_color in values.values():
                if len(hex_color) == 7:  # translucent tokens carry alpha; the icon uses none
                    self.assertEqual(derive(hex_color), hex_color)

    def test_icon_colors_stay_apart_in_every_color_vision(self):
        # The discs and the ground must separate for everyone, not only by hue.
        for mode in render.MODES:
            colors = {role: render.role_color(role, mode) for role in render.ROLES}
            for (a, ca), (b, cb) in itertools.combinations(colors.items(), 2):
                for vision in VISIONS:
                    gap = distance(simulate(ca, vision), simulate(cb, vision))
                    self.assertGreaterEqual(gap, 10, f"{a}/{b} {mode} {vision}")


class Icon(unittest.TestCase):
    def test_current_profile_stands_out_most_in_every_appearance(self):
        # The front disc is the current profile; once, the back one had twice its contrast.
        for mode in render.MODES:
            ground = render.role_color("ground", mode)
            front = contrast(render.role_color("front", mode), ground)
            back = contrast(render.role_color("back", mode), ground)
            self.assertGreater(front, back * 1.5, mode)
            self.assertGreaterEqual(back, 3 if mode == "dark" else 2.5, mode)

    def test_discs_are_one_radius_apart(self):
        self.assertAlmostEqual(math.dist(render.FRONT, render.BACK), render.R, delta=0.25)

    def test_outline_is_centered_on_the_optical_center(self):
        # Weighting the discs by contrast once left margins of 208 and 100 either side.
        left, top, right, bottom = render.outline(render.FRONT, render.BACK, render.R)
        self.assertAlmostEqual((left + right) / 2, render.OPTICAL_CENTER[0], delta=0.25)
        self.assertAlmostEqual((top + bottom) / 2, render.OPTICAL_CENTER[1], delta=0.25)

    def test_outline_keeps_the_margin(self):
        left, top, right, bottom = render.outline(render.FRONT, render.BACK, render.R)
        size = 2 * render.CENTER
        self.assertGreaterEqual(min(left, top, size - right, size - bottom), render.MARGIN - 0.25)

    def test_glyph_is_sized_in_whole_points(self):
        svg = render.glyph()
        w, h = render.GLYPH_PT
        self.assertIn(f'width="{w}" height="{h}"', svg)


if __name__ == "__main__":
    unittest.main()
