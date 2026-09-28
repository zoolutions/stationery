# frozen_string_literal: true

module Stationery
  module Barcode
    class DataMatrix
      # The ECC 200 placement of ISO/IEC 16022 annex F: codewords laid on a
      # mapping matrix of `count` × `count` modules along diagonal strokes,
      # eight modules each (the "utah" shape), with the four corner shapes
      # where a stroke meets the edge, and the fixed pattern in the corner
      # left over.
      class Placement
        UTAH = [[-2, -2], [-2, -1], [-1, -2], [-1, -1], [-1, 0], [0, -2], [0, -1], [0, 0]].freeze

        attr_reader :grid

        def initialize(count, codewords)
          @rows = @cols = count
          @codewords = codewords
          @grid = Array.new(count) { Array.new(count) }
          place
          @grid.each { |row| row.map! { |cell| cell == true } }
        end

        private

        def place
          chr = 0
          row = 4
          col = 0
          loop do
            chr = corners(row, col, chr)
            loop do
              chr = utah(row, col, chr) if row < @rows && col >= 0 && @grid[row][col].nil?
              row -= 2
              col += 2
              break unless row >= 0 && col < @cols
            end
            row += 1
            col += 3
            loop do
              chr = utah(row, col, chr) if row >= 0 && col < @cols && @grid[row][col].nil?
              row += 2
              col -= 2
              break unless row < @rows && col >= 0
            end
            row += 3
            col += 1
            break unless row < @rows || col < @cols
          end
          fill_corner
        end

        def corners(row, col, chr)
          shape = col.zero? ? left_corner(row) : (corner4 if col == 2 && row == @rows + 4 && (@cols % 8).zero?)
          return chr unless shape

          shape.each_with_index { |(r, c), bit| put(r, c, chr, bit) }
          chr + 1
        end

        def left_corner(row)
          if row == @rows then corner1
          elsif row == @rows - 2 && (@cols % 4).positive? then corner2
          elsif row == @rows - 2 && @cols % 8 == 4 then corner3
          end
        end

        def corner1
          [[@rows - 1, 0], [@rows - 1, 1], [@rows - 1, 2], [0, @cols - 2], [0, @cols - 1], [1, @cols - 1],
           [2, @cols - 1], [3, @cols - 1]]
        end

        def corner2
          [[@rows - 3, 0], [@rows - 2, 0], [@rows - 1, 0], [0, @cols - 4], [0, @cols - 3], [0, @cols - 2],
           [0, @cols - 1], [1, @cols - 1]]
        end

        def corner3
          [[@rows - 3, 0], [@rows - 2, 0], [@rows - 1, 0], [0, @cols - 2], [0, @cols - 1], [1, @cols - 1],
           [2, @cols - 1], [3, @cols - 1]]
        end

        def corner4
          [[@rows - 1, 0], [@rows - 1, @cols - 1], [0, @cols - 3], [0, @cols - 2], [0, @cols - 1], [1, @cols - 3],
           [1, @cols - 2], [1, @cols - 1]]
        end

        def utah(row, col, chr)
          UTAH.each_with_index { |(dr, dc), bit| put(row + dr, col + dc, chr, bit) }
          chr + 1
        end

        # Bit `bit` (0 the most significant) of codeword `chr` at (row, col),
        # wrapped around the edges as the annex wraps them.
        def put(row, col, chr, bit)
          if row.negative?
            row += @rows
            col += 4 - ((@rows + 4) % 8)
          end
          if col.negative?
            col += @cols
            row += 4 - ((@cols + 4) % 8)
          end
          codeword = @codewords[chr] || 0
          @grid[row][col] = codeword[7 - bit] == 1
        end

        # The bottom right corner, when no codeword reached it.
        def fill_corner
          return unless @grid[@rows - 1][@cols - 1].nil?

          @grid[@rows - 1][@cols - 1] = @grid[@rows - 2][@cols - 2] = true
          @grid[@rows - 1][@cols - 2] = @grid[@rows - 2][@cols - 1] = false
        end
      end
    end
  end
end
