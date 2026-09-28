# frozen_string_literal: true

require "rails_helper"

# /examples/<name>.pdf renders the gem's examples inside the docs image, so
# every file an example reads must be in the build context. The image leaves
# the gem's spec/ out; whatever an example takes from there has to be
# re-included in docs/Dockerfile.dockerignore.
RSpec.describe "docs image build context" do # rubocop:disable RSpec/DescribeClass
  root = SourceMarkdown::ROOT
  ignore = root.join("docs/Dockerfile.dockerignore").read

  root.glob("examples/*.rb").each do |example|
    example.read.scan(%r{"\.\./(spec/[\w/.-]+)"}).flatten.uniq.each do |path|
      it "keeps #{path} (read by examples/#{example.basename}) in the image" do
        expect(root.join(path)).to exist
        expect(ignore).to include("!/#{path.chomp("/")}/")
      end
    end
  end
end
