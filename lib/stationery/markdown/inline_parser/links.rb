# frozen_string_literal: true

module Stationery
  module Markdown
    class InlineParser
      # Brackets, inline and reference links, images and autolinks. At most OPEN brackets wait for
      # their `]` at once (the oldest gives way), and a link label is at most LABEL characters as
      # CommonMark has it, so neither nesting nor the work per `]` grows with the input. A bracket's
      # `position` is in bytes, which the scanner knows without counting characters.
      module Links
        Bracket = Struct.new(:index, :image, :active, :position)
        OPEN = 64
        LABEL = 999

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
          @brackets.shift if @brackets.size >= OPEN
          @brackets << Bracket.new(@nodes.size, image, true, @scanner.pos)
          add(image ? "![" : "[")
        end

        def close_bracket
          bracket = @brackets.pop
          return add("]") unless bracket&.active

          href = inline_destination || reference(bracket.position...(@scanner.pos - 1))
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

        # The target of `[text][label]`, `[text][]` or `[text]`, `span` being where the text lies.
        def reference(span)
          position = @scanner.pos
          label = @scanner[1] if @scanner.scan(REFERENCE) && !@scanner[1].empty?
          href = defined_as(label || (@source.byteslice(span) if span.size <= LABEL * 4))
          @scanner.pos = position unless href
          href
        end

        def defined_as(label) = label && label.length <= LABEL && @refs[InlineParser.label(label)]

        def autolink
          url = @scanner[1] || "mailto:#{@scanner[2]}"
          @nodes << Nodes::Wrap.new({ link: url }, [Nodes::Text.new(@scanner[1] || @scanner[2])])
        end
      end
    end
  end
end
