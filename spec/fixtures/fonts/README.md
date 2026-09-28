# Test fonts

- `OpenSans-*.ttf` — Open Sans by Steve Matteson, Apache License 2.0.
- `Inter-Regular.ttf` — Inter by Rasmus Andersson, SIL Open Font License 1.1 (an older build than the one shipped in `lib/stationery/fonts/data`; kept as a format 12 cmap fixture).
- `OpenSans-Collection.ttc` — Open Sans Regular (face 0) and Bold (face 1)
  subset to printable ASCII and packed into one TrueType collection.
- `OpenSans-Regular.woff` — the same ASCII subset of Open Sans Regular as face 0
  of the collection, wrapped as WOFF 1.0 (some tables zlib-compressed, some stored).
- `not-a-ttf.woff2` — a WOFF2 file, used to prove unsupported formats are rejected.
- `SourceSans3-Latin.otf` — Source Sans 3 by Adobe, SIL Open Font License 1.1.
  A name-keyed CFF font with a GPOS `kern` feature, subset to Basic Latin and
  Latin-1 letters (160 glyphs).
- `NotoSansJP-Subset.otf` — Noto Sans JP by Google/Adobe, SIL Open Font License
  1.1. A CID-keyed CFF font (ROS Adobe-Identity-0) subset to "日本語テキスト",
  so its glyph ids differ from its CIDs.

Used only by the test suite; not shipped in the gem.

## How the .otf fixtures were made

With fontTools 4.66.0 (`python3 -m venv venv && venv/bin/pip install fonttools`):

```sh
# Source Sans 3 3.052R, https://github.com/adobe-fonts/source-sans/releases/tag/3.052R
curl -LO https://github.com/adobe-fonts/source-sans/releases/download/3.052R/OTF-source-sans-3.052R.zip
unzip -j OTF-source-sans-3.052R.zip OTF/SourceSans3-Regular.otf
pyftsubset SourceSans3-Regular.otf --unicodes="U+0020-007E,U+00C0-00FF" \
  --layout-features=kern --output-file=SourceSans3-Latin.otf

# Noto Sans CJK Sans2.004, https://github.com/notofonts/noto-cjk/releases/tag/Sans2.004
curl -LO https://github.com/notofonts/noto-cjk/releases/download/Sans2.004/16_NotoSansJP.zip
unzip -j 16_NotoSansJP.zip NotoSansJP-Regular.otf
pyftsubset NotoSansJP-Regular.otf --text="日本語テキスト" --output-file=NotoSansJP-Subset.otf
```

Source SHA-256s: `SourceSans3-Regular.otf`
`08df266400933d3178d081a45f94a08814c3e55b4b7dd2e0ff69cb1329f13ab6`,
`NotoSansJP-Regular.otf`
`dff723ba59d57d136764a04b9b2d03205544f7cd785a711442d6d2d085ac5073`.

The glyph-id-to-CID values in `cff_spec.rb` come from
`TTFont("NotoSansJP-Subset.otf")["CFF "].cff.topDictIndex[0].charset`
(glyph names `cid01566`, … are the CIDs).

## How outlines.json was made

fontTools' outlines of a few glyphs of the fonts here, which
`glyph_outlines_spec.rb` compares with `TrueType#outline`. Each glyph is drawn
through a `fontTools.pens.basePen.BasePen` subclass that records `_moveTo`,
`_lineTo`, `_curveToOne` and `_closePath` as `["move", x, y]`, `["line", x, y]`,
`["curve", x1, y1, x2, y2, x, y]` and `["close"]`: BasePen decomposes
components and raises each quadratic to a cubic. The glyphs, keyed by file
(`#N` for a face of the collection) and character:

```python
GLYPHS = {"OpenSans-Regular.ttf": "oÁ%", "OpenSans-Regular.woff": "a", "OpenSans-Collection.ttc#1": "a",
          "SourceSans3-Latin.otf": "g@", "NotoSansJP-Subset.otf": "語"}
font = TTFont(path, fontNumber=face)
glyph_set = font.getGlyphSet()
glyph_set[font.getBestCmap()[ord(char)]].draw(pen)
```

## How the .ttc and .woff fixtures were made

With the same fontTools, from the `OpenSans-*.ttf` files here:

```sh
for f in Regular Bold; do
  pyftsubset OpenSans-$f.ttf --unicodes="U+0020-007E" --output-file=OpenSans-$f-ASCII.ttf
done
python3 -c 'from fontTools.ttLib import TTCollection, TTFont
c = TTCollection()
c.fonts = [TTFont("OpenSans-Regular-ASCII.ttf"), TTFont("OpenSans-Bold-ASCII.ttf")]
c.save("OpenSans-Collection.ttc")'
python3 -c 'from fontTools.ttLib import TTFont
f = TTFont("OpenSans-Regular-ASCII.ttf")
f.flavor = "woff"
f.save("OpenSans-Regular.woff")'
```
