class Asset < ApplicationRecord
  has_many :scenario_paths, dependent: :restrict_with_exception

  validates :slug, presence: true, uniqueness: true
  validates :display_name, presence: true
  validates :mu, :sigma, presence: true

  # The drift/volatility the simulator should use right now. In this slice these
  # are the seeded hardcoded fallbacks; the live market-data pipeline (Phase 3)
  # will recompute them from history. Comparisons snapshot this at creation time
  # so a permalink reproduces its original result even after these drift.
  def current_params
    { mu: mu, sigma: sigma }
  end
end
