# frozen_string_literal: true

module Stationery
  module Forms
    # Helvetica's advance widths (the standard-14 AFM, in 1/1000 em) for the
    # printable ASCII range, enough to lay out the appearance of a field made
    # without a font book (see Standard); other WinAnsi characters count as a
    # digit's width.
    module Metrics
      ASCII = [
        278, 278, 355, 556, 556, 889, 667, 191, 333, 333, 389, 584, 278, 333, 278, 278, # space - /
        556, 556, 556, 556, 556, 556, 556, 556, 556, 556, 278, 278, 584, 584, 584, 556, # 0 - ?
        1015, 667, 667, 722, 722, 667, 611, 778, 722, 278, 500, 667, 556, 833, 722, 778, # @ - O
        667, 778, 722, 667, 611, 722, 667, 944, 667, 667, 611, 278, 278, 278, 469, 556, # P - _
        333, 556, 556, 500, 556, 556, 278, 556, 556, 222, 222, 500, 222, 833, 556, 556, # ` - o
        556, 556, 333, 500, 278, 556, 500, 722, 500, 500, 500, 334, 260, 334, 584 # p - ~
      ].freeze
      DEFAULT = 556
      ASCENT = 0.718
      DESCENT = -0.207

      module_function

      # WinAnsi bytes for an appearance stream; unmappable characters become "?".
      def encode(text)
        text.to_s.encode(Encoding::Windows_1252, invalid: :replace, undef: :replace).b
      end

      # The width of WinAnsi `bytes` at `size`.
      def width(bytes, size)
        bytes.each_byte.sum { |byte| (byte in 32..126) ? ASCII[byte - 32] : DEFAULT } * size / 1000.0
      end
    end
  end
end
