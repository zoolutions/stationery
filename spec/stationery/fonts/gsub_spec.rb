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

  it "is nil for a font whose liga feature has no ligature substitutions" do
    expect(described_class.parse(load("Inter-Regular.ttf"))).to be_nil
    expect(parse(features: [["liga", [0]]], lookups: [lookup(1, [[1].pack("n")])])).to be_nil
  end

  it "is nil without GSUB, with an unknown major version or without a liga feature" do
    ttf = load("OpenSans-Regular.ttf")
    allow(ttf).to receive(:table_offset).with("GSUB").and_return(nil)
    liga = [["liga", [0]]]
    lookups = [lookup(4, [GsubBuilder.ligature_subst(coverage1([1]), f_ligatures)])]

    expect(described_class.parse(ttf)).to be_nil
    expect(described_class.parse(GsubBuilder.gsub(features: liga, lookups:, version: 2))).to be_nil
    expect(parse(features: [["dlig", [0]]], lookups:)).to be_nil
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
