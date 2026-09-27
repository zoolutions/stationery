# frozen_string_literal: true

module Stationery
  module Tagging
    # Writes a Tree as the catalog's /StructTreeRoot: one StructElem per
    # element that holds content, and the /ParentTree mapping each page's
    # /StructParents key to its elements by MCID.
    class Writer
      def initialize(tree, pages:, refs:)
        @tree = tree
        @page_refs = pages.zip(refs).to_h.compare_by_identity
        @keys = pages.select { |page| tree.marked(page).any? }.each_with_index.to_h.compare_by_identity
        @annotations = {}.compare_by_identity
      end

      # An annotation's entries: the /StructParent key of its element, when it
      # belongs to one. `ref` is the annotation's reference, for the /OBJR.
      def annotation(link, ref)
        return {} unless link[:tag]

        @annotations[link] = [ref, @keys.size + @annotations.size]
        { StructParent: @annotations[link][1] }
      end

      # The page dictionary's entries: its parent tree key, when it has one.
      def page_entries(page)
        key = @keys[page]
        key ? { StructParents: key } : {}
      end

      # Writes the tree and returns the catalog entries pointing at it.
      def write(writer)
        root = writer.reserve
        @refs = {}.compare_by_identity
        reserve(writer, @tree.root)
        @refs.each_key { |element| writer.set(@refs[element], dictionary(element, root)) }
        writer.set(root, { Type: :StructTreeRoot, K: [@refs[@tree.root]], ParentTree: { Nums: parent_tree },
                           ParentTreeNextKey: @keys.size + @annotations.size })
        { MarkInfo: { Marked: true }, StructTreeRoot: root }
      end

      private

      def reserve(writer, element)
        @refs[element] = writer.reserve
        element.elements.each { |kid| reserve(writer, kid) unless kid.empty? }
      end

      def dictionary(element, root)
        page = element.marked_content.first&.page
        {
          Type: :StructElem, S: element.type, P: element.parent ? @refs[element.parent] : root,
          Pg: page && @page_refs[page], K: element.kids.filter_map { |kid| kid_entry(kid, page) },
          Alt: element.alt && PDF::TextString.new(element.alt),
          A: attributes(element)
        }.compact
      end

      def kid_entry(kid, page)
        case kid
        when Element then @refs[kid]
        when MarkedContent
          kid.page.equal?(page) ? kid.mcid : { Type: :MCR, Pg: @page_refs[kid.page], MCID: kid.mcid }
        when ObjectRef
          ref, = @annotations[kid.annotation]
          ref && { Type: :OBJR, Obj: ref, Pg: @page_refs[kid.page] }
        end
      end

      def attributes(element)
        list = element.attributes.map { |owner, values| { O: owner, **values } }
        list.size > 1 ? list : list.first
      end

      def parent_tree
        @keys.flat_map { |page, key| [key, @tree.marked(page).map { |element| @refs[element] }] } +
          @annotations.flat_map { |link, (_, key)| [key, @refs[link[:tag]]] }
      end
    end
  end
end
