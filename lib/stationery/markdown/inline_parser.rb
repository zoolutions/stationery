# frozen_string_literal: true

require "strscan"
require_relative "../rich/nodes"
require_relative "../text/entities"
require_relative "inline_parser/nodes"
require_relative "inline_parser/emphasis"
require_relative "inline_parser/links"

module Stationery
  module Markdown
    # Parses CommonMark inline content into Rich::Inline runs and Rich::Image items: backslash escapes,
    # code spans, `*`/`_` emphasis, GFM `~` strikethrough, inline, reference and auto links, images,
    # hard and soft breaks and entities. Raw HTML stays text.
    class InlineParser
      include Links

      PUNCTUATION = /[!-\/:-@\[-`{-~]/
      PLAIN = /[^\\`*_~\[\]!<&\n]+/
      ENTITY = /&(?:#[xX]\h{1,6}|#\d{1,7}|[a-zA-Z][a-zA-Z0-9]{1,31});/

      def self.parse(text, refs = {}) = new(text, refs).items
      def self.label(text) = text.strip.gsub(/\s+/, " ").downcase
      def self.destination(text) = Text::Entities.decode(text.gsub(/\\(#{PUNCTUATION})/o, '\1'))

      def initialize(text, refs)
        @source = text.to_s
        @scanner = StringScanner.new(@source)
        @refs = refs
        @nodes = []
        @brackets = []
      end

      def items
        step until @scanner.eos?
        Emphasis.process(@nodes)
        Rich::Inlines.merge(Nodes.flatten(@nodes))
      end

      private

      def step
        if (text = @scanner.scan(PLAIN)) then add(text)
        elsif @scanner.skip(/\\\n/) then newline(hard: true)
        elsif @scanner.scan(/\\(#{PUNCTUATION})/o) then add(@scanner[1])
        elsif @scanner.skip("\n") then newline
        elsif @scanner.check("`") then code_span
        elsif @scanner.check(/[*_~]/) then delimiter
        elsif @scanner.skip("![") then open_bracket(image: true)
        elsif @scanner.skip("[") then open_bracket
        elsif @scanner.skip("]") then close_bracket
        elsif @scanner.scan(AUTOLINK) then autolink
        elsif @scanner.scan(ENTITY) then add(Text::Entities.decode(@scanner.matched))
        else add(@scanner.getch)
        end
      end

      def add(text) = @nodes << Nodes::Text.new(text)

      def newline(hard: false)
        last = @nodes.last
        if last.is_a?(Nodes::Text)
          stripped = last.text.sub(/ +\z/, "")
          hard ||= last.text.length - stripped.length >= 2
          last.text = stripped
        end
        @scanner.skip(/ +/)
        @nodes << (hard ? Nodes::Break.new : Nodes::Text.new(" "))
      end

      def code_span
        run = @scanner.scan(/`+/)
        content = @scanner.scan_until(/(?<!`)#{run}(?!`)/)
        return add(run) unless content

        text = content[0...-run.length].tr("\n", " ")
        text = text[1...-1] if text.start_with?(" ") && text.end_with?(" ") && !text.strip.empty?
        @nodes << Nodes::Code.new(text)
      end

      def delimiter
        before = previous_character
        run = @scanner.scan(/\*+|_+|~+/)
        @nodes << Emphasis.delimiter(run, before, @scanner.check(/./m) || " ")
      end

      # The character before the scanner, read from the few bytes before it: a character position
      # is counted from the start of the source, which a long paragraph would pay for at every run.
      def previous_character
        position = @scanner.pos
        @source.byteslice([position - 4, 0].max...position).scrub("")[-1] || " "
      end
    end
  end
end
