# frozen_string_literal: true

module Stationery
  module SVG
    # Lays out a <text> element: its strings and tspans become pieces along
    # the baseline, a new chunk starting wherever x or y is set, and each
    # chunk is shifted by its text-anchor. Glyphs are drawn upright at the
    # transformed origin, sized by the transform's uniform scale, so rotated,
    # skewed or unevenly scaled text is approximated.
    class Text
      ANCHORS = { "middle" => 0.5, "end" => 1.0 }.freeze
      DEFAULT_SIZE = 16

      Piece = Data.define(:runs, :style, :x, :y, :chunk, :advance)

      def initialize(canvas, painter, book, family)
        @canvas = canvas
        @painter = painter
        @book = book
        @family = family
      end

      def draw(element, style)
        @pieces = []
        @x = @y = @chunk = 0
        @space = true
        place(element, style)
        trim
        @pieces.group_by(&:chunk).each_value { |chunk| draw_chunk(chunk) }
      end

      private

      def place(element, style)
        move(element.attributes)
        element.children.each do |child|
          if child.is_a?(String) then add(child, style)
          elsif child.name == "tspan" then place(child, style.child(child.attributes))
          end
        end
      end

      def move(attributes)
        x, y, dx, dy = attributes.values_at("x", "y", "dx", "dy").map { |value| first(value) }
        @chunk += 1 if x || y
        @x = (x || @x) + (dx || 0)
        @y = (y || @y) + (dy || 0)
      end

      def first(value) = value.to_s.split(/[\s,]+/).find { |part| !part.empty? }&.to_f

      # Collapses the space between pieces and at the start of the text.
      def add(string, style)
        string = string.lstrip if @space
        return if string.empty?

        @space = string.end_with?(" ")
        @pieces << piece(string, style, @x, @y)
        @x += @pieces.last.advance
      end

      def piece(string, style, x, y, chunk = @chunk)
        italic = style.values["font-style"].to_s.match?(/italic|oblique/)
        text_style = Stationery::Text::Style.new(family: family(style), size: size(style), weight: weight(style),
                                                 style: italic ? :italic : :normal)
        runs = @book.fallback([Stationery::Text::Run.new(string, text_style)])
        advance = runs.sum { |run| font(run).width_of(run.text, text_style.size) }
        Piece.new(runs, style, x, y, chunk, advance)
      end

      def trim
        last = @pieces.last or return
        text = last.runs.map(&:text).join
        return unless text.end_with?(" ")

        @pieces[-1] = piece(text.rstrip, last.style, last.x, last.y, last.chunk)
      end

      def draw_chunk(pieces)
        width = pieces.last.x + pieces.last.advance - pieces.first.x
        shift = -width * ANCHORS.fetch(pieces.first.style.values["text-anchor"].to_s, 0)
        pieces.each { |piece| draw_piece(piece, shift) }
      end

      def draw_piece(piece, shift)
        color = @painter.color(piece.style.fill, piece.style)
        return unless color

        x = piece.x + shift
        scale = Transform.scale(piece.style.matrix)
        piece.runs.each do |run|
          font, face = @book.resolve(run.style)
          page_x, page_y = Transform.apply(piece.style.matrix, x, piece.y)
          @canvas.text(run.text, x: page_x, y: page_y, font:, size: run.style.size * scale, color:,
                                 opacity: Painter.translucent(piece.style.opacity),
                                 synthetic_bold: face.synthetic_bold, synthetic_oblique: face.synthetic_oblique)
          x += font.width_of(run.text, run.style.size)
        end
      end

      def font(run) = @book.resolve(run.style).first

      # The first family of the list the book knows, else the document's.
      def family(style)
        names = style.values["font-family"].to_s.split(",").map { |name| name.strip.delete("'\"") }
        names.find { |name| !name.empty? && @book.known?(name) } || @family
      end

      def size(style)
        size = style.values["font-size"].to_f
        size.positive? ? size : DEFAULT_SIZE
      end

      def weight(style)
        value = style.values["font-weight"].to_s.strip
        return value.to_i if value.match?(/\A\d+\z/)

        %w[bold bolder].include?(value) ? :bold : :regular
      end
    end
  end
end
