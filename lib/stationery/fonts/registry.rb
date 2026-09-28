# frozen_string_literal: true

module Stationery
  module Fonts
    # Process-wide cache of parsed TrueType files, keyed by path, face and
    # mtime so an edited font is re-read. Parsing is the expensive part; the
    # per-document Font objects that track used glyphs are cheap wrappers
    # around a parse. A `#N` suffix on the path picks face N of a collection.
    module Registry
      SIZE = 16
      FACE = /\A(.+)#(\d+)\z/
      @cache = {}
      @mutex = Mutex.new

      class << self
        def load(path)
          path, index = split(path.to_s)
          path = File.expand_path(path)
          raise UnsupportedFont, "font file not found: #{path}" unless File.file?(path)

          mtime = File.mtime(path)
          @mutex.synchronize { fetch(path, index, mtime) }
        end

        def clear
          @mutex.synchronize { @cache.clear }
        end

        private

        def split(path)
          match = FACE.match(path)
          match ? [match[1], match[2].to_i] : [path, 0]
        end

        def fetch(path, index, mtime)
          key = [path, index]
          cached_mtime, ttf = @cache.delete(key)
          ttf = parse(path, index) unless cached_mtime == mtime
          @cache[key] = [mtime, ttf]
          @cache.shift while @cache.size > SIZE
          ttf
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
