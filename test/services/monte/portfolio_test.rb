require "test_helper"

class Monte::PortfolioTest < ActiveSupport::TestCase
  # Two return series sharing only the last three dates; the bond series carries an
  # extra leading date SPY never saw, which must be dropped from the correlation.
  def returns
    common = { Date.new(2024, 1, 31) => 0.02, Date.new(2024, 2, 29) => -0.01, Date.new(2024, 3, 31) => 0.03 }
    stock_returns = common
    bond_returns = { Date.new(2023, 12, 31) => 0.99 }.merge(
      Date.new(2024, 1, 31) => 0.01, Date.new(2024, 2, 29) => -0.005, Date.new(2024, 3, 31) => 0.015
    )
    [ stock_returns, bond_returns ]
  end

  def portfolio(stock: { mu: 0.09, sigma: 0.16 }, bond: { mu: 0.03, sigma: 0.05 })
    stock_returns, bond_returns = returns
    Monte::Portfolio.new(stock: stock, bond: bond, stock_returns: stock_returns, bond_returns: bond_returns)
  end

  test "mu is the linear 60/40 blend of the two drifts" do
    assert_in_delta 0.6 * 0.09 + 0.4 * 0.03, portfolio.mu, 1e-12
  end

  test "correlation is measured only over the common window" do
    # The stray bond date 2023-12-31 (0.99) is dropped, leaving the three shared
    # dates: stock [0.02,-0.01,0.03] vs bond [0.01,-0.005,0.015] — perfectly
    # collinear (bond = 0.5·stock), so ρ = +1.
    assert_in_delta 1.0, portfolio.correlation, 1e-9
  end

  test "blended sigma is below the 100%-stocks sigma whenever correlation < 1" do
    # Force a low correlation by giving bond returns that move against stocks.
    stock_returns = { Date.new(2024, 1, 31) => 0.02, Date.new(2024, 2, 29) => -0.01, Date.new(2024, 3, 31) => 0.03 }
    bond_returns  = { Date.new(2024, 1, 31) => -0.01, Date.new(2024, 2, 29) => 0.02, Date.new(2024, 3, 31) => -0.015 }
    p = Monte::Portfolio.new(
      stock: { mu: 0.09, sigma: 0.16 }, bond: { mu: 0.03, sigma: 0.05 },
      stock_returns: stock_returns, bond_returns: bond_returns
    )
    assert p.correlation < 1.0
    assert p.sigma < 0.16, "60/40 σ (#{p.sigma}) should be below the 100%-stocks σ"
  end

  test "sigma follows the two-asset variance formula" do
    p = portfolio # ρ = 1, σs = 0.16, σb = 0.05
    expected = Math.sqrt((0.6**2) * 0.16**2 + (0.4**2) * 0.05**2 + 2 * 0.6 * 0.4 * 1.0 * 0.16 * 0.05)
    assert_in_delta expected, p.sigma, 1e-9
  end
end
