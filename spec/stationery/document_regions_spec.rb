# frozen_string_literal: true

RSpec.describe Stationery::Document do
  def document(&)
    Class.new(SpecDocument) do
      class_exec(&) if block_given?
      def view_template = 30.times { |i| text("line #{i}") }
    end
  end

  def runs(doc) = page_runs(doc.new.to_pdf)
  def top_of_body(page_runs) = page_runs.find { |text, _| text.start_with?("line") }.last
  def y_of(page_runs, text) = page_runs.assoc(text).last

  let(:plain) { runs(document) }
  let(:first_baseline) { top_of_body(plain.first) }

  it "starts the body below a header of the given height on every page" do
    pages = runs(document { header(height: 20) { text "HEAD" } })

    expect(pages.size).to be > 1
    expect(pages.map { |page| top_of_body(page) }).to all(be_within(0.01).of(first_baseline - 28))
    expect(pages.map { |page| y_of(page, "HEAD") }).to all(be_within(0.01).of(first_baseline))
  end

  it "measures a header without a height and adds its gap" do
    pages = runs(document { header(gap: 5) { text "HEAD" } })

    expect(top_of_body(pages.first)).to be_within(0.01).of(first_baseline - line_height - 5)
  end

  it "bottom-aligns the footer inside its reservation and ends the body above it" do
    pages = runs(document { footer(height: 40) { text "FOOT" } })
    foot = y_of(pages.first, "FOOT")
    lowest = pages.first.filter_map { |text, y| y unless text == "FOOT" }.min

    expect(foot).to be_between(20, 20 + line_height)
    expect(lowest).to be > 20 + 40 + 8
    expect(pages.size).to be > plain.size
  end

  it "shows the real page count in the footer" do
    pdf = document { footer { |page| text "Page #{page.number} of #{page.count}" } }.new.to_pdf
    count = page_count(pdf)

    expect(strings_of(pdf).grep(/Page/)).to eq((1..count).map { |n| "Page #{n} of #{count}" })
  end

  it "limits a header to the pages it is declared on" do
    pages = runs(document { header(on: :first) { text "TITLE" } })

    expect(pages.flatten.count("TITLE")).to eq(1)
    expect(top_of_body(pages[1])).to be > top_of_body(pages[0])
    expect(top_of_body(pages[1])).to be_within(0.01).of(first_baseline)
  end

  it "lets a later declaration with an empty block remove the header from its pages" do
    pages = runs(document do
      header { text "HEAD" }
      header(on: :first) { nil }
    end)

    expect(top_of_body(pages[0])).to be_within(0.01).of(first_baseline)
    expect(top_of_body(pages[1])).to be < first_baseline
    expect(pages[0].assoc("HEAD")).to be_nil
  end

  it "gives page templates the reduced content box" do
    heights = []
    document do
      header(height: 20, gap: 0)
      footer(height: 10, gap: 0)
      page_template { |page| heights << page.content_box.height }
    end.new.to_pdf

    expect(heights.uniq).to eq([160 - 30])
  end

  it "records a region taller than its reservation as a warning" do
    doc = document { header(height: 5) { text "too tall" } }.new
    pdf = doc.to_pdf

    expect(doc.warnings.map(&:page).uniq).to eq((1..page_count(pdf)).to_a)
  end

  it "refuses regions that leave no room for the body" do
    doc = document do
      header(height: 100, gap: 0)
      footer(height: 60, gap: 0)
    end

    expect { doc.new.to_pdf }.to raise_error(ArgumentError, /no room.*page 1/)
  end

  describe "on: :last" do
    def totals(lines)
      Class.new(SpecDocument) do
        footer(height: 10) { text "f", size: 6 }
        footer(on: :last, height: 60) { text "TOTAL" }
        define_method(:view_template) { lines.times { |i| text("line #{i}") } }
      end
    end

    def body_bottom(page) = page.filter_map { |text, y| y if text.start_with?("line") }.min

    it "ends the last page's body above the taller last footer" do
      pages = runs(totals(30))

      expect(pages.last.assoc("TOTAL")).not_to be_nil
      expect(pages[0...-1].flatten).not_to include("TOTAL")
      expect(body_bottom(pages.last)).to be > 20 + 60 + 8
      expect(body_bottom(pages.first)).to be < 20 + 60
    end

    it "moves content that only fits a normal page onto an extra last page" do
      pages = runs(totals(8))

      expect(pages.size).to eq(2)
      expect(pages.first.assoc("f")).not_to be_nil
      expect(pages.last.assoc("TOTAL")).not_to be_nil
    end

    it "uses the last footer on a single page" do
      pages = runs(totals(4))

      expect(pages.size).to eq(1)
      expect(pages.first.assoc("TOTAL")).not_to be_nil
      expect(pages.first.assoc("f")).to be_nil
    end
  end

  it "rejects an unknown on: selector" do
    expect { document { header(on: :sometimes) { nil } } }.to raise_error(ArgumentError, /on:/)
  end

  it "inherits regions into subclasses without leaking back" do
    parent = document { header(height: 20) { text "HEAD" } }
    child = Class.new(parent) { footer(height: 10) { text "FOOT" } }

    expect(child.config[:regions].map(&:slot)).to eq(%i[header footer])
    expect(parent.config[:regions].map(&:slot)).to eq(%i[header])
  end
end
