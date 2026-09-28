# frozen_string_literal: true

require "stringio"

# `to_pdf(incremental: true)`: each page written as soon as it is painted.
RSpec.describe Stationery::Document, "#to_pdf" do
  before { allow(Time).to receive(:now).and_return(Time.utc(2026, 1, 1, 12)) }

  # A contents page, chapters with bookmarks and anchors, links back to the
  # first, a header, a footer that knows the page count and a watermark
  # under the body: everything that is painted once every page is known.
  let(:report) do
    Class.new(SpecDocument) do
      metadata title: "Report", lang: "en"
      header { text "Report", size: 7 }
      footer { |page| text "#{page.number} of #{page.count}", size: 7 }
      page_template(layer: :background) { box(at: [20, 90]) { text "DRAFT", size: 7, color: "#CCCCCC" } }
      attach_file "notes.txt", "hello", mime: "text/plain"

      def view_template
        table_of_contents
        3.times do |index|
          page_break
          text "Chapter #{index + 1}", size: 14, bookmark: "Chapter #{index + 1}", anchor: "chapter-#{index + 1}"
          8.times { |line| text "Paragraph #{line + 1} of chapter #{index + 1}." }
          text '<a href="#chapter-1">Back to the first</a> or <a href="https://example.com">out</a>', markup: true
        end
      end
    end.new
  end

  def streamed(document, **)
    chunks = []
    count = document.to_pdf(**) { |chunk| chunks << chunk.dup }
    [chunks.join, count, chunks]
  end

  def contents_of(pdf)
    reader = reader_for(pdf)
    reader.pages.map { |page| Array(reader.objects.deref(page.attributes[:Contents])).size }
  end

  def objects_of(pdf) = pdf.scan(/^(\d+) 0 obj/).flatten.map(&:to_i)

  it "streams the same document incrementally: pages, text, fonts and contents page numbers" do
    pdf = report.to_pdf
    file, count, = streamed(report, incremental: true)

    expect(count).to eq(file.bytesize)
    expect(page_count(file)).to eq(page_count(pdf)).and eq(7)
    expect(page_runs(file).map(&:sort)).to eq(page_runs(pdf).map(&:sort))
    expect(inspect_pdf(file).page_texts.first).to include("Chapter 1").and include("Chapter 3")
    expect(inspect_pdf(file).page_texts.first.scan(/\b[246]\b/)).to eq(%w[2 2 4 6])
    expect(reader_for(file).pages.map { it.fonts.keys }).to eq(reader_for(pdf).pages.map { it.fonts.keys })
  end

  it "streams the same links, outline and attachments incrementally" do
    pdf = report.to_pdf
    file, = streamed(report, incremental: true)

    expect(inspect_pdf(file).links).to eq(inspect_pdf(pdf).links).and eq(["https://example.com"] * 3)
    expect(link_destinations(file)).to eq(link_destinations(pdf))
    expect(link_destinations(file).map { it[1] }).to include(1, 3, 5)
    expect(outline_of(file)).to eq(outline_of(pdf))
    expect(inspect_pdf(file).bookmarks).to eq(["Chapter 1", "Chapter 2", "Chapter 3"])
    expect(inspect_pdf(file).attachments).to eq(inspect_pdf(pdf).attachments)
  end

  it "writes what is painted once every page is known as streams of its own, under and over the body" do
    file, = streamed(report, incremental: true)
    contents = page_contents(file)

    expect(contents_of(report.to_pdf)).to all(eq(1))
    expect(contents_of(file)).to all(eq(3))
    expect(contents[1].index("0.8 0.8 0.8 rg")).to be < contents[1].index("14 Tf")
    expect(strings_of(file)).to include("2 of 7", "7 of 7")
  end

  it "writes a page as one stream when nothing is painted around its body" do
    document = Class.new(SpecDocument) { def view_template = 3.times { |n| text("page #{n}") && page_break } }.new
    file, = streamed(document, incremental: true)

    expect(contents_of(file)).to eq([1, 1, 1])
    expect(page_runs(file)).to eq(page_runs(document.to_pdf))
  end

  it "hands over the body of a page before the next page is painted" do
    painted = []
    seen = []
    allow(Stationery::Canvas).to receive(:new).and_wrap_original do |original, page, *rest, **options|
      painted << page unless painted.include?(page) || options[:template]
      original.call(page, *rest, **options)
    end

    report.to_pdf(incremental: true) { |chunk| seen << painted.size if chunk.include?(" 0 obj") }

    expect(painted.size).to eq(7)
    expect(seen.first(7)).to eq([1, 2, 3, 4, 5, 6, 7])
    expect(seen.size).to be > 20
  end

  it "holds the operators of one page at a time, and the nodes of the pages still to come" do
    document = Class.new(SpecDocument) do
      page size: [311, 211], margin: 20
      footer { |page| text "#{page.number} of #{page.count}", size: 7 }
      def view_template = 400.times { |index| text "release #{index}" }
    end.new
    open_pages = []
    nodes = []
    document.to_pdf(incremental: true) do |chunk|
      next unless chunk.include?(" 0 obj")

      GC.start
      open_pages << ObjectSpace.each_object(Stationery::Page).count { it.size == [311, 211] && !it.content.empty? }
      nodes << ObjectSpace.each_object(Stationery::Layout::Text).count { it.runs.first.text.start_with?("release ") }
    end

    expect(open_pages.first(30)).to all(be <= 1)
    expect(nodes.first).to be > 380
    expect(nodes[29]).to be < 120
  end

  it "releases the nodes of painted pages in every form, and seals pages nothing paints on again" do
    document = Class.new(SpecDocument) do
      page size: [312, 212], margin: 20
      def view_template = 400.times { |index| text "let go #{index}" }
    end.new
    nodes = []
    open_pages = []
    allow(Stationery::PDF::PageSealer).to receive(:new).and_wrap_original do |original, **options|
      original.call(**options).tap do |sealer|
        allow(sealer).to receive(:call).and_wrap_original do |seal, page|
          seal.call(page)
          GC.start
          nodes << ObjectSpace.each_object(Stationery::Layout::Text).count { it.runs.first.text.start_with?("let go ") }
          open_pages << ObjectSpace.each_object(Stationery::Page).count { it.size == [312, 212] && !it.sealed? }
        end
      end
    end

    document.to_pdf

    expect(nodes.size).to be > 30
    expect(nodes.first).to be > 380
    expect(nodes.last).to be < 20
    expect(open_pages).to all(be <= 1)
  end

  it "answers the String, and writes it to a path or an IO, with the bodies first" do
    pdf = report.to_pdf(incremental: true)
    io = StringIO.new(+"".b)
    path = File.join(Dir.mktmpdir, "out.pdf")

    expect(report.to_pdf(io, incremental: true)).to eq(pdf)
    expect(io.string).to eq(pdf)
    expect(report.to_pdf(path, incremental: true)).to eq(pdf)
    expect(File.binread(path)).to eq(pdf)
    expect(pdf).not_to eq(report.to_pdf)
    expect(pdf.index("/Type /Font")).to be > pdf.index("7 0 obj")
    expect(page_runs(pdf).map(&:sort)).to eq(page_runs(report.to_pdf).map(&:sort))
  end

  it "is set for every render at class level, and unset for one" do
    document = Class.new(report.class) { incremental }.new

    expect(document.to_pdf).to eq(report.to_pdf(incremental: true))
    expect(document.to_pdf(incremental: false)).to eq(report.to_pdf)
    expect(Class.new(document.class) { incremental false }.new.to_pdf).to eq(report.to_pdf)
  end

  it "writes a tagged document with the structure the usual render has" do
    pdf = report.to_pdf(tagged: true)
    file, = streamed(report, incremental: true, tagged: true)

    expect(inspect_pdf(file).structure).to eq(inspect_pdf(pdf).structure)
    expect(inspect_pdf(file).untagged_text).to eq(inspect_pdf(pdf).untagged_text)
    expect(inspect_pdf(file)).to be_tagged
  end

  it "writes an encrypted document that opens with its password" do
    file, = streamed(report, incremental: true, encrypt: { user_password: "u", owner_password: "o" })
    reader = PDF::Reader.new(StringIO.new(file), password: "u")

    expect(reader.pages.map(&:text).last).to include("7 of 7").and include("Paragraph 8 of chapter 3.")
    expect { PDF::Reader.new(StringIO.new(file), password: "no").pages.first.text }.to raise_error(StandardError)
  end

  it "keeps the fields and the warnings of the render" do
    document = SpecDocument.build do
      text_field "name", value: "Astrid"
      page_break
      text "☃"
    end
    file, = streamed(document, incremental: true)

    expect(document.fields).to eq("name" => "Astrid")
    expect(document.warnings.map(&:class)).to eq([Stationery::Warnings::MissingGlyph])
    expect(form_fields(file).keys).to eq(["name"])
  end

  it "honours debug outlines, last-page footers and images" do
    document = Class.new(SpecDocument) do
      footer(on: :last, height: 30) { text "The end", size: 7 }
      def view_template
        image File.join(PdfHelpers::IMAGES, "rgb.jpg"), width: 40
        20.times { |index| text "line #{index}" }
      end
    end.new
    file, = streamed(document, incremental: true, debug: true)

    expect(page_runs(file).map(&:sort)).to eq(page_runs(document.to_pdf(debug: true)).map(&:sort))
    expect(image_count(file)).to eq(1)
    expect(inspect_pdf(file).page_texts.last).to include("The end")
  end

  describe "taking the usual path" do
    let(:plain) { Class.new(SpecDocument) { def view_template = 3.times { |n| text("page #{n}") && page_break } }.new }

    it "renders a document that claims conformance as it always did" do
      document = Class.new(report.class) { metadata title: "Report", lang: "en", author: "A" }.new
      options = { conformance: :pdf_a3b }
      file, = streamed(document, incremental: true, **options)

      expect(file).to eq(streamed(document, **options).first)
      expect(document.to_pdf(incremental: true, **options)).to eq(document.to_pdf(**options))
      expect(contents_of(file)).to all(eq(1))
    end

    it "raises before anything is written when a claim cannot be kept" do
      document = SpecDocument.build { text "untitled" }
      chunks = []

      expect { document.to_pdf(incremental: true, conformance: :pdf_ua1) { chunks << it } }
        .to raise_error(Stationery::Error)
      expect(chunks).to be_empty
    end

    it "renders a signed document as it always did, and refuses to stream one" do
      identity = SignatureHelpers.identity(:rsa)
      sign = { certificate: identity.certificate, key: identity.key }
      pdf = report.to_pdf(incremental: true, sign:)

      expect(inspect_pdf(pdf).signatures.map { it[:valid] }).to eq([true])
      expect(objects_of(pdf)).to eq(objects_of(pdf).sort)
      expect(contents_of(pdf)).to all(eq(1))
      expect { report.to_pdf(incremental: true, sign:) { nil } }.to raise_error(ArgumentError, /cannot be streamed/)
    end

    it "raises before the first chunk when strict finds warnings on a later page" do
      chunks = []
      document = SpecDocument.build do
        text "fine"
        page_break
        text "☃"
      end

      expect { document.to_pdf(incremental: true, strict: true) { chunks << it } }
        .to raise_error(Stationery::WarningsError)
      expect(chunks).to be_empty
    end

    it "streams a strict document without warnings as it always did" do
      file, = streamed(plain, incremental: true, strict: true)

      expect(file).to eq(streamed(plain).first)
    end
  end

  describe "a strict render that goes nowhere until it is whole" do
    it "is incremental, and writes nothing to its target when it finds warnings" do
      path = File.join(Dir.mktmpdir, "out.pdf")
      document = SpecDocument.build { text "☃" }

      expect(report.to_pdf(incremental: true, strict: true)).to eq(report.to_pdf(incremental: true))
      expect { document.to_pdf(path, incremental: true, strict: true) }.to raise_error(Stationery::WarningsError)
      expect(File).not_to exist(path)
    end
  end

  describe "readers other than the gem's own" do
    def tool(*command, input:)
      path = File.join(Dir.mktmpdir, "incremental.pdf")
      File.binwrite(path, input)
      Open3.capture3(*command.map { it == :file ? path : it })
    end

    def installed?(name) = system("which #{name} > #{File::NULL} 2>&1")

    let(:file) { streamed(report, incremental: true, tagged: true).first }

    it "is read by pdftotext without complaint" do
      skip "pdftotext is not installed" unless installed?("pdftotext")
      text, errors, status = tool("pdftotext", :file, "-", input: file)

      expect(status).to be_success
      expect(errors).to be_empty
      expect(text).to eq(tool("pdftotext", :file, "-", input: report.to_pdf(tagged: true)).first)
      expect(text).to include("7 of 7")
    end

    it "is read by mutool without complaint" do
      skip "mutool is not installed" unless installed?("mutool")
      output, errors, status = tool("mutool", "show", :file, "pages", input: file)

      expect(status).to be_success
      expect(errors).to be_empty
      expect(output.lines.size).to eq(7)
    end

    it "passes qpdf --check" do
      skip "qpdf is not installed" unless installed?("qpdf")
      output, errors, status = tool("qpdf", "--check", :file, input: file)

      expect(status).to be_success
      expect(errors).to be_empty
      expect(output).to include("No syntax or stream encoding errors")
    end
  end
end
