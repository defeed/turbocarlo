require "test_helper"

class AssetTest < ActiveSupport::TestCase
  test "alpha_vantage assets require a symbol" do
    asset = Asset.new(slug: "x", display_name: "X", mu: 0.05, sigma: 0.1, data_source: :alpha_vantage)
    assert_not asset.valid?
    assert_includes asset.errors[:symbol], "can't be blank"

    asset.symbol = "SPY"
    assert asset.valid?
  end

  test "manual and derived assets need no symbol" do
    assert Asset.new(slug: "m", display_name: "M", mu: 0.05, sigma: 0.1, data_source: :manual).valid?
    assert Asset.new(slug: "d", display_name: "D", mu: 0.05, sigma: 0.1, data_source: :derived).valid?
  end

  test "the alpha_vantage scope is the refresh job's tracked set" do
    seed_decision_lab!
    assert_equal %w[AGG NVDA SPY VT], Asset.alpha_vantage.pluck(:symbol).sort
  end

  # --- recompute_parameters! (#12) ------------------------------------------

  # Builds monthly observations from a list of log returns, newest at `latest`,
  # so the produced log-return series reproduces `rets` exactly.
  def asset_with_returns(rets, latest: Date.current, slug: "av")
    asset = Asset.create!(slug: slug, display_name: slug, mu: 0.0, sigma: 0.0,
                          data_source: :alpha_vantage, symbol: slug.upcase)
    closes = [ 100.0 ]
    rets.each { |r| closes << closes.last * Math.exp(r) }
    closes.each_with_index do |close, i|
      months_ago = closes.length - 1 - i
      asset.price_observations.create!(observed_on: latest << months_ago, close: close)
    end
    asset
  end

  def mean(xs) = xs.sum / xs.length.to_f

  def sample_stddev(xs)
    m = mean(xs)
    Math.sqrt(xs.sum { |x| (x - m)**2 } / (xs.length - 1))
  end

  test "recompute_parameters! annualizes log returns with the variance-drag correction" do
    rets = Array.new(30) { |i| i.even? ? 0.01 : 0.03 }
    asset = asset_with_returns(rets)

    asset.recompute_parameters!

    expected_sigma = sample_stddev(rets) * Math.sqrt(12)
    expected_mu = mean(rets) * 12 + 0.5 * expected_sigma**2
    assert_in_delta expected_sigma, asset.sigma, 1e-12
    assert_in_delta expected_mu, asset.mu, 1e-12
  end

  test "recompute_parameters! only uses observations inside the 20-year window" do
    asset = asset_with_returns(Array.new(30) { 0.01 })
    # An ancient observation 25 years back must not enter the return series.
    ancient = 25.years.ago.to_date
    asset.price_observations.create!(observed_on: ancient, close: 1.0)

    assert_not_includes asset.log_return_series.keys, ancient
    assert_equal 30, asset.log_return_series.length
  end

  test "recompute_parameters! handles a short-history asset without error" do
    asset = asset_with_returns(Array.new(30) { 0.005 }) # ~2.5y of monthly data, well under 20y

    assert_nothing_raised { asset.recompute_parameters! }
    assert asset.sigma >= 0
    assert asset.mu.finite?
  end

  test "recompute_parameters! raises when there is too little history" do
    asset = asset_with_returns(Array.new(9) { 0.01 }) # 9 returns < MIN_RETURNS

    assert_raises(Asset::InsufficientHistory) { asset.recompute_parameters! }
  end
end
