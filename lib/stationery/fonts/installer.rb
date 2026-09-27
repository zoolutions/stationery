# frozen_string_literal: true

module Stationery
  module Fonts
    # Copies a catalog pack into `<into>/<pack>/`: every file is fetched (or
    # read from `from:`, a directory or .tar.gz, for offline installs) and its
    # SHA-256 checked before anything is written, then each file is written to
    # a temporary name and renamed into place. Existing files are kept unless
    # `force:`. Development-time only; documents never download fonts.
    class Installer
      # Fetches an https URL, following up to five redirects.
      HTTP = lambda do |url, redirects = 5|
        require "net/http"
        uri = URI(url)
        raise Error, "refusing to download over #{uri.scheme}: #{url} (https only)" unless uri.scheme == "https"

        response = Net::HTTP.get_response(uri)
        case response
        when Net::HTTPSuccess then response.body.b
        when Net::HTTPRedirection
          raise Error, "too many redirects fetching #{url}" if redirects.zero?

          HTTP.call(uri.merge(response["location"]).to_s, redirects - 1)
        else raise Error, "HTTP #{response.code} fetching #{url}"
        end
      end

      attr_reader :into

      def initialize(into: DEFAULT_DIR, force: false, from: nil, fetcher: HTTP, out: nil)
        @into = into
        @force = force
        @from = from
        @fetcher = fetcher
        @out = out
        @archives = {}
      end

      # Installs one pack; returns { style => path }.
      def install(key)
        pack = Catalog.fetch(key)
        dir = File.join(@into, pack.key.to_s)
        entries = [*pack.files.values, pack.license_file]
        pending = entries.filter_map { |entry| [entry, File.join(dir, entry.last)] unless keep?(entry.last, dir) }
        verified = pending.map { |(url, sha, name), target| [target, verify(name, sha, read(url, name))] }
        verified.each { |target, bytes| write(target, bytes) }
        pack.files.transform_values { |(*, name)| File.join(dir, name) }
      end

      private

      def keep?(name, dir)
        target = File.join(dir, name)
        return false if @force || !File.exist?(target)

        say "exists #{target} (--force replaces it)"
        true
      end

      def read(url, name)
        source = source_name(url, name)
        return offline(source) if @from
        return File.binread(File.join(Bundled::DIR, source)) unless url

        location, member = url.split("#", 2)
        bytes = @archives[location] ||= fetch(location)
        member ? untar(bytes, location, member) { it == member } : bytes
      end

      def source_name(url, name) = url ? File.basename(url.split("#").last) : name

      def fetch(url)
        say "fetch #{url}"
        @fetcher.call(url)
      end

      def offline(source)
        if File.directory?(@from)
          path = Dir.glob("**/#{source}", base: @from).min or raise Error, "#{source} not found in #{@from}"
          File.binread(File.join(@from, path))
        else
          @archives[@from] ||= File.binread(@from)
          untar(@archives[@from], @from, source) { File.basename(it) == source }
        end
      end

      # The first file in a .tar.gz whose member name the block accepts.
      def untar(bytes, label, wanted)
        require "rubygems/package"
        require "stringio"
        require "zlib"
        tar = StringIO.new(Zlib::GzipReader.new(StringIO.new(bytes)).read)
        Gem::Package::TarReader.new(tar).each do |entry|
          return entry.read.b if entry.file? && yield(entry.full_name)
        end
        raise Error, "#{wanted} not found in #{label}"
      end

      def verify(name, sha, bytes)
        require "digest"
        actual = Digest::SHA256.hexdigest(bytes)
        return bytes if actual == sha

        raise Error, "SHA-256 mismatch for #{name}: expected #{sha}, got #{actual}; nothing written"
      end

      def write(target, bytes)
        require "fileutils"
        FileUtils.mkdir_p(File.dirname(target))
        temp = "#{target}.#{Process.pid}.tmp"
        File.binwrite(temp, bytes)
        File.rename(temp, target)
        say "wrote #{target}"
      ensure
        FileUtils.rm_f(temp) if temp
      end

      def say(line) = @out&.puts(line)
    end
  end
end
