# frozen_string_literal: true

# Streams the gem's examples/ documents as live PDFs (/examples/invoice.pdf),
# rendered by the checked-out gem itself. Each example is rendered once per
# process and again only when its source file changes, so the page's links
# cost one render per deploy, not one per click.
class ExamplesController < ApplicationController
  ROOT = SourceMarkdown::ROOT.join("examples")
  CACHE = {} # written only under LOCK
  LOCK = Mutex.new

  def show
    name = params[:name].to_s
    return head(:not_found) unless self.class.names.include?(name)

    send_data self.class.pdf(name), type: "application/pdf", disposition: "inline", filename: "#{name}.pdf"
  end

  class << self
    def names = ROOT.glob("*.rb").map { |file| file.basename(".rb").to_s }.sort

    def pdf(name)
      file = ROOT.join("#{name}.rb")
      LOCK.synchronize do
        entry = CACHE[name]
        return entry[:pdf] if entry && entry[:mtime] == file.mtime

        CACHE[name] = { mtime: file.mtime, pdf: render(file) }
        CACHE[name][:pdf]
      end
    end

    private

    # Every example defines `Example<Name>` with a `preview` that builds it
    # from sample data, the same entry point `stationery render` uses.
    def render(file)
      load file.to_s
      Object.const_get(class_name(file)).preview.to_pdf
    end

    def class_name(file) = "Example#{file.basename(".rb").to_s.split("_").map(&:capitalize).join}"
  end
end
