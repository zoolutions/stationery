# frozen_string_literal: true

module Stationery
  # Interactive form fields. Each takes a name (dotted names group fields,
  # "address.city") and lays out like a box, or at a fixed page position with
  # `at: [x, y]`.
  module Elements
    # A text input. `width:` is :full or points; `multiline:`, `max_length:`,
    # `comb:` (a cell count, or true with max_length:), `read_only:`,
    # `required:`, `font_size:`, `border:`, `background:` and `radius:`.
    def text_field(name, value: "", width: :full, height: 22, at: nil, **)
      field_node(Forms::Field.new(:text, name, value: value.to_s, **), width:, height:, at:)
    end

    # A check box `size` points square, with an optional label to its right.
    def checkbox(name, checked: false, size: 12, label: nil, at: nil, **)
      field = Forms::Field.new(:checkbox, name, value: checked == true, **)
      field_node(field, width: size, height: size, at:, label:)
    end

    private

    def field_node(field, width:, height:, at:, label: nil)
      label &&= field_label(label)
      node = Layout::Field.new(field, height:, width:, label:)
      @_builder.add(at ? Layout::Positioned.new(node, x: at[0], y: at[1]) : node)
    end

    def field_label(label)
      style = @_builder.style
      Layout::Text.new([Text::Run.new(label.to_s, style)], context: @_builder.context(style))
    end
  end
end
