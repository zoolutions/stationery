# frozen_string_literal: true

module Stationery
  module Rich
    class Renderer
      # Block quotes and lists each indent what they hold, so nested deep
      # enough they leave their text no width and it is lost. Past LIMIT
      # levels the content is drawn where the last indented level put it:
      # a block quote without its bar, list items without their markers.
      module Indents
        LIMIT = 12

        private

        def indented(block)
          return flat(block) if @indents >= LIMIT

          @indents += 1
          begin
            yield
          ensure
            @indents -= 1
          end
        end

        def flat(block) = group(block.is_a?(List) ? block.items.flatten(1) : block.blocks)

        # How many block quotes and lists deep the blocks go.
        def indents_of(blocks)
          blocks.map do |block|
            case block
            when Blockquote then 1 + indents_of(block.blocks)
            when Container then indents_of(block.blocks)
            when List then 1 + (block.items.map { |item| indents_of(item) }.max || 0)
            when Table then block.rows.flatten.map { |cell| indents_of(cell.blocks) }.max || 0
            else 0
            end
          end.max || 0
        end
      end
    end
  end
end
