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
                        templates: [], regions: [], strict: false, tagged: false, incremental: false, images: {},
                        attachments: [], shaping: {}, print: {}, missing_glyphs: :raise }
                    end
      end

      # `size:` is a name of Page::SIZES, [width, height] in points or with
      # units (["102mm", "74mm"], "4in x 6in"); `margin:` takes points or
      # lengths ("3mm") the way `padding:` takes its sides. Both are checked
      # here, so a size that cannot be read raises where it is written.
      def page(size: :letter, margin: 36, layout: :portrait)
        config[:page] = { size: Page::Format.size(size), margin: Page::Format.margin(margin), layout: }
      end

      def font_family(name, **paths)
        config[:families][name.to_s] = Fonts::Family.build(name, **paths)
      end

      # Families tried, in order, for characters the text's own family has no
      # glyph for; bundled Inter is tried last.
      def font_fallbacks(*names)
        config[:fallbacks] = names.map(&:to_s)
      end

      # Hands every text to `shaper` to place its glyphs: the hook for
      # complex scripts (Arabic, Indic, Thai, …) and right-to-left text, which
      # stationery does not shape itself. Anything answering `call(text, font,
      # **options)`; see Shaper. `shaper nil` takes an inherited one away.
      def shaper(shaper)
        config[:shaping] = { shaper: Shaper.check(shaper) }
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

      # How the document asks to be printed: `print scaling: :none, copies: 2,
      # pick_tray_by_size: true, duplex: :simplex, pages: 1..3, dialog:
      # :on_open`. Hints a viewer may follow, added to the inherited ones; a
      # nil takes one away. This is not Kernel#print, which a document's
      # methods still call. See PDF::PrintHints.
      def print(**hints)
        config[:print] = config[:print].merge(PDF::PrintHints.options(hints)).compact
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
      # `downscale: true` resamples PNGs and WebPs to it. See Layout::Image.
      def images(**options)
        config[:images] = config[:images].merge(options)
      end

      # Raise WarningsError instead of writing a PDF that produced warnings.
      def strict(value = true) # rubocop:disable Style/OptionalBooleanParameter
        config[:strict] = value
      end

      # Writes each page as soon as it is painted and lets go of it, so a long
      # document peaks far lower: see #to_pdf for what the file looks like and
      # which renders take the usual path all the same.
      def incremental(value = true) # rubocop:disable Style/OptionalBooleanParameter
        config[:incremental] = value
      end

      # Writes a tagged (accessible) PDF: a structure tree of headings,
      # paragraphs and figures, and headers and footers marked as artifacts.
      # Set `metadata lang:` and give images `alt:` text.
      def tagged(value = true) # rubocop:disable Style/OptionalBooleanParameter
        config[:tagged] = value
      end

      # Claims PDF/A-2b, PDF/A-3b and/or PDF/UA-1 (`conformance :pdf_a3b,
      # :pdf_ua1`) and writes what the level asks for; a render that cannot
      # keep the claim raises. See PDF::Conformance. `missing_glyphs:` is what
      # a character no font has does: :raise (the default), or :replace to
      # draw it as the first of U+FFFD, U+25A1 and "?" its font has.
      def conformance(*levels, missing_glyphs: :raise)
        PDF::Conformance.for(levels, missing_glyphs:)
        config[:conformance] = levels.flatten
        config[:missing_glyphs] = missing_glyphs
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
      # signature is invisible. `timestamp:` is the URL of a time-stamping
      # authority whose token makes it PAdES baseline B-T. See PDF::Signature.
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

    # The PDF as a binary String, also written to `target` when given: a
    # path or an IO. With a block the file is streamed to it in pieces as it
    # is written and the call answers the number of bytes: the first bytes
    # leave before the last page is assembled and no output buffer is built.
    #
    # `incremental: true` writes each page's body as soon as the page is
    # painted and lets go of its operators, to a block before the next page is
    # painted. The file is the same document with its objects in another
    # order, and what is painted once every page is known (headers, footers,
    # page templates, contents page numbers) is a content stream of its own.
    # A render that must be checked before anything is written takes the
    # usual path instead: one with `conformance:` or `sign:`, and a `strict`
    # one that goes to a block.
    #
    # `print:` are print hints laid over those of the class (see .print): a
    # nil takes one away, and `print: nil` or `false` all of them.
    def to_pdf(target = nil, strict: self.class.config[:strict], debug: false, encrypt: self.class.config[:encrypt],
               tagged: self.class.config[:tagged], page_labels: self.class.config[:page_labels], attachments: [],
               xmp: metadata[:xmp] != false, conformance: self.class.config[:conformance],
               factur_x: self.class.config[:factur_x], sign: self.class.config[:sign],
               shaper: self.class.config[:shaping][:shaper], incremental: self.class.config[:incremental],
               print: PDF::PrintHints::NONE, missing_glyphs: self.class.config[:missing_glyphs], &block)
      invoice = PDF::FacturX.for(factur_x, self)
      attachments = PDF::Attachments.merge(self.class.config[:attachments], attachments, invoice&.attachment)
      conformance = PDF::Conformance.for(invoice ? invoice.conformance(conformance) : conformance, missing_glyphs:)
      print = PDF::PrintHints.merge(self.class.config[:print], print)
      conformance&.validate!(encrypt:, metadata:, attachments:, print:)
      signature = PDF::Signature.for(sign, self)
      raise ArgumentError, "a signed document cannot be streamed to a block: sign needs the whole file" if
        signature && block
      raise ArgumentError, "pass a target or a block, not both" if target && block

      options = { strict:, debug:, encrypt:, tagged: tagged || conformance&.pdf_ua?, page_labels:, attachments:,
                  xmp: xmp || !conformance.nil?, conformance:, invoice:, signature:, sink: block, shaper:, print:,
                  incremental: incremental && !conformance && !signature && !(strict && block) }
      Stationery.instrument("render.stationery", document: self.class.name) do |event|
        block ? render_pdf(event, **options) : write(render_pdf(event, **options), target)
      end
    end

    # Builds the document, lays it out and paints it on the canvases that
    # `canvases` makes (see PDF::Canvases and Canvas::Interface): what a
    # render does before its output is written, whatever the output is.
    # Answers the pages, hands each to `each_page` as soon as its content is
    # painted, and yields the bookmarks whose anchors were painted.
    def paint_on(canvases, warnings: Warnings.new, shaper: self.class.config[:shaping][:shaper], each_page: nil,
                 stand_ins: false)
      book = book_for(warnings, shaper, stand_ins)
      builder = builder_for(book)
      Stationery.instrument("build.stationery", document: self.class.name) { call(builder) }
      pages = paginate(builder, canvases, each_page, book:, warnings:)
      destinations = Structure.resolve(pages, warnings:, book:, canvases:)
      yield builder.outline.resolve(destinations) if block_given?
      @warnings = warnings
      pages
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

    def book_for(warnings, shaper, stand_ins)
      Fonts::FontBook.new(self.class.config[:families], fallbacks: self.class.config[:fallbacks], warnings:,
                                                        shaper:, language: metadata[:lang], stand_ins:)
    end

    # The PDF bytes; `event` is the render.stationery payload it fills in.
    def render_pdf(event, strict:, debug:, tagged:, conformance:, shaper:, incremental:, **assembly)
      tagging = Tagging::Tree.new if tagged
      warnings = Warnings.new
      resources = Resources.new
      sealer = sealer_for(incremental, conformance, **assembly)
      outline = nil
      canvases = PDF::Canvases.new(resources, debug, tagging, warnings)
      stand_ins = conformance&.replace_missing_glyphs? || false
      pages = paint_on(canvases, warnings:, shaper:, each_page: sealer, stand_ins:) { |bookmarks| outline = bookmarks }
      tagging&.audit(pages, warnings, lang: metadata[:lang])
      conformance&.audit!(pages, resources:, warnings:)
      @fields = Forms::AcroForm.values(pages)
      event[:pages] = pages.size
      event[:warnings] = warnings.size
      raise WarningsError, warnings if strict && warnings.any?

      pdf = assemble(pages, resources, outline, tagging:, conformance:, writer: sealer.writer, **assembly)
      event[:bytes] = byte_count(pdf)
      pdf
    end

    def assemble(pages, resources, outline, encrypt:, tagging:, page_labels:, attachments:, xmp:, conformance:,
                 invoice:, signature:, sink:, writer:, print:)
      assembler = PDF::Assembler.new(pages:, resources:, info:, outline:, tagging:, xmp:, writer:,
                                     encryption: writer ? nil : encryption(encrypt),
                                     lang: metadata[:lang], page_labels: PDF::PageLabels.entries(page_labels),
                                     attachments:, conformance:, xmp_extensions: invoice&.xmp_extensions || {},
                                     xmp_schemas: [invoice&.xmp_schema].compact, signature:, sink:, print:)
      Stationery.instrument("write.stationery", document: self.class.name) do |event|
        assembler.render.tap { |pdf| event[:bytes] = byte_count(pdf) }
      end
    end

    def byte_count(pdf) = pdf.is_a?(String) ? pdf.bytesize : pdf
    def encryption(options) = options && PDF::Encryption::StandardSecurity.new(**options)

    # What closes each page as it is painted. An incremental render writes
    # every body at once, to the writer the rest of the file follows on; any
    # other seals the pages nothing paints on again (no header, footer or
    # page template, and no conformance audit to read them).
    def sealer_for(incremental, conformance, encrypt:, sink:, **)
      return PDF::PageSealer.new(writer: PDF::Writer.new(encryption: encryption(encrypt), sink:)) if incremental

      config = self.class.config
      PDF::PageSealer.new(final: conformance.nil? && config[:templates].empty? && config[:regions].empty?)
    end

    # Takes the root from the builder as it hands it to the paginator, so
    # nothing here keeps the nodes of a page that has been painted.
    def paginate(builder, canvases, each_page, book:, warnings:)
      Stationery.instrument("paginate.stationery", document: self.class.name) do |event|
        regions = Regions.new(self.class.config[:regions], measure: region_measure(book))
        paginator = Layout::Paginator.new(canvases:, page: page_options, warnings:, regions:)
        paginator.paginate(builder.release) { |page| each_page&.call(page) }.tap do |pages|
          PageTemplates.new(self, book:, canvases:, regions:, warnings:).apply(pages)
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
