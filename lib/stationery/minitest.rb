# frozen_string_literal: true

require "stationery"
require_relative "testing/matchers"

module Stationery
  module Testing
    # Minitest assertions over the same matchers the RSpec integration uses:
    #
    #   class InvoiceTest < Minitest::Test
    #     include Stationery::Testing::Assertions
    #   end
    module Assertions
      def assert_pdf_text(subject, expected, msg = nil) = assert_pdf(Matchers::HaveText.new(expected), subject, msg)
      def assert_page_count(subject, count, msg = nil) = assert_pdf(Matchers::HavePageCount.new(count), subject, msg)
      def assert_pdf_link(subject, url, msg = nil) = assert_pdf(Matchers::HaveLink.new(url), subject, msg)
      def assert_image_count(subject, count, msg = nil) = assert_pdf(Matchers::HaveImageCount.new(count), subject, msg)
      def assert_bookmark(subject, title, msg = nil) = assert_pdf(Matchers::HaveBookmark.new(title), subject, msg)
      def assert_pdf_language(subject, lang, msg = nil) = assert_pdf(Matchers::HaveLanguage.new(lang), subject, msg)

      def assert_page_labels(subject, labels, msg = nil)
        assert_pdf(Matchers::HavePageLabels.new(labels), subject, msg)
      end

      def assert_no_pdf_warnings(subject, msg = nil) = assert_pdf(Matchers::HaveNoWarnings.new, subject, msg)
      def assert_pdf_structure(subject, tree, msg = nil) = assert_pdf(Matchers::HaveStructure.new(tree), subject, msg)
      def assert_tagged_content(subject, msg = nil) = assert_pdf(Matchers::HaveTaggedContent.new, subject, msg)

      def refute_pdf_text(subject, expected, msg = nil)
        matcher = Matchers::HaveText.new(expected)
        assert(!matcher.matches?(subject), msg || matcher.failure_message_when_negated)
      end

      private

      def assert_pdf(matcher, subject, msg)
        assert(matcher.matches?(subject), msg || matcher.failure_message)
      end
    end
  end
end
