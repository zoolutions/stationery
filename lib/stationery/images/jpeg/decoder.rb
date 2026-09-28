# frozen_string_literal: true

module Stationery
  module Images
    class JPEG
      # Decodes a baseline, extended or progressive Huffman-coded JPEG of 8-bit
      # samples to its components' sample planes, at `scale` (1, 2, 4 or 8:
      # the image at that fraction of its size, through a reduced IDCT). Reads
      # the tables, the frame and the restart interval as they come, and each
      # scan with a Scan; a progressive image keeps its coefficients until the
      # last scan and is transformed then.
      class Decoder
        # A component of the frame: its sampling factors, quantisation table,
        # blocks across and down (padded to whole MCUs), the samples a block
        # makes at the scale (`block` square), its samples (`plane`, `stride`
        # bytes to a row) and, while a progressive image is read, its
        # coefficients (64 per block).
        Component = Struct.new(:id, :h, :v, :tq, :blocks_wide, :blocks_high, :width, :height, :quant, :block,
                               :plane, :stride, :coefficients, :dc, :ac, :pred)
        # Natural (row by row) index of the coefficient at each zig-zag
        # position, padded with 63 for a corrupt run past the end.
        ZIGZAG = [0, 1, 8, 16, 9, 2, 3, 10, 17, 24, 32, 25, 18, 11, 4, 5, 12, 19, 26, 33, 40, 48, 41, 34, 27, 20,
                  13, 6, 7, 14, 21, 28, 35, 42, 49, 56, 57, 50, 43, 36, 29, 22, 15, 23, 30, 37, 44, 51, 58, 59, 52,
                  45, 38, 31, 39, 46, 53, 60, 61, 54, 47, 55, 62, 63, *Array.new(16, 63)].freeze
        SOF = { 0xC0 => :baseline, 0xC1 => :baseline, 0xC2 => :progressive }.freeze

        attr_reader :width, :height, :components, :adobe, :scale, :max_h, :max_v

        def initialize(data, scale)
          @data = data
          @scale = scale
          @quant = []
          @dc = []
          @ac = []
          @restart = 0
          @components = []
          @adobe = nil
        end

        def call
          pos = 2
          pos = segment(pos) while pos
          raise UnsupportedImage, "invalid JPEG image: no frame" unless @width

          finish if @progressive
          self
        end

        # The block at `col`, `row` of component `c` into its plane.
        def transform(c, block, workspace, col, row, last = 63)
          size = c.block
          offset = (row * size * c.stride) + (col * size)
          return IDCT.flat(block[0], c.plane, offset, c.stride, size) if last.zero? || size == 1

          case size
          when 8 then IDCT.call(block, workspace, c.plane, offset, c.stride)
          when 4 then IDCT.four(block, workspace, c.plane, offset, c.stride)
          else IDCT.two(block, workspace, c.plane, offset, c.stride)
          end
        end

        private

        # Reads the marker segment at `pos`; the position of the next one,
        # nil at the end of the image.
        def segment(pos)
          pos += 1 while @data.getbyte(pos) == 0xFF && @data.getbyte(pos + 1) == 0xFF
          return if pos + 4 > @data.bytesize
          raise UnsupportedImage, "invalid JPEG image: marker expected" unless @data.getbyte(pos) == 0xFF

          marker = @data.getbyte(pos + 1)
          return if marker == 0xD9

          length = @data.byteslice(pos + 2, 2).unpack1("n")
          body = pos + 4
          after = pos + 2 + length
          raise UnsupportedImage, "invalid JPEG image: segment cut short" if length < 2 || after > @data.bytesize

          case marker
          when 0xC4 then huffman(body, after)
          when 0xDB then quantisation(body, after)
          when 0xDD then @restart = @data.byteslice(body, 2).unpack1("n")
          when 0xEE then read_adobe(body)
          when 0xDA then return scan(body, after)
          else frame(marker, body) if (0xC0..0xCF).cover?(marker) && ![0xC4, 0xC8, 0xCC].include?(marker)
          end
          after
        end

        def huffman(pos, after)
          while pos < after
            kind = @data.getbyte(pos)
            counts = @data.byteslice(pos + 1, 16).bytes
            symbols = @data.byteslice(pos + 17, counts.sum).bytes
            ((kind >> 4).zero? ? @dc : @ac)[kind & 15] = Huffman.new(counts, symbols)
            pos += 17 + counts.sum
          end
        end

        # Tables in zig-zag order, kept in natural order.
        def quantisation(pos, after)
          while pos < after
            precision = @data.getbyte(pos) >> 4
            values = @data.byteslice(pos + 1, precision.zero? ? 64 : 128).unpack(precision.zero? ? "C64" : "n64")
            raise UnsupportedImage, "invalid JPEG image: bad quantisation table" if values.include?(nil)

            table = Array.new(64, 0)
            values.each_with_index { |value, k| table[ZIGZAG[k]] = value }
            @quant[@data.getbyte(pos) & 15] = table
            pos += precision.zero? ? 65 : 129
          end
        end

        # The colour transform of an Adobe APP14 segment: 0 none, 1 YCbCr,
        # 2 YCCK.
        def read_adobe(pos)
          @adobe = @data.getbyte(pos + 11) if @data.byteslice(pos, 5) == "Adobe"
        end

        def frame(marker, pos)
          mode = SOF[marker]
          precision, @height, @width, count = @data.byteslice(pos, 6).unpack("CnnC")
          raise UnsupportedImage, JPEG.unsupported_reason(marker, precision) unless mode && precision == 8
          raise UnsupportedImage, "invalid JPEG image: no size" if @width.zero? || @height.zero?

          @progressive = mode == :progressive
          @components = Array.new(count) do |i|
            id, sampling, tq = @data.byteslice(pos + 6 + (i * 3), 3).unpack("CCC")
            Component.new(id:, h: sampling >> 4, v: sampling & 15, tq:, pred: 0)
          end
          layout
        end

        # Blocks and planes of every component. A frame of one component has
        # one block to an MCU, whatever its sampling factors say.
        def layout
          @components.each { |c| c.h = c.v = 1 } if @components.size == 1
          check_sampling
          mcus_wide = (@width + (8 * @max_h) - 1) / (8 * @max_h)
          mcus_high = (@height + (8 * @max_v) - 1) / (8 * @max_v)
          @components.each { |c| place(c, mcus_wide * c.h, mcus_high * c.v) }
        end

        def place(c, blocks_wide, blocks_high)
          c.width = ((@width * c.h) + @max_h - 1) / @max_h
          c.height = ((@height * c.v) + @max_v - 1) / @max_v
          c.blocks_wide = blocks_wide
          c.blocks_high = blocks_high
          c.block = block_size(c)
          c.stride = blocks_wide * c.block
          c.plane = "\0".b * (c.stride * blocks_high * c.block)
          c.coefficients = Array.new(blocks_wide * blocks_high * 64, 0) if @progressive
        end

        # Sampling factors of 1 to 4, each dividing the largest (libjpeg decodes
        # no other).
        def check_sampling
          unless @components.any? && @components.all? { |c| c.h.between?(1, 4) && c.v.between?(1, 4) }
            raise UnsupportedImage, "invalid JPEG image: bad sampling factors"
          end

          @max_h = @components.map(&:h).max
          @max_v = @components.map(&:v).max
          return if @components.all? { |c| (@max_h % c.h).zero? && (@max_v % c.v).zero? }

          raise UnsupportedImage, "JPEG images with fractional chroma sampling are not decoded"
        end

        # Samples per block edge at the scale: 8 / scale, doubled for a
        # subsampled component while that still leaves it no larger than the
        # image (as libjpeg does, jdmaster.c), so chroma at half the width
        # and height decoded at half the size needs no upsampling.
        def block_size(c)
          least = 8 / @scale
          size = least
          size *= 2 while size < 8 && ((@max_h * least) % (c.h * size * 2)).zero? &&
                          ((@max_v * least) % (c.v * size * 2)).zero?
          size
        end

        # A scan: its header, then its entropy-coded data up to the next
        # marker that is not a restart. Returns where that marker is.
        def scan(pos, after)
          raise UnsupportedImage, "invalid JPEG image: scan before frame" unless @width

          count = @data.getbyte(pos)
          components = Array.new(count) do |i|
            id, tables = @data.byteslice(pos + 1 + (i * 2), 2).unpack("CC")
            component = @components.find { |c| c.id == id } or raise UnsupportedImage, "invalid JPEG image: bad scan"
            component.dc = @dc[tables >> 4]
            component.ac = @ac[tables & 15]
            component.quant ||= @quant[component.tq] or raise UnsupportedImage, "invalid JPEG image: no table"
            component
          end
          ss, se, approximation = @data.byteslice(pos + 1 + (count * 2), 3).unpack("CCC")
          check_scan(components, ss, se, approximation)
          stop = @data.index(Scan::MARKER, after) || @data.bytesize
          Scan.new(self, components, @restart, progressive: @progressive)
              .call(@data.byteslice(after, stop - after), ss, se, approximation >> 4, approximation & 15)
          stop
        end

        # A scan has the tables it decodes with and, when progressive, a band
        # of coefficients within the block: the DC coefficient alone, or AC
        # coefficients of one component.
        def check_scan(components, start, stop, approximation)
          valid = if @progressive
                    progressive_scan?(components, start, stop, approximation)
                  else
                    components.all? { |c| c.dc && c.ac }
                  end
          raise UnsupportedImage, "invalid JPEG image: bad scan" unless valid && components.size.between?(1, 4)
        end

        def progressive_scan?(components, start, stop, approximation)
          return false unless stop <= 63 && (approximation & 15) <= 13
          return stop.zero? && components.all? { |c| (approximation >> 4).positive? || c.dc } if start.zero?

          start <= stop && components.size == 1 && components.first.ac
        end

        # The coefficients a progressive image gathered, transformed.
        def finish
          block = Array.new(64, 0)
          workspace = Array.new(64, 0)
          @components.each do |c|
            # A component no scan reached (a file cut short) stays blank.
            quant = c.quant || @quant[c.tq] or next
            (c.blocks_high * c.blocks_wide).times do |index|
              base = index * 64
              64.times { |i| block[i] = c.coefficients[base + i] * quant[i] }
              transform(c, block, workspace, index % c.blocks_wide, index / c.blocks_wide)
            end
            c.coefficients = nil
          end
        end
      end
    end
  end
end
