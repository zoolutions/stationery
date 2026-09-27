# frozen_string_literal: true

module Stationery
  class CLI
    # `stationery render FILE`: loads a Ruby file, finds the Document it
    # defines and writes its PDF. A document whose constructor needs
    # arguments renders from `def self.preview` returning an instance.
    class Render
      SUMMARY = "Render the Stationery::Document defined in a Ruby file to PDF"

      def initialize(out:, err:)
        @out = out
        @err = err
        @options = {}
      end

      def run(argv)
        parser.parse!(argv)
        return OK if @options[:help]

        file = argv.shift or raise OptionParser::MissingArgument, "FILE"
        render(file)
      rescue OptionParser::ParseError => e
        @err.puts "stationery render: #{e.message}", parser
        USAGE
      end

      private

      def parser
        @parser ||= OptionParser.new do |opts|
          opts.banner = "Usage: stationery render FILE [options]"
          opts.on("-o", "--out PATH", "Where to write the PDF (default: FILE.pdf); - writes to stdout") do |path|
            @options[:out] = path
          end
          opts.on("-c", "--class NAME", "The document class to render when FILE defines several") do |name|
            @options[:class] = name
          end
          opts.on("--strict", "Fail without writing when layout reports warnings") { @options[:strict] = true }
          opts.on("--debug", "Render with debug: true when the document supports it") { @options[:debug] = true }
          opts.on("-h", "--help", "Show this help") do
            @out.puts opts
            @options[:help] = true
          end
        end
      end

      def render(file)
        path = File.expand_path(file)
        raise Error, "no such file: #{file}" unless File.file?(path)

        document = instantiate(pick(load_documents(path), path))
        pdf = to_pdf(document)
        return FAILURE unless warnings_ok?(document)

        write(pdf, @options[:out] || File.join(File.dirname(path), "#{File.basename(path, ".*")}.pdf"))
        OK
      end

      # Documents that are new after loading FILE or whose view_template lives
      # in it (so a file already loaded by the host still resolves).
      def load_documents(path)
        before = descendants(Document)
        load(path)
        after = descendants(Document)
        (after - before) | after.select { |klass| template_file(klass) == path }
      end

      def pick(candidates, path)
        return named_class if @options[:class]

        candidates = candidates.reject { |klass| template_file(klass).nil? }
        raise Error, "no Stationery::Document defined in #{path}" if candidates.empty?
        return candidates.first if candidates.one?

        names = candidates.map(&:name).sort.join(", ")
        raise Error, "several documents defined in #{path} (#{names}); choose one with --class NAME"
      end

      def named_class
        klass = Object.const_get(@options[:class])
        raise Error, "#{klass} is not a Stationery::Document" unless klass.is_a?(Class) && klass < Document

        klass
      rescue NameError => e
        raise Error, e.message
      end

      def instantiate(klass)
        return klass.preview if klass.respond_to?(:preview)

        begin
          klass.new
        rescue ArgumentError
          raise Error, "#{klass} needs arguments; define `def self.preview` returning an instance to render"
        end
      end

      def to_pdf(document)
        return document.to_pdf unless @options[:debug]
        return document.to_pdf(debug: true) if document.method(:to_pdf).parameters.include?(%i[key debug])

        @err.puts "note: --debug is not supported by this version of Stationery; rendering without it"
        document.to_pdf
      end

      def warnings_ok?(document)
        warnings = Array(document.warnings)
        warnings.each { |warning| @err.puts "warning: #{warning.message}" }
        return true unless @options[:strict] && warnings.any?

        @err.puts "stationery render: #{warnings.size} warning(s) under --strict; nothing written"
        false
      end

      def write(pdf, target)
        if target == "-"
          @out.binmode
          @out.write(pdf)
        else
          File.binwrite(target, pdf)
          pages = pdf.scan(%r{/Type /Page\b}).size
          @out.puts "wrote #{target} (#{pages} #{pages == 1 ? "page" : "pages"}, #{pdf.bytesize} bytes)"
        end
      end

      def descendants(klass) = klass.subclasses.flat_map { |sub| [sub, *descendants(sub)] }

      def template_file(klass)
        method = klass.instance_method(:view_template)
        method.source_location&.first unless method.owner == Component
      end
    end

    register "render", Render
  end
end
