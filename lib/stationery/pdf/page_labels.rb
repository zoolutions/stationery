# frozen_string_literal: true

module Stationery
  module PDF
    # The /PageLabels number tree: how viewers name pages ("i", "ii", "1",
    # "A-1"). A spec maps a 1-based first page to the range starting there:
    #
    #   { 1 => { style: :roman_lower }, 3 => { style: :decimal, start: 1, prefix: "A-" } }
    #
    # Styles are :decimal, :roman, :roman_lower, :alpha, :alpha_lower or nil
    # (prefix only). Pages before the first range have no label; viewers show
    # their physical number.
    module PageLabels
      STYLES = { decimal: :D, roman: :R, roman_lower: :r, alpha: :A, alpha_lower: :a }.freeze
      NUMERALS = { D: :decimal, R: :upper_roman, r: :roman, A: :upper_alpha, a: :alpha }.freeze
      KEYS = %i[style start prefix].freeze

      module_function

      # The number tree dictionary for a spec, or nil for none.
      def entries(spec)
        return if spec.nil? || spec.empty?

        nums = spec.sort_by { |page, _| validate_page(page) }.flat_map do |page, range|
          [page - 1, entry(page, range)]
        end
        { Nums: nums }
      end

      # The label of each of `count` pages from a /Nums array (as read back).
      def labels(nums, count)
        ranges = nums.each_slice(2).to_a
        Array.new(count) do |index|
          start, dict = ranges.reverse.find { |from, _| from <= index }
          dict && label(dict, index - start)
        end
      end

      def validate_page(page)
        return page if page.is_a?(Integer) && page >= 1

        raise ArgumentError, "page labels start at page 1, not page #{page.inspect}"
      end

      def entry(page, range)
        unknown = range.keys - KEYS
        raise ArgumentError, "unknown page label option #{unknown.first.inspect} for page #{page}" if unknown.any?

        style = range[:style]
        raise ArgumentError, "unknown page label style #{style.inspect}" unless style.nil? || STYLES.key?(style)

        start = range[:start]
        if start && !(start.is_a?(Integer) && start >= 1)
          raise ArgumentError, "page label start #{start.inspect} for page #{page} must be 1 or more"
        end

        entry = {}
        entry[:S] = STYLES[style] if style
        entry[:St] = start if start
        entry[:P] = TextString.new(range[:prefix].to_s) if range[:prefix]
        entry
      end

      def label(dict, offset)
        numeral = NUMERALS[dict[:S]&.to_sym]
        number = (dict[:St] || 1) + offset
        "#{dict[:P]}#{ListMarkers.numeral(numeral, number) if numeral}"
      end
    end
  end
end
