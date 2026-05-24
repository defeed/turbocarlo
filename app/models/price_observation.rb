# A single adjusted monthly close for an Alpha Vantage asset. The refresh job
# upserts these (newest-first from the client) keyed on [asset_id, observed_on];
# #12 reads them to recompute the asset's annualized μ/σ.
class PriceObservation < ApplicationRecord
  belongs_to :asset

  validates :close, presence: true
  validates :observed_on, presence: true, uniqueness: { scope: :asset_id }
end
