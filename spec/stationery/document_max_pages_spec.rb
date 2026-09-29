# frozen_string_literal: true

RSpec.describe Stationery::Document, ".max_pages" do
  # The label of the skill's recipe, and the cold agent's change to it (#157):
  # a return address above it, which pushes the Code 128 box to a second page.
  let(:label_class) do
    Class.new(SpecDocument) do
      page size: :label_4x6, margin: mm(4)
      max_pages 1
      default_text size: 10

      def initialize(from: nil)
        super()
        @from = from
      end

      define_method(:view_template) do
        if @from
          text "FROM", size: 8, weight: :bold
          text @from.join("\n"), size: 10
          spacer 10
        end
        box(background: "#000000", padding: [8, 10]) do
          text "EXPRESS", size: 18, weight: :bold, color: "#FFFFFF", align: :center
        end
        spacer 10
        text "SHIP TO", size: 8, weight: :bold
        text "Ada Example\n12 Sample Street\n3011 Testville\nNetherlands", size: 14, leading: 2
        spacer 12
        rule height: 2
        spacer 12
        row(gap: 12, align: :middle) do
          column { text "Scan to track", size: 9 }
          column(width: :auto) { barcode "https://track.example/SX0042771903", type: :qr, module_size: 2 }
        end
        spacer 12
        box(border: { width: 2 }, padding: 10) do
          barcode "SX0042771903", type: :code128, height: 60, align: :center
          spacer 4
          text "SX0042771903", size: 12, weight: :bold, letter_spacing: 1, align: :center
        end
      end
    end
  end

  let(:from) { ["Northwind Supplies", "Unit 5, Harbour Road", "40115 Gothenburg", "Sweden"] }
  let(:label) { label_class.new }
  let(:overflowing) { label_class.new(from:) }
  let(:message) { "the document may have 1 page and needs 2: page 2 starts with a Code 128 barcode" }

  def messages(document) = document.warnings.map(&:message)

  it "is declared at class level and costs a label that fits nothing" do
    allow(Time).to receive(:now).and_return(Time.utc(2026, 1, 1))
    unlimited = Class.new(label_class) { max_pages nil }

    expect(label_class.config[:max_pages]).to eq(1)
    expect(label.to_pdf).to eq(unlimited.new.to_pdf)
    expect(label.warnings).to be_empty
  end

  it "warns when a render needs more pages, naming the limit, the pages and what moved past it" do
    pdf = overflowing.to_pdf

    expect(reader_for(pdf).page_count).to eq(2)
    warning = overflowing.warnings.first
    expect(warning).to be_a(Stationery::Warnings::TooManyPages)
    expect(warning.to_h).to eq(limit: 1, pages: 2, moved: "a Code 128 barcode")
    expect(messages(overflowing)).to eq([message])
  end

  it "raises under strict instead of writing the second page" do
    expect { overflowing.to_pdf(strict: true) }.to raise_error(Stationery::WarningsError, /#{Regexp.escape(message)}/)
    expect { Class.new(label_class) { strict }.new(from:).to_pdf }.to raise_error(Stationery::WarningsError)
  end

  it "names the text a page starts with, cut short" do
    long = Class.new(SpecDocument) do
      page size: [200, 100], margin: 10
      max_pages 2
      define_method(:view_template) do
        3.times do |index|
          box(break_inside: :avoid) { text "Part #{index + 1}: a heading that runs on well past forty characters" }
          spacer 60
        end
      end
    end.new

    long.to_pdf

    expect(messages(long)).to eq(["the document may have 2 pages and needs 3: page 3 starts with " \
                                  '"Part 3: a heading that runs on well past…"'])
  end

  it "names what is not text by its kind, and looks past a spacer into rows and boxes" do
    spilled = lambda do |&content|
      Class.new(SpecDocument) do
        page size: [200, 100], margin: 10
        max_pages 1
        define_method(:view_template) do
          box(height: 70) { text "first" }
          spacer 5
          instance_exec(&content)
        end
      end.new.tap(&:to_pdf).warnings.first.moved
    end

    expect(spilled.call { table([%w[a b]]) }).to eq("a table")
    expect(spilled.call { row { column { box { rule height: 20 } } } }).to eq("a rule")
    expect(spilled.call { barcode "4006381333931", type: :ean13 }).to eq("an EAN-13 barcode")
    expect(spilled.call { box(border: { width: 1 }) { spacer 30 } }).to eq("a box")
  end

  it "is laid over by the render: max_pages: for one render, nil for none" do
    expect(overflowing.tap { it.to_pdf(max_pages: nil) }.warnings).to be_empty
    expect(overflowing.tap { it.to_pdf(max_pages: 2) }.warnings).to be_empty
    expect(messages(Class.new(label_class) { max_pages nil }.new(from:).tap { it.to_pdf(max_pages: 1) }))
      .to eq([message])
  end

  it "is inherited, kept by a page of another size and taken away by max_pages nil" do
    resized = Class.new(label_class) { page size: :label_100x150, margin: mm(4) }

    expect(resized.config[:max_pages]).to eq(1)
    expect(resized.config[:page]).to eq(size: :label_100x150, margin: Stationery::Units.mm(4), layout: :portrait)
    expect(Class.new(label_class) { max_pages nil }.config[:max_pages]).to be_nil
    expect(label_class.config[:max_pages]).to eq(1)
  end

  it "refuses what is not a count of pages, where it is written" do
    expect { Class.new(SpecDocument) { max_pages 0 } }
      .to raise_error(ArgumentError, "max_pages is an Integer of 1 or more, or nil, not 0")
    expect { Class.new(SpecDocument) { max_pages "1" } }.to raise_error(ArgumentError, /not "1"/)
    expect { label.to_pdf(max_pages: 1.5) }.to raise_error(ArgumentError, /not 1\.5/)
  end

  it "keeps the pictures of every page in to_png, and warns" do
    expect(overflowing.to_png.size).to eq(2)
    expect(messages(overflowing)).to eq([message])
    expect { overflowing.to_png(strict: true) }.to raise_error(Stationery::WarningsError)
  end

  it "writes no label in to_zpl when it needs more than the limit, strict or not" do
    expect { overflowing.to_zpl }.to raise_error(Stationery::WarningsError, /#{Regexp.escape(message)}/)
    expect(overflowing.to_zpl(max_pages: nil).scan("^XA").size).to eq(2)
    expect(label.to_zpl.scan("^XA").size).to eq(1)
  end
end
