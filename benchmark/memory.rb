# frozen_string_literal: true

# What a long document holds in memory while it renders. Each document and
# each form of `to_pdf` renders in a process of its own, twice: once plain
# under /usr/bin/time for the peak resident set size, once with a probe that
# counts what is still alive when building, pagination and writing end.
#
#   bundle exec rake memory              # 1,000 pages
#   PAGES=5000 bundle exec rake memory
#   DOCUMENTS=text,table FORMS=string,incremental bundle exec rake memory
#   PAGES=30303 DOCUMENTS=streamed,listed FORMS=incremental bundle exec rake memory   # a million rows
#
# The peak is what the operating system saw and moves with the machine, the
# allocator and the garbage collector's timing; the retained figures come
# after a full collection and repeat. Neither gates CI: `rake metrics` does.
#
# Run it on another checkout's code with `ruby -I<checkout>/lib benchmark/memory.rb`.
require "json"
require "objspace"
require "open3"
require "rbconfig"
require_relative "documents"

module Bench
  module Memory
    PAGES = Integer(ENV.fetch("PAGES", "1000"))
    WORDS = PARAGRAPH.split.freeze
    ROWS_PER_PAGE = 33
    SECTIONS_PER_PAGE = 16 / 3.0
    PHASES = { "build.stationery" => "built", "paginate.stationery" => "paginated",
               "write.stationery" => "written" }.freeze
    KINDS = { "nodes" => [Stationery::Layout::Node, Stationery::Layout::Table::Cell],
              "paragraphs" => [Stationery::Text::Paragraph, Stationery::Text::Line, Stationery::Text::Fragment],
              "runs" => [Stationery::Text::Run] }.freeze
    MEMOS = %i[@shapes @metrics].freeze

    # Paragraphs that differ from one another, as a real document's do: the
    # words of PARAGRAPH, rotated and numbered.
    def self.paragraph(number) = "#{number}. #{WORDS.rotate(number % WORDS.size).join(" ")}"

    # Headings and paragraphs, about PAGES A4 pages.
    class Text < Stationery::Document
      page size: :a4, margin: 48
      font_family "Open Sans", regular: FONT, bold: FONT_BOLD
      default_text font: "Open Sans", size: 9.5

      def view_template
        (PAGES * SECTIONS_PER_PAGE).round.times do |section|
          text "Section #{section + 1}", size: 16, weight: :bold
          3.times { |index| text Memory.paragraph((section * 3) + index) }
        end
      end
    end

    # The same with a footer that knows the page count and a table of
    # contents: what is painted once every page is known.
    class Report < Text
      footer { |page| text "Page #{page.number} of #{page.count}", align: :center }

      def view_template
        table_of_contents
        page_break
        (PAGES / 10).times { |chapter| text "Chapter #{chapter + 1}", size: 16, weight: :bold, bookmark: "Chapter" }
        super
      end
    end

    # One table with a repeating header row, about PAGES A4 pages.
    class Table < StationeryTable
      def view_template
        rows = Array.new(PAGES * ROWS_PER_PAGE) { |index| [(index + 1).to_s, *TABLE_ROWS[index % 1_500].drop(1)] }
        table([TABLE_HEADER, *rows], header: true, width: :full) { |t| t.row(0).weight = :bold }
      end
    end

    # A price list of as many rows, every column with a width, read from an
    # Enumerator as pages reach them (`streamed`), and the same rows given as
    # an Array, which holds every row from the start (`listed`).
    class Streamed < StationeryTable
      WIDTHS = [50, 223, 90, 70, 90].freeze

      def view_template = table(source, header: true, widths: WIDTHS) { |t| style(t) }

      def source
        Enumerator.new do |rows|
          rows << TABLE_HEADER
          (PAGES * ROWS_PER_PAGE).times { |index| rows << [(index + 1).to_s, *TABLE_ROWS[index % 1_500].drop(1)] }
        end
      end

      def style(table)
        table.row(0).weight = :bold
        table.columns(3..).align = :right
        table.zebra(from: 1, color: "#F4F4F4")
      end
    end

    class Listed < Streamed
      def view_template = table(source.to_a, header: true, widths: WIDTHS) { |t| style(t) }
    end

    DOCUMENTS = { "text" => Text, "report" => Report, "table" => Table, "streamed" => Streamed,
                  "listed" => Listed }.freeze
    FORMS = {
      "string" => ->(document) { document.to_pdf.bytesize },
      "block" => ->(document) { document.to_pdf { |chunk| chunk } },
      "incremental" => ->(document) { document.to_pdf(incremental: true) { |chunk| chunk } }
    }.freeze

    # Takes a snapshot as each phase of the render ends.
    class Probe
      attr_reader :snapshots

      def initialize = @snapshots = {}

      def instrument(name, payload = {})
        result = yield payload
        @snapshots[PHASES[name]] = Memory.snapshot.merge("pages" => payload[:pages]) if PHASES.key?(name)
        result
      end
    end

    module_function

    def incremental? = Stationery::Document.respond_to?(:incremental)

    def snapshot
      GC.start
      pages = ObjectSpace.each_object(Stationery::Page).to_a
      fonts = ObjectSpace.each_object(Stationery::Fonts::Font).to_a
      counts = KINDS.transform_values { |classes| classes.sum { |kind| ObjectSpace.each_object(kind).count } }
      { "memsize" => ObjectSpace.memsize_of_all, "objects" => GC.stat(:heap_live_slots), **counts,
        "content" => pages.sum { |page| content_of(page) },
        "annotations" => pages.sum { |page| page.annotations.size },
        "font_memos" => fonts.sum { |font| deep_size(MEMOS.map { font.instance_variable_get(it) }) } }
    end

    def content_of(page)
      parts = [page.content, (page.background if page.respond_to?(:background)),
               (page.body.data if page.respond_to?(:body) && page.body.respond_to?(:data))]
      parts.compact.sum(&:bytesize)
    end

    def deep_size(roots)
      seen = {}.compare_by_identity
      queue = roots.dup
      while (object = queue.pop)
        next if seen.key?(object) || object.is_a?(Module)

        seen[object] = true
        queue.concat(ObjectSpace.reachable_objects_from(object).grep_v(ObjectSpace::InternalObjectWrapper))
      end
      seen.each_key.sum { |object| ObjectSpace.memsize_of(object) }
    end

    # The child: one render, reported as a line of JSON.
    def render(document, form, probe:)
      Stationery.instrumenter = (probe = Probe.new) if probe
      bytes = FORMS.fetch(form).call(DOCUMENTS.fetch(document).new)
      puts JSON.generate("bytes" => bytes, "snapshots" => probe ? probe.snapshots : {})
    end

    def child(document, form, *flags)
      lib = File.dirname($LOADED_FEATURES.grep(%r{/stationery\.rb\z}).first)
      timer = RUBY_PLATFORM.include?("darwin") ? %w[/usr/bin/time -l] : %w[/usr/bin/time -v]
      timer = [] unless File.executable?(timer.first)
      out, err, = Open3.capture3({ "PAGES" => PAGES.to_s }, *timer, RbConfig.ruby, "-I#{lib}", __FILE__, "--render",
                                 document, form, *flags)
      [JSON.parse(out.lines.last), peak_of(err)]
    end

    # Megabytes, from BSD time's bytes or GNU time's kilobytes.
    def peak_of(report)
      return report[/(\d+)\s+maximum resident set size/, 1].to_i / 1_048_576.0 if report.include?("maximum resident")

      kilobytes = report[/Maximum resident set size \(kbytes\): (\d+)/, 1]
      kilobytes && (kilobytes.to_i / 1024.0)
    end

    def megabytes(bytes) = format("%.1f", bytes / 1_048_576.0)

    def row(document, form)
      _, peak = child(document, form)
      result, = child(document, form, "--probe")
      phases = result["snapshots"]
      paginated = phases.fetch("paginated")
      [document, form, paginated["pages"], peak ? format("%.0f", peak) : "n/a",
       *PHASES.values.map { megabytes(phases.dig(it, "memsize")) }, megabytes(paginated["content"]),
       megabytes(paginated["font_memos"]), paginated["nodes"], paginated["paragraphs"], paginated["runs"],
       phases.dig("written", "annotations"), megabytes(result["bytes"])]
    end

    HEADINGS = ["document", "form", "pages", "peak RSS MB", "built MB", "paginated MB", "written MB", "content MB",
                "font memos MB", "nodes", "paragraphs", "runs", "annotations", "file MB"].freeze

    def report
      forms = ENV.fetch("FORMS", FORMS.keys.join(",")).split(",")
      forms -= ["incremental"] unless incremental?
      rows = ENV.fetch("DOCUMENTS", DOCUMENTS.keys.join(",")).split(",").product(forms).map { |pair| row(*pair) }
      widths = [HEADINGS, *rows].transpose.map { |column| column.map { it.to_s.size }.max }
      puts "About #{PAGES} pages each, #{RUBY_DESCRIPTION}"
      puts "built, paginated and written are the megabytes alive (ObjectSpace.memsize_of_all after GC.start) as the"
      puts "phase ends; content, font memos and the counts are what is alive when pagination ends."
      [HEADINGS, *rows].each { |cells| puts cells.zip(widths).map { |cell, width| cell.to_s.rjust(width) }.join("  ") }
    end
  end
end

if $PROGRAM_NAME == __FILE__
  if ARGV.first == "--render"
    Bench::Memory.render(ARGV[1], ARGV[2], probe: ARGV.include?("--probe"))
  else
    Bench::Memory.report
  end
end
