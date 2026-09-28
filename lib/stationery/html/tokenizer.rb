# frozen_string_literal: true

require "strscan"
require_relative "../text/entities"

module Stationery
  module HTML
    # Splits HTML into [:start, name, attributes, self_closing], [:end, name], [:text, string] and
    # [:style, css] tokens. Names are lowercased, text and attribute values entity-decoded. Comments,
    # declarations and the content of script, template and title elements are skipped; a style
    # element's text is kept raw for the stylesheet; void elements never end.
    class Tokenizer
      VOID = %w[area base br col embed hr img input keygen link meta param source track wbr].freeze
      SKIPPED = %w[script template title].freeze
      RAW_END = %r{</style\s*>}i
      COMMENT = /<!--.*?(?:-->|\z)/m
      CDATA = /<!\[CDATA\[(.*?)(?:\]\]>|\z)/m
      DECLARATION = /<[!?][^>]*>?/
      START = /<([a-zA-Z][a-zA-Z0-9:-]*)/
      FINISH = %r{</([a-zA-Z][a-zA-Z0-9:-]*)[^>]*>?}
      ATTRIBUTE = %r{[\s/]*([^\s"'>/=]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+)))?}
      TAG_END = %r{\s*/?\s*>}

      def self.tokenize(source) = new(source).tokens

      def initialize(source)
        @scanner = StringScanner.new(source.to_s)
        @tokens = []
      end

      def tokens
        step until @scanner.eos?
        @tokens
      end

      private

      def step
        if (text = @scanner.scan(/[^<]+/)) then text(Text::Entities.decode(text))
        elsif @scanner.scan(CDATA) then text(@scanner[1])
        elsif @scanner.skip(COMMENT) || @scanner.skip(DECLARATION) then nil
        elsif @scanner.scan(FINISH) then finish(@scanner[1].downcase)
        elsif @scanner.scan(START) then start(@scanner[1].downcase)
        else text(@scanner.getch)
        end
      end

      def text(string)
        if @tokens.last&.first == :text
          @tokens.last[1] += string
        else
          @tokens << [:text, string]
        end
      end

      def start(name)
        attributes = {}
        while @scanner.scan(ATTRIBUTE)
          attributes[@scanner[1].downcase] ||= Text::Entities.decode(@scanner[2] || @scanner[3] || @scanner[4] || "")
        end
        ending = @scanner.scan(TAG_END) || @scanner.scan_until(/>/) || (@scanner.terminate && "")
        return skip_raw(name) if SKIPPED.include?(name)
        return style if name == "style"

        @tokens << [:start, name, attributes, ending.include?("/") || VOID.include?(name)]
      end

      def style
        start = @scanner.pos
        finish = @scanner.skip_until(RAW_END)
        css = finish ? @scanner.string.byteslice(start, finish - @scanner.matched_size) : @scanner.rest
        @scanner.terminate unless finish
        @tokens << [:style, css.force_encoding(@scanner.string.encoding)]
      end

      def finish(name)
        @tokens << [:end, name] unless VOID.include?(name)
      end

      def skip_raw(name)
        @scanner.skip_until(%r{</#{name}\s*>}i) || @scanner.terminate
      end
    end
  end
end
