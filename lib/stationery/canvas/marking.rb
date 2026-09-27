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
        open_run(element)
        begin
          yield
        ensure
          close_run
        end
      end

      # Marks what the block paints as consecutive sequences: the block gets a
      # callable, `mark.(element) { … }`, that continues the open sequence when
      # `element` is the one it marks and otherwise starts one for it. A nil
      # element is `parent`; any other joins `parent` as a child (a Link
      # inside its paragraph). Without a parent the block is an artifact.
      def tag_runs(parent, &)
        return artifact { yield PASS } unless parent
        return yield PASS unless structure?

        parent.attach(open_element)
        current = nil
        yield(lambda do |element = nil, &block|
          element ||= parent
          unless element.equal?(current)
            close_run if current
            element.attach(parent)
            open_run(current = element)
          end
          block.call
        end)
      ensure
        close_run if current
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
        @marked += 1
        begin
          yield
        ensure
          close_run
        end
      end

      PASS = ->(_element = nil, &block) { block.call }

      private

      # Records an annotation as an /OBJR of `element`, when that element is in the tree.
      def own(annotation, element)
        return unless @tagging && element.attached?

        annotation[:tag] = element
        element.kids << Stationery::Tagging::ObjectRef.new(@page, annotation)
      end

      def open_run(element)
        emit("/#{element.type} <</MCID #{@tagging.mark(@page, element)}>> BDC")
        @marked += 1
      end

      def close_run
        @marked -= 1
        emit("EMC")
      end

      def structure? = @tagging && @marked.zero?
      def open_elements = @open_elements ||= []
      def open_element = open_elements.last || @tagging.root
      def capital(value) = value.to_s.capitalize.to_sym

      def pdf_box(x, y, w, h)
        [x, @page.height - y - h, x + w, @page.height - y].map { |value| num_value(value) }
      end
    end
  end
end
