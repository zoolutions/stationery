# frozen_string_literal: true

# Widgets as other writers make them: an appearance per state, flags that
# hide them, an appearance with a box and a matrix of its own.
RSpec.describe Stationery::Testing::FieldPage do
  let(:label) { "BT /F1 10 Tf 20 180 Td (Label) Tj ET" }

  def shown(pdf) = inspect_pdf(pdf).text(fields: true).lines.map(&:strip).reject(&:empty?)
  def with_widgets(content = label) = raw_pdf(content) { |writer, font| { Annots: yield(writer, font) } }
  def showing(writer, font, text, at: "2 5", **) = raw_form(writer, font, "BT /F1 10 Tf #{at} Td (#{text}) Tj ET", **)

  def widget(normal, rect: [20, 100, 120, 120], **entries)
    { Type: :Annot, Subtype: :Widget, Rect: rect, AP: { N: normal }, **entries }
  end

  it "reads the appearance of the state a button is in, and never /Off" do
    pdf = with_widgets do |writer, font|
      states = { Yes: showing(writer, font, "checked"), Off: showing(writer, font, "unchecked") }
      [widget(states, AS: :Yes), widget(states, AS: :Off, rect: [20, 70, 120, 90]),
       widget(states, AS: :Other, rect: [20, 40, 120, 60]), widget(states, rect: [20, 10, 120, 30])]
    end

    expect(shown(pdf)).to eq(%w[Label checked])
  end

  it "reads no widget that is hidden or without an appearance, and no other annotation" do
    pdf = with_widgets do |writer, font|
      [widget(showing(writer, font, "hidden"), F: 2), widget(showing(writer, font, "unseen"), F: 36),
       widget(showing(writer, font, "note")).merge(Subtype: :FreeText),
       { Type: :Annot, Subtype: :Widget, Rect: [20, 100, 120, 120] },
       widget(showing(writer, font, "printed"), F: 4, rect: [20, 40, 120, 60])]
    end

    expect(shown(pdf)).to eq(%w[Label printed])
  end

  it "reads nothing of a page without annotations" do
    expect(shown(raw_pdf(label))).to eq(["Label"])
  end

  describe "where an appearance is drawn" do
    let(:drawn) { inspect_pdf(raw_pdf("#{label} BT /F1 10 Tf 152 45 Td (value) Tj ET")).text }

    def text_with(rect: [150, 40, 250, 60], **)
      pdf = with_widgets { |writer, font| [widget(showing(writer, font, "value", **), rect:)] }
      inspect_pdf(pdf).text(fields: true)
    end

    it "is the widget's rectangle, whichever of its corners come first" do
      expect(text_with).to eq(drawn)
      expect(text_with(rect: [250, 60, 150, 40])).to eq(drawn)
    end

    it "is the rectangle for an appearance with a box and a matrix of its own" do
      expect(text_with(at: "52 55", BBox: [50, 50, 150, 70])).to eq(drawn)
      expect(text_with(Matrix: [1, 0, 0, 1, -100, -30])).to eq(drawn)
    end

    it "is as large as the rectangle makes its box" do
      pdf = with_widgets do |writer, font|
        small = raw_form(writer, font, "BT /F1 5 Tf 1 2.5 Td (value) Tj ET", BBox: [0, 0, 50, 10])
        [widget(small, rect: [150, 40, 250, 60])]
      end

      expect(inspect_pdf(pdf).text(fields: true)).to eq(drawn)
    end

    it "is nowhere for a box or a rectangle without room" do
      expect(text_with(BBox: [0, 0, 0, 20])).to eq("Label")
      expect(text_with(BBox: [0, 0, 100, 0])).to eq("Label")
      expect(text_with(rect: [0, 0, 0, 0])).to eq("Label")
    end
  end
end
