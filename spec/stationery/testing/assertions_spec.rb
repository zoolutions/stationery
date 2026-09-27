# frozen_string_literal: true

require "stationery/minitest"

RSpec.describe Stationery::Testing::Assertions do
  let(:host_class) do
    Class.new do
      include Stationery::Testing::Assertions

      attr_reader :calls

      def assert(result, message) = (@calls ||= []) << [result, message]
    end
  end
  let(:host) { host_class.new }
  let(:pdf) { SpecDocument.build { text "Hello", link: "https://example.com" }.to_pdf }

  it "passes the matcher's result and failure message to the host's assert" do
    host.assert_pdf_text(pdf, "Hello")
    host.assert_pdf_text(pdf, "Goodbye")

    expect(host.calls).to eq([[true, "expected PDF to have text \"Hello\", got text:\nHello"],
                              [false, "expected PDF to have text \"Goodbye\", got text:\nHello"]])
  end

  it "prefers a custom message" do
    host.assert_page_count(pdf, 3, "one page please")

    expect(host.calls).to eq([[false, "one page please"]])
  end

  it "refutes text with the negated message" do
    host.refute_pdf_text(pdf, "Goodbye")
    host.refute_pdf_text(pdf, "Hello")

    expect(host.calls.map(&:first)).to eq([true, false])
    expect(host.calls.last.last).to eq("expected PDF not to have text \"Hello\", got text:\nHello")
  end

  it "asserts page count, links, images, bookmarks and warnings" do
    host.assert_page_count(pdf, 1)
    host.assert_pdf_link(pdf, "https://example.com")
    host.assert_image_count(pdf, 0)
    host.assert_bookmark(outline_pdf, "Intro")
    host.assert_no_pdf_warnings(SpecDocument.build { text "x" })
    host.assert_no_pdf_warnings(SpecDocument.build { box { 40.times { |i| text "row #{i}" } } })

    expect(host.calls.map(&:first)).to eq([true, true, true, true, true, false])
    expect(host.calls.last.last).to start_with("expected PDF to have no warnings, got:")
  end
end
