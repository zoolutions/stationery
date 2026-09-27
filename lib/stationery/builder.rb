# frozen_string_literal: true

module Stationery
  # Collects the nodes a component tree describes. Holds the container stack
  # (where the next node goes) and the text defaults in effect.
  class Builder
    STYLE_KEYS = %i[size color weight style letter_spacing underline strikethrough link opacity].freeze

    # Collects a row's columns; anything that is not already a column box is
    # wrapped in one.
    class Columns
      attr_reader :nodes

      def initialize = @nodes = []

      def <<(node)
        @nodes << (node.is_a?(Layout::Box) ? node : Layout::Box.new(Layout::Flow.new([node])))
        self
      end
    end

    # Collects a list's items: every node added becomes one item.
    class Items
      attr_reader :nodes

      def initialize = @nodes = []

      def <<(node)
        @nodes << node
        self
      end
    end

    attr_reader :root, :book, :list_depth

    def initialize(book:, text: {})
      @book = book
      @root = Layout::Flow.new
      @containers = [@root]
      @text = [text]
      @list_depth = 0
    end

    def nested_list
      @list_depth += 1
      yield
    ensure
      @list_depth -= 1
    end

    def add(node)
      @containers.last << node
      node
    end

    def within(container)
      @containers << container
      yield
      container
    ensure
      @containers.pop
    end

    def with_text(**overrides)
      @text << text_defaults.merge(overrides.compact)
      yield
    ensure
      @text.pop
    end

    def text_defaults = @text.last

    def style(options = {})
      options = text_defaults.merge(options)
      family = options[:font] || @book.families.keys.first || "default"
      Text::Style.new(family: family.to_s, **options.slice(*STYLE_KEYS))
    end

    def context(style = self.style) = Layout::Context.new(book: @book, style:)
  end
end
