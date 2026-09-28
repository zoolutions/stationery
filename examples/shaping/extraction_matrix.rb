# frozen_string_literal: true

# What comes out of a PDF whose right-to-left text a shaper placed, extractor
# by extractor, for three ways of writing it (zoolutions/stationery#151):
#
#   A  what the gem writes: a reordered stretch in one Span whose ActualText
#      is the whole stretch in logical order
#   B  one Span per cluster, in visual order
#   C  no Span where the ToUnicode map gives a glyph its text; one per
#      cluster where it cannot
#
# B and C are experiments that live in this file only (Variants, below): the
# gem writes A. Nothing here is loaded by the gem.
#
# Needs, all outside the gem's bundle:
#
#   brew install harfbuzz poppler mupdf
#   gem install harfbuzz-ruby pdf-reader
#   npm install pdfjs-dist                  (in a directory of its own)
#   python3 -m venv venv && venv/bin/pip install pypdfium2
#   NotoSansArabic-Regular.ttf and NotoSansHebrew-Regular.ttf, from
#   https://github.com/notofonts/notofonts.github.io/tree/main/fonts
#
# The Noto Arabic families draw a letter as two glyphs, its shape and its
# dots, so no ToUnicode map can give their text. Amiri
# (https://github.com/aliftype/amiri) draws one glyph per letter: run the
# matrix with both.
#
# Run:
#
#   ruby -Ilib examples/shaping/extraction_matrix.rb \
#     --arabic NotoSansArabic-Regular.ttf --hebrew NotoSansHebrew-Regular.ttf \
#     --out tmp/extraction [--pdfjs dir/node_modules/pdfjs-dist] [--python venv/bin/python]
#
# It writes <out>/<variant>-<case>.pdf, the same tagged as PDF/UA-1
# (<out>/tagged/, for veraPDF), and <out>/matrix.md. An extractor that is not
# installed is left out of the matrix, never guessed. PDFKit (what Preview
# reads with) runs on macOS through swift.
require "optparse"
require "open3"
require "fileutils"
require_relative "harfbuzz_shaper"
require "stationery/testing/inspector"

module ExtractionMatrix
  HERE = File.expand_path("extraction_matrix", __dir__)
  CONTROLS = /[‎‏‪-‮⁦-⁩]/

  # The variant being rendered, :a unless #render says otherwise.
  def self.variant = Thread.current[:extraction_matrix_variant] || :a

  # The experiments, over Stationery::Fonts::ShapedRun#to_operator.
  module Variants
    def to_operator
      return super if ExtractionMatrix.variant == :a

      groups = pieces.chunk_while { |(left, _), (right, _)| left && right }
                     .map { |group| [group.first.first, group.flat_map(&:last)] }
      groups.each_with_index.map do |(plain, indices), index|
        trailing = index < groups.size - 1
        plain ? show(indices, trailing) : marked(indices, trailing)
      end.join("\n")
    end

    private

    # [[plain, glyph indexes], …], one per cluster in visual order.
    def pieces
      counts = glyphs.map(&:cluster).tally
      own = glyphs.map { |glyph| own?(glyph, counts[glyph.cluster] == 1) }
      return clusters(glyphs.each_index.to_a, own) if ExtractionMatrix.variant == :c

      # B: the stretches A cuts, each reordered one a Span per cluster.
      stretches.flat_map { |plain, indices| plain ? [[true, indices]] : clusters(indices, own, spans: true) }
    end

    def clusters(indices, own, spans: false)
      indices.chunk_while { |left, right| glyphs[left].cluster == glyphs[right].cluster }
             .map { |cluster| [!spans && cluster.size == 1 && own[cluster.first], cluster] }
    end
  end

  Case = Data.define(:name, :lang, :text, :options)

  CASES = [
    Case.new("arabic", "ar", "فاتورة ضريبية", { align: :right }),
    Case.new("hebrew", "he", "שלום עולם", { align: :right }),
    Case.new("digits", "ar", "فاتورة رقم 2024 بقيمة", { align: :right }),
    Case.new("marks", "ar", "السَّلَامُ عَلَيْكُمْ", { align: :right }),
    # A space after the Arabic word would be shaped with it and drawn on its
    # left, before it: stretches are not reordered (see the README).
    Case.new("in-latin", "en", "Pay the فاتورة, please.", {}),
    Case.new("justified", "ar", "هذه فقرة طويلة مكتوبة باللغة العربية لتجربة ضبط السطور من اليمين إلى اليسار " \
                                "في مستند واحد يحتوي على أكثر من سطر", { align: :justify }),
    Case.new("wraps", "ar", "مرحبا بالعالم هذه فاتورة ضريبية جديدة من الشركة", { align: :right, size: 20 })
  ].freeze

  Extractor = Data.define(:name, :command)

  module_function

  def document(kase, fonts)
    Class.new(Stationery::Document) do
      page size: [298, 420], margin: 36
      metadata title: kase.name, lang: kase.lang
      shaper HarfBuzzShaper.new
      font_family "Arabic", regular: fonts.fetch(:arabic)
      font_family "Hebrew", regular: fonts.fetch(:hebrew)
      font_fallbacks "Arabic", "Hebrew"
      default_text font: { "ar" => "Arabic", "he" => "Hebrew" }.fetch(kase.lang, "Inter"), size: 14
      define_method(:view_template) { text kase.text, **kase.options }
    end
  end

  def extractors(options)
    [
      Extractor.new("poppler (pdftotext)", %w[pdftotext -enc UTF-8 %s -]),
      Extractor.new("MuPDF (mutool)", %w[mutool draw -q -F txt %s]),
      Extractor.new("PDFium (pypdfium2)", [options[:python], File.join(HERE, "pdfium.py"), "%s"]),
      Extractor.new("pdf.js (pdfjs-dist)", ["node", File.join(HERE, "pdfjs.mjs"), options[:pdfjs], "%s"]),
      Extractor.new("PDFKit (macOS)", ["swift", File.join(HERE, "pdfkit.swift"), "%s"])
    ].select { |extractor| runs?(extractor) }
  end

  def runs?(extractor)
    extractor.command.none?(&:nil?) && system("which", extractor.command.first, out: File::NULL, err: File::NULL)
  end

  def extract(extractor, path)
    out, status = Open3.capture2(*extractor.command.map { |part| part == "%s" ? path : part }, err: File::NULL)
    status.success? ? out.force_encoding(Encoding::UTF_8) : nil
  end

  def lines(text)
    text.unicode_normalize(:nfc).split(/[\n\f]+/).map { |line| line.squeeze(" ").strip }.reject(&:empty?)
  end

  # "as written", "reversed" (every line back to front), or what came out.
  def verdict(expected, text)
    return "failed" unless text

    found = lines(text)
    wanted = expected.unicode_normalize(:nfc)
    controls = found.join.match?(CONTROLS) ? ", with bidi controls" : ""
    found = found.map { |line| line.gsub(CONTROLS, "") }
    return "as written#{controls}" if found.join(" ") == wanted
    return "reversed#{controls}" if found.map(&:reverse).join(" ") == wanted

    "other#{controls}: `#{found.join(" ⏎ ")}`"
  end

  def render(options)
    FileUtils.mkdir_p(File.join(options[:out], "tagged"))
    %i[a b c].flat_map do |variant|
      Thread.current[:extraction_matrix_variant] = variant
      CASES.map do |kase|
        path = File.join(options[:out], "#{variant}-#{kase.name}.pdf")
        document(kase, options).new.to_pdf(path)
        document(kase, options).new.to_pdf(File.join(options[:out], "tagged", File.basename(path)),
                                           conformance: :pdf_ua1)
        [variant, kase, path]
      end
    end
  end

  def matrix(options)
    renders = render(options)
    readers = extractors(options)
    rows = renders.map do |variant, kase, path|
      inspector = Stationery::Testing::Inspector.new(File.binread(path)).text
      [variant.to_s.upcase, kase.name, verdict(kase.text, inspector)] +
        readers.map { |reader| verdict(kase.text, extract(reader, path)) }
    end
    names = ["Inspector"] + readers.map(&:name)
    [table(["Variant", "Case", *names], rows), table(["Variant", *names], scores(rows))].join("\n\n")
  end

  # The cases each reader returns as written, per variant.
  def scores(rows)
    rows.group_by(&:first).map do |variant, cases|
      [variant] + cases.map { |row| row.drop(2) }.transpose.map do |cells|
        "#{cells.count { |cell| cell.start_with?("as written") }} of #{cells.size}"
      end
    end
  end

  def table(names, rows)
    ["| #{names.join(" | ")} |", "|#{"---|" * names.size}", *rows.map { |row| "| #{row.join(" | ")} |" }].join("\n")
  end
end

Stationery::Fonts::ShapedRun.prepend(ExtractionMatrix::Variants)

if $PROGRAM_NAME == __FILE__
  options = { out: "tmp/extraction", python: nil, pdfjs: nil }
  OptionParser.new do |parser|
    parser.on("--arabic PATH") { |path| options[:arabic] = File.expand_path(path) }
    parser.on("--hebrew PATH") { |path| options[:hebrew] = File.expand_path(path) }
    parser.on("--out DIR") { |dir| options[:out] = File.expand_path(dir) }
    parser.on("--pdfjs DIR") { |dir| options[:pdfjs] = File.expand_path(dir) }
    parser.on("--python PATH") { |path| options[:python] = File.expand_path(path) }
  end.parse!
  abort "usage: see the head of #{__FILE__}" unless options[:arabic] && options[:hebrew]

  table = ExtractionMatrix.matrix(options)
  File.write(File.join(options[:out], "matrix.md"), "#{table}\n")
  puts table
end
