# frozen_string_literal: true

module Stationery
  # Tagged (accessible) PDF: a structure tree of standard structure types
  # (ISO 32000-1 §14.8.4) whose leaves point at marked content on the pages.
  module Tagging
    # Grouping roles a box can take, as standard structure types.
    ROLES = { section: :Sect, div: :Div, blockquote: :BlockQuote, note: :Note, caption: :Caption,
              article: :Art, part: :Part }.freeze

    # One marked-content sequence: the page it is on and its MCID there.
    MarkedContent = Data.define(:page, :mcid)

    # An annotation (the page's link Hash) that belongs to an element.
    ObjectRef = Data.define(:page, :annotation)

    def self.role(role)
      ROLES.fetch(role) { raise ArgumentError, "unknown role #{role.inspect} (use #{ROLES.keys.join(", ")})" }
    end

    def self.heading(level)
      return :P unless level
      raise ArgumentError, "heading: takes 1 to 6, got #{level.inspect}" unless (1..6).cover?(level)

      :"H#{level}"
    end

    # A structure element. Layout nodes create one per source node and share
    # it with every fragment a split produces, so content continued on the
    # next page stays one element. It joins the tree where it first paints.
    class Element
      CELLS = %i[TD TH].freeze

      attr_reader :type, :alt, :kind, :kids, :parent, :attributes

      # `alt` is a Figure's alternate text; `kind` names what drew it in
      # warnings; `attributes` are { owner => { key => value } } (/A entries).
      def initialize(type, alt: nil, kind: nil, attributes: {})
        @type = type
        @alt = alt
        @kind = kind
        @attributes = attributes.empty? ? {} : attributes.transform_values(&:dup)
        @kids = []
      end

      def attached? = !@parent.nil?

      def attach(parent)
        return if @parent

        @parent = parent
        parent.kids << self
      end

      # A bounding box in PDF space, kept from the first fragment painted.
      def place(bbox)
        (@attributes[:Layout] ||= {})[:BBox] ||= bbox
        self
      end

      def bbox = @attributes.dig(:Layout, :BBox)
      def marked_content = @kids.grep(MarkedContent)
      def elements = @kids.grep(Element)

      # Holds no content, so the writer leaves it out; an empty table cell
      # stays, keeping its row's columns in place.
      def empty?
        return false if CELLS.include?(@type)

        @kids.none?(MarkedContent) && @kids.none?(ObjectRef) && elements.all?(&:empty?)
      end
    end
  end
end
