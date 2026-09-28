# frozen_string_literal: true

RSpec.describe Stationery::PDF::Serializer do
  def dump(value) = described_class.dump(value)

  it "writes integers, floats trimmed to four decimals, booleans and null" do
    expect(dump(12)).to eq("12")
    expect(dump(1.5)).to eq("1.5")
    expect(dump(2.0)).to eq("2")
    expect(dump(0.123456)).to eq("0.1235")
    expect(dump(-0.00001)).to eq("0")
    expect(dump(true)).to eq("true")
    expect(dump(nil)).to eq("null")
  end

  it "keeps whole floats, negatives and trailing non-zero digits intact" do
    expect(dump(10.0)).to eq("10")
    expect(dump(100.25)).to eq("100.25")
    expect(dump(-3.5)).to eq("-3.5")
    expect(dump(0.5)).to eq("0.5")
  end

  it "writes names, hex-escaping delimiters and non-printable bytes" do
    expect(dump(:Type)).to eq("/Type")
    expect(dump(:"A B")).to eq("/A#20B")
    expect(dump(:"x/y(z)")).to eq("/x#2Fy#28z#29")
  end

  it "writes literal strings, escaping backslash, parentheses and carriage return" do
    expect(dump("a(b)c\\d\re")).to eq("(a\\(b\\)c\\\\d\\re)")
  end

  it "writes hex strings" do
    expect(dump(Stationery::PDF::HexString.new("AB".b))).to eq("<4142>")
  end

  it "writes text strings as PDFDocEncoding when ASCII and UTF-16BE with a BOM otherwise" do
    expect(dump(Stationery::PDF::TextString.new("Invoice"))).to eq("(Invoice)")
    expect(dump(Stationery::PDF::TextString.new("Müller"))).to eq("<FEFF004D00FC006C006C00650072>")
  end

  it "writes references, arrays and nested dictionaries" do
    ref = Stationery::PDF::Reference.new(7)
    expect(dump([1, ref, :N])).to eq("[1 7 0 R /N]")
    expect(dump({ Type: :Page, Kids: [ref], Box: { A: 1 } })).to eq("<</Type /Page /Kids [7 0 R] /Box <</A 1>>>>")
  end

  it "passes every string's bytes through a crypt hook and writes the result as hex" do
    crypt = :reverse.to_proc
    value = { S: "ab", H: Stationery::PDF::HexString.new("cd".b), T: [Stationery::PDF::TextString.new("ü"), :N, 1] }

    expect(described_class.dump(value, crypt)).to eq("<</S <6261> /H <6463> /T [<FC00FFFE> /N 1]>>")
    expect(described_class.dump(Stationery::PDF::TextString.new("ok"), crypt)).to eq("<6B6F>")
  end

  it "writes a Verbatim as it is, whatever the crypt hook" do
    placeholder = Stationery::PDF::Verbatim.new("<0000>")

    expect(dump(placeholder)).to eq("<0000>")
    expect(described_class.dump({ Contents: placeholder, Name: "ab" }, :reverse.to_proc))
      .to eq("<</Contents <0000> /Name <6261>>>")
  end

  it "refuses values it cannot represent" do
    expect { dump(Object.new) }.to raise_error(ArgumentError, /cannot serialize Object/)
  end
end
