# frozen_string_literal: true

RSpec.describe Stationery::Layout::Table do
  def table(rows, **, &)
    described_class.new(rows, context: ctx, **, &)
  end

  let(:rows) { [%w[Item Qty Total], ["Coffee", "2", "€8,00"], ["Tea", "1", "€3,00"]] }

  it "fills the width when asked and applies fixed column widths" do
    node = table(rows, width: :full, widths: [nil, 40, 60])

    expect(node.column_widths(260)).to eq([160, 40, 60])
  end

  it "draws every cell's text in row order" do
    pdf, = render_layout(table(rows))

    expect(strings_of(pdf)).to eq(%w[Item Qty Total Coffee 2 €8,00 Tea 1 €3,00])
  end

  it "styles rows, columns and cells through selections, including negative indexes and ranges" do
    node = table(rows, width: :full, cell: { borders: [] }) do |t|
      t.row(0).background = "#111111"
      t.row(0).weight = :bold
      t.columns(1..).align = :right
      t.rows(-1).size = 14
      t.row(1).columns(2..).color = "#FF0000"
    end

    expect(node.cell(0, 0).options).to include(background: "#111111", weight: :bold)
    expect(node.cell(1, 1).options[:align]).to eq(:right)
    expect(node.cell(0, 0).options[:align]).to be_nil
    expect(node.cell(2, 0).options[:size]).to eq(14)
    expect(node.cell(1, 2).options[:color]).to eq("#FF0000")
    expect(node.cell(1, 1).options[:color]).to be_nil
  end

  it "stripes rows with zebra" do
    node = table(rows + [%w[a b c]], cell: { borders: [] }) { |t| t.zebra(from: 1, color: "#F9FAFB") }

    expect((0..3).map { |r| node.cell(r, 0).options[:background] }).to eq([nil, "#F9FAFB", nil, "#F9FAFB"])
  end

  it "right-aligns numeric columns" do
    node = table(rows, width: :full, widths: [nil, 40, 60], cell: { padding: 0, borders: [] }) do |t|
      t.columns(1..).align = :right
    end
    pdf, = render_layout(node)
    font = open_sans_book.resolve(base_style).first
    total_x = positions_of(pdf)[5].first

    expect(total_x + font.width_of("€8,00", 10, kerning: true)).to be_within(0.01).of(280)
  end

  it "draws per-cell borders, backgrounds and padding" do
    node = table([["a"]],
                 cell: { padding: [2, 3], borders: %i[bottom], border_color: "#0000FF", background: "#EEEEEE" })
    pdf, = render_layout(node)
    content = page_contents(pdf).first

    expect(content).to include("0 0 1 RG")
    expect(content.scan(" l\nS").size).to eq(1)
    expect(positions_of(pdf).first.first).to be_within(0.01).of(23)
  end

  it "accepts layout nodes as cell content" do
    node = table([[text_node("<b>node</b>"), "text"]])

    expect(strings_of(render_layout(node).first)).to eq(%w[node text])
  end

  it "parses cell markup only when asked" do
    marked = table([["<b>x</b>"]], cell: { markup: true })
    plain = table([["<b>x</b>"]])

    expect(strings_of(render_layout(marked).first)).to eq(["x"])
    expect(strings_of(render_layout(plain).first)).to eq(["<b>x</b>"])
  end

  it "splits between rows and repeats header rows on the next page" do
    body = Array.new(30) { |i| ["row #{i + 1}", i.to_s] }
    pdf, paginator = render_layout(table([%w[Name N], *body], header: true))
    pages = reader_for(pdf).pages

    expect(pages.size).to be > 1
    expect(pages.map { |page| page.text.lines.first.strip }).to all(start_with("Name"))
    expect(text_of(pdf).scan(/row \d+/).uniq.size).to eq(30)
    expect(paginator.warnings).to be_empty
  end

  it "overflows a row taller than a page with a warning" do
    tall = Array.new(40) { "line" }.join("\n")
    _pdf, paginator = render_layout(table([[tall]]))

    expect(paginator.warnings).not_to be_empty
  end

  it "justifies cell text through the cell's align" do
    text = "The quick brown fox jumps over the lazy dog and keeps on running"
    node = table([[text]], width: :full, cell: { padding: 0, borders: [], align: :justify })
    pdf, = render_layout(node)
    left, = render_layout(table([[text]], width: :full, cell: { padding: 0, borders: [] }))

    expect(page_contents(pdf)).not_to eq(page_contents(left))
    expect(strings_of(pdf).join(" ")).to include("quick brown")
  end
end
