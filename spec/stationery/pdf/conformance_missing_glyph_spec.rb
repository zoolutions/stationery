# frozen_string_literal: true

# A character no font has draws as .notdef, which neither PDF/A (ISO 19005-2/3,
# 6.2.11.8) nor PDF/UA (ISO 14289-1, 7.21.8) lets text reference: veraPDF
# fails such a file on rules 6.2.11.8-1 and 7.21.8-1.
RSpec.describe "conformance with a character no font has" do # rubocop:disable RSpec/DescribeClass
  let(:base) { Class.new(SpecDocument) { metadata title: "Annual report", lang: "en" } }
  let(:body) { Class.new(base) { def view_template = text("in 日本 and 日") } }
  let(:header) do
    Class.new(base) do
      header { text "☃ head" }
      def view_template = text("body")
    end
  end
  let(:field) { Class.new(base) { def view_template = text_field("name", value: "語") } }

  def issue(char, code)
    %("#{char}" (U+#{code}) is in no font of Open Sans: add a font or font_fallbacks that covers it)
  end

  it "raises under PDF/UA, naming each character once" do
    expect { body.new.to_pdf(conformance: :pdf_ua1) }.to raise_error(Stationery::ConformanceError) do |error|
      expect(error.levels).to eq([:pdf_ua1])
      expect(error.issues).to eq([issue("日", "65E5"), issue("本", "672C")])
      expect(error.message).to start_with(%(not PDF/UA-1:\n  "日" (U+65E5) is in no font of Open Sans: add a font))
    end
  end

  it "raises under PDF/A too" do
    %i[pdf_a2b pdf_a3b].each do |level|
      expect { body.new.to_pdf(conformance: level) }.to raise_error(Stationery::ConformanceError) do |error|
        expect(error.issues).to eq([issue("日", "65E5"), issue("本", "672C")])
      end
    end
    expect { body.new.to_pdf(conformance: %i[pdf_a3b pdf_ua1]) }
      .to raise_error(Stationery::ConformanceError, %r{\Anot PDF/A-3b \+ PDF/UA-1:\n  "日"})
  end

  it "raises for a header and for a form field's value" do
    %i[pdf_a3b pdf_ua1].each do |level|
      expect { header.new.to_pdf(conformance: level) }.to raise_error(Stationery::ConformanceError) do |error|
        expect(error.issues).to eq([issue("☃", "2603")])
      end
      expect { field.new.to_pdf(conformance: level) }.to raise_error(Stationery::ConformanceError) do |error|
        expect(error.issues).to eq([issue("語", "8A9E")])
      end
    end
  end

  it "lists the missing characters with the other issues" do
    path = image_path("rgb.jpg")
    doc = Class.new(base) do
      define_method(:view_template) do
        image path, width: 20
        text "☃"
      end
    end

    expect { doc.new.to_pdf(conformance: :pdf_ua1) }.to raise_error(Stationery::ConformanceError) do |error|
      expect(error.issues).to eq(["image on page 1 has no alt: text", issue("☃", "2603")])
    end
  end

  it "only warns without a conformance level" do
    [body, header, field].each do |document|
      doc = document.new

      expect(doc.to_pdf).to start_with("%PDF")
      expect(doc.warnings.to_a).to all(be_a(Stationery::Warnings::MissingGlyph))
      expect(doc.warnings.to_a).not_to be_empty
    end
  end

  it "accepts the characters once a fallback covers them" do
    covered = Class.new(base) do
      font_family "Noto Sans JP", regular: "#{SpecDocument::FONTS}/NotoSansJP-Subset.otf"
      font_fallbacks "Noto Sans JP"
      def view_template
        text "in 日本"
        text_field "name", value: "語"
      end
    end

    %i[pdf_a3b pdf_ua1].each { |level| expect(covered.new.to_pdf(conformance: level)).to have_conformance(level) }
  end

  it "accepts whitespace the font lacks, which draws as a blank" do
    blanks = Class.new(base) do
      header { text "wide　head" }
      def view_template
        text "figure space and narrow space"
        text_field "name", value: "thin space"
      end
    end

    %i[pdf_a3b pdf_ua1].each do |level|
      doc = blanks.new

      expect(doc.to_pdf(conformance: level)).to have_conformance(level)
      expect(doc.warnings.to_a).to eq([])
    end
  end
end
