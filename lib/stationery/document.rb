# frozen_string_literal: true

module Stationery
  # A whole PDF. Configure it at class level and describe it in view_template:
  #
  #   class Invoice < Stationery::Document
  #     page size: :a4, margin: 40
  #     font_family "Brand", regular: "Brand-Regular.ttf", bold: "Brand-Bold.ttf"
  #     default_text font: "Inter", size: 9
  #     metadata title: "Invoice"
  #     page_template { |page| box(at: [40, page.height - 30]) { text "#{page.number}/#{page.count}" } }
  #
  #     def view_template = text("Hello")
  #   end
  #
  #   Invoice.new.to_pdf # => "%PDF-1.7..."
  class Document < Component
    INFO_KEYS = { title: :Title, author: :Author, subject: :Subject, keywords: :Keywords, creator: :Creator,
                  producer: :Producer }.freeze

    class << self
      def config
        @config ||= if superclass.respond_to?(:config)
                      superclass.config.transform_values(&:dup)
                    else
                      { page: { size: :letter, margin: 36 }, families: {}, fallbacks: [], text: {}, metadata: {},
                        templates: [], regions: [], strict: false, tagged: false, images: {}, attachments: [] }
                    end
      end

      def page(size: :letter, margin: 36, layout: :portrait)
        config[:page] = { size:, margin:, layout: }
      end

      def font_family(name, **paths)
        config[:families][name.to_s] = Fonts::Family.build(name, **paths)
      end

      # Families tried, in order, for characters the text's own family has no
      # glyph for; bundled Inter is tried last.
      def font_fallbacks(*names)
        config[:fallbacks] = names.map(&:to_s)
      end

      def default_text(**options)
        config[:text] = config[:text].merge(options)
      end

      def metadata(**info)
        config[:metadata] = config[:metadata].merge(info)
      end

      # How viewers name the pages: a 1-based first page mapped to the range
      # starting there, `page_labels 1 => { style: :roman_lower }, 3 =>
      # { style: :decimal, start: 1, prefix: "A-" }`; see PDF::PageLabels.
      def page_labels(spec)
        PDF::PageLabels.entries(spec)
        config[:page_labels] = spec
      end

      # Embeds a file in every render: `attach_file "invoice.xml", xml,
      # mime: "text/xml", description: "Factur-X", relationship: :alternative`.
      # `relationship:` is :alternative, :source, :data, :supplement or
      # :unspecified (the /AFRelationship); `modified_at:` a Time.
      def attach_file(name, data, **)
        config[:attachments] << PDF::Attachments.build(name, data, **)
      end

      # Bitmap defaults: `max_ppi:` (300; nil disables) is the resolution
      # above twice of which a drawn image is reported as oversized, and
      # `downscale: true` resamples PNGs to it. See Layout::Image.
      def images(**options)
        config[:images] = config[:images].merge(options)
      end

      # Raise WarningsError instead of writing a PDF that produced warnings.
      def strict(value = true) # rubocop:disable Style/OptionalBooleanParameter
        config[:strict] = value
      end

      # Writes a tagged (accessible) PDF: a structure tree of headings,
      # paragraphs and figures, and headers and footers marked as artifacts.
      # Set `metadata lang:` and give images `alt:` text.
      def tagged(value = true) # rubocop:disable Style/OptionalBooleanParameter
        config[:tagged] = value
      end

      # Claims PDF/A-2b, PDF/A-3b and/or PDF/UA-1 (`conformance :pdf_a3b,
      # :pdf_ua1`) and writes what the level asks for; a render that cannot
      # keep the claim raises. See PDF::Conformance.
      def conformance(*levels)
        PDF::Conformance.for(levels)
        config[:conformance] = levels.flatten
      end

      # Makes every render a Factur-X / ZUGFeRD e-invoice: PDF/A-3b with the
      # invoice XML embedded and identified in XMP. `xml` is the Cross
      # Industry Invoice as a String, or a method name or block answering it
      # for the document being rendered: `factur_x(profile: :en16931) {
      # invoice.to_cii }`. See PDF::FacturX for profiles and options.
      def factur_x(xml = nil, **options, &block)
        source = xml || block
        raise ArgumentError, "factur_x needs the invoice XML, a method name or a block" unless source

        PDF::FacturX.profile(options.fetch(:profile, :en16931))
        PDF::FacturX.new(source, **options) if source.is_a?(String)
        config[:factur_x] = { xml: source, **options }
      end

      # Signs every render with a digital signature over the whole file:
      # `sign certificate: pem, key: pem, reason: "Approved"`. A value may be
      # a block or callable answering it for the document being rendered (a
      # method name for certificate:, key:, chain: and passphrase:), and a
      # block may answer all of them, so keys are read when they are needed.
      # `field:` names the signature_field it fills; without it the
      # signature is invisible. See PDF::Signature.
      def sign(**options, &block)
        raise ArgumentError, "sign needs certificate: and key:, or a block answering them" unless block || options.any?

        options = PDF::Signature.check(options)
        PDF::Signature.new(**options) unless block || PDF::Signature.deferred?(options)
        config[:sign] = block || options
      end

      # Encrypts every render with the standard security handler; see
      # PDF::Encryption::StandardSecurity for the options.
      def encrypt(**)
        config[:encrypt] = PDF::Encryption::StandardSecurity.options(**)
      end

      # Runs after pagination on every page. `layer: :background` paints under
      # the page's content.
      def page_template(layer: :foreground, &block)
        config[:templates] << [layer, block]
      end

      # Reserves space at the top of the pages `on:` matches and draws the
      # block there. Without `height:` the block is measured once, on the
      # first page that asks; pass `height:` when its content varies per page.
      def header(height: nil, gap: 8, on: :all, &block)
        config[:regions] << Region.new(slot: :header, height:, gap:, on: Regions.validate!(on), block:)
      end

      # Like header, at the bottom of the page; the block is bottom-aligned.
      def footer(height: nil, gap: 8, on: :all, &block)
        config[:regions] << Region.new(slot: :footer, height:, gap:, on: Regions.validate!(on), block:)
      end
    end

    # `fields` is every form field's name and value from the last render.
    attr_reader :warnings, :fields

    def page_options = self.class.config[:page]
    def metadata = self.class.config[:metadata]

    def to_pdf(target = nil, strict: self.class.config[:strict], debug: false, encrypt: self.class.config[:encrypt],
               tagged: self.class.config[:tagged], page_labels: self.class.config[:page_labels], attachments: [],
               xmp: metadata[:xmp] != false, conformance: self.class.config[:conformance],
               factur_x: self.class.config[:factur_x], sign: self.class.config[:sign])
      invoice = PDF::FacturX.for(factur_x, self)
      attachments = PDF::Attachments.merge(self.class.config[:attachments], attachments, invoice&.attachment)
      conformance = PDF::Conformance.for(invoice ? invoice.conformance(conformance) : conformance)
      conformance&.validate!(encrypt:, metadata:, attachments:)
      options = { strict:, debug:, encrypt:, tagged: tagged || conformance&.pdf_ua?, page_labels:, attachments:,
                  xmp: xmp || !conformance.nil?, conformance:, invoice:,
                  signature: PDF::Signature.for(sign, self) }
      Stationery.instrument("render.stationery", document: self.class.name) do |event|
        write(render_pdf(event, **options), target)
      end
    end

    # Used by page templates to build nodes into their own root.
    def build_with(builder)
      previous = @_builder
      @_builder = builder
      yield
    ensure
      @_builder = previous
    end

    # Builds a page template or region block into a fresh root node.
    def template_root(info, book:, &)
      builder = builder_for(book)
      build_with(builder) { instance_exec(info, &) }
      builder.root
    end

    private

    def builder_for(book) = Builder.new(book:, text: self.class.config[:text], images: self.class.config[:images])

    # The PDF bytes; `event` is the render.stationery payload it fills in.
    def render_pdf(event, strict:, debug:, tagged:, conformance:, **assembly)
      tagging = Tagging::Tree.new if tagged
      warnings = Warnings.new
      book = Fonts::FontBook.new(self.class.config[:families], fallbacks: self.class.config[:fallbacks], warnings:)
      builder = builder_for(book)
      Stationery.instrument("build.stationery", document: self.class.name) { call(builder) }
      resources = Resources.new
      pages = paginate(builder.root, book:, resources:, warnings:, debug:, tagging:)
      outline = builder.outline.resolve(Structure.resolve(pages, warnings:, resources:, book:, tagging:))
      tagging&.audit(pages, warnings, lang: metadata[:lang])
      @warnings = warnings
      conformance&.audit!(pages, resources:, warnings:)
      @fields = Forms::AcroForm.values(pages)
      event[:pages] = pages.size
      event[:warnings] = warnings.size
      raise WarningsError, warnings if strict && warnings.any?

      pdf = assemble(pages, resources, outline, tagging:, conformance:, **assembly)
      event[:bytes] = pdf.bytesize
      pdf
    end

    def assemble(pages, resources, outline, encrypt:, tagging:, page_labels:, attachments:, xmp:, conformance:,
                 invoice:, signature:)
      encryption = encrypt && PDF::Encryption::StandardSecurity.new(**encrypt)
      assembler = PDF::Assembler.new(pages:, resources:, info:, outline:, encryption:, tagging:, xmp:,
                                     lang: metadata[:lang], page_labels: PDF::PageLabels.entries(page_labels),
                                     attachments:, conformance:, xmp_extensions: invoice&.xmp_extensions || {},
                                     xmp_schemas: [invoice&.xmp_schema].compact, signature:)
      Stationery.instrument("write.stationery", document: self.class.name) do |event|
        assembler.render.tap { |pdf| event[:bytes] = pdf.bytesize }
      end
    end

    def paginate(root, book:, resources:, warnings:, debug:, tagging:)
      Stationery.instrument("paginate.stationery", document: self.class.name) do |event|
        regions = Regions.new(self.class.config[:regions], measure: region_measure(book))
        paginator = Layout::Paginator.new(resources:, page: page_options, warnings:, debug:, regions:, tagging:)
        paginator.paginate(root).tap do |pages|
          PageTemplates.new(self, book:, resources:, debug:, regions:, warnings:, tagging:).apply(pages)
          event[:pages] = pages.size
        end
      end
    end

    def region_measure(book)
      page = Page.new(**page_options)
      lambda do |region, number|
        info = PageInfo.new(number, number, page.width, page.height, page.margin, page.margin_box)
        template_root(info, book:, &region.block).measure(page.margin_box.width)
      end
    end

    def info
      metadata.except(:lang, :xmp).to_h do |key, value|
        [INFO_KEYS.fetch(key.to_sym) { key.to_sym }, value.is_a?(Array) ? value.join(", ") : value]
      end
    end

    def write(pdf, target)
      if target.respond_to?(:write)
        target.write(pdf)
      elsif target
        File.binwrite(target.to_s, pdf)
      end
      pdf
    end
  end
end
