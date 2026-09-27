# frozen_string_literal: true

RSpec.describe Stationery::Fonts::Ligatures do
  subject(:font) { Stationery::Fonts::Font.new(Stationery::Fonts::Registry.load(font_path("OpenSans-Regular.ttf"))) }

  def load(name) = Stationery::Fonts::TrueType.new(File.binread(font_path(name)))
  def gid(char) = font.ttf.glyph_id(char.ord)
  def ligature(text) = font.ttf.ligatures.substitute(text.chars.map { |c| gid(c) }).first.first
  def hex(*gids) = gids.map { |g| format("%04X", g) }.join

  it "comes from GSUB when the font has liga ligatures, and is cached on the parsed font" do
    ttf = load("OpenSans-Regular.ttf")

    expect(described_class.for(ttf)).to be_a(Stationery::Fonts::Gsub)
    expect(ttf.ligatures).to equal(ttf.ligatures)
  end

  it "substitutes nothing for a font without ligatures" do
    ttf = load("Inter-Regular.ttf")

    expect(described_class.for(ttf)).to equal(described_class::NONE)
    expect(described_class::NONE.substitute([4, 5])).to eq([[4, 1], [5, 1]])
  end

  describe "in glyph runs" do
    it "draws fi as one glyph that carries both characters" do
      run = font.glyph_run("fi")

      expect(run.gids).to eq([ligature("fi")])
      expect(run.chars).to eq(["fi"])
      expect(run.gids.size).to eq(1)
      expect(font.glyph_run("fi", ligatures: false).gids.size).to eq(2)
    end

    it "keeps glyph runs without ligatures glyph for character" do
      run = font.glyph_run("AVATAR", kerning: true)

      expect(run.gids).to eq("AVATAR".chars.map { |c| gid(c) })
      expect(run.chars).to eq("AVATAR".chars)
    end

    it "kerns between the substituted glyphs" do
      run = font.glyph_run("office", kerning: true)

      expect(run.gids.size).to eq(4)
      expect(run.adjust.size).to eq(4)
      expect(run.width(10)).to be_within(1e-9).of(font.width_of("office", 10, kerning: true))
    end

    it "maps a ligature glyph back to every character it stands for" do
      font.glyph_run("office")

      expect(font.used_codes[ligature("ffi")]).to eq("ffi")
      expect(Stationery::Fonts::ToUnicode.cmap(font.used_codes)).to include("<#{hex(ligature("ffi"))}> <006600660069>")
    end
  end

  describe "in measuring" do
    it "measures a ligature by its own advance" do
      upem = font.ttf.units_per_em.to_f
      separate = "ffi".chars.sum { |c| font.ttf.advance(gid(c)) } * 10 / upem

      expect(font.width_of("fi", 10)).to eq(font.ttf.advance(ligature("fi")) * 10 / upem)
      expect(font.width_of("ffi", 10)).to eq(font.ttf.advance(ligature("ffi")) * 10 / upem)
      expect(font.width_of("ffi", 10, ligatures: false)).to be_within(1e-9).of(separate)
      expect(font.width_of("ffi", 10)).not_to be_within(1e-6).of(separate)
    end

    it "adds letter spacing per glyph and drops ligatures when letter spacing is set" do
      spaced = font.width_of("fi", 10, letter_spacing: 1)

      expect(spaced).to be_within(1e-9).of(font.width_of("fi", 10, ligatures: false) + 2)
      expect(font.width_of("fi", 10, letter_spacing: 1, ligatures: false)).to eq(spaced)
    end
  end

  describe "in documents" do
    def document(**)
      SpecDocument.build { text("office fit", **) }.to_pdf
    end

    it "forms ligatures by default and still extracts the source text" do
      pdf = document(kerning: false)

      expect(page_contents(pdf).first).to include("<#{hex(gid("o"), ligature("ffi"), gid("c"), gid("e"))}")
      expect(text_of(pdf)).to eq("office fit")
    end

    it "draws a single glyph for fi" do
      pdf = SpecDocument.build { text "fi", kerning: false }.to_pdf

      expect(page_contents(pdf).first).to include("<#{hex(ligature("fi"))}> Tj")
    end

    it "draws every character when the element or the document turns ligatures off" do
      plain = "<#{hex(*"office".chars.map { |c| gid(c) })}"
      unligated = Class.new(SpecDocument) do
        default_text ligatures: false, kerning: false
        def view_template = text("office fit")
      end.new.to_pdf

      expect(page_contents(document(kerning: false, ligatures: false)).first).to include(plain)
      expect(page_contents(unligated).first).to include(plain)
      expect(text_of(unligated)).to eq("office fit")
    end

    it "draws every character with letter spacing" do
      pdf = document(kerning: false, letter_spacing: 1)

      expect(page_contents(pdf).first).to include("<#{hex(*"office".chars.map { |c| gid(c) })}", "1 Tc")
      expect(text_of(pdf)).to eq("office fit")
    end
  end
end
