# frozen_string_literal: true

module Stationery
  module Fonts
    # Process-wide cache of parsed TrueType files, keyed by path and mtime so an
    # edited font is re-read. Parsing is the expensive part; the per-document
    # Font objects that track used glyphs are cheap wrappers around a parse.
    module Registry
      SIZE = 16
      @cache = {}
      @mutex = Mutex.new

      class << self
        def load(path)
          path = File.expand_path(path.to_s)
          raise UnsupportedFont, "font file not found: #{path}" unless File.file?(path)

          mtime = File.mtime(path)
          @mutex.synchronize { fetch(path, mtime) }
        end

        def clear
          @mutex.synchronize { @cache.clear }
        end

        private

        def fetch(path, mtime)
          cached_mtime, ttf = @cache.delete(path)
          ttf = TrueType.new(File.binread(path)) unless cached_mtime == mtime
          @cache[path] = [mtime, ttf]
          @cache.shift while @cache.size > SIZE
          ttf
        end
      end
    end
  end
end
