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

        # Wraps matched delimiter pairs (and what lies between them) in place.
        def process(nodes)
          index = 0
          while index < nodes.size
            closer = nodes[index]
            opener = closer?(closer) && opener_for(nodes, index)
            next index += 1 unless opener

            index = wrap(nodes, opener, index)
          end
        end

        def wrap(nodes, opening, index)
          opener = nodes[opening]
          closer = nodes[index]
          used = used(opener, closer)
          nodes[(opening + 1)...index] = [Nodes::Wrap.new(marks(closer.char, used), nodes[(opening + 1)...index])]
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

        def opener_for(nodes, index)
          closer = nodes[index]
          (index - 1).downto(0).find do |i|
            node = nodes[i]
            node.is_a?(Nodes::Delimiter) && node.opener && node.char == closer.char && node.remaining.positive? &&
              (closer.char != "~" || node.remaining == closer.remaining)
          end
        end

        def closer?(node) = node.is_a?(Nodes::Delimiter) && node.closer && node.remaining.positive?

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
