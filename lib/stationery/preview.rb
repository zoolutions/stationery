# frozen_string_literal: true

require "stationery"

module Stationery
  # Browsable sample documents, like ActionMailer previews. Each public method
  # returns one document:
  #
  #   # spec/pdfs/previews/invoice_pdf_preview.rb
  #   class InvoicePdfPreview < Stationery::Preview
  #     def paid = InvoicePdf.new(Invoice.first)
  #     def overdue(params) = InvoicePdf.new(Invoice.find(params.fetch("id")))
  #   end
  class Preview
    REGISTRY_LOCK = Mutex.new

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
      def pdfs = public_instance_methods(false).sort.map(&:to_s)

      protected

      def registry = (@registry ||= []) # rubocop:disable ThreadSafety/ClassInstanceVariable

      private

      def underscore(name)
        name.gsub("::", "/").gsub(/([A-Z\d]+)([A-Z][a-z])/, '\1_\2').gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase
      end
    end

    def render(name, params = {})
      method = public_method(name)
      document = method.arity.zero? ? method.call : method.call(params)
      return document if document.respond_to?(:to_pdf)

      raise Error, "#{self.class}##{name} must return a Stationery::Document (got #{document.class})"
    end
  end
end
