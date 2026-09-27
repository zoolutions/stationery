# frozen_string_literal: true

require_relative "../../rich/nodes"
require_relative "collector"

module Stationery
  module HTML
    class TreeBuilder
      # Converts an element tree into rich-text blocks. Containers flatten into their children, inline
      # elements add marks, and unknown elements keep their content.
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
        TEXT_ALIGN = /text-align\s*:\s*(left|center|right|justify)/i

        def self.convert(root) = new.blocks_of(root, {})

        def blocks_of(element, marks)
          collector = Collector.new
          children(element, marks, collector)
          collector.blocks
        end

        private

        def children(element, marks, out)
          element.children.each { |child| visit(child, marks, out) }
        end

        def visit(node, marks, out)
          return out.text(node, marks) if node.is_a?(String)

          case node.name
          when *CONTAINERS then out.boundary { children(node, marks, out) }
          when *HEADINGS then out.block(heading(node, marks))
          when "ul", "ol" then out.block(list(node, marks))
          when "blockquote" then out.block(Rich::Blockquote.new(blocks: blocks_of(node, marks)))
          when "pre" then out.block(code(node))
          when "hr" then out.block(Rich::Rule.new)
          when "br" then out.inline(Rich::Inline.break)
          when "img" then out.inline(image(node.attributes))
          when "table" then out.block(table(node, marks))
          else children(node, marks.merge(marks_for(node)), out)
          end
        end

        def heading(element, marks)
          inlines = blocks_of(element, marks).grep(Rich::Paragraph).flat_map(&:inlines)
          Rich::Heading.new(level: element.name[1].to_i, inlines:) unless inlines.empty?
        end

        def list(element, marks)
          items = elements(element).map do |item|
            blocks_of(item.name == "li" ? item : Element.new("li", {}, [item]), marks)
          end
          return if items.empty?

          ordered = element.name == "ol"
          start = Integer(element.attributes["start"], exception: false) || 1 if ordered
          Rich::List.new(ordered:, start:, items:)
        end

        def code(element)
          language = elements(element).find { |child| child.name == "code" }&.attributes&.[]("class")
          Rich::CodeBlock.new(text: raw_text(element).delete_prefix("\n").chomp,
                              language: language&.[](/lang(?:uage)?-(\S+)/, 1))
        end

        def raw_text(element)
          element.children.sum("") do |child|
            next child if child.is_a?(String)

            child.name == "br" ? "\n" : raw_text(child)
          end
        end

        def image(attributes)
          return unless attributes["src"]

          Rich::Image.new(src: attributes["src"], alt: attributes["alt"],
                          width: dimension(attributes["width"]), height: dimension(attributes["height"]))
        end

        def dimension(value) = value&.[](/\A\s*(\d+)/, 1)&.to_i

        def table(element, marks)
          rows = rows_of(element).filter_map do |row|
            cells = elements(row).select { |cell| %w[td th].include?(cell.name) }
            cells.map { |cell| cell(cell, marks) } unless cells.empty?
          end
          Rich::Table.new(rows:) unless rows.empty?
        end

        def rows_of(element)
          elements(element).flat_map do |child|
            next [child] if child.name == "tr"

            TreeBuilder::SECTIONS.include?(child.name) ? rows_of(child) : []
          end
        end

        def cell(element, marks)
          attributes = element.attributes
          align = attributes["align"]&.[](ALIGN, 1) || attributes["style"]&.[](TEXT_ALIGN, 1)
          Rich::Cell.new(header: element.name == "th", align: align&.downcase&.to_sym,
                         blocks: blocks_of(element, marks))
        end

        def marks_for(element)
          return MARKS[element.name] if MARKS.key?(element.name)
          return { link: element.attributes["href"] } if element.name == "a" && element.attributes["href"]
          return {} unless element.name == "span"

          style = element.attributes["style"].to_s
          marks = {}
          marks[:bold] = true if style.match?(/font-weight\s*:\s*(bold|[6-9]00)/i)
          marks[:italic] = true if style.match?(/font-style\s*:\s*italic/i)
          marks
        end

        def elements(element) = element.children.grep(TreeBuilder::Element)
      end
    end
  end
end
