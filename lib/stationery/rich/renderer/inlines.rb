# frozen_string_literal: true

module Stationery
  module Rich
    class Renderer
      # Writes inlines into a Text::RunsBuilder, nesting one builder call per mark.
      class Inlines
        STYLE_STEPS = {
          weight: ->(value) { [:b] if value == :bold },
          style: ->(value) { [:i] if value == :italic },
          underline: ->(value) { [:u] if value },
          strikethrough: ->(value) { [:strikethrough] if value },
          color: ->(value) { [:color, value] if value },
          size: ->(value) { [:size, value] if value },
          font: ->(value) { [:font, value] if value }
        }.freeze

        # A true mark switches the style on, a false one (from CSS) switches it off again.
        MARK_STEPS = {
          bold: { true => [[:b]], false => [[:with, { weight: :regular }]] },
          italic: { true => [[:i]], false => [[:with, { style: :normal }]] },
          underline: { true => [[:u]], false => [[:with, { underline: false }]] },
          strike: { true => [[:strikethrough]], false => [[:with, { strikethrough: false }]] }
        }.freeze

        def initialize(runs, styles, links = Links.new(:all, nil))
          @runs = runs
          @styles = styles
          @links = links
        end

        def write(inlines) = inlines.grep(Inline).each { |inline| inline.break? ? @runs.br : write_one(inline) }

        private

        def write_one(inline) = nest(marks_of(inline).flat_map { |mark, value| steps(mark, value) }, inline.text)

        def marks_of(inline)
          marks = inline.marks
          return marks unless marks.key?(:link) && !@links.allowed?(marks[:link])

          marks.except(:link)
        end

        def nest(steps, text)
          return @runs.plain(text) if steps.empty?

          name, *args = steps.first
          @runs.public_send(name, *args) { nest(steps.drop(1), text) }
        end

        def steps(mark, value)
          case mark
          when :link then [[:link, value], *style_steps(@styles[:a])]
          when :code then style_steps(@styles[:code])
          when :script then [[value]]
          when :color then [[:color, value]]
          when :size then [[:size, value]]
          when :scale then [[:scale, value]]
          else MARK_STEPS.dig(mark, value) || []
          end
        end

        def style_steps(style) = style.filter_map { |key, value| STYLE_STEPS[key]&.call(value) }
      end
    end
  end
end
