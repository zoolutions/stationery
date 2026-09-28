# frozen_string_literal: true

module Stationery
  # The PDF canvas: draws on one page in top-left coordinates (points, y
  # grows downwards) by writing operators to the page's content. Every
  # operation is wrapped in its own graphics state so colours and line
  # settings never leak into the next one. What may be called on it is
  # Canvas::Interface; `page` and `num` are the PDF canvas's own.
  class Canvas
    include Interface
    include Glyphs
    include Marking

    CAPS = { butt: 0, round: 1, square: 2 }.freeze
    JOINS = { miter: 0, round: 1, bevel: 2 }.freeze

    attr_reader :page

    # `template: true` records anchors apart, for canvases page templates draw on.
    # `tagging:` (a Tagging::Tree) marks content for a tagged PDF.
    def initialize(page, resources, template: false, debug: false, tagging: nil, warnings: nil)
      @page = page
      @resources = resources
      @template = template
      @debug = debug
      @tagging = tagging
      @warnings = warnings
      @marked = 0
      @artifact = @surfaced = nil
    end

    def save
      emit("q")
      yield self
      emit("Q")
    end

    # Paints the block with the affine `matrix` [a, b, c, d, e, f] applied,
    # given in top-left space (x' = ax + cy + e, y' = bx + dy + f with y
    # growing downwards). Annotations (`link`, `widget`) keep their
    # untransformed page rectangles.
    def transform(matrix)
      a, b, c, d, e, f = matrix
      height = @page.height
      pdf_matrix = [a, -b, -c, d, (c * height) + e, height - (d * height) - f]
      save do
        emit("#{pdf_matrix.map { |v| num(v) }.join(" ")} cm")
        yield self
      end
    end

    def clip(x, y, w, h, radius: 0)
      save do
        emit(Path.new(self).rounded_rect(x, y, w, h, radius).to_s, "W n")
        yield self
      end
    end

    # A path the block traces in top-left space, under `transform` when given,
    # for #clip_to.
    def outline(transform: nil, &)
      Path.new(self, transform:).tap(&)
    end

    # Paints the block inside `outlines` (see #outline), joined into one
    # clipping path under the nonzero rule or, with `even_odd:`, the even-odd
    # one. Without a path to clip to, nothing is inside and the block is skipped.
    def clip_to(outlines, even_odd: false)
      paths = outlines.map(&:to_s).reject(&:empty?)
      return if paths.empty?

      save do
        emit(*paths, even_odd ? "W* n" : "W n")
        yield self
      end
    end

    # Fills and strokes `path`, a path of this canvas (see #outline).
    def draw(path, fill: nil, stroke: nil, line_width: 1, cap: nil, join: nil, dash: nil, even_odd: false,
             opacity: nil)
      graphics(opacity:) do |ops|
        ops << Color.parse(fill).fill if fill
        ops << Color.parse(stroke).stroke if stroke
        ops.concat(line_style(stroke, line_width, cap, join, dash))
        ops << path.to_s << paint_operator(fill, stroke, even_odd)
      end
    end

    # Paints `shading` inside `path`: a gradient (SVG::Gradient::Fill), or a
    # shading dictionary as it is written to the file.
    def shade_path(path, shading, matrix:, even_odd: false, opacity: nil)
      shading = SVG::Shading.dictionary(shading.gradient, shading.coords, shading.current) unless shading.is_a?(Hash)
      name = @page.use(:Shading, @resources.shading(shading))
      a, b, c, d, e, f = matrix
      graphics(opacity:) do |ops|
        ops << path.to_s << (even_odd ? "W* n" : "W n")
        ops << "#{[a, -b, c, -d, e, @page.height - f].map { |v| num(v) }.join(" ")} cm" << "/#{name} sh"
      end
    end

    def image(image, x:, y:, width:, height:, opacity: nil)
      name = @page.use(:XObject, @resources.image(image))
      graphics(opacity:) do |ops|
        ops << "#{num(width)} 0 0 #{num(height)} #{num(x)} #{num(@page.height - y - height)} cm"
        ops << "/#{name} Do"
      end
    end

    # A clickable area opening `target`: a URL, or `#name` for an anchor in
    # this document. Annotation rectangles live in absolute, untransformed
    # page space, so they ignore clips and path transforms. `tag:` is the
    # Link element the annotation belongs to in a tagged PDF; an annotation
    # that joins none is remembered as outside the tree (Tagging::Tree#audit).
    def link(x, y, w, h, target, tag: nil)
      target = target.to_s
      rect = [x, @page.height - y - h, x + w, @page.height - y].map { |v| num_value(v) }
      annotation = target.start_with?("#") ? { rect:, dest: target[1..] } : { rect:, url: target }
      @page.annotations << annotation
      own(annotation, tag) if tag
      disown(annotation, target, tag) if @tagging && !annotation.key?(:tag)
    end

    # An interactive form field's widget (a Forms::Field) over the rectangle.
    # Its appearance is drawn here, so the glyphs it needs are in the fonts
    # before they are embedded.
    def widget(field, x, y, w, h, tag: nil)
      rect = [x, @page.height - y - h, x + w, @page.height - y].map { |v| num_value(v) }
      annotation = { rect:, widget: field, appearance: Forms::Appearance.new(field, w, h, @resources) }
      @page.annotations << annotation
      adopt(annotation, tag, rect) if tag
    end

    def num(value) = PDF::Serializer.number(num_value(value))

    private

    def line_style(stroke, width, cap, join, dash)
      return [] unless stroke

      ops = ["#{num(width)} w"]
      ops << "[#{dash.map { |v| num(v) }.join(" ")}] 0 d" if dash
      ops << "#{CAPS.fetch(cap)} J" if cap && cap != :butt
      ops << "#{JOINS.fetch(join)} j" if join && join != :miter
      ops
    end

    def paint_operator(fill, stroke, even_odd)
      if fill && stroke then even_odd ? "B*" : "B"
      elsif fill then even_odd ? "f*" : "f"
      elsif stroke then "S"
      else "n"
      end
    end

    def graphics(opacity: nil)
      ops = []
      ops << "/#{@page.use(:ExtGState, @resources.opacity(opacity))} gs" if opacity && opacity < 1
      yield ops
      artifact { emit("q", *ops, "Q") }
    end

    def emit(*ops)
      @page.content << ops.join("\n") << "\n"
    end
  end
end
