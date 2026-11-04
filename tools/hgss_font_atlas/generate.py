"""Build deterministic LÖVE image fonts for the 240x216 HGSS canvas."""

from pathlib import Path
import math
import unicodedata

from fontTools.ttLib import TTFont
from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
MOD = ROOT / "mod" / "kanto_gear"
SOURCES = Path(__file__).resolve().parent / "sources"


def glyphs() -> str:
    value = "".join(chr(code) for code in range(32, 127)) + "×→←▲▼"
    # Include external translation alphabets even when Gear's own catalogs do
    # not use them. Keep codepoint order stable across filesystems and locales.
    common = set(TTFont(SOURCES / "hgss_pixel.ttf").getBestCmap())
    common.intersection_update(TTFont(SOURCES / "hgss_small.ttf").getBestCmap())
    value += "".join(chr(code) for code in sorted(common) if chr(code).isprintable())
    for path in sorted(MOD.rglob("*.lua")):
        value += "".join(
            char for char in path.read_text(encoding="utf-8") if ord(char) >= 128
        )
    return "".join(dict.fromkeys(value))


def supported(source: Path, value: str) -> str:
    font = TTFont(source)
    cmap: set[int] = set()
    for table in font["cmap"].tables:
        cmap.update(table.cmap)
    return "".join(char for char in value if ord(char) in cmap)


def render(source: Path, size: int, value: str, output: Path) -> None:
    font = ImageFont.truetype(source, size, layout_engine=ImageFont.Layout.BASIC)
    widths = [max(1, round(font.getlength(char))) for char in value]
    ascent, descent = font.getmetrics()
    image = Image.new("RGBA", (sum(widths) + len(value) + 1, ascent + descent))
    draw = ImageDraw.Draw(image)
    x = 0
    for char, width in zip(value, widths, strict=True):
        draw.point((x, 0), fill=(255, 0, 255, 255))
        draw.text((x + 1, 0), char, font=font, fill=(255, 255, 255, 255))
        x += width + 1
    draw.point((x, 0), fill=(255, 0, 255, 255))
    image.save(output, optimize=True)


# The small source draws "¥" as a barred hash; redraw it as the yen sign the
# regular face uses, so money reads the same on every font.
SMALL_OVERRIDES = {"¥": ["#...#", ".#.#.", "#####", "..#..", "#####", "..#..", "..#.."]}

# The source outlines scatter these marks across alternate pixel rows. Repair
# only the Latin-1 accents used by Gear's languages; preserve every advance.
ACCENTED = "áàâãäéèêëíìîïóòôõöúùûüýÿñ"
ACCENTED += ACCENTED.upper()


def cells(image: Image.Image, value: str) -> dict[str, tuple[int, int]]:
    marks = [x for x in range(image.width) if image.getpixel((x, 0)) == (255, 0, 255, 255)]
    assert len(marks) == len(value) + 1, "atlas separators do not match the glyph map"
    return {char: (marks[i] + 1, marks[i + 1]) for i, char in enumerate(value)}


def repair_accents(output: Path, value: str) -> None:
    image = Image.open(output).convert("RGBA")
    spans = cells(image, value)
    original = image.copy()
    for char in ACCENTED:
        if char not in spans:
            continue
        base, accent = unicodedata.normalize("NFD", char)
        left, right = spans[char]
        base_left, base_right = spans[base]
        body = original.crop((left, 0, right, image.height))
        plain = original.crop((base_left, 0, base_right, image.height))
        top = plain.getbbox()[1]
        if base == "i":
            # The accent replaces the dot. Find the stem after the blank row.
            while plain.crop((0, top, plain.width, top + 1)).getbbox():
                top += 1
            while not plain.crop((0, top, plain.width, top + 1)).getbbox():
                top += 1
        ImageDraw.Draw(body).rectangle((0, 0, body.width - 1, top - 1), fill=(0, 0, 0, 0))
        bounds = body.getbbox()
        height = 1 if accent == "\u0308" else 2
        if bounds[1] < height + 1:
            # Small capitals have seven body rows and only two rows above them.
            # Remove a repeated stroke row, keeping the bottom/baseline fixed.
            rows = [body.crop((0, y, body.width, y + 1)) for y in range(bounds[1], bounds[3])]
            repeated = next((i for i in range(1, len(rows) - 1)
                             if rows[i].tobytes() == rows[i - 1].tobytes()), None)
            assert repeated is not None, f"no safe repeated body row in {char}"
            rows.pop(repeated)
            body.paste((0, 0, 0, 0), (0, 0, body.width, body.height))
            for i, row in enumerate(rows):
                body.paste(row, (0, bounds[3] - len(rows) + i))
            bounds = body.getbbox()
        ink_left, ink_top, ink_right, _ = bounds
        center = (ink_left + ink_right - 1) / 2
        if base == "i":
            stem = body.crop((0, (ink_top + bounds[3]) // 2, body.width,
                              (ink_top + bounds[3]) // 2 + 1)).getbbox()
            center = (stem[0] + stem[2] - 1) / 2
        if accent == "\u0301":
            shape, x = [".#", "#."], math.floor(center)
        elif accent == "\u0300":
            shape, x = ["#.", ".#"], math.ceil(center) - 1
        elif accent == "\u0302":
            shape = [".#.", "#.#"]
            x = math.floor(center - 1 + 0.5)
        elif accent == "\u0303":
            shape = [".##.#", "#.##."] if ink_right - ink_left >= 5 else [".#.#", "#.#."]
            x = math.floor(center - (len(shape[0]) - 1) / 2 + 0.5)
        else:
            assert accent == "\u0308"
            shape = ["#.#"] if ink_right - ink_left < 4 or (ink_right - ink_left) % 2 else ["#..#"]
            x = math.floor(center - (len(shape[0]) - 1) / 2 + 0.5)
        x = max(0, min(body.width - 1 - len(shape[0]), x))
        assert x >= 0 and x + len(shape[0]) < body.width, f"accent overruns {char}"
        y = ink_top - len(shape) - 1
        assert y >= 0, f"accent clips above {char}"
        for row, line in enumerate(shape):
            for column, pixel in enumerate(line):
                if pixel == "#":
                    body.putpixel((x + column, y + row), (255, 255, 255, 255))
        image.paste(body, (left, 0))
    image.save(output, optimize=True)


def scale_accents(source: Path, output: Path, value: str) -> None:
    normal = Image.open(source).convert("RGBA")
    large = Image.open(output).convert("RGBA")
    normal_spans, large_spans = cells(normal, value), cells(large, value)
    assert large.height == normal.height * 2
    for char in ACCENTED:
        if char not in normal_spans:
            continue
        left, right = normal_spans[char]
        large_left, large_right = large_spans[char]
        assert large_right - large_left == (right - left) * 2
        glyph = normal.crop((left, 0, right, normal.height))
        large.paste(glyph.resize((glyph.width * 2, glyph.height * 2), Image.Resampling.NEAREST), (large_left, 0))
    large.save(output, optimize=True)


def override(output: Path, value: str, shapes: dict[str, list[str]], top: int) -> None:
    image = Image.open(output).convert("RGBA")
    marks = [x for x in range(image.width) if image.getpixel((x, 0)) == (255, 0, 255, 255)]
    for char, rows in shapes.items():
        left, right = marks[value.index(char)] + 1, marks[value.index(char) + 1]
        for x in range(left, right):
            for y in range(image.height):
                image.putpixel((x, y), (0, 0, 0, 0))
        for row, line in enumerate(rows):
            for column, pixel in enumerate(line):
                if pixel == "#" and left + column < right:
                    image.putpixel((left + column, top + row), (255, 255, 255, 255))
    image.save(output, optimize=True)


def main() -> None:
    main_source = SOURCES / "hgss_pixel.ttf"
    small_source = SOURCES / "hgss_small.ttf"
    value = supported(main_source, supported(small_source, glyphs()))
    (MOD / "ui/fonts/glyphs.lua").write_text(
        "-- Generated by tools/hgss_font_atlas/generate.py.\n"
        f"return [=[{value}]=]\n",
        encoding="utf-8",
        newline="\n",
    )
    render(main_source, 10, value, MOD / "ui/fonts/hgss_font.png")
    repair_accents(MOD / "ui/fonts/hgss_font.png", value)
    render(small_source, 11, value, MOD / "ui/fonts/hgss_small_font.png")
    override(MOD / "ui/fonts/hgss_small_font.png", value, SMALL_OVERRIDES, 2)
    repair_accents(MOD / "ui/fonts/hgss_small_font.png", value)
    render(main_source, 20, value, MOD / "ui/fonts/hgss_large_font.png")
    scale_accents(MOD / "ui/fonts/hgss_font.png", MOD / "ui/fonts/hgss_large_font.png", value)


if __name__ == "__main__":
    main()
