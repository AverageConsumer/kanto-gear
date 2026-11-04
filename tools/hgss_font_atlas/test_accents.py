"""Pixel-level checks for the generated font assets; run from the repository root."""

from pathlib import Path
import tempfile
import unicodedata
import unittest

from PIL import Image

import generate as atlas


def components(points):
    points = set(points)
    count = 0
    while points:
        count += 1
        todo = [points.pop()]
        while todo:
            x, y = todo.pop()
            neighbors = {(x + dx, y + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1)} & points
            points.difference_update(neighbors)
            todo.extend(neighbors)
    return count


class Accents(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.value = (atlas.MOD / "ui/fonts/glyphs.lua").read_text(encoding="utf-8").split("return [=[", 1)[1].split("]=]", 1)[0]
        cls.temp = tempfile.TemporaryDirectory(dir=atlas.ROOT / "diagnostics")
        cls.raw, cls.actual = {}, {}
        for name, source, size in (("hgss_font.png", "hgss_pixel.ttf", 10),
                                   ("hgss_small_font.png", "hgss_small.ttf", 11),
                                   ("hgss_large_font.png", "hgss_pixel.ttf", 20)):
            path = Path(cls.temp.name) / name
            atlas.render(atlas.SOURCES / source, size, cls.value, path)
            if "small" in name:
                atlas.override(path, cls.value, atlas.SMALL_OVERRIDES, 2)
            cls.raw[name] = Image.open(path).convert("RGBA")
            cls.actual[name] = Image.open(atlas.MOD / "ui/fonts" / name).convert("RGBA")

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def glyph(self, image, char):
        left, right = atlas.cells(image, self.value)[char]
        return image.crop((left, 0, right, image.height))

    def test_advances_baselines_and_unrelated_glyphs(self):
        for name, actual in self.actual.items():
            raw = self.raw[name]
            self.assertEqual(actual.size, raw.size)
            self.assertEqual(atlas.cells(actual, self.value), atlas.cells(raw, self.value))
            for char in self.value:
                with self.subTest(face=name, char=char):
                    before, after = self.glyph(raw, char), self.glyph(actual, char)
                    if char not in atlas.ACCENTED:
                        self.assertEqual(after.tobytes(), before.tobytes())
                    else:
                        self.assertEqual(after.getbbox()[3], before.getbbox()[3])
                        # Keep the last column clear as spacing before the next glyph.
                        self.assertFalse(after.crop((after.width - 1, 0, after.width, after.height)).getbbox())

    def test_marks_are_connected_and_have_a_clear_row(self):
        for name in ("hgss_font.png", "hgss_small_font.png"):
            image = self.actual[name]
            for char in atlas.ACCENTED:
                with self.subTest(face=name, char=char):
                    glyph = self.glyph(image, char)
                    occupied = [y for y in range(glyph.height) if glyph.crop((0, y, glyph.width, y + 1)).getbbox()]
                    split = next(i for i in range(1, len(occupied)) if occupied[i] > occupied[i - 1] + 1)
                    mark_rows = occupied[:split]
                    body_top = occupied[split]
                    self.assertEqual(body_top - mark_rows[-1], 2)
                    points = {(x, y) for y in mark_rows for x in range(glyph.width) if glyph.getpixel((x, y))[3]}
                    diaeresis = unicodedata.normalize("NFD", char)[1] == "\u0308"
                    self.assertEqual(components(points), 2 if diaeresis else 1)
                    self.assertEqual(len(mark_rows), 1 if diaeresis else 2)

    def test_distinct_accents_and_exact_large_pixel_grid(self):
        for name in ("hgss_font.png", "hgss_small_font.png"):
            image = self.actual[name]
            for group in ("áàâãä", "ÁÀÂÃÄ", "éèêë", "ÉÈÊË", "óòôõö", "ÓÒÔÕÖ"):
                self.assertEqual(len({self.glyph(image, c).tobytes() for c in group}), len(group))
        for char in atlas.ACCENTED:
            regular = self.glyph(self.actual["hgss_font.png"], char)
            large = self.glyph(self.actual["hgss_large_font.png"], char)
            self.assertEqual(large.tobytes(), regular.resize(large.size, Image.Resampling.NEAREST).tobytes())

    def test_regeneration_is_identical(self):
        for name in ("hgss_font.png", "hgss_small_font.png"):
            path = Path(self.temp.name) / name
            atlas.repair_accents(path, self.value)
            self.assertEqual(path.read_bytes(), (atlas.MOD / "ui/fonts" / name).read_bytes())
        large = Path(self.temp.name) / "hgss_large_font.png"
        atlas.scale_accents(Path(self.temp.name) / "hgss_font.png", large, self.value)
        self.assertEqual(large.read_bytes(), (atlas.MOD / "ui/fonts" / large.name).read_bytes())


if __name__ == "__main__":
    unittest.main()
