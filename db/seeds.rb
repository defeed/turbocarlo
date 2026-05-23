# Idempotent seed of the one walking-skeleton scenario: "Invest vs keep in
# savings" (S&P 500 vs high-yield savings, both plain GBM, uncoupled). μ/σ are
# the hardcoded fallbacks from the prototype; the market-data pipeline (Phase 3)
# will refresh them. Re-runnable in every environment.

sp500 = Asset.find_or_create_by!(slug: "sp500") do |a|
  a.display_name = "S&P 500"
  a.display_meta = "US large-cap equity index"
  a.mu = 0.08
  a.sigma = 0.16
end

hysa = Asset.find_or_create_by!(slug: "hysa") do |a|
  a.display_name = "High-yield savings"
  a.display_meta = "Cash deposit account"
  a.mu = 0.045
  a.sigma = 0.005
end

scenario = Scenario.find_or_create_by!(slug: "invest-vs-savings") do |s|
  s.title = "Invest vs keep in savings"
  s.chip_meta = "€50k · S&P vs HYSA · 5y"
  s.chip_icon = "$"
  s.setup_title = "Risk vs certainty."
  s.currency = "€"
  s.default_amount = 50_000
  s.default_horizon_years = 5
  s.headline_key = "stocks_vs_cash"
  s.coupled_randomness = false
end

scenario.scenario_paths.find_or_create_by!(role: :a) do |p|
  p.asset = sp500
  p.label = "S&P 500"
  p.meta = "Equity index"
  p.behavior = :plain
end

scenario.scenario_paths.find_or_create_by!(role: :b) do |p|
  p.asset = hysa
  p.label = "High-yield savings"
  p.meta = "~4.5% APY"
  p.behavior = :plain
end
