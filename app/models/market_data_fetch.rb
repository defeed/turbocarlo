# Audit log: one row per market-data API call the refresh job makes, recording
# how it resolved (data stored, throttled by the daily quota, or failed/invalid).
class MarketDataFetch < ApplicationRecord
  belongs_to :asset

  enum :status, { success: 0, rate_limited: 1, error: 2 }
end
