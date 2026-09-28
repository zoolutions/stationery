# frozen_string_literal: true

RSpec.describe Stationery::Fonts::ShapedRun do
  let(:path) { font_path("OpenSans-Regular.ttf") }
  let(:ttf) { Stationery::Fonts::Registry.load(path) }

  def font(shaper) = Stationery::Fonts::Font.new(ttf, shaper:, path:)
  def gid(char) = ttf.glyph_id(char.ord)
  def hex(text) = text.each_char.map { |char| format("%04X", gid(char)) }.join
  def utf16(text) = "FEFF#{text.encode(Encoding::UTF_16BE).unpack1("H*").upcase}"
  def points(units, size) = units * size / ttf.units_per_em.to_f

  # A shaper answering these glyphs, whatever the text.
  def answering(*glyphs) = ->(*, **) { glyphs.map { |fields| Stationery::Shaper::Glyph.new(**fields) } }

  describe "glyphs the font would have placed the same" do
    subject(:run) { font(FakeShapers::NOMINAL).shaped("Hi there", 10) }

    it "draws as one plain string" do
      expect(run.to_operator).to eq("<#{hex("Hi there")}> Tj")
    end

    it "is as wide as the font makes the text" do
      expect(run.width).to be_within(1e-9).of(Stationery::Fonts::Font.new(ttf).width_of("Hi there", 10))
    end

    it "answers its glyph ids and misses nothing" do
      expect(run.gids).to eq("Hi there".each_char.map { |char| gid(char) })
      expect(run.missing).to be_empty
    end
  end

  describe "advances the shaper changed" do
    subject(:run) { font(FakeShapers::WIDE).shaped("abc", 10) }

    it "are adjustments after each glyph, relative to the font's own width" do
      adjust = %w[a b].map { |char| Stationery::PDF::Serializer.number(-ttf.advance(gid(char)) * 1000.0 / 2048) }

      expect(run.to_operator).to eq("[<#{hex("a")}> #{adjust[0]} <#{hex("b")}> #{adjust[1]} <#{hex("c")}>] TJ")
    end

    it "make the width" do
      expect(run.width).to be_within(1e-9).of(2 * Stationery::Fonts::Font.new(ttf).width_of("abc", 10))
    end
  end

  describe "glyphs out of logical order" do
    subject(:run) { font(FakeShapers::REVERSED).shaped("abc", 10) }

    it "are shown as placed inside a Span with the text as written" do
      adjust = Stationery::PDF::Serializer.number(-100 * 1000.0 / 2048)

      expect(run.to_operator).to eq(
        "/Span <</ActualText <#{utf16("abc")}>>> BDC\n" \
        "[<#{hex("c")}> #{adjust} <#{hex("b")}> #{adjust} <#{hex("a")}>] TJ\nEMC"
      )
    end

    it "count the advances of the shaper" do
      expect(run.width).to be_within(1e-9).of(Stationery::Fonts::Font.new(ttf).width_of("abc", 10) + points(300, 10))
    end
  end

  describe "several characters in one glyph" do
    subject(:shaped) { font(FakeShapers::LIGATING) }

    it "map the glyph to all of them when it stands for nothing else" do
      expect(shaped.shaped("fix", 10).to_operator).to eq("<#{hex("fx")}> Tj")
      expect(shaped.used_codes).to eq(gid("f") => "fi", gid("x") => "x")
    end

    it "go in a Span once the glyph stands for another text" do
      shaped.shaped("of", 10).to_operator

      expect(shaped.shaped("fix", 10).to_operator)
        .to eq("/Span <</ActualText <#{utf16("fi")}>>> BDC\n<#{hex("f")}> Tj\nEMC\n<#{hex("x")}> Tj")
      expect(shaped.used_codes).to include(gid("f") => "f")
    end

    it "take the text before the first cluster into it" do
      run = font(answering({ gid: 5, advance: 100, cluster: 1 }, { gid: 6, advance: 100, cluster: 2 }))
            .shaped("abc", 10)

      expect(run.texts).to eq(1 => "ab", 2 => "c")
    end
  end

  describe "a mark positioned on its base" do
    subject(:run) { font(FakeShapers::MARKING).shaped("aéx", 10) }

    let(:back) { Stationery::PDF::Serializer.number(300 * 1000.0 / 2048) }
    let(:mark) { format("%04X", gid("́")) }

    it "moves the pen by the x offset and back, and lifts the glyph by the y offset" do
      forth = Stationery::PDF::Serializer.number((-300 - ttf.advance(gid("́"))) * 1000.0 / 2048)

      expect(run.to_operator).to eq(
        "<#{hex("a")}> Tj\n" \
        "/Span <</ActualText <#{utf16("é")}>>> BDC\n" \
        "<#{hex("e")}> Tj\n#{Stationery::PDF::Serializer.number(points(120, 10))} Ts\n" \
        "[#{back} <#{mark}> #{forth}] TJ\n0 Ts\nEMC\n" \
        "<#{hex("x")}> Tj"
      )
    end

    it "lifts from the rise of the run and comes back to it" do
      expect(run.with(rise: 3).to_operator).to include("\n3.5859 Ts\n").and include("\n3 Ts\nEMC")
    end

    it "leaves the mark out of the width" do
      expect(run.width).to be_within(1e-9).of(Stationery::Fonts::Font.new(ttf).width_of("aex", 10))
    end

    it "holds the base's glyph for the text only until it is drawn on its own" do
      shaped = font(FakeShapers::MARKING)
      shaped.shaped("é", 10).to_operator
      expect(shaped.used_codes).to eq(gid("e") => "é", gid("́") => "é")

      expect(shaped.shaped("e", 10).to_operator).to eq("<#{hex("e")}> Tj")
      expect(shaped.used_codes).to eq(gid("e") => "e", gid("́") => "é")
    end

    it "gives the glyph to text the shaper declined as well" do
      shaped = font(->(text, face, **) { FakeShapers::MARKING.call(text, face) if text.include?("́") })
      shaped.shaped("é", 10).to_operator
      shaped.glyph_run("e")

      expect(shaped.used_codes).to include(gid("e") => "e")
    end

    it "sets the rise once for marks that follow each other and keeps the movement between them" do
      glyphs = [{ gid: 5, advance: 0, y_offset: 100, cluster: 0 }, { gid: 6, advance: 0, y_offset: 100, cluster: 0 },
                { gid: 7, advance: ttf.advance(7), cluster: 0 }]
      operator = font(answering(*glyphs)).shaped("abc", 10).to_operator

      back = Stationery::PDF::Serializer.number(ttf.advance(5) * 1000.0 / 2048)

      expect(operator.scan(/^\S+ Ts$/)).to eq(["0.4883 Ts", "0 Ts"])
      expect(operator).to include("[<0005> #{back} <0006>")
    end
  end

  describe "letter spacing" do
    it "follows each cluster, so a mark stays on its base" do
      run = font(FakeShapers::MARKING).shaped("éx", 10, letter_spacing: 1.5)

      expect(run.extra).to eq([0, 1.5, 1.5])
      expect(run.width).to be_within(1e-9).of(Stationery::Fonts::Font.new(ttf).width_of("ex", 10) + 3)
    end

    it "is drawn as adjustments, the last one left out" do
      expect(font(FakeShapers::NOMINAL).shaped("abc", 10, letter_spacing: 1).to_operator)
        .to eq("[<#{hex("a")}> -100 <#{hex("b")}> -100 <#{hex("c")}>] TJ")
    end

    it "tells the shaper to leave ligatures apart" do
      shaper = FakeShapers::Recording.new
      font(shaper).shaped("fi", 10, letter_spacing: 1)

      expect(shaper.calls.last.last[:features]).to include("liga" => false)
    end
  end

  describe "word spacing" do
    it "widens each space, wherever the shaper placed it" do
      run = font(FakeShapers::REVERSED).shaped("a b", 10).with_word_spacing(2, 10)

      expect(run.extra).to eq([0, 2, 0])
      wider = Stationery::PDF::Serializer.number(-200 - (100_000 / 2048.0))

      expect(run.to_operator).to include("<#{hex(" ")}> #{wider}")
    end

    it "counts the spaces of a cluster" do
      run = font(answering({ gid: 5, advance: 100, cluster: 0 })).shaped("a  b", 10).with_word_spacing(2)

      expect(run.extra).to eq([4])
    end
  end

  describe "glyph 0" do
    subject(:run) { font(FakeShapers::NOMINAL).shaped("a日本b", 10) }

    it "is shown inside a Span with its characters" do
      expect(run.to_operator).to eq(
        "<#{hex("a")}> Tj\n/Span <</ActualText <#{utf16("日本")}>>> BDC\n<00000000> Tj\nEMC\n<#{hex("b")}> Tj"
      )
    end

    it "names the characters that are missing" do
      expect(run.missing).to eq(%w[日 本])
    end

    it "keeps the movement before the glyphs that follow a Span" do
      run = font(->(text, face, **) { FakeShapers.nominal(text, face).map { |glyph| glyph.with(advance: 0) } })
            .shaped("日b", 10)

      expect(run.to_operator).to match(/\[<0000> [\d.]+\] TJ\nEMC\n<#{hex("b")}> Tj\z/)
    end
  end
end
