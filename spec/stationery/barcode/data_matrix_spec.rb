# frozen_string_literal: true

# Checked outside the suite as well: every size from 10 × 10 to 144 × 144,
# filled to capacity, decoded by dmtxread (libdmtx 0.7), and module for
# module the symbol dmtxwrite makes of the same data in ASCII encodation.
RSpec.describe Stationery::Barcode::DataMatrix do
  def rows(symbol) = symbol.modules.map { |row| row.map { |dark| dark ? 1 : 0 }.join }

  it "encodes ASCII a character a codeword, digits two to one, the rest with an upper shift" do
    expect(described_class.codewords("A1")).to eq([66, 50])
    expect(described_class.codewords("123456")).to eq([142, 164, 186])
    expect(described_class.codewords("12a")).to eq([142, 98])
    expect(described_class.codewords("é")).to eq([235, 68, 235, 42])
  end

  it "pads to the capacity of the smallest square that holds the data, the pads after the first scrambled" do
    symbol = described_class.new("A")

    expect(symbol.size).to eq(10)
    expect(symbol.data_codewords).to eq([66, 129, 70])
  end

  it "adds the Reed–Solomon codewords of ISO/IEC 16022 annex O's example" do
    # "123456" in a 10 × 10 symbol: data 142 164 186, check 114 25 5 88 102.
    expect(described_class.new("123456").codewords).to eq([142, 164, 186, 114, 25, 5, 88, 102])
  end

  it "takes the smallest of the 24 square sizes, and refuses more than 144 × 144 holds" do
    expect(described_class.new("a" * 3).size).to eq(10)
    expect(described_class.new("a" * 4).size).to eq(12)
    expect(described_class.new("a" * 1558).size).to eq(144)
    expect(described_class.new("1" * 3116).size).to eq(144)
    expect { described_class.new("a" * 1559) }.to raise_error(ArgumentError, /more than a Data Matrix holds/)
  end

  it "draws the finder and the clock track around each data region" do
    symbol = described_class.new("a" * 50) # 32 × 32, four regions of 14 × 14

    expect(symbol.size).to eq(32)
    expect(symbol.modules.map(&:first).uniq).to eq([true])
    expect(symbol.modules.last.uniq).to eq([true])
    expect(rows(symbol).first).to eq("10" * 16)
    expect(symbol.modules.map(&:last).each_slice(2).map { |light, dark| [light, dark] }.uniq).to eq([[false, true]])
    expect(symbol.modules[15].uniq).to eq([true])
    expect(rows(symbol)[16]).to eq("10" * 16)
  end

  it "lays out a 10 × 10 symbol as libdmtx does" do
    expect(rows(described_class.new("123456"))).to eq(%w[
                                                        1010101010 1100101101 1100000100 1100011101 1100001000
                                                        1000001111 1110110000 1111011001 1001110100 1111111111
                                                      ])
  end

  it "writes ^BX at its size, in whole dots a module" do
    expect(described_class.new("SX0042771903").zpl(module_dots: 4))
      .to eq("^BXN,4,200,14,14,6,_,1^FDSX0042771903^FS")
    expect(described_class.new("a_b").native?).to be(false)
  end
end
