# frozen_string_literal: true

module Stationery
  module Barcode
    # A Data Matrix symbol (ISO/IEC 16022, ECC 200) of the data's bytes in
    # ASCII encodation (a character a codeword, two digits in one, a byte
    # above 127 after an upper shift), in the smallest of the 24 square
    # sizes from 10 × 10 to 144 × 144 that holds it. The codewords are laid
    # out by the placement of the standard's annex F, in data regions each
    # framed by its finder (solid left and bottom) and clock track
    # (alternating top and right). The quiet zone is 1 module.
    class DataMatrix
      # Symbol size => [data codewords, error correction codewords, data
      # regions across, modules across a region, interleaved blocks].
      SIZES = {
        10 => [3, 5, 1, 8, 1], 12 => [5, 7, 1, 10, 1], 14 => [8, 10, 1, 12, 1], 16 => [12, 12, 1, 14, 1],
        18 => [18, 14, 1, 16, 1], 20 => [22, 18, 1, 18, 1], 22 => [30, 20, 1, 20, 1], 24 => [36, 24, 1, 22, 1],
        26 => [44, 28, 1, 24, 1], 32 => [62, 36, 2, 14, 1], 36 => [86, 42, 2, 16, 1], 40 => [114, 48, 2, 18, 1],
        44 => [144, 56, 2, 20, 1], 48 => [174, 68, 2, 22, 1], 52 => [204, 84, 2, 24, 2], 64 => [280, 112, 4, 14, 2],
        72 => [368, 144, 4, 16, 4], 80 => [456, 192, 4, 18, 4], 88 => [576, 224, 4, 20, 4],
        96 => [696, 272, 4, 22, 4], 104 => [816, 336, 4, 24, 6], 120 => [1050, 408, 6, 18, 6],
        132 => [1304, 496, 6, 20, 8], 144 => [1558, 620, 6, 22, 10]
      }.freeze
      PAD = 129
      UPPER_SHIFT = 235
      QUIET = 1
      # The escape character ^BX is given: data holding it is left to the picture.
      ZPL_ESCAPE = "_"

      attr_reader :data, :size, :data_codewords, :codewords, :modules

      # ASCII encodation of `data`'s bytes.
      def self.codewords(data)
        data.to_s.b.scan(/\d\d|./mn).flat_map do |chunk|
          next [130 + chunk.to_i] if chunk.size == 2

          byte = chunk.ord
          byte < 128 ? [byte + 1] : [UPPER_SHIFT, byte - 127]
        end
      end

      def initialize(data)
        @data = data.to_s
        raise ArgumentError, "a Data Matrix needs data" if @data.empty?

        encoded = self.class.codewords(@data)
        @size, (capacity, ecc, regions, region, blocks) = SIZES.find { |_, spec| encoded.size <= spec[0] }
        raise ArgumentError, "#{encoded.size} codewords are more than a Data Matrix holds (1558)" unless @size

        @data_codewords = padded(encoded, capacity)
        @codewords = @data_codewords + check(@data_codewords, ecc, blocks)
        @modules = frame(place(regions * region), region)
      end

      def linear? = false
      def quiet = QUIET
      def native? = !@data.include?(ZPL_ESCAPE)
      def zpl_top = 0

      # ^BX at this size, so the printer draws as many modules.
      def zpl(module_dots:, height_dots: nil) # rubocop:disable Lint/UnusedMethodArgument
        "^BXN,#{module_dots},200,#{@size},#{@size},6,#{ZPL_ESCAPE},1#{Barcode.field(@data)}"
      end

      private

      # The first pad is 129, the others scrambled by their position (the
      # 253-state algorithm, annex B.1.2).
      def padded(encoded, capacity)
        result = encoded.dup
        result << PAD if result.size < capacity
        while result.size < capacity
          value = PAD + ((149 * (result.size + 1)) % 253) + 1
          result << (value > 254 ? value - 254 : value)
        end
        result
      end

      # The error correction of each block (the data taken a codeword to a
      # block in turn), interleaved the same way.
      def check(data, ecc, blocks)
        per_block = ecc / blocks
        checks = Array.new(blocks) do |block|
          ReedSolomon::DATA_MATRIX.remainder(data.select.with_index { |_, i| i % blocks == block }, per_block)
        end
        (0...per_block).flat_map { |i| checks.map { |block| block[i] } }
      end

      # The mapping matrix (the data regions without their frames) of
      # `count` modules across, true for dark.
      def place(count)
        Placement.new(count, @codewords).grid
      end

      def frame(grid, region)
        step = region + 2
        Array.new(@size) do |y|
          Array.new(@size) do |x|
            ry, dy = y.divmod(step)
            rx, dx = x.divmod(step)
            if dx.zero? || dy == step - 1 then true
            elsif dy.zero? then dx.even?
            elsif dx == step - 1 then dy.odd?
            else grid[(ry * region) + dy - 1][(rx * region) + dx - 1]
            end
          end
        end
      end
    end
  end
end
