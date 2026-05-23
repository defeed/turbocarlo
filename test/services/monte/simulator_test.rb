require "test_helper"

module Monte
  class SimulatorTest < ActiveSupport::TestCase
    SPEC_A = PathSpec.new(mu: 0.08, sigma: 0.16, label: "S&P 500")
    SPEC_B = PathSpec.new(mu: 0.045, sigma: 0.005, label: "High-yield savings")

    def run_sim(seed:)
      Simulator.new(amount: 50_000, horizon: 5, seed: seed, n_paths: 500)
        .call(spec_a: SPEC_A, spec_b: SPEC_B)
    end

    test "is deterministic: a fixed seed yields identical output" do
      assert_equal run_sim(seed: 4242), run_sim(seed: 4242)
    end

    test "different seeds yield different output" do
      refute_equal run_sim(seed: 1), run_sim(seed: 2)
    end

    test "returns the full result shape" do
      result = run_sim(seed: 7)
      assert_equal %i[median_a median_b p5_a p95_a p5_b p95_b win_rate_a steps chart].sort,
        result.keys.sort
      assert_equal 60, result[:steps] # [5 * 12, 120].min
      assert_includes 0..100, result[:win_rate_a]
    end

    test "chart payload carries per-step bands and a sampled set of whole paths" do
      result = run_sim(seed: 7)
      chart = result[:chart]
      steps = result[:steps]

      # Bands span every step plus the t=0 "Now" point, pinned at the amount.
      %i[band_a band_b].each do |key|
        band = chart[key]
        assert_equal %i[p5 median p95].sort, band.keys.sort
        band.each_value do |series|
          assert_equal steps + 1, series.length
          assert_equal 50_000, series.first # pinned at the start amount
        end
      end

      # A small sample of whole paths for the spaghetti, each pinned at "Now".
      %i[sample_a sample_b].each do |key|
        sample = chart[key]
        assert_operator sample.length, :<=, Simulator::SAMPLE_SIZE
        assert_operator sample.length, :>, Simulator::SAMPLE_SIZE - 5
        sample.each do |path|
          assert_equal steps + 1, path.length
          assert_equal 50_000, path.first
        end
      end
    end

    test "equity beats cash at the median for these params" do
      result = run_sim(seed: 7)
      assert_operator result[:median_a], :>, result[:median_b]
    end

    test "a zero-volatility path is deterministic and has a tight band" do
      result = Simulator.new(amount: 10_000, horizon: 5, seed: 99, n_paths: 100).call(
        spec_a: PathSpec.new(mu: 0.08, sigma: 0.16),
        spec_b: PathSpec.new(mu: 0.04, sigma: 0.0)
      )
      assert_in_delta result[:p5_b], result[:p95_b], 1e-6
    end

    test "lump sum beats dollar-cost averaging on a shared rising market" do
      # The DCA behavior is wired through the simulator: on a deterministic rising
      # market the lump sum (A, invested from day one) ends ahead of DCA (B, holding
      # cash early). A zero-σ market makes the comparison exact; the stochastic,
      # common-random-numbers version is exercised below.
      result = Simulator.new(amount: 50_000, horizon: 5, seed: 7, n_paths: 100).call(
        spec_a: PathSpec.new(mu: 0.06, sigma: 0.0, behavior: :plain),
        spec_b: PathSpec.new(mu: 0.06, sigma: 0.0, behavior: :dca)
      )
      assert_operator result[:median_a], :>, result[:median_b]
      assert_equal 100, result[:win_rate_a]
    end

    # --- common random numbers (ADR-0001) ------------------------------------

    LUMP = PathSpec.new(mu: 0.08, sigma: 0.16, behavior: :plain, label: "Lump sum")
    DCA  = PathSpec.new(mu: 0.08, sigma: 0.16, behavior: :dca, label: "Dollar-cost averaging")

    def lump_vs_dca(seed:, coupled:)
      Simulator.new(amount: 50_000, horizon: 5, seed: seed, n_paths: 500, coupled: coupled)
        .call(spec_a: LUMP, spec_b: DCA)
    end

    test "coupled runs are deterministic for a fixed seed" do
      assert_equal lump_vs_dca(seed: 4242, coupled: true), lump_vs_dca(seed: 4242, coupled: true)
    end

    test "coupling feeds both sides the same per-simulation market" do
      # Identical specs on both sides: under coupling they consume the *same*
      # normals, so the two sides are byte-identical — no path is strictly ahead,
      # so win_rate is 0 and the chart bands coincide. Independent draws diverge.
      same = PathSpec.new(mu: 0.08, sigma: 0.16, behavior: :plain)

      coupled = Simulator.new(amount: 50_000, horizon: 5, seed: 7, n_paths: 200, coupled: true)
        .call(spec_a: same, spec_b: same)
      assert_equal 0, coupled[:win_rate_a]
      assert_equal coupled[:median_a], coupled[:median_b]
      assert_equal coupled[:chart][:band_a], coupled[:chart][:band_b]

      independent = Simulator.new(amount: 50_000, horizon: 5, seed: 7, n_paths: 200, coupled: false)
        .call(spec_a: same, spec_b: same)
      refute_equal independent[:chart][:band_a], independent[:chart][:band_b]
    end

    test "common random numbers make the lump-vs-DCA win rate a real signal" do
      # On the *same* market path the lump sum (invested from day one) usually
      # ends ahead of DCA (which sits in cash through year one): coupling yields a
      # decisive, repeatable win rate well above the 50% coin flip. Independent
      # draws drown that signal in two unrelated markets — the win rate collapses
      # toward noise. This is exactly what CRN buys us (ADR-0001).
      coupled = lump_vs_dca(seed: 7, coupled: true)
      independent = lump_vs_dca(seed: 7, coupled: false)

      assert_operator coupled[:median_a], :>, coupled[:median_b]
      assert_operator coupled[:win_rate_a], :>=, 60
      assert_operator coupled[:win_rate_a], :>, independent[:win_rate_a]
    end
  end
end
