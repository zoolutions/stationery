# frozen_string_literal: true

require "zlib"

module Stationery
  # ZPL II, the language of Zebra label printers and of most others that
  # emulate it (Document#to_zpl). A label is the page rasterised one bit to a
  # dot (see Raster::Render) and written as one graphic field:
  #
  #   ^XA^PW812^LL1218^LH0,0^FO0,0^GFA,<bytes>,<bytes>,<bytes a row>,:Z64:<data>:<CRC>^FS^PQ1^XZ
  #
  # `^PW` and `^LL` are the page's width and length in dots, `^PQ` the copies.
  # The field's dots are 1 for black, its rows padded to a byte with white.
  # Z64 is the rows deflated with zlib, in Base64, followed by the CRC-16
  # Zebra's software writes: CRC-16/XMODEM (polynomial 0x1021, starting at 0)
  # over the Base64 text, as four upper-case hex digits. `compression: :hex`
  # writes the rows as plain hex instead, for printers that do not take Z64.
  module ZPL
    # The resolutions of ZPL printers: 6, 8, 12 and 24 dots a millimetre.
    DPIS = [152, 203, 300, 600].freeze
    COMPRESSIONS = %i[z64 hex].freeze
    # The four bits of a hex digit, turned over (0 for 1).
    HEX = "0123456789abcdef"
    INVERTED = "fedcba9876543210"
    # CRC-16/XMODEM of each byte, a byte at a time.
    CRC_TABLE = Array.new(256) do |byte|
      crc = byte << 8
      8.times { crc = crc.anybits?(0x8000) ? ((crc << 1) ^ 0x1021) & 0xFFFF : (crc << 1) & 0xFFFF }
      crc
    end.freeze

    module_function

    def check_dpi(dpi)
      return dpi if DPIS.include?(dpi)

      raise ArgumentError, "dpi: is the resolution of a ZPL printer, 152, 203, 300 or 600, not #{dpi.inspect}"
    end

    def check_compression(compression)
      return compression if COMPRESSIONS.include?(compression)

      raise ArgumentError, "compression: is :z64 or :hex, not #{compression.inspect}"
    end

    # One label: `bits` are the rows of a Raster::Render (1 for white).
    def label(bits, width:, height:, copies:, compression:)
      "^XA^PW#{width}^LL#{height}^LH0,0^FO0,0#{graphic_field(bits, width:, height:, compression:)}" \
        "^FS^PQ#{copies}^XZ\n"
    end

    # The ^GF command for `bits`, rows of `width` dots packed eight to a
    # byte, most significant bit first, 1 for white.
    def graphic_field(bits, width:, height:, compression:)
      stride = (width + 7) / 8
      data = ink(bits, width, height, stride)
      total = stride * height
      "^GFA,#{total},#{total},#{stride},#{compression == :hex ? data.unpack1("H*").upcase : z64(data)}"
    end

    def z64(data)
      base64 = [Zlib::Deflate.deflate(data)].pack("m0")
      ":Z64:#{base64}:#{crc(base64)}"
    end

    # CRC-16/XMODEM of `text`, as four upper-case hex digits.
    def crc(text)
      crc = 0
      text.each_byte { |byte| crc = ((crc << 8) & 0xFFFF) ^ CRC_TABLE[(crc >> 8) ^ byte] }
      format("%04X", crc)
    end

    # The rows 1 for black, the bits past `width` in each row's last byte
    # cleared, so the padding prints white.
    def ink(bits, width, height, stride)
      data = [bits.unpack1("H*").tr(HEX, INVERTED)].pack("H*")
      return data if (width % 8).zero?

      mask = (0xFF << (8 - (width % 8))) & 0xFF
      height.times do |y|
        last = (y * stride) + stride - 1
        data.setbyte(last, data.getbyte(last) & mask)
      end
      data
    end
  end
end
