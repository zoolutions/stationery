# frozen_string_literal: true

RSpec.describe Stationery::Fonts::Charstring do
  let(:operators) do
    {
      hstem: 1, vstem: 3, vmoveto: 4, rlineto: 5, hlineto: 6, vlineto: 7, rrcurveto: 8, callsubr: 10, return: 11,
      endchar: 14, hstemhm: 18, hintmask: 19, cntrmask: 20, rmoveto: 21, hmoveto: 22, vstemhm: 23, rcurveline: 24,
      rlinecurve: 25, vvcurveto: 26, hhcurveto: 27, callgsubr: 29, vhcurveto: 30, hvcurveto: 31,
      hflex: [12, 34], flex: [12, 35], hflex1: [12, 36], flex1: [12, 37], add: [12, 10]
    }
  end

  # A charstring: Integers in the shortest encoding a font would use, Floats
  # as 16.16 fixed, Symbols as operators and Strings as raw bytes.
  def cs(*tokens)
    tokens.map do |token|
      case token
      when Symbol then Array(operators.fetch(token)).pack("C*")
      when Float then [255, (token * 65_536).round].pack("Cl>")
      when String then token.b
      else number(token)
      end
    end.join.b
  end

  def number(value)
    if value.between?(-107, 107) then [value + 139].pack("C")
    elsif value.between?(108, 1131) then [((value - 108) >> 8) + 247, (value - 108) & 0xFF].pack("CC")
    elsif value.between?(-1131, -108) then [((-value - 108) >> 8) + 251, (-value - 108) & 0xFF].pack("CC")
    else [28, value].pack("Cs>")
    end
  end

  def run(program, local: [], global: [])
    data = +"".b
    index = lambda do |items|
      Stationery::Fonts::CFF::Index.new(0, items.map { |item| [data.bytesize, item.bytesize].tap { data << item } }, 0)
    end
    locals = index.call(local)
    globals = index.call(global)
    offset = data.bytesize
    data << program
    described_class.new(data, globals, locals).outline(offset, program.bytesize).each_segment.to_a
  end

  it "moves, draws lines and closes the contour at endchar" do
    expect(run(cs(10, 20, :rmoveto, 100, 0, 0, 50, :rlineto, :endchar))).to eq(
      [[:move, 10, 20], [:line, 110, 20], [:line, 110, 70], :close]
    )
  end

  it "reads every operand encoding" do
    expect(run(cs(-107, 107, :rmoveto, 1131, -1131, 5000, 0.5, :rlineto, :endchar))).to eq(
      [[:move, -107, 107], [:line, 1024, -1024], [:line, 6024, -1023.5], :close]
    )
  end

  it "closes a contour at the next moveto and starts a line with no moveto at the origin" do
    expect(run(cs(10, 0, :rlineto, 5, :hmoveto, 20, :vmoveto, 3, :hlineto, :endchar))).to eq(
      [[:move, 0, 0], [:line, 10, 0], :close, [:move, 15, 0], :close, [:move, 15, 20], [:line, 18, 20], :close]
    )
  end

  describe "the advance width in front of the first stack-clearing operator" do
    it "is dropped before rmoveto, hmoveto, vmoveto and endchar" do
      expect(run(cs(500, 10, 20, :rmoveto, :endchar)).first).to eq([:move, 10, 20])
      expect(run(cs(500, 30, :hmoveto, :endchar)).first).to eq([:move, 30, 0])
      expect(run(cs(500, 30, :vmoveto, :endchar)).first).to eq([:move, 0, 30])
      expect(run(cs(500, :endchar))).to eq([])
    end

    it "is dropped before a stem, and before the implicit vstem of hintmask" do
      expect(run(cs(500, 0, 10, :hstem, 5, 5, :rmoveto, :endchar))).to eq([[:move, 5, 5], :close])
      expect(run(cs(500, 0, 10, :hintmask, "\xFF", 5, 5, :rmoveto, :endchar))).to eq([[:move, 5, 5], :close])
    end

    it "is taken only once" do
      expect(run(cs(1, 2, 3, :rmoveto, 4, :hmoveto, 7, :vmoveto, :endchar))).to eq(
        [[:move, 2, 3], :close, [:move, 6, 3], :close, [:move, 6, 10], :close]
      )
    end
  end

  describe "hints" do
    it "skips hstem, vstem, hstemhm and vstemhm with their operands" do
      program = cs(0, 10, :hstem, 0, 10, 20, 10, :vstem, 5, 5, :hstemhm, 5, 5, :vstemhm, 1, 1, :rmoveto, :endchar)

      expect(run(program)).to eq([[:move, 1, 1], :close])
    end

    # Nine stems (five declared, four implied by the operands in front of
    # hintmask) need two mask bytes; \x15 and \x0E read as rmoveto and endchar.
    it "counts the implicit vstem in front of hintmask when sizing its mask" do
      program = cs(0, 10, 20, 10, 40, 10, 60, 10, 80, 10, :hstemhm, 0, 10, 20, 10, 40, 10, 60, 10, :hintmask,
                   "\x15\x0E", 7, 8, :rmoveto, 5, 0, :rlineto, :endchar)

      expect(run(program)).to eq([[:move, 7, 8], [:line, 12, 8], :close])
    end

    it "skips cntrmask and a later hintmask by the same count" do
      program = cs(0, 10, 20, 10, :vstem, :cntrmask, "\x0E", :hintmask, "\x15", 7, 8, :rmoveto, :endchar)

      expect(run(program)).to eq([[:move, 7, 8], :close])
    end
  end

  describe "lines" do
    it "alternates horizontal and vertical lines, starting either way, with odd counts" do
      expect(run(cs(0, 0, :rmoveto, 10, 20, 30, :hlineto, :endchar))[1..3]).to eq(
        [[:line, 10, 0], [:line, 10, 20], [:line, 40, 20]]
      )
      expect(run(cs(0, 0, :rmoveto, 10, 20, :vlineto, :endchar))[1..2]).to eq([[:line, 0, 10], [:line, 20, 10]])
    end
  end

  describe "curves" do
    it "draws rrcurveto from relative control points" do
      expect(run(cs(0, 0, :rmoveto, 1, 2, 3, 4, 5, 6, 1, 1, 1, 1, 1, 1, :rrcurveto, :endchar))[1..2]).to eq(
        [[:curve, 1, 2, 4, 6, 9, 12], [:curve, 10, 13, 11, 14, 12, 15]]
      )
    end

    it "draws hhcurveto with and without a first dy" do
      expect(run(cs(0, 0, :rmoveto, 10, 20, 30, 40, :hhcurveto, :endchar))[1]).to eq([:curve, 10, 0, 30, 30, 70, 30])
      expect(run(cs(0, 0, :rmoveto, 5, 10, 20, 30, 40, 1, 1, 1, 1, :hhcurveto, :endchar))[1..2]).to eq(
        [[:curve, 10, 5, 30, 35, 70, 35], [:curve, 71, 35, 72, 36, 73, 36]]
      )
    end

    it "draws vvcurveto with and without a first dx" do
      expect(run(cs(0, 0, :rmoveto, 10, 20, 30, 40, :vvcurveto, :endchar))[1]).to eq([:curve, 0, 10, 20, 40, 20, 80])
      expect(run(cs(0, 0, :rmoveto, 5, 10, 20, 30, 40, :vvcurveto, :endchar))[1]).to eq([:curve, 5, 10, 25, 40, 25, 80])
    end

    it "alternates hvcurveto and vhcurveto, with the last curve's extra operand" do
      expect(run(cs(0, 0, :rmoveto, 10, 20, 30, 40, :hvcurveto, :endchar))[1]).to eq([:curve, 10, 0, 30, 30, 30, 70])
      expect(run(cs(0, 0, :rmoveto, 10, 20, 30, 40, 50, :hvcurveto, :endchar))[1])
        .to eq([:curve, 10, 0, 30, 30, 80, 70])
      expect(run(cs(0, 0, :rmoveto, 1, 2, 3, 4, 5, 6, 7, 8, 9, :hvcurveto, :endchar))[1..2]).to eq(
        [[:curve, 1, 0, 3, 3, 3, 7], [:curve, 3, 12, 9, 19, 17, 28]]
      )
      expect(run(cs(0, 0, :rmoveto, 1, 2, 3, 4, 5, 6, 7, 8, :vhcurveto, :endchar))[1..2]).to eq(
        [[:curve, 0, 1, 2, 4, 6, 4], [:curve, 11, 4, 17, 11, 17, 19]]
      )
      expect(run(cs(0, 0, :rmoveto, 10, 20, 30, 40, 50, :vhcurveto, :endchar))[1])
        .to eq([:curve, 0, 10, 20, 40, 60, 90])
    end

    it "draws rcurveline and rlinecurve" do
      expect(run(cs(0, 0, :rmoveto, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 5, 0, :rcurveline, :endchar))[1..3]).to eq(
        [[:curve, 1, 1, 2, 2, 3, 3], [:curve, 4, 4, 5, 5, 6, 6], [:line, 11, 6]]
      )
      expect(run(cs(0, 0, :rmoveto, 5, 0, 0, 5, 1, 1, 1, 1, 1, 1, :rlinecurve, :endchar))[1..3]).to eq(
        [[:line, 5, 0], [:line, 5, 5], [:curve, 6, 6, 7, 7, 8, 8]]
      )
    end
  end

  describe "flex" do
    it "draws flex as two curves, ignoring the flex depth" do
      expect(run(cs(0, 0, :rmoveto, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 50, :flex, :endchar))[1..2]).to eq(
        [[:curve, 1, 2, 4, 6, 9, 12], [:curve, 16, 20, 25, 30, 36, 42]]
      )
    end

    it "draws hflex with both ends level" do
      expect(run(cs(0, 0, :rmoveto, 1, 2, 3, 4, 5, 6, 7, :hflex, :endchar))[1..2]).to eq(
        [[:curve, 1, 0, 3, 3, 7, 3], [:curve, 12, 3, 18, 0, 25, 0]]
      )
    end

    it "draws hflex1 back to the starting height" do
      expect(run(cs(0, 0, :rmoveto, 1, 2, 3, 4, 5, 6, 7, 8, 9, :hflex1, :endchar))[1..2]).to eq(
        [[:curve, 1, 2, 4, 6, 9, 6], [:curve, 15, 6, 22, 14, 31, 0]]
      )
    end

    it "draws flex1 ending level or plumb, by which way it travelled further" do
      expect(run(cs(0, 0, :rmoveto, 10, 1, 10, 1, 10, 1, 10, 1, 10, 1, 7, :flex1, :endchar))[2]).to eq(
        [:curve, 40, 4, 50, 5, 57, 0]
      )
      expect(run(cs(0, 0, :rmoveto, 1, 10, 1, 10, 1, 10, 1, 10, 1, 10, 7, :flex1, :endchar))[2]).to eq(
        [:curve, 4, 40, 5, 50, 0, 57]
      )
    end
  end

  describe "subroutines" do
    let(:line) { cs(10, 0, :rlineto, :return) }

    it "calls local and global subroutines through the bias for fewer than 1240" do
      program = cs(0, 0, :rmoveto, -107, :callsubr, -106, :callgsubr, :endchar)

      expect(run(program, local: [line], global: [cs(:return), cs(0, 10, :rlineto, :return)])).to eq(
        [[:move, 0, 0], [:line, 10, 0], [:line, 10, 10], :close]
      )
    end

    it "biases by 1131 from 1240 subroutines and by 32768 from 33900" do
      middle = Array.new(1240) { cs(:return) }.tap { |subrs| subrs[0] = line }
      large = Array.new(33_900) { cs(:return) }.tap { |subrs| subrs[0] = line }

      expect(run(cs(0, 0, :rmoveto, -1131, :callsubr, :endchar), local: middle)[1]).to eq([:line, 10, 0])
      expect(run(cs(0, 0, :rmoveto, -32_768, :callgsubr, :endchar), global: large)[1]).to eq([:line, 10, 0])
    end

    it "ends the glyph at an endchar inside a subroutine" do
      program = cs(0, 0, :rmoveto, -107, :callsubr, 99, 99, :rlineto)

      expect(run(program, local: [cs(10, 0, :rlineto, :endchar)])).to eq([[:move, 0, 0], [:line, 10, 0], :close])
    end

    it "refuses a subroutine that does not exist" do
      expect { run(cs(0, :callsubr, :endchar)) }.to raise_error(Stationery::UnsupportedFont, /subroutine/)
    end

    it "refuses subroutines nested past the limit" do
      expect { run(cs(-107, :callsubr), local: [cs(-107, :callsubr)]) }
        .to raise_error(Stationery::UnsupportedFont, /nest/)
    end
  end

  it "refuses the deprecated seac form of endchar" do
    expect { run(cs(0, 0, 65, 194, :endchar)) }.to raise_error(Stationery::UnsupportedFont, /seac/)
  end

  it "refuses the arithmetic operators" do
    expect { run(cs(1, 2, :add, :endchar)) }.to raise_error(Stationery::UnsupportedFont, /operator 12 10/)
  end
end
