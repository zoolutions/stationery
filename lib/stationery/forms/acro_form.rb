# frozen_string_literal: true

module Stationery
  module Forms
    # Collects the widgets pages place and writes the document's interactive
    # form: one field per name, parent fields for dotted names, the shared
    # Helvetica and ZapfDingbats resources and the catalog's /AcroForm.
    class AcroForm
      FONTS = { Helv: :Helvetica, ZaDb: :ZapfDingbats }.freeze

      # A widget placed on a page: its field, PDF-space rect, page and the
      # reference the page's /Annots already points at.
      Widget = Data.define(:field, :rect, :page, :ref)

      # A name segment: widgets when it is a field, children when a group.
      Node = Struct.new(:name, :widgets, :children)

      # { full name => value } for every field widget on `pages`.
      def self.values(pages)
        pages.flat_map(&:annotations).each_with_object({}) do |annotation, values|
          field = annotation[:widget] or next
          value = field.data_value
          values[field.name] = value unless value.nil? && values.key?(field.name)
        end
      end

      def initialize(writer)
        @writer = writer
        @widgets = []
      end

      # Reserves the widget annotation for `field` at `rect` on `page`.
      def add(field, rect, page)
        ref = @writer.reserve
        @widgets << Widget.new(field, rect, page, ref)
        ref
      end

      # Writes every field; returns the /AcroForm dictionary, or nil without
      # fields.
      def write
        return if @widgets.empty?

        @fonts = FONTS.transform_values { |base| @writer.add(font(base)) }
        fields = tree.children.values.map { |node| write_node(node, nil) }
        { Fields: fields, NeedAppearances: true, DA: "/#{Field::FONT} 0 Tf 0 g", DR: { Font: @fonts } }
      end

      private

      def font(base)
        font = { Type: :Font, Subtype: :Type1, BaseFont: base }
        base == :Helvetica ? font.merge(Encoding: :WinAnsiEncoding) : font
      end

      def tree
        root = Node.new(nil, [], {})
        @widgets.each do |widget|
          node = widget.field.segments.reduce(root) do |parent, segment|
            parent.children[segment] ||= Node.new(segment, [], {})
          end
          node.widgets << widget
        end
        root.children.each_value { |node| validate(node, node.name) }
        root
      end

      def validate(node, path)
        if node.widgets.any? && node.children.any?
          raise ArgumentError, "field name #{path.inspect} is both a field and a group"
        end
        if node.widgets.map { |widget| widget.field.kind }.uniq.size > 1
          raise ArgumentError, "field name #{path.inspect} is used by fields of different kinds"
        end

        node.children.each_value { |child| validate(child, "#{path}.#{child.name}") }
      end

      def write_node(node, parent)
        own = { T: PDF::TextString.new(node.name) }
        own[:Parent] = parent if parent
        return write_field(node.widgets, own) if node.widgets.any?

        ref = @writer.reserve
        @writer.set(ref, own.merge(Kids: node.children.values.map { |child| write_node(child, ref) }))
      end

      # One widget is merged with its field; several become the field's kids.
      def write_field(widgets, own)
        field = widgets.first.field
        return @writer.set(widgets.first.ref, own.merge(field.field_entries, widget(widgets.first))) if widgets.one?

        ref = @writer.reserve
        widgets.each { |kid| @writer.set(kid.ref, widget(kid).merge(Parent: ref)) }
        @writer.set(ref, own.merge(field.field_entries, Kids: widgets.map(&:ref)))
      end

      def widget(widget)
        x1, y1, x2, y2 = widget.rect
        entries = widget.field.widget_entries(x2 - x1, y2 - y1, @fonts)
        normal = entries.dig(:AP, :N)
        normal = normal.is_a?(Hash) ? normal.transform_values { |stream| @writer.add(stream) } : @writer.add(normal)
        entries.merge(AP: { N: normal }, Rect: widget.rect, P: widget.page)
      end
    end
  end
end
