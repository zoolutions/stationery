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

  describe "heading levels" do
    it "warns about a level that is skipped, on the page the heading is on" do
      doc = build do
        text "Report", heading: 1
        page_break
        text "Details", heading: 3
      end

      expect(warnings_of(doc))
        .to eq(["heading 3 on page 2 skips a level: heading 2 is the deepest that may follow heading 1"])
      expect(doc.warnings.to_a).to eq([Stationery::Warnings::SkippedHeading.new(level: 3, allowed: 2, page: 2)])
      expect { doc.to_pdf(strict: true) }.to raise_error(Stationery::WarningsError)
    end

    it "warns about a first heading that is not heading 1" do
      doc = build { text "Details", heading: 2 }

      expect(warnings_of(doc)).to eq(["heading 2 on page 1 skips a level: the first heading is heading 1"])
    end

    it "accepts levels that go down one at a time and back up by any amount" do
      doc = build { [1, 2, 3, 1, 2, 2, 3, 4, 2].each { |level| text "Level #{level}", heading: level } }

      expect(warnings_of(doc)).to be_empty
    end

    it "reads html and markdown headings" do
      from_html = build { html "<h1>One</h1><p>Body</p><h3>Three</h3>" }
      from_markdown = build { markdown "## Two\n\nBody\n\n### Three\n" }

      expect(warnings_of(from_html))
        .to eq(["heading 3 on page 1 skips a level: heading 2 is the deepest that may follow heading 1"])
      expect(warnings_of(from_markdown)).to eq(["heading 2 on page 1 skips a level: the first heading is heading 1"])
    end

    it "finds headings in sections, lists, table cells, columns and floats" do
      doc = build do
        text "One", heading: 1
        box(role: :section) { text "Three", heading: 3 }
        ul { li "Five", heading: 5 }
        table([[-> { text "Two", heading: 2 }, -> { text "Four", heading: 4 }]])
        columns(count: 2) { text "Six", heading: 6 }
        text "One", heading: 1
        box(float: :right, width: 80) { text "Five", heading: 5 }
      end

      expect(doc.tap(&:to_pdf).warnings.map { [it.level, it.allowed] }).to eq([[3, 2], [5, 4], [4, 3], [6, 5], [5, 2]])
    end

    it "does not count the headings of headers, footers and page templates, which are artifacts" do
      klass = Class.new(tagged) do
        header { text "Running head", heading: 1 }
        footer { text "Running foot", heading: 4 }
        page_template { box(at: [5, 5]) { text "Stamp", heading: 6 } }
      end

      expect(warnings_of(build(klass) { text "Details", heading: 2 }))
        .to eq(["heading 2 on page 1 skips a level: the first heading is heading 1"])
      expect(warnings_of(build(klass) { text "Report", heading: 1 })).to be_empty
    end

    it "does not count a heading without text, which is not written" do
      doc = build do
        text "One", heading: 1
        text "", heading: 2
        text "Three", heading: 3
      end
      pdf = doc.to_pdf

      expect(struct_types(pdf)).to eq([[:Document, %i[H1 H3]]])
      expect(doc.warnings.map { [it.level, it.allowed] }).to eq([[3, 2]])
    end

    it "leaves a document that is not tagged alone" do
      doc = SpecDocument.build { text "Details", heading: 3 }

      expect(warnings_of(doc)).to be_empty
    end
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
