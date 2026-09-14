#!/usr/bin/env python3
"""Fetches Noto Sans KR and cuts it down to the glyphs this game draws.

    pip install fonttools
    python3 tools/build_font.py
    godot --headless --path . --import
    godot --headless --path . --script res://tools/build_font.gd

Everything else in assets/ is generated rather than downloaded, because
nothing was fetchable when the art pipeline was written. A Hangul font is the
one thing that cannot reasonably be generated: 11,172 syllables, each of which
has to be legible at 11 pixels. Noto Sans KR is SIL OFL 1.1, so it can ship in
the repo -- but the full face is 2.4 MB per weight, and the game speaks about
four hundred characters. Subsetting takes it to 52 KB.

Re-run this after adding strings to assets/i18n/strings.csv; a syllable with
no glyph draws as an empty box.
"""
import csv
import pathlib
import subprocess
import sys
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
STRINGS = ROOT / "assets" / "i18n" / "strings.csv"
OUT_DIR = ROOT / "assets" / "fonts"

# Resolved from https://fonts.googleapis.com/css?family=Noto+Sans+KR&subset=korean
BASE = "https://fonts.gstatic.com/s/notosanskr/v39/"
# One weight. A bold was fetched and committed at first, and then nothing ever
# asked for it -- the UI draws every window in the one face. It is easier to
# add a weight back than to explain a file in the repository nobody reads.
WEIGHTS = {
    "Regular": BASE + "PbyxFmXiEBPT4ITbgNA5Cgms3VYcOA-vvnIzzuoySLng9A.ttf",
}

# Punctuation the string table may grow into. The menu cursor and the volume
# bars are deliberately absent: Noto Sans KR's Korean subset has no geometric
# shapes, so the UI draws those as polygons instead of asking for a glyph.
UI_GLYPHS = "·—…↑↓"


def wanted_characters() -> set:
    chars = set(UI_GLYPHS)
    with STRINGS.open(encoding="utf-8") as f:
        for row in csv.reader(f):
            for cell in row:
                chars.update(cell)
    # Printable ASCII in full, so numbers and the English text always render
    # even for a string that was added without re-running this.
    chars.update(chr(c) for c in range(0x20, 0x7F))
    return {c for c in chars if c not in "\r\n"}


def main() -> int:
    chars = wanted_characters()
    spec = ",".join("U+%04X" % ord(c) for c in sorted(chars))
    unicodes = OUT_DIR / "subset-unicodes.txt"
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    unicodes.write_text(spec, encoding="utf-8")
    print("[font] %d codepoints" % len(chars))

    for weight, url in WEIGHTS.items():
        source = OUT_DIR / ("NotoSansKR-%s-full.ttf" % weight)
        if not source.exists():
            print("[font] fetching %s" % url)
            urllib.request.urlretrieve(url, source)
        target = OUT_DIR / ("NotoSansKR-%s-subset.ttf" % weight)
        subprocess.run([
            sys.executable, "-m", "fontTools.subset", str(source),
            "--unicodes-file=%s" % unicodes,
            # No shaping tables: this text is set one glyph at a time.
            "--layout-features=",
            "--no-hinting",
            "--desubroutinize",
            "--output-file=%s" % target,
        ], check=True)
        source.unlink()
        print("[font] %s  %d KB" % (target.name, target.stat().st_size // 1024))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
