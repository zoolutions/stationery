# frozen_string_literal: true

module Stationery
  class Canvas
    # Marked content for tagged PDF. Without a Tagging::Tree every method
    # just yields, so an untagged document's content streams stay as they were.
    module Marking
      def tagging? = !@tagging.nil?

      # Paints the block as one marked-content sequence of `element` (a fresh
      # MCID on this page), joining the element to the open structure. With no
      # element the block is an artifact. `bbox` is [x, y, w, h] in top-left
      # coordinates, kept as the element's layout bounding box.
      def tag(element, bbox: nil, &)
        return artifact(&) unless element
        return yield unless structure?

        element.attach(open_element)
        element.place(pdf_box(*bbox)) if bbox
        emit("/#{element.type} <</MCID #{@tagging.mark(@page, element)}>> BDC")
        marked(&)
      end

      # Opens `element` (nil: none) as the parent of the elements painted in
      # the block, without marking any content itself.
      def structure(element)
        return yield unless element && structure?

        element.attach(open_element)
        open_elements << element
        begin
          yield
        ensure
          open_elements.pop
        end
      end

      # Paints the block as an artifact: content that is not part of the
      # document's structure. `type:` (:pagination, :layout, :page) and
      # `subtype:` (:header, :footer, :watermark) describe it.
      def artifact(type: nil, subtype: nil, &)
        return yield unless structure?

        properties = { Type: type && capital(type), Subtype: subtype && capital(subtype) }.compact
        emit(properties.empty? ? "/Artifact BMC" : "/Artifact #{PDF::Serializer.dump(properties)} BDC")
        marked(&)
      end

      private

      def structure? = @tagging && @marked.zero?
      def open_elements = @open_elements ||= []
      def open_element = open_elements.last || @tagging.root
      def capital(value) = value.to_s.capitalize.to_sym

      def marked
        @marked += 1
        yield
      ensure
        @marked -= 1
        emit("EMC")
      end

      def pdf_box(x, y, w, h)
        [x, @page.height - y - h, x + w, @page.height - y].map { |value| num_value(value) }
      end
    end
  end
end
