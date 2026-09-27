# frozen_string_literal: true

require "stationery"

module Stationery
  # Browsable sample documents, like ActionMailer previews. Each public method
  # returns one document. `around_render` wraps building and rendering it,
  # for anything that must be in effect while the document paints:
  #
  #   # spec/pdfs/previews/invoice_pdf_preview.rb
  #   class InvoicePdfPreview < Stationery::Preview
  #     def paid = InvoicePdf.new(Invoice.first)
  #     def overdue(params) = InvoicePdf.new(Invoice.find(params.fetch("id")))
  #
  #     def around_render(_name, params) = I18n.with_locale(params.fetch("locale", I18n.default_locale)) { yield }
  #   end
  class Preview
    REGISTRY_LOCK = Mutex.new
    HOOKS = %w[around_render].freeze

    class << self
      def inherited(subclass)
        super
        REGISTRY_LOCK.synchronize { Preview.registry << subclass }
      end

      # Named subclasses with at least one preview; a name defined again (a
      # reloaded file) keeps its latest class.
      def all
        classes = REGISTRY_LOCK.synchronize { Preview.registry.dup }
        classes.select { it.name && it.pdfs.any? }.reverse.uniq(&:name).sort_by(&:preview_name)
      end

      # `load`, not `require`: edited previews show up without a restart.
      def load(paths)
        paths.each { |path| Dir["#{path}/**/*_preview.rb"].each { |file| Kernel.load(file) } }
      end

      # "invoice_pdf/paid" => [InvoicePdfPreview, "paid"]
      def find(path)
        name, _, pdf = path.to_s.rpartition("/")
        klass = all.find { it.preview_name == name }
        [klass, pdf] if klass&.pdfs&.include?(pdf)
      end

      def preview_name = underscore(name.delete_suffix("Preview"))
      def pdfs = public_instance_methods(false).sort.map(&:to_s) - HOOKS

      protected

      def registry = (@registry ||= []) # rubocop:disable ThreadSafety/ClassInstanceVariable

      private

      def underscore(name)
        name.gsub("::", "/").gsub(/([A-Z\d]+)([A-Z][a-z])/, '\1_\2').gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase
      end
    end

    # The PDF bytes of one preview, built and rendered inside around_render.
    # `debug: true` reaches to_pdf when the document accepts it.
    def to_pdf(name, params = {}, debug: false)
      around_render(name, params) do
        document = render(name, params)
        document.to_pdf(**(debug && accepts_debug?(document) ? { debug: true } : {}))
      end
    end

    # Override to wrap the preview: set an I18n locale, Current attributes,
    # a time zone. Both the preview method and to_pdf run inside the block.
    def around_render(_name, _params) = yield

    def render(name, params = {})
      method = public_method(name)
      document = method.arity.zero? ? method.call : method.call(params)
      return document if document.respond_to?(:to_pdf)

      raise Error, "#{self.class}##{name} must return a Stationery::Document (got #{document.class})"
    end

    private

    def accepts_debug?(document) = document.method(:to_pdf).parameters.include?(%i[key debug])
  end
end
