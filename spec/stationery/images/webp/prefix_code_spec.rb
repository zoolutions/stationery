# frozen_string_literal: true

RSpec.describe Stationery::Images::WebP::PrefixCode do
  let(:bits) { WebpFactory::Bits.new }

  def reader = Stationery::Images::WebP::BitReader.new(bits.to_s)
  def fail_with(message) = raise_error(Stationery::UnsupportedImage, message)

  # The symbols a table decodes the written words to.
  def decode(size, symbols)
    words = yield
    symbols.each { |symbol| bits.word(*words.fetch(symbol)) }
    bits.write(0, 32)
    source = reader
    table = described_class.read(source, size)
    symbols.map { source.symbol(table) }
  end

  it "reads a code of one symbol, which takes no bits" do
    bits.single(7)
    source = reader
    table = described_class.read(source, 256)

    expect(Array.new(3) { source.symbol(table) }).to eq([7, 7, 7])
  end

  it "reads a code of one symbol stored in one bit" do
    bits.write(1, 1).write(0, 1).write(0, 1).write(1, 1)
    source = reader

    expect(source.symbol(described_class.read(source, 40))).to eq(1)
  end

  it "reads a code of two symbols" do
    bits.pair(3, 200).write(0b0110, 4)
    source = reader
    table = described_class.read(source, 256)

    expect(Array.new(4) { source.symbol(table) }).to eq([3, 200, 200, 3])
  end

  it "reads coded lengths, short and long codes alike" do
    lengths = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 15]
    symbols = [0, 15, 7, 8, 14, 3, 9, 15, 1]

    expect(decode(16, symbols) { bits.code(lengths) }).to eq(symbols)
  end

  it "repeats the previous length, or zeros, with the repeat codes" do
    # 4 x length 2 as "2, then 16 (repeat 3)", 11 zeros as 18, 3 zeros as 17: only symbols 0..3 have a word.
    steps = [[2], [16, 0], [18, 0], [17, 0]]
    lengths = [2, 2, 2, 2] + Array.new(14, 0)

    expect(decode(18, [3, 0, 2, 1]) { bits.code(lengths, steps:) }).to eq([3, 0, 2, 1])
  end

  it "repeats a length of 8 when none came before" do
    lengths = Array.new(256, 8)
    steps = Array.new(42) { [16, 3] } + [[16, 1]]

    expect(decode(256, [0, 255, 128]) { bits.code(lengths, steps:) }).to eq([0, 255, 128])
  end

  it "stops reading lengths at the limit the code gives" do
    lengths = [1, 1] + Array.new(254, 0)

    expect(decode(256, [1, 0, 1]) { bits.code(lengths, steps: [[1], [1]], limit: 2) }).to eq([1, 0, 1])
  end

  it "refuses a code that leaves bit patterns unused" do
    bits.code([1, 2] + Array.new(14, 0))

    expect { described_class.read(reader, 16) }.to fail_with("invalid WebP image: incomplete prefix code")
  end

  it "refuses a code with more words than fit" do
    bits.code([1, 1, 1] + Array.new(13, 0))

    expect { described_class.read(reader, 16) }.to fail_with("invalid WebP image: incomplete prefix code")
  end

  it "refuses a code without symbols" do
    bits.code(Array.new(16, 0))

    expect { described_class.read(reader, 16) }.to fail_with("invalid WebP image: incomplete prefix code")
  end

  it "refuses a symbol outside the alphabet" do
    bits.single(40)

    expect { described_class.read(reader, 40) }.to fail_with("invalid WebP image: prefix code symbol out of range")
  end

  it "refuses more lengths than the alphabet has symbols" do
    bits.code([1, 1], limit: 17)

    expect { described_class.read(reader, 16) }.to fail_with("invalid WebP image: too many code lengths")
  end

  it "refuses a repeat that runs past the alphabet" do
    bits.code([], steps: [[1], [1], [18, 127]])

    expect { described_class.read(reader, 16) }.to fail_with("invalid WebP image: code lengths overflow")
  end
end
