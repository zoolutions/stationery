# frozen_string_literal: true

# Builds lossless WebP files bit by bit, for what an encoder never writes:
# every predictor mode side by side, and each way a bitstream can be wrong.
module WebpFactory
  # The lengths of the code that code lengths are written with: complete
  # over all 19 symbols, so any list of lengths can be spelled out.
  LENGTH_CODE = (Array.new(13, 4) + Array.new(6, 5)).freeze
  LENGTH_ORDER = [17, 18, 0, 1, 2, 3, 4, 5, 16, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15].freeze
  # Extra bits of the repeat codes 16, 17 and 18.
  REPEAT_BITS = [2, 3, 7].freeze

  # A VP8L bitstream under construction, least significant bit first.
  class Bits
    def initialize
      @bits = []
    end

    def write(value, count)
      count.times { |i| @bits << ((value >> i) & 1) }
      self
    end

    # A prefix code word, which goes most significant bit first.
    def word(value, length)
      (length - 1).downto(0) { |i| @bits << ((value >> i) & 1) }
      self
    end

    def header(width, height, alpha: false, version: 0, signature: 0x2F)
      write(signature, 8).write(width - 1, 14).write(height - 1, 14).write(alpha ? 1 : 0, 1).write(version, 3)
    end

    # A simple code of one symbol, which then takes no bits to write.
    def single(symbol)
      write(1, 1).write(0, 1).write(1, 1).write(symbol, 8)
    end

    # A simple code of two symbols, written as the bits 0 and 1.
    def pair(first, second)
      write(1, 1).write(1, 1).write(1, 1).write(first, 8).write(second, 8)
    end

    # A normal code with these lengths, one per symbol of the alphabet;
    # `steps` replaces the plain list of lengths with [symbol, extra bits]
    # pairs to use the repeat codes. Returns the words to write symbols with.
    def code(lengths, steps: lengths.zip, limit: nil)
      write(0, 1).write(LENGTH_ORDER.size - 4, 4)
      LENGTH_ORDER.each { |symbol| write(LENGTH_CODE[symbol], 3) }
      limit ? write(1, 1).write(7, 3).write(limit - 2, 16) : write(0, 1)
      words = WebpFactory.words(LENGTH_CODE)
      steps.each do |symbol, extra|
        word(*words[symbol])
        write(extra, REPEAT_BITS[symbol - 16]) if extra
      end
      WebpFactory.words(lengths)
    end

    # Any byte as an 8-bit word: the code literals are written with here.
    def bytes(size = 256)
      code(Array.new(size) { |symbol| symbol < 256 ? 8 : 0 })
    end

    def to_s = @bits.each_slice(8).map { |byte| byte.each_with_index.sum { |bit, i| bit << i } }.pack("C*")
  end

  module_function

  # Canonical code words as { symbol => [word, length] }.
  def words(lengths)
    word = 0
    (1..15).each_with_object({}) do |length, words|
      lengths.each_with_index do |candidate, symbol|
        next unless candidate == length

        words[symbol] = [word, length]
        word += 1
      end
      word <<= 1
    end
  end

  def chunk(type, payload)
    "#{type.b}#{[payload.bytesize].pack("V")}#{payload.b}#{"\0" if payload.bytesize.odd?}"
  end

  def riff(*chunks)
    body = "WEBP#{chunks.join}"
    "RIFF#{[body.bytesize].pack("V")}#{body}".b
  end

  # A file around the bitstream the block writes after the header.
  def build(width:, height:, alpha: false, **)
    bits = Bits.new.header(width, height, alpha:, **)
    yield bits
    riff(chunk("VP8L", bits.to_s))
  end

  # An image of literal pixels ([alpha, red, green, blue] each) behind the
  # transforms the block writes.
  def literal(width:, height:, pixels:, alpha: true)
    build(width:, height:, alpha:) do |bits|
      yield bits if block_given?
      bits.write(0, 1) # no more transforms
      image(bits, pixels, top: true)
    end
  end

  def image(bits, pixels, top: false)
    bits.write(0, 1) # no colour cache
    bits.write(0, 1) if top # no entropy image
    green = bits.bytes(280)
    red = bits.bytes
    blue = bits.bytes
    alpha = bits.bytes
    bits.single(0)
    pixels.each do |a, r, g, b|
      bits.word(*green[g]).word(*red[r]).word(*blue[b]).word(*alpha[a])
    end
  end
end
