# frozen_string_literal: true

require_relative "nodes"
require_relative "styles"
require_relative "renderer/indents"
require_relative "renderer/inlines"
require_relative "renderer/links"
require_relative "renderer/boxes"

module Stationery
  module Rich
    # Draws rich-text blocks with a component's element DSL. Images come from
    # `images:` (a callable given the src, returning a path, an IO or nil) or
    # from files under `base_path:`; remote URLs are never fetched. Block
    # quotes and lists nested deeper than Indents::LIMIT stop indenting, which
    # is reported as a NestingLimit warning. A block's `style` (from the
    # source's CSS) adds margins, a box, an alignment or a page break around
    # what `styles:` draws; a block without one draws exactly as before.
    class Renderer
      include Indents
      include Boxes

      REMOTE = /\A[a-z][a-z0-9+.-]*:/i
      LINK_SCHEMES = %w[http https mailto tel].freeze

      def initialize(component, builder, gap:, styles:, images:, base_path:, bookmarks: false, links: nil)
        @component = component
        @builder = builder
        @gap = gap
        @styles = Styles.resolve(styles)
        @images = images
        @base_path = base_path && File.expand_path(base_path.to_s)
        @bookmarks = bookmarks
        @links = Links.new(links || LINK_SCHEMES, builder.warnings)
        @indents = 0
      end

      def render(blocks)
        depth = indents_of(blocks)
        @builder.warnings << Warnings::NestingLimit.new(depth:, limit: Indents::LIMIT) if depth > Indents::LIMIT
        group(blocks)
      end

      private

      def group(blocks) = @component.group(gap: @gap) { blocks.each { |block| block(block) } }

      def block(block)
        case block
        when Paragraph then styled(block.style) { paragraph(block.inlines, **@styles[:p], **aligned(block.style)) }
        when Heading then styled(block.style) { heading(block) }
        when List then styled(block.style) { indented(block) { list(block) } }
        when Blockquote then spaced(block.style) { indented(block) { blockquote(block) } }
        when CodeBlock then spaced(block.style) { code(block) }
        when Rule then @component.rule(**@styles[:hr])
        when Table then styled(block.style.except(:border, :width)) { table(block) }
        when Image then image(block)
        when Container then styled(block.style) { group(block.blocks) }
        when PageBreak then @component.page_break
        end
      end

      def paragraph(inlines, **)
        @component.text(**) { |runs| Inlines.new(runs, @styles, @links).write(inlines) }
      end

      def heading(heading)
        style = @styles[:"h#{heading.level}"]
        size = style[:size] || (@builder.style.size * style.fetch(:scale, 1))
        bookmark = heading_bookmark(heading)
        paragraph(heading.inlines, **style.except(:scale), size:, heading: heading.level,
                                                           **aligned(heading.style), **({ bookmark: } if bookmark))
      end

      def heading_bookmark(heading)
        return unless @bookmarks && heading.level <= 3

        { title: heading.inlines.grep(Inline).map(&:text).join, level: heading.level }
      end

      def blockquote(quote)
        @component.box(role: :blockquote, **@styles[:blockquote], **box_options(quote.style)) do
          columned(quote.style) { group(quote.blocks) }
        end
      end

      def list(list)
        options = list.ordered ? { **@styles[:ol], start: list.start || 1 } : @styles[:ul]
        @component.public_send(list.ordered ? :ol : :ul, **options) do
          list.items.each do |blocks|
            @component.li { @component.text_style(**@styles[:li]) { group(blocks) } }
          end
        end
      end

      def code(block)
        font = @styles[:code][:font]
        @component.box(**@styles[:pre], **box_options(block.style)) do
          columned(block.style) { @component.text(block.text, **({ font: } if font)) }
        end
      end

      def table(table)
        header = table.rows.first&.all?(&:header) ? 1 : 0
        rows = table.rows.map { |row| row.map { |cell| cell_content(cell) } }
        cell = @styles[:table][:cell].merge(border_options(table.style[:border]))
        sized(table.style[:width]) { |width| @component.table(rows, header:, cell:, **width, **column_widths(table)) }
      end

      def cell_content(cell)
        style = cell.header ? @styles[:table][:header] : {}
        content = -> { @component.text_style(**style, align: cell.align) { group(cell.blocks) } }
        options = cell_options(cell.style)
        options.empty? ? content : { content:, **options }
      end

      def image(node)
        source = resolve(node.src)
        return unless source

        loaded = Images.load(source)
        @component.image(loaded, alt: node.alt, **aligned(node.style), **dimensions(node, loaded))
      rescue UnsupportedImage => e
        skip(node.src, e.message)
      end

      def resolve(src)
        return @images.call(src) || skip(src, "not found") if @images
        return skip(src, "remote") if REMOTE.match?(src)
        return skip(src, "not found") unless @base_path

        path = File.expand_path(src, @base_path)
        return skip(src, "outside base_path") unless path.start_with?(@base_path + File::SEPARATOR)

        File.file?(path) ? path : skip(src, "not found")
      end

      # A CSS width wins over the width and height attributes (the height
      # then follows the aspect ratio); a percentage is a share of the space.
      def dimensions(node, loaded)
        styled = node.style[:width]
        return { width: styled } if fraction?(styled)

        width = styled || node.width
        height = styled ? nil : node.height
        limit = @styles[:img][:max_width]
        natural = width || (height ? loaded.width * height.fdiv(loaded.height) : loaded.width)
        return { width:, height: } unless limit && natural > limit

        { width: limit, height: height && (height * limit.fdiv(natural)) }
      end

      def skip(source, reason)
        @builder.warnings << Warnings::SkippedImage.new(source:, reason:)
        nil
      end
    end
  end
end
