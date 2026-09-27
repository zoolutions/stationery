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

        def flatten(nodes, marks = {}, out = [])
          nodes.each do |node|
            case node
            when Text then out << Rich::Inline.new(text: node.text, marks:)
            when Delimiter then out << Rich::Inline.new(text: node.char * node.remaining, marks:)
            when Code then out << Rich::Inline.new(text: node.text, marks: marks.merge(code: true))
            when Break then out << Rich::Inline.break
            when Wrap then flatten(node.children, marks.merge(node.marks), out)
            when Picture then out << picture(node)
            end
          end
          out
        end

        def picture(node) = Rich::Image.new(src: node.src, alt: plain(node.children), width: nil, height: nil)

        def plain(nodes)
          flatten(nodes).sum("") { |item| item.is_a?(Rich::Image) ? item.alt.to_s : item.text }
        end
      end
    end
  end
end
