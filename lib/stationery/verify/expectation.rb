# frozen_string_literal: true

module Stationery
  module Verify
    # What a file holds, read with pdf-reader (Testing::Inspector), for the
    # engines' facts to be held against: each page's text lines, links and
    # whether it has content; the outline's titles in order; the fields,
    # once by name, and whether one of its widgets has an area; the
    # attachments' names; how many signatures the file carries and whether
    # they verify; whether it is tagged.
    Expectation = Data.define(:pages, :outline, :fields, :attachments, :signatures, :valid, :tagged) do
      # A page's `lines` are its runs of text (Testing::PageReader); it has
      # `content` when it shows text or an image. Paths are not read, so a
      # page that draws only paths is held to nothing painted.
      self::Page = Data.define(:number, :lines, :links, :content)

      def self.read(inspector)
        layout = inspector.layout
        signatures = inspector.signatures
        new(pages: layout[:pages].map { |page| page(page) }, outline: titles(layout[:outline]),
            fields: fields(layout[:pages]), attachments: layout[:attachments].map { |file| file[:name] },
            signatures: signatures.size, valid: signatures.all? { |signature| signature[:valid] },
            tagged: layout[:tagged])
      end

      def self.page(page)
        self::Page.new(number: page[:number], lines: page[:text].map { |run| run[:text] },
                       links: page[:links].map { |link| link.slice(:uri, :page) },
                       content: page[:text].any? || page[:images].any?)
      end

      def self.titles(entries) = entries.flat_map { |entry| [entry[:title], *titles(entry[:children])] }

      # A field is `visible` when one of its widgets has an area: a widget
      # of no size (an invisible signature's) needs no appearance.
      def self.fields(pages)
        pages.flat_map { |page| page[:fields] }.group_by { |field| field[:name] }.map do |_, widgets|
          widgets.first.slice(:name, :type, :value)
                 .merge(visible: widgets.any? { |widget| widget[:width].positive? && widget[:height].positive? })
        end
      end
    end
  end
end
