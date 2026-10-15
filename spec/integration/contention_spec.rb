# frozen_string_literal: true

# Whole renders from many threads and from many fibers of one Async reactor
# at once, every cache cold: the threads race to parse the font, decode the
# image and load the hyphenation patterns, under the caches' own locks, and
# every render writes the same bytes.
RSpec.describe "a full render under contention" do
  before do
    Stationery::Images::Cache.clear
    Stationery::Fonts::Registry.clear
  end

  let(:subject_call) { -> { CanaryDocuments.pinned { CanaryDocuments::Report.new.to_pdf } } }

  it_behaves_like "thread-safe under contention", threads: 8, iterations: 3, consistent: :equal
  it_behaves_like "fiber-safe under an Async reactor", fibers: 8, iterations: 3, consistent: :equal
end
