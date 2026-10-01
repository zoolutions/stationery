# frozen_string_literal: true

# A text field's or a select's alignment (/Q), colour and auto-size (/DA),
# written to the field and drawn the same way in its appearance.
RSpec.describe Stationery::Forms do
  let(:field_class) { Stationery::Forms::Field }
  let(:metrics) { Stationery::Forms::Metrics }
  let(:padding) { Stationery::Forms::Appearance::PADDING }

  def render(&) = SpecDocument.build(&).to_pdf

  # A field made without a font book (Helvetica), placed on the canvas at
  # `width` x `height`.
  def bare(kind, name, width: 100, height: 20, **)
    field = field_class.new(kind, name, **)
    pdf = render { canvas(height: height + 10) { |canvas, rect| canvas.widget(field, rect.x, rect.y, width, height) } }
    form_fields(pdf).fetch(name).then { |dictionary| [dictionary, appearance_of(pdf, dictionary)] }
  end

  def helvetica(text, size) = metrics.width(metrics.encode(text), size)
  def starts(stream) = stream.scan(/^(-?[\d.]+) -?[\d.]+ Td$/).flatten.map(&:to_f)
  def sizes(stream) = stream.scan(%r{/\w+ ([\d.]+) Tf}).flatten.map(&:to_f)
  def tenth(size) = (size * 10).floor / 10.0
  def glyph_box = metrics::ASCENT - metrics::DESCENT

  describe "align:" do
    it "writes /Q and centres or right-aligns the value in the box less its padding" do
      centred, centred_stream = bare(:text, "a", value: "Hi", align: :center)
      right, right_stream = bare(:text, "b", value: "Hi", align: :right)
      width = helvetica("Hi", 10)

      expect(centred[:Q]).to eq(1)
      expect(right[:Q]).to eq(2)
      expect(starts(centred_stream).first).to be_within(0.001).of(padding + ((100 - (2 * padding) - width) / 2))
      expect(starts(right_stream).first).to be_within(0.001).of(100 - padding - width)
    end

    it "writes no /Q for the default, left" do
      field, stream = bare(:text, "a", value: "Hi")

      expect(field).not_to have_key(:Q)
      expect(starts(stream)).to eq([padding.to_f])
    end

    it "offsets each line of a multiline value by its own width" do
      _, stream = bare(:text, "a", value: "a\nbbb", multiline: true, align: :center, height: 40)

      expect(starts(stream)).to eq(%w[a bbb].map { |line| (padding + ((96 - helvetica(line, 10)) / 2)).round(4) })
    end

    it "leaves a comb field's cells to place each character" do
      _, aligned = bare(:text, "a", value: "12", comb: 4, align: :right)
      _, plain = bare(:text, "a", value: "12", comb: 4)

      expect(starts(aligned)).to eq(starts(plain))
    end

    it "takes :left, :center or :right on a text field or a select only" do
      expect { field_class.new(:text, "a", align: :middle) }
        .to raise_error(ArgumentError, "align: is :left, :center or :right, not :middle")
      expect { field_class.new(:checkbox, "a", align: :center) }.to raise_error(ArgumentError, /align/)
    end
  end

  describe "color:" do
    it "writes the colour operator of /DA and paints the value in it" do
      pdf = render { text_field "price", value: "4 990 kr", color: "#DC2626" }
      field = form_fields(pdf).fetch("price")

      expect(field[:DA]).to eq("/F1 10 Tf 0.8627 0.149 0.149 rg")
      expect(appearance_of(pdf, field)).to include("0.8627 0.149 0.149 rg\nBT")
      expect(appearance_of(pdf, field)).not_to include("0 g\n")
    end

    it "writes CMYK as k and black as g" do
      cmyk, = bare(:text, "a", value: "x", color: [0, 0, 0, 100])
      black, = bare(:text, "b", value: "x", color: "#000000")

      expect(cmyk[:DA]).to eq("/Helv 10 Tf 0 0 0 1 k")
      expect(black[:DA]).to eq("/Helv 10 Tf 0 g")
    end

    it "refuses what is not a colour" do
      expect { field_class.new(:text, "a", color: "red") }.to raise_error(ArgumentError, /not a colour/)
    end
  end

  describe "font_size: :auto" do
    it "writes 0 Tf and draws the largest size the height fits" do
      field, stream = bare(:text, "a", value: "Hi", font_size: :auto)

      expect(field[:DA]).to eq("/Helv 0 Tf 0 g")
      expect(sizes(stream)).to eq([tenth((20 - (2 * padding)) / glyph_box)])
    end

    it "shrinks a long value to the width" do
      value = "Espresso machine Deluxe 3000"
      _, stream = bare(:text, "a", value:, font_size: :auto)
      size = sizes(stream).first

      expect(size).to eq(tenth(96 / helvetica(value, 1)))
      expect(helvetica(value, size)).to be <= 96
    end

    it "keeps within min_font_size: and max_font_size:" do
      _, floored = bare(:text, "a", value: "x" * 200, font_size: :auto, min_font_size: 6)
      _, capped = bare(:text, "a", value: "Hi", font_size: :auto, max_font_size: 12)
      _, small = bare(:text, "a", value: "x" * 200, font_size: :auto)

      expect(sizes(floored)).to eq([6.0])
      expect(sizes(capped)).to eq([12.0])
      expect(sizes(small)).to eq([4.0])
    end

    it "takes the largest size for an empty value" do
      field = field_class.new(:text, "a", value: "", font_size: :auto, max_font_size: 14)

      expect(Stationery::Forms::Appearance.new(field, 100, 40).size).to eq(14)
      expect(Stationery::Forms::Appearance.new(field, 100, 10).size).to eq(tenth(6 / glyph_box))
    end

    it "wraps a multiline value and fits its lines to the height" do
      value = "word " * 12
      _, stream = bare(:text, "a", value:, multiline: true, font_size: :auto, height: 60)
      size = sizes(stream).first
      lines = stream.scan(/ Td$/).size

      expect(lines).to be > 1
      expect((size * glyph_box) + ((lines - 1) * size * 1.15)).to be <= 56
      expect(size).to be > 4
    end

    it "fits a comb field's characters to their cells" do
      _, stream = bare(:text, "a", value: "WW", comb: 10, font_size: :auto, height: 40)

      expect(sizes(stream).uniq).to eq([tenth(10 / helvetica("W", 1))])
    end

    it "sizes a select's value and keeps the font's repertoire for editing" do
      pdf = render do
        select "unit", options: %w[kg piece], value: "piece", font_size: :auto, align: :center, color: "#64748B"
        text_field "name", value: "Hi", font_size: :auto, height: 40
      end
      unit, name = form_fields(pdf).values_at("unit", "name")

      expect(unit).to include(Q: 1, DA: "/F1 0 Tf 0.3922 0.4549 0.5451 rg")
      expect(sizes(appearance_of(pdf, unit)).first).to be > 10
      expect(characters_of(pdf, form_fonts(pdf).fetch(:F1))).to include("z", "~", "é")
      expect(sizes(appearance_of(pdf, name)).first).to be > 20
    end

    it "takes a positive number or :auto, and its bounds only with :auto" do
      expect { field_class.new(:text, "a", font_size: 0) }
        .to raise_error(ArgumentError, "font_size: is a number of points or :auto, not 0")
      expect { field_class.new(:text, "a", font_size: "12") }
        .to raise_error(ArgumentError, 'font_size: is a number of points or :auto, not "12"')
      expect { field_class.new(:text, "a", min_font_size: 8) }
        .to raise_error(ArgumentError, "min_font_size: needs font_size: :auto")
      expect { field_class.new(:text, "a", font_size: :auto, max_font_size: -1) }
        .to raise_error(ArgumentError, /max_font_size: is a number of points/)
      expect { field_class.new(:text, "a", font_size: :auto, min_font_size: 20, max_font_size: 10) }
        .to raise_error(ArgumentError, "min_font_size: 20 is above max_font_size: 10")
    end
  end

  describe "under monochrome" do
    let(:document) do
      Class.new(SpecDocument) do
        define_method(:view_template) { text_field "price", value: "9 kr", color: "#DC2626", border: nil }
      end
    end

    it "reports a coloured value as any other colour" do
      doc = document.new
      doc.to_pdf(monochrome: true)

      expect(doc.warnings.grep(Stationery::Warnings::NotMonochrome).map(&:message))
        .to eq(["text in #DC2626 on page 1 is not black or white"])
    end

    it "snaps it to black with snap: true, in /DA and the appearance alike" do
      pdf = document.new.to_pdf(monochrome: { snap: true })
      field = form_fields(pdf).fetch("price")

      expect(field[:DA]).to eq("/F1 10 Tf 0 g")
      expect(appearance_of(pdf, field)).to include("0 g\nBT")
    end
  end

  describe "under PDF/A" do
    it "reports a CMYK colour, which the sRGB output intent does not cover" do
      doc = SpecDocument.build { text_field "price", value: "9 kr", color: [0, 100, 100, 0] }
      doc.to_pdf(conformance: :pdf_a3b)

      expect(doc.warnings.map(&:message))
        .to eq(['PDF/A-3b: CMYK colour in form field "price" is not covered by the sRGB output intent'])
    end

    it "reports one in /DA alone, and not an RGB one" do
      page = Struct.new(:content, :annotations)
      appearance = Struct.new(:paints, :embedded?)
      widget = { widget: field_class.new(:text, "a"), appearance: appearance.new(["/F1 0 Tf 0 0 0 1 k"], true) }
      rgb = { widget: field_class.new(:text, "b"), appearance: appearance.new(["/F1 0 Tf 1 0 0 rg"], true) }
      warnings = []
      resources = Struct.new(:images).new([])
      Stationery::PDF::Conformance.new(:pdf_a3b).audit!([page.new("", [widget, rgb])], resources:, warnings:)

      expect(warnings.map(&:message))
        .to eq(['PDF/A-3b: CMYK colour in form field "a" is not covered by the sRGB output intent'])
    end
  end

  it "copies itself with changed options" do
    field = field_class.new(:text, "a", value: "x", align: :center, color: "#DC2626")
    copy = field.with(color: "#000000")

    expect([copy.name, copy.value, copy.align, copy.color]).to eq(["a", "x", :center, Stationery::Color.parse("#000")])
    expect(field.color).to eq(Stationery::Color.parse("#DC2626"))
  end
end
