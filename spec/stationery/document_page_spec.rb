# frozen_string_literal: true

RSpec.describe Stationery::Document, ".page" do
  def document(**page)
    Class.new(SpecDocument) do
      page(**page)
      def view_template = text("x")
    end
  end

  def media_box(document) = reader_for(document.new.to_pdf).pages.first.attributes[:MediaBox]

  it "takes a size and a margin with their units" do
    label = document(size: %w[102mm 74mm], margin: "3mm")

    expect(media_box(label)).to eq([0, 0, 289.1339, 209.7638])
    expect(positions_of(label.new.to_pdf).first.first).to be_within(0.001).of(8.504)
    expect(media_box(document(size: "4in x 6in", margin: 0))).to eq([0, 0, 288, 432])
    expect(media_box(document(size: "4in x 6in", layout: :landscape))).to eq([0, 0, 432, 288])
  end

  it "knows envelopes and label stock by name" do
    expect(media_box(document(size: :dl, layout: :landscape))).to eq([0, 0, 623.62, 311.81])
    expect(media_box(document(size: :label_4x6, margin: 9))).to eq([0, 0, 288, 432])
  end

  it "keeps what it was given when that was a name or points" do
    expect(document(size: :a4, margin: [40, 44]).config[:page]).to eq(size: :a4, margin: [40, 44], layout: :portrait)
    expect(document(size: [300.5, 200], margin: { x: 4 }, layout: "landscape").config[:page])
      .to eq(size: [300.5, 200], margin: { x: 4 }, layout: "landscape")
    expect(document(size: "A5").config[:page]).to eq(size: "A5", margin: 36, layout: :portrait)
    expect(document.config[:page]).to eq(size: :letter, margin: 36, layout: :portrait)
  end

  it "refuses a size it cannot read when the class is defined" do
    expect { document(size: %w[102mm 74]) }.to raise_error(ArgumentError, /unknown page size \["102mm", "74"\]/)
    expect { document(size: :b9) }.to raise_error(ArgumentError, /unknown page size :b9/)
    expect { document(size: [0, 100]) }.to raise_error(ArgumentError, /unknown page size \[0, 100\]/)
    expect { document(size: "102 x 74") }.to raise_error(ArgumentError, /units are mm, cm, in and pt/)
  end

  it "refuses a margin it cannot read when the class is defined" do
    expect { document(margin: "3") }.to raise_error(ArgumentError, /invalid page margin "3"/)
    expect { document(margin: [1, 2, 3, 4, 5]) }.to raise_error(ArgumentError, /invalid page margin/)
    expect { document(margin: :wide) }.to raise_error(ArgumentError, /invalid page margin :wide/)
  end

  it "writes the bytes it wrote for a size in points, and for the same size with its units" do
    allow(Time).to receive(:now).and_return(Time.utc(2026, 1, 1))
    points = document(size: [288, 432], margin: 36).new.to_pdf

    expect(document(size: %w[4in 6in], margin: "0.5in").new.to_pdf).to eq(points)
    expect(document(size: :label_4x6, margin: "36pt").new.to_pdf).to eq(points)
  end
end
