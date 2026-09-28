# frozen_string_literal: true

# The html element's CSS subset, drawn. The page is 300 × 200 with a 20 pt
# margin, the text Open Sans at 10 pt.
RSpec.describe "Stationery::Rich::Renderer" do
  def document(&) = SpecDocument.build(&)
  def render(&) = document(&).to_pdf
  def ops(pdf, page = 0) = page_contents(pdf)[page]
  def fonts(pdf) = ops(pdf).scan(%r{/(F\d+) ([\d.]+) Tf}).uniq
  def origins(pdf) = ops(pdf).scan(/^([\d.]+) ([\d.]+) Td$/).map { |x, y| [x.to_f, y.to_f] }
  def rects(pdf) = ops(pdf).scan(/^([\d.]+) ([\d.]+) ([\d.]+) ([\d.]+) re$/).map { |rect| rect.map(&:to_f) }

  describe "text" do
    it "colours and sizes runs from inline styles and rules" do
      pdf = render do
        html %(<style>.big { font-size: 20px } em { color: #00f }</style>
               <p class="big" style="color: red">Red <em>blue</em> <span style="font-size: 50%">half</span></p>)
      end

      expect(strings_of(pdf)).to eq(["Red ", "blue", " ", "half"])
      expect(ops(pdf)).to include("1 0 0 rg").and include("0 0 1 rg")
      expect(fonts(pdf).map(&:last).uniq).to contain_exactly("15", "7.5")
    end

    it "scales em, percentage and keyword sizes from the text around them" do
      pdf = render do
        html %(<p>a <span style="font-size: 2em">b <span style="font-size: 50%">c</span></span>) +
             %( <font size="5">d</font></p>)
      end

      expect(fonts(pdf).map(&:last)).to eq(%w[10 20 15])
    end

    it "switches bold, italic, underline and strike off inside an element that has them" do
      plain = render { html "<p>a b</p>" }
      undone = render do
        html %(<p><b><i><u><s><span style="font-weight: normal; font-style: normal; text-decoration: none">) +
             %(a b</span></s></u></i></b></p>)
      end

      expect(ops(undone)).to eq(ops(plain))
    end

    it "aligns paragraphs and headings, handing the alignment down from a container" do
      left = render { html "<h2>Title</h2><p>text</p>" }
      centred = render { html %(<div style="text-align: center"><h2>Title</h2><p>text</p></div>) }
      right = render do
        html %(<h2 style="text-align: right">Title</h2><center><p style="text-align: right">text</p></center>)
      end

      expect(origins(left).map(&:first)).to eq([20.0, 20.0])
      expect(origins(centred).map(&:first)).to all(be_between(100, 150))
      expect(origins(right).map(&:first)).to all(be > 200)
      expect(origins(right).map(&:last)).to eq(origins(left).map(&:last))
    end
  end

  describe "boxes" do
    it "draws a background and padding around a paragraph and a container" do
      pdf = render do
        html %(<p style="background-color: #ff0; padding: 10pt">boxed</p>
               <div style="background-color: rgb(0, 0, 255); padding: 4pt 8pt"><p>in</p><p>side</p></div>)
      end
      yellow, blue = rects(pdf)

      expect(ops(pdf)).to include("1 1 0 rg").and include("0 0 1 rg")
      expect(yellow.values_at(0, 2)).to eq([20.0, 260.0])
      expect(origins(pdf).first.first).to eq(30.0)
      expect(origins(pdf)[1].first).to eq(28.0)
      expect(blue[3]).to be > yellow[3]
    end

    it "spaces a block with its margins, on top of the gap between blocks" do
      plain = render { html "<p>a</p><p>b</p><p>c</p>" }
      spaced = render { html %(<p>a</p><p style="margin: 10pt 0 5pt">b</p><p>c</p>) }
      ys = origins(plain).map(&:last)
      moved = origins(spaced).map(&:last)

      expect(moved[0]).to eq(ys[0])
      expect(ys[1] - moved[1]).to be_within(0.001).of(10)
      expect(ys[2] - moved[2]).to be_within(0.001).of(15)
    end

    it "merges a style over the block quote and code block boxes" do
      pdf = render do
        html %(<blockquote style="background-color: #f00; padding: 6pt">q</blockquote>) +
             %(<pre style="background-color: #0f0">c</pre>)
      end

      expect(ops(pdf)).to include("1 0 0 rg").and include("0 1 0 rg")
      expect(ops(pdf)).not_to include("0.9529 0.9569 0.9647 rg")
      expect(origins(pdf).first.first).to eq(29.0) # the quote's 3 pt bar, then the padding
    end
  end

  describe "tables" do
    it "draws borders from the table and from a cell, and cell backgrounds and padding" do
      pdf = render do
        html %(<table style="border: 2pt solid #00f"><tr>
                 <td style="background-color: #ff0; padding: 10pt">a</td>
                 <td style="border: 1pt solid red">b</td><td style="border: none">c</td></tr></table>)
      end

      expect(ops(pdf)).to include("0 0 1 RG\n2 w").and include("1 0 0 RG\n1 w").and include("1 1 0 rg")
      expect(ops(pdf).scan(/ RG$/).size).to eq(2)
      expect(origins(pdf).first.first).to eq(30.0)
    end

    it "takes column widths from the first row when every cell has one" do
      sized = render do
        html %(<table><tr><td style="width: 100pt">a</td><td style="width: 40%">b</td></tr>) +
             %(<tr><td>c</td><td>d</td></tr></table>)
      end
      partial = render { html %(<table><tr><td style="width: 100pt">a</td><td>b</td></tr></table>) }

      expect(rects(sized).map { |rect| rect[2] }).to eq([100.0, 104.0, 100.0, 104.0])
      expect(rects(partial).map { |rect| rect[2] }).not_to include(100.0)
    end

    it "sizes the table itself in points, as a share of the width and in full" do
      widths = ["150pt", "50%", "100%"].map do |width|
        pdf = render { html %(<table style="width: #{width}"><tr><td>a</td><td>b</td></tr></table>) }
        rects(pdf).sum { |rect| rect[2] }
      end

      expect(widths).to eq([150.0, 130.0, 260.0])
    end
  end

  describe "images" do
    let(:photo) { image_path("rgb.jpg") }

    def drawn(pdf) = ops(pdf)[/^([\d.]+) 0 0 ([\d.]+) ([\d.]+) [\d.]+ cm$/].split.values_at(0, 3, 4).map(&:to_f)

    it "sizes an image in points or as a share of the width, keeping its aspect ratio" do
      source = photo
      points = render { html %(<img src="p" width="8" height="8" style="width: 80pt">), images: ->(_) { source } }
      share = render { html %(<img src="p" style="width: 50%">), images: ->(_) { source } }

      expect(drawn(points)).to eq([80.0, 60.0, 20.0])
      expect(drawn(share)).to eq([130.0, 97.5, 20.0])
    end

    it "places an image with the alignment of the paragraph it is in, and keeps max_width" do
      source = photo
      pdf = render do
        html %(<p style="text-align: center"><img src="p" style="width: 100pt"></p>),
             images: ->(_) { source }, styles: { img: { max_width: 60 } }
      end

      expect(drawn(pdf)).to eq([60.0, 45.0, 120.0])
    end
  end

  describe "columns" do
    def lines(count) = Array.new(count) { |i| "line #{i + 1}" }.join("<br>")

    it "pours a container through balanced columns with column-count and column-gap" do
      body = lines(6)
      pdf = render { html %(<div style="column-count: 2; column-gap: 20pt"><p>#{body}</p></div><p>after</p>) }
      left, right = origins(pdf).first(6).partition { |x, _| x < 100 }

      expect(right.map(&:first)).to eq([160.0] * 3)
      expect(right.map(&:last)).to eq(left.map(&:last))
      expect(origins(pdf).last.first).to eq(20.0)
      expect(origins(pdf).last.last).to be < left.last.last
    end

    it "reads columns: <n> on a paragraph and a list, with the default gap" do
      body = lines(4)
      pdf = render { html %(<style>p { columns: 2 }</style><p>#{body}</p>) }
      list = render { html %(<ul style="columns: 2"><li>one</li><li>two</li></ul>) }

      expect(origins(pdf).map(&:first)).to eq([20.0, 20.0, 156.0, 156.0])
      expect(origins(list).map(&:last).uniq.size).to eq(1)
    end

    it "pours the content of a block quote and of a code block through columns, inside their box" do
      body = lines(4)
      quote = render { html %(<blockquote style="columns: 2"><p>#{body}</p></blockquote>) }
      plain = render { html %(<blockquote><p>#{body}</p></blockquote>) }
      code = render { html %(<pre style="column-count: 2">#{body.gsub("<br>", "\n")}</pre>) }

      expect(origins(plain).map(&:first).uniq.size).to eq(1)
      expect(origins(quote).map(&:first).uniq.size).to eq(2)
      expect(origins(quote).map(&:first).min).to eq(origins(plain).map(&:first).min)
      expect(origins(quote).map(&:last).uniq.size).to eq(2)
      expect(origins(code).map(&:first).uniq.size).to eq(2)
      expect(origins(code).map(&:last).uniq.size).to eq(2)
    end

    it "draws one column as it drew before and reports what it does not read" do
      document = self.document do
        html %(<div style="column-count: 1"><p>one</p></div><div style="columns: 12em; column-gap: -2px">x</div>)
      end
      plain = render { html "<p>one</p><div>x</div>" }

      expect(ops(document.to_pdf)).to eq(ops(plain))
      expect(document.warnings.map(&:properties)).to eq([["columns: 12em", "column-gap: -2px"]])
    end
  end

  describe "floated images" do
    let(:photo) { image_path("rgb.jpg") }
    let(:words) { Array.new(40) { |i| "word#{i}" }.join(" ") }

    def drawn(pdf) = ops(pdf)[/^([\d.]+) 0 0 ([\d.]+) ([\d.]+) [\d.]+ cm$/].split.values_at(0, 3, 4).map(&:to_f)

    it "wraps the text that follows beside an image floated left" do
      source = photo
      text = words
      document = document do
        html %(<p><img src="p" style="float: left; width: 80pt; margin: 0 10pt 0 0">#{text}</p><p>Next</p>),
             images: ->(_) { source }
      end
      pdf = document.to_pdf

      expect(drawn(pdf)).to eq([80.0, 60.0, 20.0])
      expect(origins(pdf).map(&:first).first(5)).to eq([110.0, 110.0, 110.0, 110.0, 110.0])
      expect(origins(pdf).map(&:first).last(2)).to eq([20.0, 20.0])
      expect(document.warnings).to be_empty
    end

    it "floats an image with the align attribute to the right, a default margin away from the text" do
      source = photo
      text = words
      pdf = render { html %(<img src="p" align="right" width="80">#{text}), images: ->(_) { source } }
      custom = render do
        html %(<img src="p" align="right" width="80">#{text}),
             images: ->(_) { source }, styles: { img: { float_margin: 60 } }
      end

      expect(drawn(pdf)).to eq([80.0, 60.0, 200.0])
      expect(origins(pdf).map(&:first).uniq).to eq([20.0])
      expect(strings_of(custom).first.split.size).to be < strings_of(pdf).first.split.size
    end

    it "takes margin-top and margin-bottom over the margin" do
      source = photo
      pdf = render do
        html %(<img src="p" style="float: left; width: 80pt; margin: 5pt; margin-top: 0; margin-bottom: 30pt">word),
             images: ->(_) { source }
      end

      expect(drawn(pdf)).to eq([80.0, 60.0, 25.0])
      expect(origins(pdf).first.first).to eq(110.0)
    end

    it "keeps reporting float where it is not read" do
      document = document { html %(<div style="float: left">Text</div>) }
      document.to_pdf

      expect(document.warnings.map(&:message)).to eq(["html styles not read: properties float"])
    end
  end

  describe "page breaks" do
    it "starts a new page before or after a block" do
      pdf = render do
        html %(<p>one</p><h2 style="page-break-before: always">two</h2>
               <p style="break-after: page">three</p><p>four</p>)
      end

      expect(inspect_pdf(pdf).page_texts).to eq(%W[one two\nthree four])
    end

    it "breaks before the first block of the html when something is above it" do
      pdf = render do
        text "cover"
        html %(<h1 style="page-break-before: always">Chapter</h1><p>text</p>)
      end
      alone = render { html %(<h1 style="page-break-before: always">Chapter</h1>) }

      expect(inspect_pdf(pdf).page_texts).to eq(%W[cover Chapter\ntext])
      expect(alone).to have_page_count(1)
    end

    it "keeps a block on one page with break-inside: avoid" do
      lines = Array.new(9) { |i| "<p>line #{i}</p>" }.join
      split = render { html %(<p>top</p><div class="x">#{lines}</div>) }
      kept = render { html %(<p>top</p><div style="break-inside: avoid">#{lines}</div>) }

      expect(inspect_pdf(split).page_texts.first).to include("line 0")
      expect(inspect_pdf(kept).page_texts.first).to eq("top")
      expect(kept).to have_page_count(2)
    end
  end

  describe "what is not read" do
    it "is reported once per html call, with the rest of the document drawn" do
      doc = document do
        html %(<style>p > b { color: red } p { display: flex; color: green }</style>
               <p style="float: left; width: auto">a</p><p style="float: right">b</p>)
      end
      pdf = doc.to_pdf

      expect(doc.warnings.map(&:message)).to eq(
        ["html styles not read: properties display, float; selectors p > b"]
      )
      expect(doc.warnings.first).to eq(
        Stationery::Warnings::UnsupportedCss.new(properties: %w[display float], selectors: ["p > b"])
      )
      expect(strings_of(pdf)).to eq(%w[a b])
      expect(ops(pdf)).to include("0 0.502 0 rg")
    end

    it "never reads a url" do
      doc = document { html %(<p style="background-color: url(https://x.test/a.png); color: url(x)">a</p>) }

      expect(text_of(doc.to_pdf)).to eq("a")
      expect(doc.warnings.first.properties).to eq(["background-color: url(https://x.test/a.png)", "color: url(x)"])
    end

    it "raises under strict like any other warning" do
      doc = document { html %(<p style="float: left">a</p>) }

      expect { doc.to_pdf(strict: true) }.to raise_error(Stationery::WarningsError, /float/)
    end
  end

  describe "without styles" do
    it "draws exactly what it drew before, classes and ids included" do
      html = File.read(File.expand_path("../../fixtures/html/trix.html", __dir__))
      bare = document { html html }
      marked = document { html html.gsub("<div>", %(<div class="trix-content" id="x">)) }

      expect(page_contents(marked.to_pdf)).to eq(page_contents(bare.to_pdf))
      expect(bare.warnings.to_a).to be_empty
    end

    it "leaves markdown alone" do
      doc = document { markdown "# T\n\n<style>p { color: red }</style>\n\ntext" }

      expect(ops(doc.to_pdf)).not_to include("1 0 0 rg")
      expect(doc.warnings.to_a).to be_empty
    end
  end
end
