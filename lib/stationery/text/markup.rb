# frozen_string_literal: true

require "strscan"

module Stationery
  module Text
    # Parses Prawn-style inline markup into runs:
    #
    #   <b> <strong> <i> <em> <u> <strikethrough> <s> <del> <sub> <sup> <br>
    #   <color rgb="#hex"> <color c="" m="" y="" k="">
    #   <font size="n" name="Family"> <link href="…"> <a href="…">
    #
    # Unknown tags are dropped and their content kept. A "<" that does not open
    # a well-formed tag is text, so "1 < 2" survives.
    class Markup
      TAG = %r{<(/?)([a-zA-Z][a-zA-Z0-9]*)((?:\s+[a-zA-Z_:-]+\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>"']+))*)\s*/?>}
      ATTRIBUTE = /([a-zA-Z_:-]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>"']+))/
      STYLES = {
        "b" => { weight: :bold }, "strong" => { weight: :bold },
        "i" => { style: :italic }, "em" => { style: :italic },
        "u" => { underline: true },
        "strikethrough" => { strikethrough: true }, "s" => { strikethrough: true }, "del" => { strikethrough: true },
        "sub" => { script: :sub }, "sup" => { script: :sup }
      }.freeze

      def self.parse(source, style)
        new(source, style).runs
      end

      def initialize(source, style)
        @scanner = StringScanner.new(source.to_s)
        @stack = [[nil, style]]
        @runs = []
      end

      def runs
        until @scanner.eos?
          if (text = @scanner.scan(/[^<]+/))
            emit(Entities.decode(text))
          elsif @scanner.check(TAG)
            tag(@scanner.scan(TAG))
          else
            emit(@scanner.getch)
          end
        end
        Run.merge(@runs)
      end

      private

      def emit(text)
        @runs << Run.new(text, @stack.last.last)
      end

      def tag(source)
        closing, name, attributes = source.match(TAG).captures
        name = name.downcase
        return emit("\n") if name == "br"
        return close(name) if closing == "/"

        overrides = overrides_for(name, attributes(attributes))
        @stack << [name, @stack.last.last.with(**overrides)] if overrides
      end

      def close(name)
        index = @stack.rindex { |tag_name, _| tag_name == name }
        @stack.slice!(index..) if index&.positive?
      end

      def overrides_for(name, attributes)
        return STYLES[name] if STYLES.key?(name)

        case name
        when "color" then color(attributes)
        when "font" then font(attributes)
        when "link", "a" then attributes["href"] ? { link: attributes["href"] } : {}
        end
      end

      def color(attributes)
        return { color: attributes["rgb"] } if attributes["rgb"]
        return {} unless %w[c m y k].all? { |key| attributes.key?(key) }

        { color: %w[c m y k].map { |key| number(attributes[key]) } }
      end

      def font(attributes)
        overrides = {}
        overrides[:size] = number(attributes["size"]) if attributes["size"]
        overrides[:family] = attributes["name"] if attributes["name"]
        overrides
      end

      def attributes(source)
        source.scan(ATTRIBUTE).to_h { |key, *values| [key.downcase, Entities.decode(values.compact.first)] }
      end

      def number(value)
        value.include?(".") ? value.to_f : value.to_i
      end
    end
  end
end
