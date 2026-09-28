# frozen_string_literal: true

module Stationery
  module SVG
    # Walks a document in paint order and yields every drawn shape and text
    # with its resolved style. A `use` draws what it refers to at its x and
    # y, a symbol (through `use` only) and a nested svg draw into their
    # viewport, and what has a `clip-path` or overflows a viewport is walked
    # inside `clipper`: a callable given the Region and a block, left out
    # when the document is only read. What cannot be followed is in `issues`.
    class Walker
      RENDERED = (Shapes::NAMES + %w[text g use svg]).freeze
      VIEWPORTS = %w[symbol svg].freeze
      MAX_USES = 32 # a use of a use of a use …

      attr_reader :issues

      # `ids` are the document's elements by id, `viewport` the [width,
      # height] percentages resolve against at the root.
      def initialize(ids, viewport, clipper: nil)
        @ids = ids
        @viewports = [viewport]
        @clipper = clipper
        @clip_paths = ClipPath.new(ids, self)
        @issues = []
        @measuring = false
      end

      # Yields what the children of `parent` draw; `style` is the parent's.
      # `chain` holds the ids of the `use` targets being drawn.
      def children(parent, style, chain = [], &)
        parent.children.grep(Parser::Element).each { |element| node(element, style.child(element), chain, &) }
      end

      # The box of what `element` draws, in its own user space, clipping
      # and text aside: [x, y, width, height], or nil when it has no area.
      def box(element, style)
        bounds = Bounds.new
        measuring do
          node(element, style.at(Style::IDENTITY), []) do |shape, own|
            corners(shape, own.matrix).each { |x, y| bounds.line_to(x, y) } unless shape.name == "text"
          end
        end
        bounds.box
      end

      def issue(message)
        @issues << message unless @measuring
        nil
      end

      private

      # Anything else (defs, symbol, clipPath, a gradient, …) draws nothing
      # where it stands.
      def node(element, style, chain, &)
        return unless RENDERED.include?(element.name) && style.displayed?

        clipped(element, style) do
          case element.name
          when "g" then children(element, style, chain, &)
          when "use" then use(element, style, chain, &)
          when "svg" then viewport(element, element.attributes, style, chain, &)
          else yield element, style if style.visible?
          end
        end
      end

      def use(element, style, chain, &)
        target, id = target_of(element)
        return unless target
        return issue("use: circular reference ##{id}") if chain.include?(id)
        return issue("use: nested deeper than #{MAX_USES}") if chain.size >= MAX_USES

        attributes = element.attributes
        placed = style.transformed([1, 0, 0, 1, Shapes.f(attributes, "x"), Shapes.f(attributes, "y")])
        instance(target, placed.child(target), attributes.slice("width", "height"), chain + [id], &)
      end

      # A symbol or an svg drawn by a use takes the use's width and height.
      def instance(target, style, size, chain, &)
        return node(target, style, chain, &) unless VIEWPORTS.include?(target.name)
        return unless style.displayed?

        clipped(target, style) { viewport(target, target.attributes.merge(size), style, chain, &) }
      end

      def target_of(element)
        href = (element.attributes["href"] || element.attributes["xlink:href"]).to_s.strip
        return issue("use: no href") if href.empty?

        id = href[/\A#(.+)/, 1]
        target = @ids[id]
        target ? [target, id] : issue("use: #{href} not found")
      end

      def viewport(element, attributes, style, chain, &)
        port = Viewport.new(attributes, @viewports.last, origin: element.name == "svg")
        return unless port.drawable?

        region = Region.new([Region::Part.new(style.matrix, port)], false, nil) if style.clips?
        clip(region) { within(port) { children(element, style.transformed(port.matrix), chain, &) } }
      end

      def within(port)
        @viewports.push(port.size)
        yield
      ensure
        @viewports.pop
      end

      def clipped(element, style, &)
        id = style.clip_path
        return yield if id.nil? || @measuring

        region = @clip_paths.region(id, element, style)
        region ? clip(region, &) : yield
      end

      def clip(region, &)
        return yield if region.nil? || @measuring
        return if region.empty?

        @clipper ? @clipper.call(region, &) : yield
      end

      def measuring
        previous = @measuring
        @measuring = true
        yield
      ensure
        @measuring = previous
      end

      def corners(shape, matrix)
        x, y, width, height = Bounds.new.tap { |bounds| Shapes.trace(bounds, shape) }.box
        return [] unless x

        [[x, y], [x + width, y], [x, y + height], [x + width, y + height]]
          .map { |corner_x, corner_y| Transform.apply(matrix, corner_x, corner_y) }
      end
    end
  end
end
