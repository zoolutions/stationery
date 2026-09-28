# frozen_string_literal: true

RSpec.describe Stationery::Page::Format do
  def points(width, height) = [width, height].map { (it * 72 / 25.4).round(2) }

  describe ".size" do
    it "answers a name and a size in points as they were given" do
      size = [300, 400.5]

      expect(described_class.size(:a4)).to eq(:a4)
      expect(described_class.size("LEGAL")).to eq("LEGAL")
      expect(described_class.size(size)).to be(size)
      expect(described_class.size([Rational(1, 2), 1])).to eq([Rational(1, 2), 1])
    end

    it "reads two lengths with their units" do
      expect(described_class.size(%w[102mm 74mm]).map { it.round(2) }).to eq(points(102, 74))
      expect(described_class.size(["10.2cm", "4in"]).map { it.round(2) }).to eq([289.13, 288])
      expect(described_class.size(["4in", 300])).to eq([288, 300])
    end

    it "reads a size written as one string" do
      expect(described_class.size("4in x 6in")).to eq([288, 432])
      expect(described_class.size("4inx6in")).to eq([288, 432])
      expect(described_class.size(" 4 IN X 6 IN ")).to eq([288, 432])
      expect(described_class.size("102mm × 74mm").map { it.round(2) }).to eq(points(102, 74))
      expect(described_class.size("101.6 mm x 15.24 cm").map { it.round(2) }).to eq([288, 432])
    end

    it "gives the first length the unit of the second when it has none" do
      expect(described_class.size("102 x 74 mm").map { it.round(2) }).to eq(points(102, 74))
      expect(described_class.size("4x6in")).to eq([288, 432])
    end

    it "refuses anything else, naming what it takes" do
      [:b9, "b9", nil, [], [300], [300, 400, 500], [300, "400"], [0, 100], [100, -1], [Float::NAN, 100],
       [Float::INFINITY, 100], %w[0mm 10mm], ["10mm", nil], "102 x 74", "102mm x 74", "4in by 6in", "4in x 6in x 1in",
       "10mm x 0mm", 300, { width: 1 }, [[1, 2], 3]].each do |size|
        expect { described_class.size(size) }.to raise_error(ArgumentError) { |error|
          expect(error.message).to start_with("unknown page size #{size.inspect} (use a3, a4, a5, a6, a7, b5, ")
          expect(error.message).to end_with(
            'label_100x50, [width, height] in points, ["102mm", "74mm"] or "4in x 6in"; units are mm, cm, in and pt)'
          )
        }
      end
    end
  end

  describe ".margin" do
    it "answers a margin in points as it was given" do
      margin = [40, 44.5, 56, 44]

      expect(described_class.margin(36)).to eq(36)
      expect(described_class.margin(margin)).to be(margin)
      expect(described_class.margin(nil)).to be_nil
      expect(described_class.margin({ x: 10, top: 5 })).to eq({ x: 10, top: 5 })
      expect(described_class.margin(-5)).to eq(-5)
    end

    it "reads lengths with their units into the four sides" do
      expect(described_class.margin("1in")).to eq([72, 72, 72, 72])
      expect(described_class.margin(["1in", 10])).to eq([72, 10, 72, 10])
      expect(described_class.margin({ x: "0.5in", top: "72pt" })).to eq([72, 36, 0, 36])
    end

    it "refuses anything else, naming what it takes" do
      ["3", "3 m", :wide, [1, 2, 3, 4, 5], [], [1, nil], [1, "2"], { top: nil }, { top: :a }, [Float::NAN], true,
       [[1, 2]]].each do |margin|
        expect { described_class.margin(margin) }.to raise_error(ArgumentError) { |error|
          expect(error.message).to start_with("invalid page margin #{margin.inspect} (use points or a length as ")
          expect(error.message).to end_with("units are mm, cm, in and pt)")
        }
      end
    end
  end
end
