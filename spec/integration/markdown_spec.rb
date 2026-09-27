# frozen_string_literal: true

RSpec.describe "Rendering Markdown" do
  let(:source) { File.read(File.expand_path("../fixtures/markdown/readme.md", __dir__)) }
  let(:doc) do
    body = source
    Class.new(SpecDocument) do
      page size: [400, 800], margin: 20
      define_method(:view_template) { markdown body, bookmarks: true }
    end.new
  end
  let(:pdf) { doc.to_pdf }

  it "renders a README in order" do
    expect(text_of(pdf).split).to eq(<<~TEXT.split)
      Stationery Pure-Ruby PDF documents built from components. See the docs.
      Install gem "stationery" Features Paragraphs, headings and lists Tables:
      1. with headers 2. with aligned cells Quotes work too. Element Status
      html done Licence MIT
    TEXT
  end

  it "bookmarks its headings, links and warns about nothing" do
    expect(outline_of(pdf).map { |entry| entry[:title] }).to eq(["Stationery"])
    expect(outline_of(pdf).first[:children].map { |entry| entry[:title] }).to eq(%w[Install Features])
    expect(pdf).to have_pdf_link("https://example.test/docs")
    expect(doc).to have_no_warnings
  end
end
