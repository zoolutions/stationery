# frozen_string_literal: true

module Stationery
  module Text
    class Wrapper
      # One run of one word that fits the line, which is what most cells of a
      # table hold: a line of one fragment, made without taking the text
      # apart. Text that may break anywhere (a space, a hyphen, a newline, a
      # soft hyphen, a zero-width space, a CJK character), that a line would
      # trim, or that is wider than the line, is wrapped as any other.
      module OneWord
        BREAKABLE = /[\s\0\-­​]/

        private

        # The lines of `runs`, or nil when they are not one word that fits.
        def one_word(runs, max_width)
          return unless runs.size == 1

          run = runs.first
          text = run.text
          return if text.empty? || text.match?(BREAKABLE) || Breaks.cjk?(text)

          width = measure(text, run.style)
          return unless width <= max_width + EPSILON

          font, face = @book.resolve(run.style)
          [Line.new([Fragment.new(text, run.style, font, face, width, 0)], fallback_metrics)]
        end
      end
    end
  end
end
