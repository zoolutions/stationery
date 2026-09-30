# frozen_string_literal: true

require "json"
require "tmpdir"

module Stationery
  class CLI
    # `stationery verify FILE…`: reads each PDF in the engines viewers are
    # built on (Stationery::Verify) and fails when any of them errs, warns
    # or reads something other than the file holds. A Ruby file is rendered
    # first, as `render` finds its document. Needs the pdf-reader gem, and
    # at least one engine installed.
    class Verify < Render
      SUMMARY = "Check PDFs (or the documents Ruby files define) in the engines viewers are built on"

      def run(argv)
        parser.parse!(argv)
        return OK if @options[:help]
        raise OptionParser::MissingArgument, "FILE" if argv.empty?

        require "stationery/verify"
        verify(argv, engines)
      rescue OptionParser::ParseError => e
        @err.puts "stationery verify: #{e.message}", parser
        USAGE
      end

      private

      def parser
        @parser ||= OptionParser.new do |opts|
          opts.banner = "Usage: stationery verify FILE… [options]   (each FILE a .pdf, or a .rb defining a document)"
          opts.on("--engines LIST", Array, "The engines to run (default: every one installed): " \
                                           "#{%w[qpdf poppler mupdf pdfium pdfjs pdfkit].join(",")}") do |names|
            @options[:engines] = names
          end
          opts.on("--password PASSWORD", "The user password of encrypted files (other local processes can see",
                  "it on the command lines of Poppler and MuPDF)") { |password| @options[:password] = password }
          opts.on("--json", "Print the report as JSON") { @options[:json] = true }
          opts.on("-c", "--class NAME", "The document class to render when a Ruby FILE defines several") do |name|
            @options[:class] = name
          end
          opts.on("-h", "--help", "Show this help") do
            @out.puts opts
            @options[:help] = true
          end
        end
      end

      def engines
        Stationery::Verify.adapters(*[@options[:engines]].compact)
      rescue ArgumentError => e
        raise OptionParser::InvalidArgument, e.message
      end

      def verify(files, engines)
        installed!(engines)
        Dir.mktmpdir("stationery-verify") do |dir|
          labels = files.to_h { |file| [pdf(file, dir), file] }
          report = Stationery::Verify.run(labels.keys, engines:, password: @options[:password])
          report = report.with(results: report.results.map { |result| result.with(file: labels.fetch(result.file)) })
          @out.puts(@options[:json] ? JSON.pretty_generate(report.to_h) : report.lines)
          report.passed? ? OK : FAILURE
        end
      rescue Stationery::Error => e
        raise Error, e.message
      end

      def installed!(engines)
        missing = engines.reject(&:available?)
        return if missing.empty? || (!@options[:engines] && missing.size < engines.size)

        installs = missing.map { |engine| "#{engine.name} (#{engine.install})" }.join(", ")
        raise Error, "not installed: #{installs}" if @options[:engines]

        raise Error, "no engine is installed; install one of: #{installs}"
      end

      # The PDF to read for FILE: itself, or the render of the document a
      # Ruby FILE defines, written into `dir`.
      def pdf(file, dir)
        path = File.expand_path(file)
        raise Error, "no such file: #{file}" unless File.file?(path)
        return render_into(path, dir) if File.extname(path) == ".rb"
        raise Error, "not a PDF or a Ruby file: #{file}" unless File.binread(path, 5) == "%PDF-"

        path
      end

      def render_into(path, dir)
        document = instantiate(pick(load_documents(path), path))
        File.join(Dir.mktmpdir(nil, dir), "#{File.basename(path, ".rb")}.pdf").tap { |target| document.to_pdf(target) }
      end
    end

    register "verify", Verify
  end
end
