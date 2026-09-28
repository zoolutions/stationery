# frozen_string_literal: true

require_relative "../css"

module Stationery
  module HTML
    # The CSS the html element reads: `<style>` rules (element, class and id
    # selectors) and inline `style` attributes, for a small set of properties
    # that map onto the element DSL (`float` on an `img` only, which the
    # `align` attribute also sets). Everything else is ignored and reported
    # once per document through the Report. Values are never fetched or
    # evaluated: `url()` and `@import` are dropped like any unknown value.
    class Css
      # What a document's CSS asked for and did not get: property names, or
      # `property: value` for a known property with a value not read, and
      # selectors with combinators.
      class Report
        attr_reader :properties, :selectors

        def initialize
          @properties = []
          @selectors = []
        end

        def property(name)
          @properties << name unless @properties.include?(name)
          nil
        end

        def select(text)
          @selectors << text unless @selectors.include?(text)
        end

        def any? = @properties.any? || @selectors.any?
      end

      # Properties read on text (inherited by everything inside the element).
      INLINE = %w[color font-size font-weight font-style text-decoration].freeze
      # Properties read on the block an element becomes.
      BLOCK = %w[text-align background-color margin margin-top margin-bottom padding padding-top padding-right
                 padding-bottom padding-left border width page-break-before page-break-after break-before
                 break-after page-break-inside break-inside column-count column-gap columns].freeze
      FONT_SIZES = { "1" => 0.625, "2" => 0.8125, "3" => 1.0, "4" => 1.125, "5" => 1.5, "6" => 2.0,
                     "7" => 3.0 }.freeze
      KEYWORD_SIZES = { "xx-small" => 0.5625, "x-small" => 0.625, "small" => 0.8125, "medium" => 1.0,
                        "large" => 1.125, "x-large" => 1.5, "xx-large" => 2.0, "smaller" => 0.8333,
                        "larger" => 1.2 }.freeze
      NAMED_COLORS = {
        "black" => "#000000", "white" => "#FFFFFF", "red" => "#FF0000", "green" => "#008000",
        "blue" => "#0000FF", "yellow" => "#FFFF00", "cyan" => "#00FFFF", "aqua" => "#00FFFF",
        "magenta" => "#FF00FF", "fuchsia" => "#FF00FF", "gray" => "#808080", "grey" => "#808080",
        "silver" => "#C0C0C0", "maroon" => "#800000", "olive" => "#808000", "lime" => "#00FF00",
        "teal" => "#008080", "navy" => "#000080", "purple" => "#800080", "orange" => "#FFA500",
        "pink" => "#FFC0CB", "brown" => "#A52A2A", "gold" => "#FFD700", "darkgray" => "#A9A9A9",
        "darkgrey" => "#A9A9A9", "lightgray" => "#D3D3D3", "lightgrey" => "#D3D3D3", "darkred" => "#8B0000",
        "darkgreen" => "#006400", "darkblue" => "#00008B", "crimson" => "#DC143C", "coral" => "#FF7F50",
        "salmon" => "#FA8072", "tomato" => "#FF6347", "indigo" => "#4B0082", "violet" => "#EE82EE",
        "turquoise" => "#40E0D0", "beige" => "#F5F5DC", "ivory" => "#FFFFF0", "khaki" => "#F0E68C",
        "tan" => "#D2B48C"
      }.freeze
      HEX = /\A#(\h{3}|\h{6})\z/
      RGB = /\Argba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*[\d.]+\s*)?\)\z/i
      LENGTH = /\A(-?\d*\.?\d+)(px|pt|em|rem|%)?\z/
      ALIGN = %w[left center right justify].freeze
      FLOAT = %w[left right].freeze
      BREAK_PAGE = %w[always page left right].freeze
      CSS_PX = 0.75
      LEGACY = %w[font center].freeze
      NOTHING = [{}.freeze, {}.freeze].freeze

      def self.parse(sheets, report = Report.new) = new(CSS::Stylesheet.parse(sheets.join("\n")), report)

      attr_reader :report

      def initialize(sheet, report)
        @sheet = sheet
        @report = report
        sheet.unsupported.each { |selector| report.select(selector) }
      end

      # The declarations that apply to `element`: legacy attributes, then the
      # stylesheet by specificity, then its inline style.
      def declarations(element)
        legacy(element).merge(@sheet.declarations(element), CSS.declarations(element.attributes["style"]))
      end

      # [marks, block]: the text marks the element's content inherits and the
      # options its block takes.
      def resolve(element)
        return NOTHING if plain?(element)

        marks = {}
        block = {}
        declarations(element).each do |name, value|
          value = value.strip
          next if value.empty?

          if INLINE.include?(name) then inline(name, value, marks)
          elsif BLOCK.include?(name) then block(name, value, block)
          elsif name == "float" && element.name == "img" then read(name, value, block, :float) { float(value) }
          else report.property(name)
          end
        end
        [marks, block]
      end

      private

      # Nothing to read: no rules, no inline style, no legacy attributes.
      def plain?(element)
        @sheet.empty? && !element.attributes.key?("style") && !LEGACY.include?(element.name) &&
          !(element.name == "img" && element.attributes.key?("align"))
      end

      def legacy(element)
        case element.name
        when "font" then font_attributes(element.attributes)
        when "center" then { "text-align" => "center" }
        when "img" then image_attributes(element.attributes)
        else {}
        end
      end

      # `align="left"` and `align="right"` float an image; the vertical
      # alignments are not read.
      def image_attributes(attributes)
        side = attributes["align"].to_s.strip.downcase
        FLOAT.include?(side) ? { "float" => side } : {}
      end

      def font_attributes(attributes)
        legacy = {}
        legacy["color"] = attributes["color"] if attributes["color"]
        legacy["font-size"] = "#{FONT_SIZES.fetch(attributes["size"].to_s.strip, 1.0)}em" if attributes["size"]
        legacy
      end

      def inline(name, value, marks)
        case name
        when "color" then read(name, value, marks, :color) { color(value) }
        when "font-size" then font_size(value, marks)
        when "font-weight" then read(name, value, marks, :bold) { weight(value) }
        when "font-style" then read(name, value, marks, :italic) { style(value) }
        when "text-decoration" then decoration(value, marks)
        end
      end

      def block(name, value, block)
        case name
        when "text-align" then read(name, value, block, :align) { align(value) }
        when "background-color" then read(name, value, block, :background) { color(value) }
        when "margin" then read(name, value, block, :margin) { box(value) }
        when "padding" then read(name, value, block, :padding) { box(value) }
        when /\A(margin|padding)-/ then read(name, value, block, name.tr("-", "_").to_sym) { points(value) }
        when "border" then read(name, value, block, :border) { border(value) }
        when "width" then read(name, value, block, :width) { width(value) }
        when "page-break-before", "break-before" then read(name, value, block, :break_before) { page_break(value) }
        when "page-break-after", "break-after" then read(name, value, block, :break_after) { page_break(value) }
        when "page-break-inside", "break-inside" then read(name, value, block, :keep_together) { avoid(value) }
        when "column-count", "columns" then read(name, value, block, :columns) { column_count(value) }
        when "column-gap" then read(name, value, block, :column_gap) { column_gap(value) }
        end
      end

      # Stores what the block yields for `key`, or reports `name: value` when
      # the value is not one the property reads. `:none` is read and means
      # "nothing" (a transparent background, no page break): it takes back
      # what a less specific rule set.
      def read(name, value, into, key)
        result = yield
        return report.property("#{name}: #{value}") if result.nil?

        result == :none ? into.delete(key) : into[key] = result
      end

      def color(value)
        return :none if value.casecmp?("transparent")
        return NAMED_COLORS[value.downcase] if NAMED_COLORS.key?(value.downcase)
        return value.upcase if value.match?(HEX)

        red, green, blue = value.match(RGB)&.captures&.map { |part| part.to_i.clamp(0, 255) }
        format("#%<red>02X%<green>02X%<blue>02X", red:, green:, blue:) if red
      end

      def align(value) = ALIGN.include?(value.downcase) ? value.downcase.to_sym : nil

      def float(value)
        return :none if value.casecmp?("none")

        FLOAT.include?(value.downcase) ? value.downcase.to_sym : nil
      end

      def font_size(value, marks)
        scale = KEYWORD_SIZES[value.downcase]
        match = value.match(LENGTH)
        return report.property("font-size: #{value}") unless scale || match

        marks.delete(:size)
        marks.delete(:scale)
        number = match && match[1].to_f
        case match && match[2]
        when nil then scale ? marks[:scale] = scale : marks[:size] = number * CSS_PX
        when "em", "rem" then marks[:scale] = number
        when "%" then marks[:scale] = number / 100
        when "pt" then marks[:size] = number
        when "px" then marks[:size] = number * CSS_PX
        end
      end

      def weight(value)
        case value.downcase
        when "bold", "bolder" then true
        when "normal", "lighter" then false
        when /\A\d{3}\z/ then value.to_i >= 600
        end
      end

      def style(value)
        case value.downcase
        when "italic", "oblique" then true
        when "normal" then false
        end
      end

      def decoration(value, marks)
        words = value.downcase.split
        unless words.all? { |word| %w[none underline line-through].include?(word) }
          return report.property("text-decoration: #{value}")
        end

        marks[:underline] = words.include?("underline")
        marks[:strike] = words.include?("line-through")
      end

      # A length in points: px (at 0.75 pt), pt, or a bare 0.
      def points(value)
        match = value.match(LENGTH)
        return nil unless match
        return 0.0 if match[1].to_f.zero?

        case match[2]
        when "pt" then match[1].to_f
        when "px", nil then match[1].to_f * CSS_PX
        end
      end

      # One to four lengths as [top, right, bottom, left].
      def box(value)
        sides = value.split.map { |part| points(part) }
        return nil if sides.empty? || sides.size > 4 || sides.any?(&:nil?)

        top, right, bottom, left = sides
        [top, right || top, bottom || top, left || right || top]
      end

      # `1px solid #ccc` in any order; `none` and `0` mean no border.
      def border(value)
        parts = value.split
        return { width: 0 } if [["none"], ["0"]].include?(parts)

        width = parts.filter_map { |part| points(part) }.first
        colour = parts.filter_map { |part| color(part) }.grep(String).first
        return nil if width.nil? && colour.nil?

        { width: width || 0.75, color: colour || "#000000" }
      end

      # Points, or a fraction of the available width for a percentage.
      def width(value)
        return :none if value.casecmp?("auto")

        match = value.match(LENGTH)
        number = match && match[1].to_f
        return nil unless number&.positive?

        case match[2]
        when "%" then [number / 100.0, 1.0].min
        when "pt" then number
        when "px", nil then number * CSS_PX
        end
      end

      def page_break(value)
        return true if BREAK_PAGE.include?(value.downcase)

        :none if %w[auto avoid].include?(value.downcase)
      end

      def avoid(value)
        return true if %w[avoid avoid-page].include?(value.downcase)

        :none if value.casecmp?("auto")
      end

      # A number of columns; a column width (`columns: 12em`) is not read.
      def column_count(value)
        return :none if value.casecmp?("auto")

        count = Integer(value, 10, exception: false)
        count if count&.positive?
      end

      def column_gap(value)
        return :none if value.casecmp?("normal")

        gap = points(value)
        gap unless gap&.negative?
      end
    end
  end
end
