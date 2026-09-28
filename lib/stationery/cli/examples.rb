# frozen_string_literal: true

module Stationery
  class CLI
    # `stationery examples` lists the examples the gem ships, each with the
    # first sentence of its header comment; `stationery examples NAME` prints
    # where one is, and its source with `--source`.
    class Examples
      SUMMARY = "List the examples that ship with the gem, or print where one is"
      DIR = File.expand_path("../../../examples", __dir__)

      def initialize(out:, err:)
        @out = out
        @err = err
        @options = {}
      end

      def run(argv)
        parser.parse!(argv)
        return OK if @options[:help]

        name = argv.shift
        name ? show(name) : list
      rescue OptionParser::ParseError => e
        @err.puts "stationery examples: #{e.message}", parser
        USAGE
      end

      private

      def parser
        @parser ||= OptionParser.new do |opts|
          opts.banner = "Usage: stationery examples [NAME] [options]"
          opts.on("-s", "--source", "Print the source of NAME instead of its path") { @options[:source] = true }
          opts.on("-h", "--help", "Show this help") do
            @out.puts opts
            @options[:help] = true
          end
        end
      end

      def names = Dir.glob("**/*.rb", base: DIR).map { |file| file.delete_suffix(".rb") }.sort

      def list
        width = names.map(&:size).max.to_i
        names.each { |name| @out.puts "#{name.ljust(width)}  #{summary(name)}".rstrip }
        @out.puts "", "They are in #{DIR}; `stationery examples NAME` prints the path of one."
        OK
      end

      def show(name)
        name = name.delete_suffix(".rb")
        raise Error, "no example named #{name.inspect}; there are #{names.join(", ")}" unless names.include?(name)

        @options[:source] ? @out.write(File.read(path(name))) : @out.puts(path(name))
        OK
      end

      def path(name) = File.join(DIR, "#{name}.rb")

      # The first sentence of the comment that opens the file.
      def summary(name)
        comment = File.foreach(path(name), chomp: true).drop(2).take_while { |line| line.match?(/\A# *\S/) }
        text = comment.map { |line| line.delete_prefix("#").strip }.join(" ").sub(/\s*Run it.*\z/, "")
        (text[/\A.*?\.(?=\s|\z)/] || text).delete_suffix(":")
      end
    end

    register "examples", Examples
  end
end
