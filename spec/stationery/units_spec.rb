# frozen_string_literal: true

RSpec.describe Stationery::Units do
  it "converts millimetres, centimetres and inches to points" do
    expect(described_class.mm(25.4)).to eq(72)
    expect(described_class.mm(102)).to be_within(0.0001).of(289.1339)
    expect(described_class.cm(2.54)).to be_within(1e-9).of(72)
    expect(described_class.inch(4)).to eq(288)
    expect(described_class.inch(0.5)).to eq(36)
    expect(described_class.pt(12)).to eq(12)
  end

  it "is included in a class, for its instances and its body" do
    label = Class.new do
      include Stationery::Units

      const_set(:WIDTH, mm(254))

      def width = inch(1) + pt(3)
    end

    expect(label::WIDTH).to eq(720)
    expect(label.new.width).to eq(75)
  end

  it "adds nothing to what an object answers to" do
    label = Class.new { include Stationery::Units }

    expect(label.new).not_to respond_to(:mm)
    expect(label).not_to respond_to(:mm)
    expect(Numeric.method_defined?(:mm) || Numeric.private_method_defined?(:mm)).to be(false)
  end

  it "is there in every component and document without an include" do
    document = Class.new(SpecDocument) do
      page size: [mm(102), mm(74)], margin: mm(3)

      def view_template = box(width: cm(2)) { text "x" }
    end

    expect(document.config[:page][:size].map { it.round(2) }).to eq([289.13, 209.76])
    expect(Stationery::Testing::Inspector.new(document.new.to_pdf).page_count).to eq(1)
    expect(Class.new(Stationery::Component) { def width = inch(1) }.new.width).to eq(72)
  end

  it "leaves a document's own helper of that name alone" do
    document = Class.new(SpecDocument) do
      def mm(value) = value * 3
      def width = mm(2)
    end

    expect(document.new.width).to eq(6)
  end

  describe ".points" do
    it "reads a number with its unit" do
      expect(described_class.points("72pt")).to eq(72)
      expect(described_class.points("25.4mm")).to eq(72)
      expect(described_class.points("2.54 cm")).to be_within(1e-9).of(72)
      expect(described_class.points(" 4in ")).to eq(288)
      expect(described_class.points("0.5IN")).to eq(36)
      expect(described_class.points("0mm")).to eq(0)
    end

    it "refuses anything else, naming what it takes" do
      ["3", "3 m", "mm", "-3mm", "+3mm", "3,5mm", ".5mm", "3.mm", "1e2mm", "3mm 4mm", "3 inch", "3\"", "", "3mm\n4"]
        .each do |text|
        expect { described_class.points(text) }
          .to raise_error(ArgumentError, /#{Regexp.escape(text.inspect)} is not a length.*mm, cm, in or pt/m)
      end
      expect { described_class.points(3) }.to raise_error(ArgumentError, /not a length/)
      expect { described_class.points(nil) }.to raise_error(ArgumentError, /not a length/)
    end
  end
end
