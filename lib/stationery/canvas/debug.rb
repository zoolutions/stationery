# frozen_string_literal: true

module Stationery
  class Canvas
    # Layout outlines for `to_pdf(debug: true)`: a thin stroke around each
    # layout rectangle, coloured by what drew it. `debug:` is true (every
    # kind) or an Array of kinds.
    module Debug
      DEBUG_COLORS = {
        box: "#E11D48", padding: "#E11D48", column: "#2563EB", cell: "#16A34A", cell_padding: "#16A34A",
        flow: "#9CA3AF", positioned: "#DB2777", image: "#0D9488", page: "#06B6D4", region: "#0EA5E9"
      }.freeze
      DEBUG_DASHES = { padding: [2, 2], cell_padding: [2, 2], flow: [1, 2] }.freeze

      def debug? = @debug == true || (@debug.is_a?(Array) && @debug.any?)

      def debug_rect(x, y, w, h, kind)
        return unless @debug == true || (@debug.is_a?(Array) && @debug.include?(kind))

        color = DEBUG_COLORS.fetch(kind) { raise ArgumentError, "unknown debug kind: #{kind.inspect}" }
        rounded_rect(x + 0.25, y + 0.25, w - 0.5, h - 0.5, radius: 0, stroke: color, line_width: 0.5,
                                                           dash: DEBUG_DASHES[kind])
      end
    end
  end
end
