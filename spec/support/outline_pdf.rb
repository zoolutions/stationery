# frozen_string_literal: true

# A hand-written two-page PDF with a nested outline and internal links, for
# inspecting features the assembler does not write yet.
module OutlinePdf
  PDF = Stationery::PDF

  def outline_pdf
    writer = PDF::Writer.new
    tree = writer.reserve
    pages = [writer.reserve, writer.add({ Type: :Page, Parent: tree, MediaBox: [0, 0, 100, 100] })]
    writer.set(pages.first, first_page(writer, tree, pages.last))
    writer.set(tree, { Type: :Pages, Kids: pages, Count: 2 })
    root = writer.add({ Type: :Catalog, Pages: tree, Outlines: outlines(writer, pages.last) })
    writer.render(root:, info: writer.add({}))
  end

  private

  def first_page(writer, tree, target)
    links = [{ Dest: "totals" }, { Dest: [target, :Fit] }, { A: { S: :GoTo, D: "summary" } }]
    { Type: :Page, Parent: tree, MediaBox: [0, 0, 100, 100],
      Annots: links.map { |link| writer.add({ Type: :Annot, Subtype: :Link, Rect: [0, 0, 10, 10], **link }) } }
  end

  def outlines(writer, target)
    root, intro, detail, appendix = Array.new(4) { writer.reserve }
    writer.set(detail, { Title: PDF::TextString.new("Détails"), Parent: intro, Dest: [target, :Fit] })
    writer.set(intro, { Title: PDF::TextString.new("Intro"), Parent: root, Next: appendix,
                        First: detail, Last: detail })
    writer.set(appendix, { Title: PDF::TextString.new("Appendix"), Parent: root, Prev: intro })
    writer.set(root, { Type: :Outlines, First: intro, Last: appendix, Count: 3 })
  end
end

RSpec.configure { |config| config.include OutlinePdf }
