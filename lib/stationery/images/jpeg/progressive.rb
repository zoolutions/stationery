# frozen_string_literal: true

module Stationery
  module Images
    class JPEG
      # The blocks of a progressive scan (jdphuff.c), added to the
      # coefficients a component keeps from `base`: the DC coefficient or a
      # band of AC coefficients (spectral selection `@start`..`@stop`), first at
      # `@low` bits short of full precision, then a bit at a time
      # (successive approximation, `@high` the bit position before). A run of
      # blocks with nothing left in the band is one end-of-band run.
      module Progressive
        private

        def progressive(c, base)
          if @start.zero?
            @high.zero? ? dc_first(c, base) : dc_refine(c, base)
          else
            @high.zero? ? ac_first(c, base) : ac_refine(c, base)
          end
        end

        def dc_first(c, base)
          size = @reader.symbol(c.dc)
          c.pred += @reader.signed(size) if size.positive?
          c.coefficients[base] = c.pred << @low
        end

        def dc_refine(c, base)
          c.coefficients[base] |= (1 << @low) if @reader.bit == 1
        end

        def ac_first(c, base)
          return @eobrun -= 1 if @eobrun.positive?

          coefficients = c.coefficients
          k = @start
          while k <= @stop
            rs = @reader.symbol(c.ac)
            run = rs >> 4
            size = rs & 15
            if size.positive?
              k += run
              coefficients[base + Decoder::ZIGZAG[k]] = @reader.signed(size) << @low
            elsif run == 15
              k += 15
            else
              @eobrun = (1 << run) - 1
              @eobrun += @reader.read(run) if run.positive?
              break
            end
            k += 1
          end
        end

        def ac_refine(c, base)
          coefficients = c.coefficients
          k = @start
          k = refine_band(c, coefficients, base) if @eobrun.zero?
          return unless @eobrun.positive?

          while k <= @stop
            at = base + Decoder::ZIGZAG[k]
            refine(coefficients, at) unless coefficients[at].zero?
            k += 1
          end
          @eobrun -= 1
        end

        # The symbols of a refinement scan until the band ends or an
        # end-of-band run starts; answers where it stopped.
        def refine_band(c, coefficients, base)
          k = @start
          while k <= @stop
            rs = @reader.symbol(c.ac)
            run = rs >> 4
            size = rs & 15
            if size.positive?
              value = @reader.bit == 1 ? 1 << @low : -1 << @low
            elsif run != 15
              @eobrun = 1 << run
              @eobrun += @reader.read(run) if run.positive?
              return k
            end
            # Past coefficients already set (each refined) and `run` zeros.
            while k <= @stop
              at = base + Decoder::ZIGZAG[k]
              if coefficients[at].zero?
                break if run.zero?

                run -= 1
              else
                refine(coefficients, at)
              end
              k += 1
            end
            coefficients[base + Decoder::ZIGZAG[k]] = value if size.positive? && k <= 63
            k += 1
          end
          k
        end

        # One correction bit for a coefficient already set: its magnitude
        # grows by the bit at `@low` when that bit comes as 1.
        def refine(coefficients, at)
          return unless @reader.bit == 1

          value = coefficients[at]
          bit = 1 << @low
          return unless value.nobits?(bit)

          coefficients[at] = value.negative? ? value - bit : value + bit
        end
      end
    end
  end
end
