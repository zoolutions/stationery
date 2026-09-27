# frozen_string_literal: true

RSpec.describe Stationery::Layout::TableOfContents do
  def sections(toc_options = {})
    SpecDocument.build do
      text "Contents", size: 14
      table_of_contents(**toc_options)
      page_break
      text "Introduction", size: 18, bookmark: "Introduction"
      page_break
      text "Scope", bookmark: { title: "Scope", level: 2 }
      page_break
      bookmark "Appendix"
      text "Appendix", size: 18
    end.to_pdf
  end

  def page_text(pdf, index = 0) = reader_for(pdf).pages[index].text.split.join(" ")
  def digit_width(string) = open_sans_book.resolve(base_style).first.width_of(string, 10)
  def placed(pdf) = strings_of(pdf).zip(positions_of(pdf))

  it "lists every bookmark with the page it landed on" do
    pdf = sections

    expect(page_text(pdf)).to eq("Contents Introduction 2 Scope 3 Appendix 4")
    expect(page_count(pdf)).to eq(4)
  end

  it "right-aligns the page numbers on a shared edge and indents deeper levels" do
    first_page = placed(sections).first(7)
    numbers = first_page.select { |string, _| string.match?(/\A\d+\z/) }
    titles = first_page.to_h.values_at("Introduction", "Scope", "Appendix").map(&:first)

    expect(numbers.map(&:first)).to eq(%w[2 3 4])
    numbers.each { |string, (x, _)| expect(x + digit_width(string)).to be_within(0.01).of(280) }
    expect(titles.map { |x| x.round(2) }).to eq([20, 32, 20])
  end

  it "links every row to its section" do
    expect(link_destinations(sections)).to eq([[0, 1, 180], [0, 2, 180], [0, 3, 180]])
  end

  it "draws dotted leaders by default, solid lines on request and none with leader: nil" do
    solid = page_contents(sections(leader: :line)).first

    expect(page_contents(sections).first).to include("[0 3] 0 d", "1 J")
    expect(solid).not_to include("[0 3] 0 d")
    expect(solid).to match(/ l\nS/)
    expect(page_contents(sections(leader: nil)).first).not_to match(/ l\nS/)
  end

  it "filters by level and accepts a fixed number width" do
    pdf = sections(levels: 1, number_width: 40)

    expect(page_text(pdf)).to eq("Contents Introduction 2 Appendix 4")
  end

  it "paginates a long contents list" do
    pdf = SpecDocument.build do
      table_of_contents
      page_break
      60.times { |i| text "Section #{i + 1}", bookmark: "Section #{i + 1}" }
    end.to_pdf
    rows = link_destinations(pdf)
    toc_pages = rows.map(&:first).uniq
    targets = rows.map { |_, target, _| target }

    expect(rows.size).to eq(60)
    expect(toc_pages.size).to be > 1
    expect(targets).to eq(targets.sort)
    expect(targets.last).to eq(page_count(pdf) - 1)
    expect(page_text(pdf)).to start_with("Section 1 #{toc_pages.size + 1} Section 2")
  end

  it "wraps a long title and puts the number on its last line" do
    pdf = SpecDocument.build do
      table_of_contents
      page_break
      text "Body", bookmark: "A rather long section title that needs more than a single line to fit in the list"
    end.to_pdf
    lines = placed(pdf).first(2)
    number = placed(pdf).find { |string, _| string == "2" }

    expect(lines.map { |_, (_, y)| y }.uniq.size).to eq(2)
    expect(number[1][1]).to be_within(0.01).of(lines.last[1][1])
  end

  it "reads entries added after it was declared and sizes rows for title, indent and number" do
    outline = Stationery::Outline.new
    toc = described_class.new(outline, context: ctx, indent: 10, number_width: 30, gap: 5)
    outline.add("Late", level: 2)
    title = open_sans_book.resolve(base_style).first.width_of("Late", 10)

    expect(toc.natural_width).to be_within(0.01).of(title + 10 + 30 + 5)
    expect(toc.measure(200)).to eq(line_height)
  end

  it "renders nothing for an empty outline" do
    toc = described_class.new(Stationery::Outline.new, context: ctx)

    expect(toc.measure(200)).to eq(0)
    expect(toc.split(200, 100)).to eq([nil, nil])
    expect([toc.natural_width, toc.min_width, toc.splittable?]).to eq([0, 0, true])
  end
end
