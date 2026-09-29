# frozen_string_literal: true

# `table` given an Enumerator and a width for every column reads its rows as
# pages reach them, and writes the file the Array of the same rows writes.
RSpec.describe Stationery::Document, "#table" do
  before { allow(Time).to receive(:now).and_return(Time.utc(2026, 1, 1, 12)) }

  let(:rows) do
    data = Array.new(120) do |i|
      name = (i % 9).zero? ? "a longer name #{i} that wraps onto a second line of its cell" : "name #{i}"
      [i.to_s, name, "#{i * 3},50"]
    end
    [["Id", "Name", { content: "Price", align: :right }], *data]
  end
  let(:lazy) { ->(rows) { rows.lazy.map(&:itself) } }
  let(:whole) { ->(rows) { rows } }

  def document(source, widths: [30, 120, 0.3], tagged: false, split_rows: false)
    rows = self.rows
    Class.new(SpecDocument) do
      self.tagged if tagged
      metadata title: "Streamed", lang: "en"
      footer { |page| text "Page #{page.number} of #{page.count}", size: 7 }
      define_method(:view_template) do
        text "Prices", size: 14, weight: :bold
        table(source.call(rows), widths:, header: true, width: :full, split_rows:) do |t|
          t.row(0).set(weight: :bold, background: "#DDDDDD")
          t.columns(2).rows(1..).align = :right
          t.rows([3, 5..6]).color = "#AA0000"
          t.zebra(from: 1, color: "#F4F4F4")
        end
        text "After the table."
      end
    end.new
  end

  it "writes the file the Array of the same rows writes, from a lazy Enumerator or a plain one" do
    pdf = document(whole).to_pdf

    expect(document(lazy).to_pdf).to eq(pdf)
    expect(document(:each.to_proc).to_pdf).to eq(pdf)
    expect(page_count(pdf)).to be > 5
  end

  it "writes the same file incrementally, tagged and as PDF/UA" do
    expect(document(lazy).to_pdf(incremental: true)).to eq(document(whole).to_pdf(incremental: true))
    expect(document(lazy, tagged: true).to_pdf).to eq(document(whole, tagged: true).to_pdf)
    expect(document(lazy, tagged: true).to_pdf(conformance: :pdf_ua1))
      .to eq(document(whole, tagged: true).to_pdf(conformance: :pdf_ua1))
  end

  it "cuts a row at the page bottom with split_rows as the Array does" do
    expect(document(lazy, split_rows: true).to_pdf).to eq(document(whole, split_rows: true).to_pdf)
  end

  it "reads a lazy Enumerator whole when a column has no width" do
    expect(document(lazy, widths: [30, nil, 0.3]).to_pdf).to eq(document(whole, widths: [30, nil, 0.3]).to_pdf)
  end

  it "reads every row where the table is measured whole, in a box that does not break or a row" do
    few = rows.first(5)
    build = lambda do |source|
      SpecDocument.build do
        box(break_inside: :avoid) { table(source.call(few), widths: [30, 60, 40]) }
        row { column { table(source.call(few), widths: [30, 0.4, 40]) } }
      end
    end

    expect(build.call(lazy).to_pdf).to eq(build.call(whole).to_pdf)
  end

  it "builds a cell given as a proc when its row is reached, in the text style the table was given in" do
    build = lambda do |source|
      SpecDocument.build do
        text_style(color: "#0000AA") do
          table(source.call([["one", -> { text "built #{1 + 1}" }], %w[two plain]]), widths: [60, 120])
        end
      end
    end

    expect(build.call(lazy).to_pdf).to eq(build.call(whole).to_pdf)
  end
end
