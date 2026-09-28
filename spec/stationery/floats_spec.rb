# frozen_string_literal: true

# `float:` on images and boxes, from the DSL to the page. The page is
# 300 × 200 with a 20 pt margin, the text Open Sans at 10 pt.
RSpec.describe "Floats" do
  let(:photo) { image_path("rgb.jpg") }
  let(:words) { Array.new(60) { |i| "word#{i}" }.join(" ") }
  let(:line) { open_sans_book.resolve(base_style).first.line_height(10) }

  def build(base = SpecDocument, &) = Class.new(base) { define_method(:view_template, &) }.new
  def ops(pdf, page = 0) = page_contents(pdf)[page]
  def origins(pdf, page = 0) = ops(pdf, page).scan(/^([\d.]+) ([\d.]+) Td$/).map { |x, y| [x.to_f, y.to_f] }
  def rects(pdf) = ops(pdf).scan(/^([\d.]+) ([\d.]+) ([\d.]+) ([\d.]+) re$/).map { |rect| rect.map(&:to_f) }
  def image_at(pdf) = ops(pdf)[/^([\d.]+) 0 0 ([\d.]+) ([\d.]+) ([\d.]+) cm$/].split.values_at(0, 3, 4, 5).map(&:to_f)

  describe "image" do
    it "floats left: the text that follows starts at its top and wraps beside it, then below it" do
      source = photo
      text = words
      document = build do
        image source, float: :left, width: 80, margin: 10
        text text
      end
      xs = origins(document.to_pdf).map(&:first)
      beside = ((60 + 10) / line).ceil

      expect(image_at(document.to_pdf)).to eq([80.0, 60.0, 20.0, 120.0])
      expect(xs.first(beside).uniq).to eq([110.0])
      expect(xs.drop(beside).uniq).to eq([20.0])
      expect(origins(document.to_pdf).first.last).to be > 160
      expect(strings_of(document.to_pdf).join(" ")).to eq(text)
      expect(document).to have_no_warnings
    end

    it "floats right, and justified lines end at the float's margin" do
      source = photo
      text = words
      pdf = build do
        image source, float: :right, width: 0.5, margin: { left: 12, bottom: 4 }
        text text, align: :justify
      end.to_pdf

      expect(image_at(pdf).values_at(0, 2)).to eq([124.0, 156.0])
      expect(origins(pdf).map(&:first).uniq).to eq([20.0])
      first = reader_for(pdf).pages.first.runs.group_by { |run| run.origin.y }.max.last
      expect(first.map { |run| run.x + run.width }.max).to be_within(1).of(144)
    end

    it "rejects a side it does not know, and a margin without a float" do
      source = photo

      expect { build { image source, float: :center }.to_pdf }
        .to raise_error(ArgumentError, "float: must be :left or :right, got :center")
      expect { build { image source, margin: 4 }.to_pdf }
        .to raise_error(ArgumentError, "margin: is the space around a float: pass float: :left or :right")
    end
  end

  describe "box" do
    it "floats a pull quote with the text around it" do
      text = words
      pdf = build do
        text "Lead"
        box(float: :right, width: 90, margin: 8, padding: 6, background: "#EEEEEE") { text "Quote", weight: :bold }
        text text
      end.to_pdf

      expect(rects(pdf).first.values_at(0, 2)).to eq([190.0, 90.0])
      expect(strings_of(pdf).first(2)).to eq(%w[Lead Quote])
      expect(origins(pdf).map(&:first).first(3)).to eq([20.0, 196.0, 20.0])
      expect(origins(pdf)[0].last - origins(pdf)[2].last).to be_within(0.01).of(line)
    end

    it "takes its width in points, as a fraction or from its content" do
      widths = [60, 0.5, :auto].map do |width|
        rects(build { box(float: :left, width:, background: "#000000") { text "wide" } }.to_pdf).first[2]
      end

      expect(widths[0..1]).to eq([60.0, 130.0])
      expect(widths[2]).to be_within(0.01).of(open_sans_book.resolve(base_style).first.width_of("wide", 10))
    end

    it "needs a width and a side, and is not placed by at: as well" do
      expect { build { box(float: :left) { text "x" } }.to_pdf }
        .to raise_error(ArgumentError, "a floated box needs a width: points, a fraction or :auto")
      expect { build { box(float: :up, width: 50) { text "x" } }.to_pdf }.to raise_error(ArgumentError, /float: must/)
      expect { build { box(float: :left, width: 50, at: [0, 0]) { text "x" } }.to_pdf }
        .to raise_error(ArgumentError, "a box is placed by float: or by at:, not both")
      expect { build { box(margin: 5, width: 50) { text "x" } }.to_pdf }.to raise_error(ArgumentError, /margin: is/)
    end

    it "keeps links, anchors and bookmarks inside it working" do
      text = words
      document = build do
        text "Jump", link: "#aside"
        page_break
        box(float: :left, width: 100, margin: 6, anchor: "aside", bookmark: "Aside") do
          text "Site", link: "https://example.test"
        end
        text text
      end
      pdf = document.to_pdf

      expect(document).to have_pdf_link("https://example.test")
      expect(document).to have_bookmark("Aside")
      expect(link_destinations(pdf)).to eq([[0, 1, 180]])
      expect(outline_of(pdf).map { |item| item.values_at(:title, :page, :top) }).to eq([["Aside", 1, 180]])
      expect(origins(pdf, 1).map(&:first).first(2)).to eq([20.0, 126.0])
    end

    it "is contained by the box it is in, which is as tall as the float" do
      pdf = build do
        box(background: "#DDDDDD") do
          box(float: :left, width: 50, height: 70, background: "#000000")
          text "Beside"
        end
        text "After"
      end.to_pdf

      expect(rects(pdf).map { |rect| rect.values_at(2, 3) }).to eq([[260.0, 70.0], [50.0, 70.0]])
      expect(origins(pdf).map(&:first)).to eq([70.0, 20.0])
      expect(origins(pdf)[0].last - origins(pdf)[1].last).to be_within(0.01).of(70)
    end

    it "floats inside a column and a table cell" do
      text = words.split.first(12).join(" ")
      pdf = build do
        row(gap: 10) do
          column(width: 0.5) do
            box(float: :left, width: 30, height: 30, background: "#000000")
            text text
          end
          column { text "Other" }
        end
        table [[-> { box(float: :right, width: 20, height: 20, background: "#000000") || text("Cell") }]], width: :full
      end.to_pdf

      expect(origins(pdf).first.first).to eq(50.0)
      expect(rects(pdf).map { |rect| rect.values_at(2, 3) }).to include([30.0, 30.0], [20.0, 20.0])
    end
  end

  describe "tagged PDF" do
    let(:tagged) do
      Class.new(SpecDocument) do
        tagged
        metadata lang: "en", title: "Floats"
      end
    end

    it "tags the floats where they were written: a Figure, and the box by its role" do
      source = photo
      text = words
      pdf = build(tagged) do
        text "Title", heading: 1
        image source, float: :left, width: 60, alt: "A photo"
        text text
        box(float: :right, width: 80, role: :note) { text "Aside" }
        text "End"
      end.to_pdf

      expect(struct_types(pdf)).to eq([[:Document, [:H1, :Figure, :P, [:Note, [:P]], :P]]])
      expect(struct_tree(pdf).first.last[1][1]).to eq("A photo")
      expect(inspect_pdf(pdf).untagged_text).to be_empty
    end
  end

  it "draws the float's rectangle in debug mode" do
    text = words
    document = build do
      box(float: :left, width: 50, height: 40)
      text text
    end

    expect(document.to_pdf(debug: [:flow])).to start_with("%PDF")
    expect(document.to_pdf(debug: true).bytesize).to be > document.to_pdf.bytesize
  end

  it "keeps headers, footers and the last page's regions working around floats" do
    source = photo
    text = Array.new(400) { |i| "word#{i}" }.join(" ")
    document = Class.new(SpecDocument) do
      header { text "Head" }
      footer { text "Foot" }
      define_method(:view_template) do
        image source, float: :left, width: 100, margin: 8
        text text
        image source, float: :right, width: 100, margin: 8
        text text
      end
    end.new
    pdf = document.to_pdf
    pages = inspect_pdf(pdf).page_texts

    expect(pages.size).to be > 2
    expect(pages).to all(start_with("Head").and(end_with("Foot")))
    expect(image_count(pdf)).to eq(1)
    expect(text_of(pdf).scan(/word\d+/)).to eq(text.split * 2)
    expect(document.warnings).to be_empty
  end
end
