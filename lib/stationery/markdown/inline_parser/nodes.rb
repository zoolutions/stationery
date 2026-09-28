# frozen_string_literal: true

module Stationery
  module Markdown
    class InlineParser
      # The intermediate inline tree: text, delimiter runs, code, breaks, and mark or image wrappers.
      module Nodes
        Text = Struct.new(:text)
        Delimiter = Struct.new(:char, :remaining, :opener, :closer)
        Code = Data.define(:text)
        Break = Data.define
        Wrap = Data.define(:marks, :children)
        Picture = Data.define(:src, :children)

        module_function

        # The tree as a flat list of inlines, each with the marks of the wraps around it. Walked with
        # a stack of its own, not by recursion: emphasis nests as deep as its author types asterisks.
        def flatten(nodes, marks = {})
          out = []
          pending = [[nodes, 0, marks]]
          until pending.empty?
            level = pending.last
            node = level[0][level[1]]
            next pending.pop unless node

            level[1] += 1
            next pending << [node.children, 0, level[2].merge(node.marks)] if node.is_a?(Wrap)

            out << inline(node, level[2])
          end
          out
        end

        def inline(node, marks)
          case node
          when Text then Rich::Inline.new(text: node.text, marks:)
          when Delimiter then Rich::Inline.new(text: node.char * node.remaining, marks:)
          when Code then Rich::Inline.new(text: node.text, marks: marks.merge(code: true))
          when Break then Rich::Inline.break
          when Picture then picture(node)
          end
        end

        def picture(node) = Rich::Image.new(src: node.src, alt: plain(node.children), width: nil, height: nil)

        def plain(nodes)
          flatten(nodes).sum("") { |item| item.is_a?(Rich::Image) ? item.alt.to_s : item.text }
        end
      end
    end
  end
end
