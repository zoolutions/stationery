# frozen_string_literal: true

module Stationery
  # Interactive form fields (AcroForm): what each one holds and how it is
  # written, apart from where the layout puts it.
  module Forms
    # One form field widget: its kind, full (dotted) name, value and options.
    # Dotted names are grouped under parent fields.
    class Field
      TYPES = { text: :Tx, checkbox: :Btn }.freeze
      # Field flag bit positions (PDF 32000-1, 12.7.3.1 and 12.7.4).
      BITS = { read_only: 1, required: 2, multiline: 13, comb: 25 }.freeze
      DEFAULTS = { font_size: 10, read_only: false, required: false, border: "#9CA3AF", background: "#FFFFFF",
                   radius: 2 }.freeze
      OPTIONS = { text: %i[multiline max_length comb], checkbox: [] }.freeze
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
      def checked? = @value == true

      # The on-state of a button.
      def on_state = :Yes

      def flags
        set = %i[read_only required].select { |key| @options[key] }
        set += %i[multiline comb].select { |key| @options[key] } if @kind == :text
        set.sum { |key| 1 << (BITS.fetch(key) - 1) }
      end

      # The field-level entries; the widget's come from #widget_entries.
      def field_entries
        entries = { FT: type, DA: default_appearance }
        entries[:Ff] = flags if flags.positive?
        entries[:V] = field_value
        entries[:MaxLen] = max_length if max_length
        entries
      end

      # What Document#fields reports for this field.
      def data_value = @kind == :checkbox ? checked? : @value

      def widget_entries(width, height, fonts)
        normal = Appearance.new(self, width, height, fonts).normal
        entries = { Type: :Annot, Subtype: :Widget, F: 4, MK: appearance_characteristics, AP: { N: normal } }
        entries[:AS] = checked? ? on_state : :Off if normal.is_a?(Hash)
        entries
      end

      private

      def field_value
        return checked? ? on_state : :Off if @kind == :checkbox

        PDF::TextString.new(@value.to_s)
      end

      def appearance_characteristics
        mk = {}
        mk[:BG] = Color.parse(@options[:background]).components if @options[:background]
        mk[:BC] = Color.parse(@options[:border]).components if @options[:border]
        mk[:CA] = "4" if @kind == :checkbox
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
