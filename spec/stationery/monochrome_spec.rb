# frozen_string_literal: true

RSpec.describe Stationery::Monochrome do
  describe ".settings" do
    it "defaults to 203 dpi, no snap, a threshold of half and Floyd–Steinberg" do
      settings = described_class.settings

      expect(settings.to_h).to eq(dpi: 203, snap: false, threshold: 0.5, dither: :floyd_steinberg)
      expect(settings.dot).to be_within(1e-9).of(72.0 / 203)
    end

    it "refuses what it cannot use" do
      expect { described_class.settings(dpi: 0) }
        .to raise_error(ArgumentError, "monochrome dpi: is a number above 0, not 0")
      expect { described_class.settings(threshold: 2) }
        .to raise_error(ArgumentError, "monochrome threshold: is a number from 0 to 1, not 2")
      expect { described_class.settings(dither: :atkinson) }
        .to raise_error(ArgumentError, /monochrome dither: is :floyd_steinberg, :ordered or :threshold/)
      expect { described_class.settings(snap: "yes") }
        .to raise_error(ArgumentError, 'monochrome snap: is true or false, not "yes"')
      expect { described_class.settings(colour: 1) }.to raise_error(ArgumentError, /unknown monochrome option :colour/)
    end
  end

  describe ".for" do
    let(:declared) { described_class.settings(dpi: 300, snap: true) }

    it "keeps what the class declares, and takes it away with false or nil" do
      expect(described_class.for(declared, declared)).to be(declared)
      expect(described_class.for(declared, false)).to be_nil
      expect(described_class.for(declared, nil)).to be_nil
      expect(described_class.for(nil, nil)).to be_nil
    end

    it "turns it on with true, and lays a Hash over what the class declares" do
      expect(described_class.for(nil, true)).to eq(described_class.settings)
      expect(described_class.for(declared, true)).to be(declared)
      expect(described_class.for(declared, { dpi: 203 }).to_h).to include(dpi: 203, snap: true)
      expect(described_class.for(nil, { snap: true }).to_h).to include(dpi: 203, snap: true)
    end

    it "refuses anything else" do
      expect { described_class.for(nil, 203) }.to raise_error(ArgumentError, /monochrome: takes true, false or a Hash/)
    end
  end

  describe ".tone" do
    it "is the luma of a colour from 0 (black) to 1 (white), laid on white paper at its opacity" do
      expect(described_class.tone(Stationery::Color.parse("#000000"))).to eq(0)
      expect(described_class.tone(Stationery::Color.parse("#FFFFFF"))).to eq(1)
      expect(described_class.tone(Stationery::Color.parse("#888888"))).to be_within(0.001).of(0.533)
      expect(described_class.tone(Stationery::Color.parse("#6B7280"))).to be_within(0.001).of(0.445)
      expect(described_class.tone(Stationery::Color.parse([0, 0, 0, 100]))).to eq(0)
      expect(described_class.tone(Stationery::Color.parse("#000000"), 0.25)).to eq(0.75)
    end
  end

  describe ".hex" do
    it "names a colour as #RRGGBB" do
      expect(described_class.hex(Stationery::Color.parse("#ddd"))).to eq("#DDDDDD")
      expect(described_class.hex(Stationery::Color.parse([0, 0, 0, 100]))).to eq("#000000")
    end
  end
end
