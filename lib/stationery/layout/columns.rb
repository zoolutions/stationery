# frozen_string_literal: true

module Stationery
  module Layout
    # One flow poured through `count` columns, newspaper style: column 1 top
    # to bottom, then column 2, and so on. (A Row is the other thing: columns
    # side by side, each with content of its own.) The flow is laid out at the
    # column width and cut where a page break would cut it, by Flow#split.
    #
    # `balance: true` ends the columns at nearly the same height wherever the
    # content ends: on the last page of the block and before a page break
    # inside it. A page the content does not fit on takes columns of the full
    # height left, and the rest continues on the next page. `balance: false`
    # fills each column before the next one starts.
    #
    # Below other content the block starts only when every column takes
    # something in the height left; otherwise it moves to the next page. On a
    # fresh page a child too tall for a column is kept and reported as an
    # Overflow. The block is as tall as its tallest column.
    class Columns < Node
      RULE = { width: 0.5, color: "#000000" }.freeze
      # The tallest page PDF allows (200 inches).
      MAX_HEIGHT = 14_400

      attr_reader :flow, :count, :gap

      # `rule:` draws a line between the columns: true, or { color:, width: }.
      def initialize(flow, count: 2, gap: 12, balance: true, rule: nil)
        super()
        @flow = flow
        @count = self.class.count_option(count)
        @gap = self.class.gap_option(gap)
        @balance = self.class.balance_option(balance)
        @rule = self.class.rule_option(rule)
        @fragments = {}
      end

      def self.count_option(value)
        return value if value.is_a?(Integer) && value >= 1

        raise ArgumentError, "count: must be an Integer of at least 1, got #{value.inspect}"
      end

      def self.gap_option(value)
        return value if value.is_a?(Numeric) && !value.negative?

        raise ArgumentError, "gap: must be a number of at least 0, got #{value.inspect}"
      end

      def self.balance_option(value)
        return value if [true, false].include?(value)

        raise ArgumentError, "balance: must be true or false, got #{value.inspect}"
      end

      def self.rule_option(value)
        case value
        when nil, false then nil
        when true then RULE
        when Hash then RULE.merge(value.slice(:width, :color))
        else raise ArgumentError, "rule: must be true or { color:, width: }, got #{value.inspect}"
        end
      end

      def splittable? = true
      def breaks? = @flow.breaks?
      def leading_break? = @flow.leading_break?
      def natural_width = (@flow.natural_width * @count) + gaps
      def min_width = (@flow.min_width * @count) + gaps

      def column_width(width) = [(width - gaps) / @count.to_f, 0].max

      # Content that cannot fit columns as tall as the tallest page is never
      # placed whole, so its height is estimated instead of balanced: a long
      # block is measured on every page it continues on.
      def measure(width)
        memoize_by_width(width) do
          single = @flow.measure(column_width(width))
          single > @count * MAX_HEIGHT ? single / @count : fragment(width).measure(width)
        end
      end

      def paint(canvas, x, y, width, height = nil, **)
        fragment(width).paint(canvas, x, y, width, height)
      end

      def split(width, height, fresh: false)
        return [self, nil] if !breaks? && measure(width) <= height + EPSILON

        segment, after = segments(column_width(width))
        pour = Pour.new(segment, column_width(width), @count)
        poured = pour.call(height, fresh:)
        return ended(pour, poured, height, after) if poured.complete?
        return [nil, self] if !fresh && poured.columns.size < @count

        continued(poured, after)
      end

      # The block as it is laid out with all the height it wants. Content a
      # pour cannot place (page breaks where nothing can break the page)
      # stays in one column.
      def fragment(width)
        @fragments[width] ||= begin
          pour = Pour.new(@flow, column_width(width), @count)
          poured = @balance ? Balancer.new(pour).call : pour.call(Float::INFINITY)
          placed(poured.complete? ? poured : Poured.new(columns: [@flow], rest: nil))
        end
      end

      private

      def gaps = @gap * (@count - 1)

      # [what comes before the first page break inside, what comes after it].
      def segments(width)
        return [@flow, nil] unless breaks?

        segment, after = @flow.split(width, Float::INFINITY, fresh: true)
        [segment || @flow.with_children([]), after]
      end

      # The content ends on this page: balanced, and whatever follows a page
      # break inside goes to the next page.
      def ended(pour, poured, height, after)
        poured = Balancer.new(pour, limit: height, fallback: poured).call if @balance
        [placed(poured), after && with_flow(after)]
      end

      # The page is full. A fresh page that placed nothing keeps the content
      # anyway, so that pagination always moves on.
      def continued(poured, after)
        return [placed(poured.with(columns: [poured.rest])), after && with_flow(after)] if poured.columns.empty?

        rest = after ? [*poured.rest.children, PageBreak.new, *after.children] : poured.rest.children
        [placed(poured), with_flow(@flow.with_children(rest))]
      end

      def placed(poured) = Fragment.new(poured.columns, count: @count, gap: @gap, rule: @rule)

      def with_flow(flow)
        self.class.new(flow, count: @count, gap: @gap, balance: @balance, rule: @rule).tap do |node|
          node.keep_with_next = keep_with_next
        end
      end
    end

    class Columns
      # Columns already poured: a flow per column, painted side by side in
      # reading order. Never splits.
      class Fragment < Node
        attr_reader :columns

        def initialize(columns, count:, gap:, rule: nil)
          super()
          @columns = columns
          @count = count
          @gap = gap
          @rule = rule
        end

        def column_width(width) = [(width - (@gap * (@count - 1))) / @count.to_f, 0].max

        def measure(width)
          memoize_by_width(width) { @columns.map { |column| column.measure(column_width(width)) }.max || 0 }
        end

        def paint(canvas, x, y, width, height = nil, **)
          own = column_width(width)
          @columns.each_with_index do |column, index|
            left = x + (index * (own + @gap))
            column.paint(canvas, left, y, own)
            canvas.debug_rect(left, y, own, column.measure(own), :column)
          end
          paint_rules(canvas, x, y, own, height || measure(width)) if @rule
        end

        private

        # A line in the middle of every gap between two columns with content.
        def paint_rules(canvas, x, y, own, height)
          canvas.artifact do
            (1...@columns.size).each do |index|
              at = x + (index * (own + @gap)) - (@gap / 2.0)
              canvas.line(at, y, at, y + height, color: @rule[:color], width: @rule[:width])
            end
          end
        end
      end
    end
  end
end
