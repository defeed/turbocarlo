require "test_helper"

class MarketDataRefreshJobTest < ActiveSupport::TestCase
  RateLimitError = MarketData::AlphaVantageClient::RateLimitError
  ResponseError  = MarketData::AlphaVantageClient::ResponseError

  # A stand-in for AlphaVantageClient. Scripted per symbol: each call to
  # monthly_adjusted consumes the next response (raised if it's an exception,
  # returned otherwise); a single-element script repeats. Mirrors the real
  # client's `transport:` seam so the job runs with no HTTP and no sleeping.
  class FakeClient
    attr_reader :calls

    def initialize(script)
      @script = script
      @calls = Hash.new(0)
    end

    def monthly_adjusted(symbol)
      @calls[symbol] += 1
      responses = @script.fetch(symbol)
      response = responses.length > 1 ? responses.shift : responses.first
      raise response if response.is_a?(Class) && response <= Exception
      raise response if response.is_a?(Exception)

      response
    end
  end

  setup do
    seed_decision_lab! # gives us the four tracked assets (SPY/NVDA/VT/AGG) with symbols
  end

  # Monthly closes, newest-first, ending at `latest` — the shape the client returns.
  def observations(count: 60, latest: Date.current)
    Array.new(count) { |i| { observed_on: latest << i, close: 100.0 + i } }
  end

  def valid_script(overrides = {})
    { "SPY" => [ observations ], "NVDA" => [ observations ],
      "VT" => [ observations ], "AGG" => [ observations ] }.merge(overrides)
  end

  def run_job(script, **opts)
    MarketDataRefreshJob.new.perform(client: FakeClient.new(script), throttle: 0, retry_wait: 0, **opts)
  end

  test "success: every tracked asset gets observations and a logged success fetch" do
    run_job(valid_script)

    assert_equal 4, MarketDataFetch.success.count
    assert_equal 0, MarketDataFetch.where.not(status: :success).count
    assert_equal [ 60, 60, 60, 60 ], MarketDataFetch.success.pluck(:observations_count)
    assert_equal 60, PriceObservation.where(asset: Asset.find_by!(slug: "sp500")).count
    assert_equal 4 * 60, PriceObservation.count
  end

  test "a persistent rate limit logs once and defers the remaining assets" do
    run_job(valid_script("SPY" => [ RateLimitError ]))

    fetches = MarketDataFetch.all
    assert_equal 1, fetches.count, "should stop after the first asset is throttled"
    assert fetches.sole.rate_limited?
    assert_equal "sp500", fetches.sole.asset.slug
    assert_equal 0, PriceObservation.count, "no asset should have been stored"
  end

  test "a throttled call is retried once and succeeds" do
    client = FakeClient.new(valid_script("SPY" => [ RateLimitError, observations ]))
    MarketDataRefreshJob.new.perform(client: client, throttle: 0, retry_wait: 0)

    assert_equal 2, client.calls["SPY"], "first attempt throttled, retry succeeded"
    assert_equal 4, MarketDataFetch.success.count
    assert_equal 60, PriceObservation.where(asset: Asset.find_by!(slug: "sp500")).count
  end

  test "a response error is logged and the loop continues to the rest" do
    run_job(valid_script("NVDA" => [ ResponseError.new("boom") ]))

    nvda = Asset.find_by!(slug: "nvda")
    assert MarketDataFetch.find_by!(asset: nvda).error?
    assert_equal 0, PriceObservation.where(asset: nvda).count
    assert_equal 3, MarketDataFetch.success.count, "the other three still refresh"
  end

  test "series that are too short or stale are rejected without storing observations" do
    run_job(valid_script(
      "SPY" => [ observations(count: 30) ],
      "VT" => [ observations(latest: 100.days.ago.to_date) ]
    ))

    assert MarketDataFetch.find_by!(asset: Asset.find_by!(slug: "sp500")).error?
    assert MarketDataFetch.find_by!(asset: Asset.find_by!(slug: "world-index")).error?
    assert_equal 0, PriceObservation.where(asset: Asset.find_by!(slug: "sp500")).count
    assert_equal 0, PriceObservation.where(asset: Asset.find_by!(slug: "world-index")).count
    assert_equal 2, MarketDataFetch.success.count, "NVDA and AGG still refresh"
  end

  test "re-running upserts rather than duplicating observations" do
    run_job(valid_script)
    run_job(valid_script)

    assert_equal 4 * 60, PriceObservation.count
    assert_equal 8, MarketDataFetch.success.count
  end
end
