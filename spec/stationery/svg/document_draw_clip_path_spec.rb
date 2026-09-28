# frozen_string_literal: true

RSpec.describe Stationery::SVG::Document, "#draw" do
  let(:resources) { Stationery::Resources.new }
  let(:page) { Stationery::Page.new(size: [200, 200]) }
  let(:canvas) { Stationery::Canvas.new(page, resources) }

  let(:red_square) { "q\n1 0 0 rg\n0 200 m\n100 200 l\n100 100 l\n0 100 l\nh\nf\nQ\n" }

  def draw(source)
    svg = described_class.parse(source)
    svg.draw(canvas, x: 0, y: 0, width: 100, height: 100)
    svg
  end

  def clipped(clip_path, target = '<rect width="100" height="100" fill="#FF0000" clip-path="url(#c)"/>')
    draw(%(<svg viewBox="0 0 100 100">#{clip_path}#{target}</svg>))
  end

  it "paints an element inside the shapes of its clip path" do
    svg = clipped('<clipPath id="c"><rect x="10" y="10" width="20" height="20"/></clipPath>')

    expect(page.content).to eq("q\n10 190 m\n30 190 l\n30 170 l\n10 170 l\nh\nW n\n#{red_square}Q\n")
    expect(svg.unsupported).to eq([])
  end

  it "joins several shapes into one clipping path, each under its own transform and the clip path's" do
    clipped(<<~SVG)
      <clipPath id="c" transform="translate(10 0)"><rect width="5" height="5"/>
        <polygon points="0,0 4,0 0,4" transform="translate(20 20) scale(2)"/>
        <rect display="none" width="90" height="90"/></clipPath>
    SVG

    expect(page.content).to start_with(
      "q\n10 200 m\n15 200 l\n15 195 l\n10 195 l\nh\n30 180 m\n38 180 l\n30 172 l\nh\nW n\nq\n1 0 0 rg"
    )
  end

  it "clips with the even-odd rule when a shape asks for it" do
    clipped('<clipPath id="c"><path clip-rule="evenodd" d="M0 0H50V50H0Z M10 10H40V40H10Z"/></clipPath>')

    expect(page.content).to include("h\nW* n\nq\n1 0 0 rg")
  end

  it "reads clip-path from a style and clips a whole group, text and use included" do
    draw(<<~SVG)
      <svg viewBox="0 0 100 100"><defs><rect id="r" width="10" height="10"/></defs>
        <clipPath id="c"><circle cx="50" cy="50" r="40"/></clipPath>
        <g style="clip-path: url(#c)"><rect width="100" height="100"/><text y="50">Hi</text><use href="#r"/></g>
        <rect width="1" height="1"/></svg>
    SVG
    ops = page.content

    expect(ops.scan("W n\n").size).to eq(1)
    inside, outside = ops.split(/^Q\nQ\n/, 2)
    expect(inside).to start_with("q\n90 150 m\n").and include("BT\n").and include("0 200 m\n10 200 l")
    expect(outside).to eq("q\n0 0 0 rg\n0 200 m\n1 200 l\n1 199 l\n0 199 l\nh\nf\nQ\n")
  end

  it "applies the clip in the user space of the clipped element, its transform included" do
    clipped('<clipPath id="c"><rect width="10" height="10"/></clipPath>',
            '<rect width="20" height="20" transform="translate(30 40)" clip-path="url(#c)"/>')

    expect(page.content).to start_with("q\n30 160 m\n40 160 l\n40 150 l\n30 150 l\nh\nW n\n")
  end

  it "scales objectBoundingBox units to the box of a shape, a group or a use" do
    clip = '<clipPath id="c" clipPathUnits="objectBoundingBox"><rect width="0.5" height="0.5"/></clipPath>'
    clipped(clip, <<~SVG)
      <rect x="20" y="20" width="40" height="40" clip-path="url(#c)"/>
      <g clip-path="url(#c)"><rect x="60" y="60" width="10" height="10"/>
        <circle cx="85" cy="85" r="5" transform="translate(0 -5)"/></g>
      <defs><rect id="r" width="8" height="8"/></defs><use href="#r" x="2" y="4" clip-path="url(#c)"/>
    SVG

    expect(page.content.scan(/^q\n([\d .]+ m)\n([\d .]+ l)\n([\d .]+ l)\n.*\nh\nW n$/))
      .to eq([["20 180 m", "40 180 l", "40 160 l"], ["60 140 m", "75 140 l", "75 127.5 l"],
              ["2 196 m", "6 196 l", "6 192 l"]])
  end

  it "intersects with the clip path of the clip path" do
    clipped(<<~SVG)
      <clipPath id="outer"><rect width="50" height="100"/></clipPath>
      <clipPath id="c" clip-path="url(#outer)"><rect width="100" height="50"/></clipPath>
    SVG

    expect(page.content).to eq(
      "q\n0 200 m\n50 200 l\n50 100 l\n0 100 l\nh\nW n\n" \
      "q\n0 200 m\n100 200 l\n100 150 l\n0 150 l\nh\nW n\n#{red_square}Q\nQ\n"
    )
  end

  it "follows a use inside the clip path to a shape" do
    clipped(<<~SVG)
      <defs><rect id="shape" width="10" height="10" transform="scale(2)"/></defs>
      <clipPath id="c"><use xlink:href="#shape" x="5" y="5"/></clipPath>
    SVG

    expect(page.content).to start_with("q\n5 195 m\n25 195 l\n25 175 l\n5 175 l\nh\nW n\n")
  end

  it "draws nothing for an element whose clip path has no shape" do
    svg = clipped('<clipPath id="c"><rect display="none" width="9" height="9"/><g><rect width="9" height="9"/></g>' \
                  "</clipPath>")

    expect(page.content).to eq("")
    expect(svg.unsupported).to eq([])
  end

  it "draws unclipped and reports a clip path that is missing" do
    svg = clipped('<clipPath id="other"/>')

    expect(page.content).to eq(red_square)
    expect(svg.unsupported).to eq(["clip-path: #c not found"])
  end

  it "reports text in a clip path and clip paths that refer to each other" do
    svg = clipped(<<~SVG)
      <clipPath id="a" clip-path="url(#c)"><rect width="50" height="50"/></clipPath>
      <clipPath id="c" clip-path="url(#a)"><rect width="100" height="50"/><text>Hi</text></clipPath>
    SVG

    expect(page.content.scan("W n\n").size).to eq(2)
    expect(svg.unsupported).to eq(["clip-path: circular reference #c", "clipPath #c: text"])
  end

  it "ignores a use in the clip path that refers to a group, and reports one that refers to a text" do
    svg = clipped(<<~SVG)
      <defs><g id="group"><rect width="90" height="90"/></g><text id="label">Hi</text></defs>
      <clipPath id="c"><use href="#group"/><use href="#label"/><use href="#nowhere"/>
        <rect width="10" height="10"/></clipPath>
    SVG

    expect(page.content).to eq("q\n0 200 m\n10 200 l\n10 190 l\n0 190 l\nh\nW n\n#{red_square}Q\n")
    expect(svg.unsupported).to eq(["clipPath #c: text"])
  end

  it "leaves a viewport with overflow auto unclipped" do
    draw(<<~SVG)
      <svg viewBox="0 0 100 100"><svg width="10" height="10" style="overflow: auto">
        <rect width="100" height="100" fill="#FF0000"/></svg></svg>
    SVG

    expect(page.content).to eq(red_square)
  end

  it "clips a gradient fill too" do
    clipped(<<~SVG, '<rect width="100" height="100" fill="url(#g)" clip-path="url(#c)"/>')
      <linearGradient id="g"><stop stop-color="#FF0000"/><stop offset="1" stop-color="#0000FF"/></linearGradient>
      <clipPath id="c"><rect width="10" height="10"/></clipPath>
    SVG

    expect(page.content).to start_with("q\n0 200 m\n10 200 l\n10 190 l\n0 190 l\nh\nW n\nq\n").and include("/Sh1 sh")
    expect(page.content).to end_with("Q\nQ\n")
  end

  describe "with an Illustrator export" do
    let(:export) { File.read(File.expand_path("../../fixtures/svg/clipped.svg", __dir__)) }

    it "clips the artwork group to the rectangle its clip path uses" do
      svg = draw(export)
      ops = page.content

      expect(svg.unsupported).to eq([])
      expect(ops).to start_with("q\n10 190 m\n90 190 l\n90 130 l\n10 130 l\nh\nW n\nq\n0.0706 0.2039 0.3373 rg\n")
      expect(ops.scan("W n\n").size).to eq(1)
      expect(ops).to include("1 0 0 RG\n4 w\n0 200 m\n100 100 l\nS\nQ\nQ\n")
      # the footer band is outside the clipped group
      expect(ops).to end_with("Q\nQ\nq\n0.0706 0.2039 0.3373 rg\n0 110 m\n100 110 l\n100 100 l\n0 100 l\nh\nf\nQ\n")
    end
  end
end
