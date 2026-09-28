# frozen_string_literal: true

module Stationery
  module Layout
    class Columns
      # Finds the shortest column height at which a pour places everything,
      # so the columns end at nearly the same height.
      #
      # The search runs between a height known to be too short and one known
      # to fit. It starts at the single-column height divided by the column
      # count (what perfectly divisible content needs) and, as the answer is
      # rarely more than a line or two above that, climbs from there in
      # doubling steps until a height fits, then halves the interval. A height
      # that fits is lowered to the tallest column it produced, which is a
      # real break position, so the result is never taller than its content.
      # Fitting is not strictly monotonic in the height (keep_with_next,
      # orphans and widows move content in steps), so the answer is the
      # shortest height found, within TOLERANCE points of the shortest there
      # is. The probe count is capped: the search ends whatever a split
      # returns.
      class Balancer
        TOLERANCE = 0.5
        MAX_PROBES = 40

        # `limit` is the tallest a column may be; `fallback` is the pour at
        # that height when the caller has it already.
        def initialize(pour, limit: Float::INFINITY, fallback: nil)
          @pour = pour
          @limit = limit
          @fallback = fallback
        end

        def call
          high = [@limit, @pour.total].min
          best = @fallback || @pour.call(high)
          return best unless best.complete? && @pour.count > 1

          search(best, [high, best.height(@pour.width)].min)
        end

        private

        def search(best, high)
          low = 0.0
          probe = @pour.total / @pour.count
          step = TOLERANCE
          MAX_PROBES.times do
            break if high - low <= TOLERANCE || probe >= high

            poured = @pour.call(probe)
            if poured.complete?
              best = poured
              high = [probe, poured.height(@pour.width)].min
              step = nil
            else
              low = probe
            end
            step *= 2 if step
            probe = [(low + high) / 2.0, step ? low + step : high].min
          end
          best
        end
      end
    end
  end
end
