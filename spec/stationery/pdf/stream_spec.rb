# frozen_string_literal: true

require "zlib"

RSpec.describe Stationery::PDF::Stream do
  it "Flate-compresses data and records the compressed length" do
    stream = described_class.new("BT /F1 12 Tf ET")

    expect(stream.dictionary[:Filter]).to eq(:FlateDecode)
    expect(Zlib::Inflate.inflate(stream.data)).to eq("BT /F1 12 Tf ET")
    expect(stream.dictionary[:Length]).to eq(stream.data.bytesize)
  end

  it "leaves data alone when the dictionary already declares a filter" do
    stream = described_class.new("\xFF\xD8jpeg".b, { Filter: :DCTDecode })

    expect(stream.data).to eq("\xFF\xD8jpeg".b)
    expect(stream.dictionary).to include(Filter: :DCTDecode, Length: 6)
  end

  it "does not mutate the dictionary it was given" do
    dictionary = { Type: :XObject }
    described_class.new("x", dictionary)

    expect(dictionary).to eq(Type: :XObject)
  end
end
