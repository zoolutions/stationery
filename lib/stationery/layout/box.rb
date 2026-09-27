# frozen_string_literal: true

module Stationery
  module Layout
    # A container with padding, background, border and corner radius. A box
    # moves to the next page whole when it fits there and continues across
    # pages when it does not (`break_inside: :auto` splits at any break,
    # `:avoid` never). A fragment's cut sides are `open`: `decoration: :slice`
    # drops their padding and border, `:clone` keeps the padding. A
    # fixed-height box can truncate or shrink text that does not fit
    # (`overflow:`) and never splits. `min_height:` is a floor that does split:
    # the first fragment keeps as much of it as the page holds and the next
    # one carries only what is left of it. `rotate:` turns the painted box
    # around its centre without moving its layout rectangle (a rotated box
    # never splits); `shadow:` paints a soft drop shadow under it, taking no
    # space; `overflow: :hidden` clips the content to the rounded outline.
    class Box < Node
      BORDER = { width: 1, color: "#000000", sides: %i[top right bottom left] }.freeze
      SHADOW = { offset: [0, 4], blur: 8, color: "#000000", opacity: 0.15 }.freeze
      SHADOW_LAYERS = 8

      attr_reader :content, :width_spec

      def initialize(content = Flow.new, padding: 0, background: nil, border: nil, radius: 0, width: nil,
                     height: nil, min_height: nil, overflow: :visible, valign: :top, opacity: nil, link: nil, outset: 0,
                     open: [], decoration: :slice, role: nil, rotate: 0, shadow: nil)
        raise ArgumentError, "pass height: or min_height:, not both" if height && min_height

        super()
        @tag = role && Tagging::Element.new(Tagging.role(role))
        @min_height = min_height
        @open = open
        @decoration = decoration
        @link = link
        @link_tag = link && Tagging::Element.new(:Link)
        @outset = Geometry.box(outset)
        @content = content
        @padding = Geometry.box(padding)
        @background = background
        @border = border && BORDER.merge(border)
        @radius = radius
        @width_spec = width
        @height = height
        @overflow = overflow
        @valign = valign
        @opacity = opacity
        @rotate = rotate
        @shadow = shadow && SHADOW.merge(shadow == true ? {} : shadow)
      end

      def natural_width
        @width_spec.is_a?(Numeric) && @width_spec > 1 ? @width_spec : @content.natural_width + horizontal
      end

      def min_width = @content.min_width + horizontal

      def fixed_width(available)
        case @width_spec
        when :auto then [natural_width, available].min
        when Float then @width_spec <= 1 ? available * @width_spec : @width_spec
        when Numeric then @width_spec
        end
      end

      def splittable?
        @height.nil? && @rotate.zero? && %i[visible hidden].include?(@overflow) && @content.splittable?
      end

      def prefer_whole? = break_inside.nil? && splittable?

      def split(width, height, fresh: false)
        return [self, nil] if measure(width) <= height + EPSILON

        cut = @open | [:bottom]
        available = height - vertical(cut)
        head, tail = @content.split(inner_width(width), available, fresh:)
        return [nil, self] unless head
        return [with_content(head), nil] unless tail || @min_height.to_f > height + EPSILON

        fragments(width, height, head, tail || Flow.new, cut)
      end

      # An empty continuation: open at the top, without a floor.
      def continued = fragment(Flow.new, @open | [:top], nil)

      # A copy holding other content and open sides, every option kept.
      def with_content(content, open = @open) = dup.reopen(content, open)
      def with_open(*sides) = with_content(@content, @open | sides)

      def measure(width)
        @height || memoize_by_width(width) { [@content.measure(inner_width(width)) + vertical, @min_height || 0].max }
      end

      def paint(canvas, x, y, width, height = nil, valign: nil, debug_kind: :box, **)
        height ||= measure(width)
        canvas.rotate(@rotate, around: [x + (width / 2.0), y + (height / 2.0)]) do
          canvas.structure(@tag) do
            canvas.structure(@link_tag) do
              paint_shadow(canvas, x, y, width, height)
              paint_background(canvas, x, y, width, height)
              paint_border(canvas, x, y, width, height)
              paint_content(canvas, x, y, width, height, valign || @valign)
            end
          end
          paint_debug(canvas, Rect.new(x, y, width, height), debug_kind) if canvas.debug?
        end
        canvas.link(x, y, width, height, @link, tag: @link_tag) if @link
      end

      protected

      def reopen(content, open, min_height = @min_height)
        @content = content
        @open = open
        @min_height = min_height
        self
      end

      private

      def fragment(content, open, min_height) = dup.reopen(content, open, min_height)

      def fragments(width, height, head, tail, cut)
        first = fragment(head, cut, @min_height && [@min_height, height].min).tap { |part| part.keep_with_next = nil }
        rest = @min_height.to_f - first.measure(width)
        [first, fragment(tail, @open | [:top], rest.positive? ? rest : nil)]
      end

      def insets(open = @open)
        border = @border ? @border[:width] : 0
        sides = @border ? @border[:sides] - open : []
        Geometry::SIDES.keys.zip(@padding).map do |side, padding|
          (open.include?(side) && @decoration == :slice ? 0 : padding) + (sides.include?(side) ? border : 0)
        end
      end

      def horizontal = insets[1] + insets[3]
      def vertical(open = @open) = insets(open).values_at(0, 2).sum
      def inner_width(width) = [width - horizontal, 0].max

      # Stacked rounded rectangles under the box, the outermost grown by the
      # blur and each fainter, so the centre sums to the opacity and the edge
      # fades. An artifact: decoration, not content. Skipped on a fragment
      # with cut sides, whose corners are square anyway.
      def paint_shadow(canvas, x, y, width, height)
        return unless @shadow && @open.empty?

        blur = @shadow[:blur].to_f
        layers = blur.positive? ? [(blur / 2).ceil, SHADOW_LAYERS].min : 1
        dx, dy = @shadow[:offset]
        canvas.artifact do
          layers.downto(1) do |layer|
            grow = blur * layer / layers
            canvas.rounded_rect(x + dx - grow, y + dy - grow, width + (2 * grow), height + (2 * grow),
                                radius: grown_radius(grow), fill: @shadow[:color], opacity: @shadow[:opacity] / layers)
          end
        end
      end

      def grown_radius(grow) = @radius.is_a?(Array) ? @radius.map { |r| r + grow } : @radius + grow

      # The outset paints the background past the box's own edges (a band that
      # bleeds into the page margins) without moving the content.
      def paint_background(canvas, x, y, width, height)
        return unless @background

        top, right, bottom, left = @outset.each_with_index.map { |v, i| open?(i) ? 0 : v }
        area = Rect.new(x - left, y - top, width + left + right, height + top + bottom)
        cut(canvas, area, area) do |shape|
          canvas.rounded_rect(*shape.to_h.values, radius: @radius, fill: @background, opacity: @opacity)
        end
      end

      def paint_border(canvas, x, y, width, height)
        return unless @border

        stroke = @border[:width]
        area = Rect.new(x, y, width, height)
        if @border[:sides].size == 4 && @radius.positive?
          half = stroke / 2.0
          cut(canvas, area, area.inset(half, half, half, half)) do |shape|
            canvas.rounded_rect(*shape.to_h.values, radius: @radius, stroke: @border[:color], line_width: stroke)
          end
        else
          (@border[:sides] - @open).each { |side| border_side(canvas, side, area, stroke) }
        end
      end

      def open?(index) = @open.include?(Geometry::SIDES.key(index))

      # Cut edges are square: the rounded shape runs past them by its radius
      # and stroke, clipped to the fragment.
      def cut(canvas, area, shape)
        return yield(shape) if @open.empty? || !@radius.positive?

        reach = @radius + (@border ? @border[:width] : 0)
        top = @open.include?(:top) ? reach : 0
        bottom = @open.include?(:bottom) ? reach : 0
        canvas.clip(area.x, area.y, area.width, area.height) do
          yield Rect.new(shape.x, shape.y - top, shape.width, shape.height + top + bottom)
        end
      end

      def border_side(canvas, side, rect, stroke)
        half = stroke / 2.0
        x1, y1, x2, y2 = case side
                         when :top then [rect.x, rect.y + half, rect.right, rect.y + half]
                         when :bottom then [rect.x, rect.bottom - half, rect.right, rect.bottom - half]
                         when :left then [rect.x + half, rect.y, rect.x + half, rect.bottom]
                         else [rect.right - half, rect.y, rect.right - half, rect.bottom]
                         end
        canvas.line(x1, y1, x2, y2, color: @border[:color], width: stroke)
      end

      def paint_content(canvas, x, y, width, height, valign)
        top, _right, _bottom, left = insets
        inner = Rect.new(x, y, width, height).inset(*insets)
        content = fitted(inner)
        used = content.measure(inner.width)
        offset = Geometry.align_offset(if valign == :middle
                                         :center
                                       else
                                         (valign == :bottom ? :right : :left)
                                       end,
                                       inner.height, used)
        paint_inner = -> { content.paint(canvas, x + left, y + top + [offset, 0].max, inner.width) }
        clip_outline(canvas, Rect.new(x, y, width, height)) do
          if @overflow == :visible || (@overflow == :hidden && @height.nil?)
            paint_inner.call
          else
            canvas.clip(inner.x, inner.y, inner.width, inner.height) do
              paint_inner.call
            end
          end
        end
      end

      # `overflow: :hidden` keeps the content inside the rounded outline; cut
      # sides stay square like the background's.
      def clip_outline(canvas, area, &)
        return yield unless @overflow == :hidden && @radius.positive?

        cut(canvas, area, area) do |shape|
          canvas.clip(shape.x, shape.y, shape.width, shape.height, radius: @radius, &)
        end
      end

      def paint_debug(canvas, rect, kind)
        canvas.debug_rect(rect.x, rect.y, rect.width, rect.height, kind)
        return if insets.all?(&:zero?)

        inner = rect.inset(*insets)
        canvas.debug_rect(inner.x, inner.y, inner.width, inner.height, :padding)
      end

      def fitted(inner)
        return @content if @overflow == :visible || @height.nil? || @content.measure(inner.width) <= inner.height
        return shrunk(inner) if @overflow == :shrink_to_fit && shrinkable?

        @content.split(inner.width, inner.height).first || Flow.new
      end

      def shrinkable?
        @content.is_a?(Flow) && @content.children.size == 1 && @content.children.first.respond_to?(:fit)
      end

      def shrunk(inner)
        @content.with_children([@content.children.first.fit(inner.width, inner.height, overflow: :shrink_to_fit)])
      end
    end
  end
end
