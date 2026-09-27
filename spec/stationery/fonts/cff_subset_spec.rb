# frozen_string_literal: true

RSpec.describe Stationery::Fonts::CffSubset do
  def cff_of(name) = Stationery::Fonts::TrueType.new(File.binread(font_path(name))).cff

  def private_dict(cff, top)
    size, offset = top.fetch(Stationery::Fonts::CFF::PRIVATE)
    cff.data.byteslice(offset, size)
  end

  def local_subrs(cff, top)
    offset = top.fetch(Stationery::Fonts::CFF::PRIVATE).last
    subrs = Stationery::Fonts::CFF.parse_dict(private_dict(cff, top))[Stationery::Fonts::CFF::SUBRS]
    subrs && cff.index_at(offset + subrs.first).items.map { |item| cff.data.byteslice(*item) }
  end

  def font_dicts(cff)
    index = cff.index_at(cff.top.fetch(Stationery::Fonts::CFF::FD_ARRAY).first)
    index.items.each_index.map { |i| Stationery::Fonts::CFF.parse_dict(cff.item(index, i)) }
  end

  context "with a name-keyed font" do
    let(:cff) { cff_of("SourceSans3-Latin.otf") }
    let(:subset) { Stationery::Fonts::CFF.new(described_class.build(cff, [2, 23])) }

    it "keeps every glyph id, blanking unused charstrings to endchar" do
      expect(subset.num_glyphs).to eq(cff.num_glyphs)
      expect(subset.item(subset.charstrings, 5)).to eq("\x0E".b)
      [0, 2, 23].each { |gid| expect(subset.item(subset.charstrings, gid)).to eq(cff.item(cff.charstrings, gid)) }
      expect(subset.data.bytesize).to be < cff.data.bytesize * 2 / 3 # Global and local Subrs are kept
    end

    it "keeps the Private DICT, its Subrs, the charset and the Global Subrs" do
      expect(private_dict(subset, subset.top)).to eq(private_dict(cff, cff.top))
      expect(local_subrs(subset, subset.top)).to eq(local_subrs(cff, cff.top))
      expect(subset.global_subrs.items.size).to eq(cff.global_subrs.items.size)
      expect(subset.top[Stationery::Fonts::CFF::CHARSET]).not_to eq([0])
      expect(Stationery::Fonts::CFF.parse_charset(subset.data, subset.top[15].first, 160))
        .to eq(Stationery::Fonts::CFF.parse_charset(cff.data, cff.top[15].first, 160))
    end
  end

  context "with a CID-keyed font" do
    let(:cff) { cff_of("NotoSansJP-Subset.otf") }
    let(:subset) { Stationery::Fonts::CFF.new(described_class.build(cff, [5])) }

    it "keeps the charset, FDSelect and every Font DICT's Private DICT and Subrs" do
      expect(subset.ros).to eq(cff.ros)
      expect((0...12).map { |gid| subset.cid_for(gid) }).to eq((0...12).map { |gid| cff.cid_for(gid) })
      expect(subset.item(subset.charstrings, 6)).to eq("\x0E".b)
      expect(subset.item(subset.charstrings, 5)).to eq(cff.item(cff.charstrings, 5))
      font_dicts(subset).zip(font_dicts(cff)).each do |ours, theirs|
        expect(private_dict(subset, ours)).to eq(private_dict(cff, theirs))
        expect(local_subrs(subset, ours)).to eq(local_subrs(cff, theirs))
      end
    end

    it "copies FDSelect byte for byte" do
      fd_select = ->(font) { font.data.byteslice(font.top[Stationery::Fonts::CFF::FD_SELECT].first, 13) }

      expect(fd_select.call(subset)).to eq(fd_select.call(cff))
    end
  end

  it "sizes charsets, encodings and FDSelects in every format" do
    expect(described_class.charset_size([0].pack("C"), 0, 4)).to eq(7)
    expect(described_class.charset_size([1, 5, 2].pack("CnC"), 0, 4)).to eq(4)
    expect(described_class.charset_size([2, 5, 2].pack("Cnn"), 0, 4)).to eq(5)
    expect(described_class.encoding_size([0, 3].pack("CC"), 0)).to eq(5)
    expect(described_class.encoding_size([0x81, 2, 1, 1, 9, 1, 1, 65, 0, 1].pack("C*"), 0)).to eq(10)
    expect(described_class.fd_select_size([0].pack("C"), 0, 12)).to eq(13)
    expect(described_class.fd_select_size([3, 2].pack("Cn"), 0, 12)).to eq(11)
  end
end
