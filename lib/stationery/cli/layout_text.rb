# frozen_string_literal: true

module Stationery
  class CLI
    # The text `stationery inspect` prints for a Testing::Inspector#layout:
    # what the file says of itself, the outline, then each page with its
    # text lines, images, links and fields (x and y from the top-left corner
    # in points, y of a text line its baseline), the structure tree and the
    # warnings. A section with nothing in it is left out.
    class LayoutText
      INDENT = "  "
      # Text in the structure tree is cut to this many characters.
      EXCERPT = 60

      def initialize(layout)
        @layout = layout
      end

      def lines(name)
        [name, *about, *outline, *@layout[:pages].flat_map { |page| page(page) }, *structure, *warnings]
      end

      private

      def about
        rows = [["pages", @layout[:pages].size], *@layout[:metadata].map { |key, value| [key, list(value)] }]
        rows << ["conformance", list(@layout[:conformance])] if @layout[:conformance].any?
        rows << %w[tagged yes] if @layout[:tagged]
        rows << ["print", pairs(@layout[:print])] if @layout[:print].any?
        @layout[:attachments].each { |file| rows << ["attachment", attachment(file)] }
        @layout[:signatures].each { |signature| rows << ["signature", signature_text(signature)] }
        width = rows.map { |key, _| key.to_s.size }.max
        rows.map { |key, value| "#{INDENT}#{key.to_s.ljust(width)}  #{value}" }
      end

      def outline
        entries = outline_lines(@layout[:outline], 1)
        entries.empty? ? [] : ["", "Outline", *entries]
      end

      def outline_lines(entries, depth)
        entries.flat_map do |entry|
          where = entry[:page] ? "  page #{entry[:page]}" : ""
          ["#{INDENT * depth}#{entry[:title]}#{where}", *outline_lines(entry[:children], depth + 1)]
        end
      end

      def page(page)
        label = page[:label] ? " (#{page[:label]})" : ""
        ["", "Page #{page[:number]}#{label}  #{number(page[:width])} x #{number(page[:height])} pt",
         *section("Text (x, baseline y, font, size, text)", page[:text]) { |line| text_line(line) },
         *section("Images (x, y, width x height, pixels)", page[:images]) do |image|
           "#{box(image)}  #{image[:pixels].join(" x ")} px"
         end,
         *section("Links (x, y, width x height, target)", page[:links]) { |link| "#{box(link)}  #{target(link)}" },
         *section("Fields (x, y, width x height, name, type, value, alignment, size, colour)", page[:fields]) do |field|
           "#{box(field)}  #{field_text(field)}"
         end]
      end

      def section(title, items, &)
        items.empty? ? [] : ["#{INDENT}#{title}", *items.map { |item| "#{INDENT * 2}#{yield item}" }]
      end

      def text_line(line)
        size = number(line[:size]).rjust(4)
        "#{column(line[:x])} #{column(line[:y])}  #{line[:font].ljust(font_width)} #{size}  #{line[:text]}"
      end

      def font_width
        @font_width ||= @layout[:pages].flat_map { |page| page[:text].map { |line| line[:font].size } }.max.to_i
      end

      def box(item) = "#{column(item[:x])} #{column(item[:y])}  #{number(item[:width])} x #{number(item[:height])}"

      def column(value) = format("%6.1f", value)

      def target(link)
        return link[:uri] if link[:uri]
        return "##{link[:name]}" if link[:name]

        link[:top] ? "page #{link[:page]} at #{number(link[:top])}" : "page #{link[:page]}"
      end

      def field_text(field)
        value = field[:value].is_a?(Array) ? field[:value].inspect : field[:value]&.inspect
        [field[:name], field[:type], field[:state] && "on: #{field[:state]}", value, *style(field)].compact.join("  ")
      end

      # What is not the default of a field's alignment, size and colour.
      def style(field)
        return [] unless field.key?(:align)

        size = field[:font_size]
        [field[:align] == :left ? nil : field[:align],
         if size == :auto then "auto"
         elsif size != Forms::Field::DEFAULTS[:font_size] then "#{number(size)} pt"
         end,
         field[:color] == "#000000" ? nil : field[:color]]
      end

      def structure
        return [] if @layout[:structure].empty?

        ["", "Structure", *@layout[:structure].flat_map { |element| element_lines(element, 1) }]
      end

      def element_lines(element, depth)
        return ["#{INDENT * depth}#{excerpt(element)}"] if element.is_a?(String)

        type, content = element
        return ["#{INDENT * depth}#{type} #{excerpt(content)}"] if content.is_a?(String)

        ["#{INDENT * depth}#{type}", *Array(content).flat_map { |kid| element_lines(kid, depth + 1) }]
      end

      def excerpt(text)
        text = text.gsub(/\s+/, " ")
        text.size > EXCERPT ? "#{text[0, EXCERPT - 1]}…".inspect : text.inspect
      end

      def warnings
        return [] if @layout[:warnings].empty?

        ["", "Warnings", *@layout[:warnings].map { |message| "#{INDENT}#{message}" }]
      end

      def attachment(file)
        details = [file[:mime], "#{file[:bytes]} bytes", file[:relationship]].compact.join(", ")
        "#{file[:name]} (#{details})"
      end

      def signature_text(signature)
        [signature[:field], signature[:signer], signature[:valid] ? "valid" : "not valid"].compact.join(", ")
      end

      def pairs(hash) = hash.map { |key, value| "#{key}: #{list(value)}" }.join(", ")

      def list(value) = value.is_a?(Array) ? value.join(", ") : value.to_s

      def number(value) = value == value.round ? value.round.to_s : value.to_s
    end
  end
end
