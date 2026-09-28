# frozen_string_literal: true

module Stationery
  module Barcode
    # A QR Code (ISO/IEC 18004, model 2) of the data's bytes (UTF-8 for a
    # String, marked as UTF-8 with an ECI when it is not ASCII), in byte
    # mode, at the smallest version (1 to 40) that holds it at the error
    # correction `level:` (:l, :m, :q or :h: 7, 15, 25 or 30 % of the
    # symbol may be lost). The modules are laid out by QR::Matrix, which
    # also picks the mask; the quiet zone is 4 modules.
    class QR
      LEVELS = %i[l m q h].freeze
      # Error correction codewords a block, and blocks, by level and version.
      ECC_PER_BLOCK = {
        l: [7, 10, 15, 20, 26, 18, 20, 24, 30, 18, 20, 24, 26, 30, 22, 24, 28, 30, 28, 28, 28, 28, 30, 30, 26, 28, 30,
            30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30],
        m: [10, 16, 26, 18, 24, 16, 18, 22, 22, 26, 30, 22, 22, 24, 24, 28, 28, 26, 26, 26, 26, 28, 28, 28, 28, 28,
            28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28],
        q: [13, 22, 18, 26, 18, 24, 18, 22, 20, 24, 28, 26, 24, 20, 30, 24, 28, 28, 26, 30, 28, 30, 30, 30, 30, 28,
            30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30],
        h: [17, 28, 22, 16, 22, 28, 26, 26, 24, 28, 24, 28, 22, 24, 24, 30, 28, 28, 26, 28, 30, 24, 30, 30, 30, 30,
            30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30]
      }.freeze
      BLOCKS = {
        l: [1, 1, 1, 1, 1, 2, 2, 2, 2, 4, 4, 4, 4, 4, 6, 6, 6, 6, 7, 8, 8, 9, 9, 10, 12, 12, 12, 13, 14, 15, 16, 17, 18,
            19, 19, 20, 21, 22, 24, 25],
        m: [1, 1, 1, 2, 2, 4, 4, 4, 5, 5, 5, 8, 9, 9, 10, 10, 11, 13, 14, 16, 17, 17, 18, 20, 21, 23, 25, 26, 28, 29,
            31, 33, 35, 37, 38, 40, 43, 45, 47, 49],
        q: [1, 1, 2, 2, 4, 4, 6, 6, 8, 8, 8, 10, 12, 16, 12, 17, 16, 18, 21, 20, 23, 23, 25, 27, 29, 34, 34, 35, 38,
            40, 43, 45, 48, 51, 53, 56, 59, 62, 65, 68],
        h: [1, 1, 2, 4, 4, 4, 5, 6, 8, 8, 11, 11, 16, 16, 18, 16, 19, 21, 25, 25, 25, 34, 30, 32, 35, 37, 40, 42, 45,
            48, 51, 54, 57, 60, 63, 66, 70, 74, 77, 81]
      }.freeze
      QUIET = 4
      PADS = [0xEC, 0x11].freeze
      # An ECI segment naming UTF-8 (assignment 26), before text that is not ASCII.
      ECI_UTF8 = "011100011010"

      attr_reader :data, :level, :version, :matrix

      # The data codewords of `version` at `level`.
      def self.capacity(version, level)
        (Matrix.raw_modules(version) / 8) - (ECC_PER_BLOCK.fetch(level)[version - 1] * BLOCKS.fetch(level)[version - 1])
      end

      # The bytes byte mode holds at `version` and `level`: 4 bits of mode
      # and 8 or 16 of length come first, and 12 of ECI with `eci:`.
      def self.bytes(version, level, eci: false)
        ((capacity(version, level) * 8) - 4 - (version < 10 ? 8 : 16) - (eci ? 12 : 0)) / 8
      end

      def initialize(data, level: :m)
        raise ArgumentError, "a QR code's level: is :l, :m, :q or :h, not #{level.inspect}" unless
          LEVELS.include?(level)

        @data = data.to_s
        @level = level
        bytes = @data.b
        raise ArgumentError, "a QR code needs data" if bytes.empty?

        @eci = !bytes.ascii_only? && @data.encoding == Encoding::UTF_8
        @version = (1..40).find { |version| bytes.bytesize <= self.class.bytes(version, level, eci: @eci) } or
          raise ArgumentError, "#{bytes.bytesize} bytes are more than a QR code holds at level #{level.inspect}"
        @matrix = Matrix.new(@version, level, codewords(bytes))
      end

      def linear? = false
      # Whether a printer's ^BQ draws the same data: not UTF-8 text, which
      # this symbol marks with an ECI (26) that ^BQ has no field for.
      def native? = !@eci
      # Dots ^BQ draws the symbol below its ^FO (as Labelary renders it,
      # at any magnification and resolution).
      def zpl_top = 10
      def quiet = QUIET
      def size = @matrix.size

      # The dark modules, row by row, true for dark.
      def modules = @matrix.modules

      # ^BQ in manual byte mode, so the printer encodes the bytes as they
      # are, at this level and so this version (its mask may differ).
      def zpl(module_dots:, height_dots: nil) # rubocop:disable Lint/UnusedMethodArgument
        bytes = @data.b
        "^BQN,2,#{module_dots}#{Barcode.field("#{@level.upcase}M,B#{format("%04d", bytes.bytesize)}#{bytes}")}"
      end

      private

      def codewords(bytes)
        bits = [(@eci ? ECI_UTF8 : ""), "0100", bytes.bytesize.to_s(2).rjust(@version < 10 ? 8 : 16, "0"),
                bytes.unpack1("B*")].join
        capacity = self.class.capacity(@version, @level)
        bits << ("0" * [4, (capacity * 8) - bits.size].min)
        bits << ("0" * (-bits.size % 8))
        data = [bits].pack("B*").bytes
        data << PADS[(data.size - (bits.size / 8)) % 2] while data.size < capacity
        interleave(data)
      end

      # The data split into blocks, each followed by its error correction,
      # read a codeword from each block in turn.
      def interleave(data)
        count = BLOCKS.fetch(@level)[@version - 1]
        ecc = ECC_PER_BLOCK.fetch(@level)[@version - 1]
        raw = Matrix.raw_modules(@version) / 8
        short = count - (raw % count)
        short_length = (raw / count) - ecc
        offset = 0
        blocks = Array.new(count) do |index|
          length = short_length + (index < short ? 0 : 1)
          block = data[offset, length]
          offset += length
          [block, ReedSolomon::QR.remainder(block, ecc)]
        end
        (0..short_length).flat_map { |i| blocks.filter_map { |block, _| block[i] } } +
          (0...ecc).flat_map { |i| blocks.map { |_, check| check[i] } }
      end
    end
  end
end
