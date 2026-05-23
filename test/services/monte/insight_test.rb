require "test_helper"

module Monte
  class InsightTest < ActiveSupport::TestCase
    Stub = Struct.new(:insight_key)

    def results(median_a:, median_b:, p5_a:, p95_a: 0)
      { median_a: median_a, median_b: median_b, p5_a: p5_a, p95_a: p95_a,
        win_rate_a: 50, p5_b: 0, p95_b: 0, steps: 60, chart: {} }
    end

    def insight(key, amount: 50_000, **result_overrides)
      Insight.call(Stub.new(key), results(**result_overrides), amount: amount)
    end

    def money_segment?(copy, role, value)
      copy.segments.any? { |s| s.money && s.emphasis == role && s.value == value }
    end

    # --- stocks_vs_cash -----------------------------------------------------

    test "stocks_vs_cash, downside below starting capital: warns about real loss" do
      copy = insight("stocks_vs_cash", amount: 50_000, median_a: 70_000, median_b: 62_000, p5_a: 40_000)
      assert_match(/worst 5% of futures/, copy.to_s)
      assert money_segment?(copy, :cash, 40_000)
      assert money_segment?(copy, :neutral, 50_000)
    end

    test "stocks_vs_cash, downside holds capital but trails cash: softer framing" do
      copy = insight("stocks_vs_cash", amount: 50_000, median_a: 70_000, median_b: 62_000, p5_a: 55_000)
      assert_match(/roughly holds its value/, copy.to_s)
      assert money_segment?(copy, :neutral, 55_000)
    end

    test "stocks_vs_cash, B wins median (drift): risk premium has thinned" do
      copy = insight("stocks_vs_cash", amount: 50_000, median_a: 60_000, median_b: 62_000, p5_a: 40_000)
      assert_match(/premium for taking risk has thinned/, copy.to_s)
      assert money_segment?(copy, :cash, 62_000)
      assert money_segment?(copy, :growth, 60_000)
    end

    # --- lump_vs_dca --------------------------------------------------------

    test "lump_vs_dca, A wins median: time-in-the-market with close tails" do
      copy = insight("lump_vs_dca", median_a: 69_000, median_b: 67_000, p5_a: 41_000, p95_a: 132_000)
      assert_match(/time in the market/, copy.to_s)
      assert money_segment?(copy, :growth, 41_000)
      assert money_segment?(copy, :growth, 132_000)
    end

    test "lump_vs_dca, B wins median (drift): the slow approach won" do
      copy = insight("lump_vs_dca", median_a: 66_000, median_b: 68_000, p5_a: 40_000)
      assert_match(/slow approach won/, copy.to_s)
      assert money_segment?(copy, :cash, 68_000)
    end

    # --- invest_vs_debt -----------------------------------------------------

    test "invest_vs_debt, bad run trails the payoff (seeded default): guaranteed-return framing" do
      copy = insight("invest_vs_debt", amount: 20_000, median_a: 21_000, median_b: 27_000, p5_a: 9_000)
      assert_match(/guaranteed return/, copy.to_s)
      assert money_segment?(copy, :growth, 21_000)
      assert money_segment?(copy, :cash, 9_000)
      assert money_segment?(copy, :neutral, 27_000)
    end

    test "invest_vs_debt, even the bad run clears the payoff: maths favours investing" do
      copy = insight("invest_vs_debt", amount: 20_000, median_a: 40_000, median_b: 27_000, p5_a: 30_000)
      assert_match(/clear the bar set by paying off the debt/, copy.to_s)
      assert_match(/favours keeping the loan/, copy.to_s)
    end

    # --- dispatch -----------------------------------------------------------

    test "raises on an unknown or nil insight_key" do
      assert_raises(ArgumentError) do
        Insight.call(Stub.new("nope"), results(median_a: 1, median_b: 1, p5_a: 1), amount: 1)
      end
      assert_raises(ArgumentError) do
        Insight.call(Stub.new(nil), results(median_a: 1, median_b: 1, p5_a: 1), amount: 1)
      end
    end
  end
end
