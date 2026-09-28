# frozen_string_literal: true

RSpec.describe Stationery::Layout::Columns::Leveller do
  let(:pour_class) { Stationery::Layout::Columns::Pour }
  let(:balancer) { Stationery::Layout::Columns::Balancer }

  # The columns filled in order at the balanced height: what is levelled.
  def balance(content, count: 3, **) = balancer.new(pour_class.new(content, 120, count), **).call

  def level(content, count: 3, limit: Float::INFINITY, **)
    pour = pour_class.new(content, 120, count)
    described_class.new(pour, limit:).call(balancer.new(pour, limit:, **).call)
  end

  def lines_in(poured) = poured.columns.map { |column| (column.measure(120) / line_height).round }
  def heights_of(poured) = poured.columns.map { |column| column.measure(120).round(3) }
  def sizes_of(poured) = poured.columns.map { |column| column.children.size }
  def fixed(height) = Stationery::Layout::Box.new(flow(text_node("box")), height:)
  def heading = text_node("Heading").tap { |node| node.keep_with_next = true }

  def whole(lines)
    Stationery::Layout::Box.new(flow(lines_of(lines, prefix: "boxed"))).tap { |node| node.break_inside = :avoid }
  end

  # Every column takes its share of what is left, rounded up to a line.
  def shares(lines, count)
    Array.new(count) { |index| (lines / (count - index).to_f).ceil.tap { |taken| lines -= taken } }.reject(&:zero?)
  end

  describe "equal lines" do
    it "gives the earlier columns what cannot be shared" do
      expect(lines_in(balance(flow(lines_of(10))))).to eq([4, 4, 2])
      expect(lines_in(level(flow(lines_of(10))))).to eq([4, 3, 3])
      expect(lines_in(level(flow(lines_of(11))))).to eq([4, 4, 3])
      expect(lines_in(level(flow(lines_of(9))))).to eq([3, 3, 3])
    end

    it "leaves two columns as they are" do
      expect(lines_in(level(flow(lines_of(7)), count: 2))).to eq([4, 3])
      expect(sizes_of(level(flow(*Array.new(5) { |index| text_node("item #{index}") }), count: 2))).to eq([3, 2])
    end

    it "leaves one column and an empty flow as they are" do
      expect(lines_in(level(flow(lines_of(5)), count: 1))).to eq([5])
      expect(level(flow).columns).to be_empty
    end

    it "leaves columns empty when there are fewer lines than columns" do
      expect(lines_in(level(flow(lines_of(2)), count: 4))).to eq([1, 1])
    end

    it "shares any number of lines among any number of columns" do
      (1..5).each do |count|
        (1..17).each do |lines|
          expect(lines_in(level(flow(lines_of(lines)), count:))).to eq(shares(lines, count)), "#{lines} in #{count}"
        end
      end
    end
  end

  describe "the height" do
    it "is that of the columns filled in order" do
      (3..5).each do |count|
        (1..17).each do |lines|
          content = flow(lines_of(lines, orphans: 2, widows: 2), spacer(6), fixed(20), lines_of(3, prefix: "end"))
          expected = balance(content, count:).height(120)

          expect(level(content, count:).height(120)).to be_within(0.0001).of(expected), "#{lines} in #{count}"
        end
      end
    end

    it "keeps the columns filled in order when levelling would make the block shorter" do
      pour = pour_class.new(flow(whole(3), whole(3), lines_of(4)), 120, 3)
      poured = pour.call(5 * line_height)

      expect(lines_in(poured)).to eq([3, 5, 2])
      expect(lines_in(balancer.new(pour.first(5 * line_height).last).call)).to eq([4, 3])
      expect(described_class.new(pour).call(poured)).to equal(poured)
    end

    it "keeps the columns filled in order when a column comes back taller" do
      pour = pour_class.new(flow(lines_of(10)), 120, 3)
      poured = balancer.new(pour).call
      allow(pour).to receive(:first)
        .and_return([flow(lines_of(5, prefix: "tall")), pour_class.new(flow(lines_of(5, prefix: "rest")), 120, 2)])

      expect(described_class.new(pour).call(poured)).to equal(poured)
    end
  end

  describe "unequal heights" do
    it "shares children of unequal heights" do
      content = flow(fixed(10), fixed(10), fixed(10), fixed(25), fixed(5))

      expect(heights_of(balance(content))).to eq([30, 30])
      expect(heights_of(level(content))).to eq([30, 25, 5])
    end

    it "shares lines of unequal heights" do
      large = Stationery::Text::Markup.parse("large", base_style(size: 20))
      lines = Array.new(4) { text_node("small") } + Array.new(5) { Stationery::Layout::Text.new(large, context: ctx) }

      expect(sizes_of(balance(flow(*lines)))).to eq([5, 3, 1])
      expect(sizes_of(level(flow(*lines)))).to eq([5, 2, 2])
      expect(heights_of(level(flow(*lines)))).to eq([(4 * line_height) + line_height(20), 2 * line_height(20),
                                                     2 * line_height(20)].map { |height| height.round(3) })
    end

    it "keeps the columns filled in order when levelling would make a later one the taller" do
      content = flow(fixed(25), fixed(20), fixed(5), fixed(18))

      expect(heights_of(balance(flow(fixed(20), fixed(5), fixed(18)), count: 2))).to eq([20, 23])
      expect(heights_of(level(content))).to eq([25, 25, 18])
    end

    it "levels columns that were not in descending order to begin with" do
      content = flow(fixed(20), fixed(30), fixed(10), fixed(10), fixed(10), fixed(10), fixed(10))

      expect(heights_of(balance(content, count: 4))).to eq([20, 30, 30, 20])
      expect(heights_of(level(content, count: 4))).to eq([20, 30, 30, 20])
      expect(heights_of(balance(content, count: 5))).to eq([20, 30, 30, 20])
      expect(heights_of(level(content, count: 5))).to eq([20, 30, 20, 20, 10])
    end
  end

  describe "break rules" do
    it "honours orphans and widows of two" do
      expect(lines_in(level(flow(lines_of(10, orphans: 2, widows: 2))))).to eq([4, 3, 3])
      expect(lines_in(level(flow(lines_of(9, orphans: 2, widows: 2)), count: 4))).to eq([3, 2, 2, 2])
    end

    it "keeps the lines orphans and widows hold together, however uneven the columns" do
      content = flow(lines_of(6), lines_of(4, prefix: "kept", orphans: 4))

      expect(lines_in(balance(content))).to eq([4, 2, 4])
      expect(lines_in(level(content))).to eq([4, 2, 4])
      expect(lines_in(level(flow(lines_of(5), lines_of(5, prefix: "kept", widows: 5))))).to eq([5, 5])
    end

    it "keeps a heading with the start of what follows it" do
      title = heading
      poured = level(flow(lines_of(5), title, lines_of(4, prefix: "body")))

      expect(lines_in(poured)).to eq([4, 3, 3])
      expect(poured.columns[1].children[1]).to equal(title)
      expect(sizes_of(poured)).to eq([1, 3, 1])
    end

    it "does not leave a heading at the end of a column" do
      title = heading
      poured = level(flow(lines_of(6), title, lines_of(3, prefix: "body")))

      expect(lines_in(poured)).to eq([4, 4, 2])
      expect(poured.columns[1].children[1]).to equal(title)
      expect(sizes_of(poured)).to eq([1, 3, 1])
    end

    it "moves a box that avoids breaking whole" do
      box = whole(3)
      poured = level(flow(lines_of(4), box, lines_of(3, prefix: "last")))

      expect(lines_in(balance(flow(lines_of(4), box, lines_of(3, prefix: "last"))))).to eq([4, 4, 2])
      expect(lines_in(poured)).to eq([4, 3, 3])
      expect(poured.columns[1].children).to eq([box])
    end

    it "keeps the columns as they are around a box nothing can be moved past" do
      box = whole(4)
      poured = level(flow(lines_of(3), box, lines_of(3, prefix: "last")))

      expect(lines_in(poured)).to eq([3, 4, 3])
      expect(poured.columns[1].children).to eq([box])
    end

    it "drops a spacer at a column break, as a pour in order does" do
      poured = level(flow(lines_of(4), spacer(8), lines_of(3, prefix: "b"), spacer(8), lines_of(3, prefix: "c")))

      expect(lines_in(poured)).to eq([4, 3, 3])
    end
  end

  describe "at the height of a page" do
    it "levels the columns of a page that is full" do
      pour = pour_class.new(flow(lines_of(13)), 120, 3)
      fallback = pour.call(5 * line_height, fresh: true)

      expect(lines_in(fallback)).to eq([5, 5, 3])
      expect(lines_in(level(flow(lines_of(13)), limit: 5 * line_height, fallback:))).to eq([5, 4, 4])
    end

    it "leaves a pour that did not place everything as it is" do
      pour = pour_class.new(flow(lines_of(20)), 120, 3)
      poured = pour.call(5 * line_height)

      expect(described_class.new(pour, limit: 5 * line_height).call(poured)).to equal(poured)
    end

    it "keeps the columns filled in order when what the first one leaves cannot be poured again" do
      tall = fixed(100)
      pour = pour_class.new(flow(lines_of(4), tall, text_node("after")), 120, 3)
      poured = pour.call(60, fresh: true)

      expect(heights_of(poured)).to eq([(4 * line_height).round(3), 100, line_height.round(3)])
      expect(described_class.new(pour, limit: 60).call(poured)).to equal(poured)
    end

    it "keeps the columns filled in order when the first one cannot be cut again" do
      pour = pour_class.new(flow(fixed(100), lines_of(6)), 120, 3)
      poured = pour.call(60, fresh: true)

      expect(heights_of(poured)).to eq([100, (4 * line_height).round(3), (2 * line_height).round(3)])
      expect(described_class.new(pour, limit: 60).call(poured)).to equal(poured)
    end
  end

  describe "the work" do
    def counting_pours
      pours = 0
      allow(pour_class).to receive(:new).and_wrap_original do |original, *arguments|
        original.call(*arguments).tap do |pour|
          allow(pour).to receive(:call).and_wrap_original do |call, *heights, **options|
            pours += 1
            call.call(*heights, **options)
          end
        end
      end
      yield
      pours
    end

    it "is one search for every column after the first, two columns needing none" do
      content = flow(lines_of(41, orphans: 2, widows: 2))
      balancing = counting_pours { balance(content, count: 4) }
      levelling = counting_pours { level(content, count: 4) } - balancing

      expect(balancing).to be <= balancer::MAX_PROBES + 1
      expect(levelling).to be_between(2, 2 * (balancer::MAX_PROBES + 1))
      expect(counting_pours { level(content, count: 2) }).to eq(counting_pours { balance(content, count: 2) })
    end

    it "ends when no pour places everything" do
      pour = pour_class.new(flow(lines_of(10)), 120, 3)
      poured = balancer.new(pour).call
      stubborn = pour_class.new(flow(lines_of(6)), 120, 2)
      allow(stubborn).to receive(:call).and_return(stubborn.call(line_height))
      allow(pour).to receive(:first).and_return([flow(lines_of(4)), stubborn])

      expect(described_class.new(pour).call(poured)).to equal(poured)
      expect(stubborn).to have_received(:call).at_most(balancer::MAX_PROBES + 1).times
    end

    it "wraps each paragraph once per width" do
      allow(Stationery::Text::Wrapper).to receive(:new).and_call_original

      level(flow(lines_of(30)), count: 4)

      expect(Stationery::Text::Wrapper).to have_received(:new).once
    end
  end
end
