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

        MARK_STEPS = {
          bold: [[:b]], italic: [[:i]], underline: [[:u]], strike: [[:strikethrough]]
        }.freeze

        def initialize(runs, styles)
          @runs = runs
          @styles = styles
        end

        def write(inlines) = inlines.grep(Inline).each { |inline| inline.break? ? @runs.br : write_one(inline) }

        private

        def write_one(inline) = nest(inline.marks.flat_map { |mark, value| steps(mark, value) }, inline.text)

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
          else MARK_STEPS.fetch(mark, [])
          end
        end

        def style_steps(style) = style.filter_map { |key, value| STYLE_STEPS[key]&.call(value) }
      end
    end
  end
end
