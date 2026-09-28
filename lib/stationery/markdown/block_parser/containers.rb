# frozen_string_literal: true

module Stationery
  module Markdown
    class BlockParser
      # Blockquotes and lists: each collects its lines (stripping the `>` or the item's content indent,
      # taking lazy continuation lines) and parses them as a nested document. Tight and loose items both
      # hold Paragraphs; the model does not distinguish them.
      module Containers
        QUOTE = /\A {0,3}> ?/
        LIST = /\A(?<indent> {0,3})(?<marker>[-+*]|(?<number>\d{1,9})[.)])(?<space> *)(?<rest>.*)\z/
        MARKER = /\G[ \t]*(?:>|(?:[-+*]|\d{1,9}[.)])(?=[ \t]|\z))/

        private

        def container?(line) = QUOTE.match?(line) || !list_marker(line).nil?

        # Block quotes and lists nested past the limit: their lines, up to a blank one, as one
        # paragraph with the markers dropped.
        def flattened
          lines = []
          while (line = @lines[@index]) && !blank?(line)
            lines << unmarked(line)
            @index += 1
          end
          lines.reject!(&:empty?)
          Rich::Paragraph.new(inlines: text(lines)) if lines.any?
        end

        def unmarked(line)
          markers = line.scan(MARKER).size
          @nesting.record(@depth + markers)
          line.sub(/\A(?:#{MARKER.source.delete_prefix("\\G")})*[ \t]*/, "")
        end

        def blockquote
          lines = []
          while (line = @lines[@index])
            if QUOTE.match?(line) then lines << line.sub(QUOTE, "")
            elsif !blank?(line) && !blank?(lines.last) && !interrupts?(line) then lines << line
            else break
            end
            @index += 1
          end
          Rich::Blockquote.new(blocks: nested(lines))
        end

        def list(first)
          kind = first[:marker][-1]
          items = []
          while (match = next_item(kind))
            items << nested(item_lines(match))
          end
          ordered = !first[:number].nil?
          Rich::List.new(ordered:, start: (first[:number].to_i if ordered), items:)
        end

        # The marker of the list's next item, after any blank lines between items.
        def next_item(kind)
          index = @index
          index += 1 while @lines[index] && blank?(@lines[index])
          line = @lines[index].to_s
          match = list_marker(line)
          return unless match && match[:marker][-1] == kind && !THEMATIC.match?(line)

          @index = index
          match
        end

        def item_lines(match)
          column, first = content_start(match)
          lines = [first]
          while (line = @lines[@index += 1])
            if blank?(line) then break if lines == [""]

                                 lines << ""
            elsif indent(line) >= column then lines << line[column..]
            elsif !lines.last.empty? && !list_marker(line) && !interrupts?(line) then lines << line.lstrip
            else break
            end
          end
          give_back_blanks(lines)
        end

        def content_start(match)
          width = match[:indent].length + match[:marker].length
          spaces = match[:space].length
          return [width + 1, ""] if match[:rest].empty?
          return [width + 1, (" " * (spaces - 1)) + match[:rest]] if spaces > 4

          [width + spaces, match[:rest]]
        end

        def give_back_blanks(lines)
          while lines.length > 1 && lines.last.empty?
            lines.pop
            @index -= 1
          end
          lines
        end

        def list_marker(line)
          match = LIST.match(line)
          match if match && (!match[:space].empty? || match[:rest].empty?)
        end

        # Only a non-empty item interrupts a paragraph, and an ordered one only when it starts at 1.
        def list_interrupts?(line)
          match = list_marker(line)
          match && !match[:rest].strip.empty? && (match[:number].nil? || match[:number].to_i == 1)
        end
      end
    end
  end
end
