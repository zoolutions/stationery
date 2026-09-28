# frozen_string_literal: true

require_relative "../../rich/nodes"
require_relative "collector"

module Stationery
  module HTML
    class TreeBuilder
      # Converts an element tree into rich-text blocks. Containers flatten into their children, inline
      # elements add marks, and unknown elements keep their content. Each element's CSS (see Css) adds
      # marks to the text inside it and a style to the block it becomes; `text-align` is handed down
      # to the blocks inside, the way CSS inherits it.
      class Blocks
        CONTAINERS = %w[
          #root html body div p section article header footer main figure figcaption aside nav address
          dl dt dd center details summary form fieldset
        ].freeze
        HEADINGS = %w[h1 h2 h3 h4 h5 h6].freeze
        MARKS = {
          "strong" => { bold: true }, "b" => { bold: true },
          "em" => { italic: true }, "i" => { italic: true },
          "u" => { underline: true }, "ins" => { underline: true },
          "s" => { strike: true }, "del" => { strike: true }, "strike" => { strike: true },
          "code" => { code: true }, "kbd" => { code: true }, "samp" => { code: true }, "tt" => { code: true },
          "sub" => { script: :sub }, "sup" => { script: :sup }
        }.freeze
        ALIGN = /\A\s*(left|center|right|justify)\s*\z/i
        # What makes a container a block of its own instead of flattening into its parent.
        BOXED = %i[background padding padding_top padding_right padding_bottom padding_left margin margin_top
                   margin_bottom break_before break_after keep_together columns].freeze
        # What a block of its own takes besides.
        WITH_BOX = %i[column_gap].freeze
        INHERITED = %i[align].freeze
        EMPTY = {}.freeze

        def self.convert(root, css = Css.parse([])) = new(css).blocks_of(root, EMPTY, EMPTY)

        def initialize(css = Css.parse([]))
          @css = css
        end

        def blocks_of(element, marks, inherited, style = EMPTY)
          collector = Collector.new
          collector.boundary(style) { children(element, marks, inherited, collector) }
          collector.blocks
        end

        private

        def children(element, marks, inherited, out)
          element.children.each { |child| visit(child, marks, inherited, out) }
        end

        def visit(node, marks, inherited, out)
          return out.text(node, marks) if node.is_a?(String)

          own, block = @css.resolve(node)
          marks = inherit(marks, own)
          style = inherited.merge(block)
          inherited = style.slice(*INHERITED)
          case node.name
          when *CONTAINERS then container(node, marks, inherited, style, out)
          when *HEADINGS then out.block(heading(node, marks, style))
          when "ul", "ol" then out.block(list(node, marks, inherited, style.except(*INHERITED)))
          when "blockquote" then out.block(quote(node, marks, inherited, style.except(*INHERITED)))
          when "pre" then out.block(code(node, style.except(*INHERITED)))
          when "hr" then out.block(Rich::Rule.new)
          when "br" then out.inline(Rich::Inline.break)
          when "wbr" then out.inline(Rich::Inline.new(text: Text::Breaks::ZERO_WIDTH_SPACE, marks:))
          when "img" then out.inline(image(node.attributes, style))
          when "table" then out.block(table(node, marks, inherited, style.except(*INHERITED)))
          else children(node, marks.merge(marks_for(node)), inherited, out)
          end
        end

        # A `p` hands its whole style to its paragraphs. Any other container with a box of its own
        # (a background, padding, margins, a page-break rule, columns) becomes a Container; without one it
        # flattens into its parent, as it always did.
        def container(node, marks, inherited, style, out)
          return out.boundary(style) { children(node, marks, inherited, out) } if node.name == "p"

          boxed = style.slice(*BOXED)
          return out.boundary(inherited) { children(node, marks, inherited, out) } if boxed.empty?

          boxed = style.slice(*BOXED, *WITH_BOX)
          out.block(Rich::Container.new(blocks: blocks_of(node, marks, inherited, inherited), style: boxed))
        end

        def heading(element, marks, style)
          inlines = blocks_of(element, marks, EMPTY).grep(Rich::Paragraph).flat_map(&:inlines)
          Rich::Heading.new(level: element.name[1].to_i, inlines:, style:) unless inlines.empty?
        end

        def list(element, marks, inherited, style)
          items = elements(element).map do |item|
            item = Element.new("li", {}, [item]) unless item.name == "li"
            own, block = @css.resolve(item)
            within = inherited.merge(block.slice(*INHERITED))
            blocks_of(item, inherit(marks, own), within, within)
          end
          return if items.empty?

          ordered = element.name == "ol"
          start = Integer(element.attributes["start"], exception: false) || 1 if ordered
          Rich::List.new(ordered:, start:, items:, style:)
        end

        def quote(element, marks, inherited, style)
          Rich::Blockquote.new(blocks: blocks_of(element, marks, inherited, inherited), style:)
        end

        def code(element, style)
          language = elements(element).find { |child| child.name == "code" }&.attributes&.[]("class")
          Rich::CodeBlock.new(text: raw_text(element).delete_prefix("\n").chomp,
                              language: language&.[](/lang(?:uage)?-(\S+)/, 1), style:)
        end

        def raw_text(element)
          element.children.sum("") do |child|
            next child if child.is_a?(String)

            child.name == "br" ? "\n" : raw_text(child)
          end
        end

        def image(attributes, style)
          return unless attributes["src"]

          Rich::Image.new(src: attributes["src"], alt: attributes["alt"],
                          width: dimension(attributes["width"]), height: dimension(attributes["height"]),
                          style: style.slice(:width, :align))
        end

        def dimension(value) = value&.[](/\A\s*(\d+)/, 1)&.to_i

        def table(element, marks, inherited, style)
          rows = rows_of(element).filter_map do |row|
            cells = elements(row).select { |cell| %w[td th].include?(cell.name) }
            cells.map { |cell| cell(cell, marks, inherited) } unless cells.empty?
          end
          Rich::Table.new(rows:, style:) unless rows.empty?
        end

        def rows_of(element)
          elements(element).flat_map do |child|
            next [child] if child.name == "tr"

            TreeBuilder::SECTIONS.include?(child.name) ? rows_of(child) : []
          end
        end

        def cell(element, marks, inherited)
          own, block = @css.resolve(element)
          marks = inherit(marks, own)
          align = block[:align] || aligned(element.attributes["align"]) || inherited[:align]
          Rich::Cell.new(header: element.name == "th", align:, blocks: blocks_of(element, marks, EMPTY),
                         style: block.except(:align))
        end

        # The marks an element's text has: its ancestors' with its own over them. A relative size
        # (em, %) is relative to the size around it, so it multiplies what is inherited.
        def inherit(marks, own)
          return marks if own.empty?
          return marks.merge(own) unless own[:scale]

          merged = marks.merge(own.except(:scale))
          if marks[:size] then merged[:size] = marks[:size] * own[:scale]
          else merged[:scale] = marks.fetch(:scale, 1) * own[:scale]
          end
          merged
        end

        # The align attribute of a cell, as a symbol.
        def aligned(value)
          name = value && value[ALIGN, 1]
          name&.downcase&.to_sym
        end

        def marks_for(element)
          return MARKS[element.name] if MARKS.key?(element.name)
          return { link: element.attributes["href"] } if element.name == "a" && element.attributes["href"]

          EMPTY
        end

        def elements(element) = element.children.grep(TreeBuilder::Element)
      end
    end
  end
end
