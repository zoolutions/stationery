# frozen_string_literal: true

module Stationery
  module Forms
    # A widget's normal appearance: the form XObject(s) every viewer draws, so
    # a form looks right without relying on the viewer to regenerate it.
    # Variable text sits between `/Tx BMC … EMC`, the part a viewer redraws
    # when the value changes.
    #
    # It is drawn when the widget is placed, so the glyphs it uses are in the
    # fonts before they are subset, and written as streams once the fonts
    # have their references (#streams).
    class Appearance
      PADDING = 2
      LEADING = 1.15
      # The check mark's corners in the unit square (y down) and its stroke.
      CHECK = { points: [[0.22, 0.52], [0.42, 0.72], [0.78, 0.28]], stroke: 0.12 }.freeze
      DOT = 0.45
      # What /DA and the appearance say when the value is black.
      BLACK = "0 g"
      SIGNATURE = { rule: 14, label_size: 7, label_baseline: 4, label_gray: 0.42 }.freeze

      # The size the value is drawn at: the field's, or what `font_size:
      # :auto` fits (see AutoSize).
      attr_reader :size

      # `resources` are the render's, where the field's fonts get their names.
      def initialize(field, width, height, resources = nil)
        @field = field
        @width = width
        @height = height
        @type = field.typeface.with(resources)
        @size = field.auto_size? ? AutoSize.new(field, @type, width, height).size : field.font_size
        @contents = contents
        keep
      end

      # Whether everything it draws with is embedded in the file.
      def embedded? = @type.names.empty? || @type.embedded?

      # The resource names of the fonts it draws with or keeps for editing.
      def font_names = @type.names

      # What the field's /DA says: the font, size (0 for auto) and colour a
      # viewer redraws the value with. nil for a field without variable text.
      def default_appearance
        return unless @field.variable_text?

        "/#{@type.name} #{@field.auto_size? ? 0 : num(size)} Tf #{text_color}"
      end

      # What it paints: its content streams and its /DA, for a check of the
      # colours they use (see PDF::Conformance).
      def paints = [*(@contents.is_a?(Hash) ? @contents.values : @contents), default_appearance].compact

      # One stream, or a Hash of streams by appearance state for buttons.
      # `fonts` are the references by resource name.
      def streams(fonts)
        resources = font_names.empty? ? {} : { Font: fonts.slice(*font_names) }
        return stream(@contents, resources) unless @contents.is_a?(Hash)

        @contents.transform_values { |content| stream(content, resources) }
      end

      private

      def options = @field.options
      def text_color = @field.color == Field::BLACK ? BLACK : @field.color.fill
      def num(value) = PDF::Serializer.number(value.is_a?(Float) && value == value.round ? value.round : value)

      def contents
        case @field.kind
        when :text, :select then frame + variable_text(text_lines)
        when :checkbox then { @field.on_state => frame + check, Off: frame }
        when :radio then { @field.on_state => circle + dot, Off: circle }
        when :signature then signature
        end
      end

      # What a viewer may draw after an edit: the other options of a select,
      # and the base repertoire of a field that can be typed into.
      def keep
        return unless @field.variable_text?

        @type.name
        return if options[:read_only]

        @type.keep(Array(options[:options]).join, size, repertoire: true)
      end

      def stream(content, resources)
        PDF::Stream.new(content, { Type: :XObject, Subtype: :Form, BBox: [0, 0, @width, @height],
                                   Resources: resources })
      end

      def frame
        return +"" unless options[:background] || options[:border]

        draw do |canvas|
          canvas.rounded_rect(0.5, 0.5, @width - 1, @height - 1,
                              radius: options[:radius], fill: options[:background], stroke: options[:border])
        end
      end

      def middle_baseline = (@height / 2.0) - ((@type.ascent(size) - @type.descent(size)) / 2)

      # [x, baseline, text] runs in PDF space.
      def text_lines
        return comb_cells if options[:comb]
        return multiline_runs if options[:multiline]

        value = @field.value.to_s
        [[start(value), middle_baseline, value]]
      end

      def multiline_runs
        top = @height - PADDING - @type.ascent(size)
        AutoSize.wrap(@type, @field.value.to_s, @width - (2 * PADDING), size).each_with_index.map do |line, index|
          [start(line), top - (index * size * LEADING), line]
        end
      end

      # Where a line starts: aligned within the box less its padding, as a
      # viewer does (PDF 32000-1, 12.7.3.3).
      def start(line)
        return PADDING if @field.align == :left

        PADDING + Geometry.align_offset(@field.align, @width - (2 * PADDING), @type.width(line, size))
      end

      def comb_cells
        cell = @width.fdiv(@field.max_length)
        @field.value.to_s[0, @field.max_length].chars.each_with_index.map do |char, index|
          [(index * cell) + ((cell - @type.width(char, size)) / 2), middle_baseline, char]
        end
      end

      def variable_text(runs)
        ops = ["/Tx BMC", "q", "1 1 #{num(@width - 2)} #{num(@height - 2)} re W n", text_color]
        runs.reject { |_, _, text| text.empty? }.each do |x, y, text|
          ops.push("BT", "#{num(x)} #{num(y)} Td", *@type.show(text, size), "ET")
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
        label = options[:label].to_s
        return content if label.empty?

        ops = ["q", "#{SIGNATURE[:label_gray]} g", "BT", "#{PADDING} #{SIGNATURE[:label_baseline]} Td",
               *@type.show(label, SIGNATURE[:label_size]), "ET", "Q"]
        "#{content}#{ops.join("\n")}\n"
      end

      def draw
        page = Page.new(size: [@width, @height])
        yield Canvas.new(page, nil)
        page.content
      end

      # A check mark stroked as a path, so no symbol font is needed.
      def check
        side = [@width, @height].min * 0.8
        left = (@width - side) / 2.0
        top = (@height - side) / 2.0
        first, *rest = CHECK[:points].map { |x, y| [left + (x * side), top + (y * side)] }
        draw do |canvas|
          canvas.path(stroke: "#000000", line_width: side * CHECK[:stroke], cap: :round, join: :round) do |path|
            path.move_to(*first)
            rest.each { |point| path.line_to(*point) }
          end
        end
      end
    end
  end
end
