# frozen_string_literal: true

module Stationery
  module Markdown
    class InlineParser
      # Brackets, inline and reference links, images and autolinks.
      module Links
        Bracket = Struct.new(:index, :image, :active, :position)

        INLINE = /
          \(\s*
          (?:<([^<>\n]*)>|((?:[^\s()\\]|\\.|\((?:[^\s()\\]|\\.)*\))*))
          (?:\s+(?:"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'|\((?:[^()\\]|\\.)*\)))?
          \s*\)
        /x
        REFERENCE = /\[((?:[^\[\]\\]|\\.){0,999})\]/
        AUTOLINK = %r{
          <((?:https?|mailto):[^\s<>]*)>
          |<([a-zA-Z0-9.!\#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?
            (?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?)*)>
        }x

        private

        def open_bracket(image: false)
          @brackets << Bracket.new(@nodes.size, image, true, @scanner.charpos)
          add(image ? "![" : "[")
        end

        def close_bracket
          bracket = @brackets.pop
          return add("]") unless bracket&.active

          href = inline_destination || reference(@source[bracket.position...(@scanner.charpos - 1)])
          return add("]") unless href

          children = @nodes.slice!(bracket.index..).drop(1)
          Emphasis.process(children)
          return @nodes << Nodes::Picture.new(href, children) if bracket.image

          @nodes << Nodes::Wrap.new({ link: href }, children)
          @brackets.each { |open| open.active = false unless open.image }
        end

        def inline_destination
          return unless @scanner.scan(INLINE)

          InlineParser.destination(@scanner[1] || @scanner[2])
        end

        def reference(label)
          position = @scanner.pos
          if @scanner.scan(REFERENCE)
            label = @scanner[1] unless @scanner[1].empty?
            href = @refs[InlineParser.label(label)]
            @scanner.pos = position unless href
            href
          else
            @refs[InlineParser.label(label)]
          end
        end

        def autolink
          url = @scanner[1] || "mailto:#{@scanner[2]}"
          @nodes << Nodes::Wrap.new({ link: url }, [Nodes::Text.new(@scanner[1] || @scanner[2])])
        end
      end
    end
  end
end
