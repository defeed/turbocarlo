require "test_helper"

class MarketDataFetchTest < ActiveSupport::TestCase
  setup do
    seed_decision_lab!
    @asset = Asset.find_by!(slug: "sp500")
  end

  test "exposes the three audit statuses" do
    assert_equal %w[success rate_limited error], MarketDataFetch.statuses.keys
  end

  test "belongs to an asset and records a status" do
    fetch = MarketDataFetch.create!(asset: @asset, status: :success, observations_count: 318)
    assert fetch.success?
    assert_equal @asset, fetch.asset
    assert_equal 318, fetch.observations_count
  end
end
