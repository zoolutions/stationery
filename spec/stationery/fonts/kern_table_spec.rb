# frozen_string_literal: true

RSpec.describe Stationery::Fonts::KernTable do
  let(:bytes) { File.binread(font_path("OpenSans-Regular.ttf")).b }
  let(:ttf) { Stationery::Fonts::TrueType.new(bytes) }

  def gid(char, font = ttf) = font.glyph_id(char.ord)

  def patched(offset, packed)
    data = bytes.dup
    data[ttf.table_offset("kern") + offset, packed.bytesize] = packed
    Stationery::Fonts::TrueType.new(data)
  end

  it "reads format 0 pairs in font units, negative for tightening pairs" do
    kern = described_class.parse(ttf)

    expect(kern.adjust(gid("A"), gid("V"))).to be < 0
    expect(kern.adjust(gid("T"), gid("o"))).to be < 0
    expect(kern.adjust(gid("A"), gid("B"))).to eq(0)
  end

  it "is nil for a font without a kern table" do
    inter = Stationery::Fonts::TrueType.new(File.binread(font_path("Inter-Regular.ttf")))

    expect(described_class.parse(inter)).to be_nil
  end

  it "is nil for Apple's version 1 kern table" do
    expect(described_class.parse(patched(0, [0x0001_0000].pack("N")))).to be_nil
  end

  it "skips subtables that are vertical, cross-stream or not format 0" do
    [0x0000, 0x0005, 0x0201].each do |coverage|
      font = patched(8, [coverage].pack("n"))

      expect(described_class.parse(font).adjust(gid("A", font), gid("V", font))).to eq(0)
    end
  end
end
