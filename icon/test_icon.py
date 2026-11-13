import math
import unittest

import render
from colour import contrast, derive


class Colour(unittest.TestCase):
    def test_palette_round_trips_through_oklch(self):
        for hex_colour in render._PALETTE["palette"].values():
            self.assertEqual(derive(hex_colour), hex_colour)


class Icon(unittest.TestCase):
    def test_current_profile_stands_out_most_in_every_appearance(self):
        # The front disc is the current profile; once, the back one had twice its contrast.
        for mode in render.MODES:
            ground = render.role_colour("ground", mode)
            front = contrast(render.role_colour("front", mode), ground)
            back = contrast(render.role_colour("back", mode), ground)
            self.assertGreater(front, back * 1.5, mode)
            self.assertGreaterEqual(back, 3 if mode == "dark" else 2.5, mode)

    def test_discs_are_one_radius_apart(self):
        self.assertAlmostEqual(math.dist(render.FRONT, render.BACK), render.R, delta=0.25)

    def test_visual_weight_sits_on_the_optical_centre(self):
        # Centring the bounding box left the light front disc pulling the icon low-left.
        centre = render.visual_centre(render.FRONT, render.BACK, render.GAP, render.R)
        self.assertLess(math.dist(centre, render.OPTICAL_CENTRE), 1)

    def test_balancing_keeps_the_margin(self):
        # Balancing alone pushed the back disc to within 75 units of the edge.
        reach = render.reach(render.FRONT, render.BACK, render.R)
        self.assertLessEqual(reach, render.CENTRE - render.MARGIN + 0.5)

    def test_glyph_is_sized_in_whole_points(self):
        svg = render.glyph()
        w, h = render.GLYPH_PT
        self.assertIn(f'width="{w}" height="{h}"', svg)


if __name__ == "__main__":
    unittest.main()
