# frozen_string_literal: true

require "etc"

module Stationery
  # Renders many documents at once across Ractors (Stationery.render_all),
  # on Ruby 4.0 and later (Ractor#value). The documents are dealt in turn to
  # `ractors` Ractors, each renders its share with caches of its own (fonts
  # parsed, images decoded, hyphenation loaded once per Ractor), and the PDFs
  # come back in the documents' order, the bytes #to_pdf writes for each.
  #
  # A Ractor takes a copy of each document, so what a render leaves on the
  # document (#warnings, #page_count) stays on the copy. A document a Ractor
  # cannot render is rendered on the main Ractor once the others are done:
  # one whose class's settings are not shareable (see Document.finalize!),
  # one that cannot be copied (it holds a Proc, a Method, a Thread), with
  # the documents dealt to the same Ractor; one whose render reaches what a
  # Ractor cannot; or one whose render raised, which raises there what
  # #to_pdf raises. Below Ruby 4.0, with one Ractor, or with an instrumenter
  # that is not shareable, every document is rendered on the main Ractor, in
  # order.
  module Parallel
    class << self
      # One `render_all.stationery` event: `documents:` (how many),
      # `ractors:` (how many were started) and `main_ractor:` (the indexes
      # of the documents rendered on the main Ractor).
      def render(documents, ractors:, **options)
        check(ractors)
        documents = documents.to_a
        Stationery.instrument("render_all.stationery", documents: documents.size) do |event|
          pdfs = Array.new(documents.size)
          event[:ractors] = parallel?(ractors, documents) ? across(documents, ractors, options, pdfs) : 0
          event[:main_ractor] = pdfs.each_index.select { pdfs[it].nil? }
          event[:main_ractor].each { pdfs[it] = documents[it].to_pdf(**options) }
          pdfs
        end
      end

      def available? = defined?(::Ractor) && ::Ractor.method_defined?(:value)

      def default_ractors = Etc.nprocessors

      private

      def check(ractors)
        return if ractors.is_a?(Integer) && ractors.positive?

        raise ArgumentError, "ractors: must be a positive Integer, not #{ractors.inspect}"
      end

      def parallel?(ractors, documents)
        ractors > 1 && documents.size > 1 && available? && ::Ractor.shareable?(Stationery.instrumenter)
      end

      # Fills `pdfs` with what the Ractors rendered, dealing the documents
      # they may take to at most `ractors` of them in turn, and answers how
      # many it started; a share a Ractor could not take or render stays
      # nil, for the main Ractor.
      def across(documents, ractors, options, pdfs)
        indexes = documents.each_index.select { shareable?(documents[it]) }
        count = [ractors, indexes.size].min
        shares = Array.new(count) { |share| indexes.select.with_index { |_, position| position % count == share } }
        workers = shares.map { |share| [share, start(share.map { documents[it] }, options)] }
        workers.each do |share, ractor|
          rendered = ractor&.value
          share.each_with_index { |index, position| pdfs[index] = rendered[position] } if rendered
        end
        workers.count { |_, ractor| ractor }
      end

      def shareable?(document) = document.is_a?(Document) && ::Ractor.shareable?(document.class.config)

      # A Ractor rendering `documents`, or nil when they or the options
      # cannot be copied into one (the main Ractor renders that share). It
      # answers a nil for a render that failed: the main Ractor renders that
      # document again and raises what to_pdf raises.
      def start(documents, options)
        ::Ractor.new(documents, options) do |share, settings|
          share.map do |document|
            document.to_pdf(**settings)
          rescue StandardError
            nil
          end
        end
      rescue TypeError, ::Ractor::Error
        nil
      end
    end
  end

  # The PDFs of `documents` (Stationery::Document instances), in their order,
  # rendered across `ractors` Ractors (one per processor by default) on Ruby
  # 4.0 and later, and on the main Ractor below it; `options` are passed to
  # every #to_pdf. See Parallel.
  def self.render_all(documents, ractors: Parallel.default_ractors, **)
    Parallel.render(documents, ractors:, **)
  end
end
