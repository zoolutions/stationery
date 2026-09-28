# frozen_string_literal: true

module Stationery
  module Text
    # A measured piece of one line in one style, positioned at `x` from the
    # line's start.
    Fragment = Data.define(:text, :style, :font, :face, :width, :x)

    # One laid-out line. Vertical metrics come from its tallest fragment (or
    # from the paragraph's base style when the line is empty). A soft-wrapped
    # line is justifiable; the last line and one ended by a newline are not.
    # Beside a float it starts `offset` points into the paragraph and has
    # `available` points of width; anywhere else that is 0 and nil, the
    # paragraph's own width.
    class Line
      attr_reader :fragments, :width, :ascent, :descent, :height, :offset, :available

      def initialize(fragments, fallback, justifiable: false, offset: 0, available: nil)
        @fragments = fragments
        @justifiable = justifiable
        @offset = offset
        @available = available
        @width = fragments.sum(&:width)
        metrics = fragments.empty? ? [fallback] : fragments.map { |f| [f.font, f.style.render_size] }
        @ascent = metrics.map { |font, size| font.ascender(size) }.max
        @descent = metrics.map { |font, size| font.descender(size) }.max
        @height = metrics.map { |font, size| font.line_height(size) }.max
      end

      def text = fragments.map(&:text).join
      def justifiable? = @justifiable

      # U+0020 spaces only: justification stretches those, never tabs.
      def space_count = fragments.sum { |fragment| fragment.text.count(" ") }
    end
  end
end
