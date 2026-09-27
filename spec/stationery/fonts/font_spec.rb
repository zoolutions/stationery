# frozen_string_literal: true

RSpec.describe Stationery::Fonts::Font do
  subject(:font) { described_class.new(Stationery::Fonts::Registry.load(font_path("OpenSans-Regular.ttf"))) }

  let(:writer) { Stationery::PDF::Writer.new }

  def object(ref) = writer.instance_variable_get(:@objects)[ref.id - 1]

  it "measures text in points, with letter spacing per character" do
    plain = font.width_of("Invoice", 10)

    expect(plain).to be_within(3).of(33)
    expect(font.width_of("Invoice", 20)).to be_within(0.001).of(plain * 2)
    expect(font.width_of("Invoice", 10, letter_spacing: 1)).to be_within(0.001).of(plain + 7)
  end

  it "narrows kerned pairs when measuring with kerning" do
    kerned = font.width_of("AVA", 10, kerning: true)

    expect(kerned).to be < font.width_of("AVA", 10)
    expect(kerned).to be_within(1e-9).of(font.glyph_run("AVA", kerning: true).width(10))
    expect(font.width_of("AVA", 20, kerning: true)).to be_within(1e-9).of(kerned * 2)
    expect(font.width_of("ABC", 10, kerning: true)).to eq(font.width_of("ABC", 10))
  end

  it "adds pair adjustments in thousandths of an em to kerned glyph runs" do
    run = font.glyph_run("AVA", kerning: true)
    upem = font.ttf.units_per_em
    a, v = %w[A V].map { |c| font.ttf.glyph_id(c.ord) }

    expect(run.adjust.first).to be < 0
    expect(run.adjust.first).to be_within(1e-9).of(font.ttf.kerning.adjust(a, v) * 1000.0 / upem)
    expect(run.adjust.last).to eq(0)
    expect(font.glyph_run("AV").adjust).to eq([0, 0])
    expect(font.glyph_run("", kerning: true).adjust).to eq([])
  end

  describe "whitespace the font lacks" do
    let(:source_sans) { described_class.new(Stationery::Fonts::Registry.load(font_path("SourceSans3-Latin.otf"))) }

    def gid(font, char) = font.ttf.glyph_id(char.ord)

    it "draws an ideographic space as the space glyph advanced to one em" do
      run = font.glyph_run("a\u3000b")
      upem = font.ttf.units_per_em

      expect(font.glyph?("\u3000")).to be(false)
      expect(run.gids).to eq([gid(font, "a"), gid(font, " "), gid(font, "b")])
      expect(run.chars).to eq(["a", "\u3000", "b"])
      expect(run.adjust[1]).to be_within(1e-9).of((upem - font.ttf.advance(gid(font, " "))) * 1000.0 / upem)
      expect(run.width(10)).to be_within(1e-9).of(font.width_of("a\u3000b", 10))
      expect(font.width_of("a\u3000b", 10)).to be_within(1e-9).of(font.width_of("ab", 10) + 10)
    end

    it "gives a figure space the digit width, a thin space a fifth of an em and the rest the space width" do
      space = source_sans.width_of(" ", 10)

      expect(source_sans.width_of("\u2007", 10)).to be_within(1e-9).of(source_sans.width_of("0", 10))
      expect(source_sans.width_of("\u2008", 10)).to be_within(1e-9).of(source_sans.width_of(".", 10))
      expect(source_sans.width_of("\u2009", 10)).to be_within(1e-9).of(2)
      expect(source_sans.width_of("\u200A", 10)).to be_within(1e-9).of(1.25)
      expect(source_sans.width_of("\u2003", 10)).to be_within(1e-9).of(10)
      expect([source_sans.width_of("\u00A0", 10), source_sans.width_of("\u202F", 10)]).to all(eq(space))
    end

    it "writes a plain Tj string when the substitute is as wide as a space" do
      expect(source_sans.glyph_run("a\u00A0b").to_operator).to eq(source_sans.glyph_run("a b").to_operator)
    end

    it "maps the space glyph back to a space in ToUnicode whichever character drew it first" do
      font.encode("\u3000 ")

      expect(font.used_codes[gid(font, " ")]).to eq(" ")
    end

    it "leaves whitespace the font has and glyphs it lacks alone" do
      expect(font.glyph_run("a\u00A0b").gids[1]).to eq(gid(font, "\u00A0"))
      expect(font.glyph_run("a\u00A0b").adjust).to eq([0, 0, 0])
      expect(font.glyph_run("☃").gids).to eq([0])
    end
  end

  it "exposes vertical metrics scaled to a size" do
    expect(font.ascender(10)).to be_between(9, 12)
    expect(font.descender(10)).to be_between(2, 4)
    expect(font.line_height(10)).to be > 10
  end

  it "encodes text as two-byte glyph ids and remembers which characters were used" do
    encoded = font.encode("Hi")

    expect(encoded.bytesize).to eq(4)
    expect(encoded.unpack("n*")).to eq("Hi".chars.map { |c| font.ttf.glyph_id(c.ord) })
  end

  it "builds a Type0 font over a CIDFontType2 with Identity-H, a subset and ToUnicode" do
    font.encode("Hi €")
    type0 = object(font.build(writer))
    cid = object(type0[:DescendantFonts].first)
    descriptor = object(cid[:FontDescriptor])

    expect(type0).to include(Subtype: :Type0, Encoding: :"Identity-H")
    expect(type0[:BaseFont].to_s).to match(/\A[A-Z]{6}\+OpenSans-Regular\z/)
    expect(cid).to include(Subtype: :CIDFontType2)
    expect(descriptor[:FontFile2]).to be_a(Stationery::PDF::Reference)
    expect(object(type0[:ToUnicode])).to be_a(Stationery::PDF::Stream)
  end

  it "maps glyphs back to Unicode in chunks of at most 100" do
    alphabet = [*"A".."Z", *"a".."z", *"0".."9"].join
    font.encode("#{alphabet}ÅÄÖåäöÜüéèàç.,;:!?-()[]{}'\"/\\@#$%&*+=<>|~^_`")
    cmap = Stationery::Fonts::ToUnicode.cmap(font.used_codes)

    expect(cmap.scan(/(\d+) beginbfchar/).flatten.map(&:to_i)).to all(be <= 100)
    expect(cmap).to include("<00E5>") # å
  end

  it "writes TrueType and name-keyed CFF glyphs by glyph id, CID-keyed CFF glyphs by CID" do
    jp = described_class.new(Stationery::Fonts::Registry.load(font_path("NotoSansJP-Subset.otf")))
    otf = described_class.new(Stationery::Fonts::Registry.load(font_path("SourceSans3-Latin.otf")))

    expect(font.code(42)).to eq(42)
    expect(otf.code(80)).to eq(80)
    expect(jp.code(jp.ttf.glyph_id("日".ord))).to eq(20_220)
    expect(jp.encode("日").unpack("n*")).to eq([20_220])
    expect(jp.used_codes).to eq(20_220 => "日")
  end
end
