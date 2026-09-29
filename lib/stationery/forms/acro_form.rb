# frozen_string_literal: true

module Stationery
  module Forms
    # Collects the widgets pages place and writes the document's interactive
    # form: one field per name, parent fields for dotted names, the fonts the
    # appearances draw with as default resources and the catalog's /AcroForm.
    #
    # The appearances themselves need no standard font: text is set in the
    # document's embedded fonts and marks are paths. Only a form that asks
    # viewers to regenerate appearances lists ZapfDingbats, which is what
    # they redraw a check box or radio button's /MK caption with.
    #
    # A `signature:` (a PDF::Signature) becomes the value of the signature
    # field it names, or of a field of its own whose widget nobody sees.
    class AcroForm
      SYMBOLS = { ZaDb: { Type: :Font, Subtype: :Type1, BaseFont: :ZapfDingbats }.freeze }.freeze
      # SignaturesExist and AppendOnly: what a signed form tells viewers.
      SIGNED = 3

      # A widget placed on a page: its field, appearance, PDF-space rect, page
      # and the reference the page's /Annots already points at.
      Widget = Data.define(:field, :appearance, :rect, :page, :ref, :extra)

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

      # `fonts` are the document's embedded fonts by resource name.
      # `need_appearances: false` leaves out the flag asking viewers to
      # regenerate every appearance (PDF/A and PDF/UA forbid it, and a
      # signed file must not be redrawn).
      def initialize(writer, fonts: {}, need_appearances: true, signature: nil)
        @writer = writer
        @embedded = fonts
        @need_appearances = need_appearances
        @signature = signature
        @widgets = []
      end

      # Reserves the widget annotation (a page annotation holding the field
      # as :widget, its :appearance and :rect) on `page`. `extra` entries for
      # the widget dictionary may be computed from its reference (a tagged
      # PDF's /StructParent).
      def add(annotation, page)
        ref = @writer.reserve
        appearance = annotation[:appearance] || Appearance.new(annotation[:widget], *size_of(annotation[:rect]))
        @widgets << Widget.new(annotation[:widget], appearance, annotation[:rect], page, ref,
                               block_given? ? yield(ref) : {})
        ref
      end

      # Reserves the widget of a signature that fills no field: without a
      # size or an appearance, printable and locked, on `page`. `taken` are
      # the names the document's fields use.
      def sign(page, taken: [])
        name = (1..).lazy.map { |number| "Signature#{number}" }.find { |candidate| !taken.include?(candidate) }
        ref = @writer.reserve
        @widgets << Widget.new(Field.new(:signature, name, label: ""), nil, [0, 0, 0, 0], page, ref, {})
        ref
      end

      # Writes every field; returns the /AcroForm dictionary, or nil without
      # fields. /DR lists the fonts the appearances use, /DA selects the first.
      def write
        @signed = signed
        return if @widgets.empty?

        @fonts = fonts
        fields = tree.children.values.map { |node| write_node(node, nil) }
        form = { Fields: fields }
        form[:SigFlags] = SIGNED if @signed
        form[:NeedAppearances] = true if @need_appearances
        form[:DA] = "/#{@fonts.keys.first} 0 Tf 0 g" if @fonts.any?
        resources = @fonts.merge(symbols)
        form[:DR] = { Font: resources } if resources.any?
        form
      end

      private

      def size_of(rect) = [rect[2] - rect[0], rect[3] - rect[1]]

      # The signature dictionary's reference, once the field it fills is
      # known to exist; nil without a signature.
      def signed
        return unless @signature
        return @writer.add_unpacked(@signature.dictionary) if @widgets.any? { |widget| signs?(widget) }

        raise ArgumentError, %(sign field: names "#{@signature.field}", but the document has no such signature_field)
      end

      def signs?(widget)
        return widget.appearance.nil? if @signature.invisible?

        widget.field.kind == :signature && widget.field.name == @signature.field
      end

      def symbols
        return {} unless @need_appearances && @widgets.any? { |widget| widget.field.type == :Btn }

        SYMBOLS.transform_values { |font| @writer.add(font) }
      end

      # The fonts the appearances name: the embedded ones, and the standard
      # Helvetica when a field without a font book draws with it.
      def fonts
        names = @widgets.flat_map { |widget| widget.appearance&.font_names.to_a }.uniq
        names.to_h do |name|
          [name, @embedded.fetch(name) { @writer.add(Standard::FONT) }]
        end
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

      # One widget is merged with its field; several, or radios, become the
      # field's kids. A radio group's value is its checked choice.
      def write_field(widgets, own)
        field = widgets.first.field
        default_appearance = widgets.first.appearance&.default_appearance
        value = @signed && signs?(widgets.first) ? { V: @signed } : {}
        unless field.radio? || !widgets.one?
          entries = field.field_entries(default_appearance:)
          return @writer.set(widgets.first.ref, own.merge(entries, value, widget(widgets.first)))
        end

        ref = @writer.reserve
        choice = field.radio? ? widgets.map(&:field).find(&:checked?)&.on_state || :Off : nil
        widgets.each { |kid| @writer.set(kid.ref, widget(kid, choice).merge(Parent: ref)) }
        entries = choice ? field.field_entries(choice, default_appearance:) : field.field_entries(default_appearance:)
        @writer.set(ref, own.merge(entries, value, Kids: widgets.map(&:ref)))
      end

      def widget(widget, group_value = nil)
        unless widget.appearance
          return { Type: :Annot, Subtype: :Widget, F: PDF::Signature::INVISIBLE, Rect: widget.rect, P: widget.page }
        end

        state = group_value && (widget.field.on_state == group_value ? group_value : :Off)
        entries = widget.field.widget_entries(widget.appearance, @fonts, state:)
        normal = entries.dig(:AP, :N)
        normal = normal.is_a?(Hash) ? normal.transform_values { |stream| @writer.add(stream) } : @writer.add(normal)
        entries.merge(AP: { N: normal }, Rect: widget.rect, P: widget.page, **widget.extra)
      end
    end
  end
end
