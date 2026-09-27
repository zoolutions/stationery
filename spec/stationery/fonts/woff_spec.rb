# frozen_string_literal: true

require "zlib"

RSpec.describe Stationery::Fonts::WOFF do
  # Open Sans Regular subset to ASCII: the WOFF fixture and face 0 of the
  # collection fixture were both written from the same file.
  let(:source) { Stationery::Fonts::TrueType.new(File.binread(font_path("OpenSans-Collection.ttc"))) }
  let(:woff) { File.binread(font_path("OpenSans-Regular.woff")) }

  def directory(sfnt)
    Array.new(sfnt.byteslice(4, 2).unpack1("n")) { |i| sfnt.byteslice(12 + (i * 16), 16).unpack("a4NNN") }
  end

  def table(sfnt, tag)
    _, _, offset, length = directory(sfnt).find { |entry| entry.first == tag }
    sfnt.byteslice(offset, length)
  end

  # A WOFF 1.0 file holding `tables`, zlib-compressed where `compress` says so.
  def build_woff(tables, compress:)
    offset = 44 + (tables.size * 20)
    entries = []
    body = tables.map do |tag, data|
      packed = compress.include?(tag) ? Zlib::Deflate.deflate(data) : data
      entries << [tag, offset, packed.bytesize, data.bytesize, Stationery::Fonts::Subset.checksum(data)].pack("a4NNNN")
      offset += packed.bytesize + (-packed.bytesize % 4)
      packed + ("\0" * (-packed.bytesize % 4))
    end
    header = ["wOFF", 0x00010000, offset, tables.size, 0, 0, 1, 0, 0, 0, 0, 0, 0].pack("a4NNnnNnnNNNNN")
    (header + entries.join + body.join).b
  end

  it "rebuilds an sfnt with the source font's flavor and tables" do
    sfnt = described_class.unpack(woff)
    tags = directory(sfnt).map(&:first)

    expect(sfnt.byteslice(0, 4)).to eq("\x00\x01\x00\x00".b)
    expect(tags).to eq(source.tables.keys.sort)
    (tags - ["head"]).each { |tag| expect(table(sfnt, tag)).to eq(source.table_data(tag)), "#{tag} differs" }
  end

  it "writes a valid table directory: aligned offsets, checksums and search fields" do
    sfnt = described_class.unpack(woff)
    count = directory(sfnt).size

    expect(sfnt.byteslice(6, 6).unpack("nnn")).to eq([256, 4, (count * 16) - 256])
    directory(sfnt).each do |tag, checksum, offset, length|
      body = sfnt.byteslice(offset, length)
      body = body.dup.tap { |b| b[8, 4] = "\0\0\0\0" } if tag == "head"
      expect(offset % 4).to eq(0)
      expect(Stationery::Fonts::Subset.checksum(body)).to eq(checksum), "checksum mismatch for #{tag}"
    end
  end

  it "reads stored and compressed tables alike" do
    tables = source.tables.keys.sort.to_h { |tag| [tag, source.table_data(tag)] }
    sfnt = described_class.unpack(build_woff(tables, compress: %w[glyf cmap name]))

    tables.each { |tag, data| expect(table(sfnt, tag)).to eq(data) }
    expect(Stationery::Fonts::TrueType.new(sfnt).postscript_name).to eq("OpenSans-Regular")
  end

  it "raises a named error for a table that does not inflate" do
    broken = build_woff({ "head" => "x" * 60 }, compress: [])
    broken[44 + 8, 4] = [59].pack("N")

    expect { described_class.unpack(broken) }.to raise_error(Stationery::UnsupportedFont, /corrupt WOFF table head/)
  end
end
