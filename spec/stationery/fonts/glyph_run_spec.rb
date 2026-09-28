# frozen_string_literal: true

RSpec.describe Stationery::Fonts::GlyphRun do
  let(:font) { Stationery::Fonts::Font.new(Stationery::Fonts::Registry.load(font_path("OpenSans-Regular.ttf"))) }

  def hex(text) = text.each_char.map { |c| format("%04X", font.ttf.glyph_id(c.ord)) }.join

  it "measures exactly like Font#width_of when there are no adjustments" do
    cases = [["Invoice", 10, 0], ["Hello, world", 12.5, 0], ["Total €", 9, 0.3], ["x", 7.25, -0.1]]
    cases.each do |text, size, spacing|
      expect(font.glyph_run(text).width(size, letter_spacing: spacing))
        .to be_within(1e-9).of(font.width_of(text, size, letter_spacing: spacing))
    end
  end

  it "adds adjustments in thousandths of the size to the width" do
    run = font.glyph_run("abc").with(adjust: [0, 100, 0])

    expect(run.width(10)).to be_within(1e-9).of(font.width_of("abc", 10) + 1)
  end

  it "records the glyphs it uses, like encode" do
    font.glyph_run("Hi")

    expect(font).to be_used
  end

  it "emits a Tj string when every adjustment is zero" do
    expect(font.glyph_run("Hi").to_operator).to eq("<#{hex("Hi")}> Tj")
  end

  it "emits a TJ array grouping unadjusted glyphs and negating adjustments" do
    run = font.glyph_run("abc").with(adjust: [0, -50, 0])

    expect(run.to_operator).to eq("[<#{hex("ab")}> 50 <#{hex("c")}>] TJ")
  end

  it "formats fractional adjustments like other PDF numbers" do
    run = font.glyph_run("ab").with(adjust: [12.345678, 0])

    expect(run.to_operator).to eq("[<#{hex("a")}> -12.3457 <#{hex("b")}>] TJ")
  end

  it "drops a trailing adjustment, which has no visual effect" do
    run = font.glyph_run("ab").with(adjust: [0, 30])

    expect(run.to_operator).to eq("<#{hex("ab")}> Tj")
  end

  it "adds word spacing after space glyphs only" do
    run = font.glyph_run("a b c").with_word_spacing(2, 10)

    expect(run.adjust).to eq([0, 200, 0, 200, 0])
    expect(run.to_operator).to eq("[<#{hex("a ")}> -200 <#{hex("b ")}> -200 <#{hex("c")}>] TJ")
    expect(run.width(10)).to be_within(1e-9).of(font.width_of("a b c", 10) + 4)
  end

  describe "the operator, written in one pass" do
    # What the operator was: the run sliced after each adjustment, a part per
    # slice and per adjustment, joined.
    def reference(run, trailing)
      gids = run.gids
      adjust = run.adjust
      return "<#{hex_of(gids)}> Tj" unless (trailing ? adjust : adjust[0...-1]).any? { |a| !a.zero? }

      parts = gids.each_index.slice_after { |i| !adjust[i].zero? }.flat_map do |indices|
        last = indices.last
        chunk = ["<#{hex_of(indices.map { |i| gids[i] })}>"]
        (last == gids.size - 1 && !trailing) || adjust[last].zero? ? chunk : chunk << format_number(-adjust[last])
      end
      "[#{parts.join(" ")}] TJ"
    end

    def hex_of(ids) = ids.map { |gid| font.code(gid) }.pack("n*").unpack1("H*").upcase
    def format_number(value) = Stationery::PDF::Serializer.number(value)

    def allocations
      GC.disable
      before = GC.stat(:total_allocated_objects)
      yield
      GC.stat(:total_allocated_objects) - before
    ensure
      GC.enable
    end

    it "is what the parts joined were, for every pattern of adjustments, trailing or not" do
      random = Random.new(156)
      values = [0, 0, 0, -50, 12.345678, 200, -0.00001, 1e-5].freeze
      both = [true, false].freeze
      texts = ["a", "ab", "Hello, world", "AVATAR To you", "fi ffi office", "x y z"]
      texts.each do |text|
        base = font.glyph_run(text)
        200.times do
          run = base.with(adjust: Array.new(base.gids.size) { values[random.rand(values.size)] })
          both.each do |trailing|
            expect(run.send(:show, trailing:)).to eq(reference(run, trailing)), "#{text.inspect} #{run.adjust.inspect}"
          end
        end
      end
    end

    it "keeps the pieces of a run with .notdef glyphs as they were" do
      run = font.glyph_run("a☃b☃☃c").with(adjust: [0, -50, 0, 0, 30, 0])

      expect(run.to_operator).to eq(
        "<#{hex("a")}> Tj\n/Span <</ActualText <FEFF2603>>> BDC\n[<0000> 50] TJ\nEMC\n<#{hex("b")}> Tj\n" \
        "/Span <</ActualText <FEFF26032603>>> BDC\n[<00000000> -30] TJ\nEMC\n<#{hex("c")}> Tj"
      )
    end

    it "makes a TJ array of a kerned run with a handful of objects" do
      run = font.glyph_run("AVATAR To you", kerning: true)
      run.to_operator

      expect(allocations { 10.times { run.to_operator } }).to be <= 10 * (10 + (3 * run.adjust.count { |a| !a.zero? }))
    end
  end

  it "measures kerned runs exactly like Font#width_of with kerning" do
    ["AVATAR", "To you", "Wave", "x"].each do |text|
      expect(font.glyph_run(text, kerning: true).width(11, letter_spacing: 0.2))
        .to be_within(1e-9).of(font.width_of(text, 11, letter_spacing: 0.2, kerning: true))
    end
  end
end
