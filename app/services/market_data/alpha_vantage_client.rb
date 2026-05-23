require "net/http"
require "json"

module MarketData
  # Thin stdlib wrapper around the two Alpha Vantage endpoints the market-data
  # pipeline needs: TIME_SERIES_MONTHLY_ADJUSTED (per-asset price history) and
  # FEDERAL_FUNDS_RATE (the HYSA drift input). No HTTP gem — Net::HTTP + JSON.
  #
  # Alpha Vantage signals throttling *in a 200 response body* (not an HTTP
  # status): a top-level "Information" (current) or "Note" (legacy) key. We
  # surface that as a typed RateLimitError so the refresh job can back off; an
  # "Error Message" or otherwise unparseable payload is a ResponseError.
  #
  #   client = MarketData::AlphaVantageClient.new
  #   client.monthly_adjusted("SPY")   # => [{ observed_on: Date, close: Float }, ...] newest-first
  #   client.federal_funds_rate        # => { rate: 0.0533, observed_on: Date }
  #
  # Tests inject `transport:` (a ->(url) { body_string } lambda) to avoid real
  # HTTP without an HTTP-stubbing gem.
  class AlphaVantageClient
    BASE_URL = "https://www.alphavantage.co/query".freeze

    Error          = Class.new(StandardError) # base for everything below
    RateLimitError = Class.new(Error)         # the Information/Note throttle signal
    ResponseError  = Class.new(Error)         # "Error Message" / malformed payload

    def initialize(api_key: self.class.default_api_key, transport: nil)
      @api_key = api_key
      @transport = transport || method(:http_get)
    end

    def self.default_api_key
      Rails.application.credentials.alpha_vantage_api_key
    end

    # Adjusted monthly close history, newest observation first.
    def monthly_adjusted(symbol)
      payload = get(function: "TIME_SERIES_MONTHLY_ADJUSTED", symbol: symbol)
      series = payload["Monthly Adjusted Time Series"]
      raise ResponseError, "missing monthly series for #{symbol}" unless series.is_a?(Hash)

      series
        .map { |date, fields| { observed_on: Date.parse(date), close: Float(fields.fetch("5. adjusted close")) } }
        .sort_by { |obs| obs[:observed_on] }
        .reverse
    end

    # The latest federal funds rate, as a fraction (5.33% => 0.0533).
    def federal_funds_rate
      payload = get(function: "FEDERAL_FUNDS_RATE", interval: "monthly")
      data = payload["data"]
      raise ResponseError, "missing FFR data" unless data.is_a?(Array) && data.any?

      latest = data.first
      { rate: Float(latest.fetch("value")) / 100.0, observed_on: Date.parse(latest.fetch("date")) }
    end

    private

    # Fetch, parse, and translate Alpha Vantage's in-body throttle/error signals
    # into typed exceptions before any endpoint-specific parsing runs.
    def get(function:, **params)
      body = @transport.call(build_url(function: function, **params))
      payload = JSON.parse(body)
      raise ResponseError, "unexpected payload" unless payload.is_a?(Hash)
      raise RateLimitError, (payload["Information"] || payload["Note"]) if payload.key?("Information") || payload.key?("Note")
      raise ResponseError, payload["Error Message"] if payload.key?("Error Message")

      payload
    rescue JSON::ParserError => e
      raise ResponseError, "could not parse Alpha Vantage response: #{e.message}"
    end

    def build_url(function:, **params)
      query = { function: function, apikey: @api_key, **params }
      "#{BASE_URL}?#{URI.encode_www_form(query)}"
    end

    def http_get(url)
      response = Net::HTTP.get_response(URI(url))
      raise ResponseError, "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      response.body
    end
  end
end
