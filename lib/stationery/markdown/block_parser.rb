# frozen_string_literal: true

require_relative "../rich/nodes"
require_relative "inline_parser"
require_relative "block_parser/containers"
require_relative "block_parser/tables"

module Stationery
  module Markdown
    # Splits CommonMark source into blocks, line by line. Paragraph, heading and table cell text is left
    # raw (a String in place of inlines) for Markdown.parse to run through the inline parser once every
    # link reference definition, which this parser collects into `refs`, is known. Raw HTML stays text.
    class BlockParser
      include Containers
      include Tables

      ATX = /\A {0,3}(\#{1,6})(?:[ \t]+(.*?))?[ \t]*\z/
      SETEXT = /\A {0,3}(=+|-+)[ \t]*\z/
      THEMATIC = /\A {0,3}(?:(?:\*[ \t]*){3,}|(?:-[ \t]*){3,}|(?:_[ \t]*){3,})\z/
      FENCE = /\A( {0,3})(`{3,}|~{3,})[ \t]*([^`]*?)[ \t]*\z/
      DEFINITION = /
        \A\ {0,3}\[((?:[^\]\\]|\\.)+)\]:[ \t]*
        (?:<([^<>]*)>|(\S+))
        (?:[ \t]+(?:"[^"]*"|'[^']*'|\([^)]*\)))?[ \t]*\z
      /x

      def self.parse(source, refs) = new(lines(source), refs).blocks

      def self.lines(source) = source.to_s.split(/\r\n?|\n/).map { |line| expand_tabs(line) }

      # Tabs in a line's indentation and container markers advance to the next multiple of four columns.
      def self.expand_tabs(line)
        prefix = line[/\A[ \t>*+\-\d.)]*/]
        return line unless prefix.include?("\t")

        expanded = prefix.each_char.with_object(+"") do |char, out|
          out << (char == "\t" ? " " * (4 - (out.length % 4)) : char)
        end
        expanded + line[prefix.length..]
      end

      def initialize(lines, refs)
        @lines = lines
        @refs = refs
        @index = 0
      end

      def blocks
        blocks = []
        while (line = @lines[@index])
          block = block(line)
          blocks << block if block
        end
        blocks
      end

      private

      def block(line)
        if blank?(line) then skip
        elsif indent(line) >= 4 then indented_code
        elsif (match = FENCE.match(line)) then fenced_code(match)
        elsif (match = ATX.match(line)) then atx(match)
        elsif THEMATIC.match?(line) then skip(Rich::Rule.new)
        elsif QUOTE.match?(line) then blockquote
        elsif (match = list_marker(line)) then list(match)
        elsif table_start? then table
        else paragraph
        end
      end

      def skip(block = nil)
        @index += 1
        block
      end

      def indented_code
        lines = []
        while (line = @lines[@index]) && (blank?(line) || indent(line) >= 4)
          lines << line.sub(/\A {1,4}/, "")
          @index += 1
        end
        lines.pop while lines.last.strip.empty?
        Rich::CodeBlock.new(text: lines.join("\n"), language: nil)
      end

      def fenced_code(match)
        indent, fence, info = match.captures
        closing = /\A {0,3}#{Regexp.escape(fence[0])}{#{fence.length},}[ \t]*\z/
        lines = []
        while (line = @lines[@index += 1])
          break @index += 1 if closing.match?(line)

          lines << line.sub(/\A {0,#{indent.length}}/, "")
        end
        Rich::CodeBlock.new(text: lines.join("\n"), language: info.split.first)
      end

      def atx(match)
        @index += 1
        Rich::Heading.new(level: match[1].length, inlines: match[2].to_s.sub(/(?:\A|[ \t]+)#+\z/, ""))
      end

      def paragraph
        lines = [@lines[@index].lstrip]
        while (line = @lines[@index += 1]) && !blank?(line)
          if (underline = SETEXT.match(line)) && definitions(lines).any?
            @index += 1
            return Rich::Heading.new(level: underline[1].start_with?("=") ? 1 : 2, inlines: text(lines))
          end
          break if interrupts?(line)

          lines << line.lstrip
        end
        lines = definitions(lines)
        Rich::Paragraph.new(inlines: text(lines)) if lines.any?
      end

      # Strips the link reference definitions leading a paragraph into @refs.
      def definitions(lines)
        lines = lines.dup
        while (match = DEFINITION.match(lines.first.to_s))
          @refs[InlineParser.label(match[1])] ||= InlineParser.destination(match[2] || match[3])
          lines.shift
        end
        lines
      end

      def text(lines) = lines.join("\n").rstrip

      def interrupts?(line)
        FENCE.match?(line) || ATX.match?(line) || THEMATIC.match?(line) || QUOTE.match?(line) ||
          list_interrupts?(line)
      end

      def blank?(line) = line.strip.empty?
      def indent(line) = line[/\A */].length
      def nested(lines) = BlockParser.new(lines, @refs).blocks
    end
  end
end
