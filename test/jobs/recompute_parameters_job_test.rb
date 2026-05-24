require "test_helper"

class RecomputeParametersJobTest < ActiveSupport::TestCase
  # Stand-in for AlphaVantageClient: only federal_funds_rate is used by the job.
  # Returns a fixed rate, or raises a scripted error.
  class FakeClient
    def initialize(rate: 0.0533, raises: nil)
      @rate = rate
      @raises = raises
    end

    def federal_funds_rate
      raise @raises if @raises

      { rate: @rate, observed_on: Date.current }
    end
  end

  setup { seed_decision_lab! }

  # Give an asset (by slug) `count` monthly observations whose log returns follow
  # `pattern`-shaped values, so recompute has real history to chew on.
  def observe(slug, count: 30, &pattern)
    pattern ||= ->(i) { 0.01 * Math.sin(i) }
    asset = Asset.find_by!(slug: slug)
    close = 100.0
    latest = Date.current
    count.times do |i|
      close *= Math.exp(pattern.call(i))
      asset.price_observations.create!(observed_on: latest << (count - 1 - i), close: close)
    end
    asset
  end

  def observe_all
    observe("sp500")      { |i| 0.02 * Math.sin(i) }            # volatile equities
    observe("us-bonds")   { |i| 0.004 * Math.cos(i) }           # low-vol bonds, decorrelated
    observe("world-index") { |i| 0.015 * Math.sin(i + 1) }
    observe("nvda")       { |i| 0.03 * Math.sin(i * 1.3) }
  end

  test "tracked assets get their mu/sigma recomputed from stored history" do
    observe_all
    sp500 = Asset.find_by!(slug: "sp500")
    before = sp500.sigma

    RecomputeParametersJob.new.perform(client: FakeClient.new)

    sp500.reload
    assert_not_equal before, sp500.sigma
    assert sp500.sigma.positive?
    assert sp500.mu.finite?
  end

  test "the 60/40 portfolio is derived with sigma below the 100%-stocks sigma" do
    observe_all

    RecomputeParametersJob.new.perform(client: FakeClient.new)

    balanced = Asset.find_by!(slug: "balanced-60-40")
    sp500 = Asset.find_by!(slug: "sp500")
    assert balanced.sigma < sp500.sigma,
      "60/40 σ (#{balanced.sigma}) should be below 100%-stocks σ (#{sp500.sigma})"
  end

  test "HYSA is set from the federal funds rate plus the spread and logged" do
    observe_all

    RecomputeParametersJob.new.perform(client: FakeClient.new(rate: 0.0533))

    hysa = Asset.find_by!(slug: "hysa")
    assert_in_delta 0.0533 + RecomputeParametersJob::SPREAD, hysa.mu, 1e-12
    assert_in_delta RecomputeParametersJob::HYSA_SIGMA, hysa.sigma, 1e-12

    fetch = MarketDataFetch.where(asset: hysa).sole
    assert fetch.success?
    assert_match "0.0533", fetch.detail
  end

  test "an asset with no observations keeps its seeded fallback params" do
    observe("sp500"); observe("us-bonds") # leave NVDA without any history
    nvda = Asset.find_by!(slug: "nvda")
    fallback = nvda.mu

    RecomputeParametersJob.new.perform(client: FakeClient.new)

    assert_equal fallback, nvda.reload.mu, "fallback μ must survive a cold-start asset"
  end

  test "a throttled FFR call is logged and leaves HYSA on its fallback" do
    observe_all
    hysa = Asset.find_by!(slug: "hysa")
    fallback_mu = hysa.mu

    RecomputeParametersJob.new.perform(
      client: FakeClient.new(raises: MarketData::AlphaVantageClient::RateLimitError.new("throttled"))
    )

    assert_equal fallback_mu, hysa.reload.mu
    assert MarketDataFetch.where(asset: hysa).sole.rate_limited?
  end
end
