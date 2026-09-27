# frozen_string_literal: true

module Stationery
  # One page: its size and margins, the drawing operators written to it, the
  # resources those operators reference, its link annotations and the named
  # anchors painted on it (PDF-space tops).
  class Page
    SIZES = {
      a3: [841.89, 1190.55], a4: [595.28, 841.89], a5: [419.53, 595.28],
      letter: [612, 792], legal: [612, 1008], tabloid: [792, 1224]
    }.freeze

    attr_reader :size, :margin, :content, :annotations, :anchors, :template_anchors, :resource_names

    def initialize(size: :letter, layout: :portrait, margin: 0)
      @size = dimensions(size)
      @size = @size.reverse if layout.to_sym == :landscape
      @margin = Geometry.box(margin)
      @content = String.new(encoding: Encoding::BINARY)
      @annotations = []
      @anchors = []
      @template_anchors = []
      @resource_names = Hash.new { |hash, key| hash[key] = [] }
    end

    def width = @size[0]
    def height = @size[1]

    def content_box
      top, right, bottom, left = @margin
      Rect.new(left, top, width - left - right, height - top - bottom)
    end

    def use(category, name)
      names = @resource_names[category]
      names << name unless names.include?(name)
      name
    end

    private

    def dimensions(size)
      return size.map { |v| v } if size.is_a?(Array) && size.size == 2

      SIZES.fetch(size.to_s.downcase.to_sym) do
        raise ArgumentError, "unknown page size #{size.inspect} (use #{SIZES.keys.join(", ")} or [width, height])"
      end
    end
  end
end
