require "test_helper"

module MarketData
  class AlphaVantageClientTest < ActiveSupport::TestCase
    # A transport that records the URL it was asked for and returns a canned body.
    def stub_transport(body)
      requested = []
      transport = ->(url) { requested << url; body }
      [ transport, requested ]
    end

    def client_for(body, api_key: "TEST_KEY")
      transport, requested = stub_transport(body)
      [ AlphaVantageClient.new(api_key: api_key, transport: transport), requested ]
    end

    MONTHLY_BODY = <<~JSON
      {
        "Meta Data": { "2. Symbol": "SPY" },
        "Monthly Adjusted Time Series": {
          "2026-03-31": { "5. adjusted close": "520.0000" },
          "2026-01-30": { "5. adjusted close": "500.5000" },
          "2026-02-27": { "5. adjusted close": "510.2500" }
        }
      }
    JSON

    FFR_BODY = <<~JSON
      {
        "name": "Effective Federal Funds Rate",
        "interval": "monthly",
        "unit": "percent",
        "data": [
          { "date": "2026-05-01", "value": "5.33" },
          { "date": "2026-04-01", "value": "5.31" }
        ]
      }
    JSON

    # --- monthly_adjusted: success ------------------------------------------

    test "monthly_adjusted parses observations newest-first" do
      client, = client_for(MONTHLY_BODY)
      obs = client.monthly_adjusted("SPY")

      assert_equal 3, obs.length
      assert_equal [ Date.new(2026, 3, 31), Date.new(2026, 2, 27), Date.new(2026, 1, 30) ],
                   obs.map { |o| o[:observed_on] }
      assert_equal 520.0, obs.first[:close]
      assert_instance_of Float, obs.first[:close]
    end

    test "monthly_adjusted builds a query carrying function, symbol, and apikey" do
      client, requested = client_for(MONTHLY_BODY)
      client.monthly_adjusted("SPY")

      url = requested.sole
      assert_includes url, "function=TIME_SERIES_MONTHLY_ADJUSTED"
      assert_includes url, "symbol=SPY"
      assert_includes url, "apikey=TEST_KEY"
    end

    # --- federal_funds_rate -------------------------------------------------

    test "federal_funds_rate returns the latest rate as a fraction with its date" do
      client, requested = client_for(FFR_BODY)
      result = client.federal_funds_rate

      assert_in_delta 0.0533, result[:rate], 1e-9
      assert_equal Date.new(2026, 5, 1), result[:observed_on]
      assert_includes requested.sole, "function=FEDERAL_FUNDS_RATE"
    end

    # --- rate-limit detection -----------------------------------------------

    test "current Information throttle signal raises RateLimitError" do
      body = %({ "Information": "rate limit is 25 requests per day" })
      client, = client_for(body)

      error = assert_raises(AlphaVantageClient::RateLimitError) { client.monthly_adjusted("SPY") }
      assert_match(/25 requests per day/, error.message)
    end

    test "legacy Note throttle signal raises RateLimitError" do
      body = %({ "Note": "Thank you for using Alpha Vantage! Our standard API rate limit..." })
      client, = client_for(body)

      assert_raises(AlphaVantageClient::RateLimitError) { client.federal_funds_rate }
    end

    # --- error / malformed payloads -----------------------------------------

    test "Error Message payload raises ResponseError" do
      body = %({ "Error Message": "Invalid API call" })
      client, = client_for(body)

      error = assert_raises(AlphaVantageClient::ResponseError) { client.monthly_adjusted("BOGUS") }
      assert_match(/Invalid API call/, error.message)
    end

    test "blank body raises ResponseError" do
      client, = client_for("")
      assert_raises(AlphaVantageClient::ResponseError) { client.monthly_adjusted("SPY") }
    end

    test "a non-object JSON payload raises ResponseError" do
      client, = client_for("null")
      assert_raises(AlphaVantageClient::ResponseError) { client.monthly_adjusted("SPY") }
    end

    test "missing time-series key raises ResponseError" do
      client, = client_for(%({ "Meta Data": { "2. Symbol": "SPY" } }))
      assert_raises(AlphaVantageClient::ResponseError) { client.monthly_adjusted("SPY") }
    end

    # RateLimitError and ResponseError are both rescuable as the base Error.
    test "typed errors share a common base" do
      assert_operator AlphaVantageClient::RateLimitError, :<, AlphaVantageClient::Error
      assert_operator AlphaVantageClient::ResponseError, :<, AlphaVantageClient::Error
    end
  end
end
