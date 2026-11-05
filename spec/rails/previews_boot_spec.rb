# frozen_string_literal: true

require_relative "spec_helper"
require "json"
require "open3"
require "tmpdir"

# Each example boots an app of its own in a fresh process
# (spec/fixtures/rails/boot_app.rb): the app of spec_helper has booted
# already, and a constant once defined stays defined.
RSpec.describe Stationery::Railtie, ".add_previews" do
  let(:root) { Dir.mktmpdir }
  let(:script) { File.expand_path("../fixtures/rails/boot_app.rb", __dir__) }
  let(:lib) { File.expand_path("../../lib", __dir__) }

  after { FileUtils.remove_entry(root) }

  def boot(show_previews:)
    write("app/helpers/application_helper.rb", "module ApplicationHelper; end\n")
    write("config/initializers/touch_controller.rb", "ActionController::Base\n")
    report = File.join(root, "report.json")
    output, status = Open3.capture2e(RbConfig.ruby, "-I#{lib}", script, root, show_previews.to_s, report, chdir: root)
    raise "the app did not boot:\n#{output}" unless status.success?

    JSON.parse(File.read(report))
  end

  def write(path, content)
    FileUtils.mkdir_p(File.dirname(File.join(root, path)))
    File.write(File.join(root, path), content)
  end

  context "with previews on" do
    subject(:report) { boot(show_previews: true) }

    it "boots when ActionController::Base loads during boot, and defines the controller only when asked for" do
      expect(report["autoload"]).to end_with("stationery/rails/previews_controller")
    end

    it "serves the index and a preview with the app's helpers" do
      expect(report).to include("routed" => true, "index" => 200, "pdf" => 200, "pdf_body" => "%PDF", "helpers" => true)
    end
  end

  context "with previews off" do
    subject(:report) { boot(show_previews: false) }

    it "neither autoloads nor routes the controller" do
      expect(report).to include("autoload" => nil, "routed" => false, "index" => "unrouted", "pdf" => "unrouted")
    end
  end
end
