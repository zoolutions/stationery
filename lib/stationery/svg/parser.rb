# frozen_string_literal: true

require "strscan"

module Stationery
  module SVG
    # A minimal XML reader for SVG documents: elements, attributes and nesting.
    # Comments, processing instructions and doctypes are skipped; text content
    # (CDATA included) is kept only inside text, tspan and style, as String
    # children with entities decoded and each whitespace run one space.
    #
    # An element nested deeper than MAX_DEPTH is not descended into: it takes
    # its place in the deepest element kept and so does what it holds, so
    # nothing that walks the tree recurses deeper than that.
    module Parser
      Element = Data.define(:name, :attributes, :children)

      TEXT = %w[text tspan style].freeze
      MAX_DEPTH = 128

      IGNORED = /<!--.*?-->|<\?.*?\?>|<!DOCTYPE[^>]*>/m
      CDATA = /<!\[CDATA\[(.*?)\]\]>/m
      ESCAPES = { "&" => "&amp;", "<" => "&lt;", ">" => "&gt;" }.freeze
      TAG = %r{<(/?)([a-zA-Z][\w:.-]*)((?:\s+[\w:.-]+\s*=\s*(?:"[^"]*"|'[^']*'))*)\s*(/?)>}m
      ATTRIBUTE = /([\w:.-]+)\s*=\s*(?:"([^"]*)"|'([^']*)')/

      module_function

      # The root element. The block is given how deep the source nested when
      # that was deeper than `max_depth`.
      def parse(source, max_depth: MAX_DEPTH)
        source = source.to_s.gsub(IGNORED, "").gsub(CDATA) { Regexp.last_match(1).gsub(/[&<>]/, ESCAPES) }
        scanner = StringScanner.new(source)
        tree = Tree.new(max_depth)
        while (content = scanner.scan_until(/(?=<)/))
          keep(tree.open, content)
          tag = scanner.scan(TAG) or (scanner.getch && next)
          tree.tag(*tag.match(TAG).captures)
        end
        yield tree.deepest if block_given? && tree.deepest > max_depth
        tree.root
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

      # The elements open while the source is read. `hoisted` counts the open
      # ones too deep to descend into; their end tags are counted off again.
      class Tree
        attr_reader :deepest

        def initialize(max_depth)
          @document = Element.new("document", {}, [])
          @stack = [@document]
          @max_depth = max_depth
          @hoisted = 0
          @deepest = 0
        end

        def root = @document.children.first
        def open = @stack.last

        def tag(closing, name, attributes, self_closing)
          return close if closing == "/"

          element = Element.new(name, attributes.scan(ATTRIBUTE).to_h { |k, *v| [k, v.compact.first] }, [])
          open.children << element
          descend(element) if self_closing.empty?
        end

        private

        def close
          return @hoisted -= 1 if @hoisted.positive?

          @stack.pop if @stack.size > 1
        end

        def descend(element)
          depth = @stack.size + @hoisted
          @deepest = depth if depth > @deepest
          return @stack << element if @stack.size <= @max_depth

          @hoisted += 1
        end
      end
    end
  end
end
