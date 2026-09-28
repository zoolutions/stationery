# frozen_string_literal: true

RSpec.describe Stationery::ZPL do
  # From a print file ZebraDesigner wrote (BinaryKits/BinaryKits.Zpl discussion
  # #161): a 16-byte-wide field of 1536 bytes, and the CRC Zebra's own software
  # put after it.
  let(:zebra_designer) do
    "eJztk71OwzAQx89EkYdKNRsLqhnZWDtUTYbyBjD3FRgZimypD4LEyEvUfQMG2DMiJg9Fiqo05uz4EpcFZoSlOvrpenf/" \
      "+zDAb86iPMIT95EiU869JDxyz5t9wupzce3MwC3+RNUj3/kYh56F9vd8cA/Jl32AOtwZBWC2+9SRyTCNLKOjijw5SgPw" \
      "QDLMsV/W2RmqW7K73MQ8gOHnmUX9ltIzJ62s4L5zM5C1si6qGAjDcqcOroJVxxrEu1u3VKEAKLaONyg08Bh5Xfv2jDv5" \
      "qJzvpCU7ym95JUzwxHMOrBHWF8kDz7AToip0yNRxI43qC5xBVgtT9AV6Tu1Tz3qwr4AHf1Ym9h/8Mb4e/DF/pQzZ515v" \
      "oi/Rr/v6rNQ0oFB/4+sX1B+F/bFpf9L+oZesQn8n1H95UG+ujP1HVVm7qR3NB+fF3GOjbJwfw85vQoJ+vrDcNtzS/HHP" \
      "TvQlXNCedWHhlPaHFpf2S5ZAQjtB+vh/POZpIn/f77j/Z4a40MMdAvsAyfvJfIBR3TNTr5Cr5IGK9umqHRBy59wuYXzA" \
      "e51yfnsD/+dPni9Wt7Uh"
  end

  describe ".crc" do
    it "is the CRC-16 Zebra's software writes after a Z64 field: over the Base64 text, 4 hex digits" do
      expect(described_class.crc(zebra_designer)).to eq("BD69")
    end

    it "agrees with a second, independent writer (BinaryKits.Zpl's unit spec)" do
      expect(described_class.crc("eNr7/x8GGhj+/2cAYUZsLCjNAFKJjQUDAOLDM1I=")).to eq("8F39")
    end

    it "is the CRC-16/XMODEM check value for \"123456789\"" do
      expect(described_class.crc("123456789")).to eq("31C3")
    end
  end

  describe ".graphic_field" do
    # Two rows of 10 dots, 1 for white as a raster has them: the first row
    # black from the third dot, the second white but its last dot.
    let(:bits) { [0b1100_0000, 0b0011_1111, 0b1111_1111, 0b1011_1111].pack("C*") }

    it "writes the dots 1 for black, with the padding past the width left white" do
      field = described_class.graphic_field(bits, width: 10, height: 2, compression: :hex)

      expect(field).to eq("^GFA,4,4,2,3FC00040")
    end

    it "writes Z64: zlib, Base64 and the CRC of the Base64" do
      field = described_class.graphic_field(bits, width: 10, height: 2, compression: :z64)
      base64 = field[/:Z64:(.*):/, 1]

      expect(field).to start_with("^GFA,4,4,2,:Z64:")
      expect(Zlib::Inflate.inflate(base64.unpack1("m0"))).to eq(["3FC00040"].pack("H*"))
      expect(field).to end_with(":#{described_class.crc(base64)}")
    end
  end

  describe ".check_dpi" do
    it "takes the resolutions ZPL printers have and refuses others, naming them" do
      expect([152, 203, 300, 600].map { |dpi| described_class.check_dpi(dpi) }).to eq([152, 203, 300, 600])
      expect { described_class.check_dpi(200) }.to raise_error(ArgumentError, /152, 203, 300 or 600/)
    end
  end
end
