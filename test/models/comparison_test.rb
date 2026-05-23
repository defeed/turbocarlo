require "test_helper"

class ComparisonTest < ActiveSupport::TestCase
  setup do
    @scenario = seed_decision_lab!
  end

  test "identical inputs and params dedupe to one row with the same slug" do
    first = Comparison.find_or_run!(scenario: @scenario, amount: 50_000, horizon: 5)
    second = Comparison.find_or_run!(scenario: @scenario, amount: 50_000, horizon: 5)

    assert_equal first.id, second.id
    assert_equal first.slug, second.slug
    assert_equal 1, Comparison.count
  end

  test "a different amount mints a different slug and row" do
    first = Comparison.find_or_run!(scenario: @scenario, amount: 50_000, horizon: 5)
    other = Comparison.find_or_run!(scenario: @scenario, amount: 60_000, horizon: 5)

    refute_equal first.slug, other.slug
    assert_equal 2, Comparison.count
  end

  test "freezes the snapshot, derived seed, and data_as_of on create" do
    comparison = Comparison.find_or_run!(scenario: @scenario, amount: 50_000, horizon: 5)

    assert_equal 0.08, comparison.mu_a_snapshot
    assert_equal 0.16, comparison.sigma_a_snapshot
    assert_equal 0.045, comparison.mu_b_snapshot
    assert_equal 0.005, comparison.sigma_b_snapshot
    assert_equal Date.current, comparison.data_as_of
    assert_operator comparison.seed, :>, 0
  end

  test "drifting live Asset params after creation mints a different slug" do
    first = Comparison.find_or_run!(scenario: @scenario, amount: 50_000, horizon: 5)

    @scenario.path_a.asset.update!(mu: 0.30, sigma: 0.40)
    drifted = Comparison.find_or_run!(scenario: @scenario, amount: 50_000, horizon: 5)

    refute_equal first.slug, drifted.slug
  end
end
