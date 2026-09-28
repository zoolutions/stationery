# frozen_string_literal: true

module Stationery
  module SVG
    # The rectangle a symbol or a nested svg draws into, and how its viewBox
    # is fitted there by `preserveAspectRatio`. Lengths may be percentages of
    # the viewport around it (`parent`, [width, height]); without a size it
    # fills that viewport. A symbol sits at the origin of its `use`
    # (`origin: false`), a nested svg at its own x and y.
    class Viewport
      ALIGNMENT = /\Ax(Min|Mid|Max)Y(Min|Mid|Max)(?:\s+(meet|slice))?\z/
      FRACTIONS = { "Min" => 0.0, "Mid" => 0.5, "Max" => 1.0 }.freeze

      attr_reader :x, :y, :width, :height

      def initialize(attributes, parent, origin: true)
        @x = origin ? length(attributes["x"], parent[0], 0) : 0
        @y = origin ? length(attributes["y"], parent[1], 0) : 0
        @width = length(attributes["width"], parent[0], parent[0])
        @height = length(attributes["height"], parent[1], parent[1])
        @view_box = read_view_box(attributes["viewBox"])
        @aspect = attributes["preserveAspectRatio"].to_s.strip
      end

      def drawable?
        @width.positive? && @height.positive? && (@view_box.nil? || @view_box.last(2).all?(&:positive?))
      end

      # The size percentages inside resolve against.
      def size = @view_box ? @view_box.last(2) : [@width, @height]

      # Content space to the user space the viewport sits in.
      def matrix
        return [1, 0, 0, 1, @x, @y] unless @view_box

        vx, vy, vw, vh = @view_box
        sx, sy = scales(@width.fdiv(vw), @height.fdiv(vh))
        align_x, align_y = alignment
        [sx, 0, 0, sy, @x + (align_x * (@width - (vw * sx))) - (vx * sx),
         @y + (align_y * (@height - (vh * sy))) - (vy * sy)].map { |value| tidy(value) }
      end

      # Traces the viewport's rectangle, for clipping what overflows it.
      def trace(path) = path.rounded_rect(@x, @y, @width, @height, 0)

      private

      def scales(horizontal, vertical)
        return [horizontal, vertical] if @aspect == "none"

        scale = slice? ? [horizontal, vertical].max : [horizontal, vertical].min
        [scale, scale]
      end

      def slice? = @aspect.match(ALIGNMENT)&.[](3) == "slice"

      # The share of the spare room put before the content on each axis.
      def alignment
        match = @aspect.match(ALIGNMENT)
        match ? [FRACTIONS.fetch(match[1]), FRACTIONS.fetch(match[2])] : [0.5, 0.5]
      end

      def read_view_box(source)
        values = source.to_s.split(/[\s,]+/).reject(&:empty?).map { |value| tidy(value.to_f) }
        values if values.size == 4
      end

      def length(value, reference, default)
        value = value.to_s.strip
        return default if value.empty?

        tidy(value.end_with?("%") ? value.to_f * reference / 100 : value.to_f)
      end

      def tidy(value) = value == value.round ? value.round : value
    end
  end
end
