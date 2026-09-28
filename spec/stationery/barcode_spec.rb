# frozen_string_literal: true

# The symbols were also decoded with zbarimg (ZBar 0.23) from pictures of
# them: every Code 128 and EAN-13 here, and QR codes filled to capacity at
# versions 1 to 40 and every level. The specs pin what was decoded.
RSpec.describe Stationery::Barcode do
  describe Stationery::Barcode::Code128 do
    def codes(data) = described_class.new(data).codes

    it "has 107 patterns of 11 modules, and a stop of 13" do
      widths = described_class::PATTERNS.map { |pattern| pattern.chars.sum(&:to_i) }

      expect(widths.first(106).uniq).to eq([11])
      expect(widths.last).to eq(13)
    end

    it "encodes digits two to a symbol in code set C, with the checksum and the stop" do
      expect(codes("12345678")).to eq([105, 12, 34, 56, 78, 47, 106])
    end

    it "stays in code set B for a short run of digits, and switches to C for four at the end" do
      expect(codes("AB12")).to eq([104, 33, 34, 17, 18, 19, 106])
      expect(codes("AB123456")).to eq([104, 33, 34, 99, 12, 34, 56, 26, 106])
    end

    it "encodes the odd digit of a run in code set B" do
      expect(codes("1234567")).to eq([105, 12, 34, 56, 100, 23, 44, 106])
    end

    it "answers its bars, and the ^BC command naming the same code sets" do
      symbol = described_class.new("SX00427719")

      expect(symbol.bars.first).to eq([0, 2])
      expect(symbol.bars.sum(&:last) + symbol.bars.size).to be < symbol.width
      expect(symbol.width).to eq((symbol.codes.size * 11) + 2)
      expect(symbol.zpl(module_dots: 3, height_dots: 100)).to eq("^BY3^BCN,100,N,N,N,N^FD>:SX>500427719^FS")
      expect(described_class.new("a>b").zpl(module_dots: 2, height_dots: 50)).to include("^FD>:a><b^FS")
    end

    it "refuses what is not printable ASCII" do
      expect { described_class.new("Grüße") }.to raise_error(ArgumentError, /printable ASCII.*"ü"/)
      expect { described_class.new("") }.to raise_error(ArgumentError, /needs data/)
    end
  end

  describe Stationery::Barcode::EAN13 do
    it "adds the check digit to twelve, and checks thirteen" do
      expect(described_class.new("400638133393").data).to eq("4006381333931")
      expect(described_class.new("4006381333931").data).to eq("4006381333931")
      expect { described_class.new("4006381333932") }.to raise_error(ArgumentError, /check digit .* is 1/)
      expect { described_class.new("12345") }.to raise_error(ArgumentError, /12 or 13 digits/)
    end

    it "is 95 modules between guards, its parity set by the first digit" do
      bars = described_class.new("590123412345").bars

      expect(bars.first(2)).to eq([[0, 1], [2, 1]])
      expect(bars.last).to eq([94, 1])
      expect(bars.last.sum).to eq(95)
    end

    it "writes ^BE with the twelve digits, the printer adding the check digit" do
      expect(described_class.new("400638133393").zpl(module_dots: 2, height_dots: 80))
        .to eq("^BY2^BEN,80,N,N^FD400638133393^FS")
    end
  end

  describe Stationery::Barcode::QR do
    it "holds as many bytes at each version and level as ISO/IEC 18004 table 7 says" do
      expect(%i[l m q h].map { |level| described_class.bytes(1, level) }).to eq([17, 14, 11, 7])
      expect(described_class.bytes(10, :m)).to eq(213)
      expect(described_class.bytes(40, :l)).to eq(2953)
      expect(described_class.bytes(40, :h)).to eq(1273)
    end

    it "takes the smallest version that holds the data" do
      expect(described_class.new("a" * 14).version).to eq(1)
      expect(described_class.new("a" * 15).version).to eq(2)
      expect(described_class.new("a" * 2331, level: :m).version).to eq(40)
      expect { described_class.new("a" * 2332, level: :m) }.to raise_error(ArgumentError, /more than a QR code holds/)
    end

    it "lays out a version 1 symbol as ZBar reads it" do
      symbol = described_class.new("stationery", level: :q)

      expect(symbol.modules.map { |row| row.map { |dark| dark ? 1 : 0 }.join }).to eq(
        %w[111111101000001111111 100000101100101000001 101110101010001011101 101110101001001011101
           101110101011001011101 100000100100101000001 111111101010101111111 000000001100100000000
           011010110100001011111 010110011110100110001 010110110110111110111 010100010010100110001
           101000101100110100001 000000001001110111001 111111101111000111111 100000100001000010011
           101110101111010101000 101110100111011110010 101110101111011110101 100000101101110000010
           111111100001001000011]
      )
    end

    it "writes the format information of ISO/IEC 18004 table C.1" do
      format = lambda do |level, mask|
        matrix = described_class.new("x", level:).matrix
        matrix.send(:format_cells, mask).first(15).map { |_, _, dark| dark ? 1 : 0 }.join.reverse
      end

      expect(format.call(:m, 0)).to eq("101010000010010")
      expect(format.call(:l, 0)).to eq("111011111000100")
      expect(format.call(:q, 0)).to eq("011010101011111")
      expect(format.call(:h, 0)).to eq("001011010001001")
    end

    it "places alignment patterns where the standard's table E.1 does" do
      expect(described_class::Matrix.alignment(2)).to eq([6, 18])
      expect(described_class::Matrix.alignment(7)).to eq([6, 22, 38])
      expect(described_class::Matrix.alignment(32)).to eq([6, 34, 60, 86, 112, 138])
      expect(described_class::Matrix.alignment(40)).to eq([6, 30, 58, 86, 114, 142, 170])
    end

    it "marks text that is not ASCII as UTF-8, and leaves such a code to the picture in ZPL" do
      expect(described_class.new("Grüße").native?).to be(false)
      expect(described_class.new("plain").native?).to be(true)
    end

    it "writes ^BQ in manual byte mode, at its level" do
      expect(described_class.new("https://example.com/p/42").zpl(module_dots: 6))
        .to eq("^BQN,2,6^FDMM,B0024https://example.com/p/42^FS")
    end
  end

  describe ".build" do
    it "makes the symbol of a type, and refuses others" do
      expect(described_class.build(:qr, "x", level: :h).level).to eq(:h)
      expect { described_class.build(:pdf417, "x") }.to raise_error(ArgumentError, /:code128, :ean13 or :qr/)
      expect { described_class.build(:code128, "x", level: :h) }.to raise_error(ArgumentError, /level: is for a QR/)
    end
  end

  describe ".field" do
    it "escapes what ZPL would read as a command with ^FH" do
      expect(described_class.field("plain")).to eq("^FDplain^FS")
      expect(described_class.field("a^b~c\\d")).to eq("^FH\\^FDa\\5Eb\\7Ec\\5Cd^FS")
    end
  end
end
