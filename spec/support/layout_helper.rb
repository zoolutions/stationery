# frozen_string_literal: true

module LayoutHelper
  L = Stationery::Layout

  def ctx
    @ctx ||= L::Context.new(book: open_sans_book, style: base_style)
  end

  def text_node(source, **)
    L::Text.new(Stationery::Text::Markup.parse(source, base_style), context: ctx, **)
  end

  def spacer(height) = L::Spacer.new(height)
  def flow(*children, **) = L::Flow.new(children, **)

  def lines_of(count, prefix: "line")
    text_node(Array.new(count) { |i| "#{prefix} #{i + 1}" }.join("\n"))
  end

  # Paginates `root` onto pages of `size` and returns [pdf, paginator].
  def render_layout(root, size: [300, 200], margin: 20)
    resources = Stationery::Resources.new
    paginator = L::Paginator.new(resources:, page: { size:, margin: })
    pages = paginator.paginate(root)
    [Stationery::PDF::Assembler.new(pages:, resources:).render, paginator]
  end

  def line_height(size = 10)
    open_sans_book.resolve(base_style(size:)).first.line_height(size)
  end
end

RSpec.configure { |config| config.include LayoutHelper }
