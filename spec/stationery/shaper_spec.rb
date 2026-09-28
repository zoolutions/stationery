# frozen_string_literal: true

RSpec.describe Stationery::Shaper do
  let(:face) do
    Stationery::Shaper::Face.new(path: "/fonts/a.ttf", index: 0, data: "", units_per_em: 1000, postscript_name: "A",
                                 glyph_count: 10)
  end

  def glyph(**fields) = Stationery::Shaper::Glyph.new(gid: 1, advance: 500, cluster: 0, **fields)

  describe described_class::Glyph do
    it "sits on the pen unless it is given offsets" do
      expect(glyph.to_h).to eq(gid: 1, advance: 500, x_offset: 0, y_offset: 0, cluster: 0)
      expect(glyph(x_offset: -20, y_offset: 35).to_h).to include(x_offset: -20, y_offset: 35)
    end
  end

  describe described_class::Face do
    it "names the font when inspected, not its bytes" do
      expect(face.inspect).to eq("#<Stationery::Shaper::Face A index=0 glyphs=10>")
    end
  end

  describe ".check" do
    it "takes anything that answers call, and nil for no shaper" do
      shaper = Class.new { def self.call(*, **) = [] }

      expect(described_class.check(shaper)).to be(shaper)
      expect(described_class.check(FakeShapers::NOMINAL)).to be(FakeShapers::NOMINAL)
      expect(described_class.check(nil)).to be_nil
    end

    it "refuses what cannot be called" do
      expect { described_class.check(:harfbuzz) }
        .to raise_error(ArgumentError, "shaper must answer call(text, font, **options), got :harfbuzz")
    end
  end

  describe ".glyphs" do
    it "answers the glyphs as they came" do
      glyphs = [glyph, glyph(cluster: 1, advance: 12.5)]

      expect(described_class.glyphs(glyphs, "ab", face)).to eq(glyphs)
    end

    it "takes a Hash of a glyph's fields for a glyph" do
      expect(described_class.glyphs([{ gid: 3, advance: 10, cluster: 1 }], "ab", face))
        .to eq([Stationery::Shaper::Glyph.new(gid: 3, advance: 10, cluster: 1)])
    end

    it "is a Stationery::Error when the answer cannot be drawn" do
      expect(Stationery::ShaperError.ancestors).to include(Stationery::Error)
    end

    {
      "an answer that is not an Array" => ["glyphs", "shaper must answer an Array of glyphs or nil, got \"glyphs\""],
      "something that is not a glyph" => [[42], "shaper answered 42, not a Stationery::Shaper::Glyph"],
      "a Hash without the fields" => [[{ gid: 1 }], /shaper answered \{gid: 1\}: missing keyword/],
      "a Hash with a field too many" => [[{ gid: 1, advance: 1, cluster: 0, colour: 1 }], /unknown keyword: :colour/]
    }.each do |what, (answer, message)|
      it "refuses #{what} for an answer" do
        expect { described_class.glyphs(answer, "ab", face) }.to raise_error(Stationery::ShaperError, message)
      end
    end

    {
      "a glyph the font does not have" => [{ gid: 10 }, "shaper answered gid 10: the font has 10 glyphs"],
      "a negative glyph id" => [{ gid: -1 }, "shaper answered gid -1: the font has 10 glyphs"],
      "a glyph id that is not an Integer" => [{ gid: 1.0 }, "shaper answered gid 1.0: the font has 10 glyphs"],
      "a cluster past the text" => [{ cluster: 2 }, "shaper answered cluster 2: the text has 2 characters"],
      "a cluster that is no Integer" => [{ cluster: nil }, "shaper answered cluster nil: the text has 2 characters"],
      "an advance that is not a number" => [{ advance: "500" },
                                            "shaper answered advance \"500\", not a number of font units"],
      "an advance that is not finite" => [{ advance: Float::NAN },
                                          "shaper answered advance NaN, not a number of font units"],
      "an offset that is not finite" => [{ y_offset: Float::INFINITY },
                                         "shaper answered y_offset Infinity, not a number of font units"],
      "an offset that is not a number" => [{ x_offset: nil },
                                           "shaper answered x_offset nil, not a number of font units"]
    }.each do |what, (fields, message)|
      it "refuses #{what}" do
        expect { described_class.glyphs([glyph(**fields)], "ab", face) }
          .to raise_error(Stationery::ShaperError, message)
      end
    end
  end
end
