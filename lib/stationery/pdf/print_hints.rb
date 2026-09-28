# frozen_string_literal: true

module Stationery
  module PDF
    # How a document asks to be printed: the print entries of the catalog's
    # /ViewerPreferences (ISO 32000-1, 12.2, table 150) and the named action
    # that opens the print dialog.
    #
    #   { scaling: :none, copies: 2, pick_tray_by_size: true, duplex: :simplex, pages: 1..3, dialog: :on_open }
    #
    # `scaling:` is :none or :default, `copies:` an Integer of 1 or more,
    # `pick_tray_by_size:` true or false, `duplex:` :simplex, :long_edge or
    # :short_edge, `pages:` a Range of page numbers from 1 or a list of them
    # (`2..` runs to the last page) and `dialog:` :on_open. They are hints: a
    # viewer follows the ones it knows and the print dialog can overrule them.
    module PrintHints
      NONE = {}.freeze
      SCALING = { none: :None, default: :AppDefault }.freeze
      DUPLEX = { simplex: :Simplex, long_edge: :DuplexFlipLongEdge, short_edge: :DuplexFlipShortEdge }.freeze
      ACCEPTED = {
        scaling: ":none or :default", copies: "an Integer of 1 or more", pick_tray_by_size: "true or false",
        duplex: ":simplex, :long_edge or :short_edge", dialog: ":on_open",
        pages: "a Range of page numbers from 1 (1..3) or a list of them"
      }.freeze
      KEYS = %i[scaling copies pick_tray_by_size duplex pages dialog].freeze
      OPEN_ACTION = { Type: :Action, S: :Named, N: :Print }.freeze

      module_function

      # The hints as they were given, checked: a nil takes a hint away.
      def options(hints)
        unknown = hints.keys - KEYS
        raise ArgumentError, "unknown print hint #{unknown.first.inspect} (use #{names})" if unknown.any?

        hints.each do |key, value|
          next if value.nil? || valid?(key, value)

          raise ArgumentError, "print #{key}: is #{ACCEPTED.fetch(key)}, not #{value.inspect}"
        end
        ranges(hints[:pages]) if hints[:pages]
        hints
      end

      # The hints of a render: what it gives laid over what the class
      # declares. nil or false for `given` takes every hint away; nil without any.
      def merge(declared, given)
        return unless given
        raise ArgumentError, "print: takes a Hash of hints, nil or false, not #{given.inspect}" unless given.is_a?(Hash)
        return declared.empty? ? nil : declared if given.empty?

        hints = declared.merge(options(given)).compact
        hints.empty? ? nil : hints
      end

      # The catalog's entries for `hints`, in a document of `pages` pages. A
      # page range is cut at the last page, and one that starts after it is
      # left out: a viewer drops a /PrintPageRange that names a page the
      # document does not have.
      def catalog_entries(hints, pages:)
        preferences = preferences(hints, pages)
        entries = preferences.empty? ? {} : { ViewerPreferences: preferences }
        entries[:OpenAction] = OPEN_ACTION if hints[:dialog]
        entries
      end

      # The hints a catalog holds (as read back), {} without any.
      def read(catalog)
        preferences = catalog[:ViewerPreferences] || NONE
        action = catalog[:OpenAction]
        range = preferences[:PrintPageRange]
        { scaling: name(SCALING, preferences[:PrintScaling]), copies: preferences[:NumCopies],
          pick_tray_by_size: preferences[:PickTrayByPDFSize], duplex: name(DUPLEX, preferences[:Duplex]),
          pages: range&.each_slice(2)&.map { |first, last| first..last },
          dialog: (:on_open if action.is_a?(Hash) && action[:S] == :Named && action[:N] == :Print) }.compact
      end

      def names = KEYS.map(&:inspect).join(", ")
      def name(names, value) = value && (names.key(value) || value)

      def valid?(key, value)
        case key
        when :scaling then SCALING.key?(value)
        when :duplex then DUPLEX.key?(value)
        when :copies then value.is_a?(Integer) && value >= 1
        when :pick_tray_by_size then [true, false].include?(value)
        when :dialog then value == :on_open
        when :pages then pages?(value)
        end
      end

      def list(pages) = pages.is_a?(Array) ? pages : [pages]

      def pages?(value)
        list(value).any? && list(value).all? { |range| range.is_a?(Range) && bounds(range) }
      end

      # [first, last] of a range of page numbers, last nil for one that runs
      # to the end; nil for a range that is not one.
      def bounds(range)
        first = range.begin || 1
        last = range.end
        return unless first.is_a?(Integer) && first >= 1 && (last.nil? || last.is_a?(Integer))

        last -= 1 if last && range.exclude_end?
        [first, last] if last.nil? || last >= first
      end

      # The ranges in page order as [first, last, range]; ones that overlap raise.
      def ranges(pages)
        sorted = list(pages).map { |range| [*bounds(range), range] }.sort_by(&:first)
        sorted.each_cons(2) do |(_, last, one), (first, _, other)|
          raise ArgumentError, "print pages: #{one} and #{other} overlap" if last.nil? || first <= last
        end
        sorted
      end

      def preferences(hints, pages)
        preferences = {}
        preferences[:PrintScaling] = SCALING.fetch(hints[:scaling]) if hints[:scaling]
        preferences[:NumCopies] = hints[:copies] if hints[:copies]
        preferences[:PickTrayByPDFSize] = hints[:pick_tray_by_size] if hints.key?(:pick_tray_by_size)
        preferences[:Duplex] = DUPLEX.fetch(hints[:duplex]) if hints[:duplex]
        range = page_range(hints[:pages], pages)
        preferences[:PrintPageRange] = range if range.any?
        preferences
      end

      def page_range(ranges, pages)
        return [] unless ranges

        ranges(ranges).flat_map do |first, last, _|
          first > pages ? [] : [first, [last || pages, pages].min]
        end
      end
    end
  end
end
