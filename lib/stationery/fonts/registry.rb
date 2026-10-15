# frozen_string_literal: true

module Stationery
  module Fonts
    # The parsed TrueType files of one Ractor (see Store), the SIZE most
    # recently used, keyed by path and face and read again when the file's
    # mtime changes. Parsing is the expensive part; the per-document Font
    # objects that track used glyphs are cheap wrappers around a parse. A
    # `#N` suffix on the path picks face N of a collection.
    module Registry
      SIZE = 16
      FACE = /\A(.+)#(\d+)\z/

      class << self
        def load(path)
          path, index = split(path.to_s)
          path = File.expand_path(path)
          raise UnsupportedFont, "font file not found: #{path}" unless File.file?(path)

          mtime = File.mtime(path)
          lru.fetch([path, index]) { |held| held&.first == mtime ? held : [mtime, parse(path, index)] }.last
        end

        def clear = lru.clear

        private

        def lru = Store.fetch(:stationery_fonts) { LRU.new(SIZE) }

        def split(path)
          match = FACE.match(path)
          match ? [match[1], match[2].to_i] : [path, 0]
        end

        def parse(path, index)
          Stationery.instrument("font.stationery", path: File.basename(path), action: :parse) do
            TrueType.new(File.binread(path), index:)
          end
        end
      end
    end
  end
end
