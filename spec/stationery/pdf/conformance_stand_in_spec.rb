# frozen_string_literal: true

# `missing_glyphs: :replace` draws a character no font has as a glyph the
# font does have (U+FFFD, else U+25A1, else "?") inside the Span whose
# ActualText is the character, so nothing references .notdef and the claim
# holds: veraPDF passes 2b, 3b and ua1 for body text, headers and page
# templates, form fields and shaped text, with each of the three stand-ins.
RSpec.describe "conformance with missing glyphs replaced" do # rubocop:disable RSpec/DescribeClass
  let(:base) { Class.new(SpecDocument) { metadata title: "Annual report", lang: "en" } }
  let(:body) { Class.new(base) { def view_template = text("in 日本 and 日") } }
  let(:header) do
    Class.new(base) do
      header { text "☃ head" }
      page_template { |page| box(at: [40, page.height - 30]) { text "見 #{page.number}" } }
      def view_template = text("body")
    end
  end

  def replacement = Stationery::Fonts::Font::REPLACEMENT

  def field = Class.new(base) { def view_template = text_field("name", value: "a語b", tooltip: "Name") }
  def open_sans = Stationery::Fonts::Registry.load(font_path("OpenSans-Regular.ttf"))
  # The code of Open Sans's U+FFFD glyph.
  def stand_in = format("%04X", open_sans.glyph_id(0xFFFD))
  def contents(pdf) = reader_for(pdf).pages.map(&:raw_content).join("\n")
  # The character codes the content shows, four hex digits each.
  def codes(content) = content.scan(/<(\h+)>(?= Tj|[^\n]*\] TJ)/).flatten.flat_map { |hex| hex.scan(/\h{4}/) }
  def spans(content) = content.scan(%r{/Span <</ActualText <(\h+)>>> BDC\n<(\h+)> Tj\nEMC})

  def to_unicode(pdf)
    reader_for(pdf).objects.filter_map do |_ref, object|
      next unless object.is_a?(PDF::Reader::Stream) && object.unfiltered_data.include?("beginbfchar")

      object.unfiltered_data
    end.join
  end

  describe "the option" do
    it "is :raise unless said otherwise, at class level and per render" do
      declared = Class.new(body) { conformance :pdf_a3b }

      expect { declared.new.to_pdf }.to raise_error(Stationery::ConformanceError, /"日" \(U\+65E5\) is in no font/)
      expect { body.new.to_pdf(conformance: :pdf_a3b, missing_glyphs: :raise) }
        .to raise_error(Stationery::ConformanceError, /is in no font of Open Sans: add a font/)
    end

    it "is taken by conformance at class level" do
      declared = Class.new(body) { conformance :pdf_a3b, :pdf_ua1, missing_glyphs: :replace }

      expect(declared.new.to_pdf).to have_conformance(:pdf_a3b, :pdf_ua1)
      expect { declared.new.to_pdf(missing_glyphs: :raise) }.to raise_error(Stationery::ConformanceError)
    end

    it "is inherited, and a subclass that declares its levels again starts from :raise" do
      declared = Class.new(body) { conformance :pdf_a3b, missing_glyphs: :replace }

      expect(Class.new(declared).new.to_pdf).to have_conformance(:pdf_a3b)
      expect { Class.new(declared) { conformance :pdf_ua1 }.new.to_pdf }.to raise_error(Stationery::ConformanceError)
    end

    it "is taken by to_pdf per render" do
      %i[pdf_a2b pdf_a3b pdf_ua1].each do |level|
        expect(body.new.to_pdf(conformance: level, missing_glyphs: :replace)).to have_conformance(level)
      end
    end

    it "refuses a value it does not know" do
      message = "unknown missing_glyphs: :skip (use :raise or :replace)"

      expect { Class.new(base) { conformance :pdf_a3b, missing_glyphs: :skip } }.to raise_error(ArgumentError, message)
      expect { body.new.to_pdf(conformance: :pdf_a3b, missing_glyphs: :skip) }.to raise_error(ArgumentError, message)
      expect { body.new.to_pdf(missing_glyphs: nil) }.to raise_error(ArgumentError, /unknown missing_glyphs: nil/)
    end

    it "goes with the PDF/A-3b of a Factur-X invoice" do
      xml = %(<?xml version="1.0" encoding="UTF-8"?>\n<rsm:CrossIndustryInvoice/>)
      invoice = Class.new(body) { factur_x xml }

      expect { invoice.new.to_pdf }.to raise_error(Stationery::ConformanceError)
      expect(invoice.new.to_pdf(missing_glyphs: :replace)).to have_conformance(:pdf_a3b)
    end
  end

  describe "what is drawn" do
    it "is the stand-in inside a Span with the characters as ActualText, and never .notdef" do
      pdf = body.new.to_pdf(conformance: :pdf_a3b, missing_glyphs: :replace)

      expect(spans(contents(pdf))).to eq([["FEFF65E5672C", stand_in * 2], ["FEFF65E5", stand_in]])
      expect(codes(contents(pdf))).not_to include("0000")
      expect(to_unicode(pdf)).to include("<#{stand_in}> <FFFD>")
      expect(to_unicode(pdf)[/beginbfchar.*endbfchar/m]).not_to include("<0000>")
    end

    it "extracts as written" do
      pdf = body.new.to_pdf(conformance: :pdf_ua1, missing_glyphs: :replace)

      expect(text_of(pdf)).to eq("in 日本 and 日")
      expect(inspect_pdf(pdf).structure).to eq([[:Document, [[:P, "in 日本 and 日"]]]])
    end

    it "covers headers and page templates" do
      pdf = header.new.to_pdf(conformance: :pdf_a3b, missing_glyphs: :replace)

      expect(spans(contents(pdf))).to contain_exactly(["FEFF2603", stand_in], ["FEFF898B", stand_in])
      expect(text_of(pdf)).to include("☃ head").and include("見 1")
    end

    it "covers a form field's value" do
      pdf = field.new.to_pdf(conformance: :pdf_ua1, missing_glyphs: :replace)
      widget = form_fields(pdf).fetch("name")

      expect(spans(appearance_of(pdf, widget))).to eq([["FEFF8A9E", stand_in]])
      expect(appearance_text(pdf, widget)).to eq(%w[a 語 b])
      expect(decode_text(widget[:V])).to eq("a語b")
    end

    it "maps the stand-in to its own character where the document writes that character too" do
      doc = Class.new(base) { def view_template = text("日 is not \uFFFD, nor 本") }
      pdf = doc.new.to_pdf(conformance: :pdf_a3b, missing_glyphs: :replace)

      expect(spans(contents(pdf)).map(&:first)).to eq(%w[FEFF65E5 FEFF672C])
      expect(to_unicode(pdf).scan(/^<#{stand_in}> <\h+>$/)).to eq(["<#{stand_in}> <FFFD>"])
      expect(text_of(pdf)).to eq("日 is not #{replacement}, nor 本")
    end

    it "is the first of U+FFFD, U+25A1 and ? the font drawing it has" do
      path = font_path("SourceSans3-Latin.otf")
      doc = Class.new(base) do
        font_family "Source Sans", regular: path
        def view_template
          text "日", font: "Inter"
          text "本", font: "Source Sans"
          text "語?"
        end
      end.new
      pdf = doc.to_pdf(conformance: :pdf_a3b, missing_glyphs: :replace)

      expect(doc.warnings.map { |warning| [warning.char, warning.family, warning.stand_in] })
        .to eq([%w[日 Inter □], ["本", "Source Sans", "?"], ["語", "Open Sans", replacement]])
      expect(to_unicode(pdf)).to include("<25A1>").and include("<003F>").and include("<FFFD>")
      expect(text_of(pdf).split).to eq(%w[日 本 語?])
    end

    it "is extracted as written by pdftotext" do
      skip "pdftotext is not installed" unless system("which pdftotext > /dev/null 2>&1")

      pdf = body.new.to_pdf(conformance: :pdf_a3b, missing_glyphs: :replace)
      text = IO.popen(%w[pdftotext - -], "r+b") do |io|
        io.write(pdf)
        io.close_write
        io.read
      end

      expect(text.force_encoding(Encoding::UTF_8).strip).to eq("in 日本 and 日")
    end
  end

  describe "what is reported" do
    it "is the missing glyph and what stood in for it" do
      doc = body.new
      doc.to_pdf(conformance: :pdf_a3b, missing_glyphs: :replace)

      expect(doc.warnings.map(&:message))
        .to eq(["missing glyph \"日\" (U+65E5) in Open Sans, drawn 2 times as \"#{replacement}\" (U+FFFD)",
                "missing glyph \"本\" (U+672C) in Open Sans, drawn once as \"#{replacement}\" (U+FFFD)"])
    end

    it "still fails a strict render" do
      expect { body.new.to_pdf(conformance: :pdf_a3b, missing_glyphs: :replace, strict: true) }
        .to raise_error(Stationery::WarningsError, /missing glyph "日"/)
    end

    it "is not whitespace the font lacks, which stays a blank" do
      doc = Class.new(base) do
        def view_template
          text "wide　space"
          text_field "name", value: "wide　space", tooltip: "Name"
        end
      end.new
      pdf = doc.to_pdf(conformance: :pdf_ua1, missing_glyphs: :replace)

      expect(doc.warnings.to_a).to eq([])
      expect(contents(pdf)).not_to include("Span <</ActualText")
      expect(to_unicode(pdf)).not_to include("<FFFD>")
    end
  end

  describe "a font with no stand-in" do
    it "still raises, saying so" do
      path = font_path("NotoSansJP-Subset.otf")
      symbols = Class.new(base) do
        font_family "Noto Sans JP", regular: path
        def view_template = text("日☃", font: "Noto Sans JP")
      end

      expect { symbols.new.to_pdf(conformance: :pdf_a3b, missing_glyphs: :replace) }
        .to raise_error(Stationery::ConformanceError) do |error|
          expect(error.issues).to eq(['"☃" (U+2603) is in no font of Noto Sans JP, and the font drawing it has none ' \
                                      'of U+FFFD, U+25A1 and "?" to draw in its place: add a font or font_fallbacks ' \
                                      "that covers it"])
        end
    end
  end

  describe "without a conformance level" do
    before { allow(Time).to receive(:now).and_return(Time.utc(2026, 9, 28, 12)) }

    it "changes nothing: a missing glyph draws as .notdef" do
      [body, header, field].each do |document|
        doc = document.new
        pdf = doc.to_pdf(missing_glyphs: :replace)

        expect(pdf).to eq(document.new.to_pdf)
        expect(doc.warnings.map(&:stand_in)).to all(be_nil)
        expect(doc.warnings.map(&:message)).to all(end_with("as .notdef"))
      end
      expect(spans(contents(body.new.to_pdf(missing_glyphs: :replace))))
        .to eq([%w[FEFF65E5672C 00000000], %w[FEFF65E5 0000]])
    end

    it "changes nothing under a level either when every character has a glyph" do
      doc = Class.new(base) { def view_template = text("plain text, with a ? and a \uFFFD") }

      expect(doc.new.to_pdf(conformance: :pdf_a3b, missing_glyphs: :replace))
        .to eq(doc.new.to_pdf(conformance: :pdf_a3b))
    end
  end

  describe "widths" do
    def book = Stationery::Fonts::FontBook.new(SpecDocument.config[:families], stand_ins: true)
    def font(book) = book.resolve(Stationery::Text::Style.new(family: "Open Sans")).first

    it "measures the stand-in that is drawn, not .notdef" do
      font = font(book)
      plain = Stationery::Fonts::Font.new(open_sans)

      expect(font.width_of("日本", 10)).to eq(plain.width_of(replacement * 2, 10))
      expect(font.width_of("日本", 10)).not_to eq(plain.width_of("日本", 10))
      expect(font.glyph_run("a日 本", kerning: true).width(10)).to eq(font.width_of("a日 本", 10, kerning: true))
    end

    it "breaks lines at what is drawn" do
      runs = [Stationery::Text::Run.new("日本語 and " * 30, Stationery::Text::Style.new(family: "Open Sans", size: 10))]
      lines = Stationery::Text::Paragraph.new(runs, book:, width: 200, align: :justify).lines

      expect(lines.size).to be > 5
      lines.each do |line|
        drawn = line.fragments.sum { |fragment| fragment.font.glyph_run(fragment.text).width(10) }

        expect(line.width).to be_within(1e-9).of(drawn)
        expect(drawn).to be <= 200
      end
    end
  end

  describe "text a shaper placed" do
    it "draws the stand-in where the shaper answered glyph 0" do
      doc = Class.new(body) { shaper FakeShapers::REVERSED }.new
      pdf = doc.to_pdf(conformance: :pdf_ua1, missing_glyphs: :replace)

      expect(pdf).to have_conformance(:pdf_ua1)
      expect(contents(pdf)).to include(stand_in)
      expect(codes(contents(pdf))).not_to include("0000")
      expect(text_of(pdf)).to eq("in 日本 and 日")
      expect(doc.warnings.map { |warning| [warning.char, warning.count, warning.stand_in] })
        .to contain_exactly(["日", 2, replacement], ["本", 1, replacement])
    end

    it "advances by the stand-in's width" do
      font = Stationery::Fonts::Font.new(open_sans, shaper: FakeShapers::NOMINAL, stand_ins: true,
                                                    path: font_path("OpenSans-Regular.ttf"))
      run = font.shaped("a日b", 10)

      expect(run.missing).to eq(["日"])
      expect(run.width).to be_within(1e-9).of(Stationery::Fonts::Font.new(open_sans).width_of("a#{replacement}b", 10))
      expect(run.to_operator).to include("/Span <</ActualText <FEFF65E5>>> BDC\n<#{stand_in}> Tj\nEMC")
    end
  end
end
