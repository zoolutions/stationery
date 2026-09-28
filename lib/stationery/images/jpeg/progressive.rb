# frozen_string_literal: true

module Stationery
  module Images
    class JPEG
      # The blocks of a progressive scan (jdphuff.c), added to the
      # coefficients a component keeps from `base`, in zig-zag order (a band
      # is then a run of the Array): the DC coefficient or a
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
          c.coefficients[base] = c.pred * (1 << @low)
        end

        def dc_refine(c, base)
          c.coefficients[base] |= (1 << @low) if @reader.bit == 1
        end

        def ac_first(c, base)
          return @eobrun -= 1 if @eobrun.positive?

          coefficients = c.coefficients
          reader = @reader
          table = c.ac
          unit = 1 << @low
          k = @start
          while k <= @stop
            rs = reader.symbol(table)
            run = rs >> 4
            size = rs & 15
            if size.positive?
              k += run
              coefficients[base + k] = reader.signed(size) * unit if k < 64
            elsif run == 15
              k += 15
            else
              @eobrun = (1 << run) - 1
              @eobrun += reader.read(run) if run.positive?
              break
            end
            k += 1
          end
        end

        def ac_refine(c, base)
          k = @eobrun.zero? ? refine_band(c, base) : @start
          return unless @eobrun.positive?

          refine_rest(c.coefficients, base + k, base + @stop)
          @eobrun -= 1
        end

        # The symbols of a refinement scan until the band ends or an
        # end-of-band run starts; answers where it stopped.
        def refine_band(c, base)
          coefficients = c.coefficients
          reader = @reader
          unit = 1 << @low
          stop = base + @stop
          at = base + @start
          while at <= stop
            rs = reader.symbol(c.ac)
            run = rs >> 4
            size = rs & 15
            if size.positive?
              value = reader.bit == 1 ? unit : -unit
            elsif run != 15
              @eobrun = 1 << run
              @eobrun += reader.read(run) if run.positive?
              return at - base
            end
            at = skip(coefficients, at, stop, run, unit)
            coefficients[at] = value if size.positive? && at <= stop
            at += 1
          end
          at - base
        end

        # Past the coefficients already set (each refined) and `run` zeros:
        # where the next zero is, the place of a new coefficient.
        def skip(coefficients, at, stop, run, unit)
          reader = @reader
          while at <= stop
            coefficient = coefficients[at]
            if coefficient.zero?
              return at if run.zero?

              run -= 1
            elsif reader.bit == 1 && coefficient.nobits?(unit)
              coefficients[at] = coefficient.negative? ? coefficient - unit : coefficient + unit
            end
            at += 1
          end
          at
        end

        # One correction bit for each coefficient already set from `at` to
        # `stop`: its magnitude grows by the bit at `@low` when that bit is 1.
        def refine_rest(coefficients, at, stop)
          reader = @reader
          unit = 1 << @low
          while at <= stop
            coefficient = coefficients[at]
            if !coefficient.zero? && reader.bit == 1 && coefficient.nobits?(unit)
              coefficients[at] = coefficient.negative? ? coefficient - unit : coefficient + unit
            end
            at += 1
          end
        end
      end
    end
  end
end
