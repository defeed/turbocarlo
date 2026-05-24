# Daily refresh of the tracked (Alpha Vantage) assets' price history. Iterates
# Asset.alpha_vantage, fetches each ticker's adjusted monthly closes, validates
# the series, upserts the observations, and logs every call to MarketDataFetch.
#
# The free key allows only 25 requests/day at ~1 req/s, so this is deliberately
# frugal: a throttle between calls, a single 60 s retry when a call is throttled,
# and then it *defers* the rest (stops the loop) rather than re-running the whole
# job and double-spending the quota — the next scheduled run picks up from a
# fresh quota. The throttle/retry/client seams are injectable so tests run
# instantly with a fake client (mirroring AlphaVantageClient's `transport:` seam).
class MarketDataRefreshJob < ApplicationJob
  THROTTLE_SECONDS = 12
  RETRY_WAIT_SECONDS = 60
  MIN_OBSERVATIONS = 60
  FRESHNESS_DAYS = 60

  def perform(client: MarketData::AlphaVantageClient.new,
              throttle: THROTTLE_SECONDS, retry_wait: RETRY_WAIT_SECONDS)
    catch(:defer) do
      Asset.alpha_vantage.order(:id).each_with_index do |asset, index|
        sleep throttle if throttle.positive? && index.positive? # respect the ~1 req/s burst limit
        refresh(asset, client: client, retry_wait: retry_wait)
      rescue MarketData::AlphaVantageClient::Error => e # ResponseError & friends: log, move on
        log!(asset, :error, detail: e.message)
      end
      # Ingest→recompute pipeline: only reached when the loop completed without
      # deferring, so we never recompute on a half-spent daily quota.
      RecomputeParametersJob.perform_later
    end
  end

  private

  def refresh(asset, client:, retry_wait:)
    observations = fetch_with_one_retry(asset, client: client, retry_wait: retry_wait)
    store(asset, observations)
  end

  # One fetch, one 60 s retry on a throttle signal, then defer the remaining
  # assets to the next scheduled run.
  def fetch_with_one_retry(asset, client:, retry_wait:)
    client.monthly_adjusted(asset.symbol)
  rescue MarketData::AlphaVantageClient::RateLimitError
    sleep retry_wait if retry_wait.positive?
    begin
      client.monthly_adjusted(asset.symbol)
    rescue MarketData::AlphaVantageClient::RateLimitError => e
      log!(asset, :rate_limited, detail: e.message)
      throw :defer
    end
  end

  def store(asset, observations)
    reason = invalid_reason(observations)
    return log!(asset, :error, detail: reason) if reason

    upsert(asset, observations)
    log!(asset, :success, observations_count: observations.size)
  end

  # nil when the series is trustworthy, otherwise why it was rejected.
  def invalid_reason(observations)
    return "only #{observations.size} observations (need #{MIN_OBSERVATIONS})" if observations.size < MIN_OBSERVATIONS

    latest = observations.first[:observed_on] # client returns newest-first
    return "stale: latest observation #{latest} older than #{FRESHNESS_DAYS} days" if latest < FRESHNESS_DAYS.days.ago.to_date

    nil
  end

  def upsert(asset, observations)
    now = Time.current
    rows = observations.map do |obs|
      { asset_id: asset.id, observed_on: obs[:observed_on], close: obs[:close],
        created_at: now, updated_at: now }
    end
    PriceObservation.upsert_all(rows, unique_by: [ :asset_id, :observed_on ])
  end

  def log!(asset, status, detail: nil, observations_count: nil)
    MarketDataFetch.create!(asset: asset, status: status, detail: detail,
                            observations_count: observations_count)
  end
end
