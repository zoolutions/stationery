# frozen_string_literal: true

require "stationery/testing/inspector"

# A form field's value is drawn by its widget's appearance, a form XObject of
# the annotation and no part of the page content.
RSpec.describe Stationery::Testing::Inspector do
  let(:form) do
    SpecDocument.build do
      text "Name"
      text_field "name", value: "Astrid Lindqvist"
      text "Country"
      select "country", options: %w[Sweden Norway], value: "Sweden"
      checkbox "terms", checked: true, label: "I accept"
      radio "plan", "basic", label: "Basic"
      radio "plan", "pro", checked: true, label: "Pro"
      page_break
      text "Signed"
      signature_field "signature", label: "Signature of the applicant"
    end
  end
  let(:content) { [["Name", "Country", "I accept", "Basic", "Pro"], ["Signed"]] }
  let(:shown) do
    [["Name", "Astrid Lindqvist", "Country", "Sweden", "I accept", "Basic", "Pro"],
     ["Signed", "Signature of the applicant"]]
  end

  # The lines of a text, without the room the layout leaves between them.
  def lines(text) = text.lines.map(&:strip).reject(&:empty?)
  def lines_with_fields(subject) = lines(described_class.new(subject).text(fields: true))

  it "reads the page content alone, as it always has" do
    inspector = described_class.new(form)

    expect(inspector.page_texts.map { |text| lines(text) }).to eq(content)
    expect(inspector.text).to eq(inspector.reader.pages.map { |page| page.text.squeeze(" ").strip }.join("\n"))
  end

  it "reads what the fields show with fields: true, on their page and in their place" do
    inspector = described_class.new(form)

    expect(inspector.page_texts(fields: true).map { |text| lines(text) }).to eq(shown)
    expect(inspector.text(fields: true)).to eq(inspector.page_texts(fields: true).join("\n"))
    expect(lines(inspector.text)).to eq(content.flatten)
  end

  it "reads every line of a multiline field and every cell of a comb" do
    doc = SpecDocument.build do
      text_field "notes", value: "one two three four five six seven", multiline: true, width: 100, height: 40
      text_field "pin", value: "1234", comb: 4, width: 100
    end

    expect(lines_with_fields(doc)).to eq(["one two three four", "five six seven", "1 2 3 4"])
  end

  it "reads characters no font has from the ActualText around them" do
    expect(lines_with_fields(SpecDocument.build { text_field "name", value: "a日本b☃" })).to eq(["a日本b☃"])
  end

  it "reads a field made without a font book, set in the standard Helvetica" do
    doc = SpecDocument.build do
      field = Stationery::Forms::Field.new(:text, "raw", value: "Åsa Öberg")
      canvas(height: 30) { |canvas, rect| canvas.widget(field, rect.x, rect.y, 100, 20) }
    end

    expect(lines_with_fields(doc)).to eq(["Åsa Öberg"])
  end

  it "reads the fields of an encrypted document" do
    pdf = form.to_pdf(encrypt: { owner_password: "s3cret", permissions: [:print] })

    expect(pdf).to include("/Encrypt")
    expect(lines_with_fields(pdf)).to eq(shown.flatten)
  end

  it "reads a field a signature fills, and nothing of a signature without a field" do
    identity = signer
    sign = { certificate: identity.certificate, key: identity.key }

    expect(lines_with_fields(form.to_pdf(sign: { **sign, field: "signature" }))).to eq(shown.flatten)
    expect(lines_with_fields(SpecDocument.build { text "Body" }.to_pdf(sign:))).to eq(["Body"])
  end

  it "is the page content for a document without fields" do
    inspector = described_class.new(SpecDocument.build { text "Body" })

    expect(inspector.text(fields: true)).to eq(inspector.text)
  end
end
