# frozen_string_literal: true

module Stationery
  # Bulleted and numbered lists.
  module Elements
    BULLETS = %i[disc circle square].freeze

    # A bulleted list. `style:` is :disc, :circle, :square, :dash or any
    # String; unstyled nested lists cycle disc → circle → square. Every node
    # added inside becomes an item, `li` or not.
    def ul(style: nil, gap: 4, indent: nil, marker_gap: 6, marker_color: nil, &)
      shape = style || BULLETS[@_builder.list_depth % BULLETS.size]
      marker_style = @_builder.style({ color: marker_color }.compact)
      list(marker_style, gap:, indent:, marker_gap:, marker: ->(_) { list_bullet(shape, marker_style) }, &)
    end

    # A numbered list. `format:` is :decimal, :alpha, :upper_alpha, :roman,
    # :upper_roman or a Proc given the number.
    def ol(format: :decimal, start: 1, suffix: ".", gap: 4, indent: nil, marker_gap: 6, marker_color: nil, &)
      marker_style = @_builder.style({ color: marker_color }.compact)
      label = ->(index) { list_label(ListMarkers.label(format, start + index, suffix), marker_style) }
      list(marker_style, gap:, indent:, marker_gap:, marker: label, &)
    end

    # A list item: a String becomes a paragraph (taking every text option),
    # a block a flow of its children.
    def li(content = nil, gap: 0, **text_options, &)
      return text(content, **text_options) if content

      @_builder.add(container(gap:, &))
    end

    private

    def list(marker_style, gap:, indent:, marker_gap:, marker:, &)
      items = Builder::Items.new
      @_builder.nested_list { @_builder.within(items) { yield_content(&) } }
      markers = items.nodes.each_index.map(&marker)
      indent ||= [markers.map(&:natural_width).max || 0, marker_style.size].max + marker_gap
      entries = items.nodes.zip(markers).map do |node, mark|
        Layout::ListItem.new(mark, node.is_a?(Layout::Flow) ? node : Layout::Flow.new([node]), indent:, marker_gap:)
      end
      @_builder.add(Layout::Flow.new(entries, gap:))
    end

    def list_bullet(shape, style)
      return Layout::Bullet.new(shape, style:, context: @_builder.context(style)) if BULLETS.include?(shape)
      return list_label(shape.to_s, style) unless shape == :dash

      font = @_builder.book.resolve(style).first
      list_label(font.glyph?("–") ? "–" : "-", style)
    end

    def list_label(label, style)
      Layout::Text.new([Text::Run.new(label, style)], context: @_builder.context(style), align: :right)
    end
  end
end
