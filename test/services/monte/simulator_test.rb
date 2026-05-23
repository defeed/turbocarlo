require "test_helper"

module Monte
  class SimulatorTest < ActiveSupport::TestCase
    PATH_A = { mu: 0.08, sigma: 0.16 }.freeze
    PATH_B = { mu: 0.045, sigma: 0.005 }.freeze

    def run_sim(seed:)
      Simulator.new(amount: 50_000, horizon: 5, seed: seed, n_paths: 500)
        .call(path_a: PATH_A, path_b: PATH_B)
    end

    test "is deterministic: a fixed seed yields identical output" do
      assert_equal run_sim(seed: 4242), run_sim(seed: 4242)
    end

    test "different seeds yield different output" do
      refute_equal run_sim(seed: 1), run_sim(seed: 2)
    end

    test "returns the full result shape" do
      result = run_sim(seed: 7)
      assert_equal %i[median_a median_b p5_a p95_a p5_b p95_b win_rate_a steps].sort,
        result.keys.sort
      assert_equal 60, result[:steps] # [5 * 12, 120].min
      assert_includes 0..100, result[:win_rate_a]
    end

    test "equity beats cash at the median for these params" do
      result = run_sim(seed: 7)
      assert_operator result[:median_a], :>, result[:median_b]
    end

    test "a zero-volatility path is deterministic and has a tight band" do
      result = Simulator.new(amount: 10_000, horizon: 5, seed: 99, n_paths: 100)
        .call(path_a: { mu: 0.08, sigma: 0.16 }, path_b: { mu: 0.04, sigma: 0.0 })
      assert_in_delta result[:p5_b], result[:p95_b], 1e-6
    end
  end
end
