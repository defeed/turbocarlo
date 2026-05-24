module Monte
  # Small pure statistics helpers shared by the parameter recompute (#12):
  # Asset#recompute_parameters! uses mean/sample_stddev on monthly log returns,
  # and Monte::Portfolio uses correlation to blend the 60/40 volatility. Rails-free
  # and side-effect-free so the μ/σ math is unit-testable in isolation.
  module Statistics
    module_function

    def mean(xs)
      raise ArgumentError, "mean of an empty series" if xs.empty?

      xs.sum.to_f / xs.length
    end

    # Sample standard deviation (n−1 denominator) — we treat the observed history
    # as a sample of the asset's return process, not the whole population.
    def sample_stddev(xs)
      raise ArgumentError, "stddev needs at least 2 values" if xs.length < 2

      m = mean(xs)
      Math.sqrt(xs.sum { |x| (x - m)**2 } / (xs.length - 1))
    end

    # Pearson correlation over two equal-length, index-aligned series. Returns 0.0
    # when either series is flat (zero variance) — undefined correlation, treated
    # as "no linear relationship" for the portfolio blend.
    def correlation(xs, ys)
      raise ArgumentError, "correlation needs equal-length series" unless xs.length == ys.length
      raise ArgumentError, "correlation needs at least 2 values" if xs.length < 2

      mx = mean(xs)
      my = mean(ys)
      cov = xs.zip(ys).sum { |x, y| (x - mx) * (y - my) }
      denom = Math.sqrt(xs.sum { |x| (x - mx)**2 } * ys.sum { |y| (y - my)**2 })
      return 0.0 if denom.zero?

      cov / denom
    end
  end
end
