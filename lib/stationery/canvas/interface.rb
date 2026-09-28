# frozen_string_literal: true

module Stationery
  class Canvas
    # What a layout node, the SVG renderer and a `canvas { |c| … }` block may
    # call on the canvas they paint on: every operation in top-left
    # coordinates and points (y grows downwards), colours as Color.parse
    # reads them, and nothing of the output's own format in what is handed
    # over or answered. Stationery::Canvas, the PDF canvas, is one canvas;
    # a canvas for another output includes this module and is made by the
    # render's canvases (see PDF::Canvases for what those answer).
    #
    # A canvas draws on one Page (`@page`), whose size it answers and whose
    # anchors and page-number slots it records. It implements what draws:
    #
    #   save { … }                        the block in a graphics state of its own
    #   transform(matrix) { … }           the block under [a, b, c, d, e, f]
    #   clip_to(paths, even_odd:) { … }   the block inside the paths, joined
    #   draw(path, fill:, stroke:, line_width:, cap:, join:, dash:, even_odd:, opacity:)
    #   shade_path(path, shading, matrix:, even_odd:, opacity:)
    #   image(image, x:, y:, width:, height:, opacity:)
    #   glyphs(run, x, y, font:, size:, color:, letter_spacing:, rise:, bold:, oblique:, opacity:)
    #
    # and takes the rest from here: the shapes and #text, which come down to
    # those, and what only some outputs have a use for (links, form fields,
    # tagging, artifacts), which does nothing here but run its block.
    module Interface
      include Text
      include Debug

      # The callable #tag_runs hands its block where nothing is marked.
      PASS = ->(_element = nil, &block) { block.call }

      # The render's collector (nil on a bare canvas), for what a node
      # notices only while painting, such as an oversized image.
      attr_reader :warnings

      def page_width = @page.width
      def page_height = @page.height

      # A path the block traces in top-left space, under `transform` when
      # given, for #clip_to.
      def outline(transform: nil, &)
        Stationery::Path.new(transform:).tap(&)
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

      # Paints the block inside the rectangle, its corners rounded by `radius`.
      def clip(x, y, w, h, radius: 0, &)
        clip_to([outline { |path| path.rounded_rect(x, y, w, h, radius) }], &)
      end

      def fill_rect(x, y, w, h, color:, opacity: nil)
        draw(outline { |path| path.rect(x, y, w, h) }, fill: color, opacity:)
      end

      def rounded_rect(x, y, w, h, radius:, fill: nil, stroke: nil, line_width: 1, dash: nil, opacity: nil)
        draw(outline { |path| path.rounded_rect(x, y, w, h, radius) }, fill:, stroke:, line_width:, dash:, opacity:)
      end

      def circle(cx, cy, r, fill: nil, stroke: nil, line_width: 1, opacity: nil)
        draw(outline { |path| path.ellipse(cx, cy, r, r) }, fill:, stroke:, line_width:, opacity:)
      end

      def line(x1, y1, x2, y2, color:, width: 1, dash: nil, cap: :butt, opacity: nil)
        segment = outline do |path|
          path.move_to(x1, y1)
          path.line_to(x2, y2)
        end
        draw(segment, stroke: color, line_width: width, dash:, cap:, opacity:)
      end

      # Fills and strokes the path the block traces (a Stationery::Path),
      # under `transform` when given. `cap:` is :butt, :round or :square,
      # `join:` :miter, :round or :bevel, `dash:` the lengths of dashes and
      # gaps in turn.
      def path(fill: nil, stroke: nil, line_width: 1, cap: :butt, join: :miter, dash: nil, even_odd: false,
               opacity: nil, transform: nil, &)
        draw(outline(transform:, &), fill:, stroke:, line_width:, cap:, join:, dash:, even_odd:, opacity:)
      end

      # Paints `shading` (a gradient: see SVG::Gradient::Fill) inside the
      # path the block traces. `matrix` maps the shading's coordinates into
      # top-left page space.
      def shade(shading, matrix:, transform: nil, even_odd: false, opacity: nil, &)
        shade_path(outline(transform:, &), shading, matrix:, even_odd:, opacity:)
      end

      # A clickable area opening `target`: a URL, or `#name` for an anchor in
      # this document. `tag:` is the Link element it belongs to when tagged.
      def link(_x, _y, _w, _h, _target, tag: nil) = nil # rubocop:disable Lint/UnusedMethodArgument

      # An interactive form field's widget (a Forms::Field) over the rectangle.
      def widget(_field, _x, _y, _w, _h, tag: nil) = nil # rubocop:disable Lint/UnusedMethodArgument

      # Names the point `y` on this page as a link target, and as what a
      # page-number slot counts to.
      def anchor(name, y)
        (@template ? @page.template_anchors : @page.anchors) << [name.to_s, num_value(@page.height - y)]
      end

      # Leaves room for the page number `anchor` lands on; Structure draws it
      # with #text once every page is painted, and adds the `link:` area
      # ([x, y, w, h]) when the anchor exists. `tags:` are the [link, number]
      # elements they belong to when tagged.
      def number_slot(anchor, x:, baseline:, width:, style:, link: nil, tags: nil)
        @page.slots << Page::Slot.new(anchor.to_s, x, baseline, width, style, link, tags)
      end

      def tagging? = false

      # Paints the block as the content of `element` (a Tagging::Element, or
      # nil for an artifact), `bbox` being its [x, y, w, h].
      def tag(_element, bbox: nil) = yield # rubocop:disable Lint/UnusedMethodArgument

      # Hands the block a callable, `mark.(element) { … }`, that paints its
      # block as the content of `element`, or of `parent` without one.
      def tag_runs(_parent) = yield PASS

      # Opens `element` as the parent of the elements painted in the block.
      def structure(_element) = yield

      # Paints the block as content that is not part of the document's
      # structure. `type:` is :pagination, :layout or :page, `subtype:`
      # :header, :footer or :watermark.
      def artifact(type: nil, subtype: nil) = yield # rubocop:disable Lint/UnusedMethodArgument

      private

      def num_value(value)
        value.is_a?(Float) && value == value.round ? value.round : value
      end
    end
  end
end
