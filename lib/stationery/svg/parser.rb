# frozen_string_literal: true

require "strscan"

module Stationery
  module SVG
    # A minimal XML reader for SVG documents: elements, attributes and nesting.
    # Comments, processing instructions, doctypes and text content are skipped.
    module Parser
      Element = Data.define(:name, :attributes, :children)

      IGNORED = /<!--.*?-->|<\?.*?\?>|<!DOCTYPE[^>]*>|<!\[CDATA\[.*?\]\]>/m
      TAG = %r{<(/?)([a-zA-Z][\w:.-]*)((?:\s+[\w:.-]+\s*=\s*(?:"[^"]*"|'[^']*'))*)\s*(/?)>}m
      ATTRIBUTE = /([\w:.-]+)\s*=\s*(?:"([^"]*)"|'([^']*)')/

      module_function

      def parse(source)
        scanner = StringScanner.new(source.to_s.gsub(IGNORED, ""))
        root = Element.new("document", {}, [])
        stack = [root]
        while scanner.skip_until(/(?=<)/)
          tag = scanner.scan(TAG) or (scanner.getch && next)
          handle(stack, *tag.match(TAG).captures)
        end
        root.children.first
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
