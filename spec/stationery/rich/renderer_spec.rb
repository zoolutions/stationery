# frozen_string_literal: true

RSpec.describe "Stationery::Rich::Renderer" do
  def document(&) = SpecDocument.build(&)
  def render(&) = document(&).to_pdf
  def fonts(pdf) = page_contents(pdf).join.scan(%r{/(F\d+) ([\d.]+) Tf}).uniq

  it "renders headings bold and scaled from the text size, overridable through styles:" do
    pdf = render { html "<h1>Title</h1><h2>Sub</h2>" }
    custom = render { html "<h1>Title</h1>", styles: { h1: { size: 30 } } }

    expect(strings_of(pdf)).to eq(%w[Title Sub])
    expect(fonts(pdf).map(&:last)).to eq(%w[20 16])
    expect(fonts(custom).map(&:last)).to eq(%w[30])
  end

  it "renders paragraphs with bold, italic, underlined, struck, scripted and broken runs" do
    pdf = render do
      html "<p>plain <b>bold</b> <i>it</i> <u>under</u> <s>gone</s> H<sub>2</sub>O x<sup>2</sup><br>next</p>"
    end

    expect(text_of(pdf)).to include("next")
    expect(strings_of(pdf)).to include("bold", "it", "under", "gone", "2")
    expect(fonts(pdf).map(&:first).uniq.size).to eq(3)
    expect(fonts(pdf).map(&:last)).to include("5.83")
  end

  it "styles code runs with styles[:code] and keeps the text font by default" do
    pdf = render { markdown "run `ls` now", styles: { code: { font: "Open Sans", color: "#FF0000" } } }

    expect(strings_of(pdf)).to eq(["run ", "ls", " now"])
    expect(page_contents(pdf).first).to include("1 0 0 rg")
  end

  it "turns links into annotations coloured like styles[:a]" do
    pdf = render { markdown "see [docs](https://example.test/docs)" }

    expect(pdf).to have_pdf_link("https://example.test/docs")
    expect(page_contents(pdf).first).to include("0.1451 0.3882 0.9216 rg")
  end

  it "applies weight, style, strikethrough and size from styles[:a]" do
    a = { weight: :bold, style: :italic, strikethrough: true, size: 14, underline: false }
    pdf = render { markdown "[go](https://example.test)", styles: { a: } }

    expect(fonts(pdf)).to eq([%w[F1 14]])
    expect(pdf).to have_pdf_link("https://example.test")
  end

  describe "link schemes" do
    let(:source) do
      %(<a href="javascript:alert(1)">js</a> <a href="/relative">rel</a> <a href="page.html">page</a>
        <a href="HTTPS://x.test/?a=1&amp;b=2">ok</a> <a href="mailto:hi@x.test">mail</a>
        <a href="tel:+123">call</a> <a href="#top">anchor</a> <a href="data:text/html,x">data</a>)
    end

    it "keeps http, https, mailto, tel and #anchor links and drops the rest, keeping their text" do
      html_source = source
      doc = document do
        anchor "top"
        html html_source
      end
      pdf = doc.to_pdf

      expect(inspect_pdf(pdf).links).to eq(["HTTPS://x.test/?a=1&b=2", "mailto:hi@x.test", "tel:+123"])
      expect(inspect_pdf(pdf).internal_links).to eq([1])
      expect(text_of(pdf)).to eq("js rel page ok mail call anchor data")
      expect(doc.warnings.map(&:href)).to eq(["javascript:alert(1)", "/relative", "page.html", "data:text/html,x"])
      expect(doc.warnings.first.message).to eq(%(link "javascript:alert(1)" dropped: scheme not allowed))
    end

    it "draws dropped links as plain text, without the a: style" do
      pdf = render { html %(<a href="javascript:alert(1)">js</a>) }

      expect(page_contents(pdf).first).not_to include("0.1451 0.3882 0.9216 rg")
    end

    it "takes a custom allow-list through links:" do
      doc = document { html %(<a href="ftp://x.test/f">ftp</a> <a href="https://x.test">web</a>), links: %w[ftp] }
      pdf = doc.to_pdf

      expect(inspect_pdf(pdf).links).to eq(["ftp://x.test/f"])
      expect(doc.warnings.map(&:href)).to eq(["https://x.test"])
    end

    it "writes every link as-is with links: :all" do
      doc = document { markdown "[js](javascript:alert(1)) [rel](/relative)", links: :all }
      pdf = doc.to_pdf

      expect(inspect_pdf(pdf).links).to eq(["javascript:alert(1)", "/relative"])
      expect(doc.warnings).to be_empty
    end

    it "filters markdown links too" do
      doc = document { markdown "[js](javascript:alert(1)) [ok](https://x.test)" }

      expect(inspect_pdf(doc.to_pdf).links).to eq(["https://x.test"])
      expect(doc.warnings.to_a).to eq([Stationery::Warnings::DroppedLink.new(href: "javascript:alert(1)")])
    end
  end

  it "turns &shy; into a soft hyphen the wrapper may break at" do
    pdf = render { box(width: 50) { html "<p>Zei&shy;tungs&shy;leser</p>" } }

    expect(text_of(pdf)).to eq("Zeitungs-\nleser")
    expect(text_of(render { html "<p>Zei&shy;tungsleser</p>" })).to eq("Zeitungsleser")
  end

  it "hyphenates paragraphs and list items through styles:" do
    pdf = render do
      box(width: 70) do
        html "<p>Silbentrennung</p><ul><li>Donaudampfschifffahrt</li></ul>",
             styles: { p: { hyphenate: "de" }, li: { hyphenate: "de" } }
      end
    end

    expect(text_of(pdf)).to match(/Sil-|ben-|tren-/)
    expect(text_of(pdf)).to match(/Do-|nau-|dampf-|schiff-/)
  end

  it "renders ordered, bulleted and nested lists with markers" do
    pdf = render { markdown "3. three\n4. four\n   - inner\n" }

    expect(strings_of(pdf)).to eq(["3.", "three", "4.", "four", "inner"])
  end

  describe "list styles" do
    def baselines(pdf) = page_runs(pdf).first.map(&:last).uniq

    it "passes styles[:ul] to ul" do
      loose = render { markdown "- a\n- b" }
      tight = render { markdown "- a\n- b", styles: { ul: { gap: 0 } } }

      expect(baselines(loose).first - baselines(loose).last).to be > baselines(tight).first - baselines(tight).last
    end

    it "passes styles[:ol] to ol, keeping the list's own start" do
      pdf = render { markdown "3. a\n4. b", styles: { ol: { format: :alpha, suffix: ")" } } }

      expect(strings_of(pdf)).to eq(["c)", "a", "d)", "b"])
    end

    it "colours markers with marker_color" do
      pdf = render { html "<ul><li>a</li></ul>", styles: { ul: { marker_color: "#FF0000" } } }

      expect(page_contents(pdf).first).to include("1 0 0 rg")
    end
  end

  it "draws a left border beside blockquotes" do
    pdf = render { html "<blockquote><p>quoted</p></blockquote>" }

    expect(strings_of(pdf)).to eq(["quoted"])
    expect(page_contents(pdf).first).to include("3 w", "0.898 0.9059 0.9216 RG")
  end

  it "renders code blocks on a background keeping their line breaks" do
    pdf = render { markdown "```\nfirst\nsecond\n```" }

    expect(page_runs(pdf).first.map(&:first)).to eq(%w[first second])
    expect(page_contents(pdf).first).to include("0.9529 0.9569 0.9647 rg")
  end

  it "draws horizontal rules" do
    expect(page_contents(render { markdown "a\n\n---\n\nb" }).first).to include("0.898 0.9059 0.9216 rg")
  end

  it "renders tables with a bold header row and aligned cells" do
    pdf = render { markdown "| Item | Price |\n|---|--:|\n| Tea | 4 |" }

    expect(strings_of(pdf)).to eq(%w[Item Price Tea 4])
    expect(fonts(pdf).map(&:first).uniq.size).to eq(2)
    four, price = positions_of(pdf).values_at(3, 1).map(&:first)
    expect(four).to be > price
  end

  it "treats a table without header cells as all body rows" do
    expect(strings_of(render { html "<table><tr><td>a</td></tr></table>" })).to eq(["a"])
  end

  describe "images" do
    let(:dir) { File.dirname(image_path("rgb.jpg")) }

    it "resolves sources through images:" do
      logo = image_path("rgb.jpg")
      doc = document { html %(<img src="logo">), images: ->(src) { logo if src == "logo" } }

      expect(image_count(doc.to_pdf)).to eq(1)
      expect(doc.warnings).to be_empty
    end

    it "resolves sources under base_path: and honours width, height and max_width" do
      base = dir
      pdf = render do
        html %(<img src="rgb.jpg" width="40" height="20"><img src="rgb.jpg">),
             base_path: base, styles: { img: { max_width: 2 } }
      end

      expect(image_count(pdf)).to eq(1)
      expect(page_contents(pdf).first).to include("2 0 0 1 ", "2 0 0 1.5 ")
    end

    it "warns and continues on missing, remote, escaping and unsupported images" do
      base = dir
      doc = document do
        html %(<img src="nope.png"><img src="https://x.test/a.png"><img src="../../spec_helper.rb">
               <img src="gif.gif"><p>after</p>), base_path: base
      end

      expect(strings_of(doc.to_pdf)).to eq(["after"])
      expect(doc.warnings.map(&:reason)).to eq(["not found", "remote", "outside base_path",
                                                "GIF images are not supported, convert to PNG or JPEG"])
    end

    it "warns when nothing resolves the source" do
      doc = document { markdown "![x](a.png)", images: ->(_) {} }
      doc.to_pdf

      expect(doc.warnings.map(&:message)).to eq([%(image "a.png" skipped: not found)])
    end
  end

  it "bookmarks h1 to h3 when asked" do
    pdf = render { markdown "# One\n\n## Two\n\n#### Four", bookmarks: true }

    expect(outline_of(pdf).map { |entry| [entry[:title], entry[:children].map { |c| c[:title] }] })
      .to eq([["One", ["Two"]]])
  end
end
