# frozen_string_literal: true

module Stationery
  # Interactive form fields (AcroForm): what each one holds and how it is
  # written, apart from where the layout puts it.
  module Forms
    # One form field widget: its kind, full (dotted) name, value and options.
    # Widgets sharing a name form one field (a radio group); dotted names are
    # grouped under parent fields.
    class Field
      TYPES = { text: :Tx, checkbox: :Btn, radio: :Btn, select: :Ch, signature: :Sig }.freeze
      # Field flag bit positions (PDF 32000-1, 12.7.3.1 and 12.7.4).
      BITS = { read_only: 1, required: 2, multiline: 13, no_toggle_to_off: 15, radio: 16, combo: 18, edit: 19,
               comb: 25 }.freeze
      DEFAULTS = { font_size: 10, read_only: false, required: false, border: "#9CA3AF", background: "#FFFFFF",
                   radius: 2 }.freeze
      OPTIONS = {
        text: %i[multiline max_length comb], checkbox: [], radio: %i[checked], select: %i[options editable],
        signature: %i[label]
      }.freeze
      FONT = "Helv"

      attr_reader :kind, :name, :value, :options

      def initialize(kind, name, value: nil, **options)
        @kind = kind
        @name = validate_name(name.to_s)
        @value = value
        unknown = options.keys - DEFAULTS.keys - OPTIONS.fetch(kind)
        raise ArgumentError, "unknown #{kind} field option: #{unknown.join(", ")}" if unknown.any?

        @options = DEFAULTS.merge(options)
        validate_comb
      end

      def segments = @name.split(".")
      def type = TYPES.fetch(@kind)
      def font_size = @options[:font_size]
      def default_appearance = "/#{FONT} #{PDF::Serializer.number(font_size)} Tf 0 g"
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
      def field_entries(value = field_value)
        entries = { FT: type, DA: default_appearance }
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

      # `state` overrides the button's own appearance state.
      def widget_entries(width, height, fonts, state: nil)
        normal = Appearance.new(self, width, height, fonts).normal
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
    end
  end
end
