# frozen_string_literal: true

module Stationery
  # Resolves internal links (`#name`) against the anchors painted on the
  # finished pages. Anchors drawn by page templates repeat on every page, so
  # they resolve to their first page and never count as duplicates.
  class Structure
    # Where a named anchor sits: a zero-based page index and a PDF-space top.
    Destination = Data.define(:page, :top)

    # Returns the destinations by name; unresolved links are dropped.
    def self.resolve(pages, warnings:) = new(pages, warnings).resolve

    def initialize(pages, warnings)
      @pages = pages
      @warnings = warnings
      @destinations = {}
    end

    def resolve
      collect
      collect_templates
      @pages.each_with_index do |page, index|
        page.annotations.replace(page.annotations.filter_map { |link| link_to(link, index) })
      end
      @destinations
    end

    private

    def collect
      @pages.each_with_index do |page, index|
        page.anchors.each do |name, top|
          if @destinations.key?(name)
            @warnings << Warnings::DuplicateAnchor.new(name:, page: index + 1)
          else
            @destinations[name] = Destination.new(index, top)
          end
        end
      end
    end

    def collect_templates
      @pages.each_with_index do |page, index|
        page.template_anchors.each { |name, top| @destinations[name] ||= Destination.new(index, top) }
      end
    end

    def link_to(link, index)
      return link unless link.key?(:dest)

      destination = @destinations[link[:dest]]
      return { rect: link[:rect], dest: destination } if destination

      @warnings << Warnings::UnresolvedLink.new(name: link[:dest], page: index + 1)
      nil
    end
  end
end
