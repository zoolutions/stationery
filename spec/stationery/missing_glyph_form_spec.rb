# frozen_string_literal: true

# A form field's appearance is text like any other: characters no font has
# are drawn as glyph 0 inside a Span whose ActualText is the characters, so
# the value extracts and copies as it was written.
RSpec.describe "a form field value no font has" do # rubocop:disable RSpec/DescribeClass
  def widget(pdf, name) = form_fields(pdf).fetch(name)
  def content(pdf, name) = appearance_of(pdf, widget(pdf, name))
  def shown(pdf, name) = appearance_text(pdf, widget(pdf, name))

  # The operators that open and close text objects and marked content.
  def nesting(content) = content.scan(/^(?:.* )?(BMC|BDC|EMC|BT|ET)$/).flatten

  let(:font) do
    book = Stationery::Fonts::FontBook.new(SpecDocument.config[:families])
    book.resolve(Stationery::Text::Style.new(family: "Open Sans")).first
  end

  it "extracts a single line as written, each stretch of .notdef glyphs in its Span" do
    pdf = SpecDocument.build { text_field "name", value: "a日本b☃" }.to_pdf

    expect(content(pdf, "name").scan(%r{/Span <</ActualText <(\h+)>>> BDC\n<(\h+)> Tj\nEMC}))
      .to eq([%w[FEFF65E5672C 00000000], %w[FEFF2603 0000]])
    expect(shown(pdf, "name")).to eq(%w[a 日本 b ☃])
  end

  it "extracts a value of nothing but missing characters" do
    pdf = SpecDocument.build { text_field "name", value: "日本語" }.to_pdf

    expect(shown(pdf, "name")).to eq(["日本語"])
  end

  it "closes each Span inside its text object, inside the variable text" do
    pdf = SpecDocument.build { text_field "name", value: "a日b", comb: 3 }.to_pdf

    expect(nesting(content(pdf, "name"))).to eq(%w[BMC BT ET BT BDC EMC ET BT ET EMC])
    expect(content(pdf, "name")).to start_with("q\n").and include("/Tx BMC\nq\n").and end_with("Q\nEMC\n")
  end

  it "keeps the characters of every line of a multiline field" do
    pdf = SpecDocument.build do
      text_field "notes", value: "one 日本語 two three four five six\n語 end", multiline: true, width: 100, height: 60
    end.to_pdf
    lines = content(pdf, "notes").scan(/^BT\n.*?^ET$/m)

    expect(lines.size).to be > 2
    expect(shown(pdf, "notes")).to eq(["one ", "日本語", " two three", "four five six", "語", " end"])
    expect(lines.last).to include("/Span <</ActualText <FEFF8A9E>>> BDC\n<0000> Tj\nEMC")
    expect(nesting(content(pdf, "notes")).each_cons(2)).not_to include(%w[BDC ET], %w[BDC BT])
  end

  it "keeps the character of a comb cell" do
    pdf = SpecDocument.build { text_field "code", value: "1日3", comb: 4 }.to_pdf

    expect(shown(pdf, "code")).to eq(%w[1 日 3])
    expect(content(pdf, "code").scan(/ActualText <(\h+)>/)).to eq([["FEFF65E5"]])
  end

  it "keeps the characters of a select's value and of a signature field's label" do
    pdf = SpecDocument.build do
      select "country", options: %w[日本 Norway], value: "日本"
      signature_field "signature", label: "署名 here"
    end.to_pdf

    expect(shown(pdf, "country")).to eq(["日本"])
    expect(shown(pdf, "signature")).to eq(["署名", " here"])
    expect(nesting(content(pdf, "signature"))).to eq(%w[BT BDC EMC ET])
  end

  it "reports the missing glyphs as before" do
    doc = SpecDocument.build { text_field "name", value: "日本 日" }
    doc.to_pdf

    expect(doc.warnings.map(&:message))
      .to eq(['missing glyph "日" (U+65E5) in Open Sans, drawn 2 times as .notdef',
              'missing glyph "本" (U+672C) in Open Sans, drawn once as .notdef'])
  end

  it "leaves a value the fonts cover as it was" do
    pdf = SpecDocument.build { text_field "name", value: "Astrid" }.to_pdf

    expect(content(pdf, "name")).to include("Tf\n#{font.glyph_run("Astrid", ligatures: false).to_operator}\nET")
    expect(content(pdf, "name")).not_to include("Span")
    expect(nesting(content(pdf, "name"))).to eq(%w[BMC BT ET EMC])
    expect(shown(pdf, "name")).to eq(["Astrid"])
  end

  # The standard Helvetica has no .notdef to stand in: a character outside
  # Windows-1252 is written as a real "?", and the field's /V keeps the value.
  it "writes no Span for a field made without a font book" do
    doc = SpecDocument.build do
      field = Stationery::Forms::Field.new(:text, "raw", value: "a日本")
      canvas(height: 30) { |canvas, rect| canvas.widget(field, rect.x, rect.y, 100, 20) }
    end
    pdf = doc.to_pdf

    expect(content(pdf, "raw")).to include("(a??) Tj")
    expect(content(pdf, "raw")).not_to include("Span")
    expect(decode_text(widget(pdf, "raw")[:V])).to eq("a日本")
    expect(doc.warnings.to_a).to eq([])
  end
end
