# frozen_string_literal: true

# The spec page holds 260 x 160 points, eleven lines of the default text.
RSpec.describe "columns" do # rubocop:disable RSpec/DescribeClass
  def lines(count, prefix = "line") = Array.new(count) { |i| "#{prefix} #{i + 1}" }.join("\n")

  # { text => [x, baseline from the bottom of the page] } per page.
  def placed(pdf)
    reader_for(pdf).pages.map do |page|
      page.runs.to_h { |run| [run.text, [run.origin.x.round(2), run.origin.y.round(2)]] }
    end
  end

  it "pours one flow through balanced columns and continues below the tallest" do
    body = lines(5)
    doc = SpecDocument.build do
      text "Title"
      columns(gap: 20) { text body }
      text "After"
    end
    page = placed(doc.to_pdf).first

    expect(page["line 1"]).to match([20, a_value_within(0.01).of(page["Title"].last - line_height)])
    expect(page["line 4"]).to eq([160, page["line 1"].last])
    expect(page["line 5"]).to eq([160, page["line 2"].last])
    expect(page["After"]).to match([20, a_value_within(0.01).of(page["line 3"].last - line_height)])
    expect(doc).to have_no_warnings
  end

  it "fills balanced columns evenly" do
    body = lines(10)
    page = placed(SpecDocument.build { columns(count: 3, gap: 10) { text body } }.to_pdf).first
    columns = page.group_by { |_, (x, _)| x.round }.transform_values { |runs| runs.map(&:first) }
    expected = lines(10).split("\n")

    expect(columns).to eq(20 => expected[0, 4], 110 => expected[4, 3], 200 => expected[7, 3])
  end

  it "takes a count, a gap and text alignment" do
    body = lines(3)
    pdf = SpecDocument.build { columns(count: 3, gap: 10, align: :right) { text body } }.to_pdf
    page = placed(pdf).first
    width = open_sans_book.resolve(base_style).first.width_of("line 1", 10, kerning: true)

    expect(page.values.map(&:last).uniq.size).to eq(1)
    expect(page["line 1"].first).to be_within(0.01).of(20 + 80 - width)
    expect(page["line 3"].first).to be_within(0.01).of(20 + 260 - width)
  end

  it "fills each column before the next with balance: false" do
    body = lines(14)
    page = placed(SpecDocument.build { columns(balance: false) { text body } }.to_pdf).first

    expect(page.count { |_, (x, _)| x == 20 }).to eq(11)
    expect(page.count { |_, (x, _)| x > 20 }).to eq(3)
  end

  it "refuses arguments it cannot use" do
    expect { SpecDocument.build { columns(count: 0) { text "x" } }.to_pdf }.to raise_error(ArgumentError, /count:/)
    expect { SpecDocument.build { columns(gap: -1) { text "x" } }.to_pdf }.to raise_error(ArgumentError, /gap:/)
  end

  it "balances the last page between a header and the last page's footer" do
    body = lines(40)
    doc = Class.new(SpecDocument) do
      header(height: 20) { text "HEAD" }
      footer(on: :last, height: 40) { text "TOTAL" }
      define_method(:view_template) { columns(gap: 20) { text body } }
    end.new
    pages = placed(doc.to_pdf)

    expect(pages.size).to eq(3)
    expect(pages.map { |page| page.key?("HEAD") }).to all(be(true))
    expect(pages.map { |page| page.key?("TOTAL") }).to eq([false, false, true])
    expect(pages[0].size - 1).to eq(18)
    expect(pages[2]["line 37"].last).to eq(pages[2]["line 39"].last)
    expect(pages[2]["line 40"].last).to be > 20 + 40
    expect(doc).to have_no_warnings
  end

  describe "in a tagged PDF" do
    def build(&)
      Class.new(SpecDocument) do
        tagged
        metadata lang: "en"
        define_method(:view_template, &)
      end.new
    end

    it "reads column 1 top to bottom, then column 2, with a split paragraph as one P" do
      body = lines(6)
      pdf = build do
        text "Title", heading: 1
        columns do
          text "Lead", heading: 2
          text body
          text "End"
        end
        text "After"
      end.to_pdf

      expect(struct_tree(pdf)).to eq([[:Document, nil, [[:H1, nil, [[0, 0]]], [:H2, nil, [[0, 1]]],
                                                        [:P, nil, [[0, 2], [0, 3]]], [:P, nil, [[0, 4]]],
                                                        [:P, nil, [[0, 5]]]]]])
      expect(parent_tree(pdf)).to eq(0 => %i[H1 H2 P P P P])
      expect(strings_of(pdf))
        .to eq(["Title", "Lead", *Array.new(6) { |i| "line #{i + 1}" }, "End", "After"])
    end

    it "reads columns filled evenly in order, a paragraph split across three of them as one P" do
      body = lines(10)
      pdf = build { columns(count: 3) { text body } }.to_pdf

      expect(struct_tree(pdf)).to eq([[:Document, nil, [[:P, nil, [[0, 0], [0, 1], [0, 2]]]]]])
      expect(strings_of(pdf)).to eq(body.split("\n"))
      expect(inspect_pdf(pdf).untagged_text).to be_empty
    end

    it "marks the rule as an artifact and keeps a paragraph split across pages and columns as one P" do
      body = lines(30)
      pdf = build { columns(rule: true) { text body } }.to_pdf

      expect(struct_tree(pdf)).to eq([[:Document, nil, [[:P, nil, [[0, 0], [0, 1], [1, 0], [1, 1]]]]]])
      expect(page_contents(pdf).first).to match(%r{/Artifact BMC\nq\n[^Q]*\bS\nQ\nEMC})
      expect(inspect_pdf(pdf).untagged_text).to be_empty
    end
  end

  describe "links, anchors, bookmarks and the table of contents" do
    let(:document) do
      body = lines(30)
      SpecDocument.build do
        table_of_contents
        text "go", link: "#deep"
        columns(gap: 20) do
          text "First", bookmark: "First", heading: 1
          text body
          text "Deep", anchor: "deep", bookmark: "Deep"
          text "site", link: "https://example.com"
        end
      end
    end
    let(:pdf) { document.to_pdf }

    it "numbers the pages of bookmarks inside columns" do
      page = reader_for(pdf).pages.first.runs.map(&:text)

      expect(page_count(pdf)).to eq(2)
      expect(page.each_cons(2).to_a).to include(%w[First 1], %w[Deep 2])
      expect(outline_of(pdf).map { |item| item.values_at(:title, :page) }).to eq([["First", 0], ["Deep", 1]])
    end

    it "links to an anchor in the column it landed in, and out from a column" do
      deep = placed(pdf)[1]["Deep"]
      targets = link_destinations(pdf)

      expect(deep.first).to eq(160)
      expect(targets).to include([0, 1, a_value_within(line_height).of(deep.last + line_height)])
      expect(pdf).to have_pdf_link("https://example.com")
      expect(link_rects(pdf).map(&:first)).to include(a_value_within(0.01).of(160))
      expect(document).to have_no_warnings
    end
  end

  it "leaves a document without columns as it was" do
    doc = SpecDocument.build { text "plain" }
    allow(Stationery::Layout::Columns).to receive(:new)

    doc.to_pdf

    expect(Stationery::Layout::Columns).not_to have_received(:new)
  end
end
