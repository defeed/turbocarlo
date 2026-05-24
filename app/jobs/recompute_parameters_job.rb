# Turns the stored price history (ingested by MarketDataRefreshJob) into the μ/σ
# the simulator uses (#12). Runs in dependency order: each tracked asset's own
# history first, then the derived 60/40 portfolio (which reads SPY/AGG), then HYSA
# from the live federal funds rate.
#
# Chained off a completed refresh rather than scheduled separately, so it always
# sees fresh observations. The single FFR call goes through the same injectable
# `client:` seam as the refresh job, so tests run with no HTTP. Every step is
# defensive: an asset with too little history (cold start) or a throttled FFR call
# leaves that asset on its seeded fallback μ/σ rather than failing the whole run.
class RecomputeParametersJob < ApplicationJob
  SPREAD = 0.003      # HYSA drift = federal funds rate + this spread
  HYSA_SIGMA = 0.005  # fixed; a savings rate barely moves month to month

  def perform(client: MarketData::AlphaVantageClient.new)
    recompute_tracked_assets
    recompute_balanced
    recompute_hysa(client: client)
  end

  private

  def recompute_tracked_assets
    Asset.alpha_vantage.find_each do |asset|
      asset.recompute_parameters!
    rescue Asset::InsufficientHistory
      next # keep the seeded fallback until enough history accumulates
    end
  end

  # 60/40 from SPY (stocks) + AGG/us-bonds (bonds), using their freshly recomputed
  # params and measured correlation. Skipped if either side lacks enough history.
  def recompute_balanced
    stock = Asset.find_by(slug: "sp500")
    bond = Asset.find_by(slug: "us-bonds")
    balanced = Asset.find_by(slug: "balanced-60-40")
    return unless stock && bond && balanced

    stock_returns = stock.log_return_series
    bond_returns = bond.log_return_series
    return if stock_returns.length < Asset::MIN_RETURNS || bond_returns.length < Asset::MIN_RETURNS

    portfolio = Monte::Portfolio.new(
      stock: stock.current_params, bond: bond.current_params,
      stock_returns: stock_returns, bond_returns: bond_returns
    )
    balanced.update!(portfolio.params)
  end

  def recompute_hysa(client:)
    hysa = Asset.find_by(slug: "hysa")
    return unless hysa

    rate = client.federal_funds_rate.fetch(:rate)
    hysa.update!(mu: rate + SPREAD, sigma: HYSA_SIGMA)
    MarketDataFetch.create!(asset: hysa, status: :success, detail: "FFR #{rate}")
  rescue MarketData::AlphaVantageClient::RateLimitError => e
    MarketDataFetch.create!(asset: hysa, status: :rate_limited, detail: e.message)
  rescue MarketData::AlphaVantageClient::Error => e
    MarketDataFetch.create!(asset: hysa, status: :error, detail: e.message)
  end
end
