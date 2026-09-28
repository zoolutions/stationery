# frozen_string_literal: true

module Stationery
  module Markdown
    class InlineParser
      # CommonMark's delimiter-run emphasis, simplified: flanking rules and the `_` intraword restriction,
      # without the rule of three. `~` runs of equal length strike through (GFM).
      module Emphasis
        WHITESPACE = /[[:space:]]/
        PUNCTUATION = /[[:punct:]]|\p{S}/

        module_function

        def delimiter(run, before, after)
          left = !space?(after) && (!punct?(after) || space?(before) || punct?(before))
          right = !space?(before) && (!punct?(before) || space?(after) || punct?(after))
          if run.start_with?("_")
            Nodes::Delimiter.new("_", run.length, left && (!right || punct?(before)), right && (!left || punct?(after)))
          else
            Nodes::Delimiter.new(run[0], run.length, left, right)
          end
        end

        # Wraps matched delimiter pairs (and what lies between them) in place. `bottoms` remembers, per
        # kind of closer, the index below which no opener is left for it, so a run of closers that
        # nothing opens is not searched for again and again (CommonMark's openers_bottom).
        def process(nodes)
          bottoms = Hash.new(0)
          index = 0
          while index < nodes.size
            closer = nodes[index]
            next index += 1 unless closer?(closer)

            opening = opener_for(nodes, index, bottoms[kind(closer)])
            next index = wrap(nodes, opening, index, bottoms) if opening

            bottoms[kind(closer)] = index
            index += 1
          end
        end

        def wrap(nodes, opening, index, bottoms)
          opener = nodes[opening]
          closer = nodes[index]
          used = used(opener, closer)
          nodes[(opening + 1)...index] = [Nodes::Wrap.new(marks(closer.char, used), nodes[(opening + 1)...index])]
          bottoms.each { |kind, bottom| bottoms[kind] = opening + 1 if bottom > opening + 1 }
          opener.remaining -= used
          closer.remaining -= used
          index = opening + 2
          if opener.remaining.zero?
            nodes.delete_at(opening)
            index -= 1
          end
          nodes.delete_at(index) if closer.remaining.zero?
          index
        end

        def opener_for(nodes, index, bottom)
          closer = nodes[index]
          (index - 1).downto(bottom).find do |i|
            node = nodes[i]
            node.is_a?(Nodes::Delimiter) && node.opener && node.char == closer.char && node.remaining.positive? &&
              (closer.char != "~" || node.remaining == closer.remaining)
          end
        end

        def closer?(node) = node.is_a?(Nodes::Delimiter) && node.closer && node.remaining.positive?

        # What decides which openers suit a closer: its character, and for `~` its length too.
        def kind(closer) = closer.char == "~" ? [closer.char, closer.remaining] : closer.char

        def used(opener, closer)
          return closer.remaining if closer.char == "~"

          opener.remaining >= 2 && closer.remaining >= 2 ? 2 : 1
        end

        def marks(char, used)
          return { strike: true } if char == "~"

          used == 2 ? { bold: true } : { italic: true }
        end

        def space?(char) = WHITESPACE.match?(char)
        def punct?(char) = PUNCTUATION.match?(char)
      end
    end
  end
end
