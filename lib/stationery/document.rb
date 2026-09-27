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
                        templates: [], regions: [], strict: false, tagged: false }
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

    attr_reader :warnings

    def page_options = self.class.config[:page]
    def metadata = self.class.config[:metadata]

    def to_pdf(target = nil, strict: self.class.config[:strict], debug: false, encrypt: self.class.config[:encrypt],
               tagged: self.class.config[:tagged])
      encryption = encrypt && PDF::Encryption::StandardSecurity.new(**encrypt)
      tagging = Tagging::Tree.new if tagged
      warnings = Warnings.new
      book = Fonts::FontBook.new(self.class.config[:families], fallbacks: self.class.config[:fallbacks], warnings:)
      call(builder = Builder.new(book:, text: self.class.config[:text]))
      resources = Resources.new
      pages = paginate(builder.root, book:, resources:, warnings:, debug:, tagging:)
      outline = builder.outline.resolve(Structure.resolve(pages, warnings:, resources:, book:, tagging:))
      tagging&.audit(pages, warnings, lang: metadata[:lang])
      @warnings = warnings
      raise WarningsError, warnings if strict && warnings.any?

      assembler = PDF::Assembler.new(pages:, resources:, info:, outline:, encryption:, tagging:, lang: metadata[:lang])
      write(assembler.render, target)
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
      builder = Builder.new(book:, text: self.class.config[:text])
      build_with(builder) { instance_exec(info, &) }
      builder.root
    end

    private

    def paginate(root, book:, resources:, warnings:, debug:, tagging:)
      regions = Regions.new(self.class.config[:regions], measure: region_measure(book))
      paginator = Layout::Paginator.new(resources:, page: page_options, warnings:, debug:, regions:, tagging:)
      paginator.paginate(root).tap do |pages|
        PageTemplates.new(self, book:, resources:, debug:, regions:, warnings:, tagging:).apply(pages)
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
      metadata.except(:lang).to_h do |key, value|
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
