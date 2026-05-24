class Asset < ApplicationRecord
  # Where this asset's μ/σ come from: a live Alpha Vantage ticker (refreshed by
  # MarketDataRefreshJob), fixed hardcoded params (manual), or computed from
  # other assets (derived — e.g. the 60/40 portfolio in #12). Only :alpha_vantage
  # assets carry a `symbol` and a price history; `Asset.alpha_vantage` is the set
  # the refresh job tracks.
  enum :data_source, { alpha_vantage: 0, manual: 1, derived: 2 }

  # How far back the μ/σ recompute (#12) looks, and the minimum number of monthly
  # log returns it needs to produce a meaningful estimate (≈2 years).
  LOOKBACK = 20.years
  MIN_RETURNS = 24

  # Raised when an asset has too little stored history to recompute from; the
  # caller keeps the seeded fallback μ/σ.
  InsufficientHistory = Class.new(StandardError)

  has_many :scenario_paths, dependent: :restrict_with_exception
  has_many :price_observations, dependent: :destroy
  has_many :market_data_fetches, dependent: :destroy

  validates :slug, presence: true, uniqueness: true
  validates :display_name, presence: true
  validates :mu, :sigma, presence: true
  validates :symbol, presence: true, if: :alpha_vantage?

  # The drift/volatility the simulator should use right now. In this slice these
  # are the seeded hardcoded fallbacks; the live market-data pipeline (Phase 3)
  # will recompute them from history. Comparisons snapshot this at creation time
  # so a permalink reproduces its original result even after these drift.
  def current_params
    { mu: mu, sigma: sigma }
  end

  # Recompute drift/volatility from this asset's stored price history (#12).
  #
  # σ is the annualized standard deviation of monthly log returns (·√12); μ is the
  # annualized arithmetic drift the GBM expects, recovered from the log-return mean
  # with the variance-drag correction (μ = m·12 + σ²/2 — see Monte::Path which
  # subtracts 0.5σ² internally). Honest about short histories: it just uses
  # whatever falls inside min(20y, available).
  def recompute_parameters!
    returns = log_return_series.values
    if returns.length < MIN_RETURNS
      raise InsufficientHistory, "#{slug}: #{returns.length} returns (< #{MIN_RETURNS})"
    end

    sigma = Monte::Statistics.sample_stddev(returns) * Math.sqrt(12)
    mu = Monte::Statistics.mean(returns) * 12 + 0.5 * sigma**2
    update!(mu: mu, sigma: sigma)
  end

  # Monthly log returns ln(closeₜ / closeₜ₋₁) keyed by the later observation's
  # date, over the lookback window. Used by recompute and (for SPY/AGG) by
  # Monte::Portfolio's correlation. The min(20y, available) cap is implicit: a
  # short-history asset simply yields fewer rows.
  def log_return_series(window: LOOKBACK)
    closes = price_observations
      .where(observed_on: window.ago.to_date..)
      .order(:observed_on)
      .pluck(:observed_on, :close)

    closes.each_cons(2).to_h do |(_, prev_close), (date, close)|
      [ date, Math.log(close / prev_close) ]
    end
  end
end
