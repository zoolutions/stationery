# frozen_string_literal: true

RSpec.describe Stationery::Fonts::Gsub do
  include GposBuilder

  def load(name) = Stationery::Fonts::TrueType.new(File.binread(font_path(name)))

  # f = 1, i = 2, l = 3; fi = 10, ffi = 11, fl = 12, ff = 13.
  let(:f_ligatures) { { 1 => { [2] => 10, [1] => 13, [1, 2] => 11, [3] => 12 } } }

  def parse(features:, lookups:) = described_class.parse(GsubBuilder.gsub(features:, lookups:))

  describe "with Open Sans" do
    let(:ttf) { load("OpenSans-Regular.ttf") }
    let(:gsub) { described_class.parse(ttf) }

    def glyphs(text) = text.chars.map { |c| ttf.glyph_id(c.ord) }

    it "reads the liga feature's ligatures" do
      fi = gsub.substitute(glyphs("fi")).first.first
      ffi = gsub.substitute(glyphs("ffi")).first.first

      expect(gsub.substitute(glyphs("fi"))).to eq([[fi, 2]])
      o, c, e = glyphs("oce")
      expect(gsub.substitute(glyphs("office"))).to eq([[o, 1], [ffi, 3], [c, 1], [e, 1]])
      expect([fi, ffi]).to all(be > ttf.glyph_id("z".ord))
    end

    it "leaves text without ligatures alone" do
      expect(gsub.substitute(glyphs("AVATAR"))).to eq(glyphs("AVATAR").map { |gid| [gid, 1] })
    end
  end

  it "substitutes nothing by default for a font without liga ligatures, but lists its features" do
    gsub = described_class.parse(load("Inter-Regular.ttf"))

    expect(gsub.features).to include("tnum", "zero", "dlig")
    expect(gsub.features).not_to include("liga")
    expect(gsub.substitute([4, 5])).to eq([[4, 1], [5, 1]])
  end

  it "is nil without GSUB, with an unknown major version or with only unsupported lookup types" do
    ttf = load("OpenSans-Regular.ttf")
    allow(ttf).to receive(:table_offset).with("GSUB").and_return(nil)
    liga = [["liga", [0]]]
    lookups = [lookup(4, [GsubBuilder.ligature_subst(coverage1([1]), f_ligatures)])]

    expect(described_class.parse(ttf)).to be_nil
    expect(described_class.parse(GsubBuilder.gsub(features: liga, lookups:, version: 2))).to be_nil
    expect(parse(features: liga, lookups: [lookup(5, [[1].pack("n")])])).to be_nil
  end

  it "keeps a feature other than liga without applying it by default" do
    lookups = [lookup(4, [GsubBuilder.ligature_subst(coverage1([1]), f_ligatures)])]
    gsub = parse(features: [["dlig", [0]]], lookups:)

    expect(gsub.features).to eq(["dlig"])
    expect(gsub.substitute([1, 2])).to eq([[1, 1], [2, 1]])
    expect(gsub.substitute([1, 2], ["dlig"])).to eq([[10, 2]])
  end

  describe "single substitutions" do
    # smcp: lookup 0 adds 100 to glyphs 1..3 (format 1); onum: lookup 1 (format
    # 2, behind an Extension) maps 4 => 40 and 5 => 50, then lookup 2 forms the
    # ligature 40 41 => 60; liga is lookup 3.
    let(:gsub) do
      smcp = GsubBuilder.single_subst1(coverage1([1, 2, 3]), 100)
      onum = GsubBuilder.single_subst2(coverage2([4..5]), [40, 50])
      pairs = GsubBuilder.ligature_subst(coverage1([40]), { 40 => { [41] => 60 } })
      liga = GsubBuilder.ligature_subst(coverage1([1]), f_ligatures)
      parse(features: [["smcp", [0]], ["onum", [1, 2]], ["liga", [3]]],
            lookups: [lookup(1, [smcp]), lookup(7, [extension(1, onum)]), lookup(4, [pairs]), lookup(4, [liga])])
    end

    it "lists the features it can apply" do
      expect(gsub.features).to eq(%w[smcp onum liga])
    end

    it "applies a format 1 delta and a format 2 list, each glyph standing for one character" do
      expect(gsub.substitute([1, 2, 3, 4], ["smcp"])).to eq([[101, 1], [102, 1], [103, 1], [4, 1]])
      expect(gsub.substitute([4, 5, 6], ["onum"])).to eq([[40, 1], [50, 1], [6, 1]])
    end

    it "runs a feature's lookups in LookupList order, so a later ligature sees the substitutes" do
      expect(gsub.substitute([4, 41], ["onum"])).to eq([[60, 2]])
    end

    it "merges the lookups of several features in LookupList order whatever the tag order" do
      expect(gsub.substitute([1, 2, 4], %w[smcp onum])).to eq(gsub.substitute([1, 2, 4], %w[onum smcp]))
      expect(gsub.substitute([1, 2, 4], %w[liga smcp])).to eq([[101, 1], [102, 1], [4, 1]])
      expect(gsub.substitute([1, 2, 4], ["liga"])).to eq([[10, 2], [4, 1]])
    end

    it "ignores features the font does not have" do
      expect(gsub.substitute([1, 2], ["zero"])).to eq([[1, 1], [2, 1]])
      expect(gsub.substitute([1, 2], [])).to eq([[1, 1], [2, 1]])
    end

    it "wraps a format 1 delta at 16 bits" do
      wrap = parse(features: [["ss01", [0]]], lookups: [lookup(1, [GsubBuilder.single_subst1(coverage1([65_535]), 2)])])

      expect(wrap.substitute([65_535], ["ss01"])).to eq([[1, 1]])
    end
  end

  describe "with every lookup shape" do
    let(:gsub) do
      ligatures = GsubBuilder.ligature_subst(coverage1([1]), f_ligatures)
      chained = GsubBuilder.ligature_subst(coverage2([13..13]), { 13 => { [3] => 20 } })
      dlig = GsubBuilder.ligature_subst(coverage1([2]), { 2 => { [2] => 30 } })
      parse(features: [["dlig", [2]], ["liga", [3, 0, 4]], ["liga", [1]]],
            lookups: [lookup(7, [extension(4, ligatures)]), lookup(4, [chained]), lookup(4, [dlig]),
                      lookup(7, [extension(1, [1].pack("n"))]), lookup(4, [[2].pack("n")])])
    end

    it "forms a ligature from two glyphs, through an Extension lookup" do
      expect(gsub.substitute([1, 2])).to eq([[10, 2]])
      expect(gsub.substitute([1, 3, 5])).to eq([[12, 2], [5, 1]])
    end

    it "prefers the longest ligature at a position" do
      expect(gsub.substitute([1, 1, 2])).to eq([[11, 3]])
      expect(gsub.substitute([1, 1, 1, 2])).to eq([[13, 2], [10, 2]])
    end

    it "does not match a substituted glyph again in the same lookup, but later lookups see it" do
      expect(gsub.substitute([1, 1, 3])).to eq([[20, 3]])
    end

    it "ignores lookups only other features name" do
      expect(gsub.substitute([2, 2])).to eq([[2, 1], [2, 1]])
    end

    it "keeps glyphs no ligature starts with, and empty runs" do
      expect(gsub.substitute([5, 1])).to eq([[5, 1], [1, 1]])
      expect(gsub.substitute([])).to eq([])
    end
  end

  it "lets the first subtable matching at a position win" do
    first = GsubBuilder.ligature_subst(coverage1([1]), { 1 => { [2] => 40 } })
    second = GsubBuilder.ligature_subst(coverage1([1]), { 1 => { [2] => 41, [3] => 42 } })
    gsub = parse(features: [["liga", [0]]], lookups: [lookup(4, [first, second])])

    expect(gsub.substitute([1, 2, 1, 3])).to eq([[40, 2], [42, 2]])
  end
end
