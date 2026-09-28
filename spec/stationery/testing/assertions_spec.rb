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
    host.assert_no_pdf_warnings(SpecDocument.build { box(break_inside: :avoid) { 40.times { |i| text "row #{i}" } } })

    expect(host.calls.map(&:first)).to eq([true, true, true, true, true, false])
    expect(host.calls.last.last).to start_with("expected PDF to have no warnings, got:")
  end

  it "asserts the structure tree and tagged content" do
    tagged = SpecDocument.build { text "Hi" }.to_pdf(tagged: true)
    host.assert_pdf_structure(tagged, [[:Document, [[:P, "Hi"]]]])
    host.assert_tagged_content(tagged)
    host.assert_tagged_content(pdf)

    expect(host.calls.map(&:first)).to eq([true, true, false])
  end

  it "asserts page labels" do
    labelled = Class.new(SpecDocument) do
      page_labels 1 => { style: :roman }
      def view_template
        2.times do
          text("x")
          page_break
        end
      end
    end.new.to_pdf
    host.assert_page_labels(labelled, %w[I II])
    host.assert_page_labels(pdf, %w[I II])

    expect(host.calls.map(&:first)).to eq([true, false])
    expect(host.calls.last.last).to eq('expected PDF to have page labels ["I", "II"], got none')
  end

  it "asserts the language" do
    german = Class.new(SpecDocument) do
      metadata lang: "de"
      def view_template = text("Hallo")
    end.new.to_pdf
    host.assert_pdf_language(german, "de")
    host.assert_pdf_language(pdf, "de")

    expect(host.calls.map(&:first)).to eq([true, false])
    expect(host.calls.last.last).to eq('expected PDF to have language "de", got none')
  end
end
