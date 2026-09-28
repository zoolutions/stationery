# frozen_string_literal: true

module Stationery
  module Layout
    # A barcode (a Barcode symbol) at `module_size` points a module, or as
    # many as fit `width:` across, with its quiet zone around it (a linear
    # one's on its sides, a QR code's all round) unless `quiet_zone: false`:
    # never wider than the space given, its module made smaller to fit. A
    # linear barcode is `height:` tall, a QR code square.
    class Barcode < Node
      LINEAR_MODULE = 1
      SQUARE_MODULE = 2
      HEIGHT = 36
      NAMES = { code128: "Code 128", ean13: "EAN-13", qr: "QR code" }.freeze

      def initialize(symbol, type:, module_size: nil, width: nil, height: nil, color: "#000000", quiet_zone: true,
                     native: nil, context: nil, alt: nil)
        super()
        @symbol = symbol
        @tag = figure(type, context, alt)
        @module_size = module_size
        @width = width
        @height = height || HEIGHT
        @color = color
        @quiet = quiet_zone ? symbol.quiet : 0
        @native = native
      end

      # [width, height, module] at `available` points across.
      def size(available)
        module_size = [requested_module, available / across].min
        [across * module_size, @symbol.linear? ? @height : across * module_size, module_size]
      end

      def measure(width) = size(width)[1]
      def fixed_width(available) = size(available)[0]
      def natural_width = across * requested_module
      def min_width = natural_width

      def paint(canvas, x, y, width, _height = nil, **)
        w, h, module_size = size(width)
        quiet = @quiet * module_size
        canvas.tag(@tag, bbox: [x, y, w, h]) do
          canvas.barcode(@symbol, x: x + quiet, y: @symbol.linear? ? y : y + quiet, module_size:,
                                  height: (@height if @symbol.linear?), color: @color, native: @native)
        end
        canvas.debug_rect(x, y, w, h, :image)
      end

      private

      # A Figure whose alternate text is `alt:`, else the kind of barcode and
      # its data; none when decorative (`alt: false`) or not tagged.
      def figure(type, context, alt)
        return if alt == false || (context && !context.tagged)

        Tagging::Element.new(:Figure, alt: alt || "#{NAMES.fetch(type)}: #{@symbol.data}", kind: :barcode)
      end

      # Modules across, quiet zones included.
      def across = (@symbol.linear? ? @symbol.width : @symbol.size) + (2 * @quiet)

      def requested_module
        return @module_size if @module_size
        return @width.to_f / across if @width

        @symbol.linear? ? LINEAR_MODULE : SQUARE_MODULE
      end
    end
  end
end
