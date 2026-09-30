# frozen_string_literal: true

require "json"
require "stationery/verify"

# Facts recorded from each engine on the form and invoice examples
# (spec/fixtures/verify/<example>.<engine>.json), held against what the
# render of the same example lays out.
RSpec.describe Stationery::Verify::Comparison do
  def expectation(name)
    Stationery::Verify::Expectation.read(Stationery::Testing::Inspector.new(RenderDigests.example(name)))
  end

  def facts(name, engine)
    JSON.parse(File.read(File.expand_path("../../fixtures/verify/#{name}.#{engine}.json", __dir__)))
  end

  def problems(name, engine, facts = facts(name, engine), allowlist: Stationery::Verify::Allowlist::ENTRIES)
    described_class.new(expectation(name), facts, engine:, allowlist:).problems
  end

  %w[form invoice].each do |name|
    Stationery::Verify::ENGINES.each_key do |engine|
      it "finds nothing wrong in #{name}.pdf as #{engine} read it" do
        expect(problems(name, engine)).to eq([])
      end
    end
  end

  it "fails a page count that is off" do
    read = facts("invoice", "qpdf").merge("pages" => [{ "number" => 1 }, { "number" => 2 }])

    expect(problems("invoice", "qpdf", read)).to eq(["2 pages, expected 1"])
  end

  it "fails a text line the engine does not find, whitespace, soft hyphens and compatibility forms aside" do
    read = facts("invoice", "pdfium")
    text = read["pages"][0]["text"]
    read["pages"][0]["text"] = text.sub("Thank you for your business", "Thank\u00ADyou for your busi ness")
                                   .sub("Rush delivery", "Rush")

    expect(problems("invoice", "pdfium", read)).to eq(['page 1: text not found: "Rush delivery"'])
  end

  it "finds a list's marker read apart from its item: before it on the page, or right after it" do
    report = Stationery::Verify::Expectation.read(Stationery::Testing::Inspector.new(RenderDigests.example("report")))
    list = report.pages[3].lines.grep(/\A\d\. (Commissioning|Moving|Consolidating)/)
    items = list.map { it.sub(/\A\d\. /, "") }
    read = lambda do |text|
      pages = report.pages.map { |page| { "number" => page.number, "text" => (page.lines - list).join("\n") } }
      pages[3]["text"] += "\n#{text}"
      described_class.new(report, { "file" => "report.pdf", "pages" => pages, "errors" => [], "warnings" => [] },
                          engine: "pdfkit").problems
    end

    expect(list.size).to eq(3)
    # PDFKit on macOS 26 reads the markers as a column before the items.
    expect(read.call("1. 2. 3. #{items.join("\n")}")).to eq([])
    expect(read.call(items.zip(%w[1. 2. 3.]).flatten.join("\n"))).to eq([])
    expect(read.call("#{items.join("\n")}\nfar below: 1. 2. 3."))
      .to eq(list.map { "page 4: text not found: #{it.inspect}" })
  end

  it "reads a column of markers before items that start with something shaped like a marker" do
    page = Stationery::Verify::Expectation::Page.new(number: 1, lines: ["1. 3.5 mm screws", "2. 4.0 mm bolts"],
                                                     links: [], content: true)
    expectation = Stationery::Verify::Expectation.new(pages: [page], outline: [], fields: [], attachments: [],
                                                      signatures: 0, valid: true, tagged: false)
    read = { "file" => "list.pdf", "pages" => [{ "number" => 1, "text" => "1. 2. 3.5 mm screws 4.0 mm bolts" }],
             "errors" => [], "warnings" => [] }

    expect(described_class.new(expectation, read, engine: "pdfkit").problems).to eq([])
  end

  it "holds a line that does not start with a list's marker to being found whole" do
    read = facts("invoice", "pdfium")
    read["pages"][0]["text"] = read["pages"][0]["text"].sub("Rush delivery", "delivery Rush")

    expect(problems("invoice", "pdfium", read)).to eq(['page 1: text not found: "Rush delivery"'])
  end

  it "names the first five lines not found on a page and counts the rest" do
    read = facts("invoice", "pdfium")
    read["pages"][0]["text"] = ""

    expect(problems("invoice", "pdfium", read)).to eq(
      [*expectation("invoice").pages[0].lines.first(5).map { "page 1: text not found: #{it.inspect}" },
       "page 1: text not found: #{expectation("invoice").pages[0].lines.size - 5} more lines"]
    )
  end

  it "fails a link the engine does not find" do
    read = facts("invoice", "pdfjs")
    read["pages"][0]["links"] = []

    expect(problems("invoice", "pdfjs", read)).to eq(["page 1: 0 links, expected 1",
                                                      'page 1: link not found: {uri: "mailto:hello@acme.test"}'])
  end

  it "fails a page with content the engine paints blank, not one it does not say" do
    blank = facts("invoice", "pdfkit").tap { |read| read["pages"][0]["painted"] = false }
    silent = facts("invoice", "pdfjs").tap { |read| read["pages"][0]["painted"] = nil }

    expect(problems("invoice", "pdfkit", blank)).to eq(["page 1: painted blank, but it has content"])
    expect(problems("invoice", "pdfjs", silent)).to eq([])
  end

  it "fails a font that is not embedded or has no ToUnicode" do
    read = facts("invoice", "poppler")
    read["fonts"][0]["unicode"] = false
    read["fonts"][1]["embedded"] = false

    expect(problems("invoice", "poppler", read)).to eq(["font OADZOW+OpenSans-Bold has no ToUnicode",
                                                        "font BBDPFR+OpenSans-Regular is not embedded"])
  end

  it "fails every error and warning, each once" do
    read = facts("invoice", "mupdf").merge("errors" => ["cannot open"], "warnings" => ["bad xref", "bad xref"])

    expect(problems("invoice", "mupdf", read)).to eq(["error: cannot open", "warning: bad xref"])
  end

  it "passes a warning the allowlist names for that engine, and only for it" do
    allowlist = [{ engine: "mupdf", pattern: /\Abad xref\z/, why: "a spec" }].freeze
    read = facts("invoice", "mupdf").merge("warnings" => ["bad xref"])

    expect(problems("invoice", "mupdf", read, allowlist:)).to eq([])
    expect(problems("invoice", "qpdf", facts("invoice", "qpdf").merge("warnings" => ["bad xref"]), allowlist:))
      .to eq(["warning: bad xref"])
  end

  it "fails a field that is missing, holds another value or has no appearance" do
    read = facts("form", "pdfium")
    read["fields"].reject! { |field| field["name"] == "notes" }
    read["fields"].find { |field| field["name"] == "applicant.name" }["value"] = "Someone else"
    read["fields"].find { |field| field["name"] == "applicant.email" }["appearance"] = false

    expect(problems("form", "pdfium",
                    read)).to eq(['field applicant.name holds "Someone else", expected "Astrid Lindqvist"',
                                  "field applicant.email has no appearance",
                                  "field notes not found"])
  end

  it "fails an outline that differs" do
    read = facts("invoice", "pdfjs").merge("outline" => ["Stray"])

    expect(problems("invoice", "pdfjs", read)).to eq(['outline ["Stray"], expected []'])
  end

  it "fails attachments, signatures and structure that differ" do
    read = facts("invoice", "poppler").merge("attachments" => ["stray.xml"], "structure" => false,
                                             "signatures" => { "count" => 1, "valid" => false })
    tagged = expectation("invoice").with(tagged: true)

    expect(described_class.new(tagged, read, engine: "poppler").problems)
      .to eq(['attachments ["stray.xml"], expected []', "1 signatures, expected 0", "a signature does not verify",
              "no structure tree, but the file is tagged"])
  end
end
