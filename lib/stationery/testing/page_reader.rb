# frozen_string_literal: true

module Stationery
  module Testing
    # A pdf-reader receiver that collects what a page draws: its text as
    # runs of one font and size on one baseline, and its images with the
    # rectangles they fill, both in points from the top-left corner of the
    # media box. A form drawn on the page is read as part of it.
    #
    # A run starts where its first glyph is shown; `y` is its baseline. A
    # sequence with ActualText reads as that text, from its first glyph.
    class PageReader
      STATE = %i[save_graphics_state restore_graphics_state concatenate_matrix begin_text_object end_text_object
                 set_text_font_and_size move_text_position move_text_position_and_set_leading
                 set_text_matrix_and_text_line_matrix move_to_start_of_next_line set_text_leading
                 set_character_spacing set_word_spacing set_text_rise set_horizontal_text_scaling
                 set_text_rendering_mode].freeze
      UTF16_BOM = "\xFE\xFF".b
      SUBSET = /\A[A-Z]{6}\+/
      # A gap wider than this share of the size is a space between words;
      # one wider than the size itself starts a new run.
      SPACE = 0.2
      APART = 1.0

      Glyph = Struct.new(:x, :y, :width, :font_size, :font, :text)

      def self.read(page) = new(page).tap { |receiver| page.walk(receiver) }

      STATE.each do |operator|
        define_method(operator) { |*operands| @state.public_send(operator, *operands) }
      end

      def initialize(page)
        @page = page
        @state = ::PDF::Reader::PageState.new(page)
        @left, _, _, @top = page.rectangles[:MediaBox].to_a
        @glyphs = []
        @images = []
        @fonts = {}
      end

      # [{ x:, y:, font:, size:, text: }, …] top to bottom, left to right.
      def text
        runs = @glyphs.each_with_object([]) { |glyph, found| extend_run(found, glyph) }
        found = runs.reject { |run| run.text.strip.empty? }.map { |run| line(run) }
        found.sort_by { |run| [run[:y], run[:x]] }
      end

      # [{ x:, y:, width:, height:, pixels: [w, h] }, …] in the order drawn.
      attr_reader :images

      def show_text(string) = show([string])
      def show_text_with_positioning(params) = show(params)

      def move_to_next_line_and_show_text(string)
        @state.move_to_start_of_next_line
        show([string])
      end

      def set_spacing_next_line_show_text(word_spacing, character_spacing, string)
        @state.set_word_spacing(word_spacing)
        @state.set_character_spacing(character_spacing)
        move_to_next_line_and_show_text(string)
      end

      def begin_marked_content_with_pl(_tag, properties)
        @actual = decode(properties[:ActualText]) if properties.is_a?(Hash) && properties[:ActualText]
      end

      def end_marked_content = @actual = nil

      def invoke_xobject(label)
        @state.invoke_xobject(label) do |xobject|
          if xobject.is_a?(::PDF::Reader::FormXObject)
            xobject.walk(self)
          elsif xobject.hash[:Subtype] == :Image
            @images << image(xobject.hash)
          end
        end
      end

      private

      def show(params)
        font = @state.current_font
        params.each do |param|
          next @state.process_glyph_displacement(0, param, false) if param.is_a?(Numeric)
          next unless param.is_a?(String)

          font.unpack(param).each { |code| glyph(font, code) }
        end
      end

      def glyph(font, code)
        text = font.to_utf8(code)
        if @actual
          text = @actual
          @actual = ""
        end
        x, y = @state.trm_transform(0, 0)
        size = @state.font_size
        @state.process_glyph_displacement(font.glyph_width_in_text_space(code), 0, text == " ")
        # The advance, with the character spacing: letter-spaced text reads as words.
        advance = @state.trm_transform(0, 0).first - x
        @glyphs << Glyph.new(x - @left, @top - y, advance, size, name(font), text) unless text == " "
      end

      def extend_run(runs, glyph)
        last = runs.last
        gap = last && (glyph.x - (last.x + last.width))
        return runs << glyph.dup unless last && same_line?(last, glyph) && gap.abs < APART * glyph.font_size

        last.text = gap > SPACE * glyph.font_size ? "#{last.text} #{glyph.text}" : "#{last.text}#{glyph.text}"
        last.width = glyph.x + glyph.width - last.x
      end

      def line(run)
        { x: round(run.x), y: round(run.y), font: run.font, size: round(run.font_size), text: run.text }
      end

      def same_line?(run, glyph)
        (run.y - glyph.y).abs < 0.01 && run.font == glyph.font && (run.font_size - glyph.font_size).abs < 0.01
      end

      def image(hash)
        corners = [[0, 0], [1, 0], [0, 1], [1, 1]].map do |u, v|
          @state.ctm_transform_point(::PDF::Reader::Point.new(u, v))
        end
        xs = corners.map(&:x)
        ys = corners.map(&:y)
        { x: round(xs.min - @left), y: round(@top - ys.max), width: round(xs.max - xs.min),
          height: round(ys.max - ys.min), pixels: [hash[:Width], hash[:Height]] }
      end

      def name(font) = @fonts[font] ||= font.basefont.to_s.sub(SUBSET, "")

      def round(value) = value.to_f.round(1)

      def decode(text)
        return text.dup.force_encoding(Encoding::UTF_8) unless text.b.start_with?(UTF16_BOM)

        text.b.byteslice(2..).force_encoding(Encoding::UTF_16BE).encode(Encoding::UTF_8)
      end
    end
  end
end
