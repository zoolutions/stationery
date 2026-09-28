# frozen_string_literal: true

module Stationery
  # One page: its size and margins, the drawing operators written to it, the
  # resources those operators reference, its link annotations and the named
  # anchors painted on it (PDF-space tops) and the page-number slots waiting
  # for their anchors' pages.
  #
  # A page may be sealed once its body is painted: the operators are deflated
  # into `body` and let go, and what is painted afterwards (headers, footers,
  # page numbers) is kept apart, in `content` over the body and in
  # `background` under it.
  class Page
    # Room for the page number of `anchor`, right-aligned in `width` from `x`
    # on `baseline` (top-left coordinates), drawn in `style`. `link` is an
    # [x, y, w, h] area linked to the anchor only once it resolves. `tags` are
    # its [link, number] structure elements in a tagged PDF.
    Slot = Data.define(:anchor, :x, :baseline, :width, :style, :link, :tags) do
      def initialize(anchor:, x:, baseline:, width:, style:, link:, tags: nil) = super
    end

    # Portrait, in points. Envelopes (dl, c5, c6) are written the ISO way,
    # short edge first: `layout: :landscape` is the side the address is on.
    # Label stock is width by height as its name has it.
    SIZES = {
      a3: [841.89, 1190.55], a4: [595.28, 841.89], a5: [419.53, 595.28], a6: [297.64, 419.53], a7: [209.76, 297.64],
      b5: [498.9, 708.66], letter: [612, 792], legal: [612, 1008], tabloid: [792, 1224],
      dl: [311.81, 623.62], c5: [459.21, 649.13], c6: [323.15, 459.21],
      label_4x6: [288, 432], label_4x3: [288, 216], label_4x2: [288, 144],
      label_100x150: [283.46, 425.2], label_100x50: [283.46, 141.73]
    }.freeze

    attr_reader :size, :margin, :reserve, :content, :annotations, :anchors, :template_anchors, :slots,
                :resource_names, :body, :background

    def initialize(size: :letter, layout: :portrait, margin: 0, reserve: [0, 0])
      @size = dimensions(size)
      @size = @size.reverse if layout.to_sym == :landscape
      @margin = Format.sides(margin)
      @reserve = reserve
      @content = String.new(encoding: Encoding::BINARY)
      @annotations = []
      @anchors = []
      @template_anchors = []
      @slots = []
      @resource_names = Hash.new { |hash, key| hash[key] = [] }
    end

    def width = @size[0]
    def height = @size[1]

    def margin_box
      top, right, bottom, left = @margin
      Rect.new(left, top, width - left - right, height - top - bottom)
    end

    # The margin box less the space reserved for the header and footer.
    def content_box = margin_box.inset(@reserve[0], 0, @reserve[1], 0)

    # Deflates the operators painted so far into `body` (a PDF::Stream, or
    # what the block makes of it: its reference once it is written) and
    # starts `content` and `background` afresh.
    def seal
      stream = PDF::Stream.new(@content)
      @body = block_given? ? yield(stream) : stream
      @content = String.new(encoding: Encoding::BINARY)
      @background = String.new(encoding: Encoding::BINARY)
      self
    end

    def sealed? = !@body.nil?

    # Moves what was painted after the first `mark` bytes of `content` under
    # everything else on the page.
    def lower(mark)
      (@background || @content).prepend(@content.slice!(mark..))
    end

    def use(category, name)
      names = @resource_names[category]
      names << name unless names.include?(name)
      name
    end

    private

    def dimensions(size)
      return size.map { |v| v } if size.is_a?(Array) && size.size == 2 && size.all?(Numeric)

      SIZES.fetch(size.to_s.downcase.to_sym) { Format.size(size) }
    end
  end
end
