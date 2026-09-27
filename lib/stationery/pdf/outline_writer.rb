# frozen_string_literal: true

module Stationery
  module PDF
    # Writes outline items as the /Outlines tree. Each item nests under the
    # nearest earlier item of a shallower level, so a level jump (1 → 3) or a
    # leading level-2 item still lands somewhere sensible.
    class OutlineWriter
      Node = Data.define(:item, :ref, :children) do
        def open? = item.nil? || item.open
      end

      def initialize(writer, items, page_refs)
        @writer = writer
        @items = items
        @page_refs = page_refs
      end

      # The /Outlines root reference, or nil when there is nothing to write.
      def write
        return if @items.empty?

        root = tree
        write_children(root)
        @writer.set(root.ref, { Type: :Outlines, First: root.children.first.ref, Last: root.children.last.ref,
                                Count: visible(root) })
      end

      private

      def tree
        root = Node.new(nil, @writer.reserve, [])
        stack = []
        @items.each do |item|
          stack.pop while stack.any? && stack.last.item.level >= item.level
          node = Node.new(item, @writer.reserve, [])
          (stack.last || root).children << node
          stack << node
        end
        root
      end

      def write_children(parent)
        parent.children.each_with_index do |node, index|
          write_children(node)
          siblings = { Prev: index.positive? ? parent.children[index - 1].ref : nil,
                       Next: parent.children[index + 1]&.ref }
          @writer.set(node.ref, dictionary(node, parent).merge(siblings).compact)
        end
      end

      def dictionary(node, parent)
        dest = node.item.dest
        {
          Title: TextString.new(node.item.title), Parent: parent.ref,
          First: node.children.first&.ref, Last: node.children.last&.ref, Count: count(node),
          Dest: [@page_refs.fetch(dest.page), :XYZ, nil, dest.top, nil]
        }
      end

      # Items shown when `node` is expanded: its children plus the visible
      # descendants of each open child.
      def visible(node) = node.children.sum { |child| 1 + (child.open? ? visible(child) : 0) }

      def count(node)
        return if node.children.empty?

        node.open? ? visible(node) : -visible(node)
      end
    end
  end
end
