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
      def have_no_warnings = HaveNoWarnings.new
      def have_structure(expected) = HaveStructure.new(expected)
      def have_tagged_content = HaveTaggedContent.new
    end
  end
end
