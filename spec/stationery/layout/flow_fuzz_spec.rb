# frozen_string_literal: true

# Random flows (spec/support/random_flow.rb) from a fixed list of seeds, on a
# page of 300 × 300 with a 20 pt margin. Nothing in them is taller than the
# page by itself, so nothing may be reported as an overflow, and what was
# written is on the pages once.
#
# A failure names its seeds. One of them is rendered again with
#
#   FLOW_FUZZ_SEEDS=17 bundle exec rspec spec/stationery/layout/flow_fuzz_spec.rb
RSpec.describe Stationery::Layout::Flow do
  def seeds
    ENV.fetch("FLOW_FUZZ_SEEDS", nil)&.split(",")&.map { |seed| Integer(seed) } || (1..120).to_a
  end

  def render(flow)
    document = Class.new(SpecDocument) do
      page size: [300, 300], margin: 20
      define_method(:view_template) { flow.write(self) }
    end.new
    [document.to_pdf, document.warnings.to_a]
  end

  def drawn(pdf, operator) = page_contents(pdf).sum { |content| content.scan(operator).size }

  def words_of(pdf)
    reader_for(pdf).pages.flat_map { |page| page.runs.flat_map { |run| run.text.scan(/w\d+/) } }
  end

  # What is wrong with the render of a flow, in words.
  def failures_of(flow, pdf, warnings)
    written = words_of(pdf)
    twice = written.tally.select { |_, count| count > 1 }.keys
    floats = { "floated boxes" => [drawn(pdf, "0.8667 0.8667 0.8667 rg"), flow.floats(:box)],
               "floated images" => [drawn(pdf, "/Im1 Do"), flow.floats(:image)] }
    [*warnings.map(&:message),
     ("misses #{(flow.words - written).first(5).join(" ")}" unless (flow.words - written).empty?),
     ("writes #{twice.first(5).join(" ")} more than once" unless twice.empty?),
     *floats.map { |name, (drawn, held)| "draws #{drawn} of #{held} #{name}" if drawn != held }].compact
  end

  it "paginates random flows without an overflow, every word and every float on a page once" do
    failures = seeds.flat_map do |seed|
      flow = RandomFlow.new(seed)
      failures_of(flow, *render(flow)).map { |failure| "seed #{seed}: #{failure}" }
    end

    expect(failures).to be_empty, failures.join("\n")
  end

  it "draws floats in most of the flows, and runs of them" do
    flows = seeds.map { |seed| RandomFlow.new(seed) }

    expect(flows.count { |flow| flow.floats(:box) + flow.floats(:image) > 2 }).to be > flows.size / 2
    expect(flows.sum { |flow| flow.floats(:image) }).to be > flows.size / 2
  end
end
