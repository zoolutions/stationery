# frozen_string_literal: true

require_relative "css"
require_relative "tree_builder/blocks"

module Stationery
  module HTML
    # Builds a lenient element tree from tokens, closing what HTML5 closes implicitly (a p before a block,
    # an li before the next li, cells and rows before the next), ignoring stray end tags, then converts
    # the tree into rich-text blocks. An element nested deeper than the Rich::Nesting limit is left out
    # of the tree: what it holds goes to the deepest element kept, so everything that walks the tree
    # (and the layout it becomes) recurses no deeper than the limit.
    class TreeBuilder
      Element = Data.define(:name, :attributes, :children)

      CLOSES_P = %w[
        address article aside blockquote dd details div dl dt fieldset figcaption figure footer form
        h1 h2 h3 h4 h5 h6 header hr li main nav ol p pre section table ul
      ].freeze
      HEADINGS = %w[h1 h2 h3 h4 h5 h6].freeze
      SECTIONS = %w[thead tbody tfoot].freeze
      BLOCKS = (CLOSES_P + SECTIONS + %w[tr td th caption]).freeze
      IMPLIED = {
        "li" => [%w[li], %w[ul ol]],
        "dt" => [%w[dt dd], %w[dl]], "dd" => [%w[dt dd], %w[dl]],
        "td" => [%w[td th], %w[tr table]], "th" => [%w[td th], %w[tr table]],
        "tr" => [%w[tr], %w[table]],
        "thead" => [SECTIONS, %w[table]], "tbody" => [SECTIONS, %w[table]], "tfoot" => [SECTIONS, %w[table]]
      }.freeze

      # `css` is the Css::Report unsupported styles are told to.
      def self.parse(tokens, nesting = Rich::Nesting.new, css: nil)
        builder = new(nesting)
        root = builder.build(tokens)
        Blocks.convert(root, Css.parse(builder.sheets, css || Css::Report.new))
      end

      attr_reader :sheets

      def initialize(nesting = Rich::Nesting.new)
        @root = Element.new("#root", {}, [])
        @stack = [@root]
        @nesting = nesting
        @flattened = [] # the names of the open elements left out of the tree
        @sheets = []
      end

      def build(tokens)
        tokens.each do |type, *args|
          case type
          when :start then start(*args)
          when :end then finish(*args)
          when :style then @sheets << args.first
          else @stack.last.children << args.first
          end
        end
        @root
      end

      private

      def start(name, attributes, self_closing)
        return flatten(name, attributes, self_closing) unless @flattened.empty?

        close_nearest(%w[p], %w[table td th caption]) if CLOSES_P.include?(name)
        close_nearest(HEADINGS, []) if HEADINGS.include?(name) && HEADINGS.include?(@stack.last.name)
        close_nearest(*IMPLIED[name]) if IMPLIED.key?(name)
        return flatten(name, attributes, self_closing) if @stack.size > @nesting.limit

        push("tr", {}, false) if %w[td th].include?(name) && %w[table thead tbody tfoot].include?(@stack.last.name)
        push(name, attributes, self_closing)
      end

      def push(name, attributes, self_closing)
        element = Element.new(name, attributes, [])
        @stack.last.children << element
        @stack << element unless self_closing
      end

      # Too deep for the tree: a void element (br, img, hr) still takes its place in the deepest
      # element kept, anything else is only remembered until its end tag, its content going there too.
      def flatten(name, attributes, self_closing)
        return push(name, attributes, true) if self_closing

        @flattened << name
        @nesting.record(@stack.size - 1 + @flattened.size)
        separate(name)
      end

      def finish(name)
        flattened = @flattened.rindex(name)
        return @flattened.slice!(flattened..).each { |left_out| separate(left_out) } if flattened

        index = @stack.rindex { |element| element.name == name }
        return unless index&.positive?

        @stack.slice!(index..)
        @flattened.clear
      end

      # A flattened block no longer parts its text from its neighbours'; a space does.
      def separate(name)
        @stack.last.children << " " if BLOCKS.include?(name)
      end

      def close_nearest(names, boundary)
        index = @stack.rindex { |element| names.include?(element.name) || boundary.include?(element.name) }
        @stack.slice!(index..) if index&.positive? && names.include?(@stack[index].name)
      end
    end
  end
end
