class Asset < ApplicationRecord
  # Where this asset's μ/σ come from: a live Alpha Vantage ticker (refreshed by
  # MarketDataRefreshJob), fixed hardcoded params (manual), or computed from
  # other assets (derived — e.g. the 60/40 portfolio in #12). Only :alpha_vantage
  # assets carry a `symbol` and a price history; `Asset.alpha_vantage` is the set
  # the refresh job tracks.
  enum :data_source, { alpha_vantage: 0, manual: 1, derived: 2 }

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
end
