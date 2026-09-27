# frozen_string_literal: true

module Stationery
  # The bookmarks a document declares, in build order. Each entry names an
  # automatic anchor, unique to this outline so a page template's bookmarks
  # never stand in for the body's; once pages are painted, the entries whose
  # anchors landed somewhere become outline items.
  class Outline
    # A declared bookmark: its title, depth (1 = top level), anchor and
    # whether it starts expanded.
    Entry = Data.define(:title, :level, :anchor, :open)

    # A bookmark resolved to the page and top its anchor was painted at.
    Item = Data.define(:title, :level, :dest, :open)

    attr_reader :entries

    def initialize
      @entries = []
    end

    def add(title, level: 1, open: false)
      level = Integer(level)
      raise ArgumentError, "bookmark level must be 1 or more, got #{level}" if level < 1

      anchor = "__bookmark-#{object_id}-#{@entries.size + 1}"
      Entry.new(title.to_s, level, anchor, open ? true : false).tap { @entries << it }
    end

    def resolve(destinations)
      @entries.filter_map do |entry|
        dest = destinations[entry.anchor]
        dest && Item.new(entry.title, entry.level, dest, entry.open)
      end
    end
  end
end
