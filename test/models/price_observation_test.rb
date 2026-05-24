require "test_helper"

class PriceObservationTest < ActiveSupport::TestCase
  setup do
    seed_decision_lab!
    @asset = Asset.find_by!(slug: "sp500")
  end

  test "requires close and observed_on" do
    obs = PriceObservation.new(asset: @asset)
    assert_not obs.valid?
    assert_includes obs.errors[:close], "can't be blank"
    assert_includes obs.errors[:observed_on], "can't be blank"
  end

  test "observed_on is unique per asset but shared across assets" do
    on = Date.new(2026, 3, 31)
    @asset.price_observations.create!(observed_on: on, close: 500.0)

    dup = @asset.price_observations.build(observed_on: on, close: 501.0)
    assert_not dup.valid?
    assert_includes dup.errors[:observed_on], "has already been taken"

    other = Asset.find_by!(slug: "nvda").price_observations.build(observed_on: on, close: 200.0)
    assert other.valid?
  end
end
