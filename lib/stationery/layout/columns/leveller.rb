# frozen_string_literal: true

module Stationery
  module Layout
    class Columns
      # Fills balanced columns evenly. Columns filled in order at the balanced
      # height leave the last one what is left over: ten lines in three
      # columns are 4, 4 and 2. Here the first column keeps what fits the
      # height, what it leaves is balanced through the columns after it, and
      # so on down to the last two: 4, 3 and 3. What cannot be shared goes to
      # the earlier columns.
      #
      # Every column is cut by Flow#split from what the one before it left,
      # so the result is a pour like any other and the break rules hold in
      # it. Fitting is not monotonic in the height, so nothing is assumed of
      # that pour: the columns filled in order are kept unless it places
      # everything, is exactly as tall as they are (what follows the block
      # stays where it is), and has no later column taller than an earlier
      # one where they have none. They are also kept when their first column
      # cannot be cut again below other content (a child too tall for the
      # page).
      #
      # Each level is one Balancer search with a column less, so levelling
      # pours at most (count - 2) * (MAX_PROBES + 1) times and cuts a first
      # column count - 2 times. Two columns are even as they are: the second
      # takes what the first left.
      class Leveller
        # `limit` is the tallest a column may be.
        def initialize(pour, limit: Float::INFINITY)
          @pour = pour
          @limit = limit
        end

        # `poured` is the balanced pour: the columns filled in order.
        def call(poured)
          return poured unless poured.complete? && @pour.count > 2

          height = [@limit, poured.height(@pour.width)].min
          first, rest = @pour.first(height)
          return poured unless first && rest

          levelled = after(first, rest, height)
          better?(levelled, poured) ? levelled : poured
        end

        private

        def after(first, rest, height)
          poured = self.class.new(rest, limit: height).call(Balancer.new(rest, limit: height).call)
          Poured.new(columns: [first, *poured.columns], rest: poured.rest)
        end

        def better?(levelled, poured)
          levelled.complete? && (levelled.height(@pour.width) - poured.height(@pour.width)).abs <= EPSILON &&
            (descending?(levelled) || !descending?(poured))
        end

        def descending?(poured)
          heights = poured.columns.map { |column| column.measure(@pour.width) }
          heights.each_cons(2).all? { |taller, shorter| shorter <= taller + EPSILON }
        end
      end
    end
  end
end
