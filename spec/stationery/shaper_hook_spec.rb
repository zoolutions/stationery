# frozen_string_literal: true

# A document hands its text to a shaper (see Stationery::Shaper): the glyphs
# drawn, the widths lines break at, the glyphs embedded and the text a reader
# extracts all follow what the shaper answers.
RSpec.describe "the shaper hook" do # rubocop:disable RSpec/DescribeClass
  let(:ttf) { Stationery::Fonts::Registry.load(font_path("OpenSans-Regular.ttf")) }

  def hex(text) = text.each_char.map { |char| format("%04X", ttf.glyph_id(char.ord)) }.join
  def document(shaper = nil, &) = Class.new(SpecDocument) { shaper(shaper) if shaper }.build(&)
  def to_unicode(pdf) = PDF::Reader::CMap.new(font_of(pdf, :ToUnicode).unfiltered_data).map

  def font_of(pdf, key)
    objects = reader_for(pdf).objects
    font = objects.deref(reader_for(pdf).pages.first.fonts.values.first)
    return objects.deref(font[key]) if font.key?(key)

    objects.deref(objects.deref(objects.deref(font[:DescendantFonts]).first)[key])
  end

  def embedded(pdf)
    descriptor = font_of(pdf, :FontDescriptor)
    Stationery::Fonts::TrueType.new(reader_for(pdf).objects.deref(descriptor[:FontFile2]).unfiltered_data, cmap: false)
  end

  describe "configuration" do
    it "is set on the class and inherited" do
      parent = Class.new(SpecDocument) { shaper FakeShapers::REVERSED }
      child = Class.new(parent)

      expect(child.config[:shaping]).to eq(shaper: FakeShapers::REVERSED)
      expect(child.config[:shaping][:shaper]).to be(FakeShapers::REVERSED)
    end

    it "can be taken away in a subclass without touching the parent" do
      parent = Class.new(SpecDocument) { shaper FakeShapers::REVERSED }
      child = Class.new(parent) { shaper nil }

      expect(child.config[:shaping][:shaper]).to be_nil
      expect(parent.config[:shaping][:shaper]).to be(FakeShapers::REVERSED)
    end

    it "is given to one render with to_pdf(shaper:)" do
      doc = SpecDocument.build { text "abc" }

      expect(page_contents(doc.to_pdf(shaper: FakeShapers::REVERSED)).first).to include("<#{hex("c")}>")
      expect(page_contents(doc.to_pdf).first).to include("<#{hex("abc")}> Tj")
    end

    it "overrides the class's shaper for one render, also with none" do
      doc = document(FakeShapers::REVERSED) { text "abc" }

      expect(doc.to_pdf(shaper: nil)).to eq(SpecDocument.build { text "abc" }.to_pdf)
    end

    it "refuses a shaper that cannot be called" do
      expect { Class.new(SpecDocument) { shaper :harfbuzz } }.to raise_error(ArgumentError, /must answer call/)
      expect { SpecDocument.build { text "abc" }.to_pdf(shaper: "hb") }
        .to raise_error(ArgumentError, /must answer call/)
    end

    it "takes an object answering call as well as a lambda" do
      shaper = Class.new { def self.call(text, face, **) = FakeShapers::REVERSED.call(text, face) }

      expect(text_of(document(shaper) { text "abc" }.to_pdf)).to eq("abc")
    end
  end

  describe "what the shaper is given" do
    let(:shaper) { FakeShapers::Recording.new }

    it "is the font: its file, face, bytes, units per em, name and glyph count" do
      document(shaper) { text "abc" }.to_pdf
      face = shaper.calls.first[1]

      expect(face.to_h).to include(path: font_path("OpenSans-Regular.ttf"), index: 0, units_per_em: 2048,
                                   postscript_name: "OpenSans-Regular", glyph_count: ttf.num_glyphs)
      expect(face.data).to eq(File.binread(font_path("OpenSans-Regular.ttf")))
    end

    it "is the face of a collection" do
      collection = font_path("OpenSans-Collection.ttc")
      doc = Class.new(SpecDocument) { font_family "Collected", regular: "#{collection}#1" }
      doc.shaper shaper
      doc.build { text "abc", font: "Collected" }.to_pdf

      expect(shaper.calls.first[1].to_h).to include(path: collection, index: 1)
      expect(shaper.calls.first[1].data).to eq(File.binread(collection))
    end

    it "is the size, the features of the style and the language of the document" do
      doc = Class.new(SpecDocument) { metadata lang: "ar" }
      doc.shaper shaper
      doc.build { text "abc", size: 14, kerning: false, features: %i[smcp onum] }.to_pdf

      expect(shaper.calls.map(&:last).uniq).to eq(
        [{ size: 14, features: { "kern" => false, "liga" => true, "onum" => true, "smcp" => true }, language: "ar" }]
      )
      expect(shaper.calls.first.last[:features]).to be_frozen
    end

    it "is no language when the document names none" do
      document(shaper) { text "abc" }.to_pdf

      expect(shaper.calls.first.last).to include(language: nil, features: { "kern" => true, "liga" => true })
    end

    it "is each word and each stretch of spaces to break lines, then each line" do
      document(shaper) { text "one two three four five six seven eight nine ten eleven twelve" }.to_pdf

      expect(shaper.texts).to include("one", " ", "twelve")
      expect(shaper.texts).to include("one two three four five six seven eight nine ten eleven")
    end

    it "is a line cut where the style or the font changes" do
      document(shaper) { text "plain <b>bold</b> 日本", markup: true }.to_pdf

      expect(shaper.calls.map { |text, face, _| [text, face.postscript_name] })
        .to include(["plain ", "OpenSans-Regular"], %w[bold OpenSans-Bold], [" 日本", "OpenSans-Regular"])
    end

    it "is asked once for a text it has placed" do
      document(shaper) { 3.times { text "again" } }.to_pdf

      expect(shaper.texts.tally).to eq("again" => 1)
    end

    it "is asked again for another size or other features" do
      document(shaper) do
        text "again"
        text "again", size: 12
        text "again", ligatures: false
      end.to_pdf

      expect(shaper.calls.map { |_, _, options| [options[:size], options[:features]["liga"]] })
        .to eq([[10, true], [12, true], [10, false]])
    end
  end

  describe "measuring" do
    it "breaks lines at the advances of the shaper" do
      words = "one two three four five six seven eight nine ten"
      plain = page_contents(SpecDocument.build { text words }.to_pdf).first
      wide = page_contents(document(FakeShapers::WIDE) { text words }.to_pdf).first

      expect(plain.scan(/ Td$/).size).to eq(1)
      expect(wide.scan(/ Td$/).size).to eq(2)
    end

    it "aligns and underlines by them" do
      font = Stationery::Fonts::Font.new(ttf)
      content = page_contents(document(FakeShapers::WIDE) { text "abc", align: :right, underline: true }.to_pdf).first
      width = 2 * font.width_of("abc", 10)

      expect(content[/^(\S+) \S+ Td$/, 1].to_f).to be_within(0.001).of(280 - width)
      expect(content[/^\S+ \S+ (\S+) \S+ re$/, 1].to_f).to be_within(0.001).of(width)
    end

    it "covers a link with them" do
      pdf = document(FakeShapers::WIDE) { text "abc", link: "https://example.test" }.to_pdf
      x1, _, x2, = link_rects(pdf).first

      expect(x2 - x1).to be_within(0.001).of(2 * Stationery::Fonts::Font.new(ttf).width_of("abc", 10))
    end

    it "justifies by widening the spaces, in whatever order they are drawn" do
      words = "one two three four five six seven eight nine ten eleven twelve"
      content = page_contents(document(FakeShapers::REVERSED) { text words, align: :justify }.to_pdf).first
      line = content[/\[.*?\] TJ/]
      spaces = line.scan(/<#{hex(" ")}> (-[\d.]+)/).flatten.map(&:to_f)
      others = line.scan(/<(?!#{hex(" ")})\h{4}> (-[\d.]+)/).flatten.map(&:to_f)

      expect(spaces.size).to eq(9)
      expect(spaces.uniq.size).to eq(1)
      expect(spaces.first).to be < others.first
      expect(others.uniq).to eq([-48.8281])
    end
  end

  describe "drawing" do
    it "keeps the glyphs the shaper placed in the font, whatever they map to" do
      swash = ttf.num_glyphs - 1
      glyph = Stationery::Shaper::Glyph.new(gid: swash, advance: ttf.advance(swash), cluster: 0)
      shaper = ->(text, *, **) { Array.new(text.length) { |index| glyph.with(cluster: index) } }
      pdf = document(shaper) { text "aab" }.to_pdf
      code = format("%04X", swash)

      expect(page_contents(pdf).first)
        .to include("<#{code}#{code}> Tj\n/Span <</ActualText <FEFF0062>>> BDC\n<#{code}> Tj\nEMC")
      expect(embedded(pdf).num_glyphs).to eq(Stationery::Fonts::Subset.closure(ttf, Set[0, swash]).size)
      expect(to_unicode(pdf)).to eq(swash => [97])
      expect(font_of(pdf, :W)).to eq([swash, [(ttf.advance(swash) * 1000.0 / 2048).round]])
      expect(text_of(pdf)).to eq("aab")
    end

    it "embeds the glyphs of a ligature and of a mark" do
      pdf = document(FakeShapers::MARKING) { text "é" }.to_pdf

      expect(embedded(pdf).num_glyphs)
        .to eq(Stationery::Fonts::Subset.closure(ttf, Set[0, ttf.glyph_id(101), ttf.glyph_id(0x301)]).size)
      expect(to_unicode(pdf).keys).to contain_exactly(ttf.glyph_id("e".ord), ttf.glyph_id(0x301))
    end

    it "stays inside the text object of a synthetic oblique, a rise and a colour" do
      doc = Class.new(SpecDocument) { font_family "Upright", regular: "#{SpecDocument::FONTS}/OpenSans-Regular.ttf" }
      doc.shaper FakeShapers::MARKING
      content = page_contents(doc.build { text "xé<sup>é</sup>", font: "Upright", style: :italic, markup: true }
                                 .to_pdf).first

      expect(content.scan(/^1 0 \S+ 1 \S+ \S+ Tm$/).size).to eq(2)
      expect(content.scan(/^\S+ Ts$/)).to eq(["0.5859 Ts", "0 Ts", "3.3 Ts", "3.6416 Ts", "3.3 Ts"])
    end

    it "draws nothing for a text the shaper answers no glyphs for" do
      doc = document(FakeShapers::EMPTY) { text "abc" }

      expect(page_contents(doc.to_pdf).first).not_to include("BT")
      expect(doc.warnings).to be_empty
    end

    it "is what it was without a shaper when the shaper declines" do
      block = proc { text "office <b>日本</b> AV", markup: true, align: :justify, letter_spacing: 0.5 }

      expect(document(FakeShapers::DECLINING, &block).to_pdf).to eq(SpecDocument.build(&block).to_pdf)
    end

    it "raises what is wrong with an answer" do
      shaper = ->(text, face, **) { FakeShapers.nominal(text, face).map { |glyph| glyph.with(gid: 70_000) } }

      expect { document(shaper) { text "abc" }.to_pdf }
        .to raise_error(Stationery::ShaperError, "shaper answered gid 70000: the font has #{ttf.num_glyphs} glyphs")
    end
  end

  describe "extracted text" do
    it "is the text as written when the glyphs are drawn right to left" do
      pdf = document(FakeShapers::REVERSED) { text "Total due: 40" }.to_pdf

      expect(text_of(pdf)).to eq("Total due: 40")
      expect(page_contents(pdf).first).to include("/Span <</ActualText")
    end

    it "is the characters of a ligature and of a mark on its base" do
      expect(text_of(document(FakeShapers::LIGATING) { text "office file" }.to_pdf)).to eq("office file")
      expect(text_of(document(FakeShapers::MARKING) { text "café au lait" }.to_pdf)).to eq("café au lait")
    end

    it "reads once, in order, through the structure tree of a tagged document" do
      doc = Class.new(SpecDocument) do
        tagged
        metadata lang: "he", title: "t"
        shaper FakeShapers::REVERSED
        def view_template = text("first second", heading: 1)
      end.new
      inspector = inspect_pdf(doc.to_pdf)

      expect(inspector.structure).to eq([[:Document, [[:H1, "first second"]]]])
      expect(inspector.untagged_text).to be_empty
    end
  end

  describe "missing glyphs" do
    it "are the characters the shaper answered glyph 0 for" do
      shaper = ->(text, face, **) { FakeShapers.nominal(text, face).map { |glyph| glyph.with(gid: 0) } }
      doc = document(shaper) { text "ab" }
      pdf = doc.to_pdf

      expect(doc.warnings.map { |warning| [warning.char, warning.family, warning.count] })
        .to eq([["a", "Open Sans", 1], ["b", "Open Sans", 1]])
      expect(text_of(pdf)).to eq("ab")
    end

    it "are not the characters the shaper found a glyph for, whatever the cmap says" do
      shaper = ->(text, face, **) { FakeShapers.nominal(text, face).map { |glyph| glyph.with(gid: 5) } }
      doc = document(shaper) { text "日本" }
      doc.to_pdf

      expect(doc.warnings).to be_empty
    end

    it "are counted as without a shaper in text the shaper declines" do
      doc = document(FakeShapers::DECLINING) { text "a日" }
      doc.to_pdf

      expect(doc.warnings.map(&:char)).to eq(["日"])
    end
  end

  describe "form fields" do
    it "are not shaped" do
      shaper = FakeShapers::Recording.new { |glyphs, _| glyphs.reverse }
      pdf = document(shaper) { text_field "name", value: "Ada", width: 120 }.to_pdf
      widget = form_fields(pdf).fetch("name")[:Kids].first

      expect(appearance_of(pdf, widget)).to include("<#{hex("Ada")}> Tj")
      expect(shaper.texts).not_to include("Ada")
    end
  end
end
