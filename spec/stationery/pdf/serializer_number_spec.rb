# frozen_string_literal: true

# The number writer has a path of its own for the Floats a content stream is
# made of. What it writes is what `format("%.4f")` with its zeros trimmed
# wrote, which is kept here as the reference.
RSpec.describe Stationery::PDF::Serializer, ".number" do
  def number(value) = described_class.number(value)

  def reference(value)
    return value.to_s if value.is_a?(Integer)

    str = format("%.4f", value)
    last = str.bytesize
    last -= 1 while str.getbyte(last - 1) == 48 # "0"
    last -= 1 if str.getbyte(last - 1) == 46 # "."
    str = str.byteslice(0, last)
    str == "-0" ? "0" : str
  end

  def allocations
    GC.disable
    before = GC.stat(:total_allocated_objects)
    yield
    GC.stat(:total_allocated_objects) - before
  ensure
    GC.enable
  end

  def differences(values)
    values.reject { |value| number(value) == reference(value) }
          .first(5).map { |value| "#{value.inspect}: #{number(value)} for #{reference(value)}" }
  end

  it "has a reference that trims as the writer always did" do
    expect([5.0, 100.25, 0.123456, -0.00001, 1200.0, 0.1].map { |value| reference(value) })
      .to eq(%w[5 100.25 0.1235 0 1200 0.1])
  end

  it "writes whole Floats without a fraction, whatever their size" do
    expect(number(5.0)).to eq("5")
    expect(number(-12.0)).to eq("-12")
    expect(number(1200.0)).to eq("1200")
    expect(number(100_000.0)).to eq("100000")
    expect(number(1e15)).to eq("1000000000000000")
    expect(number(1e22)).to eq("10000000000000000000000")
    expect(number(-(2.0**70))).to eq((-(2**70)).to_s)
  end

  it "writes zero for negative zero and for what rounds to it" do
    expect(number(-0.0)).to eq("0")
    expect(number(0.0)).to eq("0")
    expect(number(0.00004)).to eq("0")
    expect(number(-0.00004)).to eq("0")
    expect(number(1e-300)).to eq("0")
    expect(number(-Float::MIN)).to eq("0")
  end

  it "keeps the sign of what rounds to a ten-thousandth" do
    expect(number(0.00006)).to eq("0.0001")
    expect(number(-0.00006)).to eq("-0.0001")
    expect(number(-0.75)).to eq("-0.75")
  end

  it "rounds to four decimals and trims the zeros after them" do
    expect(number(12.3400)).to eq("12.34")
    expect(number(0.10001)).to eq("0.1")
    expect(number(3.14159265)).to eq("3.1416")
    expect(number(-841.889763779)).to eq("-841.8898")
    expect(number(0.99995001)).to eq("1")
    expect(number(-9.99996)).to eq("-10")
    expect(number(123_456.789012)).to eq("123456.789")
  end

  it "rounds an exact tie to the even digit, as format does" do
    expect(number(0.03125)).to eq("0.0312")
    expect(number(0.09375)).to eq("0.0938")
    expect(number(-0.03125)).to eq("-0.0312")
    expect(number(2.71875)).to eq("2.7188")
    ties = (-4096..4096).map { |index| index / 32.0 } + (1..4096).map { |index| (index / 2048.0) + 17 }

    expect(differences(ties)).to be_empty
  end

  it "rounds what is a hair from a tie as format does" do
    near = (0..20_000).flat_map do |index|
      tie = (index / 10_000.0) + 0.00005
      [tie, tie.prev_float, tie.next_float, -tie, tie + 1e-12, tie - 1e-12]
    end

    expect(differences(near)).to be_empty
  end

  it "writes every multiple of 0.0001 between -3 and 3 as format does" do
    values = (-30_000..30_000).flat_map { |index| [index / 10_000.0, index * 0.0001] }

    expect(differences(values)).to be_empty
  end

  it "writes random Floats of every size as format does" do
    random = Random.new(156)
    values = [1e-6, 1e-3, 1, 100, 1e4, 1e5, 1e6, 1e9, 1e15, 1e20].flat_map do |scale|
      Array.new(3_000) { (random.rand - 0.5) * 2 * scale }
    end

    expect(differences(values)).to be_empty
  end

  it "writes the edges of the Floats as format does" do
    edges = [Float::MAX, -Float::MAX, Float::MIN, Float::EPSILON, 99_999.99995, 100_000.00005, 99_999.99994999,
             (2.0**53) - 1, 2.0**53, (2.0**53) + 2, 4_503_599_627_370_495.5, 0.5.prev_float, 1.0.prev_float,
             1.0.next_float, 999_999.99995, 1e5.prev_float, 1e5.next_float, 0.00005, 0.00015, 0.99995]

    expect(differences(edges)).to be_empty
    expect(number(Float::NAN)).to eq(format("%.4f", Float::NAN))
    expect(number(Float::INFINITY)).to eq(format("%.4f", Float::INFINITY))
    expect(number(-Float::INFINITY)).to eq(format("%.4f", -Float::INFINITY))
  end

  it "writes Integers and Rationals as it did" do
    expect(number(12)).to eq("12")
    expect(number(-7)).to eq("-7")
    expect(number(Rational(1, 3))).to eq("0.3333")
    expect(number(Rational(5, 2))).to eq("2.5")
  end

  it "answers a String of its own in the encoding it had, which may be added to" do
    [1.5, 2.0, -0.25, 0.00001, 1e20].each do |value|
      expect(number(value).encoding).to eq(Encoding::UTF_8)
      expect(number(value)).not_to be_frozen
      expect(number(value) << " m").to end_with(" m")
    end
    expect(number(0.0)).not_to be(number(0.0))
  end

  it "writes a coordinate with one String" do
    values = [12.5, 841.89, -3.25, 0.0012, 595.2756, 7.0]
    values.each { |value| number(value) }

    expect(allocations { 50.times { values.each { |value| number(value) } } }).to be <= (50 * values.size) + 1
  end
end
