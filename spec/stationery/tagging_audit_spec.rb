# frozen_string_literal: true

RSpec.describe "Tagged PDF audit" do # rubocop:disable RSpec/DescribeClass
  let(:tagged) do
    Class.new(SpecDocument) do
      tagged
      metadata title: "Report", lang: "en"
    end
  end
  let(:logo) { image_path("rgb.jpg") }
  let(:drawing) { %(<svg viewBox="0 0 10 10"><rect width="10" height="10"/></svg>) }

  def build(klass = tagged, &) = Class.new(klass) { define_method(:view_template, &) }.new

  def warnings_of(doc, **)
    doc.to_pdf(**)
    doc.warnings.map(&:message)
  end

  describe "alt text" do
    it "warns about a blank alt: as about a missing one" do
      logo = self.logo
      drawing = self.drawing
      doc = build do
        image logo, width: 20, alt: ""
        svg drawing, width: 10, alt: " \n\t"
        page_break
        image logo, width: 20, alt: "Logo"
        svg drawing, width: 10
      end

      expect(warnings_of(doc)).to eq(["image on page 1 has no alt: text", "svg on page 1 has no alt: text",
                                      "svg on page 2 has no alt: text"])
      expect { doc.to_pdf(strict: true) }.to raise_error(Stationery::WarningsError)
    end

    it "warns about an html or markdown image without a description" do
      logo = self.logo
      from_html = build { html %(<p>Logo</p><img src="rgb.jpg" alt="" width="10">), images: ->(_) { logo } }
      from_markdown = build { markdown "Logo\n\n![ ](rgb.jpg)\n", images: ->(_) { logo } }

      expect(warnings_of(from_html)).to eq(["image on page 1 has no alt: text"])
      expect(warnings_of(from_markdown)).to eq(["image on page 1 has no alt: text"])
    end

    it "accepts a decorative image and a blank alt: in a document that is not tagged" do
      logo = self.logo
      view = proc do
        image logo, width: 20, alt: false
        image logo, width: 20, alt: "Logo"
      end

      expect(warnings_of(build(&view))).to be_empty
      expect(warnings_of(SpecDocument.build { image logo, width: 20, alt: "" })).to be_empty
    end
  end
end
