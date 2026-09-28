# frozen_string_literal: true

RSpec.describe Stationery::Layout::Paginator do
  def footers(normal, last)
    entries = [normal, last].zip(%i[all last]).map do |height, on|
      Stationery::Region.new(slot: :footer, height:, gap: 0, on:, block: nil)
    end
    Stationery::Regions.new(entries, measure: ->(*) { raise "measured" })
  end

  def paginate(root, regions)
    described_class.new(resources: Stationery::Resources.new, page: { size: [300, 200], margin: 20 }, regions:)
                   .paginate(root)
  end

  it "hands each page to a block as soon as it is painted, before the next one is" do
    seen = []
    paginator = described_class.new(resources: Stationery::Resources.new, page: { size: [300, 200], margin: 20 })

    pages = paginator.paginate(flow(lines_of(30))) do |page|
      seen << [page, page.content.scan("BT").size]
      page.content.clear
    end

    expect(seen.map(&:first)).to eq(pages)
    expect(seen.map(&:last)).to eq([11, 11, 8])
    expect(pages.map(&:content)).to all(be_empty)
  end

  it "splits once per page when the last page reserves the same space" do
    root = flow(lines_of(3))
    allow(root).to receive(:split).and_call_original

    paginate(root, footers(10, 10))

    expect(root).to have_received(:split).once
  end

  it "tries the last page's box first when it reserves more" do
    root = flow(lines_of(3))
    allow(root).to receive(:split).and_call_original

    pages = paginate(root, footers(10, 60))

    expect(root).to have_received(:split).once
    expect(pages.map(&:reserve)).to eq([[0, 60]])
  end

  it "adds a page when the content fits the normal box but not the last one" do
    pages = paginate(flow(lines_of(8)), footers(10, 60))

    expect(pages.map(&:reserve)).to eq([[0, 10], [0, 60]])
  end

  it "keeps filling normal pages until the rest fits the last one" do
    pages = paginate(flow(lines_of(20)), footers(10, 60))

    expect(pages.map(&:reserve)).to eq([[0, 10], [0, 10], [0, 60]])
  end
end
