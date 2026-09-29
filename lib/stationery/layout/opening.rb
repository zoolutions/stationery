# frozen_string_literal: true

module Stationery
  module Layout
    # What a node starts with, in words, for a message: the first thing it
    # paints, depth first. Text is quoted, its first line cut at LENGTH
    # characters; anything else is named by its kind ("a Code 128 barcode",
    # "an image"). Nil when it paints nothing (a spacer, an anchor, a box
    # placed with at:).
    module Opening
      LENGTH = 40
      BARCODES = { code128: "a Code 128 barcode", ean13: "an EAN-13 barcode", qr: "a QR code",
                   datamatrix: "a Data Matrix code" }.freeze

      module_function

      def of(node)
        case node
        when Text then quote(node.opening)
        when Flow, Wrap then first(node.children)
        when Row then first(node.columns)
        when Box then of(node.content) || "a box"
        when Mark then of(node.child)
        when Floated then of(node.node)
        when ListItem then of(node.body)
        when Stack then of(node.base)
        when Columns then of(node.flow)
        else kind(node)
        end
      end

      def first(nodes)
        nodes.each do |node|
          found = of(node)
          return found if found
        end
        nil
      end

      def quote(text)
        text = text.squeeze(" ").strip
        return if text.empty?

        %("#{text.length > LENGTH ? "#{text[0, LENGTH].rstrip}…" : text}")
      end

      def kind(node)
        case node
        when Barcode then BARCODES.fetch(node.type)
        when Image then "an image"
        when Svg then "an SVG"
        when Table then "a table"
        when TableOfContents then "a table of contents"
        when Rule then "a rule"
        when Field then "a form field"
        when CanvasNode then "a canvas"
        end
      end
    end
  end
end
