# frozen_string_literal: true

RSpec.describe Stationery::Fonts::Gpos do
  def load(name) = Stationery::Fonts::TrueType.new(File.binread(font_path(name)))

  describe "with Inter (PairPos formats 1 and 2)" do
    let(:ttf) { load("Inter-Regular.ttf") }
    let(:gpos) { described_class.parse(ttf) }

    def pair(text) = gpos.adjust(*text.chars.map { |c| ttf.glyph_id(c.ord) })

    # Values cross-checked against HarfBuzz shaping with only `kern` enabled.
    it "reads the kern feature's X advance adjustments in font units" do
      expect(pair("AV")).to eq(-192)
      expect(pair("To")).to eq(-224)
      expect(pair("VA")).to eq(-176)
      expect(pair("LT")).to eq(-272)
      expect(pair("r.")).to eq(-176)
    end

    it "leaves unrelated pairs alone" do
      expect(pair("AB")).to eq(0)
      expect(pair("HH")).to eq(0)
    end
  end

  it "is nil for a GPOS table without a kern feature" do
    expect(described_class.parse(load("OpenSans-Regular.ttf"))).to be_nil
    expect(described_class.parse(GposBuilder.gpos(features: [], lookups: []))).to be_nil
  end

  it "is nil for a font without GPOS or with an unknown major version" do
    ttf = load("Inter-Regular.ttf")
    allow(ttf).to receive(:table_offset).with("GPOS").and_return(nil)

    expect(described_class.parse(ttf)).to be_nil
    expect(described_class.parse(GposBuilder.gpos(features: [["kern", [0]]], lookups: [], version: 2))).to be_nil
  end

  describe "with every lookup shape" do
    include GposBuilder

    let(:first_lookup) do
      pairs = pair_pos1(coverage2([10..11]), { 10 => { 20 => [[7, -50], [99]] }, 11 => { 21 => [[0, -30], [0]] } },
                        vf1: 0x0005, vf2: 0x0004)
      matrix = [[[[0], []]] * 3, [[[0], []], [[-999], []], [[-40], []]], [[[-5], []]] * 3]
      classes = pair_pos2(coverage1([10, 12]), class_def1(10, [1, 0, 2]), class_def2([[20..20, 1], [22..25, 2]]),
                          matrix, vf1: 0x0004, vf2: 0)
      lookup(9, [extension(2, pairs), extension(2, classes)])
    end
    let(:second_lookup) { lookup(2, [pair_pos1(coverage1([10]), { 10 => { 20 => [[-10], []] } }, vf1: 4, vf2: 0)]) }
    let(:other_feature) { lookup(2, [pair_pos1(coverage1([10]), { 10 => { 20 => [[-1000], []] } }, vf1: 4, vf2: 0)]) }
    let(:unsupported) { [lookup(9, [extension(4, [1].pack("n"))]), lookup(1, [[1].pack("n")])] }
    let(:gpos) do
      described_class.parse(
        GposBuilder.gpos(features: [["cpsp", [2]], ["kern", [0, 1, 3, 4]], ["kern", [1]]],
                         lookups: [first_lookup, second_lookup, other_feature, *unsupported])
      )
    end

    it "resolves Extension lookups and reads X advance past the other value record fields" do
      expect(gpos.adjust(11, 21)).to eq(-30)
    end

    it "lets the first subtable covering the left glyph apply, falling through missing format 1 pairs" do
      expect(gpos.adjust(10, 22)).to eq(-40)
      expect(gpos.adjust(12, 30)).to eq(-5)
      expect(gpos.adjust(11, 22)).to eq(0)
    end

    it "adds up adjustments across the kern feature's lookups, once per lookup, ignoring other features" do
      expect(gpos.adjust(10, 20)).to eq(-60)
    end

    it "ignores glyphs no subtable covers" do
      expect(gpos.adjust(13, 20)).to eq(0)
    end
  end

  it "kerns documents set in a GPOS-only font" do
    inter = Class.new(SpecDocument) do
      font_family "Inter", regular: File.join(SpecDocument::FONTS, "Inter-Regular.ttf")
      default_text font: "Inter"
      def view_template = text("AVATAR")
    end
    pdf = inter.new.to_pdf

    expect(page_contents(pdf).first).to include("] TJ")
    expect(text_of(pdf)).to eq("AVATAR")
  end
end
