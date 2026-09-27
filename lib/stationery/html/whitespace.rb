# frozen_string_literal: true

module Stationery
  module HTML
    # Collapses the whitespace of one block's inlines as CSS `white-space: normal` does: runs become one
    # space, the block's (and each line's) leading and trailing space goes, and U+00A0 is left alone.
    # A trailing line break after content draws no empty line, so it is dropped too.
    module Whitespace
      RUN = /[ \t\n\r\f]+/

      module_function

      def collapse(inlines)
        collapsed = trim_trailing(trim_leading(inlines))
        collapsed.pop if collapsed.last&.break? && collapsed[..-2].any? { |i| i.break? || !i.text.empty? }
        collapsed
      end

      def trim_leading(inlines)
        space = true
        inlines.map do |inline|
          next inline.tap { space = true } if inline.break?

          text = inline.text.gsub(RUN, " ")
          text = text.delete_prefix(" ") if space
          space = text.end_with?(" ") unless text.empty?
          inline.with(text:)
        end
      end

      def trim_trailing(inlines)
        space = true
        inlines.reverse_each.map do |inline|
          next inline.tap { space = true } if inline.break?

          text = space ? inline.text.delete_suffix(" ") : inline.text
          space = false unless text.empty?
          inline.with(text:)
        end.reverse
      end
    end
  end
end
