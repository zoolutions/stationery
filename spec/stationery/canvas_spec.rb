# frozen_string_literal: true

RSpec.describe Stationery::Canvas do
  let(:resources) { Stationery::Resources.new }
  let(:page) { Stationery::Page.new(size: [200, 100]) }
  let(:canvas) { described_class.new(page, resources) }
  let(:font) { Stationery::Fonts::Font.new(Stationery::Fonts::Registry.load(font_path("OpenSans-Regular.ttf"))) }

  def ops = page.content

  it "draws in a top-left coordinate space, converting y for PDF" do
    canvas.fill_rect(10, 20, 30, 40, color: "#000000")

    expect(ops).to include("0 0 0 rg\n10 40 30 40 re\nf")
  end

  it "wraps every drawing operation in its own graphics state" do
    canvas.fill_rect(0, 0, 1, 1, color: "#FF0000")
    canvas.line(0, 0, 10, 0, color: "#00FF00")

    expect(ops.scan("q\n").size).to eq(2)
    expect(ops.scan("Q\n").size).to eq(2)
  end

  it "nests save blocks" do
    canvas.save { canvas.save { canvas.fill_rect(0, 0, 1, 1, color: "#000") } }

    expect(ops).to start_with("q\nq\nq\n")
  end

  it "strokes lines with width, dash and cap" do
    canvas.line(0, 10, 100, 10, color: "#000", width: 2, dash: [3, 1], cap: :round)

    expect(ops).to include("2 w", "[3 1] 0 d", "1 J", "0 90 m\n100 90 l\nS")
  end

  it "draws rounded rectangles with Bezier corners and clamps the radius" do
    canvas.rounded_rect(0, 0, 20, 10, radius: 50, fill: "#000")

    expect(ops.scan(" c\n").size).to eq(4)
    expect(ops).to include("f\n")
    expect(ops).to include("5 100 m") # radius clamped to half the height
  end

  describe "per-corner radii" do
    def path_ops(radius, w: 50, h: 50)
      Stationery::Canvas::Path.new(canvas).rounded_rect(0, 0, w, h, radius).to_s
    end

    it "rounds only the corners given a radius and draws the rest straight" do
      out = path_ops([10, 10, 0, 0])

      expect(out.scan(/ c$/).size).to eq(2)
      expect(out).to include("50 50 l\n0 50 l") # bottom-right, then bottom-left, both square
    end

    it "draws a plain rectangle when every radius is zero" do
      expect(path_ops([0, 0, 0, 0])).to eq("0 50 50 50 re")
    end

    it "matches the single-radius form when all four are equal" do
      expect(path_ops([10, 10, 10, 10])).to eq(path_ops(10))
    end

    it "scales radii down proportionally so adjacent corners fit their side" do
      out = path_ops([100, 100, 0, 0])

      expect(out).to start_with("25 100 m\n25 100 l\n") # both top corners scaled to 25
      expect(out).to include("50 75 c") # top-right corner ends 25 down the right side
    end
  end

  it "dashes the stroke of a rounded rectangle" do
    canvas.rounded_rect(0, 0, 20, 10, radius: 2, stroke: "#000", dash: [2, 2])

    expect(ops).to include("[2 2] 0 d")
  end

  it "leaves rounded rectangles solid without a dash" do
    canvas.rounded_rect(0, 0, 20, 10, radius: 2, stroke: "#000")

    expect(ops).not_to match(/ d$/)
  end

  it "clips to a rectangle with per-corner radii" do
    canvas.clip(0, 0, 50, 20, radius: [5, 0, 5, 0]) { canvas.fill_rect(0, 0, 200, 100, color: "#000") }

    expect(ops.scan(/ c$/).size).to eq(2)
    expect(ops).to include("W n")
  end

  it "fills and strokes a circle" do
    canvas.circle(50, 50, 10, fill: "#000", stroke: "#FFF", line_width: 1)

    expect(ops.scan(" c\n").size).to eq(4)
    expect(ops).to include("B\n")
  end

  it "builds arbitrary paths" do
    canvas.path(stroke: "#000", line_width: 1.5, join: :round) do |p|
      p.move_to(0, 0)
      p.line_to(10, 0)
      p.curve_to(10, 5, 5, 10, 0, 10)
      p.close
    end

    expect(ops).to include("1 j", "1.5 w", "0 100 m", "10 100 l", "10 95 5 90 0 90 c", "h\nS")
  end

  it "clips drawing inside a block" do
    canvas.clip(10, 10, 50, 20) { canvas.fill_rect(0, 0, 200, 100, color: "#000") }

    expect(ops).to match(/q\n10 70 50 20 re\nW n\n.*0 0 200 100 re\nf\nQ\nQ\n/m)
  end

  it "applies opacity through an ExtGState registered on the page" do
    canvas.fill_rect(0, 0, 1, 1, color: "#000", opacity: 0.5)

    expect(ops).to include("/GS1 gs")
    expect(page.resource_names[:ExtGState]).to eq([:GS1])
  end

  it "writes text as glyph ids at a baseline, registering the font" do
    canvas.text("Hi", x: 10, y: 30, font:, size: 12, color: "#333333")

    gids = "Hi".chars.map { |c| font.ttf.glyph_id(c.ord) }.pack("n*").unpack1("H*").upcase
    expect(ops).to include("BT", "/F1 12 Tf", "10 70 Td", "<#{gids}> Tj", "ET")
    expect(page.resource_names[:Font]).to eq([:F1])
  end

  it "applies letter spacing, rise and synthetic styles to text" do
    canvas.text("x", x: 0, y: 10, font:, size: 10, letter_spacing: 0.5, rise: 3,
                     synthetic_bold: true, synthetic_oblique: true)

    expect(ops).to include("0.5 Tc", "3 Ts", "2 Tr", "0.3 w")
    expect(ops).to match(/1 0 0.2126 1 0 90 Tm/)
  end

  it "underlines and strikes through text with filled bars" do
    canvas.text("Hi", x: 0, y: 10, font:, size: 10, underline: true, strikethrough: true)

    expect(ops.scan(" re\nf").size).to eq(2)
  end

  it "returns the advance of the text it drew" do
    expect(canvas.text("Hi", x: 0, y: 10, font:, size: 10)).to eq(font.width_of("Hi", 10))
  end

  it "places images with a transformation matrix and registers the XObject" do
    image = Stationery::Images.load(image_path("rgb.jpg"))
    canvas.image(image, x: 10, y: 20, width: 40, height: 30)

    expect(ops).to include("40 0 0 30 10 50 cm\n/Im1 Do")
    expect(page.resource_names[:XObject]).to eq([:Im1])
  end

  it "records link annotations in absolute PDF space" do
    canvas.link(10, 20, 30, 5, "https://example.com/pay?x=1")

    expect(page.annotations).to eq([{ rect: [10, 75, 40, 80], url: "https://example.com/pay?x=1" }])
  end
end
