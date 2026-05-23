# Idempotent seeds for the scenarios shipped so far. μ/σ are the hardcoded
# fallbacks from the prototype; the market-data pipeline (Phase 3) will refresh
# them. Re-runnable in every environment. The full six scenarios + Entry polish
# arrive in a later slice.

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

# A guaranteed return with no volatility — clearing a loan earns exactly its
# interest rate. σ = 0 makes the path deterministic (no sampling).
debt_payoff = Asset.find_or_create_by!(slug: "debt-payoff") do |a|
  a.display_name = "Paying off debt"
  a.display_meta = "Guaranteed avoided interest"
  a.mu = 0.06
  a.sigma = 0.0
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
  s.insight_key = "stocks_vs_cash"
  s.coupled_randomness = false
end
# Backfill insight_key on environments seeded before #5 (the block above runs
# only on create).
scenario.update!(insight_key: "stocks_vs_cash") if scenario.insight_key.blank?

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

# Lump sum vs dollar-cost averaging — same market, different timing. Both paths
# ride the *same* S&P, so coupled_randomness drives them off one shared market
# path per simulation (ADR-0001), making the win rate meaningful.
lump_vs_dca = Scenario.find_or_create_by!(slug: "lump-vs-dca") do |s|
  s.title = "Lump sum vs dollar-cost averaging"
  s.chip_meta = "€50k · S&P · all now vs over 12mo"
  s.chip_icon = "≈"
  s.setup_title = "All at once, or spread out?"
  s.currency = "€"
  s.default_amount = 50_000
  s.default_horizon_years = 5
  s.headline_key = "lump_vs_dca"
  s.insight_key = "lump_vs_dca"
  s.coupled_randomness = true
end
# Enforce the flag on re-seed: find_or_create_by!'s block runs only on create,
# so an environment seeded before CRN landed keeps coupling switched on.
lump_vs_dca.update!(coupled_randomness: true) unless lump_vs_dca.coupled_randomness?
lump_vs_dca.update!(insight_key: "lump_vs_dca") if lump_vs_dca.insight_key.blank?

lump_vs_dca.scenario_paths.find_or_create_by!(role: :a) do |p|
  p.asset = sp500
  p.label = "Lump sum"
  p.meta = "Invest it all today"
  p.behavior = :plain
end

lump_vs_dca.scenario_paths.find_or_create_by!(role: :b) do |p|
  p.asset = sp500
  p.label = "Dollar-cost averaging"
  p.meta = "Spread over 12 months"
  p.behavior = :dca
end

# Invest vs pay off debt — the growth side keeps the loan and invests (net of
# accrued interest); the stable side clears it for a guaranteed return (zero-σ).
invest_vs_debt = Scenario.find_or_create_by!(slug: "invest-vs-debt") do |s|
  s.title = "Invest vs pay off debt"
  s.chip_meta = "€20k · S&P vs 6% loan · 5y"
  s.chip_icon = "%"
  s.setup_title = "Grow it, or kill the debt?"
  s.currency = "€"
  s.default_amount = 20_000
  s.default_horizon_years = 5
  s.headline_key = "invest_vs_debt"
  s.insight_key = "invest_vs_debt"
  s.coupled_randomness = false
end
invest_vs_debt.update!(insight_key: "invest_vs_debt") if invest_vs_debt.insight_key.blank?

invest_vs_debt.scenario_paths.find_or_create_by!(role: :a) do |p|
  p.asset = sp500
  p.label = "Invest, keep the debt"
  p.meta = "Net of 6% interest"
  p.behavior = :debt_adjusted
  p.behavior_params = { "debt_rate" => 0.06 }
end

invest_vs_debt.scenario_paths.find_or_create_by!(role: :b) do |p|
  p.asset = debt_payoff
  p.label = "Pay off the debt"
  p.meta = "Guaranteed 6%"
  p.behavior = :plain
end
