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
end
