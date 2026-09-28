# frozen_string_literal: true

module Stationery
  class Canvas
    # The links of a header, a footer or a page template in a tagged PDF.
    # Everything a region paints is a pagination artifact, and an annotation
    # has to belong to a Link element (ISO 14289-1, 7.18.5), whose content is
    # real content: that may not be inside an artifact. So the artifact's
    # sequence is closed before what a link paints and opened again after it,
    # and the Link joins the tree after the content of its page
    # (Tagging::Tree#follow).
    module Surfacing
      # What Marking#tag_runs hands a paragraph in a region: the canvas
      # itself, so that a region without a link allocates what it did.
      # Continues the sequence of `link` when it is the one open, and
      # otherwise starts one for it; without a link the text is the region's.
      def call(link = nil)
        unless link.equal?(@surfaced)
          submerge if @surfaced
          emerge(link) if link
        end
        yield
      end

      private

      # Whether a region's artifact is what is open.
      def surfacing? = @template && !@artifact.nil?

      def surface_runs
        yield self
      ensure
        submerge if @surfaced
      end

      # Paints the block as the content of `link` (a linked box): its text is
      # tagged inside it, and what it draws is an artifact of its own.
      def surface(link)
        artifact = @artifact
        close_run
        @artifact = nil
        @tagging.follow(@page, link)
        open_elements << link
        begin
          yield
        ensure
          open_elements.pop
          emit(@artifact = artifact)
          @marked += 1
        end
      end

      def emerge(link)
        close_run
        @tagging.follow(@page, link)
        open_run(@surfaced = link)
      end

      def submerge
        close_run
        emit(@artifact)
        @marked += 1
        @surfaced = nil
      end
    end
  end
end
