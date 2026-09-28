# frozen_string_literal: true

# Characters no font has are all drawn as glyph 0. The text they stand for
# travels as the ActualText of a Span around them, so a reader gets the
# characters that were written, not one of them repeated.
RSpec.describe "text no font has" do # rubocop:disable RSpec/DescribeClass
  def page_contents(pdf) = reader_for(pdf).pages.map(&:raw_content)

  def to_unicode(pdf)
    objects = reader_for(pdf).objects
    objects.filter_map { |_ref, object| object.unfiltered_data if stream?(object, "beginbfchar") }
  end

  def stream?(object, marker) = object.is_a?(PDF::Reader::Stream) && object.unfiltered_data.include?(marker)

  it "extracts three different missing characters in the order written" do
    doc = SpecDocument.build { text "日本語" }

    expect(text_of(doc.to_pdf)).to eq("日本語")
    expect(doc.warnings.map(&:char)).to eq(%w[日 本 語])
  end

  it "keeps them in place among characters the font has" do
    pdf = SpecDocument.build { text "in 日本 and ☃ again" }.to_pdf

    expect(text_of(pdf)).to eq("in 日本 and ☃ again")
  end

  it "wraps each stretch of .notdef glyphs in a Span with the characters as ActualText" do
    content = page_contents(SpecDocument.build { text "a日本b☃" }.to_pdf).first

    expect(content.scan(%r{/Span <</ActualText <(\h+)>>> BDC\n<(\h+)> Tj\nEMC}))
      .to eq([%w[FEFF65E5672C 00000000], %w[FEFF2603 0000]])
    expect(content.scan("BDC").size).to eq(content.scan("EMC").size)
  end

  it "keeps the kerning and word spacing between the stretches" do
    doc = SpecDocument.build { text "AV 日 To", kerning: true }
    book = Stationery::Fonts::FontBook.new(SpecDocument.config[:families])
    font = book.resolve(Stationery::Text::Style.new(family: "Open Sans")).first
    run = font.glyph_run("AV 日 To", kerning: true)

    expect(page_contents(doc.to_pdf).first).to include(run.to_operator)
    expect(run.to_operator).to include("] TJ\n/Span").and include("EMC\n")
    expect(text_of(doc.to_pdf)).to eq("AV 日 To")
  end

  it "maps glyph 0 to the replacement character, never to one of the characters" do
    cmap = to_unicode(SpecDocument.build { text "日本語" }.to_pdf).first

    expect(cmap).to include("<0000> <FFFD>")
    expect(cmap).not_to include("65E5")
  end

  it "reads once through the structure tree of a tagged document" do
    doc = Class.new(SpecDocument) do
      tagged
      metadata lang: "ja", title: "t"
      def view_template = text("本 and 語", heading: 1)
    end.new
    inspector = inspect_pdf(doc.to_pdf)

    expect(inspector.text).to eq("本 and 語")
    expect(inspector.structure).to eq([[:Document, [[:H1, "本 and 語"]]]])
    expect(inspector.untagged_text).to be_empty
  end

  it "covers table cells and html" do
    table_pdf = SpecDocument.build { table([%w[日本 x]]) }.to_pdf
    html_pdf = SpecDocument.build { html "<p>見る <b>語</b></p>" }.to_pdf

    expect(text_of(table_pdf)).to include("日本")
    expect(text_of(html_pdf)).to eq("見る 語")
  end

  it "leaves text the fonts cover as it was" do
    content = page_contents(SpecDocument.build { text "plain text" }.to_pdf).first

    expect(content).not_to include("Span")
    expect(content).to match(/\] TJ|> Tj/)
  end
end
