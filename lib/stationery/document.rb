# frozen_string_literal: true

module Stationery
  # A whole PDF. Configure it at class level and describe it in view_template:
  #
  #   class Invoice < Stationery::Document
  #     page size: :a4, margin: 40
  #     font_family "Inter", regular: "Inter-Regular.ttf", bold: "Inter-Bold.ttf"
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
                      { page: { size: :letter, margin: 36 }, families: {}, text: {}, metadata: {}, templates: [],
                        regions: [] }
                    end
      end

      def page(size: :letter, margin: 36, layout: :portrait)
        config[:page] = { size:, margin:, layout: }
      end

      def font_family(name, **paths)
        config[:families][name.to_s] = Fonts::Family.new(name, **paths)
      end

      def default_text(**options)
        config[:text] = config[:text].merge(options)
      end

      def metadata(**info)
        config[:metadata] = config[:metadata].merge(info)
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

    def to_pdf(target = nil)
      book = Fonts::FontBook.new(self.class.config[:families])
      call(builder = Builder.new(book:, text: self.class.config[:text]))
      resources = Resources.new
      regions = Regions.new(self.class.config[:regions], measure: region_measure(book))
      paginator = Layout::Paginator.new(resources:, page: page_options, regions:)
      pages = paginator.paginate(builder.root)
      @warnings = paginator.warnings
      PageTemplates.new(self, book:, resources:, regions:, warnings: @warnings).apply(pages)
      write(PDF::Assembler.new(pages:, resources:, info:).render, target)
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

    def region_measure(book)
      page = Page.new(**page_options)
      lambda do |region, number|
        info = PageInfo.new(number, number, page.width, page.height, page.margin, page.margin_box)
        template_root(info, book:, &region.block).measure(page.margin_box.width)
      end
    end

    def info
      metadata.to_h do |key, value|
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
