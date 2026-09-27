# frozen_string_literal: true

require "strscan"

module Stationery
  module SVG
    # A minimal XML reader for SVG documents: elements, attributes and nesting.
    # Comments, processing instructions and doctypes are skipped; text content
    # (CDATA included) is kept only inside text, tspan and style, as String
    # children with entities decoded and each whitespace run one space.
    module Parser
      Element = Data.define(:name, :attributes, :children)

      TEXT = %w[text tspan style].freeze

      IGNORED = /<!--.*?-->|<\?.*?\?>|<!DOCTYPE[^>]*>/m
      CDATA = /<!\[CDATA\[(.*?)\]\]>/m
      ESCAPES = { "&" => "&amp;", "<" => "&lt;", ">" => "&gt;" }.freeze
      TAG = %r{<(/?)([a-zA-Z][\w:.-]*)((?:\s+[\w:.-]+\s*=\s*(?:"[^"]*"|'[^']*'))*)\s*(/?)>}m
      ATTRIBUTE = /([\w:.-]+)\s*=\s*(?:"([^"]*)"|'([^']*)')/

      module_function

      def parse(source)
        source = source.to_s.gsub(IGNORED, "").gsub(CDATA) { Regexp.last_match(1).gsub(/[&<>]/, ESCAPES) }
        scanner = StringScanner.new(source)
        root = Element.new("document", {}, [])
        stack = [root]
        while (content = scanner.scan_until(/(?=<)/))
          keep(stack.last, content)
          tag = scanner.scan(TAG) or (scanner.getch && next)
          handle(stack, *tag.match(TAG).captures)
        end
        root.children.first
      end

      # Yields the element and every element below it, depth first.
      def walk(element, &)
        yield element
        element.children.each { |child| walk(child, &) if child.is_a?(Element) }
      end

      def keep(element, content)
        return if content.empty? || !TEXT.include?(element.name)

        element.children << Stationery::Text::Entities.decode(content).gsub(/\s+/, " ")
      end

      def handle(stack, closing, name, attributes, self_closing)
        return stack.pop if closing == "/" && stack.size > 1

        element = Element.new(name, attributes.scan(ATTRIBUTE).to_h { |k, *v| [k, v.compact.first] }, [])
        stack.last.children << element
        stack << element if self_closing.empty?
      end
    end
  end
end
