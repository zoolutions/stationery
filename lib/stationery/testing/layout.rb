# frozen_string_literal: true

require_relative "page_reader"

module Stationery
  module Testing
    # What Inspector#layout answers: what is on each page and what the file
    # says of itself, as plain data in a stable order, so two renders of one
    # document compare equal and a changed one differs where it changed.
    #
    # Places are in points from the top-left corner of the page, as the
    # gem's API speaks, rounded to a tenth. The dates of the file are left
    # out: they change with every render.
    class Layout
      INFO = { Title: :title, Author: :author, Subject: :subject, Keywords: :keywords, Creator: :creator,
               Producer: :producer }.freeze
      FIELD_TYPES = { Tx: :text, Ch: :choice, Sig: :signature }.freeze
      # The Radio and Pushbutton flags of a button field's /Ff.
      RADIO = 1 << 15
      PUSHBUTTON = 1 << 16
      ALIGNMENTS = %i[left center right].freeze
      # The font size and colour operator of a /DA: "/F1 10 Tf 0.5 g".
      DEFAULT_APPEARANCE = /([\d.]+) Tf\s+((?:-?[\d.]+\s+)+)(g|rg|k)\s*\z/

      def initialize(inspector)
        @inspector = inspector
        @reader = inspector.reader
        @objects = @reader.objects
      end

      def to_h
        { metadata:, conformance: @inspector.conformance, tagged: @inspector.tagged?,
          print: @inspector.print_preferences, outline: outline(catalog[:Outlines]),
          attachments:, signatures:, structure: @inspector.structure,
          warnings: @inspector.warnings.map(&:message), pages: }
      end

      private

      def catalog = @objects.deref_hash(@objects.trailer[:Root])

      def metadata
        info = @inspector.metadata || {}
        found = INFO.filter_map { |key, name| [name, decode(info[key])] if info[key] }.to_h
        found[:lang] = @inspector.lang if @inspector.lang
        invoice = @inspector.factur_x
        found[:factur_x] = invoice[:profile] if invoice
        found
      end

      def attachments
        @inspector.attachments.map do |file|
          file.slice(:name, :mime, :relationship, :description).merge(bytes: file[:bytes].bytesize).compact
        end
      end

      def signatures
        @inspector.signatures.map { |signature| signature.slice(:field, :name, :signer, :valid) }
      end

      def pages
        labels = @inspector.page_labels
        @reader.pages.each_with_index.map do |page, index|
          left, bottom, right, top = page.rectangles[:MediaBox].to_a
          content = PageReader.read(page)
          annots = annotations(page)
          { number: index + 1, label: labels[index], width: round(right - left), height: round(top - bottom),
            text: content.text, images: content.images, links: links(annots, left, top),
            fields: fields(annots, left, top) }
        end
      end

      def annotations(page)
        Array(@objects.deref_array(page.attributes[:Annots])).map { |ref| @objects.deref_hash(ref) }
      end

      def links(annots, left, top)
        annots.select { |annot| annot[:Subtype] == :Link }.map do |annot|
          action = @objects.deref_hash(annot[:A]) || {}
          target = if action[:S] == :URI then { uri: decode(action[:URI]) }
                   else destination(annot[:Dest] || (action[:D] if action[:S] == :GoTo))
                   end
          rect(annot, left, top).merge(target)
        end
      end

      def destination(dest)
        dest = @objects.deref(dest)
        return { name: decode(dest.to_s) } unless dest.is_a?(Array)

        index = @objects.page_references.index(dest.first)
        return {} unless index

        top = dest[3] if dest[1] == :XYZ
        { page: index + 1, top: top && round(@reader.page(index + 1).rectangles[:MediaBox].to_a[3] - top) }.compact
      end

      def fields(annots, left, top)
        annots.select { |annot| annot[:Subtype] == :Widget }.map do |widget|
          chain = parents(widget)
          name = chain.filter_map { |field| field[:T] && decode(field[:T]) }.reverse.join(".")
          type = inherit(chain, :FT)
          { name:, type: field_type(type, inherit(chain, :Ff).to_i), value: value(inherit(chain, :V)),
            **rect(widget, left, top), state: state(widget), **style(chain) }.compact
        end
      end

      # The alignment, size (:auto for 0) and colour a field's value is
      # drawn in; nothing for a field without variable text.
      def style(chain)
        match = DEFAULT_APPEARANCE.match(inherit(chain, :DA).to_s) or return {}

        size, values, operator = match.captures
        values = values.split.map(&:to_f)
        values *= 3 if operator == "g"
        { align: ALIGNMENTS.fetch(inherit(chain, :Q).to_i, :left), font_size: size.to_f.zero? ? :auto : number(size),
          color: Monochrome.hex(Color.new(operator == "k" ? :cmyk : :rgb, values)) }
      end

      def number(text) = text.include?(".") ? text.to_f : text.to_i

      def parents(widget)
        chain = [widget]
        chain << @objects.deref_hash(chain.last[:Parent]) while chain.last[:Parent] && chain.size < 32
        chain
      end

      def inherit(chain, key) = chain.find { |field| field.key?(key) }&.fetch(key)

      def field_type(type, flags)
        return FIELD_TYPES[type] || type unless type == :Btn
        return :radio if flags.anybits?(RADIO)

        flags.anybits?(PUSHBUTTON) ? :button : :checkbox
      end

      def value(value)
        value = @objects.deref(value)
        case value
        when String then decode(value)
        when Symbol then value.to_s
        when Hash then "signed"
        when Array then value.map { |one| value(one) }
        end
      end

      # The name a check box or radio button has when it is on.
      def state(widget)
        normal = @objects.deref(@objects.deref_hash(widget[:AP])&.fetch(:N, nil))
        return unless normal.is_a?(Hash) && normal.keys.all?(Symbol) && normal.key?(:Off)

        (normal.keys - [:Off]).first&.to_s
      end

      def rect(annot, left, top)
        x1, y1, x2, y2 = @objects.deref_array(annot[:Rect]).map { |value| @objects.deref(value).to_f }
        { x: round([x1, x2].min - left), y: round(top - [y1, y2].max), width: round((x2 - x1).abs),
          height: round((y2 - y1).abs) }
      end

      def outline(root)
        root = @objects.deref_hash(root)
        entries = []
        item = root && @objects.deref_hash(root[:First])
        while item
          dest = item[:Dest] || @objects.deref_hash(item[:A])&.fetch(:D, nil)
          entries << { title: decode(item[:Title]), **destination(dest), children: outline(item) }
          item = @objects.deref_hash(item[:Next])
        end
        entries
      end

      def round(value) = value.to_f.round(1)

      def decode(text)
        text = text.to_s
        return text.dup.force_encoding(Encoding::UTF_8) unless text.b.start_with?(Inspector::UTF16_BOM)

        text.b.byteslice(2..).force_encoding(Encoding::UTF_16BE).encode(Encoding::UTF_8)
      end
    end
  end
end
