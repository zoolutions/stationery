# frozen_string_literal: true

RSpec.describe Stationery::PDF::Conformance do
  let(:document) do
    Class.new(SpecDocument) do
      metadata title: "Annual report", lang: "en"
      def view_template
        text "Read the <link href=\"https://example.test\">terms</link>", markup: true
        anchor "totals"
        text "Totals", link: "#totals"
      end
    end
  end

  def catalog_of(pdf)
    objects = reader_for(pdf).objects
    objects.deref(objects.trailer[:Root])
  end

  def annotations_of(pdf)
    reader = reader_for(pdf)
    objects = reader.objects
    reader.pages.flat_map { |page| objects.deref_array(page.attributes[:Annots]).map { objects.deref_hash(it) } }
  end

  describe ".for" do
    it "is nil without levels and takes a Symbol or an Array" do
      expect(described_class.for(nil)).to be_nil
      expect(described_class.for([])).to be_nil
      expect(described_class.for(:pdf_a3b).levels).to eq([:pdf_a3b])
      expect(described_class.for([%w[pdf_a2b pdf_ua1]]).levels).to eq(%i[pdf_a2b pdf_ua1])
    end

    it "refuses unknown levels and two PDF/A levels" do
      expect { described_class.for(:pdf_a1b) }
        .to raise_error(ArgumentError, "unknown conformance :pdf_a1b (use :pdf_a2b, :pdf_a3b, :pdf_ua1)")
      expect { described_class.new(:pdf_a2b, :pdf_a3b) }
        .to raise_error(ArgumentError, "conformance takes one PDF/A level, got pdf_a2b and pdf_a3b")
    end
  end

  it "answers what it claims" do
    both = described_class.new(:pdf_a3b, :pdf_ua1)

    expect(both).to be_pdf_a.and be_pdf_ua
    expect(both.part).to eq(3)
    expect(described_class.new(:pdf_ua1)).not_to be_pdf_a
    expect(described_class.new(:pdf_ua1).part).to be_nil
    expect(described_class.label(:pdf_a2b)).to eq("PDF/A-2b")
  end

  it "identifies the levels in XMP and describes the PDF/UA schema to PDF/A" do
    expect(described_class.new(:pdf_a2b).xmp_extensions)
      .to eq("http://www.aiim.org/pdfa/ns/id/" => { prefix: "pdfaid", "part" => 2, "conformance" => "B" })
    expect(described_class.new(:pdf_ua1).xmp_extensions)
      .to eq("http://www.aiim.org/pdfua/ns/id/" => { prefix: "pdfuaid", "part" => 1 })
    expect(described_class.new(:pdf_ua1).xmp_schemas).to eq([])
    expect(described_class.new(:pdf_a3b, :pdf_ua1).xmp_schemas.map { it[:prefix] }).to eq(["pdfuaid"])
  end

  it "ships the ICC sRGB profile it embeds" do
    profile = File.binread(described_class::ICC_PROFILE)

    expect(profile.byteslice(36, 4)).to eq("acsp")
    expect(profile.byteslice(16, 4)).to eq("RGB ")
    expect(profile.unpack1("N")).to eq(profile.bytesize)
  end

  describe "PDF/A" do
    it "writes the sRGB output intent, the identification and printable annotations" do
      pdf = document.new.to_pdf(conformance: :pdf_a3b)
      objects = reader_for(pdf).objects
      intent = objects.deref_hash(objects.deref_array(catalog_of(pdf)[:OutputIntents]).first)
      profile = objects.deref(intent[:DestOutputProfile])

      expect(intent).to include(Type: :OutputIntent, S: :GTS_PDFA1, OutputConditionIdentifier: "sRGB IEC61966-2.1")
      expect(profile.hash[:N]).to eq(3)
      expect(profile.unfiltered_data).to eq(File.binread(described_class::ICC_PROFILE))
      expect(inspect_pdf(pdf).xmp_values).to include("pdfaid:part" => "3", "pdfaid:conformance" => "B")
      expect(annotations_of(pdf).map { it[:F] }).to eq([4, 4])
      expect(annotations_of(pdf).map { it[:Contents] }).to eq([nil, nil])
      expect(pdf).not_to include("/Tabs")
    end

    it "does not ask for structure: a tagged render only warns about alt text and heading levels" do
      path = image_path("rgb.jpg")
      doc = Class.new(document) do
        define_method(:view_template) do
          text "Details", heading: 2
          image path, width: 20, alt: ""
        end
      end.new

      expect(doc.to_pdf(conformance: :pdf_a3b, tagged: true)).to have_conformance(:pdf_a3b)
      expect(doc.warnings.map(&:message)).to eq(["image on page 1 has no alt: text",
                                                 "heading 2 on page 1 skips a level: the first heading is heading 1"])
      expect(doc.tap { it.to_pdf(conformance: :pdf_a3b) }.warnings.to_a).to eq([])
    end

    it "claims part 2 for :pdf_a2b" do
      expect(inspect_pdf(document.new.to_pdf(conformance: :pdf_a2b)).xmp_values).to include("pdfaid:part" => "2")
    end

    it "refuses encryption" do
      expect { document.new.to_pdf(conformance: :pdf_a3b, encrypt: { owner_password: "o" }) }
        .to raise_error(ArgumentError, "PDF/A forbids encryption: drop encrypt: or the conformance level")
    end

    it "embeds files under PDF/A-3b and refuses them under PDF/A-2b" do
      files = [{ name: "data.xml", data: "<x/>", mime: "text/xml", relationship: :alternative }]

      expect(document.new.to_pdf(conformance: :pdf_a3b, attachments: files)).to have_attachment("data.xml")
      expect { document.new.to_pdf(conformance: :pdf_a2b, attachments: files) }
        .to raise_error(ArgumentError, "PDF/A-2b only embeds PDF/A files: use conformance :pdf_a3b to attach data.xml")
    end

    it "writes the XMP packet even when xmp: false asks for none" do
      expect(inspect_pdf(document.new.to_pdf(conformance: :pdf_a3b, xmp: false)).xmp).to include("pdfaid:part")
    end

    it "reports CMYK colour and CMYK images, which the output intent does not cover" do
      doc = Class.new(SpecDocument) do
        define_method(:view_template) do
          text "ink", color: [0, 0, 0, 100]
          image File.expand_path("../../fixtures/images/cmyk.jpg", __dir__), width: 20
        end
      end.new
      doc.to_pdf(conformance: :pdf_a3b)

      expect(doc.warnings.map(&:message))
        .to eq(["PDF/A-3b: a CMYK image is not covered by the sRGB output intent",
                "PDF/A-3b: CMYK colour on page 1 is not covered by the sRGB output intent"])
      expect { doc.to_pdf(conformance: :pdf_a3b, strict: true) }.to raise_error(Stationery::WarningsError)
      expect(doc.tap(&:to_pdf).warnings.to_a).to eq([])
    end
  end

  describe "PDF/UA" do
    it "tags the document, identifies the level, orders tabs and describes links" do
      pdf = document.new.to_pdf(conformance: :pdf_ua1)
      inspector = inspect_pdf(pdf)

      expect(inspector).to be_tagged
      expect(inspector.xmp_values).to include("pdfuaid:part" => "1")
      expect(inspector.xmp_values).not_to include("pdfaid:part")
      expect(catalog_of(pdf)).not_to have_key(:OutputIntents)
      expect(reader_for(pdf).objects.deref_hash(catalog_of(pdf)[:ViewerPreferences])).to eq(DisplayDocTitle: true)
      expect(reader_for(pdf).pages.first.attributes[:Tabs]).to eq(:S)
      expect(annotations_of(pdf).map { [it[:F], it[:Contents]] }).to eq([[4, "https://example.test"], [4, "Page 1"]])
    end

    it "needs a title and a language" do
      bare = SpecDocument.build { text "x" }

      expect { bare.to_pdf(conformance: :pdf_ua1) }.to raise_error(Stationery::ConformanceError) do |error|
        expect(error.levels).to eq([:pdf_ua1])
        expect(error.issues).to eq(["metadata title: is missing", "metadata lang: is missing"])
        expect(error.message).to eq("not PDF/UA-1:\n  metadata title: is missing\n  metadata lang: is missing")
      end
    end

    it "raises on a figure without alt text and accepts a decorative one" do
      path = image_path("rgb.jpg")
      figure = Class.new(document) { define_method(:view_template) { image path, width: 20 } }
      decorative = Class.new(document) { define_method(:view_template) { image path, width: 20, alt: false } }

      expect { figure.new.to_pdf(conformance: :pdf_ua1) }
        .to raise_error(Stationery::ConformanceError, "not PDF/UA-1:\n  image on page 1 has no alt: text")
      expect(decorative.new.to_pdf(conformance: :pdf_ua1)).to start_with("%PDF")
    end

    it "raises on a figure whose alt text is blank" do
      path = image_path("rgb.jpg")
      drawing = %(<svg viewBox="0 0 10 10"><rect width="10" height="10"/></svg>)
      figures = Class.new(document) do
        define_method(:view_template) do
          image path, width: 20, alt: ""
          svg drawing, width: 10, alt: "  "
        end
      end

      expect { figures.new.to_pdf(conformance: :pdf_ua1) }.to raise_error(Stationery::ConformanceError) do |error|
        expect(error.issues).to eq(["image on page 1 has no alt: text", "svg on page 1 has no alt: text"])
      end
    end

    it "raises on heading levels that are skipped, one issue each" do
      skipping = Class.new(document) do
        define_method(:view_template) do
          text "Details", heading: 2
          text "More", heading: 4
          text "Report", heading: 1
        end
      end
      kept = Class.new(document) do
        define_method(:view_template) { [1, 2, 3, 1].each { |level| text "Level #{level}", heading: level } }
      end

      expect { skipping.new.to_pdf(conformance: %i[pdf_a3b pdf_ua1]) }
        .to raise_error(Stationery::ConformanceError) do |error|
          expect(error.issues)
            .to eq(["heading 2 on page 1 skips a level: the first heading is heading 1",
                    "heading 4 on page 1 skips a level: heading 3 is the deepest that may follow heading 2"])
        end
      expect(kept.new.to_pdf(conformance: :pdf_ua1)).to have_conformance(:pdf_ua1)
    end

    it "may be encrypted" do
      expect(document.new.to_pdf(conformance: :pdf_ua1, encrypt: { owner_password: "o" })).to include("/Encrypt")
    end
  end

  it "combines PDF/A and PDF/UA, describing the PDF/UA schema" do
    pdf = document.new.to_pdf(conformance: %i[pdf_a3b pdf_ua1])
    packet = inspect_pdf(pdf).xmp

    expect(inspect_pdf(pdf).conformance).to eq(%i[pdf_a3b pdf_ua1])
    expect(packet).to include("<pdfaExtension:schemas><rdf:Bag>")
      .and include("<pdfaSchema:namespaceURI>http://www.aiim.org/pdfua/ns/id/</pdfaSchema:namespaceURI>")
      .and include("<pdfaProperty:valueType>Integer</pdfaProperty:valueType>")
  end

  describe "interactive form fields" do
    let(:form) do
      Class.new(document) do
        def view_template
          text_field "name", value: "Astrid"
          select "country", options: %w[Sweden Norway], value: "Sweden"
          checkbox "terms", label: "I accept the terms"
          radio "plan", "pro", checked: true, label: "Pro"
          signature_field "signature"
        end
      end
    end

    it "are allowed: their appearances draw with embedded fonts and nothing asks to regenerate them" do
      %i[pdf_a3b pdf_ua1].each do |level|
        pdf = form.new.to_pdf(conformance: level)

        expect(pdf).to have_conformance(level)
        expect(acro_form(pdf)).not_to have_key(:NeedAppearances)
        expect(form_fonts(pdf).values.map { it[:Subtype] }).to all(eq(:Type0))
        expect(form_fields(pdf).values.map { decode_text(it[:TU]) })
          .to eq(["name", "country", "I accept the terms", "plan", "Signature"])
        expect(pdf).not_to include("Helvetica", "ZapfDingbats")
      end
    end

    it "keep asking viewers to regenerate appearances without a conformance level" do
      expect(acro_form(form.new.to_pdf)[:NeedAppearances]).to be(true)
    end

    it "are refused when made without a font book, since Helvetica is not embedded" do
      raw = Class.new(document) do
        def view_template
          field = Stationery::Forms::Field.new(:text, "raw", value: "x")
          canvas(height: 30) { |canvas, rect| canvas.widget(field, rect.x, rect.y, 100, 20) }
          text_field "name", value: "Astrid"
        end
      end

      expect { raw.new.to_pdf(conformance: :pdf_a3b) }.to raise_error(Stationery::ConformanceError) do |error|
        expect(error.issues).to eq(['form field "raw" draws with a font that is not embedded'])
      end
      expect { raw.new.to_pdf(conformance: :pdf_ua1) }.to raise_error(Stationery::ConformanceError, /form field "raw"/)
    end
  end

  describe "on the document" do
    it "takes the levels at class level, validated when declared, and per render" do
      archived = Class.new(document) { conformance :pdf_a3b }

      expect(archived.new.to_pdf).to have_conformance(:pdf_a3b)
      expect(archived.new.to_pdf(conformance: nil)).not_to include("OutputIntent")
      expect(archived.new.to_pdf(conformance: :pdf_ua1)).to have_conformance(:pdf_ua1)
      expect(Class.new(archived).new.to_pdf).to have_conformance(:pdf_a3b)
      expect { Class.new(document) { conformance :pdf_x } }.to raise_error(ArgumentError, /unknown conformance :pdf_x/)
    end

    it "leaves a render without conformance byte for byte as it was" do
      allow(Time).to receive(:now).and_return(Time.utc(2026, 9, 28))
      plain = document.new.to_pdf

      expect(document.new.to_pdf(conformance: nil)).to eq(plain)
      expect(document.new.to_pdf(conformance: [])).to eq(plain)
      expect(plain).not_to include("OutputIntent")
      expect(plain).not_to match(%r{/Subtype /Link[^>]*/F 4})
    end
  end
end
