module Monte
  # Pure Monte Carlo engine — zero Rails dependencies, seeded, deterministic.
  #
  # Simulates two plain geometric-Brownian-motion (GBM) paths with independent
  # draws (uncoupled) and returns summary statistics plus the per-step data the
  # fan-of-futures chart needs. Common-random-numbers coupling and the DCA /
  # debt-adjusted behaviors arrive in later slices.
  #
  #   Monte::Simulator.new(amount: 50_000, horizon: 5, seed: 123)
  #     .call(path_a: { mu: 0.08, sigma: 0.16 }, path_b: { mu: 0.045, sigma: 0.005 })
  #   # => { median_a:, median_b:, p5_a:, p95_a:, p5_b:, p95_b:, win_rate_a:, steps:,
  #   #      chart: { band_a:, band_b:, sample_a:, sample_b: } }
  #
  # The chart payload is snapshotted into the frozen Comparison row so the
  # permalink reproduces its original fan: per-step p5/median/p95 bands computed
  # from all paths, plus a small sample of whole paths for the faint spaghetti.
  class Simulator
    # Whole paths kept per side for the chart's spaghetti texture. The envelope
    # and median line use the bands (computed from all paths), not this sample.
    SAMPLE_SIZE = 40

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
      paths_a = Array.new(@n_paths)
      paths_b = Array.new(@n_paths)

      @n_paths.times do |i|
        paths_a[i] = simulate_path(path_a[:mu], path_a[:sigma], rng)
        paths_b[i] = simulate_path(path_b[:mu], path_b[:sigma], rng)
      end

      finals_a = paths_a.map(&:last)
      finals_b = paths_b.map(&:last)
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
        steps: @steps,
        chart: {
          band_a: band(paths_a),
          band_b: band(paths_b),
          sample_a: sample(paths_a),
          sample_b: sample(paths_b)
        }
      }
    end

    private

    # One plain exp-GBM path as the full series [amount, s₁, …, s_steps] so the
    # fan starts pinned at "Now". A zero-volatility path compounds
    # deterministically with no sampling (consistent exp form).
    def simulate_path(mu, sigma, rng)
      path = Array.new(@steps + 1)
      path[0] = @amount
      s = @amount
      drift = (mu - 0.5 * sigma**2) * @dt
      diffusion = sigma * Math.sqrt(@dt)

      @steps.times do |t|
        s *= if sigma.zero?
          Math.exp(mu * @dt)
        else
          Math.exp(drift + diffusion * standard_normal(rng))
        end
        path[t + 1] = s
      end
      path
    end

    # Per-step p5/median/p95 envelope across every path, rounded to whole units.
    def band(paths)
      p5 = Array.new(@steps + 1)
      median = Array.new(@steps + 1)
      p95 = Array.new(@steps + 1)

      (0..@steps).each do |t|
        column = paths.map { |path| path[t] }.sort
        p5[t]     = percentile(column, 0.05).round
        median[t] = percentile(column, 0.5).round
        p95[t]    = percentile(column, 0.95).round
      end

      { p5: p5, median: median, p95: p95 }
    end

    # An evenly-strided sample of whole paths, rounded to whole units.
    def sample(paths)
      stride = (paths.length / SAMPLE_SIZE.to_f).ceil
      (0...paths.length).step(stride).map { |i| paths[i].map(&:round) }
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
      sorted[(sorted.length * quantile).floor]
    end
  end
end
