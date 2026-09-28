# frozen_string_literal: true

module Stationery
  module Rich
    # How the html and markdown elements style each kind of block. Heading
    # `scale:` multiplies the current text size; a `size:` in points wins.
    module Styles
      HEADING_SCALES = [2.0, 1.6, 1.3, 1.1, 1.0, 0.9].freeze

      DEFAULTS = {
        **HEADING_SCALES.each_with_index.to_h do |scale, index|
          [:"h#{index + 1}", { scale:, weight: :bold, keep_with_next: true }]
        end,
        p: {},
        a: { color: "#2563EB", underline: true },
        code: { font: nil },
        pre: { background: "#F3F4F6", padding: 8, radius: 4 },
        blockquote: { border: { sides: [:left], width: 3, color: "#E5E7EB" }, padding: [0, 0, 0, 10] },
        hr: { height: 1, color: "#E5E7EB" },
        table: { cell: { padding: 4 }, header: { weight: :bold } },
        ul: {},
        ol: {},
        li: {},
        img: { max_width: nil, float_margin: 8 }
      }.freeze

      module_function

      def resolve(overrides) = merge(DEFAULTS, overrides)

      def merge(base, overrides)
        base.merge(overrides) { |_, old, new| old.is_a?(Hash) && new.is_a?(Hash) ? merge(old, new) : new }
      end
    end
  end
end
