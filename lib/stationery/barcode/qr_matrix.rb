# frozen_string_literal: true

module Stationery
  module Barcode
    class QR
      # The modules of a QR code: finder, timing and alignment patterns,
      # format and version information, then the codewords in the zigzag
      # order of ISO/IEC 18004 (7.7), masked with whichever of the eight
      # masks scores the least penalty (7.8.3).
      class Matrix
        FORMAT_LEVEL = { l: 1, m: 0, q: 3, h: 2 }.freeze
        MASKS = [
          ->(x, y) { (x + y).even? },
          ->(_x, y) { y.even? },
          ->(x, _y) { (x % 3).zero? },
          ->(x, y) { ((x + y) % 3).zero? },
          ->(x, y) { ((x / 3) + (y / 2)).even? },
          ->(x, y) { (((x * y) % 2) + ((x * y) % 3)).zero? },
          ->(x, y) { (((x * y) % 2) + ((x * y) % 3)).even? },
          ->(x, y) { (((x + y) % 2) + ((x * y) % 3)).even? }
        ].freeze

        attr_reader :size, :modules, :mask

        # Modules left for data once the patterns are drawn.
        def self.raw_modules(version)
          result = (((16 * version) + 128) * version) + 64
          return result if version < 2

          count = (version / 7) + 2
          result -= (((25 * count) - 10) * count) - 55
          version >= 7 ? result - 36 : result
        end

        # The centres of the alignment patterns, across and down alike.
        def self.alignment(version)
          return [] if version == 1

          count = (version / 7) + 2
          step = (((version * 8) + (count * 3) + 5) / ((count * 4) - 4)) * 2
          last = (version * 4) + 10
          [6, *(0...(count - 1)).map { |i| last - (i * step) }.reverse]
        end

        def initialize(version, level, codewords)
          @version = version
          @level = level
          @size = (version * 4) + 17
          @modules = Array.new(@size) { Array.new(@size, false) }
          @function = Array.new(@size) { Array.new(@size, false) }
          patterns
          place(codewords)
          @mask = (0...8).min_by { |mask| penalty(masked(mask)) }
          @modules = masked(@mask)
        end

        private

        def set(x, y, dark)
          @modules[y][x] = dark
          @function[y][x] = true
        end

        def patterns
          @size.times do |i|
            set(6, i, i.even?)
            set(i, 6, i.even?)
          end
          [[3, 3], [@size - 4, 3], [3, @size - 4]].each { |x, y| finder(x, y) }
          centres = self.class.alignment(@version)
          corners = [[6, 6], [6, centres.last], [centres.last, 6]]
          centres.product(centres).each do |x, y|
            next if corners.include?([x, y])

            (-2..2).each { |dy| (-2..2).each { |dx| set(x + dx, y + dy, [dx.abs, dy.abs].max != 1) } }
          end
          draw_format(0)
          draw_version if @version >= 7
        end

        def finder(cx, cy)
          (-4..4).each do |dy|
            (-4..4).each do |dx|
              x = cx + dx
              y = cy + dy
              ring = [dx.abs, dy.abs].max
              set(x, y, ring != 2 && ring != 4) if x.between?(0, @size - 1) && y.between?(0, @size - 1)
            end
          end
        end

        def draw_format(mask) = format_cells(mask).each { |x, y, dark| set(x, y, dark) }

        # [x, y, dark] of the format information for `mask`, both copies, and
        # the dark module beside the lower one.
        def format_cells(mask)
          data = (FORMAT_LEVEL.fetch(@level) << 3) | mask
          remainder = data
          10.times { remainder = (remainder << 1) ^ ((remainder >> 9) * 0x537) }
          bits = ((data << 10) | remainder) ^ 0x5412
          first = (0..5).map { |i| [8, i, i] } + [[8, 7, 6], [8, 8, 7], [7, 8, 8]] + (9..14).map { |i| [14 - i, 8, i] }
          second = (0..7).map { |i| [@size - 1 - i, 8, i] } + (8..14).map { |i| [8, @size - 15 + i, i] }
          (first + second).map { |x, y, i| [x, y, bits[i] == 1] } << [8, @size - 8, true]
        end

        def draw_version
          remainder = @version
          12.times { remainder = (remainder << 1) ^ ((remainder >> 11) * 0x1F25) }
          bits = (@version << 12) | remainder
          18.times do |i|
            a = @size - 11 + (i % 3)
            b = i / 3
            set(a, b, bits[i] == 1)
            set(b, a, bits[i] == 1)
          end
        end

        def place(codewords)
          i = 0
          total = codewords.size * 8
          right = @size - 1
          while right >= 1
            right = 5 if right == 6
            @size.times do |vertical|
              2.times do |j|
                x = right - j
                y = (right + 1).nobits?(2) ? @size - 1 - vertical : vertical
                next if @function[y][x] || i >= total

                @modules[y][x] = codewords[i >> 3][7 - (i & 7)] == 1
                i += 1
              end
            end
            right -= 2
          end
        end

        # The modules under `mask`, with the format information that names it.
        def masked(mask)
          rule = MASKS[mask]
          grid = @modules.each_with_index.map do |row, y|
            row.each_with_index.map { |dark, x| @function[y][x] ? dark : dark ^ rule.call(x, y) }
          end
          format_cells(mask).each { |x, y, dark| grid[y][x] = dark }
          grid
        end

        # The penalty of ISO/IEC 18004, 7.8.3: runs, 2 × 2 blocks, patterns
        # like a finder and the balance of dark and light.
        def penalty(grid)
          lines = grid + grid.transpose
          score = lines.sum { |line| runs(line) + finder_like(line) }
          (0...(@size - 1)).each do |y|
            (0...(@size - 1)).each do |x|
              dark = grid[y][x]
              score += 3 if grid[y][x + 1] == dark && grid[y + 1][x] == dark && grid[y + 1][x + 1] == dark
            end
          end
          dark = grid.sum { |row| row.count(true) }
          total = @size * @size
          score + ((((((dark * 20) - (total * 10)).abs + total - 1) / total) - 1) * 10)
        end

        def runs(line)
          line.chunk_while { |a, b| a == b }.sum { |run| run.size >= 5 ? run.size - 2 : 0 }
        end

        # Dark, light, dark three times as long, light, dark (1:1:3:1:1)
        # with four modules of light on one side and one on the other, the
        # light beyond the symbol counted as the quiet zone.
        def finder_like(line)
          lengths = line.chunk_while { |a, b| a == b }.map(&:size)
          lengths.unshift(0) if line.first
          lengths << 0 if line.last
          lengths[0] += @size
          lengths[-1] += @size
          (1...(lengths.size - 5)).step(2).sum do |i|
            n = lengths[i]
            next 0 unless lengths[i + 1] == n && lengths[i + 2] == n * 3 && lengths[i + 3] == n && lengths[i + 4] == n

            before = lengths[i - 1]
            after = lengths[i + 5]
            (before >= n * 4 && after >= n ? 40 : 0) + (after >= n * 4 && before >= n ? 40 : 0)
          end
        end
      end
    end
  end
end
