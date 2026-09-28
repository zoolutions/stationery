# frozen_string_literal: true

RSpec.describe Stationery::Fonts::GlyfOutline do
  # Hand-built glyf entries, read through a stand-in for TrueType#glyph_data.
  def outline(glyphs, gid = 0)
    source = Object.new
    source.define_singleton_method(:glyph_data) { |id| glyphs.fetch(id, "".b) }
    described_class.read(source, gid).each_segment.to_a
  end

  # A simple glyph: each contour a list of [x, y, on_curve]. Coordinates are
  # packed as a font packs them (short, same and repeated flags) when `packed`.
  def simple(*contours, packed: true)
    points = contours.flatten(1)
    ends = contours.each_with_object([]) { |contour, acc| acc << ((acc.last || -1) + contour.size) }
    deltas = points.each_with_index.map do |(x, y, _), i|
      i.zero? ? [x, y] : [x - points[i - 1][0], y - points[i - 1][1]]
    end
    flags = points.zip(deltas).map { |(_, _, on), (dx, dy)| flag(on, dx, dy, packed) }
    [contours.size, 0, 0, 0, 0, *ends, 0].pack("s>s>s>s>s>n*") + run_lengths(flags) +
      coords(deltas.map(&:first), flags, 0x02, 0x10) + coords(deltas.map(&:last), flags, 0x04, 0x20)
  end

  def flag(on, dx, dy, packed)
    flag = on ? 1 : 0
    return flag unless packed

    flag | axis(dx, 0x02, 0x10) | axis(dy, 0x04, 0x20)
  end

  def axis(delta, short, same)
    return same if delta.zero?
    return 0 if delta.abs > 255

    delta.positive? ? short | same : short
  end

  def run_lengths(flags)
    flags.chunk_while { |a, b| a == b }.map do |run|
      run.size > 1 ? [run.first | 0x08, run.size - 1].pack("CC") : [run.first].pack("C")
    end.join
  end

  def coords(deltas, flags, short, same)
    deltas.zip(flags).map do |delta, flag|
      if flag.allbits?(short) then [delta.abs].pack("C")
      elsif flag.allbits?(same) then ""
      else [delta].pack("s>")
      end
    end.join.b
  end

  # A composite glyph: each component a Hash of gid:, args: [a, b] and the
  # optional flags and transform.
  def composite(*components)
    body = components.each_with_index.map do |component, i|
      component(component, more: i < components.size - 1)
    end
    [-1, 0, 0, 0, 0].pack("s>*") + body.join
  end

  def component(component, more:)
    flags = component.fetch(:flags, 0x0002) | (more ? 0x0020 : 0) | 0x0001
    matrix = component[:matrix]
    flags |= { 1 => 0x0008, 2 => 0x0040, 4 => 0x0080 }.fetch(matrix.size) if matrix
    arguments = component[:args].pack(flags.allbits?(0x0002) ? "s>s>" : "nn")
    [flags, component[:gid]].pack("nn") + arguments + (matrix || []).map { |v| (v * 16_384).round }.pack("s>*")
  end

  def quad(from_x, from_y, cx, cy, x, y)
    t = 0.66666666666666667
    [:curve, from_x + (t * (cx - from_x)), from_y + (t * (cy - from_y)), x + (t * (cx - x)), y + (t * (cy - y)), x, y]
  end

  let(:square) { simple([[0, 0, true], [0, 700, true], [600, 700, true], [600, 0, true]]) }

  it "reads a contour of on-curve points as lines, the closing line left to close" do
    expect(outline({ 0 => square })).to eq(
      [[:move, 0, 0], [:line, 0, 700], [:line, 600, 700], [:line, 600, 0], :close]
    )
  end

  it "reads long coordinates and unrepeated flags the same as packed ones" do
    expect(outline({ 0 => simple([[0, 0, true], [0, 700, true], [600, 700, true]], packed: false) }))
      .to eq(outline({ 0 => simple([[0, 0, true], [0, 700, true], [600, 700, true]]) }))
  end

  it "puts an on-curve point between two consecutive off-curve points" do
    glyph = simple([[0, 0, true], [100, 300, false], [300, 300, false], [400, 0, true]])

    expect(outline({ 0 => glyph })).to eq(
      [[:move, 0, 0], quad(0, 0, 100, 300, 200.0, 300.0), quad(200.0, 300.0, 300, 300, 400, 0), :close]
    )
  end

  it "starts a contour that begins off-curve at its first on-curve point, curving back to it" do
    glyph = simple([[0, 300, false], [300, 0, true], [600, 300, true]])

    expect(outline({ 0 => glyph })).to eq(
      [[:move, 300, 0], [:line, 600, 300], quad(600, 300, 0, 300, 300, 0), :close]
    )
  end

  it "starts a contour with no on-curve point halfway between its last and first points" do
    glyph = simple([[0, 100, false], [100, 100, false], [100, 0, false], [0, 0, false]])

    expect(outline({ 0 => glyph })).to eq(
      [[:move, 0.0, 50.0], quad(0.0, 50.0, 0, 100, 50.0, 100.0), quad(50.0, 100.0, 100, 100, 100.0, 50.0),
       quad(100.0, 50.0, 100, 0, 50.0, 0.0), quad(50.0, 0.0, 0, 0, 0.0, 50.0), :close]
    )
  end

  it "reads every contour of a glyph, and nothing from an empty one" do
    glyph = simple([[0, 0, true], [10, 0, true], [10, 10, true]], [[50, 50, true], [60, 50, true], [60, 60, true]])

    expect(outline({ 0 => glyph }).count(:close)).to eq(2)
    expect(outline({ 0 => glyph }).find { |segment| segment == [:move, 50, 50] }).not_to be_nil
    expect(outline({})).to eq([])
  end

  describe "composite glyphs" do
    let(:triangle) { simple([[0, 0, true], [100, 0, true], [0, 100, true]]) }

    it "places each component at its offset" do
      glyph = composite({ gid: 1, args: [10, 20] }, { gid: 1, args: [-300, 500] })

      expect(outline({ 0 => glyph, 1 => triangle })).to eq(
        [[:move, 10, 20], [:line, 110, 20], [:line, 10, 120], :close,
         [:move, -300, 500], [:line, -200, 500], [:line, -300, 600], :close]
      )
    end

    it "scales a component by one scale, by x and y scales and by a 2x2 matrix, then offsets it" do
      scaled = composite({ gid: 1, args: [10, 0], matrix: [0.5] })
      stretched = composite({ gid: 1, args: [0, 0], matrix: [1.5, -1] })
      # x' = xscale*x + scale10*y, y' = scale01*x + yscale*y
      rotated = composite({ gid: 1, args: [0, 0], matrix: [0, 1, -1, 0] })

      expect(outline({ 0 => scaled, 1 => triangle }).first(3)).to eq([[:move, 10.0, 0.0], [:line, 60.0, 0.0],
                                                                      [:line, 10.0, 50.0]])
      expect(outline({ 0 => stretched, 1 => triangle })[1..2]).to eq([[:line, 150.0, 0.0], [:line, 0.0, -100.0]])
      expect(outline({ 0 => rotated, 1 => triangle })[1..2]).to eq([[:line, 0.0, 100.0], [:line, -100.0, 0.0]])
    end

    it "scales the offset with the component when SCALED_COMPONENT_OFFSET is set" do
      glyph = composite({ gid: 1, args: [100, 10], matrix: [0.5], flags: 0x0002 | 0x0800 })

      expect(outline({ 0 => glyph, 1 => triangle }).first).to eq([:move, 50.0, 5.0])
    end

    it "anchors a component by matching one of its points to a point placed before it" do
      glyph = composite({ gid: 1, args: [0, 0] }, { gid: 1, args: [2, 1], flags: 0 })

      # point 2 of the glyph so far (0, 100) meets point 1 of the new one (100, 0)
      expect(outline({ 0 => glyph, 1 => triangle })[4..6]).to eq([[:move, -100, 100], [:line, 0, 100],
                                                                  [:line, -100, 200]])
    end

    it "refuses an anchor point the glyph does not have" do
      glyph = composite({ gid: 1, args: [0, 0] }, { gid: 1, args: [9, 1], flags: 0 })

      expect { outline({ 0 => glyph, 1 => triangle }) }.to raise_error(Stationery::UnsupportedFont, /point 9/)
    end

    it "reads a composite of composites" do
      inner = composite({ gid: 2, args: [5, 5] })
      glyph = composite({ gid: 1, args: [100, 0], matrix: [1.5] })

      expect(outline({ 0 => glyph, 1 => inner, 2 => triangle }).first(2)).to eq([[:move, 107.5, 7.5],
                                                                                 [:line, 257.5, 7.5]])
    end

    it "refuses components nested deeper than the bound, such as a glyph that contains itself" do
      expect { outline({ 0 => composite({ gid: 0, args: [0, 0] }) }) }
        .to raise_error(Stationery::UnsupportedFont, /nest/)
    end
  end
end
