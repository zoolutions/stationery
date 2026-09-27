# frozen_string_literal: true

RSpec.describe Stationery::Elements do
  def render(&) = SpecDocument.build(&).to_pdf

  it "styles text with options, markup or a run block" do
    pdf = render do
      text "plain", weight: :bold, color: "#FF0000"
      text "<i>marked</i> up", markup: true
      text do |t|
        t.b("built")
        t.plain(" too")
      end
      text do
        b "exec"
        plain " style"
      end
    end

    expect(strings_of(pdf)).to eq(["plain", "marked", " up", "built", " too", "exec", " style"])
    expect(page_contents(pdf).first).to include("1 0 0 rg")
  end

  it "never parses markup in plain text" do
    expect(strings_of(render { text "<b>literal</b> & more" })).to eq(["<b>literal</b> & more"])
  end

  it "lays out rows of columns and passes text alignment down" do
    pdf = render do
      row(gap: 10) do
        column(width: 0.5) { text "left" }
        column(width: 0.5, align: :right) { text "right" }
      end
    end
    font = Stationery::Fonts::Registry.load(font_path("OpenSans-Regular.ttf"))
    right_x = positions_of(pdf).last.first

    expect(right_x + Stationery::Fonts::Font.new(font).width_of("right", 10)).to be_within(0.01).of(280)
  end

  it "wraps loose content in a row into a column" do
    expect(strings_of(render { row { text "a" } })).to eq(["a"])
  end

  it "builds boxes, rules, spacers, images, canvases, tables, groups and page breaks" do
    pdf = render do
      box(padding: 6, background: "#EEEEEE", radius: 4, border: { width: 1, color: "#999999" }) { text "boxed" }
      rule height: 2, color: "#333333"
      spacer 8
      image File.expand_path("../fixtures/images/rgb.jpg", __dir__), width: 20, align: :center
      canvas(height: 10) { |c, r| c.line(r.x, r.y, r.right, r.y, color: "#000") }
      table([%w[a b], %w[c d]], header: true, cell: { padding: 2 }) { |t| t.row(0).weight = :bold }
      group(keep_together: true) { text "grouped" }
      page_break
      text "next page"
    end

    expect(page_count(pdf)).to eq(2)
    expect(strings_of(pdf)).to eq(%w[boxed a b c d grouped] + ["next page"])
    expect(image_count(pdf)).to eq(1)
  end

  it "scopes text defaults to a block" do
    pdf = render do
      text_style(color: "#00FF00", size: 12) { text "green" }
      text "black"
    end

    expect(page_contents(pdf).first).to include("0 1 0 rg", "/F1 12 Tf", "/F1 10 Tf")
  end

  it "places a positioned box without taking up flow space" do
    pdf = render do
      box(at: [200, 150], width: 80) { text "floating" }
      text "in flow"
    end
    floating, in_flow = positions_of(pdf)

    expect(floating.first).to eq(200)
    expect(in_flow.first).to eq(20)
  end

  it "draws SVG icons from a string, sized and coloured, with currentColor replaced" do
    source = File.read(File.expand_path("../fixtures/svg/check.svg", __dir__))
    pdf = render { svg source, width: 16, color: "#FF0000", align: :center }

    expect(page_contents(pdf).first).to include("1 0 0 RG")
  end

  it "wraps chips and centres groups" do
    pdf = render do
      wrap(gap: 4, align: :center) { %w[one two].each { |label| box(width: :auto, padding: 2) { text label } } }
      group(align: :center) { image File.expand_path("../fixtures/images/rgb.jpg", __dir__), width: 20 }
    end

    expect(strings_of(pdf)).to eq(%w[one two])
    expect(page_contents(pdf).first).to include("20 0 0 15 140")
  end

  describe "lists" do
    def curves(content) = content.scan(/ c$/).size

    it "numbers ordered items from a start" do
      pdf = render do
        ol(start: 3) do
          li "three"
          li "four"
        end
      end

      expect(strings_of(pdf)).to eq(["3.", "three", "4.", "four"])
    end

    it "indents every body past the widest marker, formats markers and keeps text options" do
      pdf = render do
        ol(format: :upper_roman, suffix: ")", marker_gap: 4) do
          li "one"
          li "two", weight: :bold
        end
      end
      font = Stationery::Fonts::Font.new(Stationery::Fonts::Registry.load(font_path("OpenSans-Regular.ttf")))
      bodies = positions_of(pdf).values_at(1, 3).map(&:first)

      expect(strings_of(pdf)).to eq(["I)", "one", "II)", "two"])
      expect(bodies.uniq.size).to eq(1)
      expect(bodies.first).to be_within(0.01).of(20 + [font.width_of("II)", 10), 10].max + 4)
      expect(page_contents(pdf).first).to include("/F2 10 Tf")
    end

    it "turns bare nodes into items and draws a String style as text" do
      pdf = render do
        ul(style: ">", marker_color: "#FF0000") do
          text "bare"
          li
          li(gap: 2) { text "rich" }
        end
      end

      expect(strings_of(pdf)).to eq([">", "bare", ">", ">", "rich"])
      expect(page_contents(pdf).first).to include("1 0 0 rg")
    end

    it "draws a dash, a filled square and coloured discs" do
      dash = render { ul(style: :dash) { li "a" } }
      square = render { ul(style: :square) { li "a" } }
      disc = render { ul(marker_color: "#00FF00") { li "a" } }

      expect(strings_of(dash)).to eq(["–", "a"])
      expect(page_contents(square).first).to match(/ re\nf$/)
      expect(page_contents(disc).first).to match(/0 1 0 rg\n[\d. ]+ m$/)
    end

    it "cycles unstyled nested lists through disc, circle and square" do
      pdf = render do
        ul do
          li "outer"
          li do
            ul do
              li "middle"
              li { ul { li "deepest" } }
            end
          end
        end
      end
      content = page_contents(pdf).first
      xs = positions_of(pdf).map(&:first)

      expect(curves(content)).to eq(16)
      expect(content).to match(/ c\nh\nS$/).and match(/ re\nf$/)
      expect(xs).to eq(xs.sort)
      expect(xs.uniq.size).to eq(3)
    end
  end
end
