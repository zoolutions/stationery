# frozen_string_literal: true

module Stationery
  module Images
    class JPEG
      # The inverse DCT of a block of dequantised coefficients (64 Integers
      # in natural order) into a plane of samples (a binary String, `stride`
      # bytes to a row), in integer arithmetic as libjpeg's accurate
      # "islow" transform (jidctint.c), so a sample comes out as libjpeg's
      # does. Reduced sizes (jidctred.c, ReducedIDCT) read only the low
      # coefficients and write a 4 × 4, 2 × 2 or 1 × 1 block: the image at a
      # half, a quarter or an eighth of its size, for a fraction of the work.
      # Kept in local variables and flat loops: this runs for every block.
      module IDCT
        CONST_BITS = 13
        PASS1_BITS = 2
        # A sample of the transform (centred on zero) as 0..255, indexed by
        # its low ten bits as libjpeg's range limit is: -512..511, values
        # beyond (only corrupt data makes them) wrapping round.
        CLAMP = Array.new(1024) { |i| ((i < 512 ? i : i - 1024) + 128).clamp(0, 255) }.freeze
        # A run of 1, 2, 4 or 8 samples of each value, for flat rows.
        RUNS = [1, 2, 4, 8].to_h { |n| [n, Array.new(256) { |v| (v.chr * n).b.freeze }.freeze] }.freeze

        module_function

        # One block of DC only (`first`, every other coefficient zero): `size`
        # samples square, all of one value.
        def flat(first, plane, offset, stride, size)
          value = CLAMP[((first + 4) >> 3) & 1023]
          return plane.setbyte(offset, value) if size == 1

          row = RUNS[size][value]
          size.times { |y| plane.bytesplice(offset + (y * stride), size, row) }
        end

        def call(c, work, plane, offset, stride)
          columns(c, work)
          rows(work, plane, offset, stride)
        end

        # Pass 1 of jpeg_idct_islow: each column into the workspace, scaled
        # up by PASS1_BITS.
        def columns(c, work)
          i = 0
          while i < 8
            c1 = c[8 + i]
            c2 = c[16 + i]
            c3 = c[24 + i]
            c4 = c[32 + i]
            c5 = c[40 + i]
            c6 = c[48 + i]
            c7 = c[56 + i]
            if c1.zero? && c2.zero? && c3.zero? && c4.zero? && c5.zero? && c6.zero? && c7.zero?
              dc = c[i] << PASS1_BITS
              work[i] = work[8 + i] = work[16 + i] = work[24 + i] = dc
              work[32 + i] = work[40 + i] = work[48 + i] = work[56 + i] = dc
              i += 1
              next
            end

            z1 = (c2 + c6) * 4433
            t2 = z1 - (c6 * 15_137)
            t3 = z1 + (c2 * 6270)
            t0 = (c[i] + c4) << CONST_BITS
            t1 = (c[i] - c4) << CONST_BITS
            t10 = t0 + t3 + 1024
            t13 = t0 - t3 + 1024
            t11 = t1 + t2 + 1024
            t12 = t1 - t2 + 1024

            # The odd part, from inputs 7, 5, 3 and 1.
            z5 = (c7 + c5 + c3 + c1) * 9633
            z1 = (c7 + c1) * -7373
            z2 = (c5 + c3) * -20_995
            z3 = ((c7 + c3) * -16_069) + z5
            z4 = ((c5 + c1) * -3196) + z5
            o0 = (c7 * 2446) + z1 + z3
            o1 = (c5 * 16_819) + z2 + z4
            o2 = (c3 * 25_172) + z2 + z3
            o3 = (c1 * 12_299) + z1 + z4

            work[i] = (t10 + o3) >> 11
            work[56 + i] = (t10 - o3) >> 11
            work[8 + i] = (t11 + o2) >> 11
            work[48 + i] = (t11 - o2) >> 11
            work[16 + i] = (t12 + o1) >> 11
            work[40 + i] = (t12 - o1) >> 11
            work[24 + i] = (t13 + o0) >> 11
            work[32 + i] = (t13 - o0) >> 11
            i += 1
          end
        end

        # Pass 2: each row of the workspace into eight samples.
        def rows(work, plane, offset, stride)
          r = 0
          while r < 64
            w1 = work[r + 1]
            w2 = work[r + 2]
            w3 = work[r + 3]
            w4 = work[r + 4]
            w5 = work[r + 5]
            w6 = work[r + 6]
            w7 = work[r + 7]
            at = offset + ((r >> 3) * stride)
            if w1.zero? && w2.zero? && w3.zero? && w4.zero? && w5.zero? && w6.zero? && w7.zero?
              plane.bytesplice(at, 8, RUNS[8][CLAMP[((work[r] + 16) >> 5) & 1023]])
              r += 8
              next
            end

            z1 = (w2 + w6) * 4433
            t2 = z1 - (w6 * 15_137)
            t3 = z1 + (w2 * 6270)
            t0 = (work[r] + w4) << CONST_BITS
            t1 = (work[r] - w4) << CONST_BITS
            t10 = t0 + t3 + 131_072
            t13 = t0 - t3 + 131_072
            t11 = t1 + t2 + 131_072
            t12 = t1 - t2 + 131_072

            z5 = (w7 + w5 + w3 + w1) * 9633
            z1 = (w7 + w1) * -7373
            z2 = (w5 + w3) * -20_995
            z3 = ((w7 + w3) * -16_069) + z5
            z4 = ((w5 + w1) * -3196) + z5
            o0 = (w7 * 2446) + z1 + z3
            o1 = (w5 * 16_819) + z2 + z4
            o2 = (w3 * 25_172) + z2 + z3
            o3 = (w1 * 12_299) + z1 + z4

            plane.setbyte(at, CLAMP[((t10 + o3) >> 18) & 1023])
            plane.setbyte(at + 7, CLAMP[((t10 - o3) >> 18) & 1023])
            plane.setbyte(at + 1, CLAMP[((t11 + o2) >> 18) & 1023])
            plane.setbyte(at + 6, CLAMP[((t11 - o2) >> 18) & 1023])
            plane.setbyte(at + 2, CLAMP[((t12 + o1) >> 18) & 1023])
            plane.setbyte(at + 5, CLAMP[((t12 - o1) >> 18) & 1023])
            plane.setbyte(at + 3, CLAMP[((t13 + o0) >> 18) & 1023])
            plane.setbyte(at + 4, CLAMP[((t13 - o0) >> 18) & 1023])
            r += 8
          end
        end
      end
    end
  end
end
