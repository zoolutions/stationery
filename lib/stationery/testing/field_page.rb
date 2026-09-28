# frozen_string_literal: true

require "delegate"

module Stationery
  module Testing
    # A page with what its form fields show: the page content, then the
    # normal appearance of every widget a reader sees, drawn where the widget
    # is. An appearance is a form XObject of the annotation, which the page
    # content never draws; here it is one of the page's XObjects, so a
    # receiver reads it as it reads any form.
    #
    # A widget that is hidden shows nothing. Of the appearances a check box
    # or a radio button has, the one its state names is read, never /Off.
    class FieldPage < SimpleDelegator
      # The Hidden and NoView flags of an annotation's /F.
      UNSEEN = 0b100010
      IDENTITY = [1, 0, 0, 1, 0, 0].freeze

      def initialize(page)
        super
        @appearances = widgets.each_with_index.to_h { |widget, index| [:"Stationery.Field.#{index}", widget] }
      end

      def xobjects = __getobj__.xobjects.merge(@appearances.transform_values(&:last))

      # Each appearance is drawn as `q … cm /Name Do Q` would draw it.
      def walk(*receivers)
        __getobj__.walk(*receivers)
        @appearances.each do |label, (placement, _)|
          receivers.each do |receiver|
            receiver.save_graphics_state
            receiver.concatenate_matrix(*placement)
            receiver.invoke_xobject(label)
            receiver.restore_graphics_state
          end
        end
      end

      private

      # [[placement, appearance stream], …] of the widgets that show one.
      def widgets
        Array(objects.deref_array(attributes[:Annots])).filter_map do |ref|
          widget = objects.deref_hash(ref)
          next unless widget[:Subtype] == :Widget && widget[:F].to_i.nobits?(UNSEEN)

          stream = appearance(widget)
          placement = stream && placement(objects.deref!(widget[:Rect]), objects.deref!(stream.hash))
          [placement, stream] if placement
        end
      end

      def appearance(widget)
        normal = objects.deref(objects.deref_hash(widget[:AP])&.fetch(:N, nil))
        return normal unless normal.is_a?(Hash)

        objects.deref(normal[widget[:AS]]) unless widget[:AS] == :Off
      end

      # The matrix that takes the appearance's box, as its own /Matrix turns
      # it, onto the widget's rectangle (PDF 32000-1, 12.5.5). nil for a box
      # or a rectangle without room, which shows nothing.
      def placement(rect, form)
        across, up = box(form)
        wide = rect.values_at(0, 2).minmax
        high = rect.values_at(1, 3).minmax
        return if [across, up, wide, high].any? { |from, to| from == to }

        x_scale, x = fit(across, wide)
        y_scale, y = fit(up, high)
        [x_scale, 0, 0, y_scale, x, y]
      end

      # [[left, right], [bottom, top]] of the appearance's box, turned.
      def box(form)
        a, b, c, d, e, f = form[:Matrix] || IDENTITY
        corners = form[:BBox].values_at(0, 2).product(form[:BBox].values_at(1, 3))
        corners.map { |x, y| [(a * x) + (c * y) + e, (b * x) + (d * y) + f] }.transpose.map(&:minmax)
      end

      # The scale and the move that take the span `from` onto the span `onto`.
      def fit(from, onto)
        scale = (onto.last - onto.first).fdiv(from.last - from.first)
        [scale, onto.first - (from.first * scale)]
      end
    end
  end
end
