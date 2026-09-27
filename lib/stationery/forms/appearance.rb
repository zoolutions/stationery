# frozen_string_literal: true

module Stationery
  module Forms
    # A widget's normal appearance: the form XObject(s) every viewer draws, so
    # a form looks right without relying on the viewer to regenerate it.
    # Variable text sits between `/Tx BMC … EMC`, the part a viewer redraws
    # when the value changes.
    class Appearance
      PADDING = 2
      LEADING = 1.15
      CHECK = { glyph: "4", width: 0.846, middle: 0.345 }.freeze
      DOT = 0.45
      SIGNATURE = { rule: 14, label_size: 7, label_baseline: 4, label_gray: 0.42 }.freeze

      def initialize(field, width, height, fonts)
        @field = field
        @width = width
        @height = height
        @fonts = fonts
      end

      # One stream, or a Hash of streams by appearance state for buttons.
      def normal
        case @field.kind
        when :text, :select then stream(frame + variable_text(text_lines))
        when :checkbox then { @field.on_state => stream(frame + check), Off: stream(frame) }
        when :radio then { @field.on_state => stream(circle + dot), Off: stream(circle) }
        when :signature then stream(signature)
        end
      end

      private

      def options = @field.options
      def size = @field.font_size
      def num(value) = PDF::Serializer.number(value.is_a?(Float) && value == value.round ? value.round : value)

      def stream(content)
        PDF::Stream.new(content, { Type: :XObject, Subtype: :Form, BBox: [0, 0, @width, @height],
                                   Resources: { Font: @fonts } })
      end

      def frame
        return +"" unless options[:background] || options[:border]

        draw do |canvas|
          canvas.rounded_rect(0.5, 0.5, @width - 1, @height - 1,
                              radius: options[:radius], fill: options[:background], stroke: options[:border])
        end
      end

      # [x, baseline, WinAnsi bytes] runs in PDF space.
      def text_lines
        return comb_cells if options[:comb]
        return multiline_runs if options[:multiline]

        [[PADDING, (@height / 2.0) - (size * (Metrics::ASCENT + Metrics::DESCENT) / 2), Metrics.encode(@field.value)]]
      end

      def multiline_runs
        top = @height - PADDING - (size * Metrics::ASCENT)
        Metrics.wrap(@field.value, @width - (2 * PADDING), size).each_with_index.map do |line, index|
          [PADDING, top - (index * size * LEADING), line]
        end
      end

      def comb_cells
        cell = @width.fdiv(@field.max_length)
        baseline = (@height / 2.0) - (size * (Metrics::ASCENT + Metrics::DESCENT) / 2)
        Metrics.encode(@field.value)[0, @field.max_length].chars.each_with_index.map do |char, index|
          [(index * cell) + ((cell - Metrics.width(char, size)) / 2), baseline, char]
        end
      end

      def variable_text(runs)
        ops = ["/Tx BMC", "q", "1 1 #{num(@width - 2)} #{num(@height - 2)} re W n", "0 g"]
        runs.reject { |_, _, bytes| bytes.empty? }.each do |x, y, bytes|
          ops.push("BT", "/#{Field::FONT} #{num(size)} Tf", "#{num(x)} #{num(y)} Td",
                   "#{PDF::Serializer.literal(bytes)} Tj", "ET")
        end
        ops.push("Q", "EMC").join("\n") << "\n"
      end

      def circle
        draw { |canvas| canvas.circle(*center, radius - 0.5, fill: options[:background], stroke: options[:border]) }
      end

      def dot = draw { |canvas| canvas.circle(*center, radius * DOT, fill: "#000000") }
      def center = [@width / 2.0, @height / 2.0]
      def radius = [@width, @height].min / 2.0

      def signature
        y = @height - SIGNATURE[:rule]
        content = draw { |canvas| canvas.line(PADDING, y, @width - PADDING, y, color: options[:border], width: 0.75) }
        label = Metrics.encode(options[:label])
        return content if label.empty?

        ops = ["q", "#{SIGNATURE[:label_gray]} g", "BT", "/#{Field::FONT} #{SIGNATURE[:label_size]} Tf",
               "#{PADDING} #{SIGNATURE[:label_baseline]} Td", "#{PDF::Serializer.literal(label)} Tj", "ET", "Q"]
        "#{content}#{ops.join("\n")}\n"
      end

      def draw
        page = Page.new(size: [@width, @height])
        yield Canvas.new(page, nil)
        page.content
      end

      def check
        glyph = [@width, @height].min * 0.8
        x = (@width - (glyph * CHECK[:width])) / 2
        y = (@height / 2.0) - (glyph * CHECK[:middle])
        ["q", "0 g", "BT", "/ZaDb #{num(glyph)} Tf", "#{num(x)} #{num(y)} Td", "(#{CHECK[:glyph]}) Tj", "ET", "Q"]
          .join("\n") << "\n"
      end
    end
  end
end
