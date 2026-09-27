# frozen_string_literal: true

module Stationery
  # Draws on one page in top-left coordinates (points, y grows downwards).
  # Every operation is wrapped in its own graphics state so colours and line
  # settings never leak into the next one.
  class Canvas
    include Text

    CAPS = { butt: 0, round: 1, square: 2 }.freeze
    JOINS = { miter: 0, round: 1, bevel: 2 }.freeze

    attr_reader :page

    def initialize(page, resources)
      @page = page
      @resources = resources
    end

    def save
      emit("q")
      yield self
      emit("Q")
    end

    def clip(x, y, w, h, radius: 0)
      save do
        emit(Path.new(self).rounded_rect(x, y, w, h, radius).to_s, "W n")
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

    def image(image, x:, y:, width:, height:, opacity: nil)
      name = @page.use(:XObject, @resources.image(image))
      graphics(opacity:) do |ops|
        ops << "#{num(width)} 0 0 #{num(height)} #{num(x)} #{num(@page.height - y - height)} cm"
        ops << "/#{name} Do"
      end
    end

    # A clickable area opening `url`. Annotation rectangles live in absolute,
    # untransformed page space, so they ignore clips and path transforms.
    def link(x, y, w, h, url)
      @page.annotations << { rect: [x, @page.height - y - h, x + w, @page.height - y].map { |v| num_value(v) },
                             url: url.to_s }
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
      emit("q", *ops, "Q")
    end

    def emit(*ops)
      @page.content << ops.join("\n") << "\n"
    end
  end
end
