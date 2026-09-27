# frozen_string_literal: true

module Stationery
  class CLI
    # `stationery fonts list` and `stationery fonts install PACK...`: copies
    # pinned, SHA-256-checked font packs into vendor/fonts/<pack>/.
    class Fonts
      SUMMARY = "List or install font packs (Noto, Liberation, Inter) into vendor/fonts"
      RESERVED_NAME_NOTE = 'Liberation fonts carry the Reserved Font Name "Liberation": copying them unmodified ' \
                           "is fine; a modified copy must be renamed."

      def initialize(out:, err:)
        @out = out
        @err = err
        @options = { into: Stationery::Fonts::DEFAULT_DIR, force: false, from: nil }
      end

      def run(argv)
        parser.parse!(argv)
        return OK if @options.delete(:help)

        case argv.shift
        when "list" then list
        when "install"
          raise OptionParser::MissingArgument, "PACK" if argv.empty?

          install(argv)
        else usage
        end
      rescue OptionParser::ParseError => e
        @err.puts "stationery fonts: #{e.message}"
        usage
      rescue Stationery::Error => e
        raise Error, e.message
      end

      private

      def parser
        @parser ||= OptionParser.new do |opts|
          opts.banner = "Usage: stationery fonts list [--into DIR]\n       " \
                        "stationery fonts install PACK... [--into DIR] [--force] [--from PATH]"
          opts.on("--into DIR", "Where packs live (default: #{Stationery::Fonts::DEFAULT_DIR})") do |dir|
            @options[:into] = dir
          end
          opts.on("--force", "Replace files that are already installed") { @options[:force] = true }
          opts.on("--from PATH", "Install offline from a directory or .tar.gz holding the files") do |path|
            @options[:from] = path
          end
          opts.on("-h", "--help", "Show this help") do
            @out.puts opts
            @options[:help] = true
          end
        end
      end

      def usage
        @err.puts parser
        USAGE
      end

      def list
        rows = Stationery::Fonts.catalog.map do |pack|
          installed = File.file?(Stationery::Fonts.paths(pack.key, dir: @options[:into]).fetch(:regular))
          [pack.key.to_s, pack.family, pack.license, installed ? "installed" : "-"]
        end
        widths = rows.transpose.map { |column| column.map(&:size).max }
        rows.each { |row| @out.puts row.zip(widths).map { |cell, width| cell.ljust(width) }.join("  ").rstrip }
        @out.puts "", RESERVED_NAME_NOTE
        OK
      end

      def install(keys)
        installer = Stationery::Fonts::Installer.new(**@options, out: @out)
        keys.each do |key|
          installer.install(key)
          @out.puts "", "Use it with:", *Stationery::Fonts.usage(key, @options[:into]).map { "  #{it}" }
        end
        OK
      end
    end

    register "fonts", Fonts
  end
end
