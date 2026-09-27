# frozen_string_literal: true

module Stationery
  module Markdown
    class BlockParser
      # GFM tables: a header row, a delimiter row of the same width setting each column's alignment, and
      # body rows up to a blank line or another block. Body rows are padded or cut to the header's width.
      module Tables
        DELIMITER = /\A {0,3}\|?[ \t]*:?-+:?[ \t]*(?:\|[ \t]*:?-+:?[ \t]*)*\|?[ \t]*\z/
        ALIGNMENTS = { "::" => :center, ":" => :left, "-:" => :right }.freeze

        private

        def table_start?
          header = @lines[@index]
          delimiter = @lines[@index + 1]
          header.include?("|") && delimiter && DELIMITER.match?(delimiter) &&
            cells(header).length == cells(delimiter).length
        end

        def table
          header = cells(@lines[@index])
          aligns = cells(@lines[@index + 1]).map { |cell| alignment(cell) }
          rows = [row(header, aligns, header: true)]
          @index += 2
          while (line = @lines[@index]) && !blank?(line) && !interrupts?(line)
            texts = cells(line)
            rows << row(Array.new(header.length) { |i| texts[i] || "" }, aligns)
            @index += 1
          end
          Rich::Table.new(rows:)
        end

        def row(texts, aligns, header: false)
          texts.zip(aligns).map do |text, align|
            Rich::Cell.new(header:, align:, blocks: text.empty? ? [] : [Rich::Paragraph.new(inlines: text)])
          end
        end

        def alignment(cell)
          key = (cell.start_with?(":") ? ":" : "") + (cell.end_with?(":") ? ":" : "")
          key = "-:" if key == ":" && !cell.start_with?(":")
          ALIGNMENTS[key]
        end

        def cells(line)
          text = line.strip.delete_prefix("|")
          text = text.delete_suffix("|") unless text.end_with?("\\|")
          text.split(/(?<!\\)\|/, -1).map { |cell| cell.strip.gsub("\\|", "|") }
        end
      end
    end
  end
end
