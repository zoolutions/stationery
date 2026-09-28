# frozen_string_literal: true

require "zlib"

# Reads back what Document#to_zpl writes, independently of the writer: each
# label's ^PW, ^LL and ^PQ, and its ^GF graphic field decoded (Z64 or plain
# hex) to rows of dots, 1 for black as ZPL has them, with the field's byte
# counts and whether its Z64 CRC held.
module ZPLReader
  Label = Data.define(:width, :length, :copies, :total, :row_bytes, :rows, :crc_ok) do
    # 1 where the dot at (x, y) is black.
    def dot(x, y) = (rows[y].getbyte(x / 8) >> (7 - (x % 8))) & 1

    # The dots of the label as "0" and "1", row by row, cut at ^PW.
    def dots = rows.map { |row| row.unpack1("B*")[0, width] }
  end

  FIELD = /\^GFA,(\d+),(\d+),(\d+),(.*?)(?=\^FS|\^PQ|\^XZ)/m

  module_function

  def labels(zpl) = zpl.scan(/\^XA.*?\^XZ/m).map { |label| label(label) }

  def label(zpl)
    total, count, row_bytes, data = zpl.match(FIELD).captures
    raise "byte counts differ: #{total} and #{count}" unless total == count

    bytes, crc_ok = decode(data.strip)
    raise "#{bytes.bytesize} bytes for a field of #{total}" unless bytes.bytesize == total.to_i

    rows = Array.new(bytes.bytesize / row_bytes.to_i) { |y| bytes.byteslice(y * row_bytes.to_i, row_bytes.to_i) }
    Label.new(width: zpl[/\^PW(\d+)/, 1].to_i, length: zpl[/\^LL(\d+)/, 1].to_i, copies: zpl[/\^PQ(\d+)/, 1]&.to_i,
              total: total.to_i, row_bytes: row_bytes.to_i, rows:, crc_ok:)
  end

  def decode(data)
    return [[data.delete("\r\n")].pack("H*"), nil] unless data.start_with?(":Z64:")

    _, _, base64, crc = data.split(":")
    [Zlib::Inflate.inflate(base64.unpack1("m0")), crc == format("%04X", xmodem(base64))]
  end

  # CRC-16/XMODEM (polynomial 0x1021, initial value 0, no reflection) over
  # the Base64 text, written from the definition rather than taken from the gem.
  def xmodem(text)
    text.each_byte.reduce(0) do |crc, byte|
      crc ^= byte << 8
      8.times { crc = crc.anybits?(0x8000) ? ((crc << 1) ^ 0x1021) & 0xFFFF : (crc << 1) & 0xFFFF }
      crc
    end
  end

  # The dots of a one-bit PNG (to_png(monochrome: …)), "1" for black.
  def png_dots(png)
    Stationery::Images::PNG.new(png).pixels.color.map { |row| row.map { |v| v < 128 ? "1" : "0" }.join }
  end
end
