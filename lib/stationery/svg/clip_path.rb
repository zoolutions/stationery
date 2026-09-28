# frozen_string_literal: true

module Stationery
  module SVG
    # Turns `clip-path: url(#id)` into the Region an element is painted in.
    # The shapes of the clipPath (and the shapes its `use` children refer to)
    # are outlined in the user space of the clipped element, under the clip
    # path's own transform and theirs; `clipPathUnits="objectBoundingBox"`
    # scales them to the element's box. They join into one clipping path, so
    # overlapping shapes wound in opposite directions cancel where they
    # overlap. A clip path's own clip-path is the region around it. Text in
    # a clip path is skipped and reported.
    class ClipPath
      OUTLINED = (Shapes::NAMES + %w[text]).freeze

      def initialize(ids, walker)
        @ids = ids
        @walker = walker
      end

      # The Region for `element`, drawn with `style`; nil without such a clip
      # path, when the element is painted unclipped.
      def region(id, element, style, seen = [])
        clip = @ids[id]
        return @walker.issue("clip-path: ##{id} not found") unless clip&.name == "clipPath"
        return @walker.issue("clip-path: circular reference ##{id}") if seen.include?(id)

        base = user_space(clip, element, style) or return Region::EMPTY
        own = base.child(clip)
        outlines = clip.children.grep(Parser::Element).filter_map { |child| outline(child, own.child(child), id) }
        outer = own.clip_path && region(own.clip_path, element, style, seen + [id])
        Region.new(outlines.map(&:first), outlines.any?(&:last), outer)
      end

      private

      # The style the clip path's content starts from; nil when the units
      # are the element's box and it has none.
      def user_space(clip, element, style)
        space = style.at(style.matrix, Style::DEFAULTS)
        return space unless clip.attributes["clipPathUnits"] == "objectBoundingBox"

        x, y, width, height = @walker.box(element, style)
        space.transformed([width, 0, 0, height, x, y]) if x
      end

      # [part, even-odd?] for a child that outlines something.
      def outline(child, style, id)
        return unless style.displayed? && style.visible?

        case child.name
        when "use" then used(child, style, id)
        when "text" then @walker.issue("clipPath ##{id}: text")
        when *Shapes::NAMES then [Region::Part.new(style.matrix, Region::Shape.new(child)), style.clip_even_odd?]
        end
      end

      # A use in a clip path refers to a shape or a text, not to a group.
      def used(child, style, id)
        attributes = child.attributes
        target = @ids[(attributes["href"] || attributes["xlink:href"]).to_s[/\A#(.+)/, 1]]
        return unless target && OUTLINED.include?(target.name)

        placed = style.transformed([1, 0, 0, 1, Shapes.f(attributes, "x"), Shapes.f(attributes, "y")])
        outline(target, placed.child(target), id)
      end
    end
  end
end
