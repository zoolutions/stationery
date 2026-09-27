# frozen_string_literal: true

module Stationery
  # Resolves internal links (`#name`) against the anchors painted on the
  # finished pages and fills page-number slots with the pages their anchors
  # landed on. Anchors drawn by page templates repeat on every page, so they
  # resolve to their first page and never count as duplicates.
  class Structure
    # Where a named anchor sits: a zero-based page index and a PDF-space top.
    Destination = Data.define(:page, :top)

    # Returns the destinations by name; unresolved links are dropped.
    # Runs before resources are written, so slot digits join the font subset.
    def self.resolve(pages, warnings:, resources: nil, book: nil) = new(pages, warnings, resources, book).resolve

    def initialize(pages, warnings, resources, book)
      @pages = pages
      @warnings = warnings
      @resources = resources
      @book = book
      @destinations = {}
    end

    def resolve
      collect
      collect_templates
      @pages.each_with_index do |page, index|
        page.slots.each { |slot| fill(page, slot) }
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

    def fill(page, slot)
      destination = @destinations[slot.anchor] or return
      label = (destination.page + 1).to_s
      font, face = @book.resolve(slot.style)
      style = slot.style
      width = font.width_of(label, style.render_size, letter_spacing: style.letter_spacing)
      canvas = Canvas.new(page, @resources)
      canvas.link(*slot.link, "##{slot.anchor}") if slot.link
      canvas.text(label, x: slot.x + slot.width - width, y: slot.baseline, font:,
                         size: style.render_size, color: style.color,
                         letter_spacing: style.letter_spacing, opacity: style.opacity,
                         synthetic_bold: face.synthetic_bold, synthetic_oblique: face.synthetic_oblique)
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
