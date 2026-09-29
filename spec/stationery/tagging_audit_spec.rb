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

      expect(warnings_of(doc)).to eq(["image on page 1 has no alt: text (alt: false marks decoration)",
                                      "svg on page 1 has no alt: text (alt: false marks decoration)",
                                      "svg on page 2 has no alt: text (alt: false marks decoration)"])
      expect { doc.to_pdf(strict: true) }.to raise_error(Stationery::WarningsError)
    end

    it "takes an html image with an empty alt for decoration, floated or not" do
      logo = self.logo
      markup = %(<p>Logo</p><img src="rgb.jpg" alt="" width="10"><img src="rgb.jpg" alt=" " width="10">) +
               %(<p><img src="rgb.jpg" alt="" width="10" style="float: right; margin-left: 6px">Beside</p>)
      doc = build { html markup, images: ->(_) { logo } }
      pdf = doc.to_pdf

      expect(doc.warnings).to be_empty
      expect(image_count(pdf)).to eq(1)
      expect(page_contents(pdf).first.scan(%r{/Artifact BMC\nq\n[^\n]+ cm\n/Im1 Do}).size).to eq(3)
      expect(struct_types(pdf)).to eq([[:Document, %i[P P]]])
    end

    it "warns about an html image without an alt and a markdown image without a description" do
      logo = self.logo
      from_html = build { html %(<p>Logo</p><img src="rgb.jpg" width="10">), images: ->(_) { logo } }
      empty = build { markdown "Logo\n\n![](rgb.jpg)\n", images: ->(_) { logo } }
      blank = build { markdown "Logo\n\n![ ](rgb.jpg)\n", images: ->(_) { logo } }

      [from_html, empty, blank].each do |doc|
        expect(warnings_of(doc)).to eq(["image on page 1 has no alt: text (alt: false marks decoration)"])
        expect(struct_types(doc.to_pdf)).to eq([[:Document, %i[P Figure]]])
      end
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

  describe "links" do
    def untagged(target, place, page) = Stationery::Warnings::UntaggedLink.new(target:, place:, page:)

    it "warns about a link drawn on the canvas of a header, a footer or a page template, on every page" do
      draw = ->(target) { proc { |canvas, rect| canvas.link(rect.x, rect.y, 50, 10, target) } }
      klass = Class.new(tagged) do
        header { canvas(height: 10, &draw.call("https://example.com/head")) }
        footer { canvas(height: 10, &draw.call("#top")) }
        page_template { box(at: [36, 20]) { canvas(height: 10, &draw.call("https://example.com/stamp")) } }
      end
      doc = build(klass) do
        anchor "top"
        text "Report", heading: 1
        page_break
        text "More"
      end

      expect(warnings_of(doc))
        .to eq(["link to https://example.com/head in the header of page 1 is outside the structure tree",
                "link to #top in the footer of page 1 is outside the structure tree",
                "link to https://example.com/stamp in a page template of page 1 is outside the structure tree",
                "link to https://example.com/head in the header of page 2 is outside the structure tree",
                "link to #top in the footer of page 2 is outside the structure tree",
                "link to https://example.com/stamp in a page template of page 2 is outside the structure tree"])
      expect(doc.warnings.first).to eq(untagged("https://example.com/head", :header, 1))
      expect { doc.to_pdf(strict: true) }.to raise_error(Stationery::WarningsError)
      expect { doc.to_pdf(conformance: :pdf_ua1) }.to raise_error(Stationery::ConformanceError, /\(7\.18\.5\)/)
    end

    it "accepts the links a header, a footer and a page template paint as text and boxes" do
      klass = Class.new(tagged) do
        header { text "Home", link: "https://example.com/head" }
        footer { text %(See <link href="#top">the top</link>), markup: true }
        page_template { |page| box(at: [36, page.height - 20], link: "https://example.com/stamp") { text "Stamp" } }
      end
      doc = build(klass) do
        anchor "top"
        text "Report", heading: 1
      end

      expect(warnings_of(doc)).to be_empty
      expect { doc.to_pdf(conformance: :pdf_ua1, strict: true) }.not_to raise_error
    end

    it "warns about a link drawn on the canvas without a Link element" do
      doc = build do
        text "Report", heading: 1
        canvas(height: 20) { |canvas, rect| canvas.link(rect.x, rect.y, 50, 20, "https://example.com") }
      end

      expect(warnings_of(doc))
        .to eq(["link to https://example.com drawn by canvas.link without a tag: on page 1 " \
                "is outside the structure tree"])
      expect(doc.warnings.to_a).to eq([untagged("https://example.com", :canvas, 1)])
    end

    it "warns about a link in any other artifact, such as the header row a table repeats" do
      doc = build do
        table([[-> { text "Name", link: "https://example.com/names" }]] + Array.new(12) { ["Row #{it}"] }, header: 1)
      end

      expect(warnings_of(doc))
        .to eq(["link to https://example.com/names in an artifact of page 2 is outside the structure tree",
                "link to https://example.com/names in an artifact of page 3 is outside the structure tree"])
    end

    it "accepts the links of the body: text, markup, boxes, html, markdown and a tagged canvas link" do
      element = Stationery::Tagging::Element.new(:Link)
      doc = build do
        anchor "top"
        text "Report", heading: 1, link: "#top"
        text %(Read the <link href="https://example.com">terms</link>), markup: true
        box(link: "https://example.com/box") { text "Boxed" }
        html %(<p><a href="https://example.com/html">html</a></p>)
        markdown "[markdown](https://example.com/markdown)"
        canvas(height: 20) do |canvas, rect|
          canvas.tag(element) { canvas.rounded_rect(rect.x, rect.y, 50, 20, radius: 0, fill: "#000000") }
          canvas.link(rect.x, rect.y, 50, 20, "https://example.com/canvas", tag: element)
        end
      end
      pdf = doc.to_pdf

      expect(doc.warnings).to be_empty
      expect(inspect_pdf(pdf).links.size).to eq(5)
      expect(unpacked(pdf).scan("/StructParent ").size).to eq(6)
    end

    it "leaves a document that is not tagged alone, byte for byte" do
      view = proc do
        text "Body"
        canvas(height: 20) { |canvas, rect| canvas.link(rect.x, rect.y, 50, 20, "https://example.com") }
      end
      doc = Class.new(SpecDocument) { footer { text "example.com", link: "https://example.com" } }
      doc = Class.new(doc) { define_method(:view_template, &view) }.new

      expect(warnings_of(doc)).to be_empty
      expect(doc.to_pdf).not_to include("place")
    end
  end
end
