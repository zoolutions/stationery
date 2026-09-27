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
                      { page: { size: :letter, margin: 36 }, families: {}, text: {}, metadata: {}, templates: [],
                        strict: false }
                    end
      end

      def page(size: :letter, margin: 36, layout: :portrait)
        config[:page] = { size:, margin:, layout: }
      end

      def font_family(name, **paths)
        config[:families][name.to_s] = Fonts::Family.build(name, **paths)
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

      # Runs after pagination on every page. `layer: :background` paints under
      # the page's content.
      def page_template(layer: :foreground, &block)
        config[:templates] << [layer, block]
      end
    end

    attr_reader :warnings

    def page_options = self.class.config[:page]
    def metadata = self.class.config[:metadata]

    def to_pdf(target = nil, strict: self.class.config[:strict], debug: false)
      warnings = Warnings.new
      book = Fonts::FontBook.new(self.class.config[:families], warnings:)
      call(builder = Builder.new(book:, text: self.class.config[:text]))
      resources = Resources.new
      pages = Layout::Paginator.new(resources:, page: page_options, warnings:, debug:).paginate(builder.root)
      PageTemplates.new(self, book:, resources:, debug:).apply(pages)
      @warnings = warnings
      raise WarningsError, warnings if strict && warnings.any?

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

    private

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
