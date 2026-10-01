# frozen_string_literal: true

module Stationery
  # Interactive form fields (AcroForm): what each one holds and how it is
  # written, apart from where the layout puts it.
  module Forms
    # One form field widget: its kind, full (dotted) name, value and options.
    # Widgets sharing a name form one field (a radio group); dotted names are
    # grouped under parent fields. `typeface:` is what its appearance is set
    # in: the document's fonts from the element DSL, the standard Helvetica
    # otherwise. `tooltip:` is its accessible name (/TU), the name by default.
    class Field
      TYPES = { text: :Tx, checkbox: :Btn, radio: :Btn, select: :Ch, signature: :Sig }.freeze
      # Field flag bit positions (PDF 32000-1, 12.7.3.1 and 12.7.4).
      BITS = { read_only: 1, required: 2, multiline: 13, no_toggle_to_off: 15, radio: 16, combo: 18, edit: 19,
               comb: 25 }.freeze
      DEFAULTS = { font_size: 10, read_only: false, required: false, border: "#9CA3AF", background: "#FFFFFF",
                   radius: 2, tooltip: nil }.freeze
      # What a text field and a select take beyond the defaults: where the
      # value sits, its colour, and the bounds of `font_size: :auto`.
      BOUNDS = %i[min_font_size max_font_size].freeze
      STYLE = [:align, :color, *BOUNDS].freeze
      OPTIONS = {
        text: [:multiline, :max_length, :comb, *STYLE], checkbox: [], radio: %i[checked],
        select: [:options, :editable, *STYLE], signature: %i[label]
      }.freeze
      VARIABLE_TEXT = %i[text select].freeze
      # The /Q (quadding) of each `align:` (PDF 32000-1, 12.7.3.3).
      ALIGNMENTS = { left: 0, center: 1, right: 2 }.freeze
      BLACK = Color.parse("#000000")

      attr_reader :kind, :name, :value, :options, :typeface, :color

      def initialize(kind, name, value: nil, typeface: Standard.new, **options)
        @kind = kind
        @name = validate_name(name.to_s)
        @value = value
        @typeface = typeface
        unknown = options.keys - DEFAULTS.keys - OPTIONS.fetch(kind)
        raise ArgumentError, "unknown #{kind} field option: #{unknown.join(", ")}" if unknown.any?

        @options = DEFAULTS.merge(options)
        @color = Color.parse(@options.fetch(:color, BLACK))
        validate_comb
        validate_style
      end

      # A copy with `changes` to its options.
      def with(**changes)
        self.class.new(@kind, @name, value: @value, typeface: @typeface, **@options, **changes)
      end

      def segments = @name.split(".")
      def type = TYPES.fetch(@kind)
      def font_size = @options[:font_size]
      # Whether the value is drawn at the largest size that fits (`font_size: :auto`).
      def auto_size? = font_size == :auto
      def min_font_size = @options[:min_font_size]
      def max_font_size = @options[:max_font_size]
      def align = @options.fetch(:align, :left)
      # Whether a viewer redraws its text when the value changes.
      def variable_text? = VARIABLE_TEXT.include?(@kind)
      # The accessible name: `tooltip:`, a signature's label, else the name.
      def tooltip = (@options[:tooltip] || @options[:label]).to_s.strip.then { |text| text.empty? ? @name : text }
      def max_length = @options[:comb].is_a?(Integer) ? @options[:comb] : @options[:max_length]
      def radio? = @kind == :radio
      def checked? = radio? ? @options[:checked] == true : @value == true

      # The on-state of a button: /Yes, or a radio's export value.
      def on_state = radio? ? @value.to_s.to_sym : :Yes

      def flags
        set = %i[read_only required].select { |key| @options[key] }
        set += kind_flags
        set.sum { |key| 1 << (BITS.fetch(key) - 1) }
      end

      # The field-level entries; the widget's come from #widget_entries.
      # `value` overrides this widget's own: a radio group's checked choice.
      # `default_appearance` is the /DA of a field with variable text.
      def field_entries(value = field_value, default_appearance: nil)
        entries = { FT: type, TU: PDF::TextString.new(tooltip) }
        entries[:DA] = default_appearance if default_appearance
        entries[:Q] = ALIGNMENTS.fetch(align) unless align == :left
        entries[:Ff] = flags if flags.positive?
        entries[:V] = value unless value.nil?
        entries[:MaxLen] = max_length if max_length
        entries[:Opt] = @options[:options].map { |option| PDF::TextString.new(option.to_s) } if @kind == :select
        entries
      end

      # What Document#fields reports for this field.
      def data_value
        case @kind
        when :checkbox then checked?
        when :radio then checked? ? @value : nil
        else @value
        end
      end

      # `appearance` is the widget's Appearance and `fonts` the references by
      # resource name; `state` overrides the button's own appearance state.
      def widget_entries(appearance, fonts, state: nil)
        normal = appearance.streams(fonts)
        entries = { Type: :Annot, Subtype: :Widget, F: 4, AP: { N: normal } }
        entries[:MK] = appearance_characteristics unless @kind == :signature
        entries[:AS] = state || (checked? ? on_state : :Off) if normal.is_a?(Hash)
        entries
      end

      private

      def field_value
        case @kind
        when :checkbox, :radio then checked? ? on_state : :Off
        when :signature then nil
        else @value.nil? ? nil : PDF::TextString.new(@value.to_s)
        end
      end

      def kind_flags
        case @kind
        when :text then %i[multiline comb].select { |key| @options[key] }
        when :radio then %i[radio no_toggle_to_off]
        when :select then @options[:editable] ? %i[combo edit] : %i[combo]
        else []
        end
      end

      def appearance_characteristics
        mk = {}
        mk[:BG] = Color.parse(@options[:background]).components if @options[:background]
        mk[:BC] = Color.parse(@options[:border]).components if @options[:border]
        mk[:CA] = radio? ? "l" : "4" if type == :Btn
        mk
      end

      def validate_name(name)
        return name unless name.empty? || name.split(".", -1).any?(&:empty?)

        raise ArgumentError, "invalid field name #{name.inspect}: use non-empty, dot-separated segments"
      end

      def validate_comb
        return unless @options[:comb] && !max_length

        raise ArgumentError, "a comb field needs max_length: (or comb: <cells>)"
      end

      def validate_style
        raise ArgumentError, "align: is :left, :center or :right, not #{align.inspect}" unless ALIGNMENTS.key?(align)

        points(:font_size, " or :auto") unless auto_size?
        BOUNDS.each do |key|
          next unless @options.key?(key)
          raise ArgumentError, "#{key}: needs font_size: :auto" unless auto_size?

          points(key)
        end
        return unless min_font_size && max_font_size && min_font_size > max_font_size

        raise ArgumentError, "min_font_size: #{min_font_size} is above max_font_size: #{max_font_size}"
      end

      def points(key, alternative = "")
        value = @options[key]
        return if value.is_a?(Numeric) && value.positive?

        raise ArgumentError, "#{key}: is a number of points#{alternative}, not #{value.inspect}"
      end
    end
  end
end
