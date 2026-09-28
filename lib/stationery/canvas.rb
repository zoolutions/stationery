# frozen_string_literal: true

module Stationery
  # Draws on one page in top-left coordinates (points, y grows downwards).
  # Every operation is wrapped in its own graphics state so colours and line
  # settings never leak into the next one.
  class Canvas
    include Text
    include Debug
    include Marking

    CAPS = { butt: 0, round: 1, square: 2 }.freeze
    JOINS = { miter: 0, round: 1, bevel: 2 }.freeze

    # `warnings` is the render's collector (nil on a bare canvas), for what a
    # node notices only while painting, such as an oversized image.
    attr_reader :page, :warnings

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

    # Paints the block rotated `degrees` clockwise around the page point
    # `around` ([x, y]), as CSS `rotate()` turns an element. Zero just yields.
    def rotate(degrees, around:, &)
      return yield self if degrees.zero?

      radians = degrees * Math::PI / 180
      cos = Math.cos(radians)
      sin = Math.sin(radians)
      cx, cy = around
      transform([cos, sin, -sin, cos, cx - (cx * cos) + (cy * sin), cy - (cx * sin) - (cy * cos)], &)
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

    def fill_rect(x, y, w, h, color:, opacity: nil)
      shape(fill: color, opacity:) { |p| p.rect(x, y, w, h) }
    end

    def rounded_rect(x, y, w, h, radius:, fill: nil, stroke: nil, line_width: 1, dash: nil, opacity: nil)
      shape(fill:, stroke:, line_width:, dash:, opacity:) { |p| p.rounded_rect(x, y, w, h, radius) }
    end

    def circle(cx, cy, r, fill: nil, stroke: nil, line_width: 1, opacity: nil)
      shape(fill:, stroke:, line_width:, opacity:) { |p| p.ellipse(cx, cy, r, r) }
    end

    def line(x1, y1, x2, y2, color:, width: 1, dash: nil, cap: :butt, opacity: nil)
      shape(stroke: color, line_width: width, dash:, cap:, opacity:) do |p|
        p.move_to(x1, y1)
        p.line_to(x2, y2)
      end
    end

    def path(fill: nil, stroke: nil, line_width: 1, cap: :butt, join: :miter, dash: nil, even_odd: false,
             opacity: nil, transform: nil, &)
      shape(fill:, stroke:, line_width:, cap:, join:, dash:, even_odd:, opacity:, transform:, &)
    end

    # Paints `shading` inside the path the block traces. `matrix` maps the
    # shading's coordinates into top-left page space.
    def shade(shading, matrix:, transform: nil, even_odd: false, opacity: nil)
      path = Path.new(self, transform:)
      yield path
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
    # Link element the annotation belongs to in a tagged PDF.
    def link(x, y, w, h, target, tag: nil)
      target = target.to_s
      rect = [x, @page.height - y - h, x + w, @page.height - y].map { |v| num_value(v) }
      annotation = target.start_with?("#") ? { rect:, dest: target[1..] } : { rect:, url: target }
      @page.annotations << annotation
      own(annotation, tag) if tag
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

    # Names the point `y` on this page as a link target.
    def anchor(name, y)
      (@template ? @page.template_anchors : @page.anchors) << [name.to_s, num_value(@page.height - y)]
    end

    # Leaves room for the page number `anchor` lands on; Structure fills it in
    # and adds the `link:` area ([x, y, w, h]) when the anchor exists. `tags:`
    # are the [link, number] elements they belong to in a tagged PDF.
    def number_slot(anchor, x:, baseline:, width:, style:, link: nil, tags: nil)
      @page.slots << Page::Slot.new(anchor.to_s, x, baseline, width, style, link, tags)
    end

    def num(value) = PDF::Serializer.number(num_value(value))

    private

    def num_value(value)
      value.is_a?(Float) && value == value.round ? value.round : value
    end

    def shape(fill: nil, stroke: nil, line_width: 1, cap: nil, join: nil, dash: nil, even_odd: false,
              opacity: nil, transform: nil)
      path = Path.new(self, transform:)
      yield path
      graphics(opacity:) do |ops|
        ops << Color.parse(fill).fill if fill
        ops << Color.parse(stroke).stroke if stroke
        ops.concat(line_style(stroke, line_width, cap, join, dash))
        ops << path.to_s << paint_operator(fill, stroke, even_odd)
      end
    end

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
