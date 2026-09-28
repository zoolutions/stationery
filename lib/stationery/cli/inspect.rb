# frozen_string_literal: true

require "json"
require "pathname"

module Stationery
  class CLI
    # `stationery inspect FILE`: prints what is on each page of a PDF as
    # text (see Testing::Inspector#layout), for an agent that cannot read a
    # picture and for a diff between two renders. A Ruby file is rendered
    # first, as `render` finds its document, and its warnings are printed.
    # Needs the pdf-reader gem.
    class Inspect < Render
      SUMMARY = "Print what is on each page of a PDF (or of the document a Ruby file defines) as text"

      def run(argv)
        parser.parse!(argv)
        return OK if @options[:help]

        file = argv.shift or raise OptionParser::MissingArgument, "FILE"
        inspect_file(file)
      rescue OptionParser::ParseError => e
        @err.puts "stationery inspect: #{e.message}", parser
        USAGE
      end

      private

      def parser
        @parser ||= OptionParser.new do |opts|
          opts.banner = "Usage: stationery inspect FILE [options]   (FILE a .pdf, or a .rb defining a document)"
          opts.on("--json", "Print the layout as JSON") { @options[:json] = true }
          opts.on("-c", "--class NAME", "The document class to render when a Ruby FILE defines several") do |name|
            @options[:class] = name
          end
          opts.on("-h", "--help", "Show this help") do
            @out.puts opts
            @options[:help] = true
          end
        end
      end

      def inspect_file(file)
        path = File.expand_path(file)
        raise Error, "no such file: #{file}" unless File.file?(path)

        require "stationery/testing/inspector"
        layout = Testing::Inspector.new(subject(path)).layout
        @out.puts(@options[:json] ? JSON.pretty_generate(layout) : LayoutText.new(layout).lines(file))
        OK
      rescue Stationery::Error => e
        raise Error, e.message
      end

      def subject(path)
        return instantiate(pick(load_documents(path), path)) if File.extname(path) == ".rb"
        raise Error, "not a PDF or a Ruby file: #{path}" unless File.binread(path, 5) == "%PDF-"

        Pathname(path)
      end
    end

    register "inspect", Inspect
  end
end
