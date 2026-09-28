# frozen_string_literal: true

module Stationery
  module Layout
    EPSILON = 0.0001

    # What text nodes need to measure: the document's fonts and the base
    # style; and whether the render writes a structure tree (`tagged`), so a
    # node builds its Tagging::Element only when one will hold it.
    Context = Data.define(:book, :style, :tagged) do
      # A structure element of `type` for a node, nil when nothing will be written.
      def element(type) = tagged ? Tagging::Element.new(type) : nil
    end

    # A node placed taller than the space a page had for it.
    Overflow = Data.define(:page, :height, :available) do
      def message
        format("content %<height>.1fpt tall placed on page %<page>d with %<available>.1fpt available",
               height:, page:, available:)
      end
    end

    # The layout protocol. Every node can:
    #
    # - measure(width)            → its height at that width
    # - height_within(width, limit)
    #                             → its height at that width or, when that is
    #                               more than `limit`, any height above it
    # - paint(canvas, x, y, width, height = nil, **)
    # - split(width, height, fresh: false)
    #                             → [part that fits, remainder] (nil for an empty side);
    #                               fresh: true when nothing is above it on a new page
    # - natural_width / min_width → its preferred and narrowest widths
    # - fixed_width(available)    → its own width, or nil when it fills the width
    #
    # A node that `wraps?` lays its lines out around floats: its measure,
    # paint and split take `exclusions:` (Text::Exclusions, from its own
    # top). Any other node is placed beside a float as a block, or below it.
    class Node
      attr_accessor :keep_with_next, :break_inside
      # The Tagging::Element this node paints into, shared by its fragments.
      attr_reader :tag
      # See #placing_width.
      attr_writer :placing_width

      def measure(_width) = raise(NotImplementedError, "#{self.class} must implement measure")
      def paint(_canvas, _x, _y, _width, _height = nil, **) = raise(NotImplementedError, "#{self.class}#paint")

      # What a page asks a node it may have to split: a long table answers
      # without measuring the rows beyond the limit.
      def height_within(width, _limit) = measure(width)

      def splittable? = false
      # Moves whole to a fresh page before splitting; splits only when it does
      # not fit there either.
      def prefer_whole? = false
      def natural_width = 0
      def min_width = 0
      # The width a node is placed by beside floats (Flow::Placement): its
      # least width, or the whole's for a part cut from it at a page break
      # (Flow::Splitter), so that the part keeps the slot decided for the whole.
      def placing_width = @placing_width || min_width
      def fixed_width(_available) = nil
      def wraps? = false
      # Whether it wraps beside floats and paints something of its own under
      # them, or holds a node that does: the floats are painted after it.
      def decorated? = false
      # Whether it is taken out of the flow to one side (Floated).
      def float? = false
      # The width this node is laid out at inside a parent of `available`.
      def width_in(available) = fixed_width(available) || available
      def page_break? = false
      # Whether a page break lies somewhere inside (a flow holding one).
      def breaks? = false
      # Whether it starts with a page break (a flow whose first node is one).
      def leading_break? = false

      def split(width, height, **)
        measure(width) <= height + EPSILON ? [self, nil] : [nil, self]
      end

      def avoid_break?
        break_inside == :avoid || !splittable?
      end

      private

      # Remembers a height per width: a page measures the same subtree for the
      # flow splitter, keep_with_next and paint. Nodes are not changed after
      # layout starts (Flow#<< forgets), and copies start with no measurements.
      def memoize_by_width(width)
        @measures ||= {}
        @measures.fetch(width) { @measures[width] = yield }
      end

      def forget_measures = @measures = nil

      def initialize_copy(source)
        super
        forget_measures
      end
    end
  end
end
