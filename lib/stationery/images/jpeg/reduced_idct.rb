# frozen_string_literal: true

module Stationery
  module Images
    class JPEG
      module IDCT
        # The columns and rows a reduced transform reads.
        FOUR_COLUMNS = [0, 1, 2, 3, 5, 6, 7].freeze
        TWO_COLUMNS = [0, 1, 3, 5, 7].freeze
        TWO_ROWS = [0, 8].freeze

        module_function

        # jpeg_idct_4x4: the block at half its size, from its low
        # coefficients (column and row 4 are never read).
        def four(c, work, plane, offset, stride)
          FOUR_COLUMNS.each do |i|
            c1 = c[8 + i]
            c2 = c[16 + i]
            c3 = c[24 + i]
            c5 = c[40 + i]
            c6 = c[48 + i]
            c7 = c[56 + i]
            if c1.zero? && c2.zero? && c3.zero? && c5.zero? && c6.zero? && c7.zero?
              work[i] = work[8 + i] = work[16 + i] = work[24 + i] = c[i] * PASS1
              next
            end

            t0 = c[i] * (SCALE * 2)
            t2 = (c2 * 15_137) - (c6 * 6270)
            t10 = t0 + t2 + 2048
            t12 = t0 - t2 + 2048
            o0 = (c7 * -1730) + (c5 * 11_893) + (c3 * -17_799) + (c1 * 8697)
            o2 = (c7 * -4176) + (c5 * -4926) + (c3 * 7373) + (c1 * 20_995)
            work[i] = (t10 + o2) >> 12
            work[24 + i] = (t10 - o2) >> 12
            work[8 + i] = (t12 + o0) >> 12
            work[16 + i] = (t12 - o0) >> 12
          end
          r = 0
          while r < 32
            w1 = work[r + 1]
            w2 = work[r + 2]
            w3 = work[r + 3]
            w5 = work[r + 5]
            w6 = work[r + 6]
            w7 = work[r + 7]
            at = offset + ((r >> 3) * stride)
            if w1.zero? && w2.zero? && w3.zero? && w5.zero? && w6.zero? && w7.zero?
              plane.bytesplice(at, 4, RUNS[4][CLAMP[((work[r] + 16) >> 5) & 1023]])
              r += 8
              next
            end

            t0 = work[r] * (SCALE * 2)
            t2 = (w2 * 15_137) - (w6 * 6270)
            t10 = t0 + t2 + 262_144
            t12 = t0 - t2 + 262_144
            o0 = (w7 * -1730) + (w5 * 11_893) + (w3 * -17_799) + (w1 * 8697)
            o2 = (w7 * -4176) + (w5 * -4926) + (w3 * 7373) + (w1 * 20_995)
            plane.setbyte(at, CLAMP[((t10 + o2) >> 19) & 1023])
            plane.setbyte(at + 3, CLAMP[((t10 - o2) >> 19) & 1023])
            plane.setbyte(at + 1, CLAMP[((t12 + o0) >> 19) & 1023])
            plane.setbyte(at + 2, CLAMP[((t12 - o0) >> 19) & 1023])
            r += 8
          end
        end

        # jpeg_idct_2x2: the block at a quarter of its size.
        def two(c, work, plane, offset, stride)
          TWO_COLUMNS.each do |i|
            c1 = c[8 + i]
            c3 = c[24 + i]
            c5 = c[40 + i]
            c7 = c[56 + i]
            if c1.zero? && c3.zero? && c5.zero? && c7.zero?
              work[i] = work[8 + i] = c[i] * PASS1
              next
            end

            t10 = (c[i] * (SCALE * 4)) + 4096
            t0 = (c7 * -5906) + (c5 * 6967) + (c3 * -10_426) + (c1 * 29_692)
            work[i] = (t10 + t0) >> 13
            work[8 + i] = (t10 - t0) >> 13
          end
          TWO_ROWS.each do |r|
            at = offset + ((r >> 3) * stride)
            w1 = work[r + 1]
            w3 = work[r + 3]
            w5 = work[r + 5]
            w7 = work[r + 7]
            if w1.zero? && w3.zero? && w5.zero? && w7.zero?
              plane.bytesplice(at, 2, RUNS[2][CLAMP[((work[r] + 16) >> 5) & 1023]])
              next
            end

            t10 = (work[r] * (SCALE * 4)) + 524_288
            t0 = (w7 * -5906) + (w5 * 6967) + (w3 * -10_426) + (w1 * 29_692)
            plane.setbyte(at, CLAMP[((t10 + t0) >> 20) & 1023])
            plane.setbyte(at + 1, CLAMP[((t10 - t0) >> 20) & 1023])
          end
        end
      end
    end
  end
end
