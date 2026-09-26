# frozen_string_literal: true

require "zlib"

# Builds small PNGs byte by byte so every colour type, bit depth, filter and
# transparency mode the decoder handles has a fixture whose pixels are known.
module PngFactory
  SIGNATURE = "\x89PNG\r\n\x1A\n".b

  module_function

  # rows: Array of rows, each an Array of samples (already packed per channel,
  # e.g. [r, g, b, r, g, b] for 8-bit RGB). For bit depths below 8 pass
  # already-packed bytes and set packed: true.
  def build(width:, height:, color_type:, rows:, bit_depth: 8, filter: 0, palette: nil, trns: nil, packed: false)
    ihdr = [width, height, bit_depth, color_type, 0, 0, 0].pack("NNCCCCC")
    raw = rows.map do |row|
      bytes = if packed
        row
      else
        (bit_depth == 16) ? row.pack("n*").bytes : row
      end
      [filter, *apply_filter(filter, bytes, bpp(color_type, bit_depth))].pack("C*")
    end.join

    png = SIGNATURE.dup
    png << chunk("IHDR", ihdr)
    png << chunk("PLTE", palette.flatten.pack("C*")) if palette
    png << chunk("tRNS", trns) if trns
    png << chunk("IDAT", Zlib::Deflate.deflate(raw))
    png << chunk("IEND", "")
  end

  def chunk(type, data)
    data = data.b
    [data.bytesize].pack("N") + type.b + data + [Zlib.crc32(type + data)].pack("N")
  end

  def bpp(color_type, bit_depth)
    channels = { 0 => 1, 2 => 3, 3 => 1, 4 => 2, 6 => 4 }.fetch(color_type)
    [(channels * bit_depth) / 8, 1].max
  end

  # Encodes a row with a PNG filter against a zero previous row (single-row
  # semantics are enough for the decoder specs: filters 2-4 then exercise
  # their "previous row is zero" and left-neighbour paths).
  def apply_filter(filter, bytes, bpp)
    case filter
    when 0, 2 then bytes
    when 1 then bytes.each_with_index.map { |v, i| (v - (i >= bpp ? bytes[i - bpp] : 0)) & 0xFF }
    when 3 then bytes.each_with_index.map { |v, i| (v - ((i >= bpp ? bytes[i - bpp] : 0) >> 1)) & 0xFF }
    when 4 then bytes.each_with_index.map { |v, i| (v - (i >= bpp ? bytes[i - bpp] : 0)) & 0xFF }
    else raise ArgumentError, "unknown filter #{filter}"
    end
  end
end
