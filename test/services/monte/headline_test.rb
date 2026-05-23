require "test_helper"

module Monte
  class HeadlineTest < ActiveSupport::TestCase
    Stub = Struct.new(:headline_key)

    # A minimal result hash; per-test overrides set the keys each branch reads.
    def results(median_a:, median_b:, win_rate_a:)
      { median_a: median_a, median_b: median_b, win_rate_a: win_rate_a,
        p5_a: 0, p95_a: 0, p5_b: 0, p95_b: 0, steps: 60, chart: {} }
    end

    def headline(key, **result_overrides)
      Headline.call(Stub.new(key), results(**result_overrides))
    end

    # Did any segment with this emphasis carry the given text?
    def emphasised(copy, role, text)
      copy.segments.any? { |s| s.emphasis == role && s.value == text }
    end

    # --- stocks_vs_cash -----------------------------------------------------

    test "stocks_vs_cash, A wins median: investing-beats-cash framing with green win rate" do
      copy = headline("stocks_vs_cash", median_a: 70_000, median_b: 62_000, win_rate_a: 63)
      assert_match(/Investing beats cash in 63% of futures/, copy.to_s)
      assert emphasised(copy, :growth, "63%")
      assert emphasised(copy, :cash, "37%")
    end

    test "stocks_vs_cash, B wins median (drift): does not claim investing beats cash" do
      copy = headline("stocks_vs_cash", median_a: 60_000, median_b: 62_000, win_rate_a: 48)
      assert_match(/cash comes out ahead/, copy.to_s)
      refute_match(/Investing beats cash/, copy.to_s)
    end

    # --- lump_vs_dca --------------------------------------------------------

    test "lump_vs_dca, A wins median with confident win rate: ends-ahead framing" do
      copy = headline("lump_vs_dca", median_a: 69_000, median_b: 67_000, win_rate_a: 61)
      assert_match(/ends ahead of spreading it out in 61% of futures/, copy.to_s)
      assert emphasised(copy, :growth, "61%")
    end

    test "lump_vs_dca, A wins median but near coin-flip: neck-and-neck framing" do
      copy = headline("lump_vs_dca", median_a: 69_000, median_b: 68_900, win_rate_a: 52)
      assert_match(/neck and neck/, copy.to_s)
      assert emphasised(copy, :neutral, "52%")
    end

    test "lump_vs_dca, B wins median (drift): spreading out wins the typical future" do
      copy = headline("lump_vs_dca", median_a: 66_000, median_b: 68_000, win_rate_a: 44)
      assert_match(/Spreading it out actually wins/, copy.to_s)
      refute_match(/ends ahead/, copy.to_s)
    end

    # --- invest_vs_debt -----------------------------------------------------

    test "invest_vs_debt, A wins median: comes-out-ahead framing" do
      copy = headline("invest_vs_debt", median_a: 28_000, median_b: 26_000, win_rate_a: 58)
      assert_match(/comes out ahead in 58% of futures — and behind in the other 42%/, copy.to_s)
      assert emphasised(copy, :growth, "58%")
    end

    test "invest_vs_debt, B wins median (the seeded default): clearing the debt is the surer bet" do
      copy = headline("invest_vs_debt", median_a: 21_000, median_b: 27_000, win_rate_a: 32)
      assert_match(/Clearing the debt is the surer bet/, copy.to_s)
      assert_match(/pulls ahead in only 32% of futures/, copy.to_s)
      refute_match(/comes out ahead/, copy.to_s)
    end

    # --- invariants ---------------------------------------------------------

    # The win-side claims that would contradict the chart if B actually wins the
    # median. "cash comes out ahead" is fine — it's the B-wins phrasing.
    A_WINS_CLAIMS = /Investing beats cash|ends ahead of spreading|clearing the debt comes out ahead/

    test "no headline claims investing wins when B wins the median" do
      %w[stocks_vs_cash lump_vs_dca invest_vs_debt].each do |key|
        copy = headline(key, median_a: 100, median_b: 200, win_rate_a: 40)
        refute_match(A_WINS_CLAIMS, copy.to_s,
          "#{key} contradicted its chart when B wins the median")
      end
    end

    test "raises on an unknown headline_key" do
      assert_raises(ArgumentError) do
        Headline.call(Stub.new("nope"), results(median_a: 1, median_b: 1, win_rate_a: 1))
      end
    end
  end
end
