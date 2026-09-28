# frozen_string_literal: true

module Stationery
  module Images
    class JPEG
      # One scan of a JPEG: its entropy-coded data decoded block by block, in
      # MCUs when it interleaves several components and row by row through
      # one component's blocks when it does not, starting over (bit reader,
      # DC predictions, end-of-band run) at each restart marker. A sequential
      # scan transforms each block as it is read (Decoder#transform); a
      # progressive one adds to the coefficients it keeps (Progressive).
      class Scan
        include Progressive

        # The marker that ends a scan's data: any but a stuffed zero byte, a
        # restart marker or a fill byte.
        MARKER = /\xFF[^\x00\xD0-\xD7\xFF]/n
        RESTART = /\xFF[\xD0-\xD7]/n
        STUFFED = "\xFF\x00".b
        ZIGZAG = Decoder::ZIGZAG

        def initialize(decoder, components, restart, progressive:)
          @decoder = decoder
          @components = components
          @restart = restart
          @progressive = progressive
          @reader = BitReader.new
          @block = Array.new(64, 0)
          @workspace = Array.new(64, 0)
          @eobrun = 0
        end

        def call(data, start, stop, high, low)
          @start = start
          @stop = stop
          @high = high
          @low = low
          @intervals = data.split(RESTART).each { |interval| interval.gsub!(STUFFED, "\xFF".b) }
          @interval = -1
          @components.size == 1 ? single(@components.first) : interleaved
        end

        private

        # The blocks of one component that hold image samples, row by row.
        def single(c)
          wide = (c.width + 7) / 8
          high = (c.height + 7) / 8
          (wide * high).times do |n|
            next_interval if restart?(n)
            block(c, n % wide, n / wide)
          end
        end

        def interleaved
          first = @components.first
          wide = first.blocks_wide / first.h
          (wide * (first.blocks_high / first.v)).times do |n|
            next_interval if restart?(n)
            mx = n % wide
            my = n / wide
            @components.each do |c|
              c.v.times { |y| c.h.times { |x| block(c, (mx * c.h) + x, (my * c.v) + y) } }
            end
          end
        end

        def restart?(mcu) = mcu.zero? || (@restart.positive? && (mcu % @restart).zero?)

        def next_interval
          @interval += 1
          @reader.start(@intervals[@interval] || "".b)
          @components.each { |c| c.pred = 0 }
          @eobrun = 0
        end

        def block(c, col, row)
          return progressive(c, ((row * c.blocks_wide) + col) * 64) if @progressive

          @block.fill(0)
          last = sequential(c, @block)
          @decoder.transform(c, @block, @workspace, col, row, last)
        end

        # A block of a sequential scan, dequantised into `block`; answers the
        # zig-zag position of its last coefficient (0 for DC alone).
        def sequential(c, block)
          reader = @reader
          quant = c.quant
          size = reader.symbol(c.dc)
          c.pred += reader.signed(size) if size.positive?
          block[0] = c.pred * quant[0]
          table = c.ac
          k = 1
          last = 0
          while k < 64
            rs = reader.symbol(table)
            size = rs & 15
            if size.zero?
              break unless rs == 0xF0

              k += 16
            else
              k += rs >> 4
              z = ZIGZAG[k]
              block[z] = reader.signed(size) * quant[z]
              last = k
              k += 1
            end
          end
          last
        end
      end
    end
  end
end
