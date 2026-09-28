# frozen_string_literal: true

module Stationery
  class CLI
    # `stationery render --png`: a picture of each page (Document#to_png,
    # pure Ruby) beside the PDF, named after it with the number of the page:
    # invoice.pdf, invoice-1.png, invoice-2.png. `--png-only` writes the
    # pictures without the PDF. One line per file says where it went.
    module Pictures
      PAGES = /\A\d+(-\d+)?(,\d+(-\d+)?)*\z/

      private

      def picture_options(opts)
        opts.on("--png", "Also write a PNG of each page beside the PDF (FILE-1.png, …)") { @options[:png] = true }
        opts.on("--png-only", "Write the PNGs and no PDF") { @options[:png] = @options[:png_only] = true }
        opts.on("--dpi DPI", Float, "Pixels per inch of the PNGs (default: #{Raster::Render::DPI})") do |dpi|
          @options[:dpi] = dpi
        end
        opts.on("--pages LIST", "The pages to picture, as 1,3-4 (default: all)") do |list|
          raise OptionParser::InvalidArgument, list unless list.match?(PAGES)

          @options[:pages] = list.split(",").flat_map { |part| Range.new(*part.split("-").map(&:to_i).minmax).to_a }
        end
      end

      # Renders the pictures, and writes them unless the render warns under
      # --strict. Answers whether they were written.
      def pictures(document, target)
        pngs = document.to_png(dpi: @options[:dpi], pages: @options[:pages], debug: @options[:debug] || false)
        return false if @options[:png_only] && !warnings_ok?(document)

        numbers = @options[:pages] || (1..pngs.size).to_a
        numbers.zip(pngs).each { |number, png| write_picture(png, target, number) }
        true
      rescue ArgumentError => e
        raise Error, e.message
      end

      def refuse_stdout(target)
        raise OptionParser::InvalidArgument, "--png writes files; --out - writes the PDF to stdout" if target == "-"
      end

      def write_picture(png, target, number)
        path = "#{target.delete_suffix(File.extname(target))}-#{number}.png"
        File.binwrite(path, png)
        width, height = png.byteslice(16, 8).unpack("NN")
        @out.puts "wrote #{path} (page #{number}, #{width} x #{height} px)"
      end
    end
  end
end
