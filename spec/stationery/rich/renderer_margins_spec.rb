# frozen_string_literal: true

# The horizontal margins of the html element's CSS subset, drawn. The page is
# 300 × 200 with a 20 pt margin, the text Open Sans at 10 pt.
RSpec.describe "Stationery::Rich::Renderer" do
  def document(&) = SpecDocument.build(&)
  def render(&) = document(&).to_pdf
  def ops(pdf, page = 0) = page_contents(pdf)[page]
  def origins(pdf) = ops(pdf).scan(/^([\d.]+) ([\d.]+) Td$/).map { |x, y| [x.to_f, y.to_f] }
  def rects(pdf) = ops(pdf).scan(/^([\d.]+) ([\d.]+) ([\d.]+) ([\d.]+) re$/).map { |rect| rect.map(&:to_f) }

  let(:words) { Array.new(40) { |i| "word#{i}" }.join(" ") }

  describe "margins on a block" do
    {
      "a paragraph" => "<p%s>text</p>",
      "a heading" => "<h2%s>text</h2>",
      "a container" => "<div%s><p>one</p><p>two</p></div>",
      "a list" => "<ul%s><li>one</li><li>two</li></ul>",
      "a table" => "<table%s><tr><td>a</td><td>b</td></tr></table>",
      "a block quote" => "<blockquote%s>text</blockquote>",
      "a code block" => "<pre%s>text</pre>"
    }.each do |name, markup|
      it "indents #{name} from the left by margin-left" do
        plain = render { html format(markup, "") }
        indented = render { html format(markup, %( style="margin-left: 30pt")) }

        expect(origins(indented)).to eq(origins(plain).map { |x, y| [x + 30, y] })
      end
    end

    it "keeps the text out of margin-right" do
      text = words
      narrow = render { html %(<p style="margin-right: 100pt">#{text}</p>) }
      boxed = render { box(width: 160) { html "<p>#{text}</p>" } }

      expect(strings_of(narrow)).to eq(strings_of(boxed))
      expect(origins(narrow)).to eq(origins(boxed))
    end

    it "draws the block's background inside its margins" do
      pdf = render { html %(<p style="background-color: #ff0; padding: 5pt; margin: 0 10pt 0 30pt">boxed</p>) }

      expect(rects(pdf).first.values_at(0, 2)).to eq([50.0, 220.0])
      expect(origins(pdf).first.first).to eq(55.0)
    end

    it "reads the left and right of the margin shorthand, and a side over it" do
      short = render { html %(<p style="margin: 0 20px">text</p><p>next</p>) }
      sides = render { html %(<p style="margin-left: 15pt; margin-right: 15pt">text</p><p>next</p>) }
      over = render { html %(<p style="margin: 4pt 40pt; margin-left: 15pt; margin-right: 15pt">text</p><p>next</p>) }

      expect(origins(short).map(&:first)).to eq([35.0, 20.0])
      expect(ops(short)).to eq(ops(sides))
      expect(origins(over).map(&:first)).to eq([35.0, 20.0])
    end

    it "adds the margins of the blocks inside one another" do
      pdf = render { html %(<div style="margin-left: 10pt"><p style="margin-left: 5pt">in</p><p>out</p></div>) }

      expect(origins(pdf).map(&:first)).to eq([35.0, 30.0])
    end

    it "draws nothing for a negative margin, and reports the side that asks for one" do
      plain = render { html "<p>text</p>" }
      short = document { html %(<p style="margin: 0 -20pt">text</p>) }
      side = document { html %(<p style="margin-left: -20pt; margin-right: auto">text</p>) }

      expect(ops(short.to_pdf)).to eq(ops(plain))
      expect(ops(side.to_pdf)).to eq(ops(plain))
      expect(short.warnings.to_a).to be_empty
      expect(side.warnings.map(&:message)).to eq(
        ["html styles not read: properties margin-left: -20pt, margin-right: auto"]
      )
    end

    it "splits an indented paragraph across pages where it stands" do
      lines = Array.new(14) { |i| "line #{i}" }.join("<br>")
      pdf = render { html %(<p>top</p><p style="margin-left: 30pt">#{lines}</p>) }
      texts = inspect_pdf(pdf).page_texts

      expect(texts.first).to include("top").and include("line 0")
      expect(texts.last).to include("line 13")
      expect(origins(pdf).drop(1).map(&:first).uniq).to eq([50.0])
      expect(ops(pdf, 1).scan(/^([\d.]+) [\d.]+ Td$/).flatten.uniq).to eq(["50"])
    end
  end

  describe "margins on a heading" do
    let(:lines) { Array.new(7) { |i| "<p>line #{i}</p>" }.join }

    it "keep it with the block that follows, as without them" do
      body = lines
      plain = render { html "#{body}<h2>Heading</h2><p>after</p>" }
      indented = render { html %(#{body}<h2 style="margin: 0 0 0 10pt">Heading</h2><p>after</p>) }
      alone = render do
        html %(#{body}<h2 style="margin-left: 10pt">Heading</h2><p>after</p>), styles: { h2: { keep_with_next: nil } }
      end

      expect(inspect_pdf(plain).page_texts.last.split).to eq(%w[Heading after])
      expect(inspect_pdf(indented).page_texts.map(&:split)).to eq(inspect_pdf(plain).page_texts.map(&:split))
      expect(inspect_pdf(alone).page_texts.last).to eq("after")
    end
  end

  describe "margins on a floated image" do
    let(:photo) { image_path("rgb.jpg") }

    def drawn(pdf) = ops(pdf)[/^([-\d.]+) 0 0 ([\d.]+) ([-\d.]+) [\d.]+ cm$/].split.values_at(0, 3, 4).map(&:to_f)

    it "lets an indented block beside the image wrap around it: its margin lies under the float" do
      source = photo
      text = words
      image = %(<img src="p" style="float: left; width: 80pt; margin-right: 10pt">)
      pdf = render { html %(#{image}<p style="margin-left: 15pt">#{text}</p>), images: ->(_) { source } }

      expect(drawn(pdf)).to eq([80.0, 60.0, 20.0])
      expect(origins(pdf).map(&:first)).to eq(([110.0] * 5) + ([35.0] * 3))
    end

    it "keeps margin-left between an image floated right and the text" do
      source = photo
      text = words
      side = document do
        html %(<img src="p" style="float: right; width: 80pt; margin-left: 40pt">#{text}), images: ->(_) { source }
      end
      short = render do
        html %(<img src="p" style="float: right; width: 80pt; margin: 0 0 0 40pt">#{text}), images: ->(_) { source }
      end
      none = render do
        html %(<img src="p" style="float: right; width: 80pt; margin: 0">#{text}), images: ->(_) { source }
      end

      expect(ops(side.to_pdf)).to eq(ops(short))
      expect(side.warnings.to_a).to be_empty
      expect(drawn(short)).to eq([80.0, 60.0, 200.0])
      expect(strings_of(short).first.split.size).to be < strings_of(none).first.split.size
    end

    it "takes margin-left and margin-right over the margin, and the margin over the sides before it" do
      source = photo
      text = words
      render_with = lambda do |style|
        render { html %(<img src="p" style="float: left; width: 80pt; #{style}">#{text}), images: ->(_) { source } }
      end
      over = render_with.call("margin: 5pt; margin-right: 20pt; margin-left: 0")
      under = render_with.call("margin-right: 20pt; margin-left: 9pt; margin: 5pt")

      expect(ops(over)).to eq(ops(render_with.call("margin: 5pt 20pt 5pt 0")))
      expect(drawn(over)).to eq([80.0, 60.0, 20.0])
      expect(origins(over).first.first).to eq(120.0)
      expect(ops(under)).to eq(ops(render_with.call("margin: 5pt")))
    end

    it "keeps an image with a negative margin inside the flow" do
      source = photo
      text = words
      render_with = lambda do |style|
        render { html %(<img src="p" style="float: left; width: 80pt; #{style}">#{text}), images: ->(_) { source } }
      end
      plain = ops(render_with.call("margin: 0"))

      expect(ops(render_with.call("margin: 0 0 0 -500pt"))).to eq(plain)
      expect(ops(render_with.call("margin: 0; margin-top: -100pt"))).to eq(plain)
      expect(ops(render_with.call("margin: 0; margin-left: -500pt"))).to eq(plain)
    end
  end
end
