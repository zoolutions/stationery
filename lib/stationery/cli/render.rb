# frozen_string_literal: true

module Stationery
  class CLI
    # `stationery render FILE`: loads a Ruby file, finds the Document it
    # defines and writes its PDF, or with `--zpl` its labels in ZPL at
    # `--dpi`. A document whose constructor needs arguments renders from
    # `def self.preview` returning an instance.
    class Render
      include Pictures

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
          opts.on("--zpl", "Write ZPL for a label printer (default: FILE.zpl) instead") { @options[:zpl] = true }
          opts.on("--dpi DPI", Integer, "Dots per inch: the label printer's for --zpl (152, 203, 300 or 600),",
                  "the PNGs' for --png (default: #{Raster::Render::DPI})") do |dpi|
            @options[:dpi] = dpi
          end
          opts.on("--strict", "Fail without writing when layout reports warnings") { @options[:strict] = true }
          opts.on("--debug", "Render with debug: true when the document supports it") { @options[:debug] = true }
          picture_options(opts)
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
        extension = @options[:zpl] ? "zpl" : "pdf"
        target = @options[:out] || File.join(File.dirname(path), "#{File.basename(path, ".*")}.#{extension}")
        refuse_stdout(target) if @options[:png]
        return pictures(document, target) ? OK : FAILURE if @options[:png_only]

        output = @options[:zpl] ? to_zpl(document) : to_pdf(document)
        return FAILURE unless warnings_ok?(document)

        write(output, target)
        pictures(document, target) if @options[:png]
        OK
      end

      # Documents that are new after loading FILE or that it defines (so a
      # file already loaded by the host still resolves).
      def load_documents(path)
        before = descendants(Document)
        load(path)
        after = descendants(Document)
        (after - before) | after.select { |klass| defined_in?(klass, path) }
      end

      def pick(candidates, path)
        return named_class if @options[:class]

        candidates = local(candidates.reject { |klass| template_file(klass).nil? }, path)
        raise Error, "no Stationery::Document defined in #{path}" if candidates.empty?
        return candidates.first if candidates.one?

        names = candidates.map(&:name).sort.join(", ")
        raise Error, "several documents defined in #{path} (#{names}); choose one with --class NAME"
      end

      # The documents FILE itself defines, when it also loaded others (a
      # document extending one from a file it requires).
      def local(candidates, path)
        defined_here = candidates.select { |klass| defined_in?(klass, path) }
        defined_here.any? ? defined_here : candidates
      end

      # Whether FILE opens the class or holds its own view_template.
      def defined_in?(klass, path)
        method = klass.instance_method(:view_template)
        return true if method.owner == klass && method.source_location&.first == path

        !klass.name.nil? && Object.const_source_location(klass.name)&.first == path
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

      def to_zpl(document)
        document.to_zpl(dpi: @options[:dpi], debug: @options.fetch(:debug, false))
      rescue ArgumentError, WarningsError => e
        raise Error, e.message
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
          @out.puts "wrote #{target} (#{count(pdf)}, #{pdf.bytesize} bytes)"
        end
      end

      # "1 page", "3 labels": what the file holds.
      def count(output)
        name = @options[:zpl] ? "label" : "page"
        count = output.scan(@options[:zpl] ? "^XA" : %r{/Type /Page\b}).size
        "#{count} #{name}#{"s" unless count == 1}"
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
