# frozen_string_literal: true

RSpec.describe "Tagged PDF structure" do # rubocop:disable RSpec/DescribeClass
  let(:tagged) do
    Class.new(SpecDocument) do
      tagged
      metadata lang: "en"
    end
  end

  def build(&) = Class.new(tagged) { define_method(:view_template, &) }.new

  def objects(pdf) = reader_for(pdf).objects

  # The struct element dictionaries of `type`, in object order.
  def elements_of(pdf, type)
    found = []
    objects(pdf).each_value { |object| found << object if object.is_a?(Hash) && object[:S] == type }
    found
  end

  def attributes_of(pdf, element)
    attributes = objects(pdf).deref(element[:A])
    (attributes.is_a?(Array) ? attributes : [attributes]).map { |attrs| objects(pdf).deref(attrs) }
  end

  describe "lists" do
    it "tags a bulleted list as L > LI > LBody with its numbering and the drawn bullets as artifacts" do
      pdf = build do
        ul do
          li "One"
          li "Two"
        end
      end.to_pdf

      expect(struct_types(pdf)).to eq([[:Document, [[:L, [[:LI, [[:LBody, [:P]]]], [:LI, [[:LBody, [:P]]]]]]]]])
      expect(attributes_of(pdf, elements_of(pdf, :L).first)).to eq([{ O: :List, ListNumbering: :Disc }])
      expect(page_contents(pdf).first).to start_with("/Artifact BMC\nq\n")
    end

    it "labels numbered items with Lbl and maps the format to ListNumbering" do
      pdf = build do
        ol(format: :upper_roman) do
          li "First"
          li { ul(style: :dash) { li "Nested" } }
        end
      end.to_pdf

      nested = [:LBody, [[:L, [[:LI, [:Lbl, [:LBody, [:P]]]]]]]]
      expect(struct_types(pdf)).to eq([[:Document, [[:L, [[:LI, [:Lbl, [:LBody, [:P]]]], [:LI, [:Lbl, nested]]]]]]])
      expect(attributes_of(pdf, elements_of(pdf, :L).first)).to eq([{ O: :List, ListNumbering: :UpperRoman }])
      expect(elements_of(pdf, :L).last).not_to have_key(:A)
    end

    it "keeps an item split across pages as one LI" do
      pdf = build do
        spacer 100
        ol { li Array.new(12) { |i| "line #{i}" }.join("\n") }
      end.to_pdf

      expect(page_count(pdf)).to eq(2)
      body = struct_tree(pdf)[0][2][0][2][0][2][1]
      expect(body[0]).to eq(:LBody)
      expect(body[2][0][2].map(&:first)).to eq([0, 1])
    end
  end

  describe "tables" do
    it "tags header cells as TH with a column scope and spans as attributes" do
      pdf = build do
        table([%w[Name Qty], [{ content: "Spanning", colspan: 2 }], %w[a 1]], header: true)
      end.to_pdf

      expect(struct_types(pdf)).to eq(
        [[:Document, [[:Table, [[:TR, [[:TH, [:P]], [:TH, [:P]]]], [:TR, [[:TD, [:P]]]],
                                [:TR, [[:TD, [:P]], [:TD, [:P]]]]]]]]]
      )
      expect(attributes_of(pdf, elements_of(pdf, :TH).first)).to eq([{ O: :Table, Scope: :Column }])
      expect(attributes_of(pdf, elements_of(pdf, :TD).first)).to eq([{ O: :Table, ColSpan: 2 }])
    end

    it "shares one Table across pages and paints the repeated header as an artifact" do
      rows = [%w[Item Price]] + Array.new(8) { |i| ["item #{i}", i.to_s] }
      pdf = build { table(rows, header: 1) }.to_pdf

      expect(page_count(pdf)).to eq(2)
      tables = struct_tree(pdf)[0][2]
      expect(tables.map(&:first)).to eq([:Table])
      expect(tables[0][2].map(&:first)).to eq([:TR] * 9)
      header = tables[0][2][0][2][0][2][0]
      expect(header[2]).to eq([[0, 0]])
      expect(page_contents(pdf)[1]).to start_with("/Artifact <</Type /Pagination>> BDC\n")
    end

    it "keeps a row cut across pages in one TR with the cell's paragraph on both pages" do
      pdf = build do
        spacer 60
        table([["tall", Array.new(15) { |i| "line #{i}" }.join("\n")]], split_rows: true)
      end.to_pdf

      row = struct_tree(pdf)[0][2][0][2]
      expect(row.size).to eq(1)
      paragraph = row[0][2][1][2][0]
      expect(paragraph[2].map(&:first)).to eq([0, 1])
    end
  end

  describe "links" do
    it "puts link text in a Link inside its paragraph with the annotation's OBJR" do
      pdf = build { text "Read <a href=\"https://example.com\">the docs</a> now", markup: true }.to_pdf

      paragraph = struct_tree(pdf)[0][2][0]
      expect(paragraph[2].map { |kid| kid.first.is_a?(Symbol) ? kid.first : kid }).to eq([[0, 0], :Link, [0, 2]])
      link = elements_of(pdf, :Link).first
      objr = objects(pdf).deref(link[:K]).last
      annot = objects(pdf).deref(objr[:Obj])
      expect(objr[:Type]).to eq(:OBJR)
      expect(annot[:StructParent]).to eq(1)
      expect(parent_tree(pdf)).to eq(0 => %i[P Link P], 1 => :Link)
    end

    it "groups a linked box's content in a Link" do
      pdf = build { box(link: "https://example.com") { text "Card" } }.to_pdf

      expect(struct_types(pdf)).to eq([[:Document, [[:Link, [:P]]]]])
      expect(reader_for(pdf).pages.first.attributes[:Annots]).not_to be_nil
    end
  end

  describe "table of contents" do
    it "tags rows as TOCI with a Link holding the OBJR and a Reference for the page number" do
      pdf = build do
        table_of_contents
        page_break
        text "Intro", bookmark: "Intro", heading: 1
      end.to_pdf

      expect(struct_types(pdf)).to eq([[:Document, [[:TOC, [[:TOCI, %i[Link Reference]]]], :H1]]])
      link = elements_of(pdf, :Link).first
      kids = Array(objects(pdf).deref(link[:K]))
      expect(kids.first).to eq(0)
      expect(objects(pdf).deref(kids.last)[:Type]).to eq(:OBJR)
      expect(parent_tree(pdf)[0]).to eq(%i[Link Reference])
    end
  end

  describe "rich text" do
    it "tags headings by level and block quotes" do
      pdf = build { markdown "# Title\n\n## Part\n\n> quoted\n\nplain" }.to_pdf

      expect(struct_types(pdf)).to eq([[:Document, [:H1, :H2, [:BlockQuote, [:P]], :P]]])
    end
  end
end
