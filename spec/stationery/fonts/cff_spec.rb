# frozen_string_literal: true

RSpec.describe Stationery::Fonts::CFF do
  def cff_of(name) = Stationery::Fonts::TrueType.new(File.binread(font_path(name))).cff

  context "with a name-keyed font" do
    subject(:cff) { cff_of("SourceSans3-Latin.otf") }

    it "uses glyph ids as CIDs" do
      expect(cff).not_to be_cid_keyed
      expect(cff.ros).to be_nil
      expect([0, 1, 80].map { |gid| cff.cid_for(gid) }).to eq([0, 1, 80])
    end

    it "counts the charstrings, matching maxp" do
      expect(cff.num_glyphs).to eq(160)
    end

    # fontTools: topDictIndex[0].rawDict["Private"] == (64, 9600)
    it "reads the Top DICT" do
      expect(cff.top.keys).to include(described_class::CHARSET, described_class::CHARSTRINGS, described_class::PRIVATE)
      expect(cff.top[described_class::PRIVATE]).to eq([64, 9600])
    end
  end

  context "with a CID-keyed font" do
    subject(:cff) { cff_of("NotoSansJP-Subset.otf") }

    it "reads the registry, ordering and supplement" do
      expect(cff).to be_cid_keyed
      expect(cff.ros).to eq(["Adobe", "Identity", 0])
      expect(cff.num_glyphs).to eq(12)
    end

    # fontTools: TTFont(...)["CFF "].cff.topDictIndex[0].charset lists
    # .notdef, cid01566 (キ), cid01578, cid01591, cid01593, cid20220 (日),
    # cid20758 (本), cid37860 (語), cid65261, cid65273, cid65286, cid65288.
    it "maps glyph ids to CIDs through the charset" do
      expect((0..7).map { |gid| cff.cid_for(gid) }).to eq([0, 1566, 1578, 1591, 1593, 20_220, 20_758, 37_860])
      expect(cff.cid_for(11)).to eq(65_288)
    end
  end

  it "decodes every DICT operand encoding" do
    operands = [
      [28, 0x01, 0x00], [29, 0x00, 0x01, 0x00, 0x00], [139], [32], [246], [247, 0], [254, 255],
      [30, 0xE2, 0xA2, 0x5F], [30, 0x1C, 0x3F], [30, 0x0A, 0x1F]
    ]
    dict = described_class.parse_dict([*operands.flatten, 0, 12, 7].pack("C*"))

    expect(dict[0]).to eq([256, 65_536, 0, -107, 107, 108, -1131, -2.25, 1.0e-3, 0.1])
    expect(dict[1207]).to eq([])
  end

  it "finds the Font DICT of a glyph through FDSelect formats 0 and 3" do
    fd_of = lambda do |fd_select, gid|
      cff = described_class.allocate
      cff.instance_variable_set(:@data, fd_select)
      cff.instance_variable_set(:@top, { described_class::FD_SELECT => [0] })
      cff.send(:fd_index, gid)
    end
    format0 = [0, 2, 2, 1].pack("C*")
    format3 = [3, 3, 0, 0, 5, 2, 9, 1, 12].pack("CnnCnCnCn") # [0, 5) → 0, [5, 9) → 2, [9, 12) → 1

    expect((0..2).map { |gid| fd_of.call(format0, gid) }).to eq([2, 2, 1])
    expect([0, 4, 5, 8, 9, 11].map { |gid| fd_of.call(format3, gid) }).to eq([0, 0, 2, 2, 1, 1])
  end

  it "reads charsets in range formats 1 and 2" do
    format1 = [1, 5, 2].pack("CnC")
    format2 = [2, 100, 3].pack("Cnn")

    expect(described_class.parse_charset(format1, 0, 4)).to eq([0, 5, 6, 7])
    expect(described_class.parse_charset(format2, 0, 5)).to eq([0, 100, 101, 102, 103])
  end
end
