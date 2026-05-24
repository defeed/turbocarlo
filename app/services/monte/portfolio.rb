module Monte
  # Derives the 60/40 portfolio's drift/volatility from its two constituents
  # (#12). Given each side's current params and its monthly log-return series, it
  # blends μ linearly (exact for arithmetic drifts — the GBM treats μ that way)
  # and combines σ via the two-asset variance formula using the SPY–AGG
  # correlation measured over the *common window* (dates present in both series).
  #
  # Pure and Rails-free: the recompute job loads the assets and hands in
  # current_params + Asset#log_return_series, so the variance/correlation core is
  # unit-testable without the DB.
  #
  #   Monte::Portfolio.new(
  #     stock: { mu: 0.09, sigma: 0.16 }, bond: { mu: 0.03, sigma: 0.05 },
  #     stock_returns: { Date => Float, ... }, bond_returns: { Date => Float, ... }
  #   ).params  # => { mu:, sigma: }
  #
  # Because the correlation is < 1, the blended σ comes out below the 100%-stocks σ.
  class Portfolio
    def initialize(stock:, bond:, stock_returns:, bond_returns:, stock_weight: 0.6)
      @stock = stock
      @bond = bond
      @stock_returns = stock_returns
      @bond_returns = bond_returns
      @ws = stock_weight
      @wb = 1.0 - stock_weight
    end

    def params
      { mu: mu, sigma: sigma }
    end

    def mu
      @ws * @stock[:mu] + @wb * @bond[:mu]
    end

    def sigma
      ss = @stock[:sigma]
      sb = @bond[:sigma]
      variance = (@ws**2) * ss**2 + (@wb**2) * sb**2 + 2 * @ws * @wb * correlation * ss * sb
      Math.sqrt(variance)
    end

    # SPY–AGG correlation over the dates both series share.
    def correlation
      dates = (@stock_returns.keys & @bond_returns.keys).sort
      xs = dates.map { |d| @stock_returns[d] }
      ys = dates.map { |d| @bond_returns[d] }
      Monte::Statistics.correlation(xs, ys)
    end
  end
end
