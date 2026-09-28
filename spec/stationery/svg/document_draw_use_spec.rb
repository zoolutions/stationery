# frozen_string_literal: true

RSpec.describe Stationery::SVG::Document, "#draw" do
  let(:resources) { Stationery::Resources.new }
  let(:page) { Stationery::Page.new(size: [200, 200]) }
  let(:canvas) { Stationery::Canvas.new(page, resources) }

  def draw(source, **)
    svg = described_class.parse(source)
    svg.draw(canvas, x: 0, y: 0, width: 100, height: 100, **)
    svg
  end

  it "draws a referenced shape where use puts it, in the use's style" do
    svg = draw(<<~SVG)
      <svg viewBox="0 0 100 100"><defs><rect id="r" width="10" height="10"/></defs>
        <use href="#r" x="20" y="30" fill="#FF0000"/></svg>
    SVG

    expect(page.content).to eq("q\n1 0 0 rg\n20 170 m\n30 170 l\n30 160 l\n20 160 l\nh\nf\nQ\n")
    expect(svg.unsupported).to eq([])
  end

  it "reads xlink:href, applies the use's transform before its x and y, and lets the target's own style win" do
    draw(<<~SVG)
      <svg viewBox="0 0 100 100"><defs><g id="g" transform="translate(1 1)">
        <rect width="2" height="2" fill="#0000FF"/><rect x="4" width="2" height="2"/></g></defs>
        <use xlink:href="#g" x="10" y="10" transform="scale(2)" fill="#FF0000"/></svg>
    SVG

    # scale(2) translate(10 10) translate(1 1): the first rect's corner lands at (22, 22)
    expect(page.content).to eq(
      "q\n0 0 1 rg\n22 178 m\n26 178 l\n26 174 l\n22 174 l\nh\nf\nQ\n" \
      "q\n1 0 0 rg\n30 178 m\n34 178 l\n34 174 l\n30 174 l\nh\nf\nQ\n"
    )
  end

  it "draws a symbol through use only, scaled into the use's size and clipped to it" do
    draw(<<~SVG)
      <svg viewBox="0 0 100 100"><symbol id="s" viewBox="0 0 10 10"><rect width="10" height="10"/></symbol>
        <use href="#s" x="10" y="20" width="40" height="20" fill="#0000FF"/></svg>
    SVG

    expect(page.content).to eq(
      "q\n10 180 m\n50 180 l\n50 160 l\n10 160 l\nh\nW n\n" \
      "q\n0 0 1 rg\n20 180 m\n40 180 l\n40 160 l\n20 160 l\nh\nf\nQ\nQ\n"
    )
  end

  it "leaves a symbol with overflow visible unclipped and honours preserveAspectRatio" do
    draw(<<~SVG)
      <svg viewBox="0 0 100 100">
        <symbol id="s" viewBox="0 0 10 10" preserveAspectRatio="none" overflow="visible">
          <rect width="10" height="10"/></symbol>
        <use href="#s" width="40" height="20"/></svg>
    SVG

    expect(page.content).to eq("q\n0 0 0 rg\n0 200 m\n40 200 l\n40 180 l\n0 180 l\nh\nf\nQ\n")
  end

  it "sizes a symbol without width and height to the viewport" do
    draw(<<~SVG)
      <svg viewBox="0 0 100 50"><symbol id="t" viewBox="0 0 10 5" overflow="visible">
        <rect width="10" height="5"/></symbol><use href="#t"/></svg>
    SVG

    expect(page.content).to include("0 175 m\n100 175 l\n100 125 l\n0 125 l\nh")
  end

  it "draws a nested svg as a viewport of its own" do
    draw(<<~SVG)
      <svg viewBox="0 0 100 100"><svg x="50" y="50" width="20" height="20" viewBox="0 0 10 10">
        <rect width="20" height="10" fill="#00FF00"/></svg></svg>
    SVG

    expect(page.content).to eq(
      "q\n50 150 m\n70 150 l\n70 130 l\n50 130 l\nh\nW n\n" \
      "q\n0 1 0 rg\n50 150 m\n90 150 l\n90 130 l\n50 130 l\nh\nf\nQ\nQ\n"
    )
  end

  it "never draws defs, symbols or clip paths on their own" do
    draw(<<~SVG)
      <svg viewBox="0 0 100 100"><defs><rect width="1" height="1"/>
        <symbol id="a"><rect width="1" height="1"/></symbol></defs>
        <symbol id="s"><rect width="1" height="1"/></symbol>
        <clipPath id="c"><rect width="1" height="1"/></clipPath></svg>
    SVG

    expect(page.content).to eq("")
  end

  it "skips a use that is not displayed or whose target is not" do
    draw(<<~SVG)
      <svg viewBox="0 0 100 100"><defs><rect id="r" width="1" height="1"/>
        <rect id="h" display="none" width="1" height="1"/></defs>
        <use href="#r" display="none"/><use href="#h"/><use href="#r" visibility="hidden"/></svg>
    SVG

    expect(page.content).to eq("")
  end

  it "takes currentColor from the color property, which a use hands to its symbol" do
    draw(<<~SVG, color: "#00FF00")
      <svg viewBox="0 0 100 100"><symbol id="s" overflow="visible">
        <rect width="1" height="1" fill="currentColor"/></symbol>
        <use href="#s"/><use href="#s" color="#FF0000"/>
        <g color="blue"><use href="#s" style="color: currentColor"/></g></svg>
    SVG

    expect(page.content.scan(/^[\d. ]+ rg$/)).to eq(["0 1 0 rg", "1 0 0 rg", "0 0 1 rg"])
  end

  it "follows a use to another use and reports a circular chain once, drawing the rest" do
    svg = draw(<<~SVG)
      <svg viewBox="0 0 100 100"><defs><rect id="r" width="1" height="1"/><use id="u" href="#r" x="5"/>
        <g id="a"><use href="#b"/></g><g id="b"><rect width="2" height="2"/><use href="#a"/></g>
        <use id="self" href="#self"/></defs>
        <use href="#u" y="5"/><use href="#a"/><use href="#self"/></svg>
    SVG

    expect(page.content).to include("5 195 m\n6 195 l").and include("0 200 m\n2 200 l")
    expect(page.content.scan("\nf\n").size).to eq(2)
    expect(svg.unsupported).to eq(["use: circular reference #a", "use: circular reference #self"])
  end

  it "reports a use without a target and draws nothing for it" do
    svg = draw('<svg viewBox="0 0 10 10"><use href="#nope"/><use/><use href="other.svg#a"/></svg>')

    expect(page.content).to eq("")
    expect(svg.unsupported).to eq(["use: #nope not found", "use: no href", "use: other.svg#a not found"])
  end

  it "reports missing gradients and unsupported elements inside what a use draws" do
    svg = described_class.parse(<<~SVG)
      <svg viewBox="0 0 10 10"><symbol id="s"><rect width="1" height="1" fill="url(#g)"/><image href="a.png"/>
        <mask id="m"/><pattern id="p"/><filter id="f"/><text><textPath href="#x">a</textPath></text></symbol>
        <use href="#s"/></svg>
    SVG

    expect(svg.unsupported).to eq(%w[filter image mask pattern textPath url(#g)])
  end

  describe "with a sprite sheet" do
    let(:sprite) { File.read(File.expand_path("../../fixtures/svg/sprite.svg", __dir__)) }

    it "draws every icon at its size and colour" do
      svg = described_class.parse(sprite)
      svg.draw(canvas, x: 0, y: 0, width: 120, height: 40, color: "#111827")
      ops = page.content

      expect(svg.unsupported).to eq([])
      # four icons, the badge holding a check of its own: five viewports
      expect(ops.scan("W n\n").size).to eq(5)
      expect(ops.scan(/^[\d. ]+ RG$/)).to eq(["0.0667 0.0941 0.1529 RG", "0.0863 0.6392 0.2902 RG", "1 1 1 RG"])
      expect(ops.scan(/^[\d. ]+ rg$/)).to eq(["0.8627 0.149 0.149 rg", "0.1451 0.3882 0.9216 rg"])
      # stroke widths scale with the use: 2 in a 24 box drawn 24 and 32 wide
      expect(ops.scan(/^[\d.]+ w$/)).to eq(["2 w", "2.6667 w", "2 w"])
      # the first check starts at (4, 12) in its 24 box, drawn at (0, 8)
      expect(ops).to include("4 180 m\n10 174 l\n20 186 l")
      expect(ops.scan("q\n").size).to eq(ops.scan("Q\n").size)
    end
  end
end
