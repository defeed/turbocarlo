module Monte
  # Pure Monte Carlo engine — zero Rails dependencies, seeded, deterministic.
  #
  # Simulates two plain geometric-Brownian-motion (GBM) paths with independent
  # draws (uncoupled) and returns summary statistics. Common-random-numbers
  # coupling and the DCA / debt-adjusted behaviors arrive in later slices.
  #
  #   Monte::Simulator.new(amount: 50_000, horizon: 5, seed: 123)
  #     .call(path_a: { mu: 0.08, sigma: 0.16 }, path_b: { mu: 0.045, sigma: 0.005 })
  #   # => { median_a:, median_b:, p5_a:, p95_a:, p5_b:, p95_b:, win_rate_a:, steps: }
  class Simulator
    def initialize(amount:, horizon:, seed:, n_paths: 500)
      @amount = amount.to_f
      @horizon = horizon
      @seed = seed
      @n_paths = n_paths
      @steps = [ horizon * 12, 120 ].min
      @dt = horizon.to_f / @steps
    end

    def call(path_a:, path_b:)
      rng = Random.new(@seed)
      finals_a = Array.new(@n_paths)
      finals_b = Array.new(@n_paths)

      @n_paths.times do |i|
        finals_a[i] = simulate_final(path_a[:mu], path_a[:sigma], rng)
        finals_b[i] = simulate_final(path_b[:mu], path_b[:sigma], rng)
      end

      wins_a = @n_paths.times.count { |i| finals_a[i] > finals_b[i] }
      sorted_a = finals_a.sort
      sorted_b = finals_b.sort

      {
        median_a: percentile(sorted_a, 0.5),
        median_b: percentile(sorted_b, 0.5),
        p5_a: percentile(sorted_a, 0.05),
        p95_a: percentile(sorted_a, 0.95),
        p5_b: percentile(sorted_b, 0.05),
        p95_b: percentile(sorted_b, 0.95),
        win_rate_a: (100.0 * wins_a / @n_paths).round,
        steps: @steps
      }
    end

    private

    # One plain exp-GBM path, returning its terminal value. A zero-volatility
    # path compounds deterministically with no sampling (consistent exp form).
    def simulate_final(mu, sigma, rng)
      s = @amount
      drift = (mu - 0.5 * sigma**2) * @dt
      diffusion = sigma * Math.sqrt(@dt)

      @steps.times do
        s *= if sigma.zero?
          Math.exp(mu * @dt)
        else
          Math.exp(drift + diffusion * standard_normal(rng))
        end
      end
      s
    end

    # Box–Muller transform on the seeded RNG.
    def standard_normal(rng)
      u1 = rng.rand
      u1 = rng.rand while u1.zero?
      u2 = rng.rand
      Math.sqrt(-2.0 * Math.log(u1)) * Math.cos(2.0 * Math::PI * u2)
    end

    # Matches the prototype's index-based percentile (floor(n * q)).
    def percentile(sorted, quantile)
      sorted[(@n_paths * quantile).floor]
    end
  end
end
