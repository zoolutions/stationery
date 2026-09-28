# frozen_string_literal: true

require_relative "inspector"

module Stationery
  module Testing
    # Framework-independent PDF matchers: each answers matches?(subject),
    # failure_message, failure_message_when_negated and description, so RSpec
    # uses them directly and Minitest assertions wrap them.
    module Matchers
      EXCERPT = 500

      class Base
        def initialize(expected = nil)
          @expected = expected
        end

        def matches?(subject)
          @inspector = subject.is_a?(Inspector) ? subject : Inspector.new(subject)
          match?(@inspector)
        end

        def failure_message = "expected PDF to #{description}, #{actual}"
        def failure_message_when_negated = "expected PDF not to #{description}, #{actual}"

        private

        def show(expected) = expected.is_a?(Regexp) ? expected.inspect : expected.to_s.inspect

        def contains?(haystack, expected)
          expected.is_a?(Regexp) ? expected.match?(haystack) : haystack.include?(expected.to_s)
        end

        def excerpt(text)
          text.length > EXCERPT ? "#{text[0, EXCERPT]}…" : text
        end
      end

      class HaveText < Base
        def description = "have text #{show(@expected)}"

        private

        def match?(pdf) = contains?(pdf.text, @expected)
        def actual = "got text:\n#{excerpt(@inspector.text)}"
      end

      class HaveTextOnPage < Base
        def initialize(page, expected)
          super(expected)
          @page = page
        end

        def description = "have text #{show(@expected)} on page #{@page}"

        private

        def page_text = @inspector.page_texts.fetch(@page - 1, nil)
        def match?(_pdf) = !page_text.nil? && contains?(page_text, @expected)

        def actual
          return "but it has #{@inspector.page_count} page(s)" if page_text.nil?

          "got text on page #{@page}:\n#{excerpt(page_text)}"
        end
      end

      class HavePageCount < Base
        def description = "have #{@expected} page(s)"

        private

        def match?(pdf) = pdf.page_count == @expected
        def actual = "got #{@inspector.page_count}"
      end

      class HaveLink < Base
        def description = "have a link to #{show(@expected)}"

        private

        def match?(pdf) = pdf.links.any? { |url| @expected.is_a?(Regexp) ? @expected.match?(url) : url == @expected }
        def actual = "got links #{@inspector.links.inspect}"
      end

      class HaveImageCount < Base
        def description = "have #{@expected} image(s)"

        private

        def match?(pdf) = pdf.image_count == @expected
        def actual = "got #{@inspector.image_count}"
      end

      class HaveBookmark < Base
        def description = "have a bookmark #{show(@expected)}"

        private

        def match?(pdf) = pdf.bookmarks.include?(@expected)
        def actual = "got bookmarks #{@inspector.bookmarks.inspect}"
      end

      class HaveLanguage < Base
        def description = "have language #{show(@expected)}"

        private

        def match?(pdf) = pdf.lang == @expected.to_s
        def actual = @inspector.lang ? "got #{@inspector.lang.inspect}" : "got none"
      end

      class HavePageLabels < Base
        def description = "have page labels #{@expected.inspect}"

        private

        def match?(pdf) = pdf.page_labels == @expected
        def actual = @inspector.page_labels.empty? ? "got none" : "got #{@inspector.page_labels.inspect}"
      end

      class HaveConformance < Base
        def initialize(*levels) = super(levels.flatten.map(&:to_sym))

        def description = "conform to #{labels(@expected)}"

        private

        def labels(levels) = levels.map { |level| PDF::Conformance.label(level) }.join(" and ")
        def match?(pdf) = (@expected - pdf.conformance).empty?
        def actual = @inspector.conformance.empty? ? "got no claim" : "got #{labels(@inspector.conformance)}"
      end

      class HaveFacturX < Base
        def initialize(profile: nil) = super(profile&.to_sym)

        def description
          @expected ? "be a Factur-X invoice of profile #{@expected.inspect}" : "be a Factur-X invoice"
        end

        private

        def match?(pdf)
          invoice = pdf.factur_x
          !invoice.nil? && !invoice[:xml].nil? && (@expected.nil? || invoice[:profile] == @expected)
        end

        def actual
          invoice = @inspector.factur_x
          return "got no invoice" unless invoice
          return "got #{invoice[:filename]} named in XMP but not embedded" unless invoice[:xml]

          "got profile #{invoice[:profile].inspect}"
        end
      end

      class HaveAttachment < Base
        def initialize(name, mime: nil, relationship: nil)
          super(name)
          @mime = mime
          @relationship = relationship
        end

        def description
          extra = { mime: @mime, relationship: @relationship }.compact.map { |k, v| " #{k} #{v.inspect}" }.join
          "have an attachment #{show(@expected)}#{extra}"
        end

        private

        def match?(pdf)
          pdf.attachments.any? do |file|
            file[:name] == @expected && (@mime.nil? || file[:mime] == @mime) &&
              (@relationship.nil? || file[:relationship] == @relationship)
          end
        end

        def actual
          files = @inspector.attachments
          return "got none" if files.empty?

          "got #{files.map { |file| "#{file[:name]} (#{file[:mime]}, #{file[:relationship]})" }.inspect}"
        end
      end

      class HaveSignature < Base
        def initialize(name: nil, valid: true)
          super(name)
          @valid = valid
        end

        def description
          "have #{@valid ? "a valid" : "an invalid"} signature#{" by #{show(@expected)}" if @expected}"
        end

        private

        def match?(pdf)
          pdf.signatures.any? { |one| (@expected.nil? || one[:name] == @expected) && one[:valid] == @valid }
        end

        def actual
          signatures = @inspector.signatures
          return "got none" if signatures.empty?

          "got #{signatures.map { |one| "#{one[:name].inspect} (#{one[:valid] ? "valid" : "invalid"})" }.join(", ")}"
        end
      end

      class HaveNoWarnings < Base
        def description = "have no warnings"

        private

        def match?(pdf) = pdf.warnings.empty?
        def messages = @inspector.warnings.map(&:message)
        def actual = messages.empty? ? "got none" : "got:\n#{messages.map { |m| "  - #{m}" }.join("\n")}"
      end

      class HaveStructure < Base
        def description = "have structure #{@expected.inspect}"

        private

        def match?(pdf) = pdf.structure == @expected
        def actual = "got #{@inspector.structure.inspect}"
      end

      class HaveTaggedContent < Base
        def description = "be tagged with every text in marked content"

        private

        def match?(pdf) = pdf.tagged? && pdf.untagged_text.empty?

        def actual
          return "but it is not tagged" unless @inspector.tagged?

          "got untagged text #{@inspector.untagged_text.inspect}"
        end
      end

      def have_pdf_text(expected) = HaveText.new(expected)
      def have_pdf_text_on_page(page, expected) = HaveTextOnPage.new(page, expected)
      def have_page_count(expected) = HavePageCount.new(expected)
      def have_pdf_link(expected) = HaveLink.new(expected)
      def have_image_count(expected) = HaveImageCount.new(expected)
      def have_bookmark(title) = HaveBookmark.new(title)
      def have_pdf_language(lang) = HaveLanguage.new(lang)
      def have_page_labels(labels) = HavePageLabels.new(labels)
      def have_attachment(name, **) = HaveAttachment.new(name, **)
      def have_conformance(*levels) = HaveConformance.new(*levels)
      def have_factur_x(profile: nil) = HaveFacturX.new(profile:)
      def have_signature(name: nil, valid: true) = HaveSignature.new(name:, valid:)
      def have_no_warnings = HaveNoWarnings.new
      def have_structure(expected) = HaveStructure.new(expected)
      def have_tagged_content = HaveTaggedContent.new
    end
  end
end
